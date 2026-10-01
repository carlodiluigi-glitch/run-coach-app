import 'package:flutter/foundation.dart';

import '../models/athlete_profile.dart';
import '../models/daily_checkin.dart';
import '../models/run_snapshot.dart';
import '../models/running_activity.dart';
import '../services/pace_zone_engine.dart';
import '../services/readiness_engine.dart';
import '../services/session_classifier.dart';
import '../services/training_load_engine.dart';
import '../services/records_service.dart';
import '../services/run_index_engine.dart';
import '../services/stats_service.dart';
import '../services/storage_service.dart';
import 'shoe_provider.dart';

/// Storico delle attivita' salvate.
/// Il motore adattivo vive qui perche' qui ci sono gia' lo storico, le zone e
/// la cache: aggiungere un provider solo per il carico vorrebbe dire ricalcolare
/// le stesse cose in due posti e tenerle allineate a mano.
class ActivityProvider extends ChangeNotifier {
  ActivityProvider({
    required StorageService storage,
    required ShoeProvider shoeProvider,
  })  : _storage = storage,
        _shoes = shoeProvider;

  final StorageService _storage;
  final ShoeProvider _shoes;
  final StatsService _stats = const StatsService();
  final RecordsService _recordsService = const RecordsService();

  /// I record si calcolano scorrendo tutti i tracciati: e' un lavoro lineare
  /// ma inutile da rifare a ogni ridisegno, quindi il risultato viene tenuto
  /// da parte e buttato via solo quando lo storico cambia.
  PersonalRecords? _recordsCache;

  // Il motore di forma gira su tutto lo storico: si calcola una volta e si
  // tiene finche' non cambia niente, come per i record.
  static const RunIndexEngine _runIndexEngine = RunIndexEngine();
  static const PaceZoneEngine _paceZoneEngine = PaceZoneEngine();
  RunIndexResult? _runIndexCache;
  TrainingZones? _zonesCache;
  AthleteProfile _athleteProfile = const AthleteProfile();

  static const TrainingLoadEngine _loadEngine = TrainingLoadEngine();
  static const ReadinessEngine _readinessEngine = ReadinessEngine();
  static const SessionClassifier _classifier = SessionClassifier();
  TrainingLoadState? _loadCache;
  Readiness? _readinessCache;

  List<DailyCheckIn> _checkIns = <DailyCheckIn>[];

  List<RunningActivity> _activities = <RunningActivity>[];
  bool _loaded = false;
  String? _errorMessage;

  List<RunningActivity> get activities =>
      List<RunningActivity>.unmodifiable(_activities);
  bool get isLoaded => _loaded;
  bool get isEmpty => _activities.isEmpty;
  String? get errorMessage => _errorMessage;

  RunningActivity? get lastActivity =>
      _activities.isEmpty ? null : _activities.first;

  /// Una corsa interrotta trovata su disco all'avvio, in attesa di risposta.
  ///
  /// Non viene salvata da sola: l'atleta deve poterla guardare e decidere.
  /// Salvare a sua insaputa una corsa che magari era un avvio per sbaglio
  /// significherebbe sporcargli l'archivio, e l'archivio e' la base di ogni
  /// stima che l'app fa.
  RunSnapshot? _pendingRecovery;

  RunSnapshot? get pendingRecovery => _pendingRecovery;

  /// Salva in archivio la corsa recuperata.
  Future<bool> keepRecovered() async {
    final RunSnapshot? snapshot = _pendingRecovery;
    if (snapshot == null) return false;
    _pendingRecovery = null;
    final bool ok = await add(snapshot.toActivity());
    await _storage.clearRunSnapshot();
    return ok;
  }

  /// Butta via la corsa recuperata.
  Future<void> discardRecovered() async {
    _pendingRecovery = null;
    await _storage.clearRunSnapshot();
    notifyListeners();
  }

  Future<void> load() async {
    _activities = await _storage.loadActivities();

    // Se l'app e' stata uccisa mentre si correva, qui c'e' la corsa.
    final RunSnapshot? interrotta = await _storage.loadRunSnapshot();
    if (interrotta != null && interrotta.isWorthRecovering) {
      _pendingRecovery = interrotta;
    } else if (interrotta != null) {
      // Troppo corta per essere una corsa: si butta senza disturbare.
      await _storage.clearRunSnapshot();
    }
    _athleteProfile = await _storage.loadAthleteProfile();
    _checkIns = await _storage.loadCheckIns();
    _recordsCache = null;
    _runIndexCache = null;
    _loadCache = null;
    _readinessCache = null;
    _zonesCache = null;
    _loaded = true;
    _errorMessage = _storage.lastError;
    notifyListeners();
  }

  RunningActivity? byId(String id) {
    for (final RunningActivity a in _activities) {
      if (a.id == id) return a;
    }
    return null;
  }

  /// Salva una nuova attivita' e aggiorna i km della scarpa selezionata.
  Future<bool> add(RunningActivity activity) async {
    _activities = <RunningActivity>[activity, ..._activities];
    _recordsCache = null;
    _runIndexCache = null;
    _loadCache = null;
    _readinessCache = null;
    _zonesCache = null;
    _sort();
    notifyListeners();

    final String? shoeId = activity.shoeId;
    if (shoeId != null) {
      await _shoes.addActivityDistance(
        shoeId: shoeId,
        meters: activity.distanceMeters,
        when: activity.startTime,
      );
    }

    return _persist();
  }

  /// Aggiorna una attivita' esistente, correggendo i km delle scarpe.
  Future<bool> update(RunningActivity activity) async {
    final RunningActivity? previous = byId(activity.id);
    final List<RunningActivity> next = _activities
        .map((RunningActivity a) => a.id == activity.id ? activity : a)
        .toList();
    _activities = next;
    _recordsCache = null;
    _runIndexCache = null;
    _loadCache = null;
    _readinessCache = null;
    _zonesCache = null;
    _sort();
    notifyListeners();

    final String? oldShoe = previous?.shoeId;
    final String? newShoe = activity.shoeId;
    if (oldShoe != newShoe) {
      if (oldShoe != null) {
        await _shoes.removeActivityDistance(
          shoeId: oldShoe,
          meters: previous?.distanceMeters ?? 0,
        );
      }
      if (newShoe != null) {
        await _shoes.addActivityDistance(
          shoeId: newShoe,
          meters: activity.distanceMeters,
          when: activity.startTime,
        );
      }
    }

    return _persist();
  }

  Future<bool> remove(String id) async {
    final RunningActivity? activity = byId(id);
    _activities = _activities.where((RunningActivity a) => a.id != id).toList();
    _recordsCache = null;
    _runIndexCache = null;
    _loadCache = null;
    _readinessCache = null;
    _zonesCache = null;
    notifyListeners();

    final String? shoeId = activity?.shoeId;
    if (shoeId != null) {
      await _shoes.removeActivityDistance(
        shoeId: shoeId,
        meters: activity?.distanceMeters ?? 0,
      );
    }

    return _persist();
  }

  /// Statistiche calcolate sullo storico corrente.
  RunningStats get stats => _stats.compute(_activities);

  /// Record personali (miglior tempo su ogni distanza classica, corsa piu'
  /// lunga, settimana migliore).
  PersonalRecords get records =>
      _recordsCache ??= _recordsService.compute(_activities);

  /// Distanze per cui una determinata attivita' detiene il record attuale.
  ///
  /// Si appoggia ai record gia' calcolati, quindi e' immediato: non rilegge i
  /// tracciati.
  /// Profilo dell'atleta, usato dal motore di forma per i personali
  /// dichiarati a mano.
  AthleteProfile get athleteProfile => _athleteProfile;

  /// Sostituisce il profilo e lo salva su disco.
  ///
  /// L'indice di forma viene buttato via: un personale dichiarato cambia la
  /// stima subito, senza aspettare la prossima corsa. E' il motivo per cui
  /// questa schermata esiste.
  Future<bool> updateAthleteProfile(AthleteProfile profile) async {
    _athleteProfile = profile;
    _runIndexCache = null;
    _loadCache = null;
    _readinessCache = null;
    _zonesCache = null;
    notifyListeners();

    final bool ok = await _storage.saveAthleteProfile(profile);
    if (!ok) {
      _errorMessage = _storage.lastError;
      notifyListeners();
    }
    return ok;
  }

  /// Indice di forma calcolato sullo storico piu' i personali dichiarati.
  RunIndexResult get runIndex {
    final RunIndexResult? cached = _runIndexCache;
    if (cached != null) return cached;

    final List<PerformanceSample> samples = <PerformanceSample>[
      ..._runIndexEngine.samplesFromActivities(_activities),
      ..._runIndexEngine.samplesFromProfile(_athleteProfile),
    ];
    return _runIndexCache = _runIndexEngine.estimate(samples);
  }

  /// Zone di allenamento ricavate dall'indice. `null` se non stimabile.
  TrainingZones? get trainingZones =>
      _zonesCache ??= _paceZoneEngine.zonesFor(runIndex.index);

  // ------------------------------------------------------ motore adattivo
  /// Carico, fatica e condizione di oggi.
  TrainingLoadState get trainingLoad =>
      _loadCache ??= _loadEngine.stateFor(_activities, trainingZones);

  /// Il carico di una singola seduta, per mostrarlo nel dettaglio attivita'.
  double? loadOf(RunningActivity activity) {
    final TrainingZones? zones = trainingZones;
    if (zones == null) return null;
    return _loadEngine.loadOf(activity, zones);
  }

  /// I check-in del mattino, dal piu' recente.
  List<DailyCheckIn> get checkIns => List<DailyCheckIn>.unmodifiable(_checkIns);

  /// Il check-in di oggi, se e' stato fatto.
  DailyCheckIn? get todayCheckIn {
    final DateTime oggi = DateTime.now();
    for (final DailyCheckIn c in _checkIns) {
      if (c.date.year == oggi.year &&
          c.date.month == oggi.month &&
          c.date.day == oggi.day) {
        return c;
      }
    }
    return null;
  }

  /// Salva (o sostituisce) il check-in di un giorno.
  Future<bool> saveCheckIn(DailyCheckIn checkIn) async {
    final DateTime giorno = DateTime(
      checkIn.date.year,
      checkIn.date.month,
      checkIn.date.day,
    );
    _checkIns = <DailyCheckIn>[
      checkIn,
      ..._checkIns.where((DailyCheckIn c) =>
          !(c.date.year == giorno.year &&
              c.date.month == giorno.month &&
              c.date.day == giorno.day)),
    ]..sort((DailyCheckIn a, DailyCheckIn b) => b.date.compareTo(a.date));

    _readinessCache = null;
    notifyListeners();

    final bool ok = await _storage.saveCheckIns(_checkIns);
    if (!ok) {
      _errorMessage = _storage.lastError;
      notifyListeners();
    }
    return ok;
  }

  /// Quanto sei pronto oggi, con il perche'.
  Readiness get readiness {
    final Readiness? cached = _readinessCache;
    if (cached != null) return cached;

    return _readinessCache = _readinessEngine.compute(
      load: trainingLoad,
      checkIn: todayCheckIn,
      lastQualityAt: _lastQualityAt(),
    );
  }

  /// L'ultima seduta riconosciuta come dura dal classificatore.
  ///
  /// Si guardano solo gli ultimi giorni: piu' indietro non serve a niente e
  /// classificare un tracciato costa, perche' va riletto punto per punto.
  DateTime? _lastQualityAt() {
    final TrainingZones? zones = trainingZones;
    if (zones == null) return null;

    final DateTime limite =
        DateTime.now().subtract(const Duration(days: 5));
    DateTime? ultima;
    for (final RunningActivity a in _activities) {
      if (a.startTime.isBefore(limite)) continue;
      final SessionAnalysis analisi = _classifier.analyse(a, zones);
      if (!analisi.intensity.countsAsQuality) continue;
      if (ultima == null || a.startTime.isAfter(ultima)) ultima = a.startTime;
    }
    return ultima;
  }

  /// Le distanze per cui QUESTA corsa detiene il record.
  ///
  /// PERCHE' NON BASTA GUARDARE LO STORICO REGISTRATO
  /// ------------------------------------------------
  /// Un'uscita da 13,5 km a 5:33 si prendeva il trofeo "record personale 10 km
  /// 54:44" da un atleta che nel profilo ha dichiarato un 10 km in **44:00** -
  /// lo stesso numero su cui il motore di forma costruisce tutto l'indice.
  /// Due parti della stessa app che si contraddicono, e quella che si vede e'
  /// quella sbagliata.
  ///
  /// Un record e' un record se batte il meglio che sai di aver fatto, non il
  /// meglio che l'app ti ha visto fare.
  List<DistanceRecord> recordsHeldBy(String activityId) => records.byDistance
      .where((DistanceRecord r) => r.activityId == activityId)
      .where((DistanceRecord r) => !_beatenByDeclared(r))
      .toList();

  /// `true` se un personale dichiarato a mano e' piu' veloce di questo record.
  bool _beatenByDeclared(DistanceRecord record) {
    final int? dichiarato = declaredBestSeconds(record.distance.meters);
    return dichiarato != null && dichiarato < record.seconds;
  }

  /// Il tempo dichiarato nel profilo per una distanza, se c'e'.
  ///
  /// La tolleranza serve perche' "10 km" dichiarato e la distanza standard
  /// dei record non cadono sullo stesso metro.
  int? declaredBestSeconds(double meters) {
    int? migliore;
    for (final PersonalBest pb in _athleteProfile.personalBests) {
      if ((pb.meters - meters).abs() > meters * 0.02) continue;
      if (migliore == null || pb.seconds < migliore) migliore = pb.seconds;
    }
    return migliore;
  }

  ImprovementResult get paceImprovement =>
      _stats.computePaceImprovement(_activities);

  ImprovementResult get volumeTrend => _stats.computeVolumeTrend(_activities);

  /// Attivita' registrate con una determinata scarpa.
  List<RunningActivity> byShoe(String shoeId) =>
      _activities.where((RunningActivity a) => a.shoeId == shoeId).toList();

  void _sort() {
    _activities.sort((RunningActivity a, RunningActivity b) =>
        b.startTime.compareTo(a.startTime));
  }

  Future<bool> _persist() async {
    final bool ok = await _storage.saveActivities(_activities);
    if (!ok) {
      _errorMessage = _storage.lastError;
      notifyListeners();
    }
    return ok;
  }
}
