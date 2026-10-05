import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:run_coach_app/models/running_activity.dart';
import 'package:run_coach_app/services/elevation_service.dart';
import 'package:run_coach_app/widgets/route_shape.dart';

/// Il dislivello, e perche' quasi tutte le app lo sbagliano.
///
/// DA DOVE NASCE QUESTO FILE
/// -------------------------
/// Il GPS la quota la sa male: sulla verticale un telefono sbaglia dai quattro
/// ai dodici metri, e l'errore cambia da un secondo all'altro anche stando
/// fermi.
///
/// Sommare le differenze punto per punto - la cosa ovvia da fare - su un'ora in
/// pianura da' **ottomila metri di dislivello**, tutti fatti di rumore. Il
/// segno di riconoscimento e' che il numero cresce con la durata della corsa
/// invece che con le salite.
///
/// La prima versione scritta qui usava una finestra di cinque punti e una
/// soglia di tre metri: dava 474 metri su un'ora in pianura. Meglio del
/// metodo ingenuo e comunque inutilizzabile. I valori di adesso (finestra di
/// 45 secondi, soglia 8 metri) vengono da una simulazione su percorsi di cui
/// si conosceva il dislivello vero.
///
/// Questi test rifanno quella simulazione: generano percorsi noti, ci aggiungono
/// rumore, e controllano che il risultato somigli alla verita'.
void main() {
  const ElevationService service = ElevationService();

  /// Rumore ripetibile: un generatore con il seme fissato, cosi' il test non
  /// passa un giorno e fallisce quello dopo.
  List<RoutePoint> percorso(
    List<double> quoteVere, {
    double rumore = 4.0,
    int seed = 7,
    int secondiFraPunti = 2,
  }) {
    final math.Random random = math.Random(seed);
    double gauss() {
      // Box-Muller: due uniformi diventano una normale.
      final double u1 = 1.0 - random.nextDouble();
      final double u2 = random.nextDouble();
      return math.sqrt(-2.0 * math.log(u1)) * math.cos(2 * math.pi * u2);
    }

    return <RoutePoint>[
      for (int i = 0; i < quoteVere.length; i++)
        RoutePoint(
          latitude: 45.0 + i * 0.00002,
          longitude: 9.0 + i * 0.00002,
          elapsedSeconds: i * secondiFraPunti,
          altitude: quoteVere[i] + gauss() * rumore,
        ),
    ];
  }

  // Un'ora di corsa, un punto ogni due secondi: 1800 punti.
  const int punti = 1800;

  List<double> pianura() => List<double>.filled(punti, 120.0);

  List<double> salitaERitorno() => <double>[
        for (int i = 0; i < punti ~/ 2; i++) 100 + 100 * i / (punti / 2),
        for (int i = 0; i < punti - punti ~/ 2; i++)
          200 - 100 * i / (punti - punti ~/ 2),
      ];

  List<double> salitaContinua() =>
      <double>[for (int i = 0; i < punti; i++) 100 + 300 * i / punti];

  group('la pianura resta pianura', () {
    test('un\'ora in piano non produce dislivello', () {
      // IL test. Se cade questo, il numero mostrato e' rumore travestito.
      final ElevationSummary r = service.of(percorso(pianura()));
      expect(r.isKnown, isTrue);
      expect(r.gainMeters < 20, isTrue,
          reason: 'salita ${r.gainMeters.toStringAsFixed(0)} m su un percorso '
              'piatto: si sta misurando l\'errore del GPS');
      expect(r.isFlat, isTrue);
      expect(r.label, 'Pianeggiante');
    });

    test('nemmeno con il segnale pessimo', () {
      // Dodici metri di errore e' il peggio che capita: fra i palazzi, sotto
      // gli alberi, con il telefono in tasca.
      for (final int seed in <int>[1, 2, 3, 4, 5]) {
        final ElevationSummary r =
            service.of(percorso(pianura(), rumore: 12.0, seed: seed));
        expect(r.gainMeters < 20, isTrue,
            reason: 'seme $seed: ${r.gainMeters.toStringAsFixed(0)} m');
      }
    });

    test('la somma ingenua invece esplode', () {
      // Non e' un test del codice dell'app: e' la prova che il problema
      // esisteva. Se un giorno qualcuno "semplificasse" il servizio
      // sommando le differenze, questo numero dice cosa otterrebbe.
      final List<RoutePoint> p = percorso(pianura());
      double ingenua = 0;
      for (int i = 1; i < p.length; i++) {
        final double d = (p[i].altitude ?? 0) - (p[i - 1].altitude ?? 0);
        if (d > 0) ingenua += d;
      }
      expect(ingenua > 2000, isTrue,
          reason: 'la somma ingenua su un\'ora piatta: '
              '${ingenua.toStringAsFixed(0)} m');
    });
  });

  group('le salite vere si contano', () {
    test('cento metri di salita fanno cento metri', () {
      final ElevationSummary r = service.of(percorso(salitaERitorno()));
      expect(r.gainMeters > 75 && r.gainMeters < 120, isTrue,
          reason: 'salita ${r.gainMeters.toStringAsFixed(0)} m, attesi ~100');
      expect(r.lossMeters > 75 && r.lossMeters < 120, isTrue,
          reason: 'discesa ${r.lossMeters.toStringAsFixed(0)} m, attesi ~100');
      expect(r.isFlat, isFalse);
    });

    test('una salita lunga non si perde per strada', () {
      final ElevationSummary r = service.of(percorso(salitaContinua()));
      expect(r.gainMeters > 270 && r.gainMeters < 320, isTrue,
          reason: 'salita ${r.gainMeters.toStringAsFixed(0)} m, attesi ~300');
      // Tutta in salita: scendere non si scende.
      expect(r.lossMeters < 15, isTrue,
          reason: 'discesa ${r.lossMeters.toStringAsFixed(0)} m su una salita '
              'continua');
    });

    test('il risultato non dipende da quanto spesso registra il telefono', () {
      // La finestra e' in SECONDI apposta. Con una finestra contata in punti
      // lo stesso percorso darebbe due numeri diversi a seconda del telefono,
      // ed e' l'errore che questo file esiste per impedire.
      final ElevationSummary ogniDue =
          service.of(percorso(salitaContinua(), secondiFraPunti: 2));
      final ElevationSummary ogniCinque =
          service.of(percorso(salitaContinua(), secondiFraPunti: 5));

      final double scarto =
          (ogniDue.gainMeters - ogniCinque.gainMeters).abs();
      expect(scarto < 40, isTrue,
          reason: 'ogni 2 s: ${ogniDue.gainMeters.toStringAsFixed(0)} m, '
              'ogni 5 s: ${ogniCinque.gainMeters.toStringAsFixed(0)} m');
    });

    test('salita e discesa pareggiano su un giro chiuso', () {
      // Si parte e si torna alla stessa quota: quello che sali lo scendi.
      final ElevationSummary r = service.of(percorso(salitaERitorno()));
      expect((r.gainMeters - r.lossMeters).abs() < 25, isTrue,
          reason: 'salita ${r.gainMeters.toStringAsFixed(0)}, '
              'discesa ${r.lossMeters.toStringAsFixed(0)}');
    });
  });

  group('quando non si puo\' dire niente, non si dice niente', () {
    test('una corsa troppo corta non ha dislivello', () {
      final ElevationSummary r =
          service.of(percorso(List<double>.filled(40, 120.0)));
      expect(r.isKnown, isFalse);
      expect(r.label, '--');
    });

    test('senza quota non si inventa', () {
      final List<RoutePoint> senzaQuota = <RoutePoint>[
        for (int i = 0; i < 500; i++)
          RoutePoint(
            latitude: 45.0 + i * 0.0001,
            longitude: 9.0,
            elapsedSeconds: i * 2,
          ),
      ];
      expect(service.of(senzaQuota).isKnown, isFalse);
    });

    test('un percorso vuoto non fa saltare niente', () {
      expect(service.of(const <RoutePoint>[]).isKnown, isFalse);
      expect(service.of(const <RoutePoint>[]).label, '--');
    });

    test('punti fuori ordine non rompono il conto', () {
      // Non dovrebbe capitare, ma un file riletto da disco puo' sorprendere.
      final List<RoutePoint> p = percorso(salitaContinua());
      final List<RoutePoint> disordinati = <RoutePoint>[
        ...p.take(100),
        p[5], // un punto che torna indietro nel tempo
        ...p.skip(100),
      ];
      final ElevationSummary r = service.of(disordinati);
      expect(r.isKnown, isTrue);
      expect(r.gainMeters > 250 && r.gainMeters < 340, isTrue,
          reason: 'salita ${r.gainMeters.toStringAsFixed(0)} m');
    });
  });

  group('il disegno del percorso', () {
    test('con pochi punti non si disegna niente', () {
      // Tre punti non sono una forma: sarebbe una riga storta che non
      // assomiglia a nessun giro.
      expect(RouteShape.canDraw(const <RoutePoint>[]), isFalse);
      expect(
        RouteShape.canDraw(<RoutePoint>[
          for (int i = 0; i < 5; i++)
            RoutePoint(latitude: 45.0, longitude: 9.0, elapsedSeconds: i),
        ]),
        isFalse,
      );
    });

    test('con una corsa vera si disegna', () {
      expect(RouteShape.canDraw(percorso(pianura())), isTrue);
    });
  });

  group('la deriva del GPS su un giro chiuso', () {
    /// Un anello: si parte e si torna nello stesso punto.
    List<RoutePoint> anello(
      List<double> quoteVere, {
      double rumore = 4.0,
      double derivaMetri = 0,
      int seed = 11,
    }) {
      final math.Random random = math.Random(seed);
      double gauss() {
        final double u1 = 1.0 - random.nextDouble();
        final double u2 = random.nextDouble();
        return math.sqrt(-2.0 * math.log(u1)) * math.cos(2 * math.pi * u2);
      }
      final int n = quoteVere.length;
      return <RoutePoint>[
        for (int i = 0; i < n; i++)
          RoutePoint(
            // Un cerchio: l'ultimo punto torna sul primo.
            latitude: 45.0 + 0.004 * math.sin(2 * math.pi * i / n),
            longitude: 9.0 + 0.006 * math.cos(2 * math.pi * i / n),
            elapsedSeconds: i * 2,
            altitude: quoteVere[i] +
                gauss() * rumore +
                derivaMetri * i / n,
          ),
      ];
    }

    const int punti = 1550; // circa cinquanta minuti a un punto ogni 2 s

    test('un giro piatto resta piatto anche con la deriva', () {
      // DA DOVE NASCE QUESTO TEST
      // Su una corsa vera l'app ha scritto "salita 21, discesa 35" su un giro
      // chiuso in riva al mare. Quei quattordici metri di scarto non erano il
      // percorso: erano la quota di partenza e quella di arrivo, misurate nello
      // stesso posto, che non coincidevano piu'.
      for (final double deriva in <double>[15, -15, 0]) {
        final ElevationSummary r = service.of(
          anello(List<double>.filled(punti, 120.0), derivaMetri: deriva),
        );
        expect(r.isFlat, isTrue,
            reason: 'deriva $deriva m: salita '
                '${r.gainMeters.toStringAsFixed(0)} m su un giro piatto');
      }
    });

    test('su un anello quello che sali lo scendi', () {
      // La verifica che non si puo' barare: su un giro chiuso i due numeri
      // devono pareggiare, qualunque sia il terreno.
      final List<double> collina = <double>[
        for (int i = 0; i < punti; i++)
          120 + 20 - 20 * math.cos(2 * math.pi * i / punti),
      ];
      final ElevationSummary r =
          service.of(anello(collina, derivaMetri: 12));

      expect((r.gainMeters - r.lossMeters).abs() < 10, isTrue,
          reason: 'salita ${r.gainMeters.toStringAsFixed(0)}, '
              'discesa ${r.lossMeters.toStringAsFixed(0)}: su un anello '
              'devono pareggiare');
      expect(r.gainMeters > 25 && r.gainMeters < 50, isTrue,
          reason: 'salita ${r.gainMeters.toStringAsFixed(0)} m, attesi ~40');
    });

    test('un percorso da un punto a un altro NON viene corretto', () {
      // Qui la differenza di quota fra partenza e arrivo e' vera: toglierla
      // cancellerebbe il dislivello di chi finisce in cima a una salita.
      final List<double> salita = <double>[
        for (int i = 0; i < punti; i++) 100 + 200 * i / punti,
      ];
      final List<RoutePoint> puntoAPunto = <RoutePoint>[
        for (int i = 0; i < punti; i++)
          RoutePoint(
            latitude: 45.0 + 0.0001 * i, // si allontana e non torna
            longitude: 9.0,
            elapsedSeconds: i * 2,
            altitude: salita[i],
          ),
      ];
      final ElevationSummary r = service.of(puntoAPunto);
      expect(r.gainMeters > 170, isTrue,
          reason: 'salita ${r.gainMeters.toStringAsFixed(0)} m su 200 veri: '
              'la correzione non doveva scattare');
    });
  });
}
