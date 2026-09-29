import 'package:flutter/foundation.dart';

import '../models/training_plan.dart';
import '../services/plan_service.dart';
import '../services/storage_service.dart';

/// Stato del piano di allenamento attivo.
///
/// Su disco vanno solo i parametri (obiettivo, date, giorni, forma di
/// partenza, gare): le sedute vengono ricalcolate a ogni avvio dal
/// generatore. Un solo posto in cui esiste la verita', e un file di poche
/// righe invece di un centinaio di allenamenti serializzati.
class PlanProvider extends ChangeNotifier {
  PlanProvider({
    required StorageService storage,
    PlanService service = const PlanService(),
  })  : _storage = storage,
        _service = service;

  final StorageService _storage;
  final PlanService _service;

  PlanConfig? _config;
  TrainingPlan? _plan;
  bool _loaded = false;
  String? _errorMessage;

  PlanConfig? get config => _config;
  TrainingPlan? get plan => _plan;
  bool get isLoaded => _loaded;
  bool get hasPlan => _plan != null && !_plan!.isEmpty;
  String? get errorMessage => _errorMessage;

  Future<void> load() async {
    _config = await _storage.loadPlanConfig();
    _recompute();
    _loaded = true;
    notifyListeners();
  }

  /// Crea (o sostituisce) il piano.
  Future<bool> create(PlanConfig config) async {
    final TrainingPlan? generated = _service.generate(config);
    if (generated == null) {
      _errorMessage =
          'Serve prima una stima della forma: registra una corsa tirata di '
          'almeno 3 km.';
      notifyListeners();
      return false;
    }

    _config = config;
    _plan = generated;
    _errorMessage = null;
    notifyListeners();

    final bool ok = await _storage.savePlanConfig(config);
    if (!ok) {
      _errorMessage = _storage.lastError;
      notifyListeners();
    }
    return ok;
  }

  /// Riscrive le sedute del piano con un indice di forma aggiornato.
  ///
  /// PERCHE' NON SUCCEDE DA SOLO
  /// ---------------------------
  /// L'indice viene congelato alla creazione apposta: se i ritmi cambiassero
  /// a ogni corsa non si capirebbe piu' se stai migliorando o se e' cambiato
  /// il metro di misura. Ma su un piano che dura mesi congelarlo per sempre
  /// e' l'errore opposto: dopo tre mesi ti allena ai ritmi di quando l'hai
  /// creato, e diventa la cosa che ti frena.
  ///
  /// La via di mezzo: il piano si accorge che l'indice si e' mosso, lo dice,
  /// e aggiorna solo se glielo chiedi. Il calendario non cambia - stessi
  /// giorni, stesse settimane, stessa progressione: cambiano i passi e il
  /// numero di ripetizioni.
  Future<bool> updatePaces(double vdot) async {
    final PlanConfig? current = _config;
    if (current == null || vdot <= 0) return false;
    return create(current.copyWith(vdot: vdot));
  }

  /// Aggiunge una gara al piano e ne ricalcola le settimane intorno.
  Future<bool> addRace(RaceEvent race) async {
    final PlanConfig? current = _config;
    if (current == null) return false;

    final List<RaceEvent> races = List<RaceEvent>.from(current.races)
      ..add(race)
      ..sort((RaceEvent a, RaceEvent b) => a.date.compareTo(b.date));

    return create(current.copyWith(races: races));
  }

  Future<bool> removeRace(String raceId) async {
    final PlanConfig? current = _config;
    if (current == null) return false;

    final List<RaceEvent> races = current.races
        .where((RaceEvent r) => r.id != raceId)
        .toList();

    return create(current.copyWith(races: races));
  }

  /// Elimina il piano attivo.
  Future<void> clear() async {
    _config = null;
    _plan = null;
    _errorMessage = null;
    notifyListeners();
    await _storage.deletePlanConfig();
  }

  void _recompute() {
    final PlanConfig? current = _config;
    _plan = current == null ? null : _service.generate(current);
  }

  // ---------------------------------------------------------------- comodita'
  /// Settimana in corso.
  PlanWeek? weekFor(DateTime day) => _plan?.weekFor(day);

  /// Sedute previste in un giorno.
  List<PlannedSession> sessionsOn(DateTime day) =>
      _plan?.sessionsOn(day) ?? <PlannedSession>[];

  /// Prossima seduta da oggi in avanti.
  PlannedSession? nextSession({DateTime? from}) =>
      _plan?.nextSessionFrom(from ?? DateTime.now());

  /// `true` se il piano e' finito (l'ultima settimana e' passata).
  bool isFinished({DateTime? now}) {
    final PlanConfig? current = _config;
    if (current == null) return false;
    final DateTime reference = now ?? DateTime.now();
    return reference.isAfter(current.endDate.add(const Duration(days: 1)));
  }
}
