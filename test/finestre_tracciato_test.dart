import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:run_coach_app/models/running_activity.dart';
import 'package:run_coach_app/services/route_windows.dart';

/// Che passo si stava tenendo, momento per momento.
///
/// DA DOVE NASCE QUESTO FILE
/// -------------------------
/// La distanza di una corsa viene dalla velocita' che il chip ricava
/// dall'effetto Doppler. Ma a corsa finita l'app rilegge il tracciato per
/// capire **che seduta e' stata** (soglia? ripetute? lento?) e **quanto e'
/// costata**, e per farlo misurava il passo dalle posizioni: lo stesso difetto
/// gia' corretto sulla distanza, un passo piu' in la'.
///
/// Misurato con un errore GPS realistico - che deriva piano, invece di cambiare
/// a ogni secondo - su ripetute con passo vero 3:50/km sul forte e 6:00/km sul
/// recupero:
///
/// | errore GPS | dalle posizioni | dalla velocita' |
/// |---|---|---|
/// | 3 m | 3:49 / 5:44 | **3:52 / 5:54** |
/// | 5 m | 3:49 / 5:42 | **3:52 / 5:54** |
/// | 8 m | 3:47 / 5:38 | **3:52 / 5:54** |
///
/// Pochi secondi, ma sempre nella stessa direzione: il forte sembra piu' veloce
/// e il recupero pure, cioe' la seduta sembra piu' dura di com'e' stata. Nel
/// motore del carico quello scarto viene elevato al quadrato.
///
/// NOTA SU UNA VERSIONE PRECEDENTE DI QUESTO FILE
/// ----------------------------------------------
/// Diceva che con segnale scarso le posizioni davano 2:13/km e facevano
/// sparire i recuperi. Era un artefatto: il rumore era stato simulato come
/// indipendente a ogni secondo, e non e' cosi' che si comporta un GPS.

void main() {
  /// Un tracciato come lo salva l'app: un punto ogni due secondi.
  List<RoutePoint> tracciato(
    List<double> velocitaVere, {
    required double erroreMetri,
    double erroreVelocita = 0.3,
    bool conVelocita = true,
    int secondiFraPunti = 2,
    int seed = 1,
  }) {
    final math.Random random = math.Random(seed);
    double gauss() {
      final double u1 = 1.0 - random.nextDouble();
      final double u2 = random.nextDouble();
      return math.sqrt(-2.0 * math.log(u1)) * math.cos(2 * math.pi * u2);
    }

    const double gradiLat = 1 / 111320.0;
    final double gradiLon = 1 / (111320.0 * math.cos(45.0 * math.pi / 180.0));

    double x = 0;
    return <RoutePoint>[
      for (int i = 0; i < velocitaVere.length; i++)
        () {
          final double v = velocitaVere[i];
          x += v * secondiFraPunti;
          return RoutePoint(
            latitude: 45.0 + gauss() * erroreMetri * gradiLat,
            longitude: 9.0 + (x + gauss() * erroreMetri) * gradiLon,
            elapsedSeconds: (i + 1) * secondiFraPunti,
            speed: conVelocita
                ? math.max(0.0, v + gauss() * erroreVelocita)
                : null,
          );
        }(),
    ];
  }

  /// I passi misurati nelle finestre, in secondi al chilometro.
  List<double> passiDi(List<RoutePoint> route) => <double>[
        for (final RouteWindow w in RouteWindows.of(route))
          if (w.paceSecondsPerKm != null) w.paceSecondsPerKm!,
      ];

  double media(List<double> v) =>
      v.isEmpty ? 0 : v.reduce((double a, double b) => a + b) / v.length;

  group('il passo misurato e\' quello vero', () {
    test('corsa continua: il passo torna, con qualunque segnale', () {
      const double vera = 3.333; // 5:00/km
      const double attesa = 1000 / vera;

      for (final double errore in <double>[3, 5, 8]) {
        final List<double> passi = passiDi(
          tracciato(List<double>.filled(900, vera), erroreMetri: errore),
        );
        expect(passi.isNotEmpty, isTrue);
        final double scarto = (media(passi) - attesa).abs() / attesa * 100;
        expect(scarto < 8, isTrue,
            reason: 'errore GPS $errore m: passo misurato '
                '${media(passi).toStringAsFixed(0)} s/km invece di '
                '${attesa.toStringAsFixed(0)} (${scarto.toStringAsFixed(1)}%)');
      }
    });

    test('ripetute: il forte resta forte e il recupero resta recupero', () {
      // IL test del file. Col metodo vecchio, con segnale scarso, i recuperi
      // sparivano del tutto: tutte le finestre risultavano veloci.
      final List<double> cinquePerMille = <double>[
        for (int giro = 0; giro < 5; giro++) ...<double>[
          ...List<double>.filled(115, 4.35), // ~3:50/km
          ...List<double>.filled(60, 2.78), // ~6:00/km
        ],
      ];

      for (final double errore in <double>[3, 5, 8]) {
        final List<double> passi = passiDi(
          tracciato(cinquePerMille, erroreMetri: errore),
        );
        final List<double> forti =
            passi.where((double p) => p < 290).toList();
        final List<double> lenti =
            passi.where((double p) => p >= 290).toList();

        expect(forti.isNotEmpty, isTrue,
            reason: 'errore $errore m: nessuna finestra veloce trovata');
        expect(lenti.isNotEmpty, isTrue,
            reason: 'errore $errore m: i recuperi sono spariti - e\' il modo '
                'in cui un lento viene scambiato per una seduta dura');

        expect(media(forti) > 200 && media(forti) < 260, isTrue,
            reason: 'errore $errore m: forte a '
                '${media(forti).toStringAsFixed(0)} s/km, atteso ~230');
        expect(media(lenti) > 310 && media(lenti) < 400, isTrue,
            reason: 'errore $errore m: lento a '
                '${media(lenti).toStringAsFixed(0)} s/km, atteso ~360');
      }
    });

    test('nessun passo da record del mondo', () {
      // Due e tredici al chilometro e' quello che usciva prima con il segnale
      // scarso. Nessun essere umano tiene quel passo, e un numero cosi' non
      // deve poter entrare in nessun conto.
      for (final double errore in <double>[3, 5, 8, 15]) {
        final List<double> passi = passiDi(
          tracciato(List<double>.filled(900, 3.333), erroreMetri: errore),
        );
        for (final double p in passi) {
          expect(p > 140, isTrue,
              reason: 'errore $errore m: una finestra a '
                  '${p.toStringAsFixed(0)} s/km');
        }
      }
    });
  });

  group('da dove vengono i metri', () {
    test('con la velocita\' nel tracciato, si usa quella', () {
      final List<RouteWindow> f = RouteWindows.of(
        tracciato(List<double>.filled(300, 3.333), erroreMetri: 5),
      );
      expect(f.isNotEmpty, isTrue);
      expect(f.every((RouteWindow w) => w.fromSpeed), isTrue);
    });

    test('sui tracciati vecchi si torna alle posizioni', () {
      // Le corse registrate prima non hanno la velocita' nei punti. Devono
      // continuare a funzionare come hanno sempre funzionato: peggio, ma mai
      // peggio di prima.
      final List<RouteWindow> f = RouteWindows.of(
        tracciato(List<double>.filled(300, 3.333),
            erroreMetri: 3, conVelocita: false),
      );
      expect(f.isNotEmpty, isTrue);
      expect(f.every((RouteWindow w) => !w.fromSpeed), isTrue);
      expect(f.any((RouteWindow w) => w.paceSecondsPerKm != null), isTrue,
          reason: 'un tracciato vecchio deve restare leggibile');
    });

    test('un tracciato a meta\' non si fida della velocita\'', () {
      // Meta' dei punti con la velocita' e meta' senza: sommare solo quelli
      // che ce l'hanno darebbe una distanza dimezzata. Meglio una misura
      // coerente anche se piu' rumorosa.
      final List<RoutePoint> completo =
          tracciato(List<double>.filled(300, 3.333), erroreMetri: 3);
      final List<RoutePoint> meta = <RoutePoint>[
        for (int i = 0; i < completo.length; i++)
          i % 4 == 0
              ? completo[i]
              : RoutePoint(
                  latitude: completo[i].latitude,
                  longitude: completo[i].longitude,
                  elapsedSeconds: completo[i].elapsedSeconds,
                )
      ];
      final List<RouteWindow> f = RouteWindows.of(meta);
      expect(f.every((RouteWindow w) => !w.fromSpeed), isTrue);
    });
  });

  group('le finestre, come oggetto', () {
    test('escono in ordine di tempo', () {
      // L'ordine e' parte del contratto: e' quello che distingue un minuto di
      // lavoro continuo da tre finestre veloci sparse in mezz'ora.
      final List<RouteWindow> f = RouteWindows.of(
        tracciato(List<double>.filled(300, 3.333), erroreMetri: 3),
      );
      for (final RouteWindow w in f) {
        expect(w.seconds >= RouteWindows.defaultWindowSeconds, isTrue,
            reason: 'finestra da ${w.seconds} s');
      }
    });

    test('un passo impossibile diventa un buco, non una zona a caso', () {
      final RouteWindow fermo =
          const RouteWindow(seconds: 20, meters: 1, fromSpeed: true);
      expect(fermo.paceSecondsPerKm, isNull);

      final RouteWindow assurdo =
          const RouteWindow(seconds: 20, meters: 400, fromSpeed: true);
      expect(assurdo.paceSecondsPerKm, isNull,
          reason: '50 s/km non e\' un passo umano');

      final RouteWindow lentissimo =
          const RouteWindow(seconds: 20, meters: 10, fromSpeed: true);
      expect(lentissimo.paceSecondsPerKm, isNull,
          reason: 'mezz\'ora al chilometro e\' una sosta, non un passo');
    });

    test('un tracciato troppo corto non produce finestre', () {
      expect(RouteWindows.of(const <RoutePoint>[]), isEmpty);
      expect(
        RouteWindows.of(<RoutePoint>[
          const RoutePoint(latitude: 45, longitude: 9, elapsedSeconds: 0),
        ]),
        isEmpty,
      );
    });
  });

  group('la velocita\' sopravvive al salvataggio', () {
    test('andata e ritorno su disco', () {
      const RoutePoint p = RoutePoint(
        latitude: 45.1,
        longitude: 9.2,
        elapsedSeconds: 42,
        altitude: 120.5,
        speed: 3.47,
      );
      final RoutePoint riletto = RoutePoint.fromJson(p.toJson());
      expect(riletto.speed, 3.47);
      expect(riletto.altitude, 120.5);
      expect(riletto.elapsedSeconds, 42);
    });

    test('un punto vecchio si rilegge senza velocita\'', () {
      final RoutePoint vecchio = RoutePoint.fromJson(<String, dynamic>{
        'lat': 45.0,
        'lon': 9.0,
        't': 10,
        'alt': 100.0,
      });
      expect(vecchio.speed, isNull);
      expect(vecchio.latitude, 45.0);
    });
  });
}
