import 'package:flutter/foundation.dart';

import '../models/running_activity.dart';
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
