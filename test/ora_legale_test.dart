import 'package:flutter_test/flutter_test.dart';
import 'package:run_coach_app/models/estimate.dart';
import 'package:run_coach_app/models/running_activity.dart';
import 'package:run_coach_app/services/pace_zone_engine.dart';
import 'package:run_coach_app/services/stats_service.dart';
import 'package:run_coach_app/services/training_load_engine.dart';
import 'package:run_coach_app/utils/formatters.dart';
import 'package:run_coach_app/utils/giorni.dart';

/// Il cambio dell'ora del 25 ottobre 2026.
///
/// Quel giorno e' durato 25 ore, e il codice che contava i giorni a blocchi
/// di 24 ore ha sbagliato tre cose in una volta: il grafico di fatica non
/// vedeva piu' le corse, le barre del volume erano spostate di una settimana,
/// e il confronto col volume medio diceva -25% su una settimana nella media.
///
/// QUESTI TEST HANNO SENSO SOLO CON L'ORA ITALIANA. Sul server di GitHub
/// l'ora e' quella di Greenwich, senza ora legale, e qualunque conto
/// sbagliato passa lo stesso: e' cosi' che il difetto era arrivato sul
/// telefono. Per questo la compilazione li fa girare una seconda volta con
/// TZ=Europe/Rome (vedi .github/workflows/android.yml).
void main() {
  test('i test girano con l\'ora italiana (avviso, non errore)', () {
    // Non fallisce: dice solo se questo giro ha messo davvero alla prova il
    // cambio d'ora. Con l'ora di Greenwich i test qui sotto passano comunque.
    final bool legale = DateTime(2026, 10, 24).timeZoneOffset !=
        DateTime(2026, 10, 26).timeZoneOffset;
    // ignore: avoid_print
    print(legale
        ? 'ora_legale_test: ora locale con cambio d\'ora, prova vera.'
        : 'ora_legale_test: ora senza cambio d\'ora, prova solo formale.');
  });

  group('i giorni si contano col calendario', () {
    test('dal sabato al lunedi\' a cavallo del cambio sono due giorni', () {
      expect(giorniFra(DateTime(2026, 10, 24, 20), DateTime(2026, 10, 26, 8)),
          2);
      expect(giorniFra(DateTime(2026, 10, 26), DateTime(2026, 10, 24)), -2);
    });

    test('il giorno dopo il 25 ottobre e\' il 26, a mezzanotte', () {
      expect(piuGiorni(DateTime(2026, 10, 25), 1), DateTime(2026, 10, 26));
      expect(piuGiorni(DateTime(2026, 10, 25, 18, 30), 1),
          DateTime(2026, 10, 26));
      // Anche in primavera, quando il giorno dura 23 ore.
      expect(piuGiorni(DateTime(2026, 3, 29), 1), DateTime(2026, 3, 30));
    });

    test('sette settimane indietro da lunedi\' 26 ottobre e\' il 7 settembre',
        () {
      expect(piuGiorni(DateTime(2026, 10, 26), -49), DateTime(2026, 9, 7));
    });

    test('ieri e\' ieri anche il lunedi\' dopo il cambio', () {
      expect(
          formatRelativeDay(DateTime(2026, 10, 25, 9),
              now: DateTime(2026, 10, 26, 9)),
          'ieri');
      expect(
          formatRelativeDay(DateTime(2026, 3, 29, 9),
              now: DateTime(2026, 3, 30, 9)),
          'ieri');
    });
  });

  // ------------------------------------------------------------- statistiche
  group('le barre del volume', () {
    const StatsService stats = StatsService();
    final DateTime sabato = DateTime(2026, 10, 31, 12, 35);

    RunningActivity corsa(DateTime quando, double km) => RunningActivity(
          startTime: quando,
          name: 'Corsa',
          type: ActivityType.free,
          durationSeconds: (km * 340).round(),
          distanceMeters: km * 1000,
        );

    // Una corsa a settimana, ognuna con un numero di km diverso, cosi' si
    // vede subito se una e' finita nella casella sbagliata.
    final List<RunningActivity> storico = <RunningActivity>[
      corsa(DateTime(2026, 9, 9, 18), 7), //  -7
      corsa(DateTime(2026, 9, 16, 18), 10), // -6
      corsa(DateTime(2026, 9, 23, 18), 43), // -5
      corsa(DateTime(2026, 9, 30, 18), 43), // -4
      corsa(DateTime(2026, 10, 7, 18), 50), // -3
      corsa(DateTime(2026, 10, 14, 18), 57), // -2
      corsa(DateTime(2026, 10, 21, 18), 55), // -1
      corsa(DateTime(2026, 10, 25, 10), 2), //  -1, domenica, dopo il cambio
      corsa(DateTime(2026, 10, 26, 18), 48), // ora
    ];

    test('ogni settimana nella sua casella', () {
      final RunningStats s = stats.compute(storico, now: sabato);
      expect(s.weeklyKm, <double>[7, 10, 43, 43, 50, 57, 57, 48]);
    });

    test('la settimana in corso e le ultime quattro', () {
      final RunningStats s = stats.compute(storico, now: sabato);
      expect(s.weekKm, closeTo(48, 0.01));
      // -3, -2, -1, ora
      expect(s.lastFourWeeksKm, closeTo(50 + 57 + 57 + 48, 0.01));
    });

    test('la media delle settimane prima e\' fatta su quattro settimane', () {
      // 43 + 50 + 57 + 57 = 207, diviso quattro = 51,75. Questa settimana
      // 48 km: circa il 7% sotto, non il 25%.
      final ImprovementResult r = stats.computeVolumeTrend(storico, now: sabato);
      expect(r.hasEnoughData, isTrue);
      expect(r.percentChange, isNotNull);
      expect(r.percentChange!, closeTo(-7.25, 0.1));
    });
  });

  // ------------------------------------------------------------ carico
  group('il grafico di fatica e condizione', () {
    const TrainingLoadEngine engine = TrainingLoadEngine();
    final TrainingZones zones = const PaceZoneEngine().zonesFor(
      Estimate<double>(
        value: 46.5,
        confidence: 0.8,
        source: EstimateSource.race,
        updatedAt: DateTime(2026, 10, 31),
      ),
    )!;

    RunningActivity corsa(DateTime quando) => RunningActivity(
          id: 'c${quando.month}-${quando.day}',
          startTime: quando,
          name: 'Corsa',
          type: ActivityType.free,
          durationSeconds: 2700,
          distanceMeters: 8000,
        );

    test('le corse dopo il 25 ottobre hanno il loro carico', () {
      final List<RunningActivity> storico = <RunningActivity>[
        corsa(DateTime(2026, 10, 1, 18)),
        corsa(DateTime(2026, 10, 20, 18)),
        corsa(DateTime(2026, 10, 26, 18)),
        corsa(DateTime(2026, 10, 28, 18)),
        corsa(DateTime(2026, 10, 30, 13)),
      ];
      final List<TrainingLoadPoint> serie = engine.seriesFor(
        storico,
        zones,
        now: DateTime(2026, 10, 31, 12),
        days: 0,
      );

      // Un punto per ogni giorno dal primo allenamento a oggi, tutti a
      // mezzanotte: dall'1 al 31 ottobre fanno 31.
      expect(serie.length, 31);
      for (final TrainingLoadPoint p in serie) {
        expect(p.date, soloGiorno(p.date), reason: '${p.date}');
      }

      double caricoDa(int giorno) => serie
          .firstWhere((TrainingLoadPoint p) => p.date.day == giorno)
          .load;
      expect(caricoDa(26), greaterThan(0));
      expect(caricoDa(28), greaterThan(0));
      expect(caricoDa(30), greaterThan(0));
      expect(caricoDa(27), 0);
      expect(serie.last.date, DateTime(2026, 10, 31));
    });
  });
}
