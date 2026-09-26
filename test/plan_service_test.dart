import 'package:flutter_test/flutter_test.dart';
import 'package:run_coach_app/models/training_plan.dart';
import 'package:run_coach_app/models/workout.dart';
import 'package:run_coach_app/models/workout_step.dart';
import 'package:run_coach_app/services/plan_service.dart';

/// Il generatore di piani non si puo' verificare "a occhio": un piano di 18
/// settimane sono un centinaio di sedute. Quello che si verifica sono le
/// regole che non devono mai essere violate.
void main() {
  const PlanService service = PlanService();

  // Un lunedi'.
  final DateTime monday = DateTime(2026, 9, 28);

  PlanConfig config({
    RaceGoal goal = RaceGoal.tenK,
    int weeks = 10,
    int daysPerWeek = 4,
    double startWeeklyKm = 30,
    double vdot = 50,
    List<RaceEvent>? races,
  }) =>
      PlanConfig(
        id: 'test-plan',
        goal: goal,
        startDate: monday,
        weeks: weeks,
        daysPerWeek: daysPerWeek,
        startWeeklyKm: startWeeklyKm,
        vdot: vdot,
        races: races,
      );

  group('fasi', () {
    test('le fasi coprono tutte le settimane e sono in ordine', () {
      for (final int weeks in <int>[4, 6, 8, 10, 12, 14, 16, 18, 20, 24]) {
        final List<PlanPhase> phases =
            service.phasesFor(weeks, RaceGoal.tenK);
        expect(phases.length, weeks, reason: '$weeks settimane');

        // Una fase non torna mai indietro: costruzione, sviluppo, specifico,
        // scarico. Mai lo scarico prima dello sviluppo.
        final List<int> order = phases
            .map((PlanPhase p) => PlanPhase.values.indexOf(p))
            .toList();
        for (int i = 1; i < order.length; i++) {
          expect(order[i] >= order[i - 1], isTrue,
              reason: '$weeks settimane, fase $i va indietro');
        }

        // Un piano con obiettivo finisce sempre in scarico.
        expect(phases.last, PlanPhase.taper, reason: '$weeks settimane');
      }
    });

    test('senza gara non c\'e\' scarico finale', () {
      final List<PlanPhase> phases = service.phasesFor(12, RaceGoal.fitness);
      expect(phases.contains(PlanPhase.taper), isFalse);
      expect(phases.contains(PlanPhase.peak), isFalse);
      expect(phases.first, PlanPhase.base);
      expect(phases.last, PlanPhase.build);
    });
  });

  group('volumi', () {
    test('il tetto limita la crescita, non il volume che fai gia\'', () {
      // Partenza sotto il tetto di tutte le distanze: il piano non deve
      // superarlo mai.
      for (final RaceGoal goal in RaceGoal.values) {
        final List<PlanPhase> phases = service.phasesFor(16, goal);
        final List<double> volumes = service.volumesFor(
          weeks: 16,
          phases: phases,
          startWeeklyKm: 35,
          goal: goal,
        );
        for (final double v in volumes) {
          expect(v <= goal.weeklyCapKm + 0.1, isTrue,
              reason: '${goal.label}: $v oltre il tetto');
        }
      }

      // Chi parte da 90 km a settimana e prepara una 5 km non si deve sentire
      // dire di dimezzare: il tetto serve a frenare la crescita, non a
      // tagliare quello che uno fa gia'.
      final List<PlanPhase> phases = service.phasesFor(16, RaceGoal.fiveK);
      final List<double> volumes = service.volumesFor(
        weeks: 16,
        phases: phases,
        startWeeklyKm: 90,
        goal: RaceGoal.fiveK,
      );
      expect(volumes.first, closeTo(90, 1));
      for (final double v in volumes) {
        expect(v <= 90.1, isTrue, reason: '$v sopra la partenza');
      }
    });

    test('ogni quarta settimana e\' di scarico', () {
      final List<PlanPhase> phases = service.phasesFor(12, RaceGoal.tenK);
      final List<double> volumes = service.volumesFor(
        weeks: 12,
        phases: phases,
        startWeeklyKm: 30,
        goal: RaceGoal.tenK,
      );
      // La quarta (indice 3) deve stare sotto la terza (indice 2).
      expect(volumes[3] < volumes[2], isTrue);
      expect(volumes[7] < volumes[6], isTrue);
    });

    test('lo scarico finale scende sempre', () {
      final List<PlanPhase> phases = service.phasesFor(14, RaceGoal.half);
      final List<double> volumes = service.volumesFor(
        weeks: 14,
        phases: phases,
        startWeeklyKm: 40,
        goal: RaceGoal.half,
      );
      final List<double> taper = <double>[];
      for (int i = 0; i < 14; i++) {
        if (phases[i] == PlanPhase.taper) taper.add(volumes[i]);
      }
      expect(taper.length >= 1, isTrue);
      for (int i = 1; i < taper.length; i++) {
        expect(taper[i] < taper[i - 1], isTrue);
      }
      // L'ultima settimana e' molto piu' leggera del picco.
      final double peak = volumes.reduce((double a, double b) => a > b ? a : b);
      expect(taper.last < peak * 0.7, isTrue);
    });

    test('chi parte piano non finisce a volumi da professionista', () {
      final List<PlanPhase> phases = service.phasesFor(16, RaceGoal.half);
      final List<double> volumes = service.volumesFor(
        weeks: 16,
        phases: phases,
        startWeeklyKm: 20,
        goal: RaceGoal.half,
      );
      final double peak = volumes.reduce((double a, double b) => a > b ? a : b);
      // Al massimo il 55% in piu' del punto di partenza.
      expect(peak <= 20 * 1.56, isTrue, reason: 'picco $peak');
    });
  });

  group('struttura della settimana', () {
    test('il numero di sedute corrisponde ai giorni scelti', () {
      for (final int days in <int>[3, 4, 5, 6]) {
        final TrainingPlan? plan =
            service.generate(config(daysPerWeek: days, weeks: 8));
        expect(plan, isNotNull);
        for (final PlanWeek week in plan!.weeks) {
          expect(week.sessions.length, days,
              reason: '$days giorni, settimana ${week.number}');
        }
      }
    });

    test('il lungo e\' sempre di domenica e la qualita\' mai di sabato', () {
      final TrainingPlan? plan = service.generate(config(weeks: 12, daysPerWeek: 5));
      expect(plan, isNotNull);
      for (final PlanWeek week in plan!.weeks) {
        final Iterable<PlannedSession> longs = week.sessions
            .where((PlannedSession s) => s.kind == SessionKind.long);
        expect(longs.length, 1, reason: 'settimana ${week.number}');
        expect(longs.first.date.weekday, DateTime.sunday);

        for (final PlannedSession s in week.sessions) {
          if (!s.isQuality) continue;
          expect(s.date.weekday == DateTime.tuesday ||
              s.date.weekday == DateTime.thursday, isTrue,
              reason: 'qualita\' di ${s.date.weekday} nella settimana '
                  '${week.number}');
        }
      }
    });

    test('mai piu\' di due sedute di qualita\' a settimana', () {
      final TrainingPlan? plan = service.generate(config(weeks: 18, goal: RaceGoal.marathon, daysPerWeek: 6));
      expect(plan, isNotNull);
      for (final PlanWeek week in plan!.weeks) {
        expect(week.qualityCount <= 2, isTrue,
            reason: 'settimana ${week.number}: ${week.qualityCount}');
      }
    });

    test('in costruzione la qualita\' e\' una sola', () {
      final TrainingPlan? plan = service.generate(config(weeks: 16, goal: RaceGoal.half));
      expect(plan, isNotNull);
      for (final PlanWeek week in plan!.weeks) {
        if (week.phase != PlanPhase.base) continue;
        expect(week.qualityCount <= 1, isTrue,
            reason: 'settimana ${week.number}');
      }
    });

    test('le settimane sono consecutive e partono di lunedi\'', () {
      final TrainingPlan? plan = service.generate(config(weeks: 10));
      expect(plan, isNotNull);
      for (int i = 0; i < plan!.weeks.length; i++) {
        final PlanWeek week = plan.weeks[i];
        expect(week.startDate.weekday, DateTime.monday);
        expect(week.startDate, monday.add(Duration(days: i * 7)));
        expect(week.number, i + 1);
      }
    });

    test('ogni seduta cade dentro la sua settimana', () {
      final TrainingPlan? plan = service.generate(config(weeks: 12));
      expect(plan, isNotNull);
      for (final PlanWeek week in plan!.weeks) {
        for (final PlannedSession s in week.sessions) {
          expect(s.date.isBefore(week.startDate), isFalse);
          expect(s.date.isAfter(week.endDate), isFalse);
        }
      }
    });
  });

  group('sedute di qualita\'', () {
    test('portano un allenamento eseguibile con i passi impostati', () {
      final TrainingPlan? plan = service.generate(config(weeks: 12));
      expect(plan, isNotNull);

      int checked = 0;
      for (final PlanWeek week in plan!.weeks) {
        for (final PlannedSession s in week.sessions) {
          if (!s.isQuality) continue;
          final Workout? workout = s.workout;
          expect(workout, isNotNull, reason: s.title);

          final List<ResolvedStep> steps = workout!.expand();
          // Riscaldamento, almeno una ripetizione, defaticamento.
          expect(steps.length >= 3, isTrue, reason: s.title);
          expect(steps.first.step.type, StepType.warmup, reason: s.title);
          expect(steps.last.step.type, StepType.cooldown, reason: s.title);

          // Ogni fase ha un passo obiettivo: senza, il coach vocale non
          // avrebbe niente da dire.
          for (final ResolvedStep step in steps) {
            expect(step.step.paceTarget, isNotNull, reason: s.title);
            expect(step.step.paceTarget!.isNotEmpty, isTrue, reason: s.title);
          }
          checked++;
        }
      }
      expect(checked > 5, isTrue, reason: 'poche sedute controllate');
    });

    test('il passo di una ripetuta e\' piu\' veloce del recupero', () {
      final TrainingPlan? plan = service.generate(config(weeks: 12));
      expect(plan, isNotNull);

      for (final PlanWeek week in plan!.weeks) {
        for (final PlannedSession s in week.sessions) {
          final Workout? workout = s.workout;
          if (workout == null) continue;
          final List<ResolvedStep> steps = workout.expand();
          for (int i = 0; i < steps.length - 1; i++) {
            if (steps[i].step.type != StepType.interval) continue;
            if (steps[i + 1].step.type != StepType.recovery) continue;
            final double? work = steps[i].step.paceTarget?.centerSecPerKm;
            final double? rest =
                steps[i + 1].step.paceTarget?.centerSecPerKm;
            expect(work, isNotNull);
            expect(rest, isNotNull);
            // Passo in secondi al km: piu' basso = piu' veloce.
            expect(work! < rest!, isTrue, reason: s.title);
          }
        }
      }
    });
  });

  group('gara inserita nel mezzo', () {
    // Una 10 km il sabato della sesta settimana.
    final DateTime raceDay = monday.add(const Duration(days: 5 * 7 + 5));

    TrainingPlan planWithRace() {
      final TrainingPlan? plan = service.generate(config(
        weeks: 12,
        races: <RaceEvent>[
          RaceEvent(
            id: 'race-1',
            name: 'Corrida di paese',
            date: raceDay,
            meters: 10000,
          ),
        ],
      ));
      expect(plan, isNotNull);
      return plan!;
    }

    test('la gara compare come seduta nel giorno giusto', () {
      final List<PlannedSession> onRaceDay =
          planWithRace().sessionsOn(raceDay);
      expect(onRaceDay.length, 1);
      expect(onRaceDay.first.kind, SessionKind.race);
      expect(onRaceDay.first.title, 'Corrida di paese');
      expect(onRaceDay.first.distanceMeters, 10000);
    });

    test('nei giorni prima della gara non c\'e\' qualita\'', () {
      final TrainingPlan plan = planWithRace();
      // taperDays per una 10 km = 3.
      for (int back = 1; back <= 3; back++) {
        final DateTime day = raceDay.subtract(Duration(days: back));
        for (final PlannedSession s in plan.sessionsOn(day)) {
          expect(s.isQuality, isFalse,
              reason: 'qualita\' ${s.title} a $back giorni dalla gara');
        }
      }
    });

    test('nei giorni dopo la gara non c\'e\' qualita\'', () {
      final TrainingPlan plan = planWithRace();
      // recoveryDays per una 10 km = 6.
      for (int fwd = 1; fwd <= 6; fwd++) {
        final DateTime day = raceDay.add(Duration(days: fwd));
        for (final PlannedSession s in plan.sessionsOn(day)) {
          expect(s.isQuality, isFalse,
              reason: 'qualita\' ${s.title} a $fwd giorni dalla gara');
        }
      }
    });

    test('la settimana della gara e\' segnalata', () {
      final TrainingPlan plan = planWithRace();
      final PlanWeek? week = plan.weekFor(raceDay);
      expect(week, isNotNull);
      expect(week!.note, contains('Corrida di paese'));
    });

    test('il resto del piano non viene stravolto', () {
      final TrainingPlan withRace = planWithRace();
      final TrainingPlan? without = service.generate(config(weeks: 12));
      expect(without, isNotNull);

      // Le prime quattro settimane sono lontane dalla gara: identiche.
      for (int i = 0; i < 4; i++) {
        expect(withRace.weeks[i].sessions.length,
            without!.weeks[i].sessions.length);
        expect(withRace.weeks[i].qualityCount,
            without.weeks[i].qualityCount,
            reason: 'settimana ${i + 1}');
      }
    });

    test('una gara lunga scarica per piu\' giorni', () {
      final RaceEvent half = RaceEvent(
        id: 'r',
        name: 'Mezza',
        date: raceDay,
        meters: 21097.5,
      );
      final RaceEvent tenK = RaceEvent(
        id: 'r2',
        name: 'Dieci',
        date: raceDay,
        meters: 10000,
      );
      expect(half.taperDays > tenK.taperDays, isTrue);
      expect(half.recoveryDays > tenK.recoveryDays, isTrue);
      // Nessun recupero assurdo: al massimo dodici giorni.
      final RaceEvent marathon = RaceEvent(
        id: 'r3',
        name: 'Maratona',
        date: raceDay,
        meters: 42195,
      );
      expect(marathon.recoveryDays, 12);
    });
  });

  group('casi limite', () {
    test('senza forma stimabile non si genera niente', () {
      expect(service.generate(config(vdot: 0)), isNull);
      expect(service.generate(config(vdot: -3)), isNull);
    });

    test('un piano cortissimo resta valido', () {
      final TrainingPlan? plan = service.generate(config(weeks: 4, daysPerWeek: 3));
      expect(plan, isNotNull);
      expect(plan!.weeks.length, 4);
      for (final PlanWeek week in plan.weeks) {
        expect(week.sessions.length, 3);
      }
    });

    test('le settimane richieste sotto il minimo vengono corrette', () {
      final TrainingPlan? plan =
          service.generate(config(goal: RaceGoal.marathon, weeks: 4));
      expect(plan, isNotNull);
      // Una maratona non si prepara in quattro settimane.
      expect(plan!.weeks.length, RaceGoal.marathon.minWeeks);
    });

    test('il piano e\' deterministico', () {
      final TrainingPlan? a = service.generate(config(weeks: 10));
      final TrainingPlan? b = service.generate(config(weeks: 10));
      expect(a, isNotNull);
      expect(b, isNotNull);
      for (int w = 0; w < a!.weeks.length; w++) {
        expect(b!.weeks[w].targetKm, a.weeks[w].targetKm);
        expect(b.weeks[w].sessions.length, a.weeks[w].sessions.length);
        for (int s = 0; s < a.weeks[w].sessions.length; s++) {
          expect(b.weeks[w].sessions[s].title, a.weeks[w].sessions[s].title);
        }
      }
    });

    test('prossima seduta e settimana corrente', () {
      final TrainingPlan? plan = service.generate(config(weeks: 10));
      expect(plan, isNotNull);
      expect(plan!.currentWeekNumber(monday), 1);
      expect(plan.currentWeekNumber(monday.add(const Duration(days: 8))), 2);
      expect(plan.currentWeekNumber(monday.subtract(const Duration(days: 1))),
          isNull);

      final PlannedSession? next = plan.nextSessionFrom(monday);
      expect(next, isNotNull);
      expect(next!.date.isBefore(monday), isFalse);
    });
  });

  group('salvataggio dei parametri', () {
    test('andata e ritorno da JSON', () {
      final PlanConfig original = config(
        goal: RaceGoal.half,
        weeks: 14,
        daysPerWeek: 5,
        startWeeklyKm: 35,
        vdot: 47.5,
        races: <RaceEvent>[
          RaceEvent(
            id: 'race-x',
            name: 'Mezza di casa',
            date: DateTime(2026, 12, 6),
            meters: 21097.5,
            isGoal: true,
          ),
        ],
      );

      final PlanConfig back = PlanConfig.fromJson(original.toJson());
      expect(back.goal, RaceGoal.half);
      expect(back.weeks, 14);
      expect(back.daysPerWeek, 5);
      expect(back.startWeeklyKm, 35);
      expect(back.vdot, 47.5);
      expect(back.races.length, 1);
      expect(back.races.first.name, 'Mezza di casa');
      expect(back.races.first.isGoal, isTrue);
      expect(back.goalRace, isNotNull);
      expect(back.startDate, monday);
    });

    test('parametri mancanti: valori di riserva sensati', () {
      final PlanConfig back = PlanConfig.fromJson(<String, dynamic>{});
      expect(back.goal, RaceGoal.fitness);
      expect(back.weeks, 8);
      expect(back.daysPerWeek, 4);
      expect(back.races, isEmpty);
    });
  });
}
