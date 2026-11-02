import 'package:flutter_test/flutter_test.dart';
import 'package:run_coach_app/models/lap.dart';
import 'package:run_coach_app/models/running_activity.dart';
import 'package:run_coach_app/models/workout_step.dart';
import 'package:run_coach_app/services/cadence.dart';
import 'package:run_coach_app/services/calorie_estimate.dart';
import 'package:run_coach_app/services/run_index_engine.dart';
import 'package:run_coach_app/utils/formatters.dart';

/// Tre difetti trovati usando l'app, e una cosa che mancava.
///
///  - una soglia 2 x 2 km diventava "3 km in 14:05", indice 39,8 contro un
///    46,5 vero: il tratto migliore pescava una ripetuta piu' un recupero;
///  - quella seduta, di giovedi', sabato risultava "ieri";
///  - la cadenza annunciata a ogni chilometro andava da 140 a 190 su una
///    corsa a 165, con la media giusta;
///  - le calorie non c'erano.
void main() {
  const double metriPerGrado = 111195.0;

  // ------------------------------------------------------------------ soglia
  group('una seduta a fasi non regala tratti migliori sbagliati', () {
    const RunIndexEngine engine = RunIndexEngine();
    final DateTime adesso = DateTime(2026, 10, 31, 12, 11);

    /// Riscaldamento 2 km lento, 2 km a soglia, 1 km di recupero, 2 km a
    /// soglia, 1 km di defaticamento: la soglia 2 x 2 km di giovedi'.
    List<RoutePoint> tracciatoSoglia() {
      final List<RoutePoint> punti = <RoutePoint>[];
      const List<List<double>> tratti = <List<double>>[
        <double>[2000, 350], // riscaldamento a 5:50
        <double>[2000, 265], // soglia a 4:25
        <double>[1000, 390], // recupero a 6:30
        <double>[2000, 265],
        <double>[1000, 380],
      ];
      double metri = 0;
      double tempo = 0;
      punti.add(const RoutePoint(
          latitude: 45.0, longitude: 9.0, elapsedSeconds: 0));
      for (final List<double> t in tratti) {
        final double fine = metri + t[0];
        final double passoAlMetro = t[1] / 1000.0;
        while (metri < fine - 0.01) {
          metri += 10;
          tempo += 10 * passoAlMetro;
          punti.add(RoutePoint(
            latitude: 45.0 + metri / metriPerGrado,
            longitude: 9.0,
            elapsedSeconds: tempo.round(),
          ));
        }
      }
      return punti;
    }

    Lap fase(int n, double metri, int secondi, StepType tipo) => Lap(
          number: n,
          distanceMeters: metri,
          durationSeconds: secondi,
          totalTimeSeconds: 0,
          stepLabel: tipo.label,
          stepKind: tipo.storageKey,
        );

    RunningActivity seduta(ActivityType tipo, {EffortKind? dichiarata}) {
      final List<RoutePoint> route = tracciatoSoglia();
      return RunningActivity(
        id: 'soglia',
        startTime: DateTime(2026, 10, 29, 18, 0),
        name: 'Soglia 2 x 2.00 km',
        type: tipo,
        durationSeconds: route.last.elapsedSeconds,
        distanceMeters: 8000,
        laps: <Lap>[
          fase(1, 2000, 700, StepType.warmup),
          fase(2, 2000, 530, StepType.interval),
          fase(3, 1000, 390, StepType.recovery),
          fase(4, 2000, 530, StepType.interval),
          fase(5, 1000, 380, StepType.cooldown),
        ],
        route: route,
        declared: dichiarata,
      );
    }

    test('come seduta a fasi: nessun tratto da 1,5 / 3 / 5 km', () {
      final List<PerformanceSample> prove = engine.samplesFromActivities(
        <RunningActivity>[seduta(ActivityType.workout)],
        now: adesso,
      );
      // Il 3 km in 14:05 era questo: 2 km a soglia + 1 km di recupero.
      expect(
        prove.where((PerformanceSample s) =>
            s.meters == 1500 || s.meters == 3000 || s.meters == 5000),
        isEmpty,
        reason: 'dentro una seduta a fasi il tratto migliore mescola lavoro '
            'e recupero',
      );
    });

    test('la stessa strada come corsa libera i tratti li ha ancora', () {
      final List<PerformanceSample> prove = engine.samplesFromActivities(
        <RunningActivity>[seduta(ActivityType.free)],
        now: adesso,
      );
      expect(prove.any((PerformanceSample s) => s.meters == 3000), isTrue);
    });

    test('se e\' dichiarata come test, i tratti tornano a contare', () {
      final List<PerformanceSample> prove = engine.samplesFromActivities(
        <RunningActivity>[
          seduta(ActivityType.workout, dichiarata: EffortKind.timeTrial),
        ],
        now: adesso,
      );
      expect(prove.any((PerformanceSample s) => s.meters == 3000), isTrue);
    });
  });

  // ------------------------------------------------------------ "ieri"
  group('quando, a giorni di calendario', () {
    final DateTime sabato = DateTime(2026, 10, 31, 12, 11);

    test('giovedi\' sera visto sabato a mezzogiorno e\' 2 giorni fa', () {
      expect(quandoACalendario(DateTime(2026, 10, 29, 18, 0), adesso: sabato),
          '2 giorni fa');
    });

    test('venerdi\' e\' ieri, anche se sono passate meno di 24 ore', () {
      expect(quandoACalendario(DateTime(2026, 10, 30, 13, 17), adesso: sabato),
          'ieri');
      expect(
          quandoACalendario(DateTime(2026, 10, 30, 23, 30),
              adesso: DateTime(2026, 10, 31, 0, 15)),
          'ieri');
    });

    test('stamattina e\' oggi', () {
      expect(quandoACalendario(DateTime(2026, 10, 31, 7, 0), adesso: sabato),
          'oggi');
    });

    test('a cavallo del cambio d\'ora il conto resta giusto', () {
      // Il 25 ottobre 2026 in Italia e' durato 25 ore.
      expect(
          quandoACalendario(DateTime(2026, 10, 24, 20, 0),
              adesso: DateTime(2026, 10, 26, 8, 0)),
          '2 giorni fa');
    });
  });

  // ------------------------------------------------------------ cadenza
  group('la cadenza di ogni giro, con un contapassi che consegna a lotti', () {
    const double passiAlSecondo = 165 / 60.0;

    /// Una corsa a 165 fissi, con il contatore che risponde a intervalli
    /// irregolari - 20, 60, 35, 75 secondi - come fanno i telefoni veri.
    List<RoutePoint> corsa(int secondiTotali) {
      const List<int> lotti = <int>[20, 60, 35, 75];
      final List<int> consegne = <int>[0];
      int k = 0;
      while (consegne.last < secondiTotali + 100) {
        consegne.add(consegne.last + lotti[k % lotti.length]);
        k++;
      }
      final List<RoutePoint> punti = <RoutePoint>[];
      int ultimaConsegna = 0;
      int c = 0;
      for (int t = 0; t <= secondiTotali; t += 2) {
        while (c + 1 < consegne.length && consegne[c + 1] <= t) {
          c++;
          ultimaConsegna = consegne[c];
        }
        punti.add(RoutePoint(
          latitude: 45.0,
          longitude: 9.0,
          elapsedSeconds: t,
          steps: (ultimaConsegna * passiAlSecondo).floor(),
        ));
      }
      return punti;
    }

    test('ogni chilometro esce vicino a 165, letto a corsa finita', () {
      const int giro = 343; // 5:43 al km
      final List<RoutePoint> route = corsa(giro * 8);
      final List<StepReading> letture = Cadence.readings(route);
      for (int i = 0; i < 8; i++) {
        final double? v = Cadence.overLap(
          letture,
          fromSeconds: i * giro,
          toSeconds: (i + 1) * giro,
        );
        expect(v, isNotNull, reason: 'giro ${i + 1}');
        expect(v!, closeTo(165, 3), reason: 'giro ${i + 1}');
      }
    });

    test('e anche nel momento in cui il giro si chiude, correndo', () {
      const int giro = 343;
      for (int i = 1; i <= 8; i++) {
        // Correndo, il tracciato finisce dove finisce il giro: le letture
        // dopo non esistono ancora.
        final List<RoutePoint> finoAdesso = corsa(giro * i);
        final double? v = Cadence.overLap(
          Cadence.readings(finoAdesso),
          fromSeconds: (i - 1) * giro,
          toSeconds: i * giro,
        );
        expect(v, isNotNull, reason: 'giro $i');
        expect(v!, closeTo(165, 3), reason: 'giro $i');
      }
    });

    test('un giro troppo corto non ha una cadenza misurabile', () {
      final List<RoutePoint> route = corsa(600);
      expect(
        Cadence.overLap(Cadence.readings(route),
            fromSeconds: 100, toSeconds: 120),
        isNull,
      );
    });

    test('se il sensore si e\' fermato, il giro dopo non ha cadenza', () {
      final List<RoutePoint> route = <RoutePoint>[
        for (int t = 0; t <= 400; t += 2)
          RoutePoint(
            latitude: 45.0,
            longitude: 9.0,
            elapsedSeconds: t,
            steps: (t * passiAlSecondo).floor(),
          ),
        // Da qui il contatore resta fermo: schermo spento, risparmio spinto.
        for (int t = 402; t <= 1600; t += 2)
          RoutePoint(
            latitude: 45.0,
            longitude: 9.0,
            elapsedSeconds: t,
            steps: (400 * passiAlSecondo).floor(),
          ),
      ];
      expect(
        Cadence.overLap(Cadence.readings(route),
            fromSeconds: 1200, toSeconds: 1543),
        isNull,
      );
    });
  });

  // ------------------------------------------------------------ calorie
  group('le calorie', () {
    test('7 km in 40 minuti per 70 kg fanno circa 540 kcal', () {
      final int? k = CalorieEstimate.kcal(
          weightKg: 70, meters: 7000, seconds: 2400);
      expect(k, isNotNull);
      expect(k!, closeTo(539, 5));
    });

    test('senza peso non si inventa un numero', () {
      expect(
          CalorieEstimate.kcal(weightKg: null, meters: 7000, seconds: 2400),
          isNull);
      expect(CalorieEstimate.kcal(weightKg: 7, meters: 7000, seconds: 2400),
          isNull,
          reason: '7 kg e\' un errore di battitura, non un peso');
    });

    test('la salita costa, e il peso conta in proporzione', () {
      final int piano = CalorieEstimate.kcal(
          weightKg: 70, meters: 10000, seconds: 3300)!;
      final int collina = CalorieEstimate.kcal(
          weightKg: 70, meters: 10000, seconds: 3300, climbMeters: 200)!;
      expect(collina, greaterThan(piano));
      final int pesante = CalorieEstimate.kcal(
          weightKg: 84, meters: 10000, seconds: 3300)!;
      expect(pesante / piano, closeTo(1.2, 0.01));
    });

    test('circa una chilocaloria per chilo per chilometro', () {
      for (final int secondi in <int>[2700, 3300, 3900]) {
        final int k = CalorieEstimate.kcal(
            weightKg: 70, meters: 10000, seconds: secondi)!;
        expect(k / 70 / 10, inInclusiveRange(1.0, 1.25),
            reason: '10 km in $secondi secondi');
      }
    });
  });
}
