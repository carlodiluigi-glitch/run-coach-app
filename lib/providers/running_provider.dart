import 'dart:async';
import 'dart:collection';

import 'package:flutter/foundation.dart';

import '../models/lap.dart';
import '../models/run_snapshot.dart';
import '../models/running_activity.dart';
import '../models/user_settings.dart';
import '../models/workout.dart';
import '../models/workout_step.dart';
import '../services/audio_coach_service.dart';
import '../services/cadence.dart';
import '../services/conto_giri.dart';
import '../services/gps_filter.dart';
import '../services/gps_service.dart';
import '../services/permission_service.dart';
import '../services/storage_service.dart';
import '../services/native_bridge.dart';
import '../services/workout_engine.dart';
import '../utils/formatters.dart';
import '../utils/speech_formatters.dart';

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
    NativeBridge? nativeBridge,
    StorageService? storage,
  })  : _gps = gpsService,
        _permissions = permissionService,
        _coach = coach,
        _native = nativeBridge ?? NativeBridge(),
        _storage = storage;

  final GpsService _gps;
  final PermissionService _permissions;
  final AudioCoachService _coach;
  final NativeBridge _native;

  /// Dove si scrive la corsa mentre la si registra. `null` nei test che non
  /// hanno bisogno del disco.
  final StorageService? _storage;

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

  /// Dove e' arrivato il giro in corso. Vedi [ContoGiri]: ci sta una classe
  /// intera perche' queste due cifre, quando erano variabili sciolte qui
  /// dentro, sono state perse in un rimpasto e hanno prodotto dieci giri
  /// identici nella stessa corsa.
  final ContoGiri _giri = ContoGiri();

  final List<RoutePoint> _route = <RoutePoint>[];
  int _lastRoutePointSecond = -10;

  // ------------------------------------------------------------- i passi
  //
  // La cadenza arriva dal sensore di passo del telefono, non dal GPS. Il
  // conteggio lo tiene Android: qui si legge e ogni tanto si annota.
  //
  // PERCHE' IL VALORE VIENE TENUTO DA PARTE E NON LETTO AL MOMENTO
  // -------------------------------------------------------------
  // Perche' leggerlo e' una chiamata al codice nativo, cioe' una cosa che si
  // aspetta. Il punto del tracciato invece si scrive dentro l'arrivo di un
  // campione GPS, dove non si puo' aspettare niente senza rischiare di
  // perdere il campione dopo. Quindi il ticker legge e mette qui l'ultimo
  // valore, e il punto prende quello che trova: al massimo e' vecchio di un
  // secondo, e su un totale cumulativo un secondo non cambia la cadenza.
  bool _stepsOn = false;
  int? _stepsNow;

  /// I passi contati quando e' cominciato il giro in corso: la cadenza del
  /// giro e' la differenza con quelli di adesso.
  int? _lapStartSteps;
  int _lastStepsReadSecond = -10;
  bool _readingSteps = false;

  // ----------------------------------------------- la corsa non si perde
  /// Ogni quanti secondi la corsa viene scritta su disco.
  ///
  /// Quindici secondi e' il compromesso: nel peggiore dei casi si perdono
  /// quindici secondi di corsa, e il telefono scrive un file ogni quindici
  /// secondi invece che continuamente.
  static const int snapshotEverySeconds = 15;

  /// Dopo quanti secondi senza un punto GPS si considera che il telefono
  /// abbia sospeso la registrazione.
  ///
  /// Trenta secondi: sotto e' un semaforo o un sottopasso, sopra e' Android
  /// che ha messo l'app a dormire.
  static const int gpsStallSeconds = 30;

  int _lastSnapshotSecond = -999;
  bool _snapshotInFlight = false;

  /// Da quando il GPS ha smesso di mandare punti, se e' successo.
  DateTime? _stalledSince;

  /// Secondi totali in cui, durante questa corsa, non e' arrivato niente.
  int _lostSeconds = 0;
  bool _warnedAboutStall = false;

  /// Finestra scorrevole usata per il passo attuale (ultimi ~20 secondi).
  final Queue<_PaceSample> _paceWindow = Queue<_PaceSample>();
  static const double _paceWindowSeconds = 20.0;

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

  // ------------------------------------------------------- prova in auto
  //
  // Spegne il tetto di velocita' del filtro, cosi' la misura della distanza si
  // puo' verificare su un tragitto noto in macchina invece di aspettare una
  // corsa. Non si salva da nessuna parte: alla chiusura dell'app torna spenta
  // da sola, che e' giusto - una modalita' di prova lasciata accesa per sbaglio
  // falserebbe una corsa vera senza dire niente.
  //
  // ATTENZIONE A COSA MISURA DAVVERO
  // --------------------------------
  // Sopra i 29 km/h il filtro smette comunque di fidarsi della velocita' del
  // chip e torna alle posizioni. Quindi un giro in macchina mette alla prova
  // la strada di ripiego, non quella usata quando si corre.
  bool get provaInAuto => _filter.senzaLimiteVelocita;

  /// Accende o spegne la prova in auto.
  void impostaProvaInAuto(bool attiva) {
    if (_filter.senzaLimiteVelocita == attiva) return;
    _filter.senzaLimiteVelocita = attiva;
    notifyListeners();
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
    return _giri.metriDelGiro(_distanceMeters);
  }

  /// Tempo del lap in corso.
  int get currentLapSeconds {
    return _giri.secondiDelGiro(elapsedSeconds);
  }

  /// Passo medio dell'attivita' in secondi per chilometro.
  double? get averagePaceSecPerKm =>
      paceFromDistanceAndTime(_distanceMeters, elapsedSeconds);

  /// Passo attuale calcolato sulla finestra scorrevole degli ultimi secondi.
  ///
  /// Usare la finestra invece dell'ultimo singolo punto rende il valore molto
  /// piu' stabile e leggibile mentre si corre.
  double? get currentPaceSecPerKm {
    if (_paceWindow.length < 2) return null;
    final _PaceSample first = _paceWindow.first;
    final _PaceSample last = _paceWindow.last;
    final double deltaTime = last.elapsedSeconds - first.elapsedSeconds;
    final double deltaDistance = last.distanceMeters - first.distanceMeters;
    if (deltaTime < 5.0 || deltaDistance < 10.0) return null;
    final double pace = deltaTime / (deltaDistance / 1000.0);
    if (pace <= 0 || pace > 3599) return null;
    return pace;
  }

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

  /// `true` se la registrazione sta usando il foreground service e quindi
  /// prosegue anche con lo schermo spento.
  bool get isBackgroundTracking => _gps.isBackgroundActive;

  /// `true` se l'utente ha chiesto la registrazione in background.
  bool get backgroundTrackingRequested => _settings.backgroundTrackingEnabled;

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

      // Il permesso per il sensore dei passi si chiede QUI, mentre si aspetta
      // il segnale, e non allo START.
      //
      // PERCHE' IL MOMENTO CONTA
      // -----------------------
      // Perche' una finestra di sistema che compare nell'istante in cui si
      // schiaccia START arriva sopra una corsa gia' partita: la si chiude di
      // fretta, senza leggerla, e spesso la si chiude col "no". Qui invece
      // l'utente sta fermo ad aspettare i satelliti, e ha il tempo di
      // guardarla.
      //
      // Non si aspetta la risposta e non cambia niente se e' no: la cadenza e'
      // un dato in piu', non una condizione per correre.
      if (request) unawaited(_native.requestStepPermission());
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

    // Da Android 13 la notifica della registrazione richiede il consenso.
    // Si chiede PRIMA di avviare il servizio; se l'utente rifiuta la corsa
    // viene registrata ugualmente, solo senza notifica visibile.
    if (_settings.backgroundTrackingEnabled) {
      await _native.requestNotificationPermission();
    }

    // La cadenza: si comincia a contare i passi da adesso. Il permesso e' gia'
    // stato chiesto aprendo la schermata (vedi `prepare`); se e' stato negato,
    // o il telefono non ha il sensore, qui esce `false` e la corsa va avanti
    // identica, solo senza cadenza.
    _stepsOn = await _native.startStepCounter();
    _stepsNow = _stepsOn ? 0 : null;
    _lapStartSteps = _stepsNow;

    _startTime = DateTime.now();
    _state = RunState.running;
    _stopwatch
      ..reset()
      ..start();

    // Lo stream passa dalla modalita' anteprima a quella di registrazione:
    // con background attivo parte il foreground service con la notifica
    // permanente, che tiene vivo il processo a schermo spento.
    await _startGpsStream(background: _settings.backgroundTrackingEnabled);
    _startTicker();

    if (_settings.keepScreenOn) {
      await _native.setKeepScreenOn(true);
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
    await _native.setKeepScreenOn(false);
    await _stopSteps();

    // Chiude l'ultimo spezzone rimasto, ma solo se vale davvero qualcosa.
    //
    // Fermandosi subito dopo una ripetuta restano quasi sempre pochi metri e
    // pochi secondi: salvarli produce un parziale tipo "10 m in 6 secondi"
    // che sporca l'elenco e non dice niente. E comunque non e' una fase
    // dell'allenamento, quindi non ne prende l'etichetta: e' solo la coda
    // della corsa.
    if (currentLapDistance >= 100 || currentLapSeconds >= 30) {
      _closeLap(
        manual: false,
        announce: false,
        stepLabel: _finalLapLabel(),
        stepKind: _finalLapKind(),
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
    notifyListeners();
    return activity;
  }

  /// Riporta il provider allo stato iniziale (dopo il salvataggio o l'annullo).
  Future<void> reset() async {
    _stopTicker();
    await _stopGpsStream();
    await _native.setKeepScreenOn(false);
    await _stopSteps();
    // La corsa e' stata salvata o buttata: il file di recupero non serve piu'.
    await _storage?.clearRunSnapshot();
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
    _closeLap(
      manual: true,
      stepLabel: currentStep?.label,
      stepKind: currentStep?.step.type.storageKey,
    );
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
  /// Stacca l'ascoltatore del sensore di passo.
  ///
  /// Un sensore lasciato in ascolto a corsa finita continua a consumare
  /// batteria con l'app chiusa - cioe' esattamente il difetto per cui questa
  /// app ha una schermata intera dedicata al risparmio energetico.
  Future<void> _stopSteps() async {
    if (!_stepsOn) return;
    _stepsOn = false;
    await _native.stopStepCounter();
  }

  void _resetInternals() {
    _filter.reset();
    _stopwatch
      ..stop()
      ..reset();
    _distanceMeters = 0.0;
    _laps.clear();
    _giri.azzera();
    _route.clear();
    _lastRoutePointSecond = -10;
    _paceWindow.clear();
    _paceStatus = PaceStatus.unknown;
    _lastPaceCheck = null;
    _startTime = null;
    _gpsError = null;
    _rawGpsSpeed = null;
    _lastSnapshotSecond = -999;
    _stalledSince = null;
    _lostSeconds = 0;
    _warnedAboutStall = false;
    _stepsNow = null;
    _lapStartSteps = null;
    _lastStepsReadSecond = -10;
  }

  Future<void> _startGpsStream({bool background = false}) async {
    // Se lo stream e' gia' attivo nella modalita' giusta non si tocca nulla.
    if (_gpsSub != null && _gps.isBackgroundActive == background) return;
    // Cambio di modalita' (anteprima -> registrazione): si riavvia.
    if (_gpsSub != null) {
      await _stopGpsStream();
    }
    try {
      await _gps.start(
        background: background,
        notificationTitle: 'Falcata',
        notificationText: hasWorkout
            ? 'Allenamento in corso'
            : 'Registrazione della corsa in corso',
      );
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

    // La velocita' del chip e' il dato che misura davvero la distanza: la
    // posizione serve solo a disegnare il percorso e come ripiego. Prima
    // veniva letta e buttata via, e la distanza usciva dalle posizioni - con
    // errori fino al 70% su una corsa intera.
    final GpsFilterResult result = _filter.process(
      latitude: sample.latitude,
      longitude: sample.longitude,
      accuracy: sample.accuracy,
      timestamp: sample.timestamp,
      speed: sample.speed,
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
        // La velocita' del chip viaggia con il punto: a corsa finita e' quella
        // che dice quanto si stava andando forte, non la distanza fra due
        // posizioni rumorose.
        speed: sample.speed,
        // I passi fatti fin qui. Cumulativi: la cadenza di un tratto e' la
        // differenza fra due punti, divisa per il tempo.
        steps: _stepsOn ? _stepsNow : null,
      ));
    }

    _pushPaceSample();
  }

  /// Legge il contapassi, una volta al secondo e non di piu'.
  ///
  /// Non aspetta la risposta: se il codice nativo e' lento, il cronometro non
  /// deve rallentare. E se una lettura e' ancora in volo si salta il giro,
  /// altrimenti su un telefono impallato le chiamate si accumulerebbero.
  void _readSteps() {
    if (!_stepsOn || _readingSteps) return;
    final int seconds = elapsedSeconds;
    if (seconds - _lastStepsReadSecond < 1) return;
    _lastStepsReadSecond = seconds;
    _readingSteps = true;
    unawaited(_native.stepCount().then((int? passi) {
      _readingSteps = false;
      // Un valore nullo non azzera quello buono di prima: "non lo so adesso"
      // non e' "sono tornato a zero passi".
      if (passi != null) _stepsNow = passi;
    }, onError: (Object _) {
      _readingSteps = false;
    }));
  }

  void _pushPaceSample() {
    final double now = _stopwatch.elapsedMilliseconds / 1000.0;
    _paceWindow.add(_PaceSample(now, _distanceMeters));
    while (_paceWindow.length > 2 &&
        now - _paceWindow.first.elapsedSeconds > _paceWindowSeconds) {
      _paceWindow.removeFirst();
    }
  }

  void _onTick() {
    if (_state != RunState.running) return;

    _pushPaceSample();
    _readSteps();
    _checkAutoLap();
    _updateWorkout();
    _checkPaceAlerts();
    _checkGpsStall();
    _maybeSaveSnapshot();

    notifyListeners();
  }

  // ------------------------------------------- la corsa non si perde
  /// Scrive la corsa su disco ogni [snapshotEverySeconds].
  ///
  /// Non aspetta la fine della scrittura: se il disco e' lento, il
  /// cronometro non deve rallentare. Se una scrittura e' ancora in corso si
  /// salta il giro - il prossimo passa fra quindici secondi.
  void _maybeSaveSnapshot() {
    final StorageService? storage = _storage;
    if (storage == null || _snapshotInFlight) return;

    final int secondi = elapsedSeconds;
    if (secondi - _lastSnapshotSecond < snapshotEverySeconds) return;
    _lastSnapshotSecond = secondi;
    _snapshotInFlight = true;

    storage
        .saveRunSnapshot(buildSnapshot())
        .whenComplete(() => _snapshotInFlight = false);
  }

  /// La fotografia della corsa in questo istante.
  RunSnapshot buildSnapshot() => RunSnapshot(
        startTime: _startTime ?? DateTime.now(),
        savedAt: DateTime.now(),
        elapsedSeconds: elapsedSeconds,
        distanceMeters: _distanceMeters,
        name: _workout?.name ?? 'Corsa libera',
        type: _workout == null ? ActivityType.free : ActivityType.workout,
        laps: List<Lap>.from(_laps),
        route: List<RoutePoint>.from(_route),
        workoutId: _workout?.id,
      );

  /// Si accorge quando il telefono smette di mandare punti.
  ///
  /// PERCHE' DIRLO SUBITO
  /// --------------------
  /// Se Android sospende l'app, l'utente se ne accorge a fine corsa: sei km
  /// diventati tre, e non c'e' piu' niente da fare. Detto mentre succede,
  /// invece, si puo' rimediare - riaprire l'app, togliere il risparmio
  /// energetico - e almeno si sa che quel numero non e' da credere.
  void _checkGpsStall() {
    final DateTime? ultimo = _lastFixAt;
    if (ultimo == null) return;

    final int fermo = DateTime.now().difference(ultimo).inSeconds;

    if (fermo >= gpsStallSeconds) {
      _stalledSince ??= ultimo;
      if (!_warnedAboutStall) {
        _warnedAboutStall = true;
        _coach.speak(
          'Attenzione: il telefono ha smesso di mandare la posizione.',
          priority: SpeechPriority.high,
        );
      }
      return;
    }

    // Il segnale e' tornato: si conta il buco e si riparte.
    final DateTime? inizio = _stalledSince;
    if (inizio != null) {
      _lostSeconds += DateTime.now().difference(inizio).inSeconds;
      _stalledSince = null;
      _warnedAboutStall = false;
    }
  }

  /// `true` mentre il telefono non sta mandando posizioni.
  bool get isGpsStalled => _stalledSince != null;

  /// Da quanti secondi il GPS e' fermo adesso.
  int get stalledSeconds {
    final DateTime? inizio = _stalledSince;
    if (inizio == null) return 0;
    return DateTime.now().difference(inizio).inSeconds;
  }

  /// Secondi persi in tutto durante questa corsa.
  int get lostSeconds =>
      _lostSeconds + (isGpsStalled ? stalledSeconds : 0);

  /// `true` mentre un allenamento programmato e' effettivamente in esecuzione.
  bool get _workoutInProgress {
    final WorkoutEngine? engine = _engine;
    return engine != null &&
        !engine.isEmpty &&
        engine.isStarted &&
        !engine.isFinished;
  }

  void _checkAutoLap() {
    // Durante un allenamento programmato i parziali seguono le fasi, non i
    // chilometri: mischiare i due criteri produrrebbe giri a cavallo fra una
    // ripetuta e il recupero, cioe' numeri senza significato.
    if (_workoutInProgress) return;

    if (!_settings.autoLapEnabled) return;
    final double lapDistance = _settings.autoLapDistanceMeters;
    if (lapDistance < 100) return;

    // IL CICLO SI FERMA SE IL RIFERIMENTO NON SI MUOVE.
    //
    // Il ciclo serve a un caso solo: un salto di distanza che copre piu' di un
    // chilometro in un colpo (un buco di segnale lungo). Ma un ciclo che
    // dipende da un effetto collaterale e' pericoloso - se quell'effetto
    // sparisce, gira a vuoto e sforna giri finti finche' non sbatte contro il
    // limite. E' esattamente quello che e' successo. Adesso la condizione di
    // uscita non e' solo "ho fatto abbastanza giri": e' "il riferimento e'
    // avanzato", cioe' la cosa che deve succedere perche' il ciclo abbia senso.
    int safety = 0;
    while (currentLapDistance >= lapDistance && safety < 10) {
      safety++;
      final double primaDiChiudere = _giri.metriChiusi;
      // Il lap automatico a distanza esiste solo nella corsa libera, dove non
      // c'e' nessuna fase da scrivere.
      _closeLap(manual: false, stepLabel: null, exactDistance: lapDistance);
      if (_giri.metriChiusi <= primaDiChiudere) break;
    }
  }

  /// Etichetta da dare allo spezzone finale, quello chiuso premendo Termina.
  ///
  /// Se l'allenamento e' finito lo spezzone non appartiene a nessuna fase:
  /// sono i metri fatti dopo, e non deve chiamarsi "Ripetuta". Se invece ci si
  /// ferma a meta' di una fase, quello e' un pezzo di quella fase.
  /// Tipo della fase in corso alla chiusura, in forma non traducibile.
  String? _finalLapKind() {
    final WorkoutEngine? engine = _engine;
    if (engine == null || engine.isEmpty || engine.isFinished) return null;
    return currentStep?.step.type.storageKey;
  }

  String? _finalLapLabel() {
    final WorkoutEngine? engine = _engine;
    if (engine == null || engine.isEmpty || engine.isFinished) return null;
    return currentStep?.label;
  }

  /// Chiude un parziale alla fine di una fase dell'allenamento programmato.
  ///
  /// E' cosi' che le ripetute finiscono nello storico: senza questo un
  /// `10 x 400 m` non lasciava nessun parziale, perche' il lap automatico
  /// scatta solo ogni chilometro e le fasi sono piu' corte.
  void _closeStepLap(ResolvedStep? completed) {
    if (completed == null) return;
    // Una fase saltata all'istante non deve produrre un giro vuoto.
    if (currentLapDistance < 1 && currentLapSeconds < 1) return;

    final Lap? lap = _closeLap(
      manual: false,
      announce: false,
      stepLabel: completed.label,
      stepKind: completed.step.type.storageKey,
    );
    if (lap == null) return;

    // Il tempo del recupero non si annuncia: subito dopo arriva la voce della
    // fase nuova e due frasi di fila si accavallano proprio quando serve
    // ripartire. Il parziale resta comunque salvato.
    if (completed.step.type == StepType.recovery) return;
    if (lap.durationSeconds < 10) return;

    unawaited(_coach.speak(
      _coach.phrases.stepCompleted(
        stepLabel: completed.label,
        distanceLabel: spokenDistance(lap.distanceMeters),
        timeLabel: spokenDuration(lap.durationSeconds),
        paceLabel: spokenPace(lap.paceSecondsPerKm),
      ),
    ));
  }

  /// Chiude il lap corrente e restituisce il lap creato.
  ///
  /// [exactDistance] permette di chiudere il lap esattamente sulla distanza
  /// impostata (es. 1000 m) invece che sulla distanza percorsa al momento del
  /// controllo, evitando che i lap "slittino" progressivamente.
  ///
  /// [stepLabel] e' l'etichetta della fase, e va sempre passata dal chiamante.
  /// Non viene dedotta da `currentStep` perche' alla fine di uno step il
  /// motore e' gia' passato al successivo: leggendola qui si scriverebbe la
  /// fase sbagliata. Chi chiude un giro senza fase passa `null`.
  Lap? _closeLap({
    required bool manual,
    required String? stepLabel,
    String? stepKind,
    double? exactDistance,
    bool announce = true,
  }) {
    final double lapDistance = exactDistance ?? currentLapDistance;
    // Un parziale a distanza zero ha senso solo per le fasi a tempo (es. un
    // riscaldamento fermi sul posto): quello che conta li' e' il tempo.
    if (lapDistance < 0) return null;

    final int lapSeconds = currentLapSeconds;
    final int totalSeconds = elapsedSeconds;

    final Lap lap = Lap(
      number: _laps.length + 1,
      distanceMeters: lapDistance,
      durationSeconds: lapSeconds,
      totalTimeSeconds: totalSeconds,
      manual: manual,
      stepLabel: stepLabel,
      stepKind: stepKind,
    );
    // Il giro precedente va preso PRIMA di aggiungere questo, se no il
    // confronto sarebbe fra il giro e se stesso.
    final Lap? precedente = _laps.isEmpty ? null : _laps.last;
    _laps.add(lap);

    // SPOSTARE IL RIFERIMENTO E' LA PARTE CHE NON SI PUO' DIMENTICARE.
    //
    // Senza, i metri del giro restano sopra il chilometro e il giro automatico
    // ne chiude uno dietro l'altro fino al limite di sicurezza, tutti con lo
    // stesso tempo. E' successo davvero: vedi [ContoGiri].
    _giri.chiudi(metri: lapDistance, secondiTotali: totalSeconds);

    // La cadenza del giro: i passi di adesso meno quelli di quando il giro e'
    // cominciato. Si aggiorna il riferimento comunque, anche quando la cadenza
    // non si puo' dire, se no il giro dopo userebbe un riferimento vecchio e
    // la cadenza uscirebbe gonfiata.
    final int? passiGiro =
        (_stepsNow != null && _lapStartSteps != null && _stepsNow! >= _lapStartSteps!)
            ? _stepsNow! - _lapStartSteps!
            : null;
    _lapStartSteps = _stepsNow;

    if (announce) {
      unawaited(_coach.speak(_annuncioGiro(lap, precedente, passiGiro)));
    }

    return lap;
  }

  /// Compone l'annuncio vocale di fine giro, secondo quanto l'utente vuole
  /// sentire.
  ///
  /// I numeri vanno passati in forma pronunciabile: "cinque e ventitre" si
  /// capisce correndo, "5:23" viene letto male dalla sintesi vocale.
  String _annuncioGiro(Lap lap, Lap? precedente, int? passiGiro) {
    final SpokenDetail quanto = _coach.detail;
    final bool essenziale = quanto == SpokenDetail.essenziale;
    final bool tutto = quanto == SpokenDetail.tutto;

    // Il giro e' "standard" quando dura esattamente la distanza impostata per
    // il lap automatico: li' il tempo del giro E' il passo, e ripeterlo
    // sarebbe dire due volte lo stesso numero.
    final double attesa = _settings.autoLapDistanceMeters;
    final bool standard =
        !lap.manual && (lap.distanceMeters - attesa).abs() < attesa * 0.02;

    // Il confronto col giro prima ha senso solo fra giri confrontabili: due
    // parziali di lunghezza diversa non si confrontano al secondo.
    double? scarto;
    if (!essenziale && precedente != null) {
      final double? adesso = lap.paceSecondsPerKm;
      final double? prima = precedente.paceSecondsPerKm;
      final bool stessaLunghezza = (lap.distanceMeters -
                  precedente.distanceMeters)
              .abs() <
          lap.distanceMeters * 0.1;
      if (adesso != null && prima != null && stessaLunghezza) {
        scarto = adesso - prima;
      }
    }

    return _coach.phrases.lapFull(
      lapNumber: lap.number,
      distanceLabel: spokenDistance(lap.distanceMeters),
      timeLabel: spokenDuration(lap.durationSeconds),
      standardLength: standard,
      paceLabel: spokenPace(lap.paceSecondsPerKm),
      deltaSeconds: scarto,
      totalDistanceLabel:
          essenziale ? null : spokenDistance(_distanceMeters),
      totalTimeLabel: essenziale ? null : spokenDuration(lap.totalTimeSeconds),
      cadence: tutto && passiGiro != null
          ? Cadence.spm(
              steps: passiGiro,
              seconds: lap.durationSeconds.toDouble(),
            )?.round()
          : null,
      remainingLabel: tutto ? _quantoManca() : null,
    );
  }

  /// Quanto manca alla fine della **fase in corso** di un allenamento
  /// programmato.
  ///
  /// PERCHE' LA FASE E NON TUTTO L'ALLENAMENTO
  /// -----------------------------------------
  /// Perche' la fase e' quello che stai facendo adesso, e sapere che mancano
  /// trecento metri alla fine della ripetuta cambia come li corri. Quanto
  /// manca alla fine di tutta la seduta non cambia niente nel momento.
  ///
  /// La frase dice "a fine fase" per non lasciare dubbi: durante un lento da
  /// cinquanta minuti, un "mancano venti minuti" senza il resto della frase
  /// si capirebbe al contrario.
  ///
  /// `null` nella corsa libera: li' non c'e' una fine da raggiungere, e dire
  /// "mancano zero chilometri" sarebbe peggio di non dire niente.
  String? _quantoManca() {
    final WorkoutEngine? engine = _engine;
    if (engine == null) return null;
    final double? metri = engine.remainingMeters;
    if (metri != null && metri > 50) {
      return 'A fine fase mancano ${spokenDistance(metri)}.';
    }
    final int? secondi = engine.remainingSeconds;
    if (secondi != null && secondi > 30) {
      return 'A fine fase mancano ${spokenDuration(secondi)}.';
    }
    return null;
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
          // Prima di annunciare la fase nuova si chiude il parziale di quella
          // appena finita: e' il parziale della ripetuta.
          _closeStepLap(event.previousStep);
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
          // Anche l'ultima fase lascia il suo parziale.
          _closeStepLap(event.previousStep);
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
    unawaited(_native.setKeepScreenOn(false));
    unawaited(_stopSteps());
    super.dispose();
  }
}
