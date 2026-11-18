import 'package:flutter_test/flutter_test.dart';
import 'package:run_coach_app/models/effort.dart';
import 'package:run_coach_app/models/estimate.dart';
import 'package:run_coach_app/models/lap.dart';
import 'package:run_coach_app/models/running_activity.dart';
import 'package:run_coach_app/models/workout_step.dart';
import 'package:run_coach_app/services/coach_export.dart';
import 'package:run_coach_app/services/run_index_engine.dart';

/// Il 4 x 1000 avviato e non fatto, e le faccine di fine corsa.
///
/// Il caso vero: avviato il 4 x 1000 del piano, a meta' Carlo si accorge che
/// non e' giornata e finisce correndo tranquillo. L'app lo registrava come
/// "Lavoro 4 x 1000", e il motore di forma leggeva i quattro mille corsi
/// piano come ripetute vere: un indice che scende per una seduta mai fatta.
void main() {
  const RunIndexEngine engine = RunIndexEngine();
  const CoachExport export = CoachExport();
  final DateTime now = DateTime(2026, 11, 18, 20);

  Lap fase(int n, double metri, int secondi, StepType tipo, String nome) =>
      Lap(
        number: n,
        distanceMeters: metri,
        durationSeconds: secondi,
        totalTimeSeconds: 0,
        stepLabel: nome,
        stepKind: tipo.storageKey,
      );

  /// Il 4 x 1000 "fatto" a 6:00 al km: corso piano dall'inizio alla fine.
  RunningActivity quattroPerMille({String? saltato}) {
    final List<Lap> laps = <Lap>[
      fase(1, 2000, 760, StepType.warmup, 'Riscaldamento'),
    ];
    int n = 2;
    for (int i = 1; i <= 4; i++) {
      laps.add(fase(n++, 1000, 360, StepType.interval, 'Ripetuta $i/4'));
      if (i < 4) laps.add(fase(n++, 200, 90, StepType.recovery, 'Recupero'));
    }
    laps.add(fase(n, 1000, 380, StepType.cooldown, 'Defaticamento'));
    return RunningActivity(
      id: 'act_4x1000',
      startTime: DateTime(2026, 11, 18, 18),
      name: saltato == null ? '4 x 1000' : 'Corsa libera',
      skippedWorkoutName: saltato,
      type: ActivityType.workout,
      durationSeconds: 760 + 4 * 360 + 3 * 90 + 380,
      distanceMeters: 7600,
      laps: laps,
      route: const <RoutePoint>[
        RoutePoint(latitude: 45.0, longitude: 9.0, elapsedSeconds: 0),
        RoutePoint(latitude: 45.0, longitude: 9.0, elapsedSeconds: 1),
      ],
    );
  }

  group('il lavoro non fatto', () {
    test('fatto: i mille contano come ripetute', () {
      final List<PerformanceSample> s = engine.samplesFromActivities(
        <RunningActivity>[quattroPerMille()],
        now: now,
      );
      expect(
        s.where((PerformanceSample x) => x.source == EstimateSource.workout),
        isNotEmpty,
      );
    });

    test('non fatto: nessuna ripetuta, nessuna seduta di qualita\'', () {
      final List<PerformanceSample> s = engine.samplesFromActivities(
        <RunningActivity>[quattroPerMille(saltato: '4 x 1000')],
        now: now,
      );
      expect(
        s.where((PerformanceSample x) => x.source == EstimateSource.workout),
        isEmpty,
        reason: 'quattro mille corsi piano non sono quattro ripetute',
      );
    });

    test('la corsa sa cosa era previsto', () {
      final RunningActivity a = quattroPerMille(saltato: '4 x 1000');
      expect(a.workoutSkipped, isTrue);
      expect(a.isStructuredWorkout, isFalse);
      expect(quattroPerMille().isStructuredWorkout, isTrue);
      expect(quattroPerMille().workoutSkipped, isFalse);
    });

    test('si salva, si rilegge e si torna indietro', () {
      final RunningActivity a = quattroPerMille(saltato: '4 x 1000');
      final RunningActivity letta = RunningActivity.fromJson(a.toJson());
      expect(letta.skippedWorkoutName, '4 x 1000');
      expect(letta.name, 'Corsa libera');

      final RunningActivity indietro = letta.copyWith(
        name: letta.skippedWorkoutName,
        clearSkippedWorkout: true,
      );
      expect(indietro.workoutSkipped, isFalse);
      expect(indietro.name, '4 x 1000');
    });

    test('le corse di prima non diventano "non fatte"', () {
      final Map<String, dynamic> json = quattroPerMille().toJson()
        ..remove('lavoroNonFatto');
      expect(RunningActivity.fromJson(json).workoutSkipped, isFalse);
    });

    test('il coach legge una corsa libera e sa cosa era previsto', () {
      final String t = export.build(
        now: now,
        activities: <RunningActivity>[quattroPerMille(saltato: '4 x 1000')],
      );
      expect(t, contains('era previsto "4 x 1000"'));
      expect(t, contains('il lavoro non e\' stato fatto'));
      expect(t, isNot(contains('(lavoro)')),
          reason: 'i tratti corsi piano non vanno presentati come lavoro');
      expect(t, isNot(contains('[misurato] solo i tratti di lavoro')));
    });
  });

  group('le faccine', () {
    test('cinque, dal meglio al peggio', () {
      expect(RunSatisfaction.values.length, 5);
      expect(RunSatisfaction.benissimo.score, 5);
      expect(RunSatisfaction.malissimo.score, 1);
      expect(RunSatisfaction.cosiCosi.label, 'Così così');
    });

    test('si salvano e si rileggono, anche senza fatica', () {
      final RunningActivity a = RunningActivity(
        startTime: DateTime(2026, 11, 18, 18),
        name: 'Corsa libera',
        type: ActivityType.free,
        durationSeconds: 1800,
        distanceMeters: 5000,
        satisfaction: RunSatisfaction.bene,
      );
      final RunningActivity letta = RunningActivity.fromJson(a.toJson());
      expect(letta.satisfaction, RunSatisfaction.bene);
      expect(letta.feedback, isNull);
      expect(letta.copyWith(clearSatisfaction: true).satisfaction, isNull);
    });

    test('un valore sconosciuto nel file non rompe niente', () {
      final Map<String, dynamic> json = RunningActivity(
        startTime: DateTime(2026, 11, 18, 18),
        name: 'Corsa libera',
        type: ActivityType.free,
        durationSeconds: 1800,
        distanceMeters: 5000,
      ).toJson()
        ..['umore'] = 'euforico';
      expect(RunningActivity.fromJson(json).satisfaction, isNull);
    });

    test('arrivano al coach', () {
      final String t = export.build(
        now: now,
        activities: <RunningActivity>[
          RunningActivity(
            startTime: DateTime(2026, 11, 18, 18),
            name: 'Corsa libera',
            type: ActivityType.free,
            durationSeconds: 1800,
            distanceMeters: 5000,
            satisfaction: RunSatisfaction.male,
          ),
        ],
      );
      expect(t, contains('com\'e\' andata, a sensazione: male (2/5)'));
    });
  });
}
