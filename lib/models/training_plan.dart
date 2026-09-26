import 'workout.dart';
import '../utils/id_generator.dart';

/// Obiettivo del piano.
enum RaceGoal { fitness, fiveK, tenK, half, marathon }

extension RaceGoalInfo on RaceGoal {
  String get label {
    switch (this) {
      case RaceGoal.fitness:
        return 'Restare in forma';
      case RaceGoal.fiveK:
        return '5 km';
      case RaceGoal.tenK:
        return '10 km';
      case RaceGoal.half:
        return 'Mezza maratona';
      case RaceGoal.marathon:
        return 'Maratona';
    }
  }

  /// Distanza dell'obiettivo. `null` quando non c'e' una gara.
  double? get meters {
    switch (this) {
      case RaceGoal.fitness:
        return null;
      case RaceGoal.fiveK:
        return 5000;
      case RaceGoal.tenK:
        return 10000;
      case RaceGoal.half:
        return 21097.5;
      case RaceGoal.marathon:
        return 42195;
    }
  }

  /// Durata consigliata del piano, in settimane.
  int get defaultWeeks {
    switch (this) {
      case RaceGoal.fitness:
        return 8;
      case RaceGoal.fiveK:
        return 8;
      case RaceGoal.tenK:
        return 10;
      case RaceGoal.half:
        return 14;
      case RaceGoal.marathon:
        return 18;
    }
  }

  /// Sotto questo numero di settimane il piano non ha senso: non c'e' tempo
  /// per costruire niente.
  int get minWeeks => this == RaceGoal.marathon ? 12 : 4;

  int get maxWeeks => 24;

  /// Lunghezza massima del lungo, in metri. Oltre, si accumula fatica senza
  /// aggiungere adattamento.
  double get longRunCapMeters {
    switch (this) {
      case RaceGoal.fitness:
        return 14000;
      case RaceGoal.fiveK:
        return 16000;
      case RaceGoal.tenK:
        return 18000;
      case RaceGoal.half:
        return 26000;
      case RaceGoal.marathon:
        return 32000;
    }
  }

  /// Tetto ragionevole al volume settimanale, in chilometri.
  double get weeklyCapKm {
    switch (this) {
      case RaceGoal.fitness:
        return 60;
      case RaceGoal.fiveK:
        return 65;
      case RaceGoal.tenK:
        return 75;
      case RaceGoal.half:
        return 90;
      case RaceGoal.marathon:
        return 110;
    }
  }

  String get storageKey => name;

  static RaceGoal fromStorage(String? value) {
    for (final RaceGoal g in RaceGoal.values) {
      if (g.name == value) return g;
    }
    return RaceGoal.fitness;
  }
}

/// Fase del piano.
enum PlanPhase { base, build, peak, taper, recovery }

extension PlanPhaseInfo on PlanPhase {
  String get label {
    switch (this) {
      case PlanPhase.base:
        return 'Costruzione';
      case PlanPhase.build:
        return 'Sviluppo';
      case PlanPhase.peak:
        return 'Specifico';
      case PlanPhase.taper:
        return 'Scarico';
      case PlanPhase.recovery:
        return 'Recupero';
    }
  }

  String get description {
    switch (this) {
      case PlanPhase.base:
        return 'Si costruisce il motore: molto lento, poca qualita\'.';
      case PlanPhase.build:
        return 'Entra il lavoro sulla soglia e sulle ripetute.';
      case PlanPhase.peak:
        return 'Si lavora al passo della gara che hai scelto.';
      case PlanPhase.taper:
        return 'Si riduce il volume e si tiene l\'intensita\': arrivi fresco.';
      case PlanPhase.recovery:
        return 'Dopo una gara il corpo ripara: solo corsa lenta.';
    }
  }
}

/// Tipo di seduta.
enum SessionKind {
  easy,
  long,
  threshold,
  intervals,
  repetitions,
  racePace,
  fartlek,
  race,
}

extension SessionKindInfo on SessionKind {
  String get label {
    switch (this) {
      case SessionKind.easy:
        return 'Lento';
      case SessionKind.long:
        return 'Lungo';
      case SessionKind.threshold:
        return 'Soglia';
      case SessionKind.intervals:
        return 'Ripetute';
      case SessionKind.repetitions:
        return 'Veloci';
      case SessionKind.racePace:
        return 'Passo gara';
      case SessionKind.fartlek:
        return 'Fartlek';
      case SessionKind.race:
        return 'Gara';
    }
  }

  /// Le sedute di qualita' sono quelle che costano: dopo una di queste il
  /// giorno dopo si corre piano.
  bool get isQuality {
    switch (this) {
      case SessionKind.threshold:
      case SessionKind.intervals:
      case SessionKind.repetitions:
      case SessionKind.racePace:
      case SessionKind.fartlek:
      case SessionKind.race:
        return true;
      case SessionKind.easy:
      case SessionKind.long:
        return false;
    }
  }
}

/// Una gara messa in calendario.
///
/// Serve sia per la gara obiettivo del piano, sia per una gara che capita nel
/// mezzo: in entrambi i casi il piano alleggerisce prima e recupera dopo.
class RaceEvent {
  RaceEvent({
    String? id,
    required this.name,
    required this.date,
    required this.meters,
    this.isGoal = false,
  }) : id = id ?? IdGenerator.newId('race');

  final String id;
  final String name;

  /// Giorno della gara (l'ora non conta).
  final DateTime date;

  final double meters;

  /// `true` se e' la gara per cui il piano e' stato costruito.
  final bool isGoal;

  /// Quanti giorni prima si smette con la qualita'.
  ///
  /// Una 10 km si corre bene con tre giorni tranquilli alle spalle; una
  /// maratona no, ma una maratona non e' una gara "improvvisata".
  int get taperDays {
    if (meters <= 10500) return 3;
    if (meters <= 22000) return 5;
    return 10;
  }

  /// Quanti giorni dopo si resta sulla corsa lenta.
  ///
  /// La regola classica e' un giorno di recupero per ogni miglio di gara.
  /// Qui e' addolcita e limitata, perche' applicata alla lettera bloccherebbe
  /// tre settimane dopo una maratona.
  int get recoveryDays {
    final int fromDistance = (meters / 1600.0).round();
    if (fromDistance < 2) return 2;
    if (fromDistance > 12) return 12;
    return fromDistance;
  }

  RaceEvent copyWith({
    String? name,
    DateTime? date,
    double? meters,
    bool? isGoal,
  }) =>
      RaceEvent(
        id: id,
        name: name ?? this.name,
        date: date ?? this.date,
        meters: meters ?? this.meters,
        isGoal: isGoal ?? this.isGoal,
      );

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'name': name,
        'date': date.toIso8601String(),
        'meters': meters,
        'isGoal': isGoal,
      };

  factory RaceEvent.fromJson(Map<String, dynamic> json) => RaceEvent(
        id: json['id'] as String?,
        name: json['name'] as String? ?? 'Gara',
        date: DateTime.tryParse(json['date'] as String? ?? '') ??
            DateTime.now(),
        meters: (json['meters'] as num?)?.toDouble() ?? 10000.0,
        isGoal: json['isGoal'] as bool? ?? false,
      );
}

/// Una seduta del piano.
class PlannedSession {
  const PlannedSession({
    required this.date,
    required this.kind,
    required this.title,
    required this.detail,
    this.distanceMeters,
    this.durationSeconds,
    this.workout,
  });

  final DateTime date;
  final SessionKind kind;

  /// Titolo breve, es. "5 x 1000 in ripetute".
  final String title;

  /// Una riga di spiegazione: cosa e perche'.
  final String detail;

  /// Distanza indicativa della seduta.
  final double? distanceMeters;

  final int? durationSeconds;

  /// Allenamento pronto da eseguire. Presente solo sulle sedute strutturate:
  /// un lento non ha bisogno di un motore che conti le fasi.
  final Workout? workout;

  bool get isQuality => kind.isQuality;
  bool get hasWorkout => workout != null;

  PlannedSession copyWith({
    SessionKind? kind,
    String? title,
    String? detail,
    double? distanceMeters,
    int? durationSeconds,
    Workout? workout,
    bool clearWorkout = false,
  }) =>
      PlannedSession(
        date: date,
        kind: kind ?? this.kind,
        title: title ?? this.title,
        detail: detail ?? this.detail,
        distanceMeters: distanceMeters ?? this.distanceMeters,
        durationSeconds: durationSeconds ?? this.durationSeconds,
        workout: clearWorkout ? null : (workout ?? this.workout),
      );
}

/// Una settimana del piano.
class PlanWeek {
  const PlanWeek({
    required this.number,
    required this.phase,
    required this.startDate,
    required this.targetKm,
    required this.sessions,
    this.note,
  });

  /// Numero progressivo, da 1.
  final int number;

  final PlanPhase phase;

  /// Lunedi' della settimana.
  final DateTime startDate;

  /// Volume previsto, in chilometri.
  final double targetKm;

  final List<PlannedSession> sessions;

  /// Nota della settimana ("scarico", "gara sabato").
  final String? note;

  DateTime get endDate => startDate.add(const Duration(days: 6));

  /// Somma effettiva delle distanze delle sedute.
  double get plannedKm {
    double total = 0;
    for (final PlannedSession s in sessions) {
      total += (s.distanceMeters ?? 0) / 1000.0;
    }
    return total;
  }

  int get qualityCount =>
      sessions.where((PlannedSession s) => s.isQuality).length;

  PlanWeek copyWith({
    PlanPhase? phase,
    double? targetKm,
    List<PlannedSession>? sessions,
    String? note,
  }) =>
      PlanWeek(
        number: number,
        phase: phase ?? this.phase,
        startDate: startDate,
        targetKm: targetKm ?? this.targetKm,
        sessions: sessions ?? this.sessions,
        note: note ?? this.note,
      );
}

/// I parametri del piano: e' questo che viene salvato su disco.
///
/// Il piano vero e proprio non viene salvato ma ricalcolato ogni volta dai
/// parametri. Cosi' il file resta minuscolo e non ci sono due versioni della
/// verita' da tenere in sincronia.
class PlanConfig {
  PlanConfig({
    String? id,
    required this.goal,
    required this.startDate,
    required this.weeks,
    required this.daysPerWeek,
    required this.startWeeklyKm,
    required this.vdot,
    List<RaceEvent>? races,
    DateTime? createdAt,
  })  : id = id ?? IdGenerator.newId('plan'),
        races = races ?? <RaceEvent>[],
        createdAt = createdAt ?? DateTime.now();

  final String id;
  final RaceGoal goal;

  /// Lunedi' della prima settimana.
  final DateTime startDate;

  final int weeks;
  final int daysPerWeek;

  /// Chilometri settimanali di partenza: da qui il piano cresce.
  final double startWeeklyKm;

  /// Indice di forma al momento della creazione.
  ///
  /// Viene congelato di proposito: se cambiasse a ogni corsa, i passi delle
  /// sedute ballerebbero da un giorno all'altro e non si capirebbe piu' se
  /// stai migliorando o se e' cambiato il metro.
  final double vdot;

  final List<RaceEvent> races;
  final DateTime createdAt;

  DateTime get endDate => startDate.add(Duration(days: weeks * 7 - 1));

  /// La gara obiettivo, se e' stata messa in calendario.
  RaceEvent? get goalRace {
    for (final RaceEvent r in races) {
      if (r.isGoal) return r;
    }
    return null;
  }

  PlanConfig copyWith({
    RaceGoal? goal,
    DateTime? startDate,
    int? weeks,
    int? daysPerWeek,
    double? startWeeklyKm,
    double? vdot,
    List<RaceEvent>? races,
  }) =>
      PlanConfig(
        id: id,
        goal: goal ?? this.goal,
        startDate: startDate ?? this.startDate,
        weeks: weeks ?? this.weeks,
        daysPerWeek: daysPerWeek ?? this.daysPerWeek,
        startWeeklyKm: startWeeklyKm ?? this.startWeeklyKm,
        vdot: vdot ?? this.vdot,
        races: races ?? List<RaceEvent>.from(this.races),
        createdAt: createdAt,
      );

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'goal': goal.storageKey,
        'startDate': startDate.toIso8601String(),
        'weeks': weeks,
        'daysPerWeek': daysPerWeek,
        'startWeeklyKm': startWeeklyKm,
        'vdot': vdot,
        'createdAt': createdAt.toIso8601String(),
        'races': races.map((RaceEvent r) => r.toJson()).toList(),
      };

  factory PlanConfig.fromJson(Map<String, dynamic> json) {
    final List<dynamic> rawRaces =
        (json['races'] as List<dynamic>?) ?? <dynamic>[];
    return PlanConfig(
      id: json['id'] as String?,
      goal: RaceGoalInfo.fromStorage(json['goal'] as String?),
      startDate:
          DateTime.tryParse(json['startDate'] as String? ?? '') ??
              DateTime.now(),
      weeks: (json['weeks'] as num?)?.toInt() ?? 8,
      daysPerWeek: (json['daysPerWeek'] as num?)?.toInt() ?? 4,
      startWeeklyKm: (json['startWeeklyKm'] as num?)?.toDouble() ?? 20.0,
      vdot: (json['vdot'] as num?)?.toDouble() ?? 0.0,
      createdAt: DateTime.tryParse(json['createdAt'] as String? ?? ''),
      races: rawRaces
          .whereType<Map<dynamic, dynamic>>()
          .map((Map<dynamic, dynamic> e) =>
              RaceEvent.fromJson(e.cast<String, dynamic>()))
          .toList(),
    );
  }
}

/// Il piano calcolato.
class TrainingPlan {
  const TrainingPlan({required this.config, required this.weeks});

  final PlanConfig config;
  final List<PlanWeek> weeks;

  bool get isEmpty => weeks.isEmpty;

  double get totalKm {
    double total = 0;
    for (final PlanWeek w in weeks) {
      total += w.plannedKm;
    }
    return total;
  }

  /// Settimana che contiene un giorno dato.
  PlanWeek? weekFor(DateTime day) {
    final DateTime d = DateTime(day.year, day.month, day.day);
    for (final PlanWeek w in weeks) {
      if (!d.isBefore(w.startDate) &&
          !d.isAfter(w.endDate.add(const Duration(hours: 23)))) {
        return w;
      }
    }
    return null;
  }

  /// Sedute previste in un giorno dato (di solito zero o una).
  List<PlannedSession> sessionsOn(DateTime day) {
    final DateTime d = DateTime(day.year, day.month, day.day);
    final List<PlannedSession> out = <PlannedSession>[];
    for (final PlanWeek w in weeks) {
      for (final PlannedSession s in w.sessions) {
        if (s.date.year == d.year &&
            s.date.month == d.month &&
            s.date.day == d.day) {
          out.add(s);
        }
      }
    }
    return out;
  }

  /// Prossima seduta da oggi in avanti, compreso oggi.
  PlannedSession? nextSessionFrom(DateTime day) {
    final DateTime d = DateTime(day.year, day.month, day.day);
    PlannedSession? best;
    for (final PlanWeek w in weeks) {
      for (final PlannedSession s in w.sessions) {
        if (s.date.isBefore(d)) continue;
        if (best == null || s.date.isBefore(best.date)) best = s;
      }
    }
    return best;
  }

  /// Numero della settimana in corso, 1-based. `null` se il piano non copre
  /// il giorno richiesto.
  int? currentWeekNumber(DateTime day) => weekFor(day)?.number;
}
