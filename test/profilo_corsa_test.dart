import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:run_coach_app/models/running_activity.dart';
import 'package:run_coach_app/services/elevation_service.dart';
import 'package:run_coach_app/services/run_profile.dart';

/// Il profilo della corsa: passo e quota lungo il percorso.
///
/// DA DOVE NASCE QUESTO FILE
/// -------------------------
/// La tabella dei giri dice il passo di ogni chilometro. Non serve a capire
/// **dentro** un chilometro: una ripetuta da 400 metri sparisce nella media del
/// suo chilometro, un calo negli ultimi due minuti pure, e una salita che ti ha
/// fatto perdere venti secondi sembra una giornata storta.
///
/// Il rischio di un grafico e' che si calcoli i numeri per conto suo e finisca
/// per mostrare una corsa diversa da quella scritta sopra. Qui i numeri vengono
/// dagli stessi conti della distanza e del dislivello, e il test tiene ferma
/// quella promessa.
void main() {
  /// Un tracciato con un profilo di velocita' e uno di quota decisi dal test.
  List<RoutePoint> tracciato({
    required List<double> velocita,
    List<double>? quote,
    bool conVelocita = true,
    int secondiFraPunti = 2,
    bool anello = false,
  }) {
    const double gradiLat = 1 / 111320.0;
    final double gradiLon = 1 / (111320.0 * math.cos(45.0 * math.pi / 180.0));
    double x = 0;
    final int n = velocita.length;
    return <RoutePoint>[
      for (int i = 0; i < n; i++)
        () {
          x += velocita[i] * secondiFraPunti;
          return RoutePoint(
            latitude: anello
                ? 45.0 + 0.004 * math.sin(2 * math.pi * i / n)
                : 45.0,
            longitude: anello
                ? 9.0 + 0.006 * math.cos(2 * math.pi * i / n)
                : 9.0 + x * gradiLon,
            elapsedSeconds: (i + 1) * secondiFraPunti,
            altitude: quote == null ? null : quote[i],
            speed: conVelocita ? velocita[i] : null,
          );
        }(),
    ];
  }

  group('il profilo racconta la corsa', () {
    test('un passo costante da' ' una linea piatta', () {
      final List<ProfileSample> p =
          RunProfile.of(tracciato(velocita: List<double>.filled(600, 3.333)));
      expect(RunProfile.canDraw(p), isTrue);

      final List<double> passi = <double>[
        for (final ProfileSample s in p)
          if (s.paceSecondsPerKm != null) s.paceSecondsPerKm!,
      ];
      final double minimo = passi.reduce(math.min);
      final double massimo = passi.reduce(math.max);
      expect(massimo - minimo < 8, isTrue,
          reason: 'passo da ${minimo.toStringAsFixed(0)} a '
              '${massimo.toStringAsFixed(0)} s/km su un passo costante');
    });

    test('le ripetute si vedono come denti di sega', () {
      // Il motivo per cui il grafico esiste: nella media del chilometro questo
      // disegno sparirebbe.
      final List<double> alternato = <double>[
        for (int i = 0; i < 900; i++) (i ~/ 60) % 2 == 0 ? 4.35 : 2.78,
      ];
      final List<ProfileSample> p =
          RunProfile.of(tracciato(velocita: alternato));

      final List<double> passi = <double>[
        for (final ProfileSample s in p)
          if (s.paceSecondsPerKm != null) s.paceSecondsPerKm!,
      ];
      expect(passi.reduce(math.max) - passi.reduce(math.min) > 80, isTrue,
          reason: 'fra il piu\' veloce e il piu\' lento ci devono essere piu\' '
              'di 80 s/km: altrimenti il grafico appiattisce le ripetute');
    });

    test('la distanza cresce e finisce dove finisce la corsa', () {
      final List<ProfileSample> p =
          RunProfile.of(tracciato(velocita: List<double>.filled(600, 3.333)));
      for (int i = 1; i < p.length; i++) {
        expect(p[i].meters >= p[i - 1].meters, isTrue,
            reason: 'la distanza non puo\' tornare indietro');
      }
      // 600 punti x 2 s x 3,333 m/s = 4000 m
      expect(p.last.meters > 3700 && p.last.meters < 4100, isTrue,
          reason: 'arrivato a ${p.last.meters.toStringAsFixed(0)} m');
    });

    test('una sosta diventa un buco, non uno zero', () {
      // Una linea che scende a zero direbbe "fermo a passo infinito". Il buco
      // e' la verita': li' il passo non si poteva dire.
      final List<double> conSosta = <double>[
        ...List<double>.filled(200, 3.333),
        ...List<double>.filled(100, 0.0),
        ...List<double>.filled(200, 3.333),
      ];
      final List<ProfileSample> p =
          RunProfile.of(tracciato(velocita: conSosta));
      expect(p.any((ProfileSample s) => s.paceSecondsPerKm == null), isTrue,
          reason: 'la sosta deve lasciare un buco');
      for (final ProfileSample s in p) {
        final double? passo = s.paceSecondsPerKm;
        if (passo != null) {
          expect(passo < 1500, isTrue,
              reason: 'passo $passo: una sosta non deve entrare come numero');
        }
      }
    });
  });

  group('la quota del grafico e\' quella del dislivello', () {
    test('lo stesso conto per il numero e per il disegno', () {
      // Se il grafico ripulisse la quota in modo diverso da chi conta il
      // dislivello, il numero scritto sotto non sarebbe quello del disegno.
      const ElevationService servizio = ElevationService();
      final List<double> salita = <double>[
        for (int i = 0; i < 800; i++) 100 + 50 * i / 800,
      ];
      final List<RoutePoint> route = tracciato(
        velocita: List<double>.filled(800, 3.333),
        quote: salita,
      );

      final List<double?> ripulite = servizio.smoothedAltitudes(route);
      final List<ProfileSample> p = RunProfile.of(route);

      expect(ripulite.where((double? q) => q != null).length, 800);
      expect(RunProfile.hasAltitude(p), isTrue);

      // Il profilo deve salire quanto dice il dislivello.
      final List<double> quoteProfilo = <double>[
        for (final ProfileSample s in p)
          if (s.altitude != null) s.altitude!,
      ];
      final double saltoProfilo =
          quoteProfilo.last - quoteProfilo.first;
      final ElevationSummary somma = servizio.of(route);
      expect((saltoProfilo - somma.gainMeters).abs() < 12, isTrue,
          reason: 'profilo sale ${saltoProfilo.toStringAsFixed(0)} m, '
              'il dislivello dice ${somma.gainMeters.toStringAsFixed(0)} m');
    });

    test('senza quota il grafico lo sa', () {
      final List<ProfileSample> p =
          RunProfile.of(tracciato(velocita: List<double>.filled(600, 3.333)));
      expect(RunProfile.hasAltitude(p), isFalse);
      expect(RunProfile.canDraw(p), isTrue,
          reason: 'il passo si disegna lo stesso');
    });
  });

  group('quando non c\'e\' niente da disegnare', () {
    test('tracciato vuoto', () {
      expect(RunProfile.of(const <RoutePoint>[]), isEmpty);
      expect(RunProfile.canDraw(const <ProfileSample>[]), isFalse);
    });

    test('una corsa troppo corta non fa un grafico', () {
      final List<ProfileSample> p =
          RunProfile.of(tracciato(velocita: List<double>.filled(40, 3.333)));
      expect(RunProfile.canDraw(p), isFalse,
          reason: 'con ${p.length} punti sarebbe una linea con tre spigoli');
    });

    test('un tracciato vecchio, senza velocita\', si disegna lo stesso', () {
      final List<ProfileSample> p = RunProfile.of(
        tracciato(
          velocita: List<double>.filled(600, 3.333),
          conVelocita: false,
        ),
      );
      expect(RunProfile.canDraw(p), isTrue,
          reason: 'le corse registrate prima devono restare leggibili');
    });
  });
}
