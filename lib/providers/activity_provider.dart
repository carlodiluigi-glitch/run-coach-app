import 'package:flutter/foundation.dart';

import '../models/athlete_profile.dart';
import '../models/running_activity.dart';
import '../services/pace_zone_engine.dart';
import '../services/records_service.dart';
import '../services/run_index_engine.dart';
import '../services/stats_service.dart';
import '../services/storage_service.dart';
import 'shoe_provider.dart';

/// Storico delle attivita' salvate.
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

  Future<void> load() async {
    _activities = await _storage.loadActivities();
    _recordsCache = null;
    _runIndexCache = null;
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

  set athleteProfile(AthleteProfile profile) {
    _athleteProfile = profile;
    _runIndexCache = null;
    _zonesCache = null;
    notifyListeners();
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

  List<DistanceRecord> recordsHeldBy(String activityId) => records.byDistance
      .where((DistanceRecord r) => r.activityId == activityId)
      .toList();

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
