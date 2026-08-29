import 'package:flutter/foundation.dart';

import '../models/workout.dart';
import '../models/workout_step.dart';
import '../services/storage_service.dart';

/// Stato della libreria di allenamenti programmati.
class WorkoutProvider extends ChangeNotifier {
  WorkoutProvider({required StorageService storage}) : _storage = storage;

  final StorageService _storage;

  List<Workout> _workouts = <Workout>[];
  bool _loaded = false;
  String? _errorMessage;

  List<Workout> get workouts => List<Workout>.unmodifiable(_workouts);
  bool get isLoaded => _loaded;
  bool get isEmpty => _workouts.isEmpty;
  String? get errorMessage => _errorMessage;

  Future<void> load() async {
    _workouts = await _storage.loadWorkouts();
    _sort();
    _loaded = true;
    _errorMessage = _storage.lastError;
    notifyListeners();
  }

  Workout? byId(String? id) {
    if (id == null) return null;
    for (final Workout w in _workouts) {
      if (w.id == id) return w;
    }
    return null;
  }

  Future<void> save(Workout workout) async {
    final int index = _workouts.indexWhere((Workout w) => w.id == workout.id);
    if (index >= 0) {
      final List<Workout> next = List<Workout>.from(_workouts);
      next[index] = workout;
      _workouts = next;
    } else {
      _workouts = <Workout>[..._workouts, workout];
    }
    _sort();
    notifyListeners();
    await _persist();
  }

  Future<void> remove(String id) async {
    _workouts = _workouts.where((Workout w) => w.id != id).toList();
    notifyListeners();
    await _persist();
  }

  Future<void> duplicate(Workout workout) async {
    final Workout copy = Workout(
      name: '${workout.name} (copia)',
      note: workout.note,
      blocks: workout.blocks
          .map((WorkoutBlock b) => WorkoutBlock(
                repeat: b.repeat,
                steps: b.steps
                    .map((WorkoutStep s) => s.copyWith())
                    .toList(),
              ))
          .toList(),
    );
    await save(copy);
  }

  /// Crea un allenamento di esempio, utile come punto di partenza.
  ///
  /// Non viene creato automaticamente: l'app parte vuota e l'utente decide se
  /// aggiungerlo dal pulsante dedicato nella libreria.
  static Workout sampleIntervalWorkout() => Workout(
        name: '10 x 400 m',
        note: 'Esempio: riscaldamento, ripetute, defaticamento.',
        blocks: <WorkoutBlock>[
          WorkoutBlock(
            repeat: 1,
            steps: <WorkoutStep>[
              WorkoutStep(
                type: StepType.warmup,
                goalType: StepGoalType.time,
                goalSeconds: 15 * 60,
              ),
            ],
          ),
          WorkoutBlock(
            repeat: 10,
            steps: <WorkoutStep>[
              WorkoutStep(
                type: StepType.interval,
                goalType: StepGoalType.distance,
                goalDistanceMeters: 400,
                paceTarget: const PaceTarget(
                  fastestSecPerKm: 240,
                  slowestSecPerKm: 250,
                ),
              ),
              WorkoutStep(
                type: StepType.recovery,
                goalType: StepGoalType.distance,
                goalDistanceMeters: 200,
                paceTarget: const PaceTarget(
                  fastestSecPerKm: 330,
                  slowestSecPerKm: 360,
                ),
              ),
            ],
          ),
          WorkoutBlock(
            repeat: 1,
            steps: <WorkoutStep>[
              WorkoutStep(
                type: StepType.cooldown,
                goalType: StepGoalType.time,
                goalSeconds: 10 * 60,
              ),
            ],
          ),
        ],
      );

  void _sort() {
    _workouts.sort((Workout a, Workout b) => b.createdAt.compareTo(a.createdAt));
  }

  Future<void> _persist() async {
    final bool ok = await _storage.saveWorkouts(_workouts);
    if (!ok) {
      _errorMessage = _storage.lastError;
      notifyListeners();
    }
  }
}
