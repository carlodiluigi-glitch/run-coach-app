import 'package:flutter_test/flutter_test.dart';
import 'package:run_coach_app/models/running_activity.dart';
import 'package:run_coach_app/services/records_service.dart';

/// Costruisce un tracciato rettilineo verso nord a velocita' costante.
///
/// Un grado di latitudine vale circa 111.195 metri: usando quel rapporto si
/// ottiene un percorso di lunghezza nota, con cui verificare i tempi attesi.
List<RoutePoint> straightRoute({
  required double totalMeters,
  required double metersPerSecond,
  double stepMeters = 10,
  double startLat = 45.0,
}) {
  const double metersPerDegree = 111195.0;
  final List<RoutePoint> points = <RoutePoint>[];
  double covered = 0;
  while (covered <= totalMeters) {
    points.add(RoutePoint(
      latitude: startLat + covered / metersPerDegree,
      longitude: 9.0,
      elapsedSeconds: (covered / metersPerSecond).round(),
    ));
    covered += stepMeters;
  }
  return points;
}

/// Tracciato in due tratti: il primo lento, il secondo veloce.
List<RoutePoint> twoPaceRoute({
  required double slowMeters,
  required double slowSpeed,
  required double fastMeters,
  required double fastSpeed,
  double stepMeters = 10,
}) {
  const double metersPerDegree = 111195.0;
  final List<RoutePoint> points = <RoutePoint>[];
  double covered = 0;
  double time = 0;
  while (covered <= slowMeters + fastMeters) {
    points.add(RoutePoint(
      latitude: 45.0 + covered / metersPerDegree,
      longitude: 9.0,
      elapsedSeconds: time.round(),
    ));
    final double speed = covered < slowMeters ? slowSpeed : fastSpeed;
    time += stepMeters / speed;
    covered += stepMeters;
  }
  return points;
}

void main() {
  const RecordsService service = RecordsService();

  group('fastestTimeForDistance', () {
    test('velocita costante: tempo atteso sul chilometro', () {
      // 3 km a 4 m/s -> il km piu' veloce vale 250 secondi.
      final List<RoutePoint> route =
          straightRoute(totalMeters: 3000, metersPerSecond: 4.0);
      final int? seconds = service.fastestTimeForDistance(route, 1000);

      expect(seconds, isNotNull);
      expect(seconds, closeTo(250, 3));
    });

    test('trova il tratto veloce dentro una corsa lenta', () {
      // 2 km a 3 m/s, poi 1 km a 5 m/s: il km migliore deve valere ~200 s,
      // non i 333 s del tratto lento.
      final List<RoutePoint> route = twoPaceRoute(
        slowMeters: 2000,
        slowSpeed: 3.0,
        fastMeters: 1000,
        fastSpeed: 5.0,
      );
      final int? seconds = service.fastestTimeForDistance(route, 1000);

      expect(seconds, isNotNull);
      expect(seconds, closeTo(200, 6));
    });

    test('corsa piu corta del target: nessun record', () {
      final List<RoutePoint> route =
          straightRoute(totalMeters: 800, metersPerSecond: 4.0);
      expect(service.fastestTimeForDistance(route, 1000), isNull);
    });

    test('tracciato vuoto o con un solo punto', () {
      expect(service.fastestTimeForDistance(<RoutePoint>[], 1000), isNull);
      expect(
        service.fastestTimeForDistance(
          <RoutePoint>[
            const RoutePoint(latitude: 45, longitude: 9, elapsedSeconds: 0),
          ],
          1000,
        ),
        isNull,
      );
    });

    test('target non valido', () {
      final List<RoutePoint> route =
          straightRoute(totalMeters: 3000, metersPerSecond: 4.0);
      expect(service.fastestTimeForDistance(route, 0), isNull);
      expect(service.fastestTimeForDistance(route, -100), isNull);
    });

    test('distanze maggiori non sono mai piu veloci di quelle minori', () {
      final List<RoutePoint> route =
          straightRoute(totalMeters: 6000, metersPerSecond: 4.0);
      final int? oneKm = service.fastestTimeForDistance(route, 1000);
      final int? fiveKm = service.fastestTimeForDistance(route, 5000);

      expect(oneKm, isNotNull);
      expect(fiveKm, isNotNull);
      expect(fiveKm! > oneKm!, isTrue);
    });
  });

  group('compute', () {
    RunningActivity buildActivity({
      required String id,
      required DateTime when,
      required double meters,
      required double speed,
    }) {
      final List<RoutePoint> route =
          straightRoute(totalMeters: meters, metersPerSecond: speed);
      return RunningActivity(
        id: id,
        startTime: when,
        name: 'Corsa $id',
        type: ActivityType.free,
        durationSeconds: (meters / speed).round(),
        distanceMeters: meters,
        route: route,
      );
    }

    test('storico vuoto', () {
      final PersonalRecords records = service.compute(<RunningActivity>[]);
      expect(records.isEmpty, isTrue);
      expect(records.byDistance, isEmpty);
      expect(records.longestRun, isNull);
      expect(records.totalActivities, 0);
    });

    test('tiene il tempo migliore fra piu corse', () {
      final List<RunningActivity> activities = <RunningActivity>[
        buildActivity(
            id: 'lenta',
            when: DateTime(2026, 9, 1),
            meters: 5200,
            speed: 3.0),
        buildActivity(
            id: 'veloce',
            when: DateTime(2026, 9, 8),
            meters: 5200,
            speed: 4.0),
      ];

      final PersonalRecords records = service.compute(activities);
      final DistanceRecord? fiveKm = records.recordFor('5k');

      expect(fiveKm, isNotNull);
      expect(fiveKm!.activityId, 'veloce');
      expect(fiveKm.seconds, closeTo(1250, 20));
    });

    test('non inventa record su distanze mai raggiunte', () {
      final List<RunningActivity> activities = <RunningActivity>[
        buildActivity(
            id: 'a', when: DateTime(2026, 9, 1), meters: 3200, speed: 3.5),
      ];

      final PersonalRecords records = service.compute(activities);
      expect(records.recordFor('1k'), isNotNull);
      expect(records.recordFor('3k'), isNotNull);
      expect(records.recordFor('5k'), isNull);
      expect(records.recordFor('marathon'), isNull);
    });

    test('corsa piu lunga e settimana migliore', () {
      final List<RunningActivity> activities = <RunningActivity>[
        buildActivity(
            id: 'corta',
            when: DateTime(2026, 9, 1),
            meters: 4000,
            speed: 3.0),
        buildActivity(
            id: 'lunga',
            when: DateTime(2026, 9, 2),
            meters: 12000,
            speed: 3.0),
        buildActivity(
            id: 'altra',
            when: DateTime(2026, 9, 14),
            meters: 5000,
            speed: 3.0),
      ];

      final PersonalRecords records = service.compute(activities);
      expect(records.longestRun?.id, 'lunga');
      // 1 e 2 settembre 2026 cadono nella stessa settimana: 4 + 12 = 16 km.
      expect(records.bestWeekKm, closeTo(16.0, 0.3));
      expect(records.totalActivities, 3);
      expect(records.activitiesWithGps, 3);
    });

    test('attivita senza tracciato non producono record di distanza', () {
      final RunningActivity noGps = RunningActivity(
        id: 'senza',
        startTime: DateTime(2026, 9, 1),
        name: 'Inserita a mano',
        type: ActivityType.free,
        durationSeconds: 1800,
        distanceMeters: 6000,
      );

      final PersonalRecords records =
          service.compute(<RunningActivity>[noGps]);
      expect(records.byDistance, isEmpty);
      expect(records.activitiesWithGps, 0);
      // La corsa piu' lunga si basa sulla distanza salvata, quindi c'e'.
      expect(records.longestRun?.id, 'senza');
    });

    test('i record sono ordinati per distanza crescente', () {
      final List<RunningActivity> activities = <RunningActivity>[
        buildActivity(
            id: 'a', when: DateTime(2026, 9, 1), meters: 11000, speed: 3.5),
      ];
      final PersonalRecords records = service.compute(activities);
      final List<String> keys = records.byDistance
          .map((DistanceRecord r) => r.distance.key)
          .toList();
      expect(keys, <String>['1k', '3k', '5k', '10k']);
    });
  });
}
