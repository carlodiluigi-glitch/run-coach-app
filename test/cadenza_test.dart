import 'package:flutter_test/flutter_test.dart';
import 'package:run_coach_app/models/running_activity.dart';
import 'package:run_coach_app/services/cadence.dart';
import 'package:run_coach_app/services/route_windows.dart';
import 'package:run_coach_app/services/run_profile.dart';
import 'package:run_coach_app/utils/formatters.dart';

/// La cadenza: quanti appoggi al minuto.
///
/// DA DOVE NASCE QUESTO FILE
/// -------------------------
/// La cadenza e' l'unico dato di questa app che non viene dal GPS: la contano
/// gli accelerometri dentro al telefono. Il rischio quindi non e' la precisione
/// della misura - e' il modo in cui viene riletta.
///
/// I passi vengono salvati **cumulativi** (quanti dall'inizio), non "quanti in
/// questo tratto", e tutto il resto dipende da quella scelta: la cadenza di un
/// pezzo di corsa e' una differenza divisa per un tempo. Questo file tiene ferme
/// le tre cose che possono andare storte in quella rilettura:
///
///  1. un buco in mezzo non deve inventare una cadenza bassa che non c'e'
///     stata (la differenza fra due punti lontani e' giusta, la somma di pezzi
///     con un buco in mezzo no);
///  2. raggruppare i punti per farli stare nello schermo non deve cambiare il
///     risultato;
///  3. un valore impossibile - una camminata, il telefono che sbatte in uno
///     zaino - non deve uscire come se fosse un dato.
/// L'ultima cadenza nota prima di [i] (zero se non ce n'e' nessuna).
double _ultimoNoto(List<double?> cadenze, int i) {
  for (int k = i - 1; k >= 0; k--) {
    final double? c = cadenze[k];
    if (c != null) return c;
  }
  for (int k = i + 1; k < cadenze.length; k++) {
    final double? c = cadenze[k];
    if (c != null) return c;
  }
  return 0;
}

void main() {
  /// Un tracciato dove la cadenza la decide il test.
  ///
  /// [cadenze] e' un valore per punto, in passi al minuto; `null` significa "il
  /// sensore non ha risposto a quel giro" e quel punto esce senza passi - ma il
  /// conteggio **continua a salire**, perche' nella realta' i passi li tiene il
  /// chip del telefono e non si fermano perche' l'app non li ha letti. E' il
  /// motivo per cui i passi sono salvati cumulativi: un buco nella lettura non
  /// e' un buco nei passi.
  List<RoutePoint> tracciato({
    required List<double?> cadenze,
    int secondiFraPunti = 2,
    double velocita = 3.0,
  }) {
    const double gradiLat = 1 / 111320.0;
    double passiTotali = 0;
    double metri = 0;
    final List<RoutePoint> out = <RoutePoint>[];
    for (int i = 0; i < cadenze.length; i++) {
      final double? c = cadenze[i];
      // I passi salgono comunque: quello che manca e' la lettura, non il passo.
      // Dove la cadenza voluta e' `null` si usa l'ultimo valore noto, cosi' il
      // totale resta coerente con il resto del tracciato.
      final double ritmo = c ?? _ultimoNoto(cadenze, i);
      passiTotali += ritmo / 60.0 * secondiFraPunti;
      metri += velocita * secondiFraPunti;
      out.add(RoutePoint(
        latitude: 45.0 + metri * gradiLat,
        longitude: 9.0,
        elapsedSeconds: (i + 1) * secondiFraPunti,
        altitude: 100.0,
        speed: velocita,
        steps: c == null ? null : passiTotali.round(),
      ));
    }
    return out;
  }

  group('la media della corsa', () {
    test('una corsa a 170 passi al minuto legge 170', () {
      final List<RoutePoint> r =
          tracciato(cadenze: List<double?>.filled(300, 170.0));
      final double? media = Cadence.average(r);
      expect(media, isNotNull);
      expect(media!, closeTo(170.0, 1.0));
    });

    test('senza passi non si inventa niente', () {
      final List<RoutePoint> r =
          tracciato(cadenze: List<double?>.filled(300, null));
      expect(Cadence.average(r), isNull);
      expect(Cadence.has(r), isFalse);
      expect(Cadence.totalSteps(r), isNull);
    });

    test('una camminata non e\' una cadenza di corsa', () {
      final List<RoutePoint> r =
          tracciato(cadenze: List<double?>.filled(300, 90.0));
      expect(Cadence.average(r), isNull);
    });

    test('il telefono che sbatte nello zaino non diventa un dato', () {
      final List<RoutePoint> r =
          tracciato(cadenze: List<double?>.filled(300, 300.0));
      expect(Cadence.average(r), isNull);
    });

    test('un tracciato troppo corto non ha una media', () {
      // Venti punti da due secondi: quaranta secondi. Sotto il minuto la media
      // e' un caso, non un dato.
      final List<RoutePoint> r =
          tracciato(cadenze: List<double?>.filled(20, 170.0));
      expect(Cadence.average(r), isNull);
    });

    test('un buco in mezzo non sposta la media', () {
      // La parte centrale senza passi: la differenza fra il primo e l'ultimo
      // punto che li hanno resta giusta, perche' sono cumulativi.
      final List<double?> c = List<double?>.filled(300, 170.0);
      for (int i = 100; i < 160; i++) {
        c[i] = null;
      }
      final double? media = Cadence.average(tracciato(cadenze: c));
      expect(media, isNotNull);
      expect(media!, closeTo(170.0, 2.0));
    });

    test('un sensore che si congela non dimezza la cadenza', () {
      // Succede: Android chiude la schermata per fare posto in memoria e il
      // conteggio resta fermo sull'ultimo valore letto, mentre la corsa va
      // avanti. I punti dopo portano tutti quel numero.
      //
      // Prendendo l'ultimo di quelli, la media sarebbe "i passi di dieci
      // minuti divisi per venti" - una cadenza dimezzata, e dall'aspetto
      // perfettamente credibile. E' lo stesso errore della velocita' GPS zero
      // letta come "sta fermo".
      final List<RoutePoint> buoni =
          tracciato(cadenze: List<double?>.filled(300, 170.0));
      final int fermo = buoni.last.steps!;
      final List<RoutePoint> congelati = <RoutePoint>[
        ...buoni,
        for (int i = 1; i <= 300; i++)
          RoutePoint(
            latitude: buoni.last.latitude,
            longitude: buoni.last.longitude,
            elapsedSeconds: buoni.last.elapsedSeconds + i * 2,
            speed: 3.0,
            steps: fermo,
          ),
      ];

      final double? media = Cadence.average(congelati);
      expect(media, isNotNull);
      expect(media!, closeTo(170.0, 2.0));
    });

    test('i passi totali sono quelli fatti', () {
      // Dieci minuti a 170: circa 1700 passi.
      final List<RoutePoint> r =
          tracciato(cadenze: List<double?>.filled(300, 170.0));
      final int? passi = Cadence.totalSteps(r);
      expect(passi, isNotNull);
      expect(passi!, closeTo(1700, 15));
    });
  });

  group('le finestre del tracciato', () {
    test('ogni finestra porta la sua cadenza', () {
      final List<RouteWindow> f =
          RouteWindows.of(tracciato(cadenze: List<double?>.filled(300, 168.0)));
      expect(f.length, greaterThan(10));
      for (final RouteWindow finestra in f) {
        expect(finestra.cadenceStepsPerMinute, isNotNull);
        expect(finestra.cadenceStepsPerMinute!, closeTo(168.0, 6.0));
      }
    });

    test('senza passi la finestra non ne inventa', () {
      final List<RouteWindow> f =
          RouteWindows.of(tracciato(cadenze: List<double?>.filled(300, null)));
      expect(f, isNotEmpty);
      for (final RouteWindow finestra in f) {
        expect(finestra.steps, isNull);
        expect(finestra.cadenceStepsPerMinute, isNull);
      }
    });
  });

  group('il profilo disegnato', () {
    test('la cadenza arriva fino al grafico', () {
      final List<ProfileSample> p =
          RunProfile.of(tracciato(cadenze: List<double?>.filled(600, 172.0)));
      expect(RunProfile.canDraw(p), isTrue);
      expect(RunProfile.hasCadence(p), isTrue);

      final List<double> valori = <double>[
        for (final ProfileSample s in p)
          if (s.cadenceStepsPerMinute != null) s.cadenceStepsPerMinute!,
      ];
      expect(valori.length, greaterThan(p.length ~/ 2));
      for (final double v in valori) {
        expect(v, closeTo(172.0, 6.0));
      }
    });

    test('raggruppare per starci nello schermo non cambia la cadenza', () {
      // Venti minuti di corsa fanno sessanta finestre da venti secondi, che
      // vengono unite per stare nei settanta punti del disegno. Unire somma i
      // passi e i secondi: la cadenza deve restare quella.
      final List<RoutePoint> r =
          tracciato(cadenze: List<double?>.filled(600, 165.0));
      final List<ProfileSample> largo = RunProfile.of(r, maxSamples: 1000);
      final List<ProfileSample> stretto = RunProfile.of(r, maxSamples: 20);

      double media(List<ProfileSample> p) {
        final List<double> v = <double>[
          for (final ProfileSample s in p)
            if (s.cadenceStepsPerMinute != null) s.cadenceStepsPerMinute!,
        ];
        return v.reduce((double a, double b) => a + b) / v.length;
      }

      expect(stretto.length, lessThanOrEqualTo(20));
      expect(media(stretto), closeTo(media(largo), 2.0));
    });

    test('letture mancanti non fanno un buco nel grafico', () {
      // QUESTO TEST CHIEDEVA IL CONTRARIO, E CHIEDEVA LA COSA SBAGLIATA.
      //
      // Prima pretendeva che trenta punti senza lettura lasciassero il
      // grafico vuoto li' in mezzo, per non "inventare una cadenza crollata".
      // Ma i passi sono CUMULATIVI, e lo dice gia' il commento di questo
      // file: un buco nella lettura non e' un buco nei passi. La lettura
      // prima del buco e quella dopo bastano a dire esattamente quanti passi
      // ci sono stati e in quanto tempo.
      //
      // Lasciare il vuoto non era prudenza, era buttare via una misura che
      // c'era.
      final List<double?> c = List<double?>.filled(400, 170.0);
      for (int i = 100; i < 130; i++) {
        c[i] = null;
      }
      final List<ProfileSample> p =
          RunProfile.of(tracciato(cadenze: c), maxSamples: 20);

      for (final ProfileSample s in p) {
        expect(s.cadenceStepsPerMinute, isNotNull);
        expect(s.cadenceStepsPerMinute!, closeTo(170.0, 8.0));
      }
    });

    test('un contatore che consegna a lotti non spezza il grafico', () {
      // IL GUASTO VERO, QUELLO CHE NESSUN TEST QUI DENTRO MODELLAVA.
      //
      // I test di questo file simulavano il sensore che "non risponde", cioe'
      // un punto senza passi. Nella realta' non succede quasi mai: l'app
      // tiene l'ultimo valore letto, quindi i punti hanno sempre un numero.
      //
      // Quello che succede davvero e' che il numero RESTA FERMO per decine di
      // secondi e poi salta: il chip dei sensori accumula e consegna a lotti.
      // Su una 16 km a 164 passi al minuto - media giusta, 14.789 passi
      // totali giusti - il grafico usciva in cinque frammenti con il vuoto in
      // mezzo, perche' ogni finestra divideva "i lotti capitati qui dentro"
      // per la sua durata nominale.
      //
      // Qui si ricostruisce quella corsa: valore fermo per 45 secondi, poi il
      // salto.
      const double vera = 164.0;
      const int lotto = 45;
      final List<RoutePoint> corsa = <RoutePoint>[];
      const double gradiLat = 1 / 111320.0;
      double passiVeri = 0;
      int consegnato = 0;
      double metri = 0;
      for (int t = 1; t <= 3600; t++) {
        passiVeri += vera / 60.0;
        metri += 3.0;
        if (t % lotto == 0) consegnato = passiVeri.round();
        corsa.add(RoutePoint(
          latitude: 45.0 + metri * gradiLat,
          longitude: 9.0,
          elapsedSeconds: t,
          altitude: 100.0,
          speed: 3.0,
          steps: consegnato,
        ));
      }

      final List<ProfileSample> p = RunProfile.of(corsa);
      expect(RunProfile.hasCadence(p), isTrue);

      // NESSUN BUCO, e nessun valore inventato: la corsa era regolare, il
      // grafico deve dirlo.
      for (final ProfileSample s in p) {
        expect(s.cadenceStepsPerMinute, isNotNull,
            reason: 'un punto vuoto su una corsa a cadenza costante');
        expect(s.cadenceStepsPerMinute!, closeTo(vera, 4.0),
            reason: 'cadenza ${s.cadenceStepsPerMinute} invece di $vera');
      }
    });

    test('un calo vero di cadenza si vede ancora', () {
      // Il rovescio del test di sopra: la correzione misura su una base piu'
      // lunga, e una base piu' lunga potrebbe spianare proprio la cosa per
      // cui il grafico esiste. Non deve.
      //
      // Cadenza 174 per quaranta minuti, poi un calo a 154 negli ultimi
      // dieci: e' il quadro della stanchezza in un lungo.
      final List<double?> c = <double?>[
        for (int i = 0; i < 1200; i++) i < 960 ? 174.0 : 154.0,
      ];
      final List<ProfileSample> p =
          RunProfile.of(tracciato(cadenze: c, secondiFraPunti: 2));

      final List<double> valori = <double>[
        for (final ProfileSample s in p)
          if (s.cadenceStepsPerMinute != null) s.cadenceStepsPerMinute!,
      ];
      expect(valori.length, greaterThan(p.length ~/ 2));

      final double inizio = valori.first;
      final double fine = valori.last;
      expect(inizio, closeTo(174.0, 5.0), reason: 'inizio $inizio');
      expect(fine, closeTo(154.0, 5.0), reason: 'fine $fine');
      expect(inizio - fine, greaterThan(12.0),
          reason: 'il calo da 174 a 154 si e\' spianato: $inizio -> $fine');
    });

    test('durante una sosta il grafico resta vuoto', () {
      // Qui il buco e' la risposta giusta: se il contatore non cresce, di
      // cadenza non ce n'e'. Riempirlo sarebbe inventare.
      final List<double?> c = <double?>[
        for (int i = 0; i < 900; i++) (i >= 400 && i < 480) ? 0.0 : 168.0,
      ];
      final List<ProfileSample> p =
          RunProfile.of(tracciato(cadenze: c, secondiFraPunti: 2));

      final int senza = p
          .where((ProfileSample s) => s.cadenceStepsPerMinute == null)
          .length;
      expect(senza, greaterThan(0),
          reason: 'una sosta di quasi tre minuti deve lasciare il vuoto');
    });

    test('poca cadenza sparsa non basta per disegnare il riquadro', () {
      final List<double?> c = List<double?>.filled(600, null);
      for (int i = 0; i < 60; i++) {
        c[i] = 170.0;
      }
      final List<ProfileSample> p = RunProfile.of(tracciato(cadenze: c));
      expect(RunProfile.hasCadence(p), isFalse);
    });
  });

  group('il salvataggio', () {
    test('i passi sopravvivono al giro su disco', () {
      const RoutePoint punto = RoutePoint(
        latitude: 45.0,
        longitude: 9.0,
        elapsedSeconds: 120,
        altitude: 50.0,
        speed: 3.2,
        steps: 345,
      );
      final RoutePoint tornato = RoutePoint.fromJson(punto.toJson());
      expect(tornato.steps, 345);
      expect(tornato.speed, 3.2);
    });

    test('le corse vecchie si rileggono senza passi, non con zero', () {
      final RoutePoint vecchio = RoutePoint.fromJson(<String, dynamic>{
        'lat': 45.0,
        'lon': 9.0,
        't': 60,
        'alt': 30.0,
      });
      expect(vecchio.steps, isNull);
    });
  });

  test('i numeri grandi si leggono con il punto', () {
    expect(formatThousands(8543), '8.543');
    expect(formatThousands(999), '999');
    expect(formatThousands(1000000), '1.000.000');
    expect(formatThousands(0), '0');
  });
}
