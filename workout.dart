import '../utils/id_generator.dart';
import 'workout_step.dart';

/// Un blocco di allenamento: uno o piu' step ripetuti N volte.
///
/// Esempio: `10 x (400 m veloce + 200 m recupero)` e' un unico blocco con
/// [repeat] = 10 e due step. L'utente non deve creare 20 righe a mano.
class WorkoutBlock {
  WorkoutBlock({
    String? id,
    this.repeat = 1,
    List<WorkoutStep>? steps,
  })  : id = id ?? IdGenerator.newId('block'),
        steps = steps ?? <WorkoutStep>[];

  final String id;

  /// Numero di ripetizioni del blocco (minimo 1).
  final int repeat;

  final List<WorkoutStep> steps;

  bool get isRepeated => repeat > 1;

  WorkoutBlock copyWith({int? repeat, List<WorkoutStep>? steps}) => WorkoutBlock(
        id: id,
        repeat: repeat ?? this.repeat,
        steps: steps ?? List<WorkoutStep>.from(this.steps),
      );

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'repeat': repeat,
        'steps': steps.map((WorkoutStep s) => s.toJson()).toList(),
      };

  factory WorkoutBlock.fromJson(Map<String, dynamic> json) {
    final List<dynamic> rawSteps = (json['steps'] as List<dynamic>?) ?? <dynamic>[];
    return WorkoutBlock(
      id: json['id'] as String?,
      repeat: (json['repeat'] as num?)?.toInt() ?? 1,
      steps: rawSteps
          .map((dynamic e) =>
              WorkoutStep.fromJson((e as Map).cast<String, dynamic>()))
          .toList(),
    );
  }
}

/// Uno step "risolto": il risultato dell'espansione dei blocchi ripetuti.
///
/// E' cio' che il [WorkoutEngine] esegue realmente, ma l'utente in interfaccia
/// continua a vedere i blocchi compatti.
class ResolvedStep {
  const ResolvedStep({
    required this.step,
    required this.globalIndex,
    required this.blockIndex,
    required this.repetitionIndex,
    required this.repetitionTotal,
  });

  final WorkoutStep step;

  /// Posizione dello step nella sequenza espansa (parte da 0).
  final int globalIndex;

  /// Indice del blocco di provenienza (parte da 0).
  final int blockIndex;

  /// Ripetizione corrente del blocco (parte da 1).
  final int repetitionIndex;

  /// Ripetizioni totali del blocco.
  final int repetitionTotal;

  bool get isRepeated => repetitionTotal > 1;

  /// Etichetta compatta, es. `Ripetuta 4/10`.
  String get label => isRepeated
      ? '${step.type.label} $repetitionIndex/$repetitionTotal'
      : step.type.label;
}

/// Un allenamento programmato, composto da blocchi.
class Workout {
  Workout({
    String? id,
    required this.name,
    List<WorkoutBlock>? blocks,
    DateTime? createdAt,
    this.note,
  })  : id = id ?? IdGenerator.newId('wk'),
        blocks = blocks ?? <WorkoutBlock>[],
        createdAt = createdAt ?? DateTime.now();

  final String id;
  final String name;
  final List<WorkoutBlock> blocks;
  final DateTime createdAt;
  final String? note;

  bool get isEmpty => expand().isEmpty;

  /// Espande i blocchi ripetuti nella sequenza lineare eseguita dal motore.
  List<ResolvedStep> expand() {
    final List<ResolvedStep> result = <ResolvedStep>[];
    for (int b = 0; b < blocks.length; b++) {
      final WorkoutBlock block = blocks[b];
      final int repeat = block.repeat < 1 ? 1 : block.repeat;
      for (int r = 1; r <= repeat; r++) {
        for (final WorkoutStep step in block.steps) {
          result.add(ResolvedStep(
            step: step,
            globalIndex: result.length,
            blockIndex: b,
            repetitionIndex: r,
            repetitionTotal: repeat,
          ));
        }
      }
    }
    return result;
  }

  /// Numero di step effettivi dopo l'espansione.
  int get totalSteps => expand().length;

  /// Stima della distanza totale (metri).
  double get estimatedMeters {
    double total = 0;
    for (final ResolvedStep s in expand()) {
      total += s.step.estimatedMeters;
    }
    return total;
  }

  /// Stima della durata totale (secondi).
  int get estimatedSeconds {
    int total = 0;
    for (final ResolvedStep s in expand()) {
      total += s.step.estimatedSeconds;
    }
    return total;
  }

  Workout copyWith({
    String? name,
    List<WorkoutBlock>? blocks,
    String? note,
  }) =>
      Workout(
        id: id,
        name: name ?? this.name,
        blocks: blocks ?? List<WorkoutBlock>.from(this.blocks),
        createdAt: createdAt,
        note: note ?? this.note,
      );

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'name': name,
        'createdAt': createdAt.toIso8601String(),
        'note': note,
        'blocks': blocks.map((WorkoutBlock b) => b.toJson()).toList(),
      };

  factory Workout.fromJson(Map<String, dynamic> json) {
    final List<dynamic> rawBlocks =
        (json['blocks'] as List<dynamic>?) ?? <dynamic>[];
    return Workout(
      id: json['id'] as String?,
      name: json['name'] as String? ?? 'Allenamento',
      createdAt: DateTime.tryParse(json['createdAt'] as String? ?? ''),
      note: json['note'] as String?,
      blocks: rawBlocks
          .map((dynamic e) =>
              WorkoutBlock.fromJson((e as Map).cast<String, dynamic>()))
          .toList(),
    );
  }
}
