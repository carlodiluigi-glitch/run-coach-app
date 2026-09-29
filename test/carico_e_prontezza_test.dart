import 'package:flutter_test/flutter_test.dart';
import 'package:run_coach_app/models/daily_checkin.dart';
import 'package:run_coach_app/models/estimate.dart';
import 'package:run_coach_app/models/running_activity.dart';
import 'package:run_coach_app/services/pace_zone_engine.dart';
import 'package:run_coach_app/services/readiness_engine.dart';
import 'package:run_coach_app/services/training_load_engine.dart';

/// Il carico, la fatica e la prontezza.
///
/// La regola di tutto il motore adattivo e' una sola: **mai un numero senza i
/// suoi motivi, mai un motivo inventato**. Questi test tengono ferme le poche
/// cose che non possono sbagliare.
void main() {
  const TrainingLoadEngine load = TrainingLoadEngine();
  const ReadinessEngine readiness = ReadinessEngine();
  const PaceZoneEngine zoneEngine = PaceZoneEngine();

  final DateTime oggi = DateTime(2026, 9, 29);

  final TrainingZones zones = zoneEngine.zonesFor(Estimate<double>(
    value: 45.4,
    confidence: 0.8,
    source: EstimateSource.runSegment,
    updatedAt: oggi,
  ))!;

  final double soglia = zones[TrainingZone.threshold].centre;

  /// Un tracciato rettilineo a un passo dato.
  List<RoutePoint> tracciato(double metri, double passoSecPerKm) {
    const double gradiPerMetro = 1 / 111195.0;
    const double passo = 10;
    final List<RoutePoint> punti = <RoutePoint>[
      const RoutePoint(latitude: 45, longitude: 9, elapsedSeconds: 0),
    ];
    double fatti = 0;
    double tempo = 0;
    while (fatti < metri) {
      fatti += passo;
      tempo += passo / 1000.0 * passoSecPerKm;
      punti.add(RoutePoint(
        latitude: 45 + fatti * gradiPerMetro,
        longitude: 9,
        elapsedSeconds: tempo.round(),
      ));
    }
    return punti;
  }

  RunningActivity corsa({
    required double metri,
    required double passo,
    int daysAgo = 0,
    bool conTracciato = true,
  }) {
    final List<RoutePoint> route =
        conTracciato ? tracciato(metri, passo) : <RoutePoint>[];
    final int secondi = (metri / 1000.0 * passo).round();
    return RunningActivity(
      id: 'a$daysAgo-${metri.round()}',
      startTime: oggi.subtract(Duration(days: daysAgo)),
      name: 'Corsa',
      type: ActivityType.free,
      durationSeconds: secondi,
      distanceMeters: metri,
      route: route,
    );
  }

  group('il carico si misura in sforzo, non in chilometri', () {
    test('un\'ora esatta a ritmo soglia fa circa 100 punti', () {
      // E' la definizione dell'unita': se questo si sposta, si sposta tutto.
      final double metri = 3600 / soglia * 1000;
      final double? punti =
          load.loadOf(corsa(metri: metri, passo: soglia), zones);

      expect(punti, isNotNull);
      expect(punti!, closeTo(100, 8), reason: '$punti punti');
    });

    test('un\'ora di lento pesa molto meno di un\'ora di soglia', () {
      final double metriLento = 3600 / 320 * 1000; // 5:20 al km
      final double metriSoglia = 3600 / soglia * 1000;

      final double lento =
          load.loadOf(corsa(metri: metriLento, passo: 320), zones)!;
      final double sogliaPunti =
          load.loadOf(corsa(metri: metriSoglia, passo: soglia), zones)!;

      expect(lento < sogliaPunti * 0.85, isTrue,
          reason: 'lento $lento, soglia $sogliaPunti');
    });

    test('piu\' corto ma piu\' forte puo\' pesare di piu\'', () {
      // Mezz'ora di ripetute contro un'ora di lento: meno chilometri, piu'
      // carico. E' esattamente quello che i chilometri non sanno dire.
      final double ripetute = load.loadOf(
        corsa(metri: 30 * 60 / 256 * 1000, passo: 256),
        zones,
      )!;
      final double lento = load.loadOf(
        corsa(metri: 40 * 60 / 320 * 1000, passo: 320),
        zones,
      )!;
      expect(ripetute > lento, isTrue,
          reason: 'ripetute $ripetute, lento $lento');
    });

    test('il carico cresce con la durata', () {
      final double mezza =
          load.loadOf(corsa(metri: 5000, passo: 320), zones)!;
      final double intera =
          load.loadOf(corsa(metri: 10000, passo: 320), zones)!;
      expect(intera, closeTo(mezza * 2, mezza * 0.15));
    });

    test('senza tracciato si usa il passo medio invece di dire zero', () {
      final double? punti = load.loadOf(
        corsa(metri: 10000, passo: 320, conTracciato: false),
        zones,
      );
      expect(punti, isNotNull);
      expect(punti! > 0, isTrue);
    });

    test('un salto del GPS non trasforma un lento in una seduta dura', () {
      // Il quadrato amplifica gli errori grandi: senza il tetto
      // all'intensita', un punto sballato vale piu' di tutta la corsa.
      final List<RoutePoint> punti = tracciato(8000, 320);
      final RoutePoint saltato = punti[punti.length ~/ 2];
      punti[punti.length ~/ 2] = RoutePoint(
        latitude: saltato.latitude + 0.004, // circa 450 metri di colpo
        longitude: saltato.longitude,
        elapsedSeconds: saltato.elapsedSeconds,
      );

      final RunningActivity sporca = RunningActivity(
        id: 'sporca',
        startTime: oggi,
        name: 'Corsa',
        type: ActivityType.free,
        durationSeconds: (8000 / 1000.0 * 320).round(),
        distanceMeters: 8000,
        route: punti,
      );

      final double pulita = load.loadOf(corsa(metri: 8000, passo: 320), zones)!;
      final double conSalto = load.loadOf(sporca, zones)!;

      expect(conSalto < pulita * 1.35, isTrue,
          reason: 'pulita $pulita, con salto $conSalto');
    });
  });

  group('fatica e condizione', () {
    test('senza storico non si inventa niente', () {
      final TrainingLoadState stato =
          load.stateFor(<RunningActivity>[], zones, now: oggi);
      expect(stato.isEmpty, isTrue);
      expect(stato.confidence, 0);
      expect(stato.headline.contains('Non ci sono'), isTrue);
    });

    test('con poche settimane lo dice invece di fingere', () {
      final List<RunningActivity> poche = <RunningActivity>[
        for (int i = 0; i < 5; i++)
          corsa(metri: 10000, passo: 320, daysAgo: i * 2),
      ];
      final TrainingLoadState stato =
          load.stateFor(poche, zones, now: oggi);

      expect(stato.isEmpty, isFalse);
      expect(stato.isReliable, isFalse,
          reason: 'con dieci giorni di storico la media a 28 non e\' piena');
      expect(stato.headline.contains('imparando'), isTrue);
    });

    test('chi si allena da mesi ha una condizione, e si vede', () {
      final List<RunningActivity> tanti = <RunningActivity>[
        for (int i = 0; i < 60; i += 2)
          corsa(metri: 10000, passo: 320, daysAgo: i),
      ];
      final TrainingLoadState stato = load.stateFor(tanti, zones, now: oggi);

      expect(stato.isReliable, isTrue);
      expect(stato.fitness > 0, isTrue);
      expect(stato.loadRatio, isNotNull);
      // Carico costante da due mesi: fatica e condizione si assomigliano.
      expect(stato.loadRatio!, closeTo(1.0, 0.25),
          reason: 'rapporto ${stato.loadRatio}');
    });

    test('una settimana di carico improvviso alza il rapporto', () {
      final List<RunningActivity> storia = <RunningActivity>[
        // Due mesi tranquilli.
        for (int i = 7; i < 60; i += 3)
          corsa(metri: 8000, passo: 330, daysAgo: i),
        // Ultima settimana: tutti i giorni e piu' forte.
        for (int i = 0; i < 7; i++)
          corsa(metri: 14000, passo: 300, daysAgo: i),
      ];
      final TrainingLoadState stato = load.stateFor(storia, zones, now: oggi);
      expect(stato.loadRatio! > 1.3, isTrue,
          reason: 'rapporto ${stato.loadRatio}');
      expect(stato.headline.contains('male'), isTrue);
    });

    test('i giorni di riposo contano: fermarsi abbassa la fatica', () {
      final List<RunningActivity> fermo = <RunningActivity>[
        for (int i = 14; i < 60; i += 2)
          corsa(metri: 10000, passo: 320, daysAgo: i),
      ];
      final TrainingLoadState stato = load.stateFor(fermo, zones, now: oggi);
      expect(stato.fatigue < stato.fitness, isTrue,
          reason: 'fatica ${stato.fatigue}, condizione ${stato.fitness}');
      expect(stato.freshness > 0, isTrue);
    });
  });

  group('la prontezza', () {
    TrainingLoadState statoNormale() {
      final List<RunningActivity> storia = <RunningActivity>[
        for (int i = 0; i < 60; i += 2)
          corsa(metri: 10000, passo: 320, daysAgo: i),
      ];
      return load.stateFor(storia, zones, now: oggi);
    }

    test('il dolore chiude la porta, e nessun punteggio lo riapre', () {
      // Tutto il resto al massimo: fresco, riposato, gambe ottime.
      final Readiness r = readiness.compute(
        load: statoNormale(),
        checkIn: DailyCheckIn(
          date: oggi,
          sleep: 5,
          legs: 5,
          motivation: 5,
          hasPain: true,
        ),
        now: oggi,
      );

      expect(r.blockedByPain, isTrue);
      expect(r.band.allowsQuality, isFalse,
          reason: 'punteggio ${r.score}, fascia ${r.band.label}');
      expect(r.reasons.first.contains('dolore'), isTrue,
          reason: 'il motivo piu\' importante deve essere il primo');
    });

    test('gambe ottime e riposo danno piu\' di gambe pesanti', () {
      final TrainingLoadState stato = statoNormale();
      final Readiness bene = readiness.compute(
        load: stato,
        checkIn: DailyCheckIn(
            date: oggi, sleep: 5, legs: 5, motivation: 5),
        now: oggi,
      );
      final Readiness male = readiness.compute(
        load: stato,
        checkIn: DailyCheckIn(
            date: oggi, sleep: 2, legs: 1, motivation: 2),
        now: oggi,
      );
      expect(bene.score > male.score + 15, isTrue,
          reason: 'bene ${bene.score}, male ${male.score}');
      expect(male.reasons.any((String m) => m.contains('gambe pesanti')),
          isTrue);
    });

    test('una qualita\' fatta ieri abbassa oggi', () {
      final TrainingLoadState stato = statoNormale();
      final DailyCheckIn c =
          DailyCheckIn(date: oggi, sleep: 4, legs: 4, motivation: 4);

      final Readiness riposato =
          readiness.compute(load: stato, checkIn: c, now: oggi);
      final Readiness dopoQualita = readiness.compute(
        load: stato,
        checkIn: c,
        lastQualityAt: oggi.subtract(const Duration(hours: 18)),
        now: oggi,
      );

      expect(dopoQualita.score < riposato.score, isTrue,
          reason: 'riposato ${riposato.score}, dopo ${dopoQualita.score}');
      expect(
          dopoQualita.reasons.any((String m) => m.contains('qualita')), isTrue);
    });

    test('senza check-in il numero c\'e\' ma la fiducia scende', () {
      final TrainingLoadState stato = statoNormale();
      final Readiness senza = readiness.compute(load: stato, now: oggi);
      final Readiness con = readiness.compute(
        load: stato,
        checkIn: DailyCheckIn(
            date: oggi, sleep: 3, legs: 3, motivation: 3),
        now: oggi,
      );

      expect(senza.confidence < con.confidence, isTrue);
      expect(senza.reasons.any((String m) => m.contains('check-in')), isTrue);
    });

    test('c\'e\' sempre almeno un motivo', () {
      final Readiness r = readiness.compute(
        load: TrainingLoadState.empty(oggi),
        now: oggi,
      );
      expect(r.reasons.isNotEmpty, isTrue,
          reason: 'un numero senza motivi e\' un oracolo');
      expect(r.score >= 0 && r.score <= 100, isTrue);
    });

    test('senza sapere niente non si dice "pronto"', () {
      // Il difetto vero che questo test ha trovato: il recupero vale 1 quando
      // non hai fatto niente di duro, e da solo portava il punteggio a 100.
      // Chi installa l'app oggi si vedeva "Pronto, 100 su 100" senza che
      // l'app sapesse una sola cosa di lui.
      final Readiness r = readiness.compute(
        load: TrainingLoadState.empty(oggi),
        now: oggi,
      );
      expect(r.score < 70, isTrue,
          reason: 'punteggio ${r.score}: non si puo\' dire "pronto" senza '
              'nessun dato');
      expect(r.confidence < 0.5, isTrue,
          reason: 'e la fiducia deve essere bassa');
    });
  });

  group('il check-in', () {
    test('le gambe pesano doppio', () {
      final DailyCheckIn gambeMale = DailyCheckIn(
          date: oggi, sleep: 5, legs: 1, motivation: 5);
      final DailyCheckIn sonnoMale = DailyCheckIn(
          date: oggi, sleep: 1, legs: 5, motivation: 5);
      expect(gambeMale.score < sonnoMale.score, isTrue,
          reason: 'gambe ${gambeMale.score}, sonno ${sonnoMale.score}');
    });

    test('andata e ritorno in JSON', () {
      final DailyCheckIn c = DailyCheckIn(
        date: oggi,
        sleep: 4,
        legs: 2,
        motivation: 3,
        hasPain: true,
        painNote: 'ginocchio destro',
      );
      final DailyCheckIn riletto = DailyCheckIn.fromJson(c.toJson());
      expect(riletto.sleep, 4);
      expect(riletto.legs, 2);
      expect(riletto.hasPain, isTrue);
      expect(riletto.painNote, 'ginocchio destro');
      expect(riletto.date, DateTime(2026, 9, 29));
    });

    test('valori fuori scala non fanno esplodere niente', () {
      final DailyCheckIn c = DailyCheckIn.fromJson(<String, dynamic>{
        'date': oggi.toIso8601String(),
        'sleep': 99,
        'legs': -4,
        'motivation': 3,
      });
      expect(c.sleep, DailyCheckIn.max);
      expect(c.legs, DailyCheckIn.min);
      expect(c.normalised >= 0 && c.normalised <= 1, isTrue);
    });
  });
}
