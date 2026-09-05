import 'dart:async';
import 'dart:collection';

import 'package:flutter/foundation.dart';

import '../models/lap.dart';
import '../models/running_activity.dart';
import '../models/user_settings.dart';
import '../models/workout.dart';
import '../models/workout_step.dart';
import '../services/audio_coach_service.dart';
import '../services/gps_filter.dart';
import '../services/gps_service.dart';
import '../services/permission_service.dart';
import '../services/screen_service.dart';
import '../services/workout_engine.dart';
import '../utils/formatters.dart';

/// Stato della registrazione.
enum RunState { idle, ready, running, paused, finished }

/// Campione usato per il calcolo del passo istantaneo.
class _PaceSample {
  const _PaceSample(this.elapsedSeconds, this.distanceMeters);
  final double elapsedSeconds;
  final double distanceMeters;
}

/// Cuore della registrazione: timer, GPS, distanza, lap, motore allenamento
/// e coach vocale.
class RunningProvider extends ChangeNotifier {
  RunningProvider({
    required GpsService gpsService,
    required PermissionService permissionService,
    required AudioCoachService coach,
    ScreenService? screenService,
  })  : _gps = gpsService,
        _permissions = permissionService,
        _coach = coach,
        _screen = screenService ?? ScreenService();

  final GpsService _gps;
  final PermissionService _permissions;
  final AudioCoachService _coach;
  final ScreenService _screen;

  // ------------------------------------------------------------------ stato
  RunState _state = RunState.idle;
  GpsAvailability _gpsAvailability = GpsAvailability.unknown;
  String? _gpsError;

  final GpsFilter _filter = GpsFilter();
  final Stopwatch _stopwatch = Stopwatch();
  Timer? _ticker;
  StreamSubscription<GpsSample>? _gpsSub;
  StreamSubscription<Object>? _gpsErrorSub;

  DateTime? _startTime;
  double _distanceMeters = 0.0;
  double? _lastAccuracy;
  DateTime? _lastFixAt;
  double? _rawGpsSpeed;

  final List<Lap> _laps = <Lap>[];
  double _lapStartDistance = 0.0;
  int _lapStartSeconds = 0;

  final List<RoutePoint> _route = <RoutePoint>[];
  int _lastRoutePointSecond = -10;

  /// Finestra scorrevole usata per il passo attuale (ultimi ~30 secondi).
  final Queue<_PaceSample> _paceWindow = Queue<_PaceSample>();
  static const double _paceWindowSeconds = 30.0;

  /// Durata minima della finestra: sotto, il passo non e' affidabile.
  static const double _paceMinimumSeconds = 10.0;

  /// Velocita' sotto la quale si considera di essere fermi (m/s).
  static const double _paceStandingSpeed = 0.3;

  /// Peso del valore nuovo nel lisciamento esponenziale.
  static const double _paceSmoothing = 0.3;

  /// Passo mostrato, gia' smorzato.
  double? _smoothedPaceSecPerKm;

  // Impostazioni correnti (aggiornate dal SettingsProvider).
  UserSettings _settings = const UserSettings();

  // Allenamento programmato.
  Workout? _workout;
  WorkoutEngine? _engine;
  PaceStatus _paceStatus = PaceStatus.unknown;
  DateTime? _lastPaceCheck;

  // --------------------------------------------------------------- getters
  RunState get state => _state;
  bool get isIdle => _state == RunState.idle || _state == RunState.ready;
  bool get isRunning => _state == RunState.running;
  bool get isPaused => _state == RunState.paused;
  bool get isActive => _state == RunState.running || _state == RunState.paused;
  bool get isFinished => _state == RunState.finished;

  GpsAvailability get gpsAvailability => _gpsAvailability;
  String? get gpsError => _gpsError;
  double? get accuracy => _lastAccuracy;

  /// `true` se e' arrivato almeno un punto GPS valido di recente.
  bool get hasGpsFix {
    final DateTime? last = _lastFixAt;
    if (last == null) return false;
    return DateTime.now().difference(last).inSeconds < 15;
  }

  /// Qualita' del segnale in 3 livelli, per l'indicatore in UI.
  int get gpsQuality {
    final double? acc = _lastAccuracy;
    if (!hasGpsFix || acc == null) return 0;
    if (acc <= 10) return 3;
    if (acc <= 20) return 2;
    return 1;
  }

  double get distanceMeters => _distanceMeters;
  Duration get elapsed => _stopwatch.elapsed;
  int get elapsedSeconds => _stopwatch.elapsed.inSeconds;
  DateTime? get startTime => _startTime;

  List<Lap> get laps => List<Lap>.unmodifiable(_laps);
  int get lapCount => _laps.length;
  Lap? get lastLap => _laps.isEmpty ? null : _laps.last;

  /// Distanza percorsa nel lap in corso.
  double get currentLapDistance {
    final double value = _distanceMeters - _lapStartDistance;
    return value < 0 ? 0 : value;
  }

  /// Tempo del lap in corso.
  int get currentLapSeconds {
    final int value = elapsedSeconds - _lapStartSeconds;
    return value < 0 ? 0 : value;
  }

  /// Passo medio dell'attivita' in secondi per chilometro.
  double? get averagePaceSecPerKm =>
      paceFromDistanceAndTime(_distanceMeters, elapsedSeconds);

  /// Passo attuale calcolato sulla finestra scorrevole degli ultimi secondi.
  ///
  /// Usare la finestra invece dell'ultimo singolo punto rende il valore molto
  /// piu' stabile e leggibile mentre si corre.
  double? get currentPaceSecPerKm => _smoothedPaceSecPerKm;

  /// Velocita' attuale in m/s (dal passo calcolato, con fallback sul GPS).
  double? get currentSpeedMps {
    final double? pace = currentPaceSecPerKm;
    if (pace != null) return 1000.0 / pace;
    return _rawGpsSpeed;
  }

  Workout? get workout => _workout;
  WorkoutEngine? get engine => _engine;
  bool get hasWorkout => _engine != null && !_engine!.isEmpty;

  ResolvedStep? get currentStep => _engine?.currentStep;
  ResolvedStep? get nextStep => _engine?.nextStep;
  PaceTarget? get currentPaceTarget => _engine?.currentPaceTarget;
  PaceStatus get paceStatus => _paceStatus;

  ActivityType get activityType =>
      hasWorkout ? ActivityType.workout : ActivityType.free;

  String get activityName => _workout?.name ?? 'Corsa libera';

  // ----------------------------------------------------------- impostazioni
  /// Aggiorna le impostazioni usate durante la corsa.
  void applySettings(UserSettings settings) {
    _settings = settings;
  }

  // -------------------------------------------------------------- permessi
  /// Verifica permessi e stato del GPS. Da chiamare aprendo la schermata corsa.
  Future<GpsAvailability> prepare({bool request = true}) async {
    _gpsAvailability =
        request ? await _permissions.checkAndRequest() : await _permissions.check();
    if (_gpsAvailability.isReady && _state == RunState.idle) {
      _state = RunState.ready;
      // Si avvia subito lo stream per agganciare il segnale prima dello START.
      await _startGpsStream();
    }
    notifyListeners();
    return _gpsAvailability;
  }

  Future<bool> openLocationSettings() => _permissions.openLocationSettings();
  Future<bool> openAppSettings() => _permissions.openAppSettings();

  /// Ferma lo stream GPS di anteprima quando si esce dalla schermata corsa
  /// senza aver avviato la registrazione (evita consumo inutile di batteria).
  ///
  /// Non notifica i listener: viene chiamato durante il dispose della
  /// schermata, quando non c'e' piu' niente da ridisegnare.
  Future<void> stopPreview() async {
    if (isActive) return;
    await _stopGpsStream();
    if (_state == RunState.ready) _state = RunState.idle;
  }

  // ------------------------------------------------------------------ start
  /// Avvia la registrazione. Restituisce `false` se il GPS non e' disponibile.
  Future<bool> start({Workout? workout}) async {
    if (isActive) return true;

    final GpsAvailability availability = await _permissions.checkAndRequest();
    _gpsAvailability = availability;
    if (!availability.isReady) {
      notifyListeners();
      return false;
    }

    _resetInternals();

    _workout = workout;
    if (workout != null && workout.expand().isNotEmpty) {
      _engine = WorkoutEngine(workout);
    } else {
      _engine = null;
    }

    _startTime = DateTime.now();
    _state = RunState.running;
    _stopwatch
      ..reset()
      ..start();

    await _startGpsStream();
    _startTicker();

    if (_settings.keepScreenOn) {
      await _screen.setKeepScreenOn(true);
    }

    _coach.resetPaceAlerts();
    await _coach.speak(
      hasWorkout ? _coach.phrases.start() : _coach.phrases.freeRunStart(),
      priority: SpeechPriority.high,
    );

    final WorkoutEngine? engine = _engine;
    if (engine != null) {
      _handleEvents(engine.start());
    }

    notifyListeners();
    return true;
  }

  // ------------------------------------------------------------ pausa/stop
  Future<void> pause() async {
    if (_state != RunState.running) return;
    _state = RunState.paused;
    _stopwatch.stop();
    // Durante la pausa non si somma distanza: si "dimentica" il riferimento.
    _filter.dropReference();
    _paceWindow.clear();
    _smoothedPaceSecPerKm = null;
    await _coach.speak(_coach.phrases.paused(), priority: SpeechPriority.high);
    notifyListeners();
  }

  Future<void> resume() async {
    if (_state != RunState.paused) return;
    _state = RunState.running;
    _stopwatch.start();
    _filter.dropReference();
    await _coach.speak(_coach.phrases.resumed(), priority: SpeechPriority.high);
    notifyListeners();
  }

  /// Termina la registrazione e restituisce l'attivita' pronta da salvare.
  ///
  /// L'attivita' NON viene ancora scritta su disco: la schermata corsa chiede
  /// prima quali scarpe sono state usate e poi la passa a `ActivityProvider`.
  Future<RunningActivity?> finish() async {
    if (!isActive) return null;

    _stopwatch.stop();
    _stopTicker();
    await _stopGpsStream();
    await _screen.setKeepScreenOn(false);

    // Chiude l'ultimo lap parziale, se ha senso (almeno 10 metri).
    if (currentLapDistance >= 10) {
      _closeLap(manual: false, partial: true);
    }

    await _coach.speak(_coach.phrases.stopped(), priority: SpeechPriority.high);

    final DateTime start = _startTime ?? DateTime.now();
    final RunningActivity activity = RunningActivity(
      startTime: start,
      name: activityName,
      type: activityType,
      durationSeconds: elapsedSeconds,
      distanceMeters: _distanceMeters,
      laps: List<Lap>.from(_laps),
      route: List<RoutePoint>.from(_route),
      workoutId: _workout?.id,
    );

    _state = RunState.finished;
    notifyListeners();
    return activity;
  }

  /// Riporta il provider allo stato iniziale (dopo il salvataggio o l'annullo).
  Future<void> reset() async {
    _stopTicker();
    await _stopGpsStream();
    await _screen.setKeepScreenOn(false);
    _resetInternals();
    _state = RunState.idle;
    _workout = null;
    _engine = null;
    notifyListeners();
  }

  // -------------------------------------------------------------------- lap
  /// Lap manuale richiesto dall'utente.
  ///
  /// Nota: chiudere un lap manuale azzera anche il conteggio del lap
  /// automatico, cosi' i giri restano consecutivi e senza sovrapposizioni.
  void manualLap() {
    if (_state != RunState.running) return;
    if (currentLapDistance < 5) return;
    _closeLap(manual: true);
    notifyListeners();
  }

  /// Salta la fase corrente dell'allenamento programmato.
  void skipStep() {
    final WorkoutEngine? engine = _engine;
    if (engine == null || !isActive) return;
    _handleEvents(engine.skipToNextStep());
    notifyListeners();
  }

  // -------------------------------------------------------------- internals
  void _resetInternals() {
    _filter.reset();
    _stopwatch
      ..stop()
      ..reset();
    _distanceMeters = 0.0;
    _laps.clear();
    _lapStartDistance = 0.0;
    _lapStartSeconds = 0;
    _route.clear();
    _lastRoutePointSecond = -10;
    _paceWindow.clear();
    _smoothedPaceSecPerKm = null;
    _paceStatus = PaceStatus.unknown;
    _lastPaceCheck = null;
    _startTime = null;
    _gpsError = null;
    _rawGpsSpeed = null;
  }

  Future<void> _startGpsStream() async {
    if (_gpsSub != null) return;
    try {
      await _gps.start();
      _gpsSub = _gps.samples.listen(_onGpsSample);
      _gpsErrorSub = _gps.errors.listen((Object error) {
        _gpsError = 'Errore GPS: $error';
        notifyListeners();
      });
    } catch (error) {
      _gpsError = 'Impossibile avviare il GPS: $error';
      notifyListeners();
    }
  }

  Future<void> _stopGpsStream() async {
    await _gpsSub?.cancel();
    _gpsSub = null;
    await _gpsErrorSub?.cancel();
    _gpsErrorSub = null;
    await _gps.stop();
  }

  void _startTicker() {
    _ticker?.cancel();
    _ticker = Timer.periodic(const Duration(milliseconds: 500), (Timer _) {
      _onTick();
    });
  }

  void _stopTicker() {
    _ticker?.cancel();
    _ticker = null;
  }

  void _onGpsSample(GpsSample sample) {
    _lastAccuracy = sample.accuracy;
    _lastFixAt = DateTime.now();
    _rawGpsSpeed = sample.speed;

    // Fuori dalla registrazione i punti servono solo a mostrare la qualita'
    // del segnale prima dello START.
    if (_state != RunState.running) {
      notifyListeners();
      return;
    }

    final GpsFilterResult result = _filter.process(
      latitude: sample.latitude,
      longitude: sample.longitude,
      accuracy: sample.accuracy,
      timestamp: sample.timestamp,
    );

    if (!result.accepted) return;

    _distanceMeters += result.addedMeters;

    // Salva il tracciato con al massimo un punto ogni 2 secondi: sufficiente
    // per ricostruire il percorso senza far crescere troppo il file.
    final int seconds = elapsedSeconds;
    if (seconds - _lastRoutePointSecond >= 2) {
      _lastRoutePointSecond = seconds;
      _route.add(RoutePoint(
        latitude: sample.latitude,
        longitude: sample.longitude,
        elapsedSeconds: seconds,
        altitude: sample.altitude,
      ));
    }

    _pushPaceSample();
  }

  void _pushPaceSample() {
    final double now = _stopwatch.elapsedMilliseconds / 1000.0;
    _paceWindow.add(_PaceSample(now, _distanceMeters));
    while (_paceWindow.length > 2 &&
        now - _paceWindow.first.elapsedSeconds > _paceWindowSeconds) {
      _paceWindow.removeFirst();
    }
    _updateSmoothedPace();
  }

  /// Aggiorna il passo mostrato a partire dalla finestra corrente.
  ///
  /// A ritmo di corsa si percorrono circa 3 metri al secondo, mentre
  /// l'incertezza del GPS e' di 3-5 metri: calcolare il passo sulla
  /// differenza fra due soli punti significa leggere un errore grande
  /// quanto il dato. Qui si usano invece tutti i campioni della finestra,
  /// stimando la velocita' con una regressione lineare della distanza sul
  /// tempo, cosi' gli errori dei singoli punti si compensano fra loro.
  void _updateSmoothedPace() {
    final double? raw = _regressionPaceSecPerKm();
    if (raw == null) {
      _smoothedPaceSecPerKm = null;
      return;
    }
    final double? previous = _smoothedPaceSecPerKm;
    _smoothedPaceSecPerKm = previous == null
        ? raw
        : previous + _paceSmoothing * (raw - previous);
  }

  /// Passo grezzo della finestra, senza lisciamento.
  double? _regressionPaceSecPerKm() {
    if (_paceWindow.length < 2) return null;

    final double span =
        _paceWindow.last.elapsedSeconds - _paceWindow.first.elapsedSeconds;
    if (span < _paceMinimumSeconds) return null;

    final int n = _paceWindow.length;
    double sumT = 0;
    double sumD = 0;
    for (final _PaceSample sample in _paceWindow) {
      sumT += sample.elapsedSeconds;
      sumD += sample.distanceMeters;
    }
    final double meanT = sumT / n;
    final double meanD = sumD / n;

    double numerator = 0;
    double denominator = 0;
    for (final _PaceSample sample in _paceWindow) {
      final double dt = sample.elapsedSeconds - meanT;
      numerator += dt * (sample.distanceMeters - meanD);
      denominator += dt * dt;
    }
    if (denominator == 0) return null;

    final double speed = numerator / denominator;
    if (speed < _paceStandingSpeed) return null;

    final double pace = 1000.0 / speed;
    if (pace <= 0 || pace > 3599) return null;
    return pace;
  }

  void _onTick() {
    if (_state != RunState.running) return;

    _pushPaceSample();
    _checkAutoLap();
    _updateWorkout();
    _checkPaceAlerts();

    notifyListeners();
  }

  void _checkAutoLap() {
    if (!_settings.autoLapEnabled) return;
    final double lapDistance = _settings.autoLapDistanceMeters;
    if (lapDistance < 100) return;

    int safety = 0;
    while (currentLapDistance >= lapDistance && safety < 10) {
      safety++;
      _closeLap(manual: false, exactDistance: lapDistance);
    }
  }

  /// Chiude il lap corrente.
  ///
  /// [exactDistance] permette di chiudere il lap esattamente sulla distanza
  /// impostata (es. 1000 m) invece che sulla distanza percorsa al momento del
  /// controllo, evitando che i lap "slittino" progressivamente.
  void _closeLap({
    required bool manual,
    double? exactDistance,
    bool partial = false,
  }) {
    final double lapDistance = exactDistance ?? currentLapDistance;
    if (lapDistance <= 0) return;

    final int lapSeconds = currentLapSeconds;
    final int totalSeconds = elapsedSeconds;

    _laps.add(Lap(
      number: _laps.length + 1,
      distanceMeters: lapDistance,
      durationSeconds: lapSeconds,
      totalTimeSeconds: totalSeconds,
      manual: manual,
      stepLabel: currentStep?.label,
    ));

    _lapStartDistance += lapDistance;
    _lapStartSeconds = totalSeconds;

    if (!partial) {
      final Lap lap = _laps.last;
      unawaited(_coach.speak(
        _coach.phrases.lapCompleted(
          lapNumber: lap.number,
          distanceLabel: formatDistanceAuto(lap.distanceMeters),
          timeLabel: formatDuration(Duration(seconds: lap.durationSeconds)),
          paceLabel: formatPace(lap.paceSecondsPerKm),
        ),
      ));
    }
  }

  void _updateWorkout() {
    final WorkoutEngine? engine = _engine;
    if (engine == null) return;
    final List<WorkoutEvent> events = engine.update(
      totalDistanceMeters: _distanceMeters,
      totalActiveSeconds: elapsedSeconds,
    );
    _handleEvents(events);
  }

  void _handleEvents(List<WorkoutEvent> events) {
    for (final WorkoutEvent event in events) {
      switch (event.type) {
        case WorkoutEventType.started:
          break;
        case WorkoutEventType.stepStarted:
          final ResolvedStep? step = event.step;
          if (step == null) break;
          _coach.resetPaceAlerts();
          _paceStatus = PaceStatus.unknown;
          unawaited(_coach.speak(
            _coach.phrases.stepStart(
              typeLabel: step.step.type.label,
              goalLabel: step.step.goalLabel,
              repetitionIndex: step.repetitionIndex,
              repetitionTotal: step.repetitionTotal,
            ),
            priority: SpeechPriority.high,
          ));
          break;
        case WorkoutEventType.countdown:
          final int seconds = event.countdownSeconds ?? 0;
          unawaited(_coach.speak(
            _coach.phrases.countdown(seconds),
            priority: SpeechPriority.high,
          ));
          break;
        case WorkoutEventType.lastMeters:
          final double meters = event.remainingMeters ?? 0;
          unawaited(_coach.speak(_coach.phrases.lastMeters(meters.round())));
          break;
        case WorkoutEventType.finished:
          unawaited(_coach.speak(
            _coach.phrases.workoutCompleted(),
            priority: SpeechPriority.high,
          ));
          break;
      }
    }
  }

  void _checkPaceAlerts() {
    final PaceTarget? target = currentPaceTarget;
    if (target == null || target.isEmpty) {
      _paceStatus = PaceStatus.unknown;
      return;
    }

    final double? pace = currentPaceSecPerKm;
    final PaceStatus status = target.evaluate(pace);
    _paceStatus = status;

    if (!_settings.paceAlertsEnabled) return;

    // Si valuta al massimo ogni 3 secondi: il cooldown vero e' nel coach.
    final DateTime now = DateTime.now();
    final DateTime? last = _lastPaceCheck;
    if (last != null && now.difference(last).inSeconds < 3) return;
    _lastPaceCheck = now;

    unawaited(_coach.announcePaceStatus(status, now: now));
  }

  @override
  void dispose() {
    _stopTicker();
    unawaited(_gpsSub?.cancel());
    unawaited(_gpsErrorSub?.cancel());
    unawaited(_screen.setKeepScreenOn(false));
    super.dispose();
  }
}
