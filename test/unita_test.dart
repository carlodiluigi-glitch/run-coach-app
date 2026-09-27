import 'package:flutter_test/flutter_test.dart';
import 'package:run_coach_app/models/user_settings.dart';
import 'package:run_coach_app/utils/formatters.dart';
import 'package:run_coach_app/utils/speech_formatters.dart';
import 'package:run_coach_app/utils/units.dart';

/// Chilometri e miglia.
///
/// Il test piu' importante di questo file e' l'ultimo: cambiare unita' non
/// deve toccare i dati. Se un giorno le miglia finissero dentro i file
/// salvati, il primo cambio di impostazione trasformerebbe dieci chilometri
/// in dieci miglia e lo storico sarebbe da buttare.
void main() {
  tearDown(() => activeUnits = UnitSystem.metric);

  group('distanze', () {
    test('dieci chilometri', () {
      expect(formatDistanceWithUnit(10000, units: UnitSystem.metric),
          '10.00 km');
      expect(formatDistanceWithUnit(10000, units: UnitSystem.imperial),
          '6.21 mi');
    });

    test('le distanze corte restano in metri in entrambi i sistemi', () {
      // In pista si corrono i 400, non le 437 iarde: e' metrico anche negli
      // Stati Uniti.
      expect(formatDistanceAuto(400, units: UnitSystem.metric), '400 m');
      expect(formatDistanceAuto(400, units: UnitSystem.imperial), '400 m');
    });

    test('la mezza maratona', () {
      expect(formatDistanceWithUnit(21097.5, units: UnitSystem.imperial),
          '13.11 mi');
    });
  });

  group('passi', () {
    test('cinque al chilometro sono otto e tre al miglio', () {
      expect(formatPaceWithUnit(300, units: UnitSystem.metric), '5:00 /km');
      expect(formatPaceWithUnit(300, units: UnitSystem.imperial), '8:03 /mi');
    });

    test('intervallo di passo', () {
      expect(formatPaceRange(280, 300, units: UnitSystem.metric),
          '4:40-5:00 /km');
      expect(formatPaceRange(280, 300, units: UnitSystem.imperial),
          '7:31-8:03 /mi');
    });

    test('il passo non attendibile resta vuoto in entrambi', () {
      expect(formatPace(null, units: UnitSystem.imperial), '--:--');
      expect(formatPace(0, units: UnitSystem.imperial), '--:--');
    });
  });

  group('velocita\'', () {
    test('tre metri al secondo', () {
      expect(formatSpeed(3, units: UnitSystem.metric), '10.8 km/h');
      expect(formatSpeed(3, units: UnitSystem.imperial), '6.7 mph');
    });
  });

  group('la voce', () {
    test('dice al miglio quando serve', () {
      expect(spokenPace(300, units: UnitSystem.metric),
          '5 minuti netti al chilometro');
      expect(
          spokenPace(300, units: UnitSystem.imperial), '8 e 03 al miglio');
    });

    test('le distanze parlate seguono l\'unita\'', () {
      expect(spokenDistance(2000, units: UnitSystem.metric), '2 chilometri');
      expect(spokenDistance(1609, units: UnitSystem.imperial), 'un miglio');
      expect(spokenDistance(400, units: UnitSystem.imperial), '400 metri');
    });

    test('la velocita\' parlata segue l\'unita\'', () {
      expect(spokenSpeed(3, units: UnitSystem.metric),
          contains('chilometri orari'));
      expect(spokenSpeed(3, units: UnitSystem.imperial),
          contains('miglia orarie'));
    });
  });

  group('l\'impostazione globale', () {
    test('di partenza e\' metrica', () {
      expect(activeUnits, UnitSystem.metric);
      expect(formatDistanceWithUnit(5000), '5.00 km');
    });

    test('cambiandola cambia come si scrive', () {
      activeUnits = UnitSystem.imperial;
      expect(formatDistanceWithUnit(5000), '3.11 mi');
      expect(formatPaceWithUnit(300), '8:03 /mi');
    });
  });

  group('i dati non si toccano', () {
    test('il passo calcolato resta in secondi al chilometro', () {
      // 10 km in 44:00 fa 264 secondi al chilometro, in qualunque unita' li
      // si scriva poi sullo schermo.
      activeUnits = UnitSystem.imperial;
      expect(paceFromDistanceAndTime(10000, 2640), closeTo(264, 0.01));
      activeUnits = UnitSystem.metric;
      expect(paceFromDistanceAndTime(10000, 2640), closeTo(264, 0.01));
    });

    test('andata e ritorno non perde niente', () {
      for (final UnitSystem u in UnitSystem.values) {
        expect(u.distanceToMeters(u.distanceFrom(8543.2)), closeTo(8543.2, 0.001));
        expect(u.paceToSecondsPerKm(u.paceFrom(264)), closeTo(264, 0.001));
      }
    });
  });
}
