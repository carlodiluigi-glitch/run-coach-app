import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:run_coach_app/models/lap.dart';
import 'package:run_coach_app/models/running_activity.dart';
import 'package:run_coach_app/models/running_shoe.dart';
import 'package:run_coach_app/models/user_settings.dart';
import 'package:run_coach_app/models/workout.dart';
import 'package:run_coach_app/models/workout_step.dart';
import 'package:run_coach_app/services/storage_service.dart';

void main() {
  late Directory tempDir;
  late StorageService storage;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('run_coach_test');
    storage = StorageService(overrideDirectory: tempDir);
  });

  tearDown(() async {
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  test('impostazioni: default se il file non esiste', () async {
    final UserSettings settings = await storage.loadSettings();
    expect(settings.userName, '');
    expect(settings.audioCoachEnabled, isTrue);
    expect(settings.autoLapDistanceMeters, 1000);
  });

  test('impostazioni: salvataggio e rilettura', () async {
    const UserSettings settings = UserSettings(
      userName: 'Mario',
      coachPersonality: CoachPersonality.sergeant,
      autoLapDistanceMeters: 500,
    );
    expect(await storage.saveSettings(settings), isTrue);

    final UserSettings loaded = await storage.loadSettings();
    expect(loaded.userName, 'Mario');
    expect(loaded.coachPersonality, CoachPersonality.sergeant);
    expect(loaded.autoLapDistanceMeters, 500);
  });

  test('scarpe: salvataggio e rilettura', () async {
    final RunningShoe shoe = RunningShoe(
      brand: 'ASICS',
      model: 'Novablast 5',
      initialKm: 100,
      accumulatedMeters: 287000,
      thresholdKm: 650,
    );
    expect(await storage.saveShoes(<RunningShoe>[shoe]), isTrue);

    final List<RunningShoe> loaded = await storage.loadShoes();
    expect(loaded.length, 1);
    expect(loaded.first.displayName, 'ASICS Novablast 5');
    expect(loaded.first.totalKm, closeTo(387, 0.001));
    expect(loaded.first.isOverThreshold, isFalse);
  });

  test('allenamenti: i blocchi ripetuti sopravvivono al salvataggio', () async {
    final Workout workout = Workout(
      name: 'Test',
      blocks: <WorkoutBlock>[
        WorkoutBlock(
          repeat: 4,
          steps: <WorkoutStep>[
            WorkoutStep(
              type: StepType.interval,
              goalType: StepGoalType.distance,
              goalDistanceMeters: 1000,
              paceTarget: const PaceTarget(
                  fastestSecPerKm: 240, slowestSecPerKm: 250),
            ),
          ],
        ),
      ],
    );
    expect(await storage.saveWorkouts(<Workout>[workout]), isTrue);

    final List<Workout> loaded = await storage.loadWorkouts();
    expect(loaded.length, 1);
    expect(loaded.first.blocks.first.repeat, 4);
    expect(loaded.first.totalSteps, 4);
    expect(
      loaded.first.blocks.first.steps.first.paceTarget?.fastestSecPerKm,
      240,
    );
  });

  test('attivita: salvataggio con lap e rilettura ordinata', () async {
    final RunningActivity older = RunningActivity(
      startTime: DateTime(2026, 8, 20, 8),
      name: 'Corsa libera',
      type: ActivityType.free,
      durationSeconds: 1800,
      distanceMeters: 6000,
    );
    final RunningActivity newer = RunningActivity(
      startTime: DateTime(2026, 8, 25, 8),
      name: 'Ripetute',
      type: ActivityType.workout,
      durationSeconds: 3000,
      distanceMeters: 10000,
      laps: <Lap>[
        const Lap(
          number: 1,
          distanceMeters: 1000,
          durationSeconds: 300,
          totalTimeSeconds: 300,
        ),
      ],
    );

    expect(
      await storage.saveActivities(<RunningActivity>[older, newer]),
      isTrue,
    );

    final List<RunningActivity> loaded = await storage.loadActivities();
    expect(loaded.length, 2);
    // La piu' recente per prima.
    expect(loaded.first.name, 'Ripetute');
    expect(loaded.first.laps.length, 1);
    expect(loaded.first.laps.first.paceSecondsPerKm, 300);
    expect(loaded.first.averagePaceSecondsPerKm, 300);
  });

  test('file corrotto: non fa crashare l\'app', () async {
    final Directory dir = Directory('${tempDir.path}/run_coach');
    await dir.create(recursive: true);
    await File('${dir.path}/${StorageService.activitiesFileName}')
        .writeAsString('{ questo non e json valido ');

    final List<RunningActivity> loaded = await storage.loadActivities();
    expect(loaded, isEmpty);
    expect(storage.lastError, isNotNull);
  });
}
