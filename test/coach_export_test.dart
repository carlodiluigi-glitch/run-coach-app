import 'package:flutter_test/flutter_test.dart';
import 'package:run_coach_app/models/effort.dart';
import 'package:run_coach_app/models/lap.dart';
import 'package:run_coach_app/models/running_activity.dart';
import 'package:run_coach_app/models/workout_step.dart';
import 'package:run_coach_app/services/coach_export.dart';

/// Il testo per il coach.
///
/// I due casi di prova sono quelli veri che l'atleta ha portato come
/// esempio di cosa un'AI deve saper leggere:
///
///  - 7 x 400 a 3:47 di media, l'ultima a 3:40, recupero 400 m corso;
///  - 2 x 2000, la prima a 4:25 e la seconda a 4:10, 90 secondi di
///    recupero, e la fatica del secondo tratto non detta.
void main() {
  const CoachExport export = CoachExport();
  // Martedi' 3 novembre 2026.
  final DateTime adesso = DateTime(2026, 11, 3, 9, 0);

  Lap fase(int n, double metri, int secondi, StepType tipo, String nome) =>
      Lap(
        number: n,
        distanceMeters: metri,
        durationSeconds: secondi,
        totalTimeSeconds: 0,
        stepLabel: nome,
        stepKind: tipo.storageKey,
      );

  RunningActivity dueX2000({SessionFeedback? feedback}) {
    final List<Lap> laps = <Lap>[
      fase(1, 2000, 700, StepType.warmup, 'Riscaldamento'),
      fase(2, 2000, 530, StepType.interval, 'Ripetuta 1'), // 4:25
      fase(3, 250, 90, StepType.recovery, 'Recupero'),
      fase(4, 2000, 500, StepType.interval, 'Ripetuta 2'), // 4:10
      fase(5, 1000, 380, StepType.cooldown, 'Defaticamento'),
    ];
    return RunningActivity(
      id: 'act_soglia',
      startTime: DateTime(2026, 11, 1, 18, 0),
      name: 'Soglia 2 x 2.00 km',
      type: ActivityType.workout,
      durationSeconds: 2200,
      distanceMeters: 7250,
      laps: laps,
      feedback: feedback,
    );
  }

  String testo(List<RunningActivity> corse) =>
      export.build(now: adesso, activities: corse);

  group('le fasi separate dai recuperi', () {
    test('il 2 x 2000 ha il passo dei soli tratti di lavoro', () {
      final String t = testo(<RunningActivity>[dueX2000()]);
      expect(t, contains('Ripetuta 1 (lavoro): 2.00 km in 8:50, passo 4:25'));
      expect(t, contains('Ripetuta 2 (lavoro): 2.00 km in 8:20, passo 4:10'));
      expect(t, contains('Recupero (recupero): 250 m in 1:30'));
      // 1030 secondi su 4 km = 4:17,5 -> 4:18. Il passo medio dell'uscita
      // intera e' tutt'altro, e il testo dice che mescola i recuperi.
      expect(t, contains('solo i tratti di lavoro: 4.00 km, passo medio 4:18'));
      expect(t, contains('recuperi compresi'));
    });

    test('il 7 x 400 elenca tutte le ripetute, anche l\'ultima piu\' veloce',
        () {
      final List<Lap> laps = <Lap>[];
      int n = 1;
      for (int i = 0; i < 7; i++) {
        final int secondi = i == 6 ? 88 : 91; // 3:40 l'ultima
        laps.add(fase(n++, 400, secondi, StepType.interval, 'Ripetuta ${i + 1}'));
        if (i < 6) {
          laps.add(fase(n++, 400, 138, StepType.recovery, 'Recupero'));
        }
      }
      final RunningActivity corsa = RunningActivity(
        id: 'act_400',
        startTime: DateTime(2026, 10, 30, 18),
        name: '7 x 400',
        type: ActivityType.workout,
        durationSeconds: 2400,
        distanceMeters: 7000,
        laps: laps,
      );
      final String t = testo(<RunningActivity>[corsa]);
      expect(t, contains('Ripetuta 7 (lavoro): 400 m in 1:28, passo 3:40'));
      expect('(lavoro)'.allMatches(t).length, 7);
      expect('(recupero)'.allMatches(t).length, 6);
    });
  });

  group('quello che manca resta non noto', () {
    test('senza fatica, senza fascia: non nota, mai zero', () {
      final String t = testo(<RunningActivity>[dueX2000()]);
      expect(t, contains('fatica percepita: non nota'));
      expect(t, contains('Frequenza cardiaca: non nota'));
      expect(t, isNot(contains('null')));
      expect(t, isNot(contains('NaN')));
      expect(t, isNot(contains('Infinity')));
    });

    test('il commento dell\'atleta arriva intero, fra virgolette', () {
      final String t = testo(<RunningActivity>[
        dueX2000(
          feedback: const SessionFeedback(
            rpe: 7,
            legs: LegsFeel.normal,
            note: 'Abbastanza duro, ma avrei potuto fare un\'altra ripetuta',
          ),
        ),
      ]);
      expect(t, contains('fatica percepita 7/10'));
      expect(
          t,
          contains('commento: "Abbastanza duro, ma avrei potuto fare '
              'un\'altra ripetuta"'));
    });

    test('senza piano lo dice, invece di inventare una settimana', () {
      final String t = testo(<RunningActivity>[]);
      expect(t, contains('Obiettivo: non noto'));
      expect(t, contains('Nessun piano attivo'));
      expect(t, contains('Indice di forma (VDOT) [calcolato]: non noto'));
    });
  });

  group('il blocco di risposta', () {
    test('c\'e\' una volta, con la settimana che comincia lunedi\' prossimo',
        () {
      final String t = testo(<RunningActivity>[]);
      expect(CoachExport.inizioBlocco.allMatches(t).length, 1);
      expect(CoachExport.fineBlocco.allMatches(t).length, 1);
      expect(t.indexOf(CoachExport.inizioBlocco),
          lessThan(t.indexOf(CoachExport.fineBlocco)));
      expect(t, contains('"settimana_dal": "2026-11-09"'));
    });

    test('i giorni: quattordici, l\'ultimo e\' oggi', () {
      final String t = testo(<RunningActivity>[]);
      expect('--- '.allMatches(t).length, CoachExport.giorniInDettaglio);
      expect(t, contains('--- martedi\' 03/11/2026 ---'));
      expect(t, contains('--- mercoledi\' 21/10/2026 ---'));
    });

    test('le corse di cui parlare hanno il loro id', () {
      final String t = testo(<RunningActivity>[dueX2000()]);
      expect(t, contains('Corsa id act_soglia'));
    });
  });
}
