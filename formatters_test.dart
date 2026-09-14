import 'package:flutter_test/flutter_test.dart';
import 'package:run_coach_app/utils/formatters.dart';

void main() {
  group('formatDuration', () {
    test('sotto l\'ora usa mm:ss', () {
      expect(formatDuration(const Duration(minutes: 5, seconds: 3)), '05:03');
    });

    test('sopra l\'ora usa h:mm:ss', () {
      expect(
        formatDuration(const Duration(hours: 1, minutes: 2, seconds: 4)),
        '1:02:04',
      );
    });

    test('zero', () {
      expect(formatDuration(Duration.zero), '00:00');
    });
  });

  group('formatDistanceKm', () {
    test('due decimali', () {
      expect(formatDistanceKm(8543.2), '8.54');
    });

    test('valori negativi o non validi diventano zero', () {
      expect(formatDistanceKm(-10), '0.00');
      expect(formatDistanceKm(double.nan), '0.00');
    });

    test('con unita', () {
      expect(formatDistanceKmWithUnit(8543.2), '8.54 km');
    });
  });

  group('formatDistanceAuto', () {
    test('sotto il chilometro mostra i metri', () {
      expect(formatDistanceAuto(400), '400 m');
    });

    test('sopra il chilometro mostra i km', () {
      expect(formatDistanceAuto(1500), '1.50 km');
    });
  });

  group('formatPace', () {
    test('formato minuti:secondi', () {
      expect(formatPace(323), '5:23');
    });

    test('nessun dato disponibile', () {
      expect(formatPace(null), '--:--');
      expect(formatPace(0), '--:--');
      expect(formatPace(-5), '--:--');
      expect(formatPace(double.infinity), '--:--');
    });

    test('valori assurdi vengono scartati', () {
      expect(formatPace(99999), '--:--');
    });

    test('con unita', () {
      expect(formatPaceWithUnit(240), '4:00 /km');
    });

    test('intervallo target', () {
      expect(formatPaceRange(240, 250), '4:00-4:10 /km');
    });
  });

  group('paceFromDistanceAndTime', () {
    test('calcolo corretto', () {
      // 1000 m in 300 s -> 5:00 /km
      expect(paceFromDistanceAndTime(1000, 300), 300);
    });

    test('nessuna divisione per zero', () {
      expect(paceFromDistanceAndTime(0, 0), isNull);
      expect(paceFromDistanceAndTime(1000, 0), isNull);
      expect(paceFromDistanceAndTime(5, 60), isNull);
    });
  });

  group('speedToPace', () {
    test('conversione', () {
      final double? pace = speedToPace(4.0); // 4 m/s = 250 s/km
      expect(pace, isNotNull);
      expect(pace!.round(), 250);
    });

    test('velocita nulla non produce passo', () {
      expect(speedToPace(0), isNull);
      expect(speedToPace(null), isNull);
    });
  });

  group('date', () {
    test('formato breve', () {
      expect(formatDateShort(DateTime(2026, 8, 28)), '28/08/2026');
    });

    test('giorno relativo', () {
      final DateTime now = DateTime(2026, 8, 28, 12);
      expect(formatRelativeDay(now, now: now), 'oggi');
      expect(
        formatRelativeDay(now.subtract(const Duration(days: 1)), now: now),
        'ieri',
      );
    });
  });
}
