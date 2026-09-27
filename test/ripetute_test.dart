import 'package:flutter_test/flutter_test.dart';
import 'package:run_coach_app/models/estimate.dart';
import 'package:run_coach_app/models/lap.dart';
import 'package:run_coach_app/models/running_activity.dart';
import 'package:run_coach_app/models/workout_step.dart';
import 'package:run_coach_app/services/fitness_service.dart';
import 'package:run_coach_app/services/run_index_engine.dart';

/// Le ripetute e le gare dichiarate.
///
/// Questi test nascono da due buchi trovati usando l'app per davvero:
///
///  - un 6x1000 a 4:18 non contava niente per l'indice, perche' il motore
///    cercava solo tratti continui e in una seduta a intervalli ogni tratto
///    lungo si porta dentro i recuperi;
///  - una gara CORSA con l'app valeva 0,45 mentre la stessa gara DIGITATA a
///    mano valeva 1,00.
void main() {
  const RunIndexEngine engine = RunIndexEngine();
  const FitnessService fitness = FitnessService();
  final DateTime now = DateTime(2026, 9, 27);

  /// Due punti bastano: il tracciato serve solo a superare il controllo di
  /// esistenza. Le prestazioni le devono ricavare i parziali.
  List<RoutePoint> tracciatoMinimo() => <RoutePoint>[
        const RoutePoint(latitude: 45.0, longitude: 9.0, elapsedSeconds: 0),
        const RoutePoint(latitude: 45.0, longitude: 9.0, elapsedSeconds: 1),
      ];

  Lap ripetuta(int numero, double metri, int secondi) => Lap(
        number: numero,
        distanceMeters: metri,
        durationSeconds: secondi,
        totalTimeSeconds: numero * secondi,
        stepLabel: 'Ripetuta $numero',
        stepKind: StepType.interval.storageKey,
      );

  Lap recupero(int numero, double metri, int secondi) => Lap(
        number: numero,
        distanceMeters: metri,
        durationSeconds: secondi,
        totalTimeSeconds: numero * secondi,
        stepLabel: 'Recupero',
        stepKind: StepType.recovery.storageKey,
      );

  RunningActivity seduta({
    required List<Lap> laps,
    int daysAgo = 1,
    ActivityType type = ActivityType.workout,
    EffortKind? declared,
    double? distanceMeters,
    int? durationSeconds,
  }) {
    final double metri = distanceMeters ??
        laps.fold<double>(0, (double a, Lap l) => a + l.distanceMeters);
    final int secondi = durationSeconds ??
        laps.fold<int>(0, (int a, Lap l) => a + l.durationSeconds);
    return RunningActivity(
      id: 'a1',
      startTime: now.subtract(Duration(days: daysAgo)),
      name: 'Seduta',
      type: type,
      durationSeconds: secondi,
      distanceMeters: metri,
      laps: laps,
      route: tracciatoMinimo(),
      declared: declared,
    );
  }

  group('una serie di ripetute vale come prestazione', () {
    test('6x1000 a 4:18 diventa un 3000 equivalente', () {
      final List<Lap> laps = <Lap>[];
      for (int i = 1; i <= 6; i++) {
        laps.add(ripetuta(i * 2 - 1, 1000, 258)); // 4:18
        laps.add(recupero(i * 2, 200, 120));
      }

      final List<PerformanceSample> samples = engine.samplesFromActivities(
        <RunningActivity>[seduta(laps: laps)],
        now: now,
      );

      final Iterable<PerformanceSample> tremila =
          samples.where((PerformanceSample s) => s.meters == 3000);
      expect(tremila.length, 1,
          reason: 'la serie deve produrre una prestazione sui 3000');

      final PerformanceSample s = tremila.first;
      // 3000 metri a 4:18 = 12:54
      expect(s.seconds, closeTo(774, 2));
      expect(s.source, EstimateSource.workout,
          reason: 'in allenamento non si spreme come in gara');

      final double indice = fitness.vdotFromPerformance(s.meters, s.seconds)!;
      expect(indice, closeTo(44.1, 0.5));
    });

    test('i recuperi non entrano nel conto', () {
      // Se i recuperi contassero, il passo medio crollerebbe e l'indice
      // uscirebbe molto piu' basso.
      final List<Lap> laps = <Lap>[
        ripetuta(1, 1000, 258),
        recupero(2, 400, 240),
        ripetuta(3, 1000, 258),
        recupero(4, 400, 240),
      ];
      final PerformanceSample s = engine
          .samplesFromActivities(<RunningActivity>[seduta(laps: laps)],
              now: now)
          .firstWhere((PerformanceSample x) => x.meters == 3000);
      expect(s.seconds, closeTo(774, 2));
    });

    test('le ripetute brevi vengono scartate', () {
      // 10x400 a 3:50 si corre a ritmo velocita', non a ritmo 3000:
      // riportarlo ai 3000 gonfierebbe l'indice di sei punti.
      final List<Lap> laps = <Lap>[];
      for (int i = 1; i <= 10; i++) {
        laps.add(ripetuta(i, 400, 92));
      }
      final List<PerformanceSample> samples = engine.samplesFromActivities(
        <RunningActivity>[seduta(laps: laps)],
        now: now,
      );
      expect(samples.where((PerformanceSample s) => s.meters == 3000), isEmpty);
    });

    test('una ripetuta sola non e\' una serie', () {
      final List<PerformanceSample> samples = engine.samplesFromActivities(
        <RunningActivity>[seduta(laps: <Lap>[ripetuta(1, 3000, 774)])],
        now: now,
      );
      expect(samples.where((PerformanceSample s) => s.meters == 3000), isEmpty,
          reason: 'un episodio non fa una serie: serve ripetizione');
    });

    test('una serie a ritmi troppo diversi viene scartata', () {
      // Un progressivo: la media non significa niente.
      final List<Lap> laps = <Lap>[
        ripetuta(1, 1000, 300), // 5:00
        ripetuta(2, 1000, 275),
        ripetuta(3, 1000, 250), // 4:10, oltre il 12% di scarto
      ];
      final List<PerformanceSample> samples = engine.samplesFromActivities(
        <RunningActivity>[seduta(laps: laps)],
        now: now,
      );
      expect(samples.where((PerformanceSample s) => s.meters == 3000), isEmpty);
    });

    test('poco lavoro non basta', () {
      final List<Lap> laps = <Lap>[
        ripetuta(1, 800, 210),
        ripetuta(2, 800, 210), // 1600 m in tutto, sotto i 1800
      ];
      final List<PerformanceSample> samples = engine.samplesFromActivities(
        <RunningActivity>[seduta(laps: laps)],
        now: now,
      );
      expect(samples.where((PerformanceSample s) => s.meters == 3000), isEmpty);
    });
  });

  group('una gara dichiarata sull\'attivita\'', () {
    test('vale come gara, non come tratto dentro una corsa', () {
      final RunningActivity gara = seduta(
        laps: <Lap>[],
        type: ActivityType.free,
        declared: EffortKind.race,
        distanceMeters: 10000,
        durationSeconds: 2640, // 44:00
      );
      final List<PerformanceSample> samples =
          engine.samplesFromActivities(<RunningActivity>[gara], now: now);

      expect(samples, isNotEmpty);
      for (final PerformanceSample s in samples) {
        expect(s.source, EstimateSource.race);
      }

      // La gara intera deve esserci, non solo i tratti standard.
      final PerformanceSample intera = samples
          .firstWhere((PerformanceSample s) => s.meters == 10000);
      expect(intera.seconds, 2640);

      final double peso = engine.weightOf(intera, now: now);
      expect(peso > 0.95, isTrue,
          reason: 'peso $peso: una gara corsa con l\'app non puo\' valere '
              'meno della stessa gara digitata a mano');
    });

    test('senza dichiarazione resta un tratto dentro una corsa', () {
      final RunningActivity normale = seduta(
        laps: <Lap>[],
        type: ActivityType.free,
        distanceMeters: 10000,
        durationSeconds: 2640,
      );
      final List<PerformanceSample> samples =
          engine.samplesFromActivities(<RunningActivity>[normale], now: now);
      // Senza dichiarazione la distanza intera non viene aggiunta: il motore
      // guarda solo i tratti standard dentro il tracciato, e con un tracciato
      // di due punti non ne trova nessuno.
      expect(samples, isEmpty,
          reason: 'la distanza intera conta solo se dichiarata');
    });

    test('un test vale meno di una gara ma piu\' di un tratto', () {
      final double gara = EstimateSource.race.reliability;
      final double test = EstimateSource.timeTrial.reliability;
      final double tratto = EstimateSource.runSegment.reliability;
      expect(gara > test, isTrue);
      expect(test > tratto, isTrue);
    });
  });

  // ---------------------------------------------------------------- soglia
  //
  // Questo gruppo nasce da una domanda: "2 per 15 minuti come ripetute
  // possono andare?". No - e non perche' sia una brutta seduta, ma perche'
  // NON e' una seduta di ripetute. Quindici minuti a ritmo 3000 non esistono:
  // quel ritmo si tiene per dodici minuti in tutto, in gara. Un 2x15 e'
  // lavoro di soglia, e riportarlo ai 3000 faceva scendere l'indice da 45,4 a
  // 41: una seduta fatta bene peggiorava la stima.
  group('le frazioni lunghe sono soglia, non ripetute', () {
    test('2x15 a ritmo soglia produce la distanza di un\'ora', () {
      // 4:34 al km per 15 minuti = 3284 m circa, due volte.
      const int secondi = 900;
      const double metri = 3284;
      final List<Lap> laps = <Lap>[
        ripetuta(1, metri, secondi),
        recupero(2, 500, 180),
        ripetuta(3, metri, secondi),
      ];

      final PerformanceSample s = engine
          .samplesFromActivities(<RunningActivity>[seduta(laps: laps)],
              now: now)
          .firstWhere((PerformanceSample x) => x.seconds == 3600);

      // Il passo tenuto e' il passo dell'ora: la distanza in un'ora si
      // ricava da quello, per definizione.
      expect(s.meters, closeTo(13136, 60));
      final double indice = fitness.vdotFromPerformance(s.meters, s.seconds)!;
      expect(indice, closeTo(45.4, 0.4),
          reason: 'indice $indice: doveva confermare la forma, non abbassarla');
      expect(s.source, EstimateSource.workout);
    });

    test('non viene piu\' letta come ritmo 3000', () {
      const int secondi = 900;
      const double metri = 3284;
      final List<PerformanceSample> samples = engine.samplesFromActivities(
        <RunningActivity>[
          seduta(laps: <Lap>[
            ripetuta(1, metri, secondi),
            ripetuta(2, metri, secondi),
          ])
        ],
        now: now,
      );
      expect(samples.where((PerformanceSample s) => s.meters == 3000), isEmpty,
          reason: 'una frazione da 15 minuti non e\' lavoro da 3000');
    });

    test('poca soglia non basta', () {
      // Un solo blocco da 8 minuti: troppo poco per dire qualcosa.
      final List<PerformanceSample> samples = engine.samplesFromActivities(
        <RunningActivity>[
          seduta(laps: <Lap>[ripetuta(1, 1750, 480)])
        ],
        now: now,
      );
      expect(samples, isEmpty);
    });

    test('un blocco unico da mezz\'ora conta', () {
      // Non serve che siano due: trenta minuti di fila a ritmo soglia sono
      // la prova piu' pulita che esista per quel ritmo.
      final PerformanceSample s = engine
          .samplesFromActivities(
            <RunningActivity>[
              seduta(laps: <Lap>[ripetuta(1, 6568, 1800)])
            ],
            now: now,
          )
          .firstWhere((PerformanceSample x) => x.seconds == 3600);
      expect(s.meters, closeTo(13136, 60));
    });

    test('una seduta mista non viene convertita', () {
      // Ripetute corte piu' un blocco lungo: non e' ne' l'una ne' l'altra
      // cosa, e indovinare sarebbe peggio che tacere.
      final List<PerformanceSample> samples = engine.samplesFromActivities(
        <RunningActivity>[
          seduta(laps: <Lap>[
            ripetuta(1, 1000, 258),
            ripetuta(2, 1000, 258),
            ripetuta(3, 3284, 900),
          ])
        ],
        now: now,
      );
      expect(samples, isEmpty);
    });
  });
}
