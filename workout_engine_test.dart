import 'package:flutter_test/flutter_test.dart';
import 'package:run_coach_app/models/workout.dart';
import 'package:run_coach_app/models/workout_step.dart';
import 'package:run_coach_app/services/workout_engine.dart';

Workout _buildWorkout() {
  return Workout(
    name: '10 x 400',
    blocks: <WorkoutBlock>[
      WorkoutBlock(
        repeat: 1,
        steps: <WorkoutStep>[
          WorkoutStep(
            type: StepType.warmup,
            goalType: StepGoalType.time,
            goalSeconds: 900, // 15 minuti
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
                fastestSecPerKm: 240, slowestSecPerKm: 250),
          ),
          WorkoutStep(
            type: StepType.recovery,
            goalType: StepGoalType.distance,
            goalDistanceMeters: 200,
          ),
        ],
      ),
      WorkoutBlock(
        repeat: 1,
        steps: <WorkoutStep>[
          WorkoutStep(
            type: StepType.cooldown,
            goalType: StepGoalType.time,
            goalSeconds: 600,
          ),
        ],
      ),
    ],
  );
}

void main() {
  group('Workout.expand', () {
    test('il gruppo ripetuto viene espanso in step reali', () {
      final Workout workout = _buildWorkout();
      final List<ResolvedStep> steps = workout.expand();
      // 1 riscaldamento + (10 x 2) + 1 defaticamento = 22
      expect(steps.length, 22);
      expect(steps.first.step.type, StepType.warmup);
      expect(steps.last.step.type, StepType.cooldown);
    });

    test('gli indici di ripetizione sono corretti', () {
      final List<ResolvedStep> steps = _buildWorkout().expand();
      // steps[1] = prima ripetuta, steps[3] = seconda ripetuta
      expect(steps[1].repetitionIndex, 1);
      expect(steps[1].repetitionTotal, 10);
      expect(steps[3].repetitionIndex, 2);
      expect(steps[1].label, 'Ripetuta 1/10');
    });
  });

  group('WorkoutEngine', () {
    test('parte dal primo step', () {
      final WorkoutEngine engine = WorkoutEngine(_buildWorkout());
      final List<WorkoutEvent> events = engine.start();
      expect(events.first.type, WorkoutEventType.started);
      expect(engine.currentStep?.step.type, StepType.warmup);
      expect(engine.totalSteps, 22);
    });

    test('passa allo step successivo al termine del tempo', () {
      final WorkoutEngine engine = WorkoutEngine(_buildWorkout());
      engine.start();

      engine.update(totalDistanceMeters: 1000, totalActiveSeconds: 600);
      expect(engine.currentStep?.step.type, StepType.warmup);
      expect(engine.remainingSeconds, 300);

      final List<WorkoutEvent> events =
          engine.update(totalDistanceMeters: 2500, totalActiveSeconds: 900);
      expect(
        events.any((WorkoutEvent e) => e.type == WorkoutEventType.stepStarted),
        isTrue,
      );
      expect(engine.currentStep?.step.type, StepType.interval);
      expect(engine.repetitionIndex, 1);
    });

    test('passa allo step successivo al termine della distanza', () {
      final WorkoutEngine engine = WorkoutEngine(_buildWorkout());
      engine.start();
      // Fine riscaldamento.
      engine.update(totalDistanceMeters: 2500, totalActiveSeconds: 900);
      expect(engine.currentStep?.step.type, StepType.interval);

      // 200 m della ripetuta: ancora dentro.
      engine.update(totalDistanceMeters: 2700, totalActiveSeconds: 950);
      expect(engine.currentStep?.step.type, StepType.interval);
      expect(engine.remainingMeters, closeTo(200, 0.01));

      // 400 m completati: si passa al recupero.
      engine.update(totalDistanceMeters: 2900, totalActiveSeconds: 1000);
      expect(engine.currentStep?.step.type, StepType.recovery);
    });

    test('emette il countdown prima della fine di uno step a tempo', () {
      final WorkoutEngine engine = WorkoutEngine(_buildWorkout());
      engine.start();
      final List<WorkoutEvent> events =
          engine.update(totalDistanceMeters: 1000, totalActiveSeconds: 890);
      final Iterable<WorkoutEvent> countdowns = events
          .where((WorkoutEvent e) => e.type == WorkoutEventType.countdown);
      expect(countdowns.length, 1);
      expect(countdowns.first.countdownSeconds, 10);
    });

    test('non ripete lo stesso countdown', () {
      final WorkoutEngine engine = WorkoutEngine(_buildWorkout());
      engine.start();
      engine.update(totalDistanceMeters: 1000, totalActiveSeconds: 890);
      final List<WorkoutEvent> again =
          engine.update(totalDistanceMeters: 1000, totalActiveSeconds: 891);
      expect(
        again.any((WorkoutEvent e) => e.type == WorkoutEventType.countdown),
        isFalse,
      );
    });

    test('termina dopo l\'ultimo step', () {
      final WorkoutEngine engine = WorkoutEngine(_buildWorkout());
      engine.start();

      // Simulazione: 20 metri ogni 10 secondi (2 m/s) fino alla fine.
      double distance = 0;
      int seconds = 0;
      bool finishedEmitted = false;
      for (int i = 0; i < 3000 && !engine.isFinished; i++) {
        distance += 20;
        seconds += 10;
        final List<WorkoutEvent> events = engine.update(
          totalDistanceMeters: distance,
          totalActiveSeconds: seconds,
        );
        if (events
            .any((WorkoutEvent e) => e.type == WorkoutEventType.finished)) {
          finishedEmitted = true;
        }
      }

      expect(engine.isFinished, isTrue);
      expect(finishedEmitted, isTrue);
      expect(engine.overallProgress, 1.0);
    });

    test('skipToNextStep salta la fase corrente', () {
      final WorkoutEngine engine = WorkoutEngine(_buildWorkout());
      engine.start();
      engine.skipToNextStep();
      expect(engine.currentStep?.step.type, StepType.interval);
    });
  });

  group('PaceTarget', () {
    const PaceTarget target =
        PaceTarget(fastestSecPerKm: 240, slowestSecPerKm: 250);

    test('dentro il target', () {
      expect(target.evaluate(245), PaceStatus.onTarget);
    });

    test('troppo veloce', () {
      expect(target.evaluate(230), PaceStatus.tooFast);
    });

    test('troppo lento', () {
      expect(target.evaluate(280), PaceStatus.tooSlow);
    });

    test('senza dati', () {
      expect(target.evaluate(null), PaceStatus.unknown);
      expect(const PaceTarget().evaluate(245), PaceStatus.unknown);
    });

    test('etichetta leggibile', () {
      expect(target.label, '4:00-4:10 /km');
    });
  });
}
