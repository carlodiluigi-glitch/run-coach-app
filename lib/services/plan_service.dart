import 'dart:math' as math;

import '../models/training_plan.dart';
import '../models/workout.dart';
import '../models/workout_step.dart';
import '../utils/formatters.dart';
import 'fitness_service.dart';

/// Generatore di piani di allenamento.
///
/// DA DOVE VENGONO LE REGOLE
/// -------------------------
/// Non sono invenzioni. Il piano applica quattro principi che in letteratura
/// sono fuori discussione:
///
/// 1. **Distribuzione polarizzata.** Circa l'80% del tempo va corso piano e
///    il 20% forte, con poco in mezzo (Seiler). Il "medio tutti i giorni" e'
///    l'errore piu' comune fra chi corre da solo: stanca come il forte senza
///    darne i benefici.
/// 2. **Passi ricavati dalla forma attuale.** Ogni seduta ha un passo
///    obiettivo derivato dal VDOT (Daniels), non una percentuale a caso.
/// 3. **Progressione con scarichi.** Il volume cresce di poco per volta e
///    ogni quarta settimana scende: l'adattamento avviene nel recupero, non
///    nel carico.
/// 4. **Periodizzazione.** Prima si costruisce il motore (lento e volume),
///    poi si aggiunge la soglia, poi il passo della gara scelta, e alla fine
///    si scarica per arrivare freschi.
///
/// Le singole sedute (ripetute da 1000, frazioni di soglia da 1600, richiami
/// brevi in scarico) sono quelle classiche dei manuali, con il numero di
/// ripetizioni che cresce settimana per settimana.
///
/// QUELLO CHE QUESTO PIANO NON PUO' SAPERE
/// ---------------------------------------
/// Se hai dormito male, se il ginocchio tira, se al lavoro e' una settimana
/// pesante. Un piano scritto un mese prima e' un'ipotesi: va corretto in
/// corsa. Quella parte arrivera' con il check-in giornaliero.
class PlanService {
  const PlanService({this.fitness = const FitnessService()});

  final FitnessService fitness;

  /// Giorni della settimana in cui si corre, secondo quanti giorni hai.
  ///
  /// Le sedute di qualita' cadono sempre di martedi' e giovedi' e il lungo di
  /// domenica: schema fisso di proposito, perche' un piano si segue solo se e'
  /// prevedibile. 1 = lunedi', 7 = domenica.
  static List<int> runDaysFor(int daysPerWeek) {
    switch (daysPerWeek) {
      case 3:
        return <int>[2, 4, 7];
      case 4:
        return <int>[2, 4, 6, 7];
      case 5:
        return <int>[2, 3, 4, 6, 7];
      default:
        return <int>[1, 2, 3, 4, 6, 7];
    }
  }

  /// Giorni preferiti per la qualita', in ordine.
  static const List<int> qualityDayPreference = <int>[2, 4];

  /// Genera il piano. `null` se la forma non e' stimabile.
  TrainingPlan? generate(PlanConfig config) {
    final TrainingPaces? paces = fitness.pacesFor(config.vdot);
    if (paces == null) return null;

    final int weeks =
        config.weeks.clamp(config.goal.minWeeks, config.goal.maxWeeks);
    final int days = config.daysPerWeek.clamp(3, 6);

    final List<PlanPhase> phases = phasesFor(weeks, config.goal);
    final List<double> volumes = volumesFor(
      weeks: weeks,
      phases: phases,
      startWeeklyKm: config.startWeeklyKm,
      goal: config.goal,
    );

    final List<PlanWeek> built = <PlanWeek>[];
    for (int i = 0; i < weeks; i++) {
      built.add(_buildWeek(
        index: i,
        phase: phases[i],
        targetKm: volumes[i],
        config: config,
        paces: paces,
        days: days,
        isDownWeek: _isDownWeek(i, phases[i]),
      ));
    }

    return _applyRaces(
      TrainingPlan(config: config, weeks: built),
      paces,
    );
  }

  // ------------------------------------------------------------------ fasi
  /// Divisione del piano in fasi.
  List<PlanPhase> phasesFor(int weeks, RaceGoal goal) {
    if (weeks <= 0) return <PlanPhase>[];

    // Senza una gara non c'e' niente per cui arrivare in forma un giorno
    // preciso: si costruisce e si sviluppa, senza scarico finale.
    if (goal == RaceGoal.fitness) {
      final int base = math.max(1, (weeks * 0.35).round());
      return List<PlanPhase>.generate(
        weeks,
        (int i) => i < base ? PlanPhase.base : PlanPhase.build,
      );
    }

    int taper = (weeks * 0.10).round().clamp(1, 3);
    int peak = (weeks * 0.18).round().clamp(1, 4);
    int remaining = weeks - taper - peak;

    // Piani molto corti: si tiene una settimana per fase e il resto va in
    // sviluppo, che e' la fase che rende piu' in poco tempo.
    if (remaining < 2) {
      taper = 1;
      peak = 1;
      remaining = weeks - 2;
      if (remaining < 2) {
        return List<PlanPhase>.generate(
          weeks,
          (int i) => i == weeks - 1 ? PlanPhase.taper : PlanPhase.build,
        );
      }
    }

    int base = math.max(1, (remaining * 0.55).round());
    int build = remaining - base;
    if (build < 1) {
      build = 1;
      base = remaining - 1;
    }

    final List<PlanPhase> out = <PlanPhase>[];
    for (int i = 0; i < base; i++) {
      out.add(PlanPhase.base);
    }
    for (int i = 0; i < build; i++) {
      out.add(PlanPhase.build);
    }
    for (int i = 0; i < peak; i++) {
      out.add(PlanPhase.peak);
    }
    for (int i = 0; i < taper; i++) {
      out.add(PlanPhase.taper);
    }
    return out;
  }

  /// Ogni quarta settimana e' di scarico, ma non durante lo scarico finale.
  bool _isDownWeek(int index, PlanPhase phase) {
    if (phase == PlanPhase.taper || phase == PlanPhase.recovery) return false;
    return (index + 1) % 4 == 0;
  }

  // --------------------------------------------------------------- volumi
  /// Chilometri previsti settimana per settimana.
  List<double> volumesFor({
    required int weeks,
    required List<PlanPhase> phases,
    required double startWeeklyKm,
    required RaceGoal goal,
  }) {
    final double start = startWeeklyKm <= 0 ? 15.0 : startWeeklyKm;

    // Il picco non supera mai il 55% in piu' del punto di partenza, ne' il
    // tetto della distanza obiettivo. Chi parte da 20 km non finisce a 80:
    // e' la strada piu' breve per farsi male.
    double peakKm = math.min(start * 1.55, goal.weeklyCapKm);
    if (peakKm < start) peakKm = start;

    // Il picco si raggiunge alla fine dell'ultima settimana prima dello
    // scarico finale.
    int lastLoadIndex = weeks - 1;
    for (int i = weeks - 1; i >= 0; i--) {
      if (phases[i] != PlanPhase.taper) {
        lastLoadIndex = i;
        break;
      }
    }

    final List<double> taperFactors = _taperFactors(
      phases.where((PlanPhase p) => p == PlanPhase.taper).length,
    );
    int taperSeen = 0;

    final List<double> out = <double>[];
    for (int i = 0; i < weeks; i++) {
      double value;
      if (phases[i] == PlanPhase.taper) {
        final double factor = taperSeen < taperFactors.length
            ? taperFactors[taperSeen]
            : taperFactors.last;
        taperSeen++;
        value = peakKm * factor;
      } else {
        final double progress =
            lastLoadIndex <= 0 ? 1.0 : i / lastLoadIndex.toDouble();
        value = start + (peakKm - start) * progress.clamp(0.0, 1.0);
        if (_isDownWeek(i, phases[i])) {
          value *= 0.75;
        }
      }
      if (value < start * 0.45) value = start * 0.45;
      out.add(double.parse(value.toStringAsFixed(1)));
    }
    return out;
  }

  /// Quanto si scende nelle settimane di scarico finale.
  List<double> _taperFactors(int count) {
    switch (count) {
      case 0:
        return <double>[1.0];
      case 1:
        return <double>[0.55];
      case 2:
        return <double>[0.70, 0.50];
      default:
        return <double>[0.75, 0.60, 0.45];
    }
  }

  // ------------------------------------------------------------ settimana
  PlanWeek _buildWeek({
    required int index,
    required PlanPhase phase,
    required double targetKm,
    required PlanConfig config,
    required TrainingPaces paces,
    required int days,
    required bool isDownWeek,
  }) {
    final DateTime weekStart = _dayOnly(
      config.startDate.add(Duration(days: index * 7)),
    );
    final List<int> runDays = runDaysFor(days);
    final int longDay = runDays.last;

    int qualityWanted;
    switch (phase) {
      case PlanPhase.base:
        qualityWanted = 1;
        break;
      case PlanPhase.build:
      case PlanPhase.peak:
        qualityWanted = 2;
        break;
      case PlanPhase.taper:
        qualityWanted = 1;
        break;
      case PlanPhase.recovery:
        qualityWanted = 0;
        break;
    }
    if (days <= 3) qualityWanted = math.min(qualityWanted, 1);
    if (isDownWeek) qualityWanted = math.min(qualityWanted, 1);

    final List<int> qualityDays = <int>[];
    for (final int day in qualityDayPreference) {
      if (qualityDays.length >= qualityWanted) break;
      if (runDays.contains(day) && day != longDay) qualityDays.add(day);
    }

    // ------------------------------------------------------------- lungo
    final double longFraction = _longFraction(phase);
    double longKm = targetKm * longFraction;
    final double capKm = config.goal.longRunCapMeters / 1000.0;
    if (longKm > capKm) longKm = capKm;
    if (longKm < 5) longKm = math.min(5.0, targetKm * 0.5);

    // ---------------------------------------------------------- qualita'
    final List<PlannedSession> sessions = <PlannedSession>[];
    double qualityKm = 0;

    for (int slot = 0; slot < qualityDays.length; slot++) {
      final _QualitySession built = _qualitySession(
        phase: phase,
        goal: config.goal,
        weekIndex: index,
        slot: slot,
        paces: paces,
        vdot: config.vdot,
        weekNumber: index + 1,
      );
      final double km = (built.workout.estimatedMeters) / 1000.0;
      qualityKm += km;
      sessions.add(PlannedSession(
        date: _dateOf(weekStart, qualityDays[slot]),
        kind: built.kind,
        title: built.title,
        detail: built.detail,
        distanceMeters: built.workout.estimatedMeters,
        durationSeconds: built.workout.estimatedSeconds,
        workout: built.workout,
      ));
    }

    // -------------------------------------------------------------- lenti
    final List<int> easyDays = runDays
        .where((int d) => d != longDay && !qualityDays.contains(d))
        .toList();

    double remainingKm = targetKm - longKm - qualityKm;
    double perEasyKm =
        easyDays.isEmpty ? 0 : remainingKm / easyDays.length;
    if (perEasyKm < 3) perEasyKm = 3;
    if (perEasyKm > 18) perEasyKm = 18;

    for (final int day in easyDays) {
      sessions.add(PlannedSession(
        date: _dateOf(weekStart, day),
        kind: SessionKind.easy,
        title: 'Lento ${perEasyKm.toStringAsFixed(0)} km',
        detail: 'Passo ${formatPaceWithUnit(paces.easy.slowestSecPerKm)} - '
            '${formatPaceWithUnit(paces.easy.fastestSecPerKm)}. '
            'Se fai fatica a parlare, stai andando troppo forte.',
        distanceMeters: perEasyKm * 1000,
      ));
    }

    // -------------------------------------------------------------- lungo
    sessions.add(PlannedSession(
      date: _dateOf(weekStart, longDay),
      kind: SessionKind.long,
      title: 'Lungo ${longKm.toStringAsFixed(0)} km',
      detail: _longDetail(phase, config.goal, paces),
      distanceMeters: longKm * 1000,
    ));

    sessions.sort((PlannedSession a, PlannedSession b) =>
        a.date.compareTo(b.date));

    return PlanWeek(
      number: index + 1,
      phase: phase,
      startDate: weekStart,
      targetKm: targetKm,
      sessions: sessions,
      note: isDownWeek ? 'Settimana di scarico: il volume scende del 25%' : null,
    );
  }

  double _longFraction(PlanPhase phase) {
    switch (phase) {
      case PlanPhase.base:
        return 0.25;
      case PlanPhase.build:
        return 0.28;
      case PlanPhase.peak:
        return 0.30;
      case PlanPhase.taper:
        return 0.22;
      case PlanPhase.recovery:
        return 0.22;
    }
  }

  String _longDetail(PlanPhase phase, RaceGoal goal, TrainingPaces paces) {
    if (phase == PlanPhase.peak &&
        (goal == RaceGoal.half || goal == RaceGoal.marathon)) {
      return 'Ultimo terzo al passo medio '
          '(${formatPaceWithUnit(paces.marathon.secondsPerKm)}). '
          'Serve a imparare a spingere da stanco.';
    }
    return 'Tutto lento, '
        '${formatPaceWithUnit(paces.easy.slowestSecPerKm)} o piu\'. '
        'Il lungo costruisce la resistenza col tempo sui piedi, non col ritmo.';
  }

  // ------------------------------------------------------ sedute qualita'
  _QualitySession _qualitySession({
    required PlanPhase phase,
    required RaceGoal goal,
    required int weekIndex,
    required int slot,
    required TrainingPaces paces,
    required double vdot,
    required int weekNumber,
  }) {
    final String idBase = 'plan-w$weekNumber-q$slot';

    switch (phase) {
      case PlanPhase.base:
        {
        // In costruzione si tocca il veloce senza farne una seduta dura: il
        // corpo impara a muoversi in fretta mentre il motore cresce piano.
        if (weekIndex.isEven) {
          final int reps = 8;
          return _QualitySession(
            kind: SessionKind.fartlek,
            title: 'Fartlek $reps x 1 minuto',
            detail: 'Un minuto veloce, uno lento, otto volte. '
                'Senza guardare il passo: a sensazione, forte ma controllato.',
            workout: _buildWorkout(
              id: idBase,
              name: 'Fartlek $reps x 1\'',
              paces: paces,
              warmupSeconds: 720,
              repeat: reps,
              work: _timeStep(StepType.interval, 60, paces.interval),
              recovery: _timeStep(StepType.recovery, 60, paces.easy),
              cooldownSeconds: 480,
            ),
          );
        }
        final int reps = 8;
        return _QualitySession(
          kind: SessionKind.repetitions,
          title: 'Allunghi $reps x 200 m',
          detail: 'Allunghi brevi e sciolti a '
              '${formatPaceWithUnit(paces.repetition.secondsPerKm)}, '
              'con recupero camminato. Non deve stancare.',
          workout: _buildWorkout(
            id: idBase,
            name: 'Allunghi $reps x 200 m',
            paces: paces,
            warmupSeconds: 1200,
            repeat: reps,
            work: _distanceStep(StepType.interval, 200, paces.repetition),
            recovery: _timeStep(StepType.recovery, 90, paces.easy),
            cooldownSeconds: 600,
          ),
        );
        }

      case PlanPhase.build:
        {
        if (slot == 0) {
          // La soglia e' il lavoro che sposta di piu' il risultato su
          // qualunque distanza dai 5 km in su.
          final int reps = (3 + weekIndex ~/ 3).clamp(3, 5);
          return _QualitySession(
            kind: SessionKind.threshold,
            title: 'Soglia $reps x 1600 m',
            detail: 'A ${formatPaceWithUnit(paces.threshold.secondsPerKm)}, '
                'recupero 90 secondi. Deve essere "duro ma sostenibile": '
                'se negli ultimi non tieni il passo, hai iniziato troppo forte.',
            workout: _buildWorkout(
              id: idBase,
              name: 'Soglia $reps x 1600 m',
              paces: paces,
              warmupSeconds: 900,
              repeat: reps,
              work: _distanceStep(StepType.interval, 1600, paces.threshold),
              recovery: _timeStep(StepType.recovery, 90, paces.easy),
              cooldownSeconds: 600,
            ),
          );
        }
        final int reps = (4 + weekIndex ~/ 3).clamp(4, 6);
        return _QualitySession(
          kind: SessionKind.intervals,
          title: 'Ripetute $reps x 1000 m',
          detail: 'A ${formatPaceWithUnit(paces.interval.secondsPerKm)}, '
              'recupero 400 m lenti. E\' la seduta che alza il tetto: '
              'gli ultimi due devono costare.',
          workout: _buildWorkout(
            id: idBase,
            name: 'Ripetute $reps x 1000 m',
            paces: paces,
            warmupSeconds: 900,
            repeat: reps,
            work: _distanceStep(StepType.interval, 1000, paces.interval),
            recovery: _distanceStep(StepType.recovery, 400, paces.easy),
            cooldownSeconds: 600,
          ),
        );
        }

      case PlanPhase.peak:
        {
        if (slot == 0) {
          return _racePaceSession(
            idBase: idBase,
            goal: goal,
            paces: paces,
            vdot: vdot,
          );
        }
        final int reps = 4;
        return _QualitySession(
          kind: SessionKind.threshold,
          title: 'Soglia $reps x 2000 m',
          detail: 'A ${formatPaceWithUnit(paces.threshold.secondsPerKm)}, '
              'recupero 2 minuti. Frazioni piu\' lunghe, stesso passo.',
          workout: _buildWorkout(
            id: idBase,
            name: 'Soglia $reps x 2000 m',
            paces: paces,
            warmupSeconds: 900,
            repeat: reps,
            work: _distanceStep(StepType.interval, 2000, paces.threshold),
            recovery: _timeStep(StepType.recovery, 120, paces.easy),
            cooldownSeconds: 600,
          ),
        );
        }

      case PlanPhase.taper:
        {
        const int reps = 6;
        return _QualitySession(
          kind: SessionKind.repetitions,
          title: 'Richiamo $reps x 400 m',
          detail: 'A ${formatPaceWithUnit(paces.repetition.secondsPerKm)}, '
              'recupero 400 m. Poco volume: serve a tenere la gamba viva, '
              'non ad allenare.',
          workout: _buildWorkout(
            id: idBase,
            name: 'Richiamo $reps x 400 m',
            paces: paces,
            warmupSeconds: 900,
            repeat: reps,
            work: _distanceStep(StepType.interval, 400, paces.repetition),
            recovery: _distanceStep(StepType.recovery, 400, paces.easy),
            cooldownSeconds: 600,
          ),
        );
        }

      case PlanPhase.recovery:
        {
        // Non dovrebbe arrivarci: in recupero non si programma qualita'.
        return _QualitySession(
          kind: SessionKind.easy,
          title: 'Lento',
          detail: 'Solo corsa lenta.',
          workout: _buildWorkout(
            id: idBase,
            name: 'Lento',
            paces: paces,
            warmupSeconds: 1800,
            repeat: 1,
            work: _timeStep(StepType.run, 600, paces.easy),
            recovery: null,
            cooldownSeconds: 300,
          ),
        );
        }
    }
  }

  /// Seduta al passo della gara scelta: e' quello che rende "specifica" la
  /// fase finale.
  _QualitySession _racePaceSession({
    required String idBase,
    required RaceGoal goal,
    required TrainingPaces paces,
    required double vdot,
  }) {
    final double? meters = goal.meters;
    if (meters == null) {
      const int reps = 5;
      return _QualitySession(
        kind: SessionKind.intervals,
        title: 'Ripetute $reps x 1000 m',
        detail: 'A ${formatPaceWithUnit(paces.interval.secondsPerKm)}, '
            'recupero 400 m lenti.',
        workout: _buildWorkout(
          id: idBase,
          name: 'Ripetute $reps x 1000 m',
          paces: paces,
          warmupSeconds: 900,
          repeat: reps,
          work: _distanceStep(StepType.interval, 1000, paces.interval),
          recovery: _distanceStep(StepType.recovery, 400, paces.easy),
          cooldownSeconds: 600,
        ),
      );
    }

    final int? raceSeconds = fitness.predictSeconds(vdot, meters);
    final double racePace = raceSeconds == null
        ? paces.threshold.secondsPerKm
        : raceSeconds / (meters / 1000.0);
    final TrainingPace pace = TrainingPace(
      key: 'G',
      label: 'Passo gara',
      description: 'Il passo previsto per la tua ${goal.label}.',
      secondsPerKm: racePace,
      fastestSecPerKm: racePace - 4,
      slowestSecPerKm: racePace + 6,
    );

    // Frazioni lunghe per le gare lunghe, piu' corte e veloci per le brevi.
    late int reps;
    late double fraction;
    late int recoverySeconds;
    switch (goal) {
      case RaceGoal.fiveK:
        reps = 5;
        fraction = 1000;
        recoverySeconds = 120;
        break;
      case RaceGoal.tenK:
        reps = 4;
        fraction = 2000;
        recoverySeconds = 150;
        break;
      case RaceGoal.half:
        reps = 3;
        fraction = 4000;
        recoverySeconds = 180;
        break;
      case RaceGoal.marathon:
        reps = 2;
        fraction = 6000;
        recoverySeconds = 180;
        break;
      case RaceGoal.fitness:
        reps = 4;
        fraction = 1500;
        recoverySeconds = 120;
        break;
    }

    return _QualitySession(
      kind: SessionKind.racePace,
      title: 'Passo gara $reps x ${formatDistanceAuto(fraction)}',
      detail: 'A ${formatPaceWithUnit(racePace)}, il passo previsto per la tua '
          '${goal.label}. Serve a farlo diventare naturale prima del giorno '
          'della gara.',
      workout: _buildWorkout(
        id: idBase,
        name: 'Passo gara $reps x ${formatDistanceAuto(fraction)}',
        paces: paces,
        warmupSeconds: 900,
        repeat: reps,
        work: _distanceStep(StepType.interval, fraction, pace),
        recovery: _timeStep(StepType.recovery, recoverySeconds, paces.easy),
        cooldownSeconds: 600,
      ),
    );
  }

  // ------------------------------------------------------------- mattoni
  WorkoutStep _distanceStep(
    StepType type,
    double meters,
    TrainingPace pace,
  ) =>
      WorkoutStep(
        type: type,
        goalType: StepGoalType.distance,
        goalDistanceMeters: meters,
        paceTarget: pace.target,
      );

  WorkoutStep _timeStep(StepType type, int seconds, TrainingPace pace) =>
      WorkoutStep(
        type: type,
        goalType: StepGoalType.time,
        goalSeconds: seconds,
        paceTarget: pace.target,
      );

  /// Struttura standard: riscaldamento, blocco ripetuto, defaticamento.
  Workout _buildWorkout({
    required String id,
    required String name,
    required TrainingPaces paces,
    required int warmupSeconds,
    required int repeat,
    required WorkoutStep work,
    required WorkoutStep? recovery,
    required int cooldownSeconds,
  }) {
    return Workout(
      id: id,
      name: name,
      blocks: <WorkoutBlock>[
        WorkoutBlock(
          id: '$id-warmup',
          steps: <WorkoutStep>[
            _timeStep(StepType.warmup, warmupSeconds, paces.easy),
          ],
        ),
        WorkoutBlock(
          id: '$id-main',
          repeat: repeat,
          steps: <WorkoutStep>[
            work,
            if (recovery != null) recovery,
          ],
        ),
        WorkoutBlock(
          id: '$id-cooldown',
          steps: <WorkoutStep>[
            _timeStep(StepType.cooldown, cooldownSeconds, paces.easy),
          ],
        ),
      ],
    );
  }

  // --------------------------------------------------------------- gare
  /// Inserisce le gare nel piano: alleggerisce prima, recupera dopo.
  ///
  /// E' la parte che serve quando salta fuori una gara non prevista. Il piano
  /// non viene rifatto: vengono solo ammorbidite le sedute intorno alla data.
  TrainingPlan _applyRaces(TrainingPlan plan, TrainingPaces paces) {
    final List<RaceEvent> races = plan.config.races;
    if (races.isEmpty) return plan;

    List<PlanWeek> weeks = plan.weeks;

    for (final RaceEvent race in races) {
      final DateTime raceDay = _dayOnly(race.date);
      final DateTime taperFrom =
          raceDay.subtract(Duration(days: race.taperDays));
      final DateTime recoveryTo =
          raceDay.add(Duration(days: race.recoveryDays));

      weeks = weeks.map((PlanWeek week) {
        bool touched = false;
        bool hasRace = false;

        final List<PlannedSession> updated = <PlannedSession>[];
        for (final PlannedSession session in week.sessions) {
          final DateTime day = _dayOnly(session.date);

          // Giorno di gara: la gara sostituisce qualunque seduta.
          if (day == raceDay) {
            hasRace = true;
            touched = true;
            updated.add(PlannedSession(
              date: session.date,
              kind: SessionKind.race,
              title: race.name,
              detail: 'Gara di ${formatDistanceAuto(race.meters)}. '
                  'Riscaldamento lento, poi dai quello che hai.',
              distanceMeters: race.meters,
            ));
            continue;
          }

          // Nei giorni prima: niente qualita', e il lungo si accorcia.
          if (!day.isBefore(taperFrom) && day.isBefore(raceDay)) {
            touched = true;
            if (session.isQuality) {
              updated.add(PlannedSession(
                date: session.date,
                kind: SessionKind.easy,
                title: 'Lento corto',
                detail: 'Qualita\' rimandata: hai la gara fra pochi giorni. '
                    'Arrivarci stanco costa piu\' di quanto renda una seduta.',
                distanceMeters: (session.distanceMeters ?? 8000) * 0.5,
              ));
            } else if (session.kind == SessionKind.long) {
              updated.add(session.copyWith(
                title: 'Lungo ridotto',
                detail: 'Accorciato per la gara in arrivo.',
                distanceMeters: (session.distanceMeters ?? 12000) * 0.6,
              ));
            } else {
              updated.add(session);
            }
            continue;
          }

          // Nei giorni dopo: solo lento, il corpo sta riparando.
          if (day.isAfter(raceDay) && !day.isAfter(recoveryTo)) {
            touched = true;
            if (session.isQuality) {
              updated.add(PlannedSession(
                date: session.date,
                kind: SessionKind.easy,
                title: 'Lento di recupero',
                detail: 'Dopo una gara il muscolo ripara per giorni. '
                    'Tornare sulla qualita\' subito e\' il modo piu\' comune '
                    'di farsi male.',
                distanceMeters: (session.distanceMeters ?? 8000) * 0.6,
              ));
            } else if (session.kind == SessionKind.long) {
              updated.add(session.copyWith(
                title: 'Lungo ridotto',
                detail: 'Ancora in recupero dalla gara.',
                distanceMeters: (session.distanceMeters ?? 12000) * 0.7,
              ));
            } else {
              updated.add(session);
            }
            continue;
          }

          updated.add(session);
        }

        if (!touched) return week;

        // Se nella settimana non c'era nessuna seduta il giorno della gara,
        // la gara va aggiunta.
        if (!hasRace &&
            !raceDay.isBefore(week.startDate) &&
            !raceDay.isAfter(week.endDate)) {
          updated.add(PlannedSession(
            date: raceDay,
            kind: SessionKind.race,
            title: race.name,
            detail: 'Gara di ${formatDistanceAuto(race.meters)}.',
            distanceMeters: race.meters,
          ));
          hasRace = true;
        }

        updated.sort((PlannedSession a, PlannedSession b) =>
            a.date.compareTo(b.date));

        final String note = hasRace
            ? 'Gara: ${race.name}'
            : (raceDay.isAfter(week.endDate)
                ? 'Alleggerita per la gara in arrivo'
                : 'Recupero dopo la gara');

        return week.copyWith(
          sessions: updated,
          note: note,
          phase: (!hasRace && raceDay.isBefore(week.startDate))
              ? PlanPhase.recovery
              : week.phase,
        );
      }).toList();
    }

    return TrainingPlan(config: plan.config, weeks: weeks);
  }

  // -------------------------------------------------------------- helper
  DateTime _dayOnly(DateTime date) =>
      DateTime(date.year, date.month, date.day);

  /// Data del giorno [weekday] (1 = lunedi') dentro la settimana che inizia a
  /// [weekStart].
  DateTime _dateOf(DateTime weekStart, int weekday) =>
      weekStart.add(Duration(days: weekday - 1));
}

/// Risultato interno: una seduta di qualita' pronta.
class _QualitySession {
  const _QualitySession({
    required this.kind,
    required this.title,
    required this.detail,
    required this.workout,
  });

  final SessionKind kind;
  final String title;
  final String detail;
  final Workout workout;
}
