import 'package:flutter_test/flutter_test.dart';
import 'package:run_coach_app/models/running_activity.dart';
import 'package:run_coach_app/services/records_service.dart';
import 'package:run_coach_app/services/route_gaps.dart';
import 'package:run_coach_app/services/route_windows.dart';

/// Il cronometro in pausa mentre si continua a correre.
///
/// Il caso vero: riscaldamento chiacchierando con un amico, pausa, si
/// continua a correre, START. I record sono diventati 1 km in 2:27, 3 km in
/// 12:01, 5 km in 21:32 - perche' i metri fatti in pausa entravano nel
/// tracciato "a tempo zero".
void main() {
  const double metriPerGrado = 111195.0;
  const RecordsService records = RecordsService();

  /// 3 km a 4:30/km, pausa durante la quale si fanno [metriInPausa] metri,
  /// poi altri 3 km a 4:30/km. Un punto ogni 2 secondi.
  List<RoutePoint> corsaConPausa({
    required double metriInPausa,
    required bool segnata,
  }) {
    const double metriAlSecondo = 1000 / 270;
    final List<RoutePoint> punti = <RoutePoint>[];
    double metri = 0;
    int t = 0;
    void tratto(double lunghezza, {bool primoDopoPausa = false}) {
      final double fine = metri + lunghezza;
      bool primo = primoDopoPausa;
      while (metri < fine - 0.01) {
        metri += 2 * metriAlSecondo;
        t += 2;
        punti.add(RoutePoint(
          latitude: 45.0 + metri / metriPerGrado,
          longitude: 9.0,
          elapsedSeconds: t,
          speed: metriAlSecondo,
          resumed: primo,
        ));
        primo = false;
      }
    }

    punti.add(const RoutePoint(latitude: 45.0, longitude: 9.0, elapsedSeconds: 0));
    tratto(3000);
    // La pausa: il cronometro e' fermo, le gambe no.
    metri += metriInPausa;
    tratto(3000, primoDopoPausa: segnata);
    return punti;
  }

  test('con il segno di ripresa, il km migliore resta 4:30', () {
    final List<RoutePoint> r = corsaConPausa(metriInPausa: 700, segnata: true);
    expect(records.fastestTimeForDistance(r, 1000), closeTo(270, 3));
    expect(records.fastestTimeForDistance(r, 5000), closeTo(1350, 6));
  });

  test('senza segno (corse salvate prima): il limite fisico lo scarta', () {
    final List<RoutePoint> r = corsaConPausa(metriInPausa: 700, segnata: false);
    expect(records.fastestTimeForDistance(r, 1000), closeTo(270, 3));
    expect(records.fastestTimeForDistance(r, 3000), closeTo(810, 5));
  });

  test('prima della correzione sarebbe stato un record impossibile', () {
    // La stessa corsa misurata come prima: il tratto della pausa conta.
    final List<RoutePoint> r = corsaConPausa(metriInPausa: 700, segnata: false);
    double metri = 0;
    for (int i = 1; i < r.length; i++) {
      final double d = (r[i].latitude - r[i - 1].latitude) * metriPerGrado;
      if (RouteGaps.skip(r[i - 1], r[i], d)) metri += d;
    }
    expect(metri, greaterThan(650), reason: 'il salto della pausa c\'e\'');
  });

  test('i passi veri non vengono mai scartati, nemmeno in volata', () {
    const RoutePoint a = RoutePoint(latitude: 45, longitude: 9, elapsedSeconds: 10);
    const RoutePoint b = RoutePoint(latitude: 45, longitude: 9, elapsedSeconds: 12);
    // 2:30 al km per due secondi: 13 metri e mezzo.
    expect(RouteGaps.skip(a, b, 13.4), isFalse);
    // Fermo, due punti con lo stesso tempo e un metro di rumore.
    expect(RouteGaps.skip(a, a, 1.0), isFalse);
  });

  test('il segno sopravvive al salvataggio', () {
    const RoutePoint p = RoutePoint(
        latitude: 45, longitude: 9, elapsedSeconds: 100, resumed: true);
    expect(RoutePoint.fromJson(p.toJson()).resumed, isTrue);
    const RoutePoint q = RoutePoint(latitude: 45, longitude: 9, elapsedSeconds: 102);
    expect(q.toJson().containsKey('r'), isFalse);
    expect(RoutePoint.fromJson(q.toJson()).resumed, isFalse);
  });

  test('le finestre lette dalle posizioni saltano la pausa', () {
    // Senza velocita' del chip: si torna alle posizioni.
    final List<RoutePoint> r = <RoutePoint>[
      for (final RoutePoint p in corsaConPausa(metriInPausa: 700, segnata: true))
        RoutePoint(
          latitude: p.latitude,
          longitude: p.longitude,
          elapsedSeconds: p.elapsedSeconds,
          resumed: p.resumed,
        ),
    ];
    double totale = 0;
    for (final RouteWindow w in RouteWindows.of(r)) {
      totale += w.meters;
    }
    expect(totale, closeTo(6000, 60));
  });
}
