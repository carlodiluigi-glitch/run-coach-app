import 'package:flutter_test/flutter_test.dart';
import 'package:run_coach_app/models/training_plan.dart';
import 'package:run_coach_app/models/weekly_availability.dart';
import 'package:run_coach_app/models/workout.dart';
import 'package:run_coach_app/services/fitness_service.dart';
import 'package:run_coach_app/services/plan_service.dart';

/// I giorni e il tempo disponibile.
///
/// DA DOVE NASCE QUESTO FILE
/// -------------------------
/// "Io posso correre sempre, chiaro che sabato e domenica lavoro parecchio, ho
/// 1:00/1:30." Il piano, invece, metteva il lungo la domenica perche' tutti i
/// piani lo mettono la domenica. A 60 km a settimana il lungo arriva a 15-18
/// km, cioe' un'ora e mezza-due: nel giorno in cui c'e' meno tempo di tutta la
/// settimana.
///
/// Da qui in avanti il calendario non lo decide la tradizione, lo decide il
/// tempo che c'e'.
void main() {
  const PlanService service = PlanService();
  const FitnessService fitness = FitnessService();
  final DateTime monday = DateTime(2026, 9, 28);

  WeeklyAvailability week(Map<int, int> minutes) =>
      WeeklyAvailability(minutes);

  PlanConfig config({
    WeeklyAvailability? availability,
    RaceGoal goal = RaceGoal.tenK,
    int weeks = 10,
    int daysPerWeek = 4,
    double startWeeklyKm = 60,
    double vdot = 45.4,
  }) =>
      PlanConfig(
        id: 'test',
        goal: goal,
        startDate: monday,
        weeks: weeks,
        daysPerWeek: daysPerWeek,
        availability: availability,
        startWeeklyKm: startWeeklyKm,
        vdot: vdot,
      );

  /// La settimana di chi lavora nella ristorazione: il fine settimana e' il
  /// momento piu' pieno, non il piu' libero.
  final WeeklyAvailability settimanaDiCarlo = week(<int, int>{
    1: 90,
    2: 90,
    3: 120,
    4: 90,
    5: 90,
    6: 60,
    7: 75,
  });

  group('dove va il lungo', () {
    test('va dove c\'e\' piu\' tempo, non la domenica per abitudine', () {
      final WeekSchedule s =
          service.scheduleFor(settimanaDiCarlo, qualityWanted: 2);
      expect(s.longDay, 3, reason: 'mercoledi\' e\' il giorno da 2 ore');
      expect(s.longDay == 7, isFalse);
    });

    test('a pari tempo vince la domenica', () {
      final WeekSchedule s = service.scheduleFor(
        week(<int, int>{1: 60, 3: 60, 5: 60, 7: 60}),
        qualityWanted: 2,
      );
      expect(s.longDay, 7);
    });

    test('i giorni senza tempo non entrano nel piano', () {
      final WeekSchedule s = service.scheduleFor(
        week(<int, int>{1: 60, 2: 0, 3: 60, 5: 60, 7: 90}),
        qualityWanted: 2,
      );
      expect(s.runDays, <int>[1, 3, 5, 7]);
      expect(s.runDays.contains(2), isFalse);
    });
  });

  group('dove va la qualita\'', () {
    test('mai il giorno prima del lungo', () {
      final WeekSchedule s =
          service.scheduleFor(settimanaDiCarlo, qualityWanted: 2);
      expect(s.qualityDays.contains(2), isFalse,
          reason: 'martedi\' e\' la vigilia del lungo di mercoledi\'');
      expect(s.qualityDays.contains(s.longDay), isFalse);
    });

    test('la vigilia conta anche a cavallo della settimana', () {
      // Lungo il lunedi': la vigilia e' la domenica della settimana prima, e
      // la settimana dopo ricomincia identica. Se la domenica fosse libera
      // per la qualita', ogni lungo arriverebbe su gambe stanche.
      final WeekSchedule s = service.scheduleFor(
        week(<int, int>{1: 150, 3: 60, 5: 60, 6: 60, 7: 60}),
        qualityWanted: 2,
      );
      expect(s.longDay, 1);
      expect(s.qualityDays.contains(7), isFalse);
    });

    test('due qualita\' non sono mai attaccate', () {
      for (final WeeklyAvailability av in <WeeklyAvailability>[
        settimanaDiCarlo,
        week(<int, int>{1: 60, 2: 60, 3: 60, 4: 60, 5: 60, 6: 60, 7: 60}),
        week(<int, int>{2: 75, 3: 75, 4: 75, 6: 120}),
      ]) {
        final WeekSchedule s = service.scheduleFor(av, qualityWanted: 2);
        for (int i = 1; i < s.qualityDays.length; i++) {
          final int diff = s.qualityDays[i] - s.qualityDays[i - 1];
          expect(diff > 1, isTrue,
              reason: 'giorni ${s.qualityDays} nella settimana '
                  '${av.runDays}');
        }
        // E nemmeno a cavallo della settimana.
        if (s.qualityDays.contains(1) && s.qualityDays.contains(7)) {
          fail('lunedi\' e domenica sono attaccati: ${s.qualityDays}');
        }
      }
    });

    test('se le regole non lo permettono, si fa una qualita\' sola', () {
      // Tre giorni attaccati: lungo su uno, e per la seconda qualita' non
      // resta un posto legittimo. Meglio una seduta in meno che una regola
      // rotta.
      final WeekSchedule s = service.scheduleFor(
        week(<int, int>{4: 60, 5: 60, 6: 120}),
        qualityWanted: 2,
      );
      expect(s.longDay, 6);
      expect(s.qualityDays.length <= 1, isTrue,
          reason: 'giorni ${s.qualityDays}');
    });

    test('a pari tempo vincono martedi\' e giovedi\'', () {
      // La tradizione non e' una regola, ma vale come spareggio: se tutti i
      // giorni offrono lo stesso tempo, tanto vale la settimana prevedibile.
      final WeekSchedule s = service.scheduleFor(
        week(<int, int>{1: 60, 2: 60, 3: 60, 4: 60, 5: 60, 6: 60, 7: 120}),
        qualityWanted: 2,
      );
      expect(s.longDay, 7);
      expect(s.qualityDays, <int>[2, 4]);
    });
  });

  group('un piano vecchio non cambia', () {
    test('senza tempi dichiarati resta lo schema di prima', () {
      // Quattro giorni: qualita' martedi' e giovedi', lungo domenica. E'
      // quello che facevano i piani creati prima di questa impostazione, e
      // riaprirne uno non deve dare un piano diverso.
      final WeekSchedule s = service.scheduleFor(
        WeeklyAvailability.fromDaysPerWeek(4),
        qualityWanted: 2,
      );
      expect(s.longDay, 7);
      expect(s.qualityDays, <int>[2, 4]);
      expect(s.runDays, <int>[2, 4, 6, 7]);
    });

    test('il piano si genera anche senza availability', () {
      final TrainingPlan? plan = service.generate(config());
      expect(plan, isNotNull);
      expect(plan!.weeks.length, 10);
    });
  });

  group('il tempo e\' un tetto, non un suggerimento', () {
    final TrainingPaces paces = fitness.pacesFor(45.4)!;
    final double easySec = paces.easy.slowestSecPerKm;

    double kmIn(int minutes) => minutes * 60.0 / easySec;

    test('il lungo non sfora il tempo del suo giorno', () {
      final TrainingPlan plan =
          service.generate(config(availability: settimanaDiCarlo))!;

      for (final PlanWeek w in plan.weeks) {
        for (final PlannedSession s in w.sessions) {
          if (s.kind != SessionKind.long) continue;
          final double km = (s.distanceMeters ?? 0) / 1000.0;
          final int minuti = settimanaDiCarlo.minutesOn(s.date.weekday);
          expect(km <= kmIn(minuti) + 0.2, isTrue,
              reason: 'settimana ${w.number}: lungo di '
                  '${km.toStringAsFixed(1)} km in $minuti minuti, cioe\' al '
                  'massimo ${kmIn(minuti).toStringAsFixed(1)} km');
        }
      }
    });

    test('nessuna seduta sfora il tempo del suo giorno', () {
      final TrainingPlan plan =
          service.generate(config(availability: settimanaDiCarlo))!;

      for (final PlanWeek w in plan.weeks) {
        for (final PlannedSession s in w.sessions) {
          final int minuti = settimanaDiCarlo.minutesOn(s.date.weekday);
          expect(minuti > 0, isTrue,
              reason: 'seduta ${s.title} in un giorno di riposo '
                  '(${s.date.weekday})');

          // Le sedute a passo libero si misurano in chilometri, quelle
          // costruite hanno una durata stimata.
          final int? durata = s.durationSeconds;
          if (durata != null) {
            expect(durata <= minuti * 60 + 60, isTrue,
                reason: 'settimana ${w.number}: ${s.title} dura '
                    '${(durata / 60).round()} minuti, ne hai $minuti');
          } else {
            final double km = (s.distanceMeters ?? 0) / 1000.0;
            expect(km <= kmIn(minuti) + 0.2, isTrue,
                reason: 'settimana ${w.number}: ${s.title} '
                    '${km.toStringAsFixed(1)} km in $minuti minuti');
          }
        }
      }
    });

    test('con poco tempo la qualita\' perde ripetute, non il riscaldamento',
        () {
      // Quarantacinque minuti: il riscaldamento resta almeno di dieci, e a
      // scendere sono le ripetizioni.
      final WeeklyAvailability corta = week(<int, int>{
        1: 45,
        3: 45,
        5: 45,
        7: 120,
      });
      final TrainingPlan plan =
          service.generate(config(availability: corta))!;

      bool trovata = false;
      for (final PlanWeek w in plan.weeks) {
        for (final PlannedSession s in w.sessions) {
          final Workout? workout = s.workout;
          if (workout == null) continue;
          trovata = true;
          expect(workout.estimatedSeconds <= 45 * 60 + 60, isTrue,
              reason: 'settimana ${w.number}: ${s.title} dura '
                  '${(workout.estimatedSeconds / 60).round()} minuti');
        }
      }
      expect(trovata, isTrue, reason: 'nessuna seduta costruita nel piano');
    });

    test('il volume settimanale non supera il tempo che c\'e\'', () {
      // Tre giorni da 45 minuti piu' due ore: circa 4 ore in tutto, cioe'
      // una quarantina di chilometri a passo lento. Chiederne 70 sarebbe
      // chiedere l'impossibile.
      final WeeklyAvailability corta = week(<int, int>{
        1: 45,
        3: 45,
        5: 45,
        7: 120,
      });
      final double capacita = corta.runDays
          .map((int d) => kmIn(corta.minutesOn(d)))
          .fold<double>(0, (double a, double b) => a + b);

      final TrainingPlan plan = service.generate(
        config(availability: corta, startWeeklyKm: 70),
      )!;

      for (final PlanWeek w in plan.weeks) {
        expect(w.targetKm <= capacita + 0.5, isTrue,
            reason: 'settimana ${w.number}: '
                '${w.targetKm.toStringAsFixed(1)} km chiesti, '
                '${capacita.toStringAsFixed(1)} possibili');
      }
    });
  });

  group('i conti della disponibilita\'', () {
    test('andata e ritorno in JSON', () {
      final WeeklyAvailability ripresa = WeeklyAvailability.fromJson(
        settimanaDiCarlo.toJson(),
      );
      for (int d = 1; d <= 7; d++) {
        expect(ripresa.minutesOn(d), settimanaDiCarlo.minutesOn(d));
      }
    });

    test('un piano salvato e riletto conserva i giorni', () {
      final PlanConfig originale = config(availability: settimanaDiCarlo);
      final PlanConfig ripreso = PlanConfig.fromJson(originale.toJson());
      expect(ripreso.availability, isNotNull);
      expect(ripreso.availability!.minutesOn(3), 120);
      expect(ripreso.effectiveAvailability.longestDay, 3);
    });

    test('togliere un giorno lo toglie davvero', () {
      final WeeklyAvailability senzaSabato =
          settimanaDiCarlo.withDay(6, 0);
      expect(senzaSabato.runsOn(6), isFalse);
      expect(senzaSabato.dayCount, 6);
    });

    test('il tempo si legge in ore e minuti', () {
      expect(WeeklyAvailability.formatMinutes(0), 'Riposo');
      expect(WeeklyAvailability.formatMinutes(45), '45 min');
      expect(WeeklyAvailability.formatMinutes(60), '1h');
      expect(WeeklyAvailability.formatMinutes(90), '1h 30\'');
    });
  });
}
