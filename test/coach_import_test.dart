import 'package:flutter_test/flutter_test.dart';
import 'package:run_coach_app/models/coach_week.dart';
import 'package:run_coach_app/models/effort.dart';
import 'package:run_coach_app/models/running_activity.dart';
import 'package:run_coach_app/models/training_plan.dart';
import 'package:run_coach_app/models/workout_step.dart';
import 'package:run_coach_app/services/coach_export.dart';
import 'package:run_coach_app/services/coach_import.dart';
import 'package:run_coach_app/services/daily_steps.dart';

/// Il ritorno dal coach: il blocco scritto dall'AI, letto e controllato.
void main() {
  const CoachImport imp = CoachImport();
  // Martedi' 3 novembre 2026; la settimana proposta parte lunedi' 9.
  final DateTime adesso = DateTime(2026, 11, 3, 21, 0);

  String blocco(String sedute, {String extra = ''}) => '''
Ecco la settimana come ne abbiamo parlato.

${CoachExport.inizioBlocco}
{
  "settimana_dal": "2026-11-09",
  "decisione": "alleggerisci",
  "motivo": "Settimana di scarico: meno volume, un richiamo breve.",
  "sedute": [$sedute],
  "riepiloghi": [
    {"corsa": "act_soglia", "sensazioni": "Duro ma gestibile, ne avevo un'altra",
     "limite": "gambe", "avrebbe_continuato": "si"}
  ]$extra
}
${CoachExport.fineBlocco}

Buona settimana!''';

  const String lento = '''
    {"data": "2026-11-10", "tipo": "lento", "titolo": "Lento 40'",
     "fasi": [{"ripeti": 1, "passi": [{"tipo": "corsa", "secondi": 2400}]}]}''';

  const String ripetute = '''
    {"data": "2026-11-12", "tipo": "ripetute", "titolo": "5 x 1000",
     "fasi": [
       {"ripeti": 1, "passi": [{"tipo": "riscaldamento", "secondi": 900}]},
       {"ripeti": 5, "passi": [
         {"tipo": "lavoro", "metri": 1000, "passo_da": "4:20", "passo_a": "4:15"},
         {"tipo": "recupero", "secondi": 120}]},
       {"ripeti": 1, "passi": [{"tipo": "defaticamento", "secondi": 600}]}
     ]}''';

  group('lettura', () {
    test('la risposta intera dell\'AI: il blocco si trova da solo', () {
      final CoachImportResult r =
          imp.parse(blocco('$lento,$ripetute'), now: adesso);
      expect(r.errors, isEmpty);
      expect(r.isOk, isTrue);
      final CoachWeek w = r.week!;
      expect(w.from, DateTime(2026, 11, 9));
      expect(w.decision, 'alleggerisci');
      expect(w.sessions.length, 2);

      final PlannedSession rip = w.sessions[1];
      expect(rip.kind, SessionKind.intervals);
      expect(rip.workout!.blocks.length, 3);
      expect(rip.workout!.blocks[1].repeat, 5);
      final WorkoutStep lavoro = rip.workout!.blocks[1].steps.first;
      expect(lavoro.type, StepType.interval);
      // Passi scritti al contrario: si rimettono in ordine.
      expect(lavoro.paceTarget!.fastestSecPerKm, 255);
      expect(lavoro.paceTarget!.slowestSecPerKm, 260);
      expect(rip.detail, contains('5 x (1.00 km'));

      expect(r.summaries.single.activityId, 'act_soglia');
      expect(r.summaries.single.asText, contains('Limite: gambe.'));
    });

    test('il blocco fra tre apici inversi si legge lo stesso', () {
      final String t = blocco(lento)
          .replaceFirst('${CoachExport.inizioBlocco}\n{',
              '${CoachExport.inizioBlocco}\n```json\n{')
          .replaceFirst('}\n${CoachExport.fineBlocco}',
              '}\n```\n${CoachExport.fineBlocco}');
      expect(imp.parse(t, now: adesso).isOk, isTrue);
    });

    test('senza segni: lo dice, non indovina', () {
      final CoachImportResult r =
          imp.parse('{"settimana_dal": "2026-11-09"}', now: adesso);
      expect(r.isOk, isFalse);
      expect(r.errors.single, contains(CoachExport.inizioBlocco));
    });

    test('JSON rotto: lo dice', () {
      final CoachImportResult r = imp.parse(
          '${CoachExport.inizioBlocco}\n{ "settimana_dal": \n'
          '${CoachExport.fineBlocco}',
          now: adesso);
      expect(r.isOk, isFalse);
      expect(r.errors.single, contains('JSON'));
    });

    test('un passo con metri e secondi insieme non passa', () {
      const String sbagliata = '''
        {"data": "2026-11-10", "tipo": "lento",
         "fasi": [{"ripeti": 1, "passi": [
           {"tipo": "corsa", "secondi": 2400, "metri": 8000}]}]}''';
      final CoachImportResult r = imp.parse(blocco(sbagliata), now: adesso);
      expect(r.isOk, isFalse);
      expect(r.errors.single, contains('uno solo'));
    });

    test('una seduta fuori dalla settimana non passa', () {
      final CoachImportResult r = imp.parse(
          blocco(lento.replaceFirst('2026-11-10', '2026-11-17')),
          now: adesso);
      expect(r.isOk, isFalse);
      expect(r.errors.single, contains('fuori dalla settimana'));
    });

    test('un tipo sconosciuto viene nominato', () {
      final CoachImportResult r = imp.parse(
          blocco(lento.replaceFirst('"lento"', '"collinare"')),
          now: adesso);
      expect(r.errors.single, contains('collinare'));
    });

    test('il 30 febbraio non e\' una data', () {
      final CoachImportResult r = imp.parse(
          blocco(lento).replaceFirst('2026-11-09', '2026-02-30'),
          now: adesso);
      expect(r.isOk, isFalse);
    });
  });

  group('controlli', () {
    test('due sedute di qualita\' attaccate: da correggere', () {
      final String soglia = ripetute
          .replaceFirst('2026-11-12', '2026-11-13')
          .replaceFirst('"ripetute"', '"soglia"');
      final CoachImportResult r =
          imp.parse(blocco('$ripetute,$soglia'), now: adesso);
      final List<CoachCheck> c = imp.check(
          week: r.week!, activities: const <RunningActivity>[]);
      expect(c.any((CoachCheck x) => x.blocking), isTrue);
    });

    test('qualita\' il giorno prima del lungo: da correggere', () {
      const String lungo = '''
        {"data": "2026-11-13", "tipo": "lungo",
         "fasi": [{"ripeti": 1, "passi": [{"tipo": "corsa", "secondi": 5400}]}]}''';
      final CoachImportResult r =
          imp.parse(blocco('$ripetute,$lungo'), now: adesso);
      final List<CoachCheck> c = imp.check(
          week: r.week!, activities: const <RunningActivity>[]);
      expect(
          c.where((CoachCheck x) => x.blocking).single.message,
          contains('lungo'));
    });

    test('una settimana normale non ha niente da correggere', () {
      final CoachImportResult r =
          imp.parse(blocco('$lento,$ripetute'), now: adesso);
      final List<CoachCheck> c = imp.check(
          week: r.week!, activities: const <RunningActivity>[]);
      expect(c.where((CoachCheck x) => x.blocking), isEmpty);
    });

    test('un carico che sale troppo e\' un avviso', () {
      // Quattro settimane da 20 km, poi una proposta da circa 60.
      final List<RunningActivity> storico = <RunningActivity>[
        for (int s = 1; s <= 4; s++)
          RunningActivity(
            startTime: DateTime(2026, 11, 9 - 7 * s + 2, 18),
            name: 'Corsa',
            type: ActivityType.free,
            durationSeconds: 7200,
            distanceMeters: 20000,
          ),
      ];
      const String lunga = '''
        {"data": "2026-11-15", "tipo": "lungo",
         "fasi": [{"ripeti": 1, "passi": [{"tipo": "corsa", "metri": 45000}]}]}''';
      final CoachImportResult r =
          imp.parse(blocco('$lento,$lunga'), now: adesso);
      final List<CoachCheck> c =
          imp.check(week: r.week!, activities: storico);
      expect(c.any((CoachCheck x) => !x.blocking && x.message.contains('carico')),
          isTrue);
    });
  });

  group('la settimana salvata', () {
    test('sopravvive al salvataggio, con le fasi', () {
      final CoachWeek w =
          imp.parse(blocco('$lento,$ripetute'), now: adesso).week!;
      final CoachWeek back = CoachWeek.fromJson(w.toJson())!;
      expect(back.from, w.from);
      expect(back.sessions.length, 2);
      expect(back.sessions[1].workout!.blocks[1].repeat, 5);
      expect(back.reason, w.reason);
    });

    test('copre sette giorni, non uno di piu\'', () {
      final CoachWeek w =
          imp.parse(blocco(lento), now: adesso).week!;
      expect(w.covers(DateTime(2026, 11, 9, 7)), isTrue);
      expect(w.covers(DateTime(2026, 11, 15, 23)), isTrue);
      expect(w.covers(DateTime(2026, 11, 16)), isFalse);
      expect(w.covers(DateTime(2026, 11, 8, 23)), isFalse);
    });
  });

  group('le note, il tempo e i passi arrivano al coach', () {
    test('nel testo esportato, ciascuno con la sua etichetta', () {
      final RunningActivity corsa = RunningActivity(
        id: 'act_n',
        startTime: DateTime(2026, 11, 2, 18),
        name: 'Corsa',
        type: ActivityType.free,
        durationSeconds: 2400,
        distanceMeters: 7000,
        note: 'Gambe a posto, mi ha fermato il caldo',
        temperature: FeltTemperature.moltoCaldo,
        coachSummary: 'Limite: caldo.',
      );
      final String t = const CoachExport().build(
        now: adesso,
        activities: <RunningActivity>[corsa],
        dailySteps: <DateTime, int>{DateTime(2026, 11, 2): 17450},
      );
      expect(t, contains('[dichiarato] note: "Gambe a posto, mi ha fermato '
          'il caldo"'));
      expect(t, contains('tempo, come l\'ha sentito: molto caldo'));
      expect(t, contains('[interpretazione AI'));
      expect(t, contains('Passi in tutta la giornata [misurato, stima]: '
          '17450'));
    });
  });

  group('i passi della giornata', () {
    final DateTime accensione = DateTime(2026, 11, 1, 6, 0);

    test('fra due letture dello stesso giorno: la differenza', () {
      final Map<DateTime, DaySteps> g = DailySteps.perDay(<StepSample>[
        StepSample(at: DateTime(2026, 11, 3, 9), steps: 1000, bootAt: accensione),
        StepSample(at: DateTime(2026, 11, 3, 18), steps: 16000, bootAt: accensione),
      ]);
      expect(g[DateTime(2026, 11, 3)]!.steps, 15000);
      expect(g[DateTime(2026, 11, 3)]!.fromMidnight, isFalse);
    });

    test('a cavallo di mezzanotte: diviso in proporzione, ed e\' una stima',
        () {
      final Map<DateTime, DaySteps> g = DailySteps.perDay(<StepSample>[
        StepSample(at: DateTime(2026, 11, 3, 20), steps: 0, bootAt: accensione),
        StepSample(at: DateTime(2026, 11, 4, 8), steps: 1200, bootAt: accensione),
      ]);
      // 4 ore prima di mezzanotte, 8 dopo.
      expect(g[DateTime(2026, 11, 3)]!.steps, 400);
      expect(g[DateTime(2026, 11, 4)]!.steps, 800);
      expect(g[DateTime(2026, 11, 4)]!.estimated, isTrue);
      expect(g[DateTime(2026, 11, 4)]!.fromMidnight, isTrue);
    });

    test('dopo un riavvio si conta dall\'accensione', () {
      final DateTime riavvio = DateTime(2026, 11, 3, 12, 0);
      final Map<DateTime, DaySteps> g = DailySteps.perDay(<StepSample>[
        StepSample(at: DateTime(2026, 11, 3, 9), steps: 50000, bootAt: accensione),
        StepSample(at: DateTime(2026, 11, 3, 18), steps: 6000, bootAt: riavvio),
      ]);
      // I passi fra le 9 e il riavvio sono persi: si contano i 6000 dopo.
      expect(g[DateTime(2026, 11, 3)]!.steps, 6000);
    });

    test('un salto assurdo viene scartato', () {
      final Map<DateTime, DaySteps> g = DailySteps.perDay(<StepSample>[
        StepSample(at: DateTime(2026, 11, 3, 9), steps: 0, bootAt: accensione),
        StepSample(at: DateTime(2026, 11, 3, 10), steps: 900000, bootAt: accensione),
      ]);
      expect(g[DateTime(2026, 11, 3)], isNull);
    });
  });
}
