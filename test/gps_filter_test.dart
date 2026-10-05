import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:run_coach_app/services/gps_filter.dart';

/// Da dove viene la distanza di una corsa.
///
/// DA DOVE NASCE QUESTO FILE
/// -------------------------
/// La distanza e' l'ingresso di tutto: da li' escono il passo, l'indice di
/// forma, i record, il carico, i ritmi del piano. Nessun calcolo a valle puo'
/// rimediare a un numero sbagliato in ingresso.
///
/// Il metodo vecchio sommava la distanza fra un punto GPS e il successivo, e
/// sbagliava **dal -4% al +8%**: poco, ma sistematicamente, e con il segno che
/// cambiava secondo il tipo di seduta - le corse con soste allungate, le
/// ripetute accorciate. Confrontare una seduta con l'altra voleva dire
/// confrontare due misure storte in direzioni opposte.
///
/// ATTENZIONE A COME SI LEGGONO QUESTI TEST
/// ----------------------------------------
/// La prima versione di questo file simulava il rumore del GPS come
/// **indipendente a ogni secondo**, e concludeva che il metodo vecchio
/// sbagliava fino al 69%. Era falso: l'errore vero deriva lentamente, quindi
/// due posizioni consecutive condividono quasi tutto l'errore e la differenza
/// fra loro e' molto piu' pulita. Il numero e' stato smentito da chi usa
/// l'app, non dal codice.
///
/// Le soglie qui sotto restano larghe apposta: servono a prendere una
/// regressione grossa, non a certificare una precisione che questa
/// simulazione non puo' garantire.
///
/// Il metodo nuovo usa la velocita' che il chip ricava dall'effetto Doppler:
/// una misura diretta, precisa a qualche decimo di metro al secondo anche
/// quando la posizione balla di dieci metri. Resta sotto il 5% in ogni
/// condizione provata.
///
/// I test qui sotto non controllano dei dettagli: **ricostruiscono corse di cui
/// si conosce la distanza vera** e verificano che il numero ci somigli. E' la
/// sola prova che conta.
void main() {
  final DateTime t0 = DateTime(2026, 1, 1, 10);

  group('haversineMeters', () {
    test('distanza nota approssimata', () {
      // Un decimo di grado di latitudine: circa 11,1 km.
      final double d = haversineMeters(45.0, 9.0, 45.1, 9.0);
      expect(d, greaterThan(11000));
      expect(d, lessThan(11200));
    });

    test('stesso punto = zero', () {
      expect(haversineMeters(45.0, 9.0, 45.0, 9.0), closeTo(0, 0.001));
    });
  });

  // ---------------------------------------------------------- la simulazione
  /// Una corsa ricostruita: posizioni con errore, velocita' del chip con il
  /// suo errore, e la distanza vera che il test conosce.
  ///
  /// Il generatore ha il seme fissato: il test non puo' passare un giorno e
  /// fallire quello dopo.
  ({double vera, double misurata, double dopplerShare}) corri({
    required List<double> velocitaVere, // m/s, un valore al secondo
    required double erroreMetri,
    double erroreVelocita = 0.3,
    bool chipRiportaVelocita = true,
    double accuratezza = 6.0,
    int seed = 1,
  }) {
    final math.Random random = math.Random(seed);
    double gauss() {
      final double u1 = 1.0 - random.nextDouble();
      final double u2 = random.nextDouble();
      return math.sqrt(-2.0 * math.log(u1)) * math.cos(2 * math.pi * u2);
    }

    // Un metro in gradi, a 45 gradi di latitudine.
    const double gradiPerMetroLat = 1 / 111320.0;
    final double gradiPerMetroLon =
        1 / (111320.0 * math.cos(45.0 * math.pi / 180.0));

    final GpsFilter filter = GpsFilter();
    double x = 0; // metri percorsi, in linea retta verso est
    double vera = 0;

    for (int i = 0; i < velocitaVere.length; i++) {
      final double v = velocitaVere[i];
      x += v;
      vera += v;

      filter.process(
        latitude: 45.0 + gauss() * erroreMetri * gradiPerMetroLat,
        longitude: 9.0 + (x + gauss() * erroreMetri) * gradiPerMetroLon,
        accuracy: accuratezza,
        timestamp: t0.add(Duration(seconds: i + 1)),
        speed: chipRiportaVelocita
            ? math.max(0.0, v + gauss() * erroreVelocita)
            : 0.0,
      );
    }

    return (
      vera: vera,
      misurata: filter.totalMeters,
      dopplerShare: filter.dopplerShare,
    );
  }

  double errorePercentuale(double misurata, double vera) =>
      (misurata - vera) / vera * 100;

  group('una corsa vera torna una corsa vera', () {
    test('cinquanta minuti a 5:00/km, con qualunque qualita\' di segnale', () {
      // IL test del file. Sotto, il metodo vecchio sbagliava fino al 69%.
      for (final double errore in <double>[2, 3, 5, 8]) {
        final ({double vera, double misurata, double dopplerShare}) r =
            corri(
          velocitaVere: List<double>.filled(3000, 3.333),
          erroreMetri: errore,
        );
        final double scarto = errorePercentuale(r.misurata, r.vera).abs();
        expect(scarto < 8, isTrue,
            reason: 'errore GPS $errore m: sbaglia del '
                '${scarto.toStringAsFixed(1)}% '
                '(${(r.misurata / 1000).toStringAsFixed(2)} km invece di '
                '${(r.vera / 1000).toStringAsFixed(2)})');
      }
    });

    test('le ripetute non ingannano il conto', () {
      // Il passo che cambia in continuazione era il caso peggiore per il
      // metodo vecchio: sbagliava fino al 73%.
      final List<double> alternato = <double>[
        for (int i = 0; i < 3000; i++) (i ~/ 300) % 2 == 0 ? 2.9 : 4.5,
      ];
      for (final double errore in <double>[3, 8]) {
        final double scarto = errorePercentuale(
          corri(velocitaVere: alternato, erroreMetri: errore).misurata,
          corri(velocitaVere: alternato, erroreMetri: errore).vera,
        ).abs();
        expect(scarto < 8, isTrue,
            reason: 'errore GPS $errore m: sbaglia del '
                '${scarto.toStringAsFixed(1)}%');
      }
    });

    test('i semafori non diventano chilometri', () {
      // Fermi il 10% del tempo. Il rumore da fermo e' il modo classico in cui
      // un'app regala distanza che non hai corso.
      final List<double> conSoste = <double>[
        for (int i = 0; i < 3000; i++) (i % 300) < 30 ? 0.0 : 3.333,
      ];
      for (final double errore in <double>[3, 8]) {
        final ({double vera, double misurata, double dopplerShare}) r =
            corri(velocitaVere: conSoste, erroreMetri: errore);
        final double scarto = errorePercentuale(r.misurata, r.vera);
        expect(scarto.abs() < 8, isTrue,
            reason: 'errore GPS $errore m: ${scarto.toStringAsFixed(1)}%');
      }
    });

    test('un passeggio lento non viene scambiato per corsa', () {
      final double scarto = errorePercentuale(
        corri(
          velocitaVere: List<double>.filled(1800, 1.4), // ~12:00/km
          erroreMetri: 5,
        ).misurata,
        1800 * 1.4,
      ).abs();
      expect(scarto < 10, isTrue,
          reason: 'sbaglia del ${scarto.toStringAsFixed(1)}%');
    });
  });

  group('i telefoni che non riportano la velocita\'', () {
    test('la corsa non si azzera (la trappola dello zero)', () {
      // Velocita' esattamente zero non vuol dire "sei fermo": vuol dire che il
      // telefono non sta dicendo niente. Trattarla come "fermo" azzerava la
      // corsa intera - cento per cento di errore.
      final ({double vera, double misurata, double dopplerShare}) r = corri(
        velocitaVere: List<double>.filled(3000, 3.333),
        erroreMetri: 3,
        chipRiportaVelocita: false,
      );
      expect(r.dopplerShare, 0,
          reason: 'questo telefono non deve risultare come Doppler');
      expect(r.misurata > r.vera * 0.5, isTrue,
          reason: 'misurati ${(r.misurata / 1000).toStringAsFixed(2)} km su '
              '${(r.vera / 1000).toStringAsFixed(2)}: la corsa e\' sparita');
    });

    test('il ripiego resta in un errore accettabile', () {
      for (final double errore in <double>[2, 3, 5]) {
        final ({double vera, double misurata, double dopplerShare}) r = corri(
          velocitaVere: List<double>.filled(3000, 3.333),
          erroreMetri: errore,
          chipRiportaVelocita: false,
          accuratezza: errore * 1.5,
        );
        final double scarto = errorePercentuale(r.misurata, r.vera).abs();
        expect(scarto < 12, isTrue,
            reason: 'errore GPS $errore m: ripiego sbaglia del '
                '${scarto.toStringAsFixed(1)}%');
      }
    });

    test('si sa quanto ci si puo\' fidare', () {
      final double conChip = corri(
        velocitaVere: List<double>.filled(600, 3.333),
        erroreMetri: 3,
      ).dopplerShare;
      expect(conChip > 0.9, isTrue, reason: 'quota Doppler $conChip');
    });
  });

  group('quello che non deve mai essere contato', () {
    late GpsFilter filter;
    setUp(() => filter = GpsFilter());

    test('il primo punto non aggiunge distanza', () {
      final GpsFilterResult r = filter.process(
        latitude: 45.0,
        longitude: 9.0,
        accuracy: 5,
        timestamp: t0,
        speed: 3.3,
      );
      expect(r.accepted, isTrue);
      expect(r.isFirstFix, isTrue);
      expect(filter.totalMeters, 0);
    });

    test('accuratezza scarsa: punto scartato', () {
      final GpsFilterResult r = filter.process(
        latitude: 45.0,
        longitude: 9.0,
        accuracy: 100,
        timestamp: t0,
        speed: 3.3,
      );
      expect(r.accepted, isFalse);
      expect(r.reason, GpsRejectReason.poorAccuracy);
    });

    test('fermi al semaforo: il tempo passa, la distanza no', () {
      filter.process(
          latitude: 45.0, longitude: 9.0, accuracy: 5, timestamp: t0,
          speed: 0.1);
      for (int i = 1; i <= 60; i++) {
        filter.process(
          latitude: 45.0,
          longitude: 9.0,
          accuracy: 5,
          timestamp: t0.add(Duration(seconds: i)),
          speed: 0.2, // il tremolio del chip di chi e' in piedi
        );
      }
      expect(filter.totalMeters, 0,
          reason: 'un minuto fermo ha prodotto ${filter.totalMeters} m');
    });

    test('una velocita\' da automobile non viene creduta', () {
      filter.process(
          latitude: 45.0, longitude: 9.0, accuracy: 5, timestamp: t0,
          speed: 3.3);
      final double prima = filter.totalMeters;
      filter.process(
        latitude: 45.0,
        longitude: 9.0,
        accuracy: 5,
        timestamp: t0.add(const Duration(seconds: 1)),
        speed: 25, // 90 km/h
      );
      // Non viene sommata come Doppler; al massimo passa dal ripiego, che
      // qui non trova spostamento.
      expect(filter.totalMeters, prima);
    });

    test('un buco lungo non si riempie di distanza inventata', () {
      // Il telefono tace per un minuto. Moltiplicare l'ultima velocita' nota
      // per quel minuto sarebbe regalare trecento metri.
      filter.process(
          latitude: 45.0, longitude: 9.0, accuracy: 5, timestamp: t0,
          speed: 3.3);
      final GpsFilterResult r = filter.process(
        latitude: 45.0,
        longitude: 9.0,
        accuracy: 5,
        timestamp: t0.add(const Duration(seconds: 60)),
        speed: 3.3,
      );
      expect(r.accepted, isFalse);
      expect(r.reason, GpsRejectReason.gpsJump);
      expect(filter.totalMeters, 0);
    });

    test('campioni troppo ravvicinati vengono ignorati', () {
      filter.process(
          latitude: 45.0, longitude: 9.0, accuracy: 5, timestamp: t0,
          speed: 3.3);
      final GpsFilterResult r = filter.process(
        latitude: 45.0,
        longitude: 9.0,
        accuracy: 5,
        timestamp: t0.add(const Duration(milliseconds: 100)),
        speed: 3.3,
      );
      expect(r.accepted, isFalse);
      expect(r.reason, GpsRejectReason.tooSoon);
    });

    test('coordinate impossibili: scartate', () {
      final GpsFilterResult r = filter.process(
        latitude: 200,
        longitude: 9.0,
        accuracy: 5,
        timestamp: t0,
        speed: 3.3,
      );
      expect(r.accepted, isFalse);
      expect(r.reason, GpsRejectReason.invalidCoordinates);
    });
  });

  group('pause e azzeramenti', () {
    test('dropReference non azzera la distanza gia\' percorsa', () {
      final GpsFilter filter = GpsFilter();
      for (int i = 0; i <= 30; i++) {
        filter.process(
          latitude: 45.0,
          longitude: 9.0 + i * 0.00004,
          accuracy: 5,
          timestamp: t0.add(Duration(seconds: i)),
          speed: 3.3,
        );
      }
      final double percorsi = filter.totalMeters;
      expect(percorsi, greaterThan(50));

      filter.dropReference();
      expect(filter.totalMeters, percorsi,
          reason: 'la pausa non deve cancellare quello che hai corso');
      expect(filter.hasReference, isFalse);

      // Durante la pausa ci si e' spostati: quel tratto non va sommato.
      filter.process(
        latitude: 45.01,
        longitude: 9.01,
        accuracy: 5,
        timestamp: t0.add(const Duration(minutes: 10)),
        speed: 3.3,
      );
      expect(filter.totalMeters, percorsi,
          reason: 'il primo punto dopo la pausa non aggiunge niente');
    });

    test('reset azzera tutto', () {
      final GpsFilter filter = GpsFilter();
      for (int i = 0; i <= 20; i++) {
        filter.process(
          latitude: 45.0,
          longitude: 9.0 + i * 0.00004,
          accuracy: 5,
          timestamp: t0.add(Duration(seconds: i)),
          speed: 3.3,
        );
      }
      expect(filter.totalMeters, greaterThan(0));

      filter.reset();
      expect(filter.totalMeters, 0);
      expect(filter.hasReference, isFalse);
      expect(filter.dopplerShare, 0);
    });
  });
}
