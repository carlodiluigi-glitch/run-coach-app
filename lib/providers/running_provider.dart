import 'dart:async';
import 'dart:collection';

import 'package:flutter/foundation.dart';

import '../models/lap.dart';
import '../models/run_checkpoint.dart';
import '../models/running_activity.dart';
import '../models/user_settings.dart';
import '../models/workout.dart';
import '../models/workout_step.dart';
import '../services/audio_coach_service.dart';
import '../services/gps_filter.dart';
import '../services/gps_service.dart';
import '../services/permission_service.dart';
import '../services/screen_service.dart';
import '../services/storage_service.dart';
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
    StorageService? storage,
  })  : _gps = gpsService,
        _permissions = permissionService,
        _coach = coach,
        _screen = screenService ?? ScreenService(),
        _storage = storage ?? StorageService();

  final GpsService _gps;
  final PermissionService _permissions;
  final AudioCoachService _coach;
  final ScreenService _screen;
  final StorageService _storage;

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

  /// Secondi gia' corsi prima di questa sessione del cronometro.
  ///
  /// Vale zero in una corsa normale. Dopo il recupero di una corsa interrotta
  /// contiene il tempo salvato nel checkpoint, cosi' il cronometro riparte da
  /// li' invece che da zero. Il tempo passato con l'app chiusa non viene
  /// conteggiato: non sappiamo se stavi correndo o eri fermo, e inventarlo
  /// sarebbe peggio che perderlo.
  int _baseSeconds = 0;

  /// Ogni quanti secondi si salva il checkpoint della corsa in corso.
  ///
  /// Compromesso fra quanto si perde in un crash e quanto si scrive su disco:
  /// il file contiene tutta la traccia, che su un'uscita lunga diventa grande.
  static const int _checkpointIntervalSeconds = 20;

  int _lastCheckpointSecond = -1000;
  bool _checkpointWriteInFlight = false;

  final List<Lap> _laps = <Lap>[];
  double _lapStartDistance = 0.0;
  int _lapStartSeconds = 0;

  /// Confine dello step corrente, in valori assoluti dall'inizio attivita'.
  ///
  /// PERCHE' SERVE: il motore comunica quanto e' durato lo step appena
  /// concluso, non dove cade il confine. Se durante una ripetuta l'utente
  /// preme LAP, parte di quello step e' gia' finita in un lap manuale: usare
  /// la misura piena dello step conterebbe quei metri due volte. Tenendo qui
  /// il confine assoluto, il lap di fine step vale sempre e solo il tratto
  /// non ancora registrato.
  double _stepBoundaryDistance = 0.0;
  int _stepBoundarySeconds = 0;

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
  int get elapsedSeconds => _baseSeconds + _stopwatch.elapsed.inSeconds;
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
    // La pausa e' un buon momento per fotografare: e' un cambio di stato che
    // vale la pena ritrovare intatto dopo un crash.
    unawaited(_saveCheckpoint());
    await _coach.speak(_coach.phrases.paused(), priority: SpeechPriority.high);
    notifyListeners();
  }

  Future<void> resume() async {
    if (_state != RunState.paused) return;
    _state = RunState.running;
    _stopwatch.start();
    _filter.dropReference();
    unawaited(_saveCheckpoint());
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
    //
    // La fase si allega solo se l'allenamento e' ancora in corso: dopo la fine
    // il motore continua a indicare l'ultimo step, e i metri corsi dopo il
    // termine finirebbero attribuiti a una fase gia' chiusa.
    if (currentLapDistance >= 10) {
      final WorkoutEngine? engine = _engine;
      final bool workoutRunning = engine != null && !engine.isFinished;
      _closeLap(
        manual: false,
        partial: true,
        step: workoutRunning ? currentStep : null,
      );
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

    // Ultimo checkpoint, marcato come in pausa.
    //
    // PERCHE' NON SI CANCELLA QUI: fra lo stop e il salvataggio l'utente sceglie
    // ancora le scarpe e conferma. Se l'app morisse in quel momento, cancellare
    // adesso significherebbe perdere una corsa gia' finita. Il file viene
    // eliminato in reset(), cioe' dopo che l'attivita' e' stata salvata o
    // scartata davvero.
    await _saveCheckpoint(asPaused: true);

    notifyListeners();
    return activity;
  }

  /// Riporta il provider allo stato iniziale (dopo il salvataggio o l'annullo).
  Future<void> reset() async {
    _stopTicker();
    await _stopGpsStream();
    await _screen.setKeepScreenOn(false);
    // La corsa e' stata salvata o scartata: il checkpoint non serve piu' e
    // lasciarlo la' farebbe riproporre al prossimo avvio una corsa gia' chiusa.
    await _storage.deleteCheckpoint();
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
  ///
  /// Resta disponibile anche durante un allenamento programmato: il lap viene
  /// marcato come frazione manuale e riporta la fase in cui e' stato chiuso,
  /// cosi' nello storico si distingue dai lap di fine step.
  void manualLap() {
    if (_state != RunState.running) return;
    if (currentLapDistance < 5) return;
    _closeLap(manual: true, step: currentStep);
    notifyListeners();
  }

  /// Salta la fase corrente dell'allenamento programmato.
  void skipStep() {
    final WorkoutEngine? engine = _engine;
    if (engine == null || !isActive) return;
    _handleEvents(engine.skipToNextStep());
    notifyListeners();
  }

  // -------------------------------------------------------------- checkpoint
  //
  // La corsa in corso viene fotografata su file ogni pochi secondi. Se l'app
  // muore - crash, batteria, sistema che libera memoria - al riavvio si puo'
  // riprendere invece di perdere tutto.
  //
  // Regola di fondo: il checkpoint non deve MAI disturbare la corsa. Ogni
  // errore di scrittura viene ignorato in silenzio, perche' fallire un
  // salvataggio e' un fastidio, mentre interrompere una registrazione in
  // corso e' un danno.

  void _maybeSaveCheckpoint() {
    if (!isActive) return;
    final int now = elapsedSeconds;
    if (now - _lastCheckpointSecond < _checkpointIntervalSeconds) return;
    _lastCheckpointSecond = now;
    unawaited(_saveCheckpoint());
  }

  Future<void> _saveCheckpoint({bool asPaused = false}) async {
    // Su una traccia lunga la scrittura non e' istantanea: se ne parte una
    // mentre la precedente e' ancora in corso si accumulano scritture inutili.
    if (_checkpointWriteInFlight) return;
    _checkpointWriteInFlight = true;
    try {
      await _storage.saveCheckpoint(_buildCheckpoint(asPaused: asPaused));
    } catch (_) {
      // Ignorato di proposito: vedi nota sopra.
    } finally {
      _checkpointWriteInFlight = false;
    }
  }

  RunCheckpoint _buildCheckpoint({bool asPaused = false}) {
    final WorkoutEngine? engine = _engine;
    return RunCheckpoint(
      savedAt: DateTime.now(),
      startTime: _startTime ?? DateTime.now(),
      elapsedSeconds: elapsedSeconds,
      distanceMeters: _distanceMeters,
      paused: asPaused || _state == RunState.paused,
      laps: List<Lap>.from(_laps),
      lapStartDistance: _lapStartDistance,
      lapStartSeconds: _lapStartSeconds,
      stepBoundaryDistance: _stepBoundaryDistance,
      stepBoundarySeconds: _stepBoundarySeconds,
      route: List<RoutePoint>.from(_route),
      workout: _workout,
      workoutStepIndex: engine?.currentIndex ?? 0,
      workoutStarted: engine?.isStarted ?? false,
      workoutFinished: engine?.isFinished ?? false,
      workoutStepStartDistance: _stepBoundaryDistance,
      workoutStepStartSeconds: _stepBoundarySeconds,
    );
  }

  /// Cerca una corsa interrotta che valga la pena riproporre.
  ///
  /// Un checkpoint troppo vecchio o troppo corto viene eliminato al volo:
  /// meglio non far nemmeno comparire la domanda.
  Future<RunCheckpoint?> loadRecoverableCheckpoint() async {
    if (isActive) return null;
    final RunCheckpoint? checkpoint = await _storage.loadCheckpoint();
    if (checkpoint == null) return null;
    if (!checkpoint.isRecoverable) {
      await _storage.deleteCheckpoint();
      return null;
    }
    return checkpoint;
  }

  /// Butta via la corsa interrotta.
  Future<void> discardCheckpoint() => _storage.deleteCheckpoint();

  /// Costruisce l'attivita' da una corsa interrotta, senza riprenderla.
  ///
  /// Serve a chi al riavvio sceglie "chiudi e salva": la corsa entra nello
  /// storico com'era al momento dell'ultimo salvataggio.
  RunningActivity activityFromCheckpoint(RunCheckpoint checkpoint) {
    final Workout? workout = checkpoint.workout;
    final bool isWorkout = workout != null && workout.expand().isNotEmpty;
    return RunningActivity(
      startTime: checkpoint.startTime,
      name: workout?.name ?? 'Corsa libera',
      type: isWorkout ? ActivityType.workout : ActivityType.free,
      durationSeconds: checkpoint.elapsedSeconds,
      distanceMeters: checkpoint.distanceMeters,
      laps: List<Lap>.from(checkpoint.laps),
      route: List<RoutePoint>.from(checkpoint.route),
      workoutId: workout?.id,
    );
  }

  /// Riprende una corsa interrotta e ricomincia a registrare.
  ///
  /// La corsa riparte nello stato in cui era: se il checkpoint era stato
  /// scritto in pausa, resta in pausa. Distanza e tempo trascorsi mentre
  /// l'app era chiusa sono persi e non c'e' modo di recuperarli.
  Future<bool> resumeFromCheckpoint(RunCheckpoint checkpoint) async {
    if (isActive) return false;

    final GpsAvailability availability = await _permissions.checkAndRequest();
    _gpsAvailability = availability;
    if (!availability.isReady) {
      notifyListeners();
      return false;
    }

    _resetInternals();

    final Workout? workout = checkpoint.workout;
    _workout = workout;
    if (workout != null && workout.expand().isNotEmpty) {
      final WorkoutEngine engine = WorkoutEngine(workout);
      engine.restoreState(
        stepIndex: checkpoint.workoutStepIndex,
        started: checkpoint.workoutStarted,
        finished: checkpoint.workoutFinished,
        stepStartDistance: checkpoint.workoutStepStartDistance,
        stepStartSeconds: checkpoint.workoutStepStartSeconds,
        totalDistance: checkpoint.distanceMeters,
        totalSeconds: checkpoint.elapsedSeconds,
      );
      _engine = engine;
    } else {
      _engine = null;
    }

    _startTime = checkpoint.startTime;
    _baseSeconds = checkpoint.elapsedSeconds;
    _distanceMeters = checkpoint.distanceMeters;
    _laps.addAll(checkpoint.laps);
    _lapStartDistance = checkpoint.lapStartDistance;
    _lapStartSeconds = checkpoint.lapStartSeconds;
    _stepBoundaryDistance = checkpoint.stepBoundaryDistance;
    _stepBoundarySeconds = checkpoint.stepBoundarySeconds;
    _route.addAll(checkpoint.route);
    _lastRoutePointSecond =
        _route.isEmpty ? -10 : _route.last.elapsedSeconds;

    _state = checkpoint.paused ? RunState.paused : RunState.running;
    _stopwatch.reset();
    if (_state == RunState.running) {
      _stopwatch.start();
    }

    await _startGpsStream();
    _startTicker();

    if (_settings.keepScreenOn) {
      await _screen.setKeepScreenOn(true);
    }

    _coach.resetPaceAlerts();
    await _coach.speak(
      _coach.phrases.resumed(),
      priority: SpeechPriority.high,
    );

    notifyListeners();
    return true;
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
    _stepBoundaryDistance = 0.0;
    _stepBoundarySeconds = 0;
    _route.clear();
    _lastRoutePointSecond = -10;
    _paceWindow.clear();
    _smoothedPaceSecPerKm = null;
    _paceStatus = PaceStatus.unknown;
    _lastPaceCheck = null;
    _startTime = null;
    _gpsError = null;
    _rawGpsSpeed = null;
    _baseSeconds = 0;
    _lastCheckpointSecond = -1000;
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
    _maybeSaveCheckpoint();

    notifyListeners();
  }

  /// Chiusura automatica del lap ogni [UserSettings.autoLapDistanceMeters].
  ///
  /// Attiva solo nella corsa libera. Durante un allenamento programmato i lap
  /// li chiudono le fasi: un chilometro automatico taglierebbe le ripetute a
  /// meta' e renderebbe la tabella dello storico illeggibile.
  void _checkAutoLap() {
    if (hasWorkout) return;
    if (!_settings.autoLapEnabled) return;
    final double lapDistance = _settings.autoLapDistanceMeters;
    if (lapDistance < 100) return;

    int safety = 0;
    while (currentLapDistance >= lapDistance && safety < 10) {
      safety++;
      _closeLap(manual: false, exactDistance: lapDistance);
    }
  }

  /// Chiude il lap corrispondente allo step appena concluso.
  ///
  /// Il lap copre il tratto che va dalla fine del lap precedente al confine
  /// dello step, quindi si incastra correttamente anche se nel frattempo
  /// l'utente ha premuto LAP a meta' ripetuta.
  void _closeLapForCompletedStep(WorkoutEvent event) {
    final ResolvedStep? completed = event.previousStep;
    if (completed == null) return;

    _stepBoundaryDistance += event.completedDistanceMeters ?? 0.0;
    _stepBoundarySeconds += event.completedSeconds ?? 0;

    double lapDistance = _stepBoundaryDistance - _lapStartDistance;
    int lapSeconds = _stepBoundarySeconds - _lapStartSeconds;
    if (lapDistance < 0) lapDistance = 0;
    if (lapSeconds < 0) lapSeconds = 0;

    // Puo' capitare che non resti nulla da registrare, ad esempio se il lap
    // manuale e' stato premuto un istante prima della fine della fase.
    if (lapDistance <= 0 && lapSeconds <= 0) return;

    _closeLap(
      manual: false,
      exactDistance: lapDistance,
      exactSeconds: lapSeconds,
      step: completed,
    );
  }

  /// Chiude il lap corrente.
  ///
  /// [exactDistance] ed [exactSeconds] permettono di chiudere il lap su un
  /// confine preciso (la distanza impostata, oppure la fine di uno step)
  /// invece che sui valori letti al momento del controllo: senza di questo i
  /// lap "slitterebbero" progressivamente rispetto al riferimento.
  ///
  /// [step] e' la fase a cui il lap appartiene: ne vengono salvati sia
  /// l'etichetta leggibile sia il tipo.
  void _closeLap({
    required bool manual,
    double? exactDistance,
    int? exactSeconds,
    bool partial = false,
    ResolvedStep? step,
  }) {
    final double lapDistance = exactDistance ?? currentLapDistance;
    final int lapSeconds = exactSeconds ?? currentLapSeconds;
    if (lapDistance <= 0 && lapSeconds <= 0) return;

    // Tempo totale al confine del lap. Coincide con il tempo attuale per i lap
    // manuali e automatici; per i lap di fine step puo' essere leggermente
    // indietro, perche' il confine cade sull'obiettivo della fase.
    final int totalSeconds = _lapStartSeconds + lapSeconds;

    _laps.add(Lap(
      number: _laps.length + 1,
      distanceMeters: lapDistance,
      durationSeconds: lapSeconds,
      totalTimeSeconds: totalSeconds,
      manual: manual,
      stepLabel: step?.label,
      stepType: step?.step.type,
    ));

    // L'avanzamento e' additivo su entrambi gli assi: il lap successivo parte
    // esattamente dove finisce questo, senza recuperare i valori correnti.
    _lapStartDistance += lapDistance;
    _lapStartSeconds += lapSeconds;

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
          // Il confine di partenza e' il punto in cui l'allenamento comincia.
          _stepBoundaryDistance = _distanceMeters;
          _stepBoundarySeconds = elapsedSeconds;
          break;
        case WorkoutEventType.stepStarted:
          _closeLapForCompletedStep(event);
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
          _closeLapForCompletedStep(event);
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
