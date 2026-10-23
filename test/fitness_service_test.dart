import 'package:flutter_test/flutter_test.dart';
import 'package:run_coach_app/models/workout_step.dart';
import 'package:run_coach_app/services/fitness_service.dart';
import 'package:run_coach_app/services/records_service.dart';

/// I valori attesi sono quelli pubblicati nelle tabelle di Jack Daniels.
/// Servono da ancora: se un giorno qualcuno tocca le formule e questi test
/// passano ancora, il motore da' ancora numeri giusti e non solo plausibili.
void main() {
  const FitnessService service = FitnessService();

  int mmss(int minutes, int seconds) => minutes * 60 + seconds;
  int hms(int h, int m, int s) => h * 3600 + m * 60 + s;

  group('VDOT da una prestazione', () {
    // Nelle tabelle di Daniels queste quattro prestazioni valgono tutte 50.
    test('prestazioni equivalenti danno lo stesso VDOT', () {
      expect(service.vdotFromPerformance(5000, mmss(19, 57)),
          closeTo(50, 0.3));
      expect(service.vdotFromPerformance(10000, mmss(41, 21)),
          closeTo(50, 0.3));
      expect(service.vdotFromPerformance(21097.5, hms(1, 31, 35)),
          closeTo(50, 0.3));
      expect(service.vdotFromPerformance(42195, hms(3, 10, 49)),
          closeTo(50, 0.3));
    });

    test('un altro livello: 5 km in 25:12 vale circa 38', () {
      expect(service.vdotFromPerformance(5000, mmss(25, 12)),
          closeTo(38, 0.5));
    });

    test('correre di piu\' fa salire il VDOT', () {
      final double? slow = service.vdotFromPerformance(5000, mmss(25, 0));
      final double? fast = service.vdotFromPerformance(5000, mmss(20, 0));
      expect(slow, isNotNull);
      expect(fast, isNotNull);
      expect(fast! > slow!, isTrue);
    });

    test('dati inutilizzabili', () {
      expect(service.vdotFromPerformance(100, 20), isNull);
      expect(service.vdotFromPerformance(5000, 0), isNull);
      expect(service.vdotFromPerformance(5000, -10), isNull);
      // Un chilometro in dieci secondi: non e' una prestazione, e' un errore.
      expect(service.vdotFromPerformance(1000, 10), isNull);
    });
  });

  group('previsioni di gara', () {
    test('VDOT 50 riproduce la tabella', () {
      expect(service.predictSeconds(50, 5000), closeTo(mmss(19, 57), 20));
      expect(service.predictSeconds(50, 10000), closeTo(mmss(41, 21), 40));
      expect(service.predictSeconds(50, 21097.5), closeTo(hms(1, 31, 35), 90));
      expect(service.predictSeconds(50, 42195), closeTo(hms(3, 10, 49), 180));
    });

    test('previsione e stima sono l\'una l\'inversa dell\'altra', () {
      final int? tenK = service.predictSeconds(52, 10000);
      expect(tenK, isNotNull);
      expect(service.vdotFromPerformance(10000, tenK!), closeTo(52, 0.2));
    });

    test('distanza coperta in un tempo dato', () {
      // In un'ora, un VDOT 50 copre poco piu' di 14 km.
      final double? meters = service.distanceForDuration(50, 3600);
      expect(meters, isNotNull);
      expect(meters!, closeTo(14200, 300));
    });

    test('il margine si allarga allontanandosi dalla misura di partenza', () {
      final List<RacePrediction> fromFiveK = service.predictions(50, 5000);
      final RacePrediction fiveK =
          fromFiveK.firstWhere((RacePrediction p) => p.distance.key == '5k');
      final RacePrediction marathon = fromFiveK
          .firstWhere((RacePrediction p) => p.distance.key == 'marathon');

      expect(fiveK.marginPercent < marathon.marginPercent, isTrue);
      // La forbice contiene sempre la previsione.
      expect(marathon.bestCaseSeconds < marathon.seconds, isTrue);
      expect(marathon.worstCaseSeconds > marathon.seconds, isTrue);
    });
  });

  group('passi di allenamento', () {
    test('VDOT 50: i cinque passi corrispondono alla tabella', () {
      final TrainingPaces? p = service.pacesFor(50);
      expect(p, isNotNull);

      // Tolleranza di 8 secondi al km: le tabelle sono arrotondate.
      expect(p!.marathon.secondsPerKm, closeTo(mmss(4, 31), 8));
      expect(p.threshold.secondsPerKm, closeTo(mmss(4, 13), 8));
      expect(p.interval.secondsPerKm, closeTo(mmss(3, 51), 8));
      expect(p.repetition.secondsPerKm, closeTo(mmss(3, 36), 8));
      // La tabella stampa, per indice 50, un lento da 5:07 a 5:38. Questa
      // riga chiedeva 5:38 - 6:12: aveva preso l'estremo LENTO della fascia
      // e lo aveva messo come estremo veloce, scalando tutto di una fascia.
      // Il test era verde perche' il codice sbagliava nella stessa
      // direzione. La tolleranza adesso e' di due secondi, non dieci: con la
      // frazione giusta il conto torna al secondo.
      expect(p.easy.fastestSecPerKm, closeTo(mmss(5, 7), 2));
      expect(p.easy.slowestSecPerKm, closeTo(mmss(5, 38), 2));
    });

    test('i passi restano in ordine a qualunque livello', () {
      for (final double vdot in <double>[30, 35, 40, 45, 50, 55, 60, 70, 80]) {
        final TrainingPaces? p = service.pacesFor(vdot);
        expect(p, isNotNull, reason: 'VDOT $vdot');
        // Numeri piu' alti = piu' lento.
        expect(p!.easy.slowestSecPerKm > p.easy.fastestSecPerKm, isTrue,
            reason: 'VDOT $vdot');
        expect(p.easy.fastestSecPerKm > p.marathon.secondsPerKm, isTrue,
            reason: 'VDOT $vdot');
        expect(p.marathon.secondsPerKm > p.threshold.secondsPerKm, isTrue,
            reason: 'VDOT $vdot');
        expect(p.threshold.secondsPerKm > p.interval.secondsPerKm, isTrue,
            reason: 'VDOT $vdot');
        expect(p.interval.secondsPerKm > p.repetition.secondsPerKm, isTrue,
            reason: 'VDOT $vdot');
      }
    });

    test('la banda del passo e\' pronta per il motore allenamenti', () {
      final TrainingPaces? p = service.pacesFor(50);
      expect(p, isNotNull);

      final PaceTarget target = p!.threshold.target;
      expect(target.isNotEmpty, isTrue);
      expect(target.fastestSecPerKm! < target.slowestSecPerKm!, isTrue);

      // Dentro la banda si e' in ritmo, fuori no: e' quello che dira' la voce
      // durante la seduta.
      final double centre = p.threshold.secondsPerKm;
      expect(target.evaluate(centre), PaceStatus.onTarget);
      expect(target.evaluate(centre - 30), PaceStatus.tooFast);
      expect(target.evaluate(centre + 30), PaceStatus.tooSlow);
    });

    test('VDOT non valido', () {
      expect(service.pacesFor(0), isNull);
      expect(service.pacesFor(-5), isNull);
    });
  });

  group('stima dai record personali', () {
    DistanceRecord record(String key, String label, double meters, int seconds,
            DateTime date) =>
        DistanceRecord(
          distance: RecordDistance(key: key, label: label, meters: meters),
          seconds: seconds,
          activityId: 'act-$key',
          activityName: 'Corsa',
          date: date,
        );

    PersonalRecords wrap(List<DistanceRecord> records) => PersonalRecords(
          byDistance: records,
          longestRun: null,
          bestWeekKm: 0,
          bestWeekStart: null,
          totalActivities: records.length,
          activitiesWithGps: records.length,
        );

    final DateTime now = DateTime(2026, 9, 26);

    test('usa il record che vale di piu\', non il piu\' lungo', () {
      final PersonalRecords records = wrap(<DistanceRecord>[
        // 5 km scarso.
        record('5k', '5 km', 5000, mmss(27, 0), DateTime(2026, 9, 1)),
        // 3 km tirato: vale un VDOT piu' alto.
        record('3k', '3 km', 3000, mmss(11, 33), DateTime(2026, 9, 20)),
      ]);

      final FitnessEstimate? est =
          service.estimateFromRecords(records, now: now);
      expect(est, isNotNull);
      expect(est!.isEmpty, isFalse);
      expect(est.vdot, closeTo(50, 0.5));
      expect(est.sourceLabel, '3 km');
    });

    test('i tratti sotto i 3 km non contano', () {
      final PersonalRecords records = wrap(<DistanceRecord>[
        // Un chilometro lanciatissimo: da' un VDOT altissimo, va ignorato.
        record('1k', '1 km', 1000, mmss(2, 50), DateTime(2026, 9, 20)),
      ]);

      final FitnessEstimate? est =
          service.estimateFromRecords(records, now: now);
      expect(est, isNotNull);
      expect(est!.isEmpty, isTrue);
      expect(est.hasAnyRecord, isTrue);
    });

    test('i record vecchi non descrivono la forma di adesso', () {
      final PersonalRecords records = wrap(<DistanceRecord>[
        record('5k', '5 km', 5000, mmss(20, 0), DateTime(2025, 1, 10)),
      ]);

      final FitnessEstimate? est =
          service.estimateFromRecords(records, now: now);
      expect(est, isNotNull);
      expect(est!.isEmpty, isTrue);
      expect(est.hasOldRecords, isTrue);
      expect(est.missingReason, contains('quattro mesi'));
    });

    test('storico vuoto', () {
      final FitnessEstimate? est =
          service.estimateFromRecords(wrap(<DistanceRecord>[]), now: now);
      expect(est, isNotNull);
      expect(est!.isEmpty, isTrue);
      expect(est.hasAnyRecord, isFalse);
      expect(est.predictions, isEmpty);
    });

    test('la stima porta con se\' previsioni e passi', () {
      final PersonalRecords records = wrap(<DistanceRecord>[
        record('5k', '5 km', 5000, mmss(19, 57), DateTime(2026, 9, 20)),
      ]);

      final FitnessEstimate? est =
          service.estimateFromRecords(records, now: now);
      expect(est, isNotNull);
      expect(est!.paces, isNotNull);
      expect(est.predictions.length, 4);
      expect(est.sourceActivityId, 'act-5k');
      final RacePrediction marathon = est.predictions
          .firstWhere((RacePrediction p) => p.distance.key == 'marathon');
      expect(marathon.seconds, closeTo(hms(3, 10, 49), 240));
    });
  });

  // -------------------------------------------------------------- il lento
  //
  // La prima versione usava due frazioni fisse di consumo (0,55 e 0,62) per
  // tutti, e su un atleta da indice 36 sbagliava di quasi un minuto al
  // chilometro. Questo gruppo e' la rete che impedisce di tornarci: confronta
  // la fascia del lento con la tabella di riferimento su tutto l'arco dei
  // livelli, non solo su quello comodo.
  group('fascia del lento', () {
    // LA TABELLA VERA, COPIATA DAL LIBRO.
    //
    // Quella che c'era qui prima non era questa: era stata ricavata a
    // rovescio dalla formula del codice, che sbagliava. Si vede dal profilo
    // dell'errore - giusta a indice 35, dodici secondi fuori a indice 30 e
    // venticinque a indice 65 - ed e' il modo tipico in cui un test diventa
    // la fotocopia del difetto che dovrebbe trovare. Un test scritto cosi'
    // resta verde per sempre e non prova niente.
    //
    // Indice: (estremo veloce, estremo lento) in secondi al chilometro.
    const Map<int, List<int>> tabella = <int, List<int>>{
      30: <int>[459, 503], // 7:39 - 8:23
      35: <int>[407, 448], // 6:47 - 7:28
      40: <int>[367, 404], // 6:07 - 6:44
      45: <int>[334, 368], // 5:34 - 6:08
      50: <int>[307, 338], // 5:07 - 5:38
      55: <int>[284, 313], // 4:44 - 5:13
      60: <int>[265, 292], // 4:25 - 4:52
      65: <int>[248, 274], // 4:08 - 4:34
    };

    test('combacia con la tabella a ogni livello', () {
      tabella.forEach((int vdot, List<int> attesi) {
        final double veloce = service.easyPaceFastest(vdot.toDouble());
        final double lento = service.easyPaceSlowest(vdot.toDouble());
        // Un secondo al chilometro. Non e' pignoleria: con il 70% e il 62%
        // del consumo massimo il conto riproduce tutte e otto le righe della
        // tabella al secondo esatto, e una tolleranza larga qui servirebbe
        // solo a nascondere un modello sbagliato - che e' esattamente
        // quello che e' successo.
        expect(veloce, closeTo(attesi[0], 1),
            reason: 'indice $vdot, estremo veloce');
        expect(lento, closeTo(attesi[1], 1),
            reason: 'indice $vdot, estremo lento');
      });
    });

    test('il lento e\' piu\' lento del medio a ogni livello', () {
      for (final double vdot in <double>[30, 36, 42, 50, 58, 65]) {
        final TrainingPaces? paces = service.pacesFor(vdot);
        expect(paces, isNotNull, reason: 'indice $vdot');
        expect(paces!.easy.fastestSecPerKm > paces.marathon.secondsPerKm,
            isTrue,
            reason: 'indice $vdot: il lento non puo\' essere piu\' veloce '
                'del medio');
        expect(paces.easy.slowestSecPerKm > paces.easy.fastestSecPerKm, isTrue,
            reason: 'indice $vdot');
      }
    });

    test('la frazione e\' la stessa a ogni livello', () {
      // QUESTO TEST DICEVA IL CONTRARIO, E SBAGLIAVA.
      //
      // Chiedeva che la percentuale del massimo a cui si corre il lento
      // scendesse col crescere del livello. Suona fisiologico, ma la
      // tabella dice un'altra cosa: riportando ogni passo lento stampato
      // alla frazione che lo produce viene sempre 0,700 e 0,620, da indice
      // 30 a 65, con uno scostamento di un millesimo. La fascia e' piatta.
      //
      // Chi migliora corre il lento piu' forte perche' il suo massimo e'
      // piu' alto, non perche' usi una fetta piu' piccola di quel massimo.
      for (final double vdot in <double>[30, 38, 45, 52, 60, 65]) {
        expect(service.easyOxygenFraction(vdot, fast: true),
            FitnessService.easyFractionFast,
            reason: 'indice $vdot');
        expect(service.easyOxygenFraction(vdot, fast: false),
            FitnessService.easyFractionSlow,
            reason: 'indice $vdot');
      }
    });

    test('non c\'e\' niente da estrapolare', () {
      // Prima c'erano due rette con dei tagli agli estremi, e i tagli erano
      // la parte piu' fragile: un confronto sul valore grezzo faceva uscire
      // 0,6992999999999999 invece di 0,70. Una costante non ha estremi.
      expect(service.easyOxygenFraction(5, fast: true), 0.700);
      expect(service.easyOxygenFraction(200, fast: true), 0.700);
      expect(service.easyOxygenFraction(5, fast: false), 0.620);
      expect(service.easyOxygenFraction(200, fast: false), 0.620);
    });
  });
}
