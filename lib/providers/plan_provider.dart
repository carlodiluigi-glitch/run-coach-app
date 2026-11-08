import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../models/coach_week.dart';
import '../models/training_plan.dart';
import '../models/weekly_availability.dart';
import '../services/plan_service.dart';
import '../services/storage_service.dart';
import '../utils/giorni.dart';

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

  /// Le settimane concordate col coach, appoggiate sopra il piano.
  List<CoachWeek> _coachWeeks = <CoachWeek>[];
  List<CoachWeek> get coachWeeks => List<CoachWeek>.unmodifiable(_coachWeeks);

  /// Il piano com'e' senza le settimane del coach: per mostrare il "prima".
  TrainingPlan? _basePlan;
  List<PlannedSession> baseSessionsOn(DateTime day) =>
      _basePlan?.sessionsOn(day) ?? <PlannedSession>[];
  bool _loaded = false;
  String? _errorMessage;

  PlanConfig? get config => _config;
  TrainingPlan? get plan => _plan;
  bool get isLoaded => _loaded;
  bool get hasPlan => _plan != null && !_plan!.isEmpty;
  String? get errorMessage => _errorMessage;

  Future<void> load() async {
    _config = await _storage.loadPlanConfig();
    await _loadCoachWeeks();
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
    _basePlan = generated;
    _plan = _conCoach(generated);
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

  /// Cambia i giorni e i tempi di UNA settimana sola.
  ///
  /// PERCHE' NON CAMBIA LA SETTIMANA NORMALE
  /// ---------------------------------------
  /// Perche' un turno diverso e' un'eccezione, non un trasloco. Se cambiare la
  /// settimana del 12 ottobre cambiasse anche quelle dopo, l'atleta dovrebbe
  /// ricordarsi di rimetterla a posto - e non lo fara', e tre mesi dopo il
  /// piano avra' il lungo nel giorno sbagliato senza che nessuno sappia
  /// perche'.
  ///
  /// Si passa `null` per rimettere quella settimana come le altre.
  Future<bool> setWeekAvailability(
    int weekNumber,
    WeeklyAvailability? availability,
  ) async {
    final PlanConfig? current = _config;
    if (current == null || weekNumber < 1) return false;
    return create(current.withWeekAvailability(weekNumber, availability));
  }

  /// Rimette una settimana sui giorni normali.
  Future<bool> resetWeek(int weekNumber) =>
      setWeekAvailability(weekNumber, null);

  /// Rimette TUTTO il piano sui giorni normali.
  Future<bool> resetAllWeeks() async {
    final PlanConfig? current = _config;
    if (current == null) return false;
    return create(
      current.copyWith(weekOverrides: const <int, WeeklyAvailability>{}),
    );
  }

  /// I giorni in vigore per una settimana: i suoi, se li ha, altrimenti quelli
  /// normali. Un solo posto da cui legge anche la schermata.
  WeeklyAvailability availabilityForWeek(int weekNumber) =>
      _config?.availabilityForWeek(weekNumber) ??
      WeeklyAvailability.suggested();

  bool isWeekChanged(int weekNumber) =>
      _config?.isWeekChanged(weekNumber) ?? false;

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
    _basePlan = null;
    _errorMessage = null;
    notifyListeners();
    await _storage.deletePlanConfig();
  }

  void _recompute() {
    final PlanConfig? current = _config;
    _basePlan = current == null ? null : _service.generate(current);
    _plan = _conCoach(_basePlan);
  }

  // ------------------------------------------------- settimane del coach
  //
  // Il piano si ricalcola a ogni avvio dalle sue regole: una settimana
  // importata non lo modifica, gli si appoggia sopra. Per i sette giorni
  // della settimana del coach valgono le sue sedute; fuori, quelle del
  // piano. Togliere la settimana del coach riporta il piano com'era.

  /// La settimana del coach che copre [day], se c'e'.
  CoachWeek? coachWeekCovering(DateTime day) {
    for (final CoachWeek w in _coachWeeks) {
      if (w.covers(day)) return w;
    }
    return null;
  }

  /// Applica una settimana del coach. Ne sostituisce un'altra che copra
  /// gli stessi giorni.
  Future<bool> applyCoachWeek(CoachWeek week) async {
    _coachWeeks = <CoachWeek>[
      for (final CoachWeek w in _coachWeeks)
        if (giorniFra(w.from, week.from).abs() > 6) w,
      week,
    ]..sort((CoachWeek a, CoachWeek b) => a.from.compareTo(b.from));
    _recompute();
    notifyListeners();
    return _saveCoachWeeks();
  }

  /// Toglie la settimana del coach che copre [day]: tornano le sedute del
  /// piano.
  Future<bool> removeCoachWeek(DateTime day) async {
    _coachWeeks =
        _coachWeeks.where((CoachWeek w) => !w.covers(day)).toList();
    _recompute();
    notifyListeners();
    return _saveCoachWeeks();
  }

  TrainingPlan? _conCoach(TrainingPlan? piano) {
    if (piano == null || _coachWeeks.isEmpty) return piano;
    final List<PlanWeek> settimane = <PlanWeek>[];
    for (final PlanWeek w in piano.weeks) {
      CoachWeek? nota;
      final List<PlannedSession> sedute = <PlannedSession>[];
      for (final PlannedSession s in w.sessions) {
        final CoachWeek? c = coachWeekCovering(s.date);
        if (c == null) sedute.add(s);
      }
      for (final CoachWeek c in _coachWeeks) {
        for (int g = 0; g < 7; g++) {
          final DateTime giorno = piuGiorni(w.startDate, g);
          if (c.covers(giorno)) nota = c;
        }
        for (final PlannedSession s in c.sessions) {
          final int g = giorniFra(w.startDate, s.date);
          if (g >= 0 && g <= 6) sedute.add(s);
        }
      }
      if (nota == null) {
        settimane.add(w);
        continue;
      }
      sedute.sort((PlannedSession a, PlannedSession b) =>
          a.date.compareTo(b.date));
      settimane.add(w.copyWith(
        sessions: sedute,
        note: 'Concordata col coach (${nota.decisionLabel.toLowerCase()})'
            '${nota.reason.isEmpty ? '' : ': ${nota.reason}'}',
      ));
    }
    return TrainingPlan(config: piano.config, weeks: settimane);
  }

  Future<void> _loadCoachWeeks() async {
    final String? raw =
        await _storage.readExtra(StorageService.coachWeeksFileName);
    if (raw == null) return;
    try {
      final Object? decoded = jsonDecode(raw);
      if (decoded is! List) return;
      // Le settimane passate da piu' di due mesi non servono piu'.
      final DateTime limite = piuGiorni(DateTime.now(), -60);
      _coachWeeks = decoded
          .whereType<Map<dynamic, dynamic>>()
          .map((Map<dynamic, dynamic> e) =>
              CoachWeek.fromJson(e.cast<String, dynamic>()))
          .whereType<CoachWeek>()
          .where((CoachWeek w) => w.to.isAfter(limite))
          .toList();
    } catch (_) {
      _coachWeeks = <CoachWeek>[];
    }
  }

  Future<bool> _saveCoachWeeks() => _storage.writeExtra(
        StorageService.coachWeeksFileName,
        jsonEncode(_coachWeeks.map((CoachWeek w) => w.toJson()).toList()),
      );

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
    return reference.isAfter(piuGiorni(current.endDate, 1));
  }
}
