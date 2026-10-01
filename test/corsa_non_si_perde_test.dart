import 'package:flutter_test/flutter_test.dart';
import 'package:run_coach_app/models/lap.dart';
import 'package:run_coach_app/models/run_snapshot.dart';
import 'package:run_coach_app/models/running_activity.dart';
import 'package:run_coach_app/utils/battery_advice.dart';

/// La corsa non si perde.
///
/// DA DOVE NASCE QUESTO FILE
/// -------------------------
/// Fino a ieri una corsa viveva solo nella memoria del processo. Se Android
/// chiudeva l'app - risparmio energetico, memoria finita, il gestore
/// aggressivo di Xiaomi, un crash - la corsa spariva. Un'ora e mezza di
/// lavoro persa, e nessun modo di riaverla.
///
/// E' il difetto piu' grave possibile per un'app che vive sul telefono,
/// perche' non e' un numero sbagliato: e' il dato che non c'e' piu'. Una
/// stima imprecisa si corregge, una corsa persa no.
void main() {
  final DateTime inizio = DateTime(2026, 9, 30, 18, 0);

  RunSnapshot snapshot({
    int secondi = 2700,
    double metri = 9000,
    List<Lap>? laps,
    List<RoutePoint>? route,
  }) =>
      RunSnapshot(
        startTime: inizio,
        savedAt: inizio.add(Duration(seconds: secondi)),
        elapsedSeconds: secondi,
        distanceMeters: metri,
        name: 'Corsa libera',
        type: ActivityType.free,
        laps: laps ?? <Lap>[],
        route: route ?? <RoutePoint>[],
      );

  group('il salvataggio continuo', () {
    test('andata e ritorno su disco non perde niente', () {
      final RunSnapshot originale = snapshot(
        laps: <Lap>[
          const Lap(
            number: 1,
            distanceMeters: 1000,
            durationSeconds: 320,
            totalTimeSeconds: 320,
            stepLabel: 'Giro 1',
          ),
        ],
        route: <RoutePoint>[
          const RoutePoint(latitude: 45.1, longitude: 9.2, elapsedSeconds: 0),
          const RoutePoint(latitude: 45.2, longitude: 9.3, elapsedSeconds: 60),
        ],
      );

      final RunSnapshot riletto = RunSnapshot.fromJson(originale.toJson());

      expect(riletto.elapsedSeconds, 2700);
      expect(riletto.distanceMeters, 9000);
      expect(riletto.startTime, inizio);
      expect(riletto.type, ActivityType.free);
      expect(riletto.laps.length, 1);
      expect(riletto.laps.first.distanceMeters, 1000);
      expect(riletto.route.length, 2);
      expect(riletto.route.last.elapsedSeconds, 60);
    });

    test('un allenamento programmato resta un allenamento', () {
      final RunSnapshot originale = RunSnapshot(
        startTime: inizio,
        savedAt: inizio,
        elapsedSeconds: 3000,
        distanceMeters: 10000,
        name: 'Ripetute 5 x 1000 m',
        type: ActivityType.workout,
        laps: <Lap>[],
        route: <RoutePoint>[],
        workoutId: 'w-123',
      );
      final RunSnapshot riletto = RunSnapshot.fromJson(originale.toJson());
      expect(riletto.type, ActivityType.workout);
      expect(riletto.workoutId, 'w-123');
      expect(riletto.name, 'Ripetute 5 x 1000 m');
    });

    test('diventa un\'attivita\' vera, pronta da archiviare', () {
      final RunningActivity attivita = snapshot().toActivity();
      expect(attivita.durationSeconds, 2700);
      expect(attivita.distanceMeters, 9000);
      expect(attivita.startTime, inizio);
      // L'id lo genera l'attivita': un salvataggio non e' ancora una corsa.
      expect(attivita.id.isNotEmpty, isTrue);
    });
  });

  group('cosa vale la pena recuperare', () {
    test('un\'ora di corsa si recupera', () {
      expect(snapshot().isWorthRecovering, isTrue);
    });

    test('un avvio per sbaglio no', () {
      // Trenta secondi e cinquanta metri: il pulsante premuto senza volere.
      // Proporre di salvarlo sporcherebbe l'archivio, e l'archivio e' la base
      // di ogni stima che l'app fa.
      expect(snapshot(secondi: 30, metri: 50).isWorthRecovering, isFalse);
    });

    test('nemmeno il telefono in tasca fermo', () {
      // Tempo lungo ma nessun metro: e' rimasta aperta, non e' una corsa.
      expect(snapshot(secondi: 3600, metri: 20).isWorthRecovering, isFalse);
    });

    test('nemmeno due minuti scarsi', () {
      expect(snapshot(secondi: 90, metri: 400).isWorthRecovering, isFalse);
      expect(snapshot(secondi: 200, metri: 700).isWorthRecovering, isTrue);
    });
  });

  group('dove cercare l\'impostazione che spegne le app', () {
    test('le marche con un gestore proprio sono riconosciute', () {
      for (final String marca in <String>[
        'Xiaomi',
        'xiaomi',
        'Redmi',
        'POCO',
        'HUAWEI',
        'samsung',
        'OPPO',
        'realme',
        'vivo',
        'OnePlus',
        'HONOR',
      ]) {
        expect(BatteryAdvice.needsExtraSteps(marca), isTrue, reason: marca);
        expect(BatteryAdvice.stepsFor(marca).length > 40, isTrue,
            reason: 'istruzioni troppo corte per $marca');
      }
    });

    test('Redmi e POCO ricevono le istruzioni di Xiaomi', () {
      // Sono la stessa interfaccia e lo stesso gestore: istruzioni diverse
      // manderebbero l'utente a cercare una voce che non esiste.
      final String xiaomi = BatteryAdvice.stepsFor('Xiaomi');
      expect(BatteryAdvice.stepsFor('Redmi Note 13'), xiaomi);
      expect(BatteryAdvice.stepsFor('POCO'), xiaomi);
    });

    test('le istruzioni nominano la voce giusta, non "le impostazioni"', () {
      // Un consiglio generico non lo segue nessuno. Su Xiaomi la voce che
      // conta davvero e' l'avvio automatico, e va nominata.
      expect(
        BatteryAdvice.stepsFor('Xiaomi').toLowerCase().contains('avvio'),
        isTrue,
      );
    });

    test('una marca sconosciuta riceve le istruzioni generiche', () {
      expect(BatteryAdvice.needsExtraSteps('Fairphone'), isFalse);
      expect(BatteryAdvice.needsExtraSteps(''), isFalse);
      expect(BatteryAdvice.stepsFor('Fairphone').isNotEmpty, isTrue);
      expect(BatteryAdvice.stepsFor(''), BatteryAdvice.stepsFor('Fairphone'));
    });

    test('il nome si mostra con l\'iniziale maiuscola', () {
      expect(BatteryAdvice.displayName('xiaomi'), 'Xiaomi');
      expect(BatteryAdvice.displayName('REDMI'), 'Xiaomi');
      expect(BatteryAdvice.displayName('Fairphone'), '');
    });
  });
}
