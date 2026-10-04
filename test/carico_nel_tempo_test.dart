import 'package:flutter_test/flutter_test.dart';
import 'package:run_coach_app/models/estimate.dart';
import 'package:run_coach_app/models/running_activity.dart';
import 'package:run_coach_app/services/pace_zone_engine.dart';
import 'package:run_coach_app/services/training_load_engine.dart';
import 'package:run_coach_app/widgets/load_chart.dart';

/// La storia del carico, non solo il numero di oggi.
///
/// DA DOVE NASCE QUESTO FILE
/// -------------------------
/// "Condizione 48, fatica 52" non dice niente da solo. Quarantotto dopo essere
/// stato a trenta vuol dire che stai costruendo; quarantotto dopo essere stato
/// a sessantacinque vuol dire che ti stai perdendo. Il numero di oggi e'
/// identico nei due casi, e sono due situazioni opposte.
///
/// Il rischio quando si aggiunge un grafico e' che finisca per raccontare una
/// storia diversa dal numero scritto sopra: due conti separati divergono
/// sempre. Qui il numero di oggi **e'** l'ultimo punto della serie, e il test
/// piu' importante del file e' esattamente quello.
void main() {
  const TrainingLoadEngine engine = TrainingLoadEngine();
  final DateTime oggi = DateTime(2026, 10, 4);

  // Zone di un atleta da 10 km in 44 minuti: soglia intorno ai 4:10/km.
  final TrainingZones zone = const PaceZoneEngine().zonesFor(Estimate<double>(
    value: 46.5,
    confidence: 0.8,
    source: EstimateSource.runSegment,
    updatedAt: DateTime(2026, 10, 1),
  ))!;

  RunningActivity corsa({
    required DateTime quando,
    required double km,
    required int secondiPerKm,
  }) {
    final int durata = (km * secondiPerKm).round();
    return RunningActivity(
      startTime: quando,
      name: 'Corsa',
      type: ActivityType.free,
      durationSeconds: durata,
      distanceMeters: km * 1000,
    );
  }

  /// Dieci settimane di allenamento regolare: tre corse a settimana.
  List<RunningActivity> dieciSettimane({int secondiPerKm = 330}) {
    final List<RunningActivity> out = <RunningActivity>[];
    for (int settimana = 10; settimana >= 1; settimana--) {
      final DateTime lunedi = oggi.subtract(Duration(days: settimana * 7));
      for (final int giorno in <int>[0, 2, 5]) {
        out.add(corsa(
          quando: lunedi.add(Duration(days: giorno)),
          km: giorno == 5 ? 16 : 10,
          secondiPerKm: secondiPerKm,
        ));
      }
    }
    return out;
  }

  group('il grafico e il numero raccontano la stessa cosa', () {
    test('l\'ultimo punto della serie E\' lo stato di oggi', () {
      // Il test piu' importante del file. Se cade, la schermata Forma mostra
      // un numero e un grafico che finisce da un'altra parte, e l'utente non
      // ha modo di sapere a quale credere.
      final List<RunningActivity> attivita = dieciSettimane();

      final TrainingLoadState stato =
          engine.stateFor(attivita, zone, now: oggi);
      final List<TrainingLoadPoint> serie =
          engine.seriesFor(attivita, zone, now: oggi, days: 90);

      expect(serie.isNotEmpty, isTrue);
      expect(serie.last.date, oggi);
      expect(serie.last.fitness.toStringAsFixed(1),
          stato.fitness.toStringAsFixed(1));
      expect(serie.last.fatigue.toStringAsFixed(1),
          stato.fatigue.toStringAsFixed(1));
      expect(serie.last.freshness.toStringAsFixed(1),
          stato.freshness.toStringAsFixed(1));
    });

    test('vale anche chiedendo un periodo corto', () {
      // Il periodo cambia quanto se ne mostra, non quanto se ne calcola.
      final List<RunningActivity> attivita = dieciSettimane();
      final TrainingLoadState stato =
          engine.stateFor(attivita, zone, now: oggi);

      for (final int giorni in <int>[14, 30, 90, 365]) {
        final List<TrainingLoadPoint> serie =
            engine.seriesFor(attivita, zone, now: oggi, days: giorni);
        expect(serie.last.fitness.toStringAsFixed(1),
            stato.fitness.toStringAsFixed(1),
            reason: 'con $giorni giorni mostrati');
      }
    });

    test('il calcolo parte sempre dal primo allenamento', () {
      // Se la serie a 30 giorni ripartisse da zero un mese fa, direbbe che un
      // mese fa eri fermo anche se correvi da dieci settimane. Le medie
      // esponenziali hanno memoria, e va rispettata.
      final List<RunningActivity> attivita = dieciSettimane();
      final List<TrainingLoadPoint> corta =
          engine.seriesFor(attivita, zone, now: oggi, days: 20);

      expect(corta.length, 20);
      expect(corta.first.fitness > 10, isTrue,
          reason: 'condizione al primo punto mostrato: '
              '${corta.first.fitness.toStringAsFixed(1)} - se e\' vicina a '
              'zero, il conto e\' ripartito da capo');
    });
  });

  group('la serie racconta quello che e\' successo davvero', () {
    test('i giorni di riposo ci sono, ed e\' li\' che la fatica scende', () {
      final List<TrainingLoadPoint> serie =
          engine.seriesFor(dieciSettimane(), zone, now: oggi, days: 30);

      // Un giorno per giorno vero: nessun buco.
      for (int i = 1; i < serie.length; i++) {
        expect(
          serie[i].date.difference(serie[i - 1].date).inDays,
          1,
          reason: 'buco fra ${serie[i - 1].date} e ${serie[i].date}',
        );
      }

      // E ci sono giorni a carico zero: sono i riposi.
      expect(serie.any((TrainingLoadPoint p) => p.load == 0), isTrue);
    });

    test('dopo uno stop la condizione scende e la fatica sparisce', () {
      // Tre settimane ferme in fondo: la fatica (7 giorni) se ne va quasi
      // tutta, la condizione (28 giorni) cala ma resta.
      final List<RunningActivity> conStop = dieciSettimane()
          .where((RunningActivity a) =>
              a.startTime.isBefore(oggi.subtract(const Duration(days: 21))))
          .toList();

      final List<TrainingLoadPoint> serie =
          engine.seriesFor(conStop, zone, now: oggi, days: 60);

      final TrainingLoadPoint fine = serie.last;
      expect(fine.fatigue < 3, isTrue,
          reason: 'fatica dopo tre settimane ferme: '
              '${fine.fatigue.toStringAsFixed(1)}');
      expect(fine.fitness > fine.fatigue, isTrue,
          reason: 'dopo uno stop si e\' freschi, non stanchi');
      expect(fine.freshness > 0, isTrue);
    });

    test('allenarsi piu\' forte alza il carico', () {
      // Stessi chilometri, stessi giorni, passo piu' veloce: il carico deve
      // salire. Se non salisse, l'unita' di misura sarebbe il chilometro
      // travestito da sforzo.
      final double lento = engine
          .seriesFor(dieciSettimane(secondiPerKm: 360), zone, now: oggi)
          .last
          .fitness;
      final double forte = engine
          .seriesFor(dieciSettimane(secondiPerKm: 290), zone, now: oggi)
          .last
          .fitness;
      expect(forte > lento, isTrue,
          reason: 'lento $lento, forte $forte');
    });
  });

  group('quando non c\'e\' niente da disegnare', () {
    test('archivio vuoto: serie vuota, nessun grafico', () {
      final List<TrainingLoadPoint> serie =
          engine.seriesFor(const <RunningActivity>[], zone, now: oggi);
      expect(serie, isEmpty);
      expect(LoadChart.canDraw(serie), isFalse);
    });

    test('senza zone non si inventa un carico', () {
      // Le zone arrivano dall'indice di forma: senza una stima, non c\'e\' un
      // passo di soglia a cui rapportare niente.
      expect(engine.seriesFor(dieciSettimane(), null, now: oggi), isEmpty);
    });

    test('due settimane scarse non fanno un andamento', () {
      final List<RunningActivity> poche = <RunningActivity>[
        corsa(
            quando: oggi.subtract(const Duration(days: 4)),
            km: 10,
            secondiPerKm: 330),
        corsa(
            quando: oggi.subtract(const Duration(days: 2)),
            km: 8,
            secondiPerKm: 330),
      ];
      final List<TrainingLoadPoint> serie =
          engine.seriesFor(poche, zone, now: oggi);
      expect(LoadChart.canDraw(serie), isFalse,
          reason: 'con ${serie.length} giorni il grafico sarebbe solo due '
              'linee che partono da zero');
    });

    test('con un mese di corse il grafico si disegna', () {
      expect(
        LoadChart.canDraw(engine.seriesFor(dieciSettimane(), zone, now: oggi)),
        isTrue,
      );
    });
  });
}
