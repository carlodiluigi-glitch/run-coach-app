import '../models/workout.dart';
import '../models/workout_step.dart';

/// Eventi emessi dal motore di allenamento.
enum WorkoutEventType {
  /// L'allenamento e' partito.
  started,

  /// E' iniziato un nuovo step.
  stepStarted,

  /// Countdown vocale prima della fine dello step corrente.
  countdown,

  /// Mancano pochi metri alla fine di uno step a distanza.
  lastMeters,

  /// L'allenamento e' terminato.
  finished,
}

/// Evento prodotto dal motore, consumato dal provider e dal coach vocale.
class WorkoutEvent {
  const WorkoutEvent({
    required this.type,
    this.step,
    this.previousStep,
    this.countdownSeconds,
    this.remainingMeters,
  });

  final WorkoutEventType type;

  /// Step interessato (quello nuovo per `stepStarted`, quello in corso per gli
  /// altri eventi).
  final ResolvedStep? step;

  /// Step appena concluso (solo per `stepStarted`).
  final ResolvedStep? previousStep;

  final int? countdownSeconds;
  final double? remainingMeters;
}

/// Motore che esegue automaticamente la sequenza di step di un allenamento.
///
/// FUNZIONAMENTO
/// -------------
/// Il motore non ha un timer proprio: viene "alimentato" dal provider della
/// corsa con la distanza totale e il tempo attivo totale. Ad ogni update
/// calcola se lo step corrente e' concluso e, in tal caso, avanza.
/// Questo lo rende deterministico e testabile senza GPS.
class WorkoutEngine {
  WorkoutEngine(this.workout) : _steps = workout.expand();

  final Workout workout;
  final List<ResolvedStep> _steps;

  int _currentIndex = 0;
  bool _started = false;
  bool _finished = false;

  /// Distanza totale (m) e tempo attivo (s) all'inizio dello step corrente.
  double _stepStartDistance = 0.0;
  int _stepStartSeconds = 0;

  /// Ultimi valori ricevuti.
  double _totalDistance = 0.0;
  int _totalSeconds = 0;

  /// Countdown gia' annunciati per lo step corrente (per non ripeterli).
  final Set<int> _announcedCountdowns = <int>{};
  bool _announcedLastMeters = false;

  /// Soglie di countdown, in secondi, annunciate prima della fine di uno step.
  static const List<int> countdownThresholds = <int>[10, 5, 3, 2, 1];

  /// Metri residui sotto i quali si annuncia "ultimi metri".
  static const double lastMetersThreshold = 100.0;

  List<ResolvedStep> get steps => List<ResolvedStep>.unmodifiable(_steps);

  bool get isEmpty => _steps.isEmpty;
  bool get isFinished => _finished;
  bool get isStarted => _started;

  int get currentIndex => _currentIndex;
  int get totalSteps => _steps.length;

  ResolvedStep? get currentStep =>
      (_currentIndex >= 0 && _currentIndex < _steps.length)
          ? _steps[_currentIndex]
          : null;

  ResolvedStep? get nextStep => (_currentIndex + 1 < _steps.length)
      ? _steps[_currentIndex + 1]
      : null;

  /// Distanza percorsa nello step corrente (metri).
  double get stepDistanceMeters {
    final double value = _totalDistance - _stepStartDistance;
    return value < 0 ? 0 : value;
  }

  /// Tempo trascorso nello step corrente (secondi di tempo attivo).
  int get stepElapsedSeconds {
    final int value = _totalSeconds - _stepStartSeconds;
    return value < 0 ? 0 : value;
  }

  /// Metri mancanti alla fine dello step (solo step a distanza).
  double? get remainingMeters {
    final ResolvedStep? step = currentStep;
    if (step == null || !step.step.isDistanceBased) return null;
    final double remaining = step.step.goalDistanceMeters - stepDistanceMeters;
    return remaining < 0 ? 0 : remaining;
  }

  /// Secondi mancanti alla fine dello step (solo step a tempo).
  int? get remainingSeconds {
    final ResolvedStep? step = currentStep;
    if (step == null || step.step.isDistanceBased) return null;
    final int remaining = step.step.goalSeconds - stepElapsedSeconds;
    return remaining < 0 ? 0 : remaining;
  }

  /// Avanzamento dello step corrente, 0.0 - 1.0.
  double get stepProgress {
    final ResolvedStep? step = currentStep;
    if (step == null) return 0.0;
    double progress;
    if (step.step.isDistanceBased) {
      final double goal = step.step.goalDistanceMeters;
      progress = goal <= 0 ? 1.0 : stepDistanceMeters / goal;
    } else {
      final int goal = step.step.goalSeconds;
      progress = goal <= 0 ? 1.0 : stepElapsedSeconds / goal;
    }
    if (progress.isNaN || progress < 0) return 0.0;
    return progress > 1.0 ? 1.0 : progress;
  }

  /// Avanzamento complessivo dell'allenamento, 0.0 - 1.0.
  double get overallProgress {
    if (_steps.isEmpty) return 0.0;
    if (_finished) return 1.0;
    return ((_currentIndex + stepProgress) / _steps.length).clamp(0.0, 1.0);
  }

  /// Ripetizione corrente e totale del blocco in esecuzione.
  int get repetitionIndex => currentStep?.repetitionIndex ?? 0;
  int get repetitionTotal => currentStep?.repetitionTotal ?? 0;

  /// Passo target dello step corrente.
  PaceTarget? get currentPaceTarget => currentStep?.step.paceTarget;

  /// Avvia il motore. Restituisce gli eventi iniziali.
  List<WorkoutEvent> start() {
    if (_started || _steps.isEmpty) return const <WorkoutEvent>[];
    _started = true;
    _currentIndex = 0;
    _stepStartDistance = _totalDistance;
    _stepStartSeconds = _totalSeconds;
    _announcedCountdowns.clear();
    _announcedLastMeters = false;
    return <WorkoutEvent>[
      WorkoutEvent(type: WorkoutEventType.started, step: currentStep),
      WorkoutEvent(type: WorkoutEventType.stepStarted, step: currentStep),
    ];
  }

  /// Aggiorna il motore con i valori totali della corsa.
  ///
  /// [totalDistanceMeters] distanza totale filtrata dall'inizio attivita'.
  /// [totalActiveSeconds] tempo attivo totale (pause escluse).
  List<WorkoutEvent> update({
    required double totalDistanceMeters,
    required int totalActiveSeconds,
  }) {
    _totalDistance = totalDistanceMeters;
    _totalSeconds = totalActiveSeconds;

    if (!_started || _finished || _steps.isEmpty) {
      return const <WorkoutEvent>[];
    }

    final List<WorkoutEvent> events = <WorkoutEvent>[];

    // Il ciclo gestisce anche il caso (raro) in cui un singolo aggiornamento
    // completi piu' step consecutivi, ad esempio dopo un lungo blocco.
    bool advanced = true;
    int safety = 0;
    while (advanced && !_finished && safety < 100) {
      safety++;
      advanced = false;
      if (_isCurrentStepComplete()) {
        final ResolvedStep? completed = currentStep;
        // Il nuovo step parte esattamente dall'obiettivo del precedente, non
        // dai valori attuali: cosi' non si perde l'eventuale "extra" percorso.
        final WorkoutStep done = completed!.step;
        if (done.isDistanceBased) {
          _stepStartDistance += done.goalDistanceMeters;
          _stepStartSeconds = _totalSeconds;
        } else {
          _stepStartSeconds += done.goalSeconds;
          _stepStartDistance = _totalDistance;
        }

        if (_currentIndex + 1 >= _steps.length) {
          _finished = true;
          events.add(WorkoutEvent(
            type: WorkoutEventType.finished,
            previousStep: completed,
          ));
        } else {
          _currentIndex++;
          _announcedCountdowns.clear();
          _announcedLastMeters = false;
          events.add(WorkoutEvent(
            type: WorkoutEventType.stepStarted,
            step: currentStep,
            previousStep: completed,
          ));
          advanced = true;
        }
      }
    }

    if (_finished) return events;

    // Countdown vocale prima della fine dello step a tempo.
    final int? secondsLeft = remainingSeconds;
    if (secondsLeft != null) {
      // Le soglie sono ordinate dalla piu' grande alla piu' piccola: si
      // annuncia solo la piu' alta ancora valida, cosi' un aggiornamento
      // "saltato" non fa perdere il countdown ne' lo fa ripetere.
      for (final int threshold in countdownThresholds) {
        if (secondsLeft <= threshold && !_announcedCountdowns.contains(threshold)) {
          _announcedCountdowns.add(threshold);
          events.add(WorkoutEvent(
            type: WorkoutEventType.countdown,
            step: currentStep,
            countdownSeconds: threshold,
          ));
          break;
        }
      }
    }

    // Avviso "ultimi metri" per gli step a distanza.
    final double? metersLeft = remainingMeters;
    if (metersLeft != null &&
        !_announcedLastMeters &&
        metersLeft <= lastMetersThreshold &&
        (currentStep?.step.goalDistanceMeters ?? 0) > lastMetersThreshold * 2) {
      _announcedLastMeters = true;
      events.add(WorkoutEvent(
        type: WorkoutEventType.lastMeters,
        step: currentStep,
        remainingMeters: metersLeft,
      ));
    }

    return events;
  }

  /// Forza il passaggio allo step successivo (pulsante "salta fase").
  List<WorkoutEvent> skipToNextStep() {
    if (!_started || _finished || _steps.isEmpty) {
      return const <WorkoutEvent>[];
    }
    final ResolvedStep? completed = currentStep;
    _stepStartDistance = _totalDistance;
    _stepStartSeconds = _totalSeconds;
    _announcedCountdowns.clear();
    _announcedLastMeters = false;

    if (_currentIndex + 1 >= _steps.length) {
      _finished = true;
      return <WorkoutEvent>[
        WorkoutEvent(type: WorkoutEventType.finished, previousStep: completed),
      ];
    }
    _currentIndex++;
    return <WorkoutEvent>[
      WorkoutEvent(
        type: WorkoutEventType.stepStarted,
        step: currentStep,
        previousStep: completed,
      ),
    ];
  }

  bool _isCurrentStepComplete() {
    final ResolvedStep? step = currentStep;
    if (step == null) return false;
    if (step.step.isDistanceBased) {
      return stepDistanceMeters >= step.step.goalDistanceMeters;
    }
    return stepElapsedSeconds >= step.step.goalSeconds;
  }
}
