import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:run_coach_app/models/estimate.dart';
import 'package:run_coach_app/models/running_activity.dart';
import 'package:run_coach_app/services/pace_zone_engine.dart';
import 'package:run_coach_app/services/session_classifier.dart';

/// Il rumore del GPS non deve diventare allenamento.
///
/// DA DOVE NASCE QUESTO FILE
/// -------------------------
/// Un lento vero, corso con l'app: parziali 5:27, 5:00, 5:20, 5:20, 5:25,
/// 5:20, 5:24, 5:10, 5:30, 5:18. L'app lo ha riassunto cosi': "7 minuti a
/// soglia o piu' veloce: seduta impegnativa". Non era vero, e il motore ci
/// avrebbe costruito sopra il giorno dopo.
///
/// Il conto: una finestra di venti secondi copre un centinaio di metri. Fra
/// 5:00 e 4:34 al chilometro, su un centinaio di metri, ci sono sei metri di
/// differenza. Il GPS sbaglia di piu' di sei metri. Quindi su una corsa
/// regolare qualche finestra cade per caso nella soglia, e sommandole viene
/// fuori un lavoro che non e' stato fatto.
///
/// La correzione: il tempo di qualita' si conta solo a blocchi continui di
/// almeno un minuto. Il rumore e' sparso, il lavoro e' continuo.
void main() {
  const PaceZoneEngine engine = PaceZoneEngine();
  const SessionClassifier classifier = SessionClassifier();

  final TrainingZones zones = engine.zonesFor(Estimate<double>(
    value: 45.4,
    confidence: 0.8,
    source: EstimateSource.runSegment,
    updatedAt: DateTime(2026, 9, 27),
  ))!;

  final double easy = zones[TrainingZone.easy].centre;
  final double repetition = zones[TrainingZone.repetition].centre;
  final double interval = zones[TrainingZone.interval].centre;

  /// Costruisce un tracciato con [rumoreMetri] di errore laterale per punto.
  ///
  /// E' il modo onesto di simulare il GPS: la posizione balla di qualche
  /// metro, quindi la distanza misurata su una singola finestra e' sbagliata,
  /// mentre il tempo e' esatto. Il seme e' fisso: il test non deve dipendere
  /// dalla fortuna.
  RunningActivity corsa(
    List<List<double>> tratti, {
    double rumoreMetri = 0,
    int seme = 7,
  }) {
    const double gradiPerMetro = 1 / 111195.0;
    const double passoMetri = 10;
    final Random random = Random(seme);

    final List<RoutePoint> punti = <RoutePoint>[
      const RoutePoint(latitude: 45, longitude: 9, elapsedSeconds: 0),
    ];
    double percorsi = 0;
    double tempo = 0;

    for (final List<double> tratto in tratti) {
      final double metri = tratto[0];
      final double passo = tratto[1];
      double fatti = 0;
      while (fatti < metri) {
        fatti += passoMetri;
        percorsi += passoMetri;
        tempo += passoMetri / 1000.0 * passo;
        final double scarto = rumoreMetri == 0
            ? 0
            : (random.nextDouble() * 2 - 1) * rumoreMetri;
        punti.add(RoutePoint(
          latitude: 45 + percorsi * gradiPerMetro,
          longitude: 9 + scarto * gradiPerMetro,
          elapsedSeconds: tempo.round(),
        ));
      }
    }

    double metriTotali = 0;
    for (final List<double> t in tratti) {
      metriTotali += t[0];
    }
    return RunningActivity(
      id: 'rumore',
      startTime: DateTime(2026, 9, 27, 19),
      name: 'Corsa',
      type: ActivityType.free,
      durationSeconds: punti.last.elapsedSeconds,
      distanceMeters: metriTotali,
      route: punti,
    );
  }

  group('il rumore del GPS non e\' qualita\'', () {
    test('un lento a 5:20 resta un lento anche con il GPS che balla', () {
      final SessionAnalysis a = classifier.analyse(
        corsa(<List<double>>[
          <double>[10000, 320], // 5:20 al km, il lento di tutti i giorni
        ], rumoreMetri: 6),
        zones,
      );

      expect(a.qualityMinutes < 1, isTrue,
          reason: '${a.qualityMinutes} minuti di soglia in un lento: '
              'e\' il rumore, non il lavoro');
      expect(a.intensity.countsAsQuality, isFalse,
          reason: 'classificata ${a.intensity.label}: domani si potrebbe '
              'fare qualita\', e il motore lo vieterebbe per niente');
      expect(a.explanation.contains('soglia'), isFalse,
          reason: 'la spiegazione non deve raccontare un lavoro inventato');
    });

    test('lo stesso lento senza rumore da\' lo stesso giudizio', () {
      // Se il risultato cambiasse fra tracciato pulito e tracciato sporco,
      // vorrebbe dire che stiamo misurando il GPS invece della corsa.
      final SessionIntensity pulito = classifier
          .analyse(corsa(<List<double>>[<double>[10000, 320]]), zones)
          .intensity;
      final SessionIntensity sporco = classifier
          .analyse(
              corsa(<List<double>>[<double>[10000, 320]], rumoreMetri: 6),
              zones)
          .intensity;
      expect(sporco, pulito);
    });

    test('anche la quota di tempo "sopra il lento" si conta a blocchi', () {
      // Questo era il secondo modo di sbagliare: senza tratti di soglia, la
      // seduta diventava "impegnativa" perche' il 52% delle finestre cadeva
      // nella zona del medio. Sempre rumore, stessa cura.
      final SessionAnalysis a = classifier.analyse(
        corsa(<List<double>>[<double>[10000, 320]], rumoreMetri: 6),
        zones,
      );
      expect(a.hardFraction < 0.40, isTrue,
          reason: 'quota ${a.hardFraction}');
    });
  });

  group('il lavoro vero continua a contare', () {
    test('5x1000 a ritmo ripetute resta una seduta dura', () {
      final List<List<double>> tratti = <List<double>>[
        <double>[2000, easy],
      ];
      for (int i = 0; i < 5; i++) {
        tratti.add(<double>[1000, interval]);
        tratti.add(<double>[400, easy + 60]);
      }
      tratti.add(<double>[1000, easy]);

      final SessionAnalysis a =
          classifier.analyse(corsa(tratti, rumoreMetri: 3), zones);
      expect(a.intensity, SessionIntensity.hard);
      expect(a.qualityMinutes > 15, isTrue,
          reason: '${a.qualityMinutes} minuti');
    });

    test('10x400 veloci non vengono buttate via dal minuto minimo', () {
      // Il rischio della correzione era questo: un 400 dura poco piu' di un
      // minuto e mezzo, e se il conteggio a blocchi lo scartasse avremmo
      // risolto un problema creandone uno peggiore.
      final List<List<double>> tratti = <List<double>>[
        <double>[2000, easy],
      ];
      for (int i = 0; i < 10; i++) {
        tratti.add(<double>[400, repetition]);
        tratti.add(<double>[200, easy + 60]);
      }
      tratti.add(<double>[1000, easy]);

      final SessionAnalysis a =
          classifier.analyse(corsa(tratti, rumoreMetri: 3), zones);
      expect(a.qualityMinutes > 10, isTrue,
          reason: 'solo ${a.qualityMinutes} minuti: le ripetute da 400 '
              'devono restare visibili');
      expect(a.intensity, SessionIntensity.hard);
    });

    test('venti minuti di soglia restano venti minuti di soglia', () {
      final SessionAnalysis a = classifier.analyse(
        corsa(<List<double>>[
          <double>[2000, easy],
          <double>[4380, 274], // 20 minuti a 4:34
          <double>[2000, easy],
        ], rumoreMetri: 3),
        zones,
      );
      // Non venti esatti: la fascia della soglia e' larga tredici secondi al
      // chilometro, e il rumore fa uscire qualche finestra sotto il medio,
      // spezzando il blocco. Quello che conta e' che la seduta resti dura.
      expect(a.qualityMinutes > 10, isTrue,
          reason: '${a.qualityMinutes} minuti');
      expect(a.intensity, SessionIntensity.hard);
    });

    test('8x200 non conta come qualita\', ed e\' giusto cosi\'', () {
      // Duecento metri veloci durano quaranta secondi: sotto il minuto, e
      // quindi non entrano nel conto. Non e' un difetto: le ripetute brevi
      // servono alla meccanica di corsa, non devono stancare, e un corpo che
      // ha fatto 8x200 puo' allenarsi forte il giorno dopo.
      final List<List<double>> tratti = <List<double>>[
        <double>[2000, easy],
      ];
      for (int i = 0; i < 8; i++) {
        tratti.add(<double>[200, repetition - 10]);
        tratti.add(<double>[200, easy + 80]);
      }
      tratti.add(<double>[1000, easy]);

      final SessionAnalysis a =
          classifier.analyse(corsa(tratti, rumoreMetri: 3), zones);
      expect(a.intensity.countsAsQuality, isFalse,
          reason: 'classificata ${a.intensity.label}');
    });
  });
}
