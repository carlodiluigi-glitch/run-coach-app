import 'package:flutter_test/flutter_test.dart';
import 'package:run_coach_app/models/running_activity.dart';
import 'package:run_coach_app/services/stats_service.dart';

RunningActivity _activity({
  required DateTime when,
  required double meters,
  required int seconds,
}) {
  return RunningActivity(
    startTime: when,
    name: 'Corsa',
    type: ActivityType.free,
    durationSeconds: seconds,
    distanceMeters: meters,
  );
}

void main() {
  const StatsService service = StatsService();
  // Mercoledi' 26 agosto 2026: la settimana inizia lunedi' 24.
  final DateTime now = DateTime(2026, 8, 26, 18);

  group('compute', () {
    test('storico vuoto', () {
      final RunningStats stats =
          service.compute(<RunningActivity>[], now: now);
      expect(stats.isEmpty, isTrue);
      expect(stats.weekKm, 0);
      expect(stats.lastActivity, isNull);
    });

    test('somma i chilometri della settimana corrente', () {
      final List<RunningActivity> activities = <RunningActivity>[
        _activity(
            when: DateTime(2026, 8, 24, 7), meters: 10000, seconds: 3000),
        _activity(
            when: DateTime(2026, 8, 25, 7), meters: 5000, seconds: 1500),
        // Settimana precedente: non deve entrare nel conteggio settimanale.
        _activity(
            when: DateTime(2026, 8, 20, 7), meters: 8000, seconds: 2400),
      ];
      final RunningStats stats = service.compute(activities, now: now);
      expect(stats.weekKm, closeTo(15.0, 0.001));
      expect(stats.weekActivities, 2);
      expect(stats.totalKm, closeTo(23.0, 0.001));
      expect(stats.totalActivities, 3);
      expect(stats.longestRunMeters, 10000);
    });

    test('ultima attivita e la piu recente', () {
      final List<RunningActivity> activities = <RunningActivity>[
        _activity(
            when: DateTime(2026, 8, 20, 7), meters: 8000, seconds: 2400),
        _activity(
            when: DateTime(2026, 8, 25, 7), meters: 5000, seconds: 1500),
      ];
      final RunningStats stats = service.compute(activities, now: now);
      expect(stats.lastActivity?.startTime, DateTime(2026, 8, 25, 7));
    });

    test('startOfWeek restituisce il lunedi', () {
      expect(
        StatsService.startOfWeek(DateTime(2026, 8, 26, 18)),
        DateTime(2026, 8, 24),
      );
    });
  });

  group('computePaceImprovement', () {
    test('senza dati sufficienti non inventa percentuali', () {
      final ImprovementResult result = service.computePaceImprovement(
        <RunningActivity>[
          _activity(
              when: DateTime(2026, 8, 25), meters: 5000, seconds: 1500),
        ],
        now: now,
      );
      expect(result.hasEnoughData, isFalse);
      expect(result.percentChange, isNull);
      expect(result.message, contains('Servono piu'));
    });

    test('rileva un miglioramento del passo', () {
      final List<RunningActivity> activities = <RunningActivity>[
        // Periodo recente: 5 km in 25:00 (5:00/km)
        _activity(
            when: now.subtract(const Duration(days: 3)),
            meters: 5000,
            seconds: 1500),
        _activity(
            when: now.subtract(const Duration(days: 10)),
            meters: 5000,
            seconds: 1500),
        // Periodo precedente: 5 km in 26:40 (5:20/km)
        _activity(
            when: now.subtract(const Duration(days: 35)),
            meters: 5000,
            seconds: 1600),
        _activity(
            when: now.subtract(const Duration(days: 45)),
            meters: 5000,
            seconds: 1600),
      ];
      final ImprovementResult result =
          service.computePaceImprovement(activities, now: now);
      expect(result.hasEnoughData, isTrue);
      expect(result.percentChange, isNotNull);
      expect(result.percentChange! < 0, isTrue);
      expect(result.message, contains('migliorato'));
    });
  });

  group('computeVolumeTrend', () {
    test('senza settimane precedenti non calcola nulla', () {
      final ImprovementResult result = service.computeVolumeTrend(
        <RunningActivity>[
          _activity(
              when: DateTime(2026, 8, 25), meters: 5000, seconds: 1500),
        ],
        now: now,
      );
      expect(result.hasEnoughData, isFalse);
    });

    test('confronta con la media delle 4 settimane precedenti', () {
      final List<RunningActivity> activities = <RunningActivity>[
        _activity(
            when: DateTime(2026, 8, 25), meters: 20000, seconds: 6000),
        _activity(
            when: DateTime(2026, 8, 18), meters: 10000, seconds: 3000),
        _activity(
            when: DateTime(2026, 8, 11), meters: 10000, seconds: 3000),
      ];
      final ImprovementResult result =
          service.computeVolumeTrend(activities, now: now);
      expect(result.hasEnoughData, isTrue);
      expect(result.percentChange, isNotNull);
      expect(result.percentChange! > 0, isTrue);
    });
  });
}
