import 'package:flutter_test/flutter_test.dart';
import 'package:run_coach_app/models/estimate.dart';
import 'package:run_coach_app/models/running_activity.dart';
import 'package:run_coach_app/services/pace_zone_engine.dart';
import 'package:run_coach_app/services/records_service.dart';
import 'package:run_coach_app/services/run_index_engine.dart';
import 'package:run_coach_app/services/stats_service.dart';
import 'package:run_coach_app/services/training_load_engine.dart';

/// La corsa sul tapis roulant, inserita a mano.
///
/// LA RIGA DI CONFINE, E PERCHE' ESISTE
/// ------------------------------------
/// Su un nastro la distanza non la misura l'applicazione: la dichiara la
/// macchina. E i nastri sbagliano di routine del cinque o dieci per cento,
/// senza che da qui ci sia modo di accorgersene - non c'e' un satellite, un
/// sensore o un confronto che possa smentirli. In piu' a pendenza zero manca
/// la resistenza dell'aria: lo stesso passo, sul nastro, costa meno.
///
/// Da qui la scelta, che questi test tengono ferma:
///
///   I CHILOMETRI CONTANO - volume della settimana, carico, scarpe consumate,
///   corsa piu' lunga. Un'ora di corsa e' un'ora di corsa: le gambe non sanno
///   che il pavimento scorreva, e un piano che non vede quei chilometri
///   calcola la progressione su una base falsa.
///
///   LA VELOCITA' NO - indice di forma, passi di allenamento, record sulle
///   distanze. Tutto quello che dice "vai a questo ritmo" resta fuori, perche'
///   costruirlo su un numero non verificabile vorrebbe dire far decidere i
///   ritmi dell'allenamento alla taratura di un nastro.
///
/// E' una riga sottile e si rompe facilmente: basta che un domani qualcuno
/// aggiunga una fonte, cambi un filtro o tolga un controllo. Per questo e'
/// scritta qui sotto in forma di test, e non solo nei commenti.
void main() {
  final DateTime now = DateTime(2026, 10, 28, 18, 0);

  /// Un'ora sul nastro: 10 km in 55:00, nessun tracciato, nessun parziale.
  RunningActivity tapis({
    double metri = 10000,
    int secondi = 3300,
    int giorniFa = 1,
  }) =>
      RunningActivity(
        startTime: now.subtract(Duration(days: giorniFa)),
        name: 'Tapis roulant',
        type: ActivityType.treadmill,
        durationSeconds: secondi,
        distanceMeters: metri,
      );

  /// La stessa identica corsa, ma col GPS: serve come termine di paragone.
  RunningActivity conGps({
    double metri = 10000,
    int secondi = 3300,
    int giorniFa = 1,
  }) {
    // Un grado di latitudine misurato con lo stesso raggio terrestre che usa
    // il filtro GPS (6.371.008,8 m): cosi' i metri dichiarati e quelli che
    // escono dal tracciato coincidono, invece di stare l'uno per mille sotto.
    // Con il valore arrotondato 111.320 una corsa da 10 km ne produceva
    // 9.988, e il record sui 10 km non scattava: il test sarebbe stato rosso
    // per colpa sua, non dell'applicazione.
    const double gradiPerMetro = 1 / 111195.08;
    final double velocita = metri / secondi;
    final List<RoutePoint> punti = <RoutePoint>[];
    for (int t = 0; t <= secondi; t += 5) {
      punti.add(RoutePoint(
        latitude: 45.0 + velocita * t * gradiPerMetro,
        longitude: 9.0,
        elapsedSeconds: t,
        altitude: 100.0,
        speed: velocita,
      ));
    }
    return RunningActivity(
      startTime: now.subtract(Duration(days: giorniFa)),
      name: 'Uscita',
      type: ActivityType.free,
      durationSeconds: secondi,
      distanceMeters: metri,
      route: punti,
    );
  }

  group('il tipo', () {
    test('andata e ritorno su disco', () {
      final RunningActivity a = tapis();
      final RunningActivity riletta = RunningActivity.fromJson(a.toJson());
      expect(riletta.type, ActivityType.treadmill);
      expect(riletta.distanceMeters, closeTo(10000, 0.5));
      expect(riletta.durationSeconds, 3300);
    });

    test('un archivio vecchio non diventa tapis roulant', () {
      // Le corse salvate prima che questo tipo esistesse non hanno il campo:
      // devono restare corse libere, non trasformarsi in qualcos'altro.
      expect(ActivityTypeLabel.fromStorage(null), ActivityType.free);
      expect(ActivityTypeLabel.fromStorage('free'), ActivityType.free);
      expect(ActivityTypeLabel.fromStorage('workout'), ActivityType.workout);
      expect(
          ActivityTypeLabel.fromStorage('treadmill'), ActivityType.treadmill);
    });

    test('solo il tapis roulant e\' scritto a mano', () {
      expect(ActivityType.treadmill.isManual, isTrue);
      expect(ActivityType.free.isManual, isFalse);
      expect(ActivityType.workout.isManual, isFalse);
    });
  });

  group('i chilometri contano', () {
    test('entrano nel volume della settimana', () {
      final RunningStats soloTapis =
          const StatsService().compute(<RunningActivity>[tapis()], now: now);
      expect(soloTapis.weekKm, closeTo(10.0, 0.01),
          reason: 'i chilometri sul nastro sono chilometri corsi');
      expect(soloTapis.weekActivities, 1);
    });

    test('si sommano a quelli col GPS', () {
      final RunningStats insieme = const StatsService().compute(
        <RunningActivity>[tapis(), conGps(giorniFa: 2)],
        now: now,
      );
      expect(insieme.weekKm, closeTo(20.0, 0.2));
      expect(insieme.weekActivities, 2);
    });

    test('possono essere la corsa piu\' lunga', () {
      // La corsa piu' lunga misura quanto hai corso, non quanto vai forte.
      final PersonalRecords r = const RecordsService().compute(
        <RunningActivity>[
          conGps(metri: 8000, secondi: 2600, giorniFa: 5),
          tapis(metri: 21000, secondi: 7200, giorniFa: 2),
        ],
      );
      expect(r.longestRun, isNotNull);
      expect(r.longestRun!.type, ActivityType.treadmill);
      expect(r.longestRun!.distanceMeters, closeTo(21000, 0.5));
    });

    test('il carico non e\' zero solo perche\' manca il GPS', () {
      final TrainingZones zones = const PaceZoneEngine().zonesFor(
        Estimate<double>(
          value: 45.4,
          confidence: 0.8,
          source: EstimateSource.runSegment,
          updatedAt: now,
        ),
      )!;
      final double? carico =
          const TrainingLoadEngine().loadOf(tapis(), zones);
      expect(carico, isNotNull);
      expect(carico! > 0, isTrue,
          reason: 'un\'ora di corsa e\' costata qualcosa, comunque misurata');
    });
  });

  group('la velocita\' no', () {
    const RunIndexEngine engine = RunIndexEngine();

    test('non produce nessuna prestazione per l\'indice', () {
      final List<PerformanceSample> campioni =
          engine.samplesFromActivities(<RunningActivity>[tapis()], now: now);
      expect(campioni, isEmpty,
          reason: 'la distanza la dichiara il nastro: non puo\' decidere i '
              'passi di allenamento');
    });

    test('la stessa corsa col GPS invece la produce', () {
      // IL CONTROLLO CHE RENDE SENSATO QUELLO SOPRA. Senza, "nessuna
      // prestazione" potrebbe voler dire che il test e' costruito male - una
      // corsa troppo corta, una data troppo vecchia - invece che "il tapis
      // roulant resta fuori".
      final List<PerformanceSample> campioni =
          engine.samplesFromActivities(<RunningActivity>[conGps()], now: now);
      expect(campioni, isNotEmpty);
    });

    test('non sposta l\'indice di un punto', () {
      final RunIndexResult soloGps = engine.estimate(
        engine.samplesFromActivities(
            <RunningActivity>[conGps(metri: 5000, secondi: 1320, giorniFa: 3)],
            now: now),
        now: now,
      );
      final RunIndexResult conTapis = engine.estimate(
        engine.samplesFromActivities(
          <RunningActivity>[
            conGps(metri: 5000, secondi: 1320, giorniFa: 3),
            tapis(metri: 12000, secondi: 3000, giorniFa: 1),
          ],
          now: now,
        ),
        now: now,
      );

      expect(soloGps.index, isNotNull);
      expect(conTapis.index, isNotNull);
      expect(conTapis.index!.value, soloGps.index!.value,
          reason: 'una 12 km sul nastro a 4:10 al km non deve muovere niente');
      expect(conTapis.index!.confidence, soloGps.index!.confidence);
    });

    test('non mette record sulle distanze', () {
      final PersonalRecords r = const RecordsService()
          .compute(<RunningActivity>[tapis(metri: 10000, secondi: 2400)]);
      expect(r.byDistance, isEmpty,
          reason: 'un 10 km in 40:00 sul nastro non e\' un primato tuo, '
              'e\' un primato del nastro');
      expect(r.activitiesWithGps, 0);
    });

    test('non ruba il record a una corsa vera', () {
      // Il caso che fa male: il nastro dice 40:00 sui 10 km, la strada dice
      // 44:00. Se il nastro entrasse nei record, il primato vero sparirebbe.
      final PersonalRecords r = const RecordsService().compute(
        <RunningActivity>[
          tapis(metri: 10000, secondi: 2400, giorniFa: 1),
          // Dodici chilometri invece di dieci: cosi' il tratto da 10 km dentro
          // il tracciato c'e' di sicuro, senza dipendere dall'ultimo metro.
          conGps(metri: 12000, secondi: 3168, giorniFa: 10),
        ],
      );
      final Iterable<DistanceRecord> dieciKm =
          r.byDistance.where((DistanceRecord d) => d.distance.meters == 10000);
      expect(dieciKm, isNotEmpty, reason: 'il 10 km col GPS deve esserci');
      expect(dieciKm.first.seconds, greaterThan(2500),
          reason: 'il record deve essere quello della strada, non del nastro');
    });
  });
}
