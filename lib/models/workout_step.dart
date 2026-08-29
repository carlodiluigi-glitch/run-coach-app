import '../utils/formatters.dart';
import '../utils/id_generator.dart';

/// Tipo (fase) di uno step di allenamento.
enum StepType { warmup, run, interval, recovery, cooldown, generic }

/// Come termina uno step: al raggiungimento di una distanza o di un tempo.
enum StepGoalType { distance, time }

extension StepTypeLabel on StepType {
  String get label {
    switch (this) {
      case StepType.warmup:
        return 'Riscaldamento';
      case StepType.run:
        return 'Corsa';
      case StepType.interval:
        return 'Ripetuta';
      case StepType.recovery:
        return 'Recupero';
      case StepType.cooldown:
        return 'Defaticamento';
      case StepType.generic:
        return 'Generico';
    }
  }

  /// Etichetta usata dal coach vocale (minuscola, pronunciabile).
  String get spokenLabel => label.toLowerCase();

  String get storageKey => name;

  static StepType fromStorage(String? value) {
    for (final StepType t in StepType.values) {
      if (t.name == value) return t;
    }
    return StepType.generic;
  }
}

extension StepGoalTypeLabel on StepGoalType {
  String get label => this == StepGoalType.distance ? 'Distanza' : 'Tempo';

  static StepGoalType fromStorage(String? value) =>
      value == 'time' ? StepGoalType.time : StepGoalType.distance;
}

/// Intervallo di passo target per uno step.
///
/// I valori sono in **secondi per chilometro**:
///  - [fastestSecPerKm] e' il limite piu' veloce (valore numerico piu' basso);
///  - [slowestSecPerKm] e' il limite piu' lento (valore numerico piu' alto).
///
/// Esempio "4:00-4:10 /km" -> fastest = 240, slowest = 250.
class PaceTarget {
  const PaceTarget({this.fastestSecPerKm, this.slowestSecPerKm});

  final double? fastestSecPerKm;
  final double? slowestSecPerKm;

  bool get isEmpty => fastestSecPerKm == null && slowestSecPerKm == null;
  bool get isNotEmpty => !isEmpty;

  /// Passo centrale dell'intervallo (utile per stime e messaggi).
  double? get centerSecPerKm {
    if (fastestSecPerKm != null && slowestSecPerKm != null) {
      return (fastestSecPerKm! + slowestSecPerKm!) / 2.0;
    }
    return fastestSecPerKm ?? slowestSecPerKm;
  }

  /// Valuta un passo corrente rispetto al target.
  PaceStatus evaluate(double? currentSecPerKm) {
    if (isEmpty || currentSecPerKm == null || currentSecPerKm <= 0) {
      return PaceStatus.unknown;
    }
    if (fastestSecPerKm != null && currentSecPerKm < fastestSecPerKm!) {
      return PaceStatus.tooFast;
    }
    if (slowestSecPerKm != null && currentSecPerKm > slowestSecPerKm!) {
      return PaceStatus.tooSlow;
    }
    return PaceStatus.onTarget;
  }

  String get label => formatPaceRange(fastestSecPerKm, slowestSecPerKm);

  Map<String, dynamic> toJson() => <String, dynamic>{
        'fastestSecPerKm': fastestSecPerKm,
        'slowestSecPerKm': slowestSecPerKm,
      };

  factory PaceTarget.fromJson(Map<String, dynamic> json) => PaceTarget(
        fastestSecPerKm: (json['fastestSecPerKm'] as num?)?.toDouble(),
        slowestSecPerKm: (json['slowestSecPerKm'] as num?)?.toDouble(),
      );
}

/// Stato del ritmo rispetto al target.
enum PaceStatus { tooSlow, onTarget, tooFast, unknown }

extension PaceStatusLabel on PaceStatus {
  String get label {
    switch (this) {
      case PaceStatus.tooSlow:
        return 'troppo lento';
      case PaceStatus.onTarget:
        return 'ritmo corretto';
      case PaceStatus.tooFast:
        return 'troppo veloce';
      case PaceStatus.unknown:
        return 'in attesa dati';
    }
  }

  /// Simbolo testuale, leggibile anche senza distinguere i colori.
  String get symbol {
    switch (this) {
      case PaceStatus.tooSlow:
        return '↓'; // freccia giu'
      case PaceStatus.onTarget:
        return '✓'; // spunta
      case PaceStatus.tooFast:
        return '↑'; // freccia su
      case PaceStatus.unknown:
        return '•'; // punto
    }
  }
}

/// Un singolo step di un allenamento programmato.
class WorkoutStep {
  WorkoutStep({
    String? id,
    required this.type,
    required this.goalType,
    this.goalDistanceMeters = 1000,
    this.goalSeconds = 300,
    this.paceTarget,
    this.note,
  }) : id = id ?? IdGenerator.newId('step');

  final String id;
  final StepType type;
  final StepGoalType goalType;

  /// Distanza obiettivo in metri (usata se [goalType] e' `distance`).
  final double goalDistanceMeters;

  /// Tempo obiettivo in secondi (usato se [goalType] e' `time`).
  final int goalSeconds;

  final PaceTarget? paceTarget;
  final String? note;

  bool get isDistanceBased => goalType == StepGoalType.distance;

  /// Descrizione breve dell'obiettivo: `400 m` oppure `15 min`.
  String get goalLabel => isDistanceBased
      ? formatDistanceAuto(goalDistanceMeters)
      : formatDurationShort(goalSeconds);

  /// Stima della durata dello step in secondi (per il riepilogo allenamento).
  ///
  /// Per gli step a distanza usa il passo target se presente, altrimenti una
  /// andatura prudenziale di 6:00/km. E' solo una stima mostrata in UI.
  int get estimatedSeconds {
    if (!isDistanceBased) return goalSeconds;
    final double pace = paceTarget?.centerSecPerKm ?? 360.0;
    return (goalDistanceMeters / 1000.0 * pace).round();
  }

  /// Stima della distanza dello step in metri.
  double get estimatedMeters {
    if (isDistanceBased) return goalDistanceMeters;
    final double pace = paceTarget?.centerSecPerKm ?? 360.0;
    return goalSeconds / pace * 1000.0;
  }

  WorkoutStep copyWith({
    StepType? type,
    StepGoalType? goalType,
    double? goalDistanceMeters,
    int? goalSeconds,
    PaceTarget? paceTarget,
    bool clearPaceTarget = false,
    String? note,
  }) {
    return WorkoutStep(
      id: id,
      type: type ?? this.type,
      goalType: goalType ?? this.goalType,
      goalDistanceMeters: goalDistanceMeters ?? this.goalDistanceMeters,
      goalSeconds: goalSeconds ?? this.goalSeconds,
      paceTarget: clearPaceTarget ? null : (paceTarget ?? this.paceTarget),
      note: note ?? this.note,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'type': type.name,
        'goalType': goalType.name,
        'goalDistanceMeters': goalDistanceMeters,
        'goalSeconds': goalSeconds,
        'paceTarget': paceTarget?.toJson(),
        'note': note,
      };

  factory WorkoutStep.fromJson(Map<String, dynamic> json) {
    final Map<String, dynamic>? target =
        (json['paceTarget'] as Map?)?.cast<String, dynamic>();
    return WorkoutStep(
      id: json['id'] as String?,
      type: StepTypeLabel.fromStorage(json['type'] as String?),
      goalType: StepGoalTypeLabel.fromStorage(json['goalType'] as String?),
      goalDistanceMeters:
          (json['goalDistanceMeters'] as num?)?.toDouble() ?? 1000.0,
      goalSeconds: (json['goalSeconds'] as num?)?.toInt() ?? 300,
      paceTarget: target == null ? null : PaceTarget.fromJson(target),
      note: json['note'] as String?,
    );
  }
}
