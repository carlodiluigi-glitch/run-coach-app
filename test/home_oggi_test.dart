import 'package:flutter_test/flutter_test.dart';
import 'package:run_coach_app/models/training_plan.dart';
import 'package:run_coach_app/models/weekly_availability.dart';
import 'package:run_coach_app/services/plan_service.dart';

/// Il blocco "Oggi" della Home.
///
/// DA DOVE NASCE QUESTO FILE
/// -------------------------
/// Si apre un'app di allenamento per rispondere a una domanda sola: **cosa
/// faccio oggi**. Nella Home di prima quella risposta compariva solo se in
/// calendario c'era una seduta, e stava al quarto posto - sotto il saluto, la
/// prontezza, e una settimana che diceva zero tre volte.
///
/// Quando la seduta non c'era, al suo posto non c'era niente. Ma il vuoto non
/// e' una risposta: "oggi riposo" e "non hai un piano" sono due risposte
/// diverse, utili tutte e due, e nessuna si legge da un'assenza.
///
/// Qui non si prova la grafica: si prova che **il piano sappia sempre dire se
/// oggi c'e' qualcosa**, che e' il dato da cui quel blocco dipende. Un piano
/// che per certi giorni non risponde ne' si' ne' no riporterebbe la Home al
/// vuoto di prima.
void main() {
  const PlanService service = PlanService();

  final WeeklyAvailability settimana = WeeklyAvailability(<int, int>{
    1: 60,
    3: 90,
    5: 60,
    7: 120,
  });

  PlanConfig config() => PlanConfig(
        goal: RaceGoal.tenK,
        startDate: DateTime(2026, 10, 5), // lunedi'
        weeks: 8,
        daysPerWeek: settimana.dayCount,
        availability: settimana,
        startPhase: PlanPhase.build,
        startWeeklyKm: 55,
        vdot: 46.5,
      );

  group('il piano risponde per ogni giorno', () {
    test('nei giorni dichiarati c\'e\' una seduta', () {
      final TrainingPlan piano = service.generate(config())!;
      // Prima settimana: lunedi' 5, mercoledi' 7, venerdi' 9, domenica 11.
      for (final int giorno in <int>[5, 7, 9, 11]) {
        final List<PlannedSession> sedute =
            piano.sessionsOn(DateTime(2026, 10, giorno));
        expect(sedute.isNotEmpty, isTrue,
            reason: 'il 2026-10-$giorno doveva esserci una seduta');
      }
    });

    test('negli altri giorni non c\'e\' niente, ed e\' una risposta', () {
      // Martedi', giovedi' e sabato sono riposo: il blocco "Oggi" deve poter
      // dire "riposo" invece di sparire.
      final TrainingPlan piano = service.generate(config())!;
      for (final int giorno in <int>[6, 8, 10]) {
        expect(piano.sessionsOn(DateTime(2026, 10, giorno)), isEmpty,
            reason: 'il 2026-10-$giorno doveva essere riposo');
      }
    });

    test('ogni settimana del piano ha un obiettivo in chilometri', () {
      // E' il numero che la scheda della settimana mostra come bersaglio:
      // senza, tornerebbe a mostrare uno zero solo.
      final TrainingPlan piano = service.generate(config())!;
      for (final PlanWeek w in piano.weeks) {
        expect(w.targetKm > 0, isTrue,
            reason: 'settimana ${w.number} senza obiettivo');
      }
    });

    test('il giorno di oggi trova la sua settimana', () {
      // La Home chiede al piano la settimana di oggi per sapere il bersaglio.
      final TrainingPlan piano = service.generate(config())!;
      for (final int giorno in <int>[5, 8, 11]) {
        expect(piano.weekFor(DateTime(2026, 10, giorno)), isNotNull,
            reason: 'nessuna settimana per il 2026-10-$giorno');
      }
    });

    test('fuori dal piano non si inventa una settimana', () {
      // Prima dell'inizio e dopo la fine la Home deve ripiegare sul confronto
      // con il solito, non mostrare un bersaglio che non esiste.
      final TrainingPlan piano = service.generate(config())!;
      expect(piano.weekFor(DateTime(2026, 9, 20)), isNull);
      expect(piano.weekFor(DateTime(2027, 6, 1)), isNull);
    });
  });
}
