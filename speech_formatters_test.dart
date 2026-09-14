import 'package:flutter_test/flutter_test.dart';
import 'package:run_coach_app/utils/speech_formatters.dart';

void main() {
  group('spokenDuration', () {
    test('solo secondi', () {
      expect(spokenDuration(45), '45 secondi');
      expect(spokenDuration(1), '1 secondo');
    });

    test('minuti tondi', () {
      expect(spokenDuration(900), '15 minuti');
      expect(spokenDuration(60), 'un minuto');
    });

    test('minuti e secondi', () {
      expect(spokenDuration(95), 'un minuto e 35 secondi');
    });

    test('ore', () {
      expect(spokenDuration(3600), 'un\'ora');
      expect(spokenDuration(5400), 'un\'ora e 30 minuti');
    });
  });

  group('spokenDistance', () {
    test('sotto il chilometro', () {
      expect(spokenDistance(400), '400 metri');
      expect(spokenDistance(1), '1 metro');
    });

    test('chilometri tondi', () {
      expect(spokenDistance(1000), 'un chilometro');
      expect(spokenDistance(2000), '2 chilometri');
    });

    test('chilometri e metri arrotondati al centinaio', () {
      expect(spokenDistance(8540), '8 chilometri e 500 metri');
    });

    test('valori non validi', () {
      expect(spokenDistance(-5), 'zero metri');
      expect(spokenDistance(double.nan), 'zero metri');
    });
  });

  group('spokenPace', () {
    test('minuti e secondi', () {
      expect(spokenPace(323), '5 e 23 al chilometro');
    });

    test('minuti netti', () {
      expect(spokenPace(300), '5 minuti netti al chilometro');
    });

    test('secondi sotto il dieci mantengono lo zero', () {
      expect(spokenPace(305), '5 e 05 al chilometro');
    });

    test('niente numeri inventati senza dati attendibili', () {
      expect(spokenPace(null), isNull);
      expect(spokenPace(0), isNull);
      expect(spokenPace(-10), isNull);
      expect(spokenPace(99999), isNull);
    });
  });

  group('spokenNumber', () {
    test('numeri piccoli in lettere', () {
      expect(spokenNumber(0), 'zero');
      expect(spokenNumber(10), 'dieci');
      expect(spokenNumber(20), 'venti');
    });

    test('numeri grandi restano cifre', () {
      expect(spokenNumber(21), '21');
      expect(spokenNumber(400), '400');
    });
  });

  group('spokenSpeedKmh', () {
    test('usa la virgola decimale', () {
      expect(spokenSpeedKmh(4.0), '14,4 chilometri orari');
    });

    test('velocita non disponibile', () {
      expect(spokenSpeedKmh(null), 'velocita non disponibile');
      expect(spokenSpeedKmh(0), 'velocita non disponibile');
    });
  });
}
