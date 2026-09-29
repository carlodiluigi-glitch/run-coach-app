import 'package:flutter_test/flutter_test.dart';
import 'package:run_coach_app/models/training_plan.dart';
import 'package:run_coach_app/models/weekly_availability.dart';
import 'package:run_coach_app/models/workout.dart';
import 'package:run_coach_app/models/workout_step.dart';
import 'package:run_coach_app/services/plan_service.dart';

/// Da dove parte il piano, e il piano che non ha fasi.
///
/// DA DOVE NASCE QUESTO FILE
/// -------------------------
/// "Una qualita' a settimana e pure facile." Il piano dava quattro settimane
/// di Costruzione a un atleta che gia' correva 60 km a settimana con un 10 km
/// in 44:00, perche' la lunghezza delle fasi era una percentuale fissa. E la
/// Costruzione prevede fartlek e allunghi, che per definizione non devono
/// stancare: un mese di lavoro tolto a chi la base ce l'aveva gia'.
///
/// Poi: "pensavo ad un piano senza fasi". Giusto - una fase serve a
/// distribuire il lavoro verso una data. Senza quella data e' un'etichetta.
void main() {
  const PlanService service = PlanService();
  final DateTime monday = DateTime(2026, 9, 28);

  final WeeklyAvailability settimana = WeeklyAvailability(<int, int>{
    1: 60,
    2: 75,
    3: 90,
    4: 75,
    5: 60,
    6: 60,
    7: 60,
  });

  PlanConfig config({
    RaceGoal goal = RaceGoal.tenK,
    int weeks = 10,
    PlanPhase startPhase = PlanPhase.base,
    double startWeeklyKm = 60,
    double vdot = 45.4,
  }) =>
      PlanConfig(
        id: 'test',
        goal: goal,
        startDate: monday,
        weeks: weeks,
        daysPerWeek: settimana.dayCount,
        availability: settimana,
        startPhase: startPhase,
        startWeeklyKm: startWeeklyKm,
        vdot: vdot,
      );

  int quante(List<PlanPhase> phases, PlanPhase phase) =>
      phases.where((PlanPhase p) => p == phase).length;

  group('da dove parte il piano', () {
    test('partendo dalla Costruzione resta come prima', () {
      final List<PlanPhase> phases =
          service.phasesFor(10, RaceGoal.tenK, startPhase: PlanPhase.base);
      expect(phases.length, 10);
      expect(quante(phases, PlanPhase.base) >= 3, isTrue,
          reason: 'fasi $phases');
      expect(quante(phases, PlanPhase.build) >= 1, isTrue);
    });

    test('partendo dallo Sviluppo la Costruzione sparisce', () {
      final List<PlanPhase> phases =
          service.phasesFor(10, RaceGoal.tenK, startPhase: PlanPhase.build);
      expect(quante(phases, PlanPhase.base), 0);
    });

    test('le settimane saltate vanno a Sviluppo, non si perdono', () {
      final List<PlanPhase> conBase =
          service.phasesFor(10, RaceGoal.tenK, startPhase: PlanPhase.base);
      final List<PlanPhase> senzaBase =
          service.phasesFor(10, RaceGoal.tenK, startPhase: PlanPhase.build);

      expect(senzaBase.length, conBase.length,
          reason: 'saltare la base non accorcia il piano');
      expect(
        quante(senzaBase, PlanPhase.build),
        quante(conBase, PlanPhase.build) + quante(conBase, PlanPhase.base),
        reason: 'le settimane della base devono diventare sviluppo',
      );
      // Specifico e scarico non si toccano: quelli dipendono dalla gara.
      expect(quante(senzaBase, PlanPhase.peak), quante(conBase, PlanPhase.peak));
      expect(
          quante(senzaBase, PlanPhase.taper), quante(conBase, PlanPhase.taper));
    });

    test('partendo dallo Specifico c\'e\' solo passo gara e scarico', () {
      final List<PlanPhase> phases =
          service.phasesFor(8, RaceGoal.tenK, startPhase: PlanPhase.peak);
      expect(quante(phases, PlanPhase.base), 0);
      expect(quante(phases, PlanPhase.build), 0);
      expect(quante(phases, PlanPhase.taper) >= 1, isTrue);
      expect(phases.last, PlanPhase.taper);
    });

    test('piu\' lavoro vero saltando la base', () {
      int qualita(PlanPhase start) {
        final TrainingPlan plan =
            service.generate(config(startPhase: start))!;
        int n = 0;
        for (final PlanWeek w in plan.weeks) {
          n += w.qualityCount;
        }
        return n;
      }

      expect(qualita(PlanPhase.build) > qualita(PlanPhase.base), isTrue,
          reason: 'base ${qualita(PlanPhase.base)}, '
              'sviluppo ${qualita(PlanPhase.build)}');
    });

    test('la scelta sopravvive al salvataggio', () {
      final PlanConfig ripreso = PlanConfig.fromJson(
        config(startPhase: PlanPhase.build).toJson(),
      );
      expect(ripreso.startPhase, PlanPhase.build);
    });

    test('un piano vecchio riparte dalla Costruzione', () {
      // Nei piani salvati prima di questa scelta il campo non c'e'.
      final Map<String, dynamic> vecchio =
          config(startPhase: PlanPhase.build).toJson();
      vecchio.remove('startPhase');
      expect(PlanConfig.fromJson(vecchio).startPhase, PlanPhase.base);
    });
  });

  group('il piano senza gara non ha fasi', () {
    test('tutte le settimane sono uguali', () {
      final List<PlanPhase> phases =
          service.phasesFor(26, RaceGoal.fitness);
      expect(phases.length, 26);
      expect(phases.toSet().length, 1,
          reason: 'senza una data a cui arrivare le fasi non significano '
              'niente: $phases');
    });

    test('non c\'e\' scarico finale: il piano non finisce', () {
      final List<PlanPhase> phases =
          service.phasesFor(26, RaceGoal.fitness);
      expect(quante(phases, PlanPhase.taper), 0);
    });

    test('il volume cresce a cicli di quattro settimane', () {
      final List<PlanPhase> phases = service.phasesFor(24, RaceGoal.fitness);
      final List<double> volumi = service.volumesFor(
        weeks: 24,
        phases: phases,
        startWeeklyKm: 40,
        goal: RaceGoal.fitness,
      );

      // Dentro un ciclo le prime tre settimane hanno lo stesso volume.
      expect(volumi[0], volumi[1]);
      expect(volumi[1], volumi[2]);

      // La quarta e' di scarico.
      expect(volumi[3] < volumi[2], isTrue,
          reason: 'scarico ${volumi[3]} contro ${volumi[2]}');

      // Il ciclo dopo riparte SOPRA il precedente.
      expect(volumi[4] > volumi[0], isTrue,
          reason: 'ciclo 1 ${volumi[0]}, ciclo 2 ${volumi[4]}');
      expect(volumi[8] > volumi[4], isTrue);
    });

    test('la crescita e\' lenta e si ferma a un tetto', () {
      final List<PlanPhase> phases = service.phasesFor(52, RaceGoal.fitness);
      final List<double> volumi = service.volumesFor(
        weeks: 52,
        phases: phases,
        startWeeklyKm: 40,
        goal: RaceGoal.fitness,
      );

      // Un ciclo alla volta, non di piu' del 6%.
      expect(volumi[4] / volumi[0] < 1.06, isTrue,
          reason: '${volumi[0]} -> ${volumi[4]}');

      // E non si arriva mai al doppio: il tetto esiste.
      for (final double v in volumi) {
        expect(v <= 40 * 1.55 + 0.2, isTrue, reason: '$v km in una settimana');
      }
    });

    test('a meta\' anno si sta ancora allenando, non e\' finito', () {
      final TrainingPlan plan = service.generate(
        config(goal: RaceGoal.fitness, weeks: 26),
      )!;
      expect(plan.weeks.length, 26);

      final PlanWeek ultima = plan.weeks.last;
      expect(ultima.qualityCount >= 1, isTrue,
          reason: 'l\'ultima settimana deve allenare come le altre');
      expect(ultima.phase, PlanPhase.build);
    });
  });

  group('quanta qualita\' ci sta in una settimana', () {
    test('la soglia non supera il 10% del volume', () {
      for (final double km in <double>[30, 45, 60, 80]) {
        final int reps = service.repsForShare(
          weekKm: km,
          share: PlanService.thresholdShareOfWeek,
          fractionMeters: 1600,
          minReps: 2,
          maxReps: 6,
        );
        expect(reps * 1600 <= km * 1000 * 0.10 + 1600, isTrue,
            reason: '$km km: $reps x 1600');
      }
    });

    test('chi corre di piu\' fa piu\' lavoro', () {
      final int pochi = service.repsForShare(
        weekKm: 30,
        share: PlanService.intervalShareOfWeek,
        fractionMeters: 1000,
        minReps: 3,
        maxReps: 7,
      );
      final int tanti = service.repsForShare(
        weekKm: 75,
        share: PlanService.intervalShareOfWeek,
        fractionMeters: 1000,
        minReps: 3,
        maxReps: 7,
      );
      expect(tanti > pochi, isTrue, reason: '$pochi contro $tanti');
    });

    test('c\'e\' comunque un minimo e un massimo', () {
      expect(
        service.repsForShare(
          weekKm: 5,
          share: 0.10,
          fractionMeters: 1600,
          minReps: 2,
          maxReps: 6,
        ),
        2,
        reason: 'sotto il minimo non e\' piu\' una seduta',
      );
      expect(
        service.repsForShare(
          weekKm: 300,
          share: 0.10,
          fractionMeters: 1600,
          minReps: 2,
          maxReps: 6,
        ),
        6,
      );
    });

    test('nel piano vero il lavoro forte resta sotto i limiti', () {
      final TrainingPlan plan =
          service.generate(config(startPhase: PlanPhase.build))!;

      for (final PlanWeek w in plan.weeks) {
        // Lo Specifico ha regole sue: il passo gara non e' soglia ne'
        // ripetute, e una seduta da 4 x 2000 al passo della gara e'
        // esattamente quello che deve essere nelle ultime settimane.
        if (w.phase == PlanPhase.peak) continue;

        double metriForti = 0;
        for (final PlannedSession s in w.sessions) {
          final Workout? workout = s.workout;
          if (workout == null) continue;
          for (final ResolvedStep step in workout.expand()) {
            if (step.step.type == StepType.interval) {
              metriForti += step.step.estimatedMeters;
            }
          }
        }
        // Soglia + ripetute insieme: mai oltre un quinto della settimana.
        expect(metriForti <= w.targetKm * 1000 * 0.20 + 1000, isTrue,
            reason: 'settimana ${w.number}: '
                '${(metriForti / 1000).toStringAsFixed(1)} km forti su '
                '${w.targetKm.toStringAsFixed(0)} km');
      }
    });
  });
}
