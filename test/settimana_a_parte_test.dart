import 'package:flutter_test/flutter_test.dart';
import 'package:run_coach_app/models/training_plan.dart';
import 'package:run_coach_app/models/weekly_availability.dart';
import 'package:run_coach_app/services/plan_service.dart';

/// Una settimana puo' fare eccezione.
///
/// DA DOVE NASCE QUESTO FILE
/// -------------------------
/// La settimana si dichiara una volta, quando si crea il piano. Va bene per
/// generarlo e non va bene per viverlo: chi lavora su turni sa il mercoledi'
/// com'e' fatta la settimana dopo, non tre mesi prima.
///
/// E quello che succede quando il piano chiede il lungo nel giorno del doppio
/// turno non e' che l'atleta si adatta: e' che quella settimana viene saltata.
/// Dopo due settimane saltate il piano non si guarda piu'.
///
/// Le due cose che questo file deve garantire, perche' se cadono il resto non
/// serve a niente:
///
/// 1. l'eccezione vale SOLO per quella settimana;
/// 2. si torna indietro senza perdere niente.
void main() {
  const PlanService service = PlanService();

  final WeeklyAvailability normale = WeeklyAvailability(<int, int>{
    1: 60, // lunedi'
    3: 90, // mercoledi'
    5: 60, // venerdi'
    7: 120, // domenica <- il lungo cade qui
  });

  /// La settimana dei turni cattivi: sabato e domenica pieni, tempo in mezzo.
  final WeeklyAvailability turni = WeeklyAvailability(<int, int>{
    2: 60, // martedi'
    3: 150, // mercoledi' <- qui c'e' piu' tempo
    5: 75, // venerdi'
    6: 45, // sabato
  });

  PlanConfig config({Map<int, WeeklyAvailability>? overrides}) => PlanConfig(
        goal: RaceGoal.tenK,
        startDate: DateTime(2026, 10, 5), // un lunedi'
        weeks: 10,
        daysPerWeek: normale.dayCount,
        availability: normale,
        startPhase: PlanPhase.build,
        startWeeklyKm: 55,
        vdot: 46.5,
        weekOverrides: overrides,
      );

  group('quale settimana viene usata', () {
    test('senza eccezioni, tutte le settimane usano quella normale', () {
      final PlanConfig c = config();
      for (int w = 1; w <= 10; w++) {
        expect(c.availabilityForWeek(w), normale, reason: 'settimana $w');
        expect(c.isWeekChanged(w), isFalse);
      }
    });

    test('con un\'eccezione, solo quella settimana cambia', () {
      final PlanConfig c = config().withWeekAvailability(4, turni);

      expect(c.availabilityForWeek(4), turni);
      expect(c.isWeekChanged(4), isTrue);

      // Le vicine non si muovono: e' tutto il punto.
      expect(c.availabilityForWeek(3), normale);
      expect(c.availabilityForWeek(5), normale);
      expect(c.isWeekChanged(3), isFalse);
      expect(c.isWeekChanged(5), isFalse);
      expect(c.changedWeekCount, 1);

      // E la settimana normale resta la settimana normale.
      expect(c.effectiveAvailability, normale);
    });

    test('un\'eccezione identica alla normale non viene tenuta', () {
      // Altrimenti comparirebbe scritto "giorni cambiati" su una settimana
      // in cui non e' cambiato niente, e non si capirebbe perche'.
      final PlanConfig c = config().withWeekAvailability(
        4,
        WeeklyAvailability(Map<int, int>.from(normale.minutesByDay)),
      );
      expect(c.isWeekChanged(4), isFalse);
      expect(c.weekOverrides.containsKey(4), isFalse);
    });

    test('si torna indietro', () {
      final PlanConfig cambiata = config().withWeekAvailability(4, turni);
      final PlanConfig tornata = cambiata.withWeekAvailability(4, null);
      expect(tornata.isWeekChanged(4), isFalse);
      expect(tornata.availabilityForWeek(4), normale);
      expect(tornata.changedWeekCount, 0);
    });
  });

  group('cosa cambia davvero nel piano', () {
    test('il lungo si sposta dove c\'e\' tempo, solo in quella settimana', () {
      final TrainingPlan? generato =
          service.generate(config().withWeekAvailability(4, turni));
      expect(generato, isNotNull);
      final TrainingPlan piano = generato!;

      PlannedSession lungoDi(int week) => piano.weeks[week - 1].sessions
          .firstWhere((PlannedSession s) => s.kind == SessionKind.long);

      // Nella settimana normale il lungo e' la domenica (120 minuti).
      expect(lungoDi(3).date.weekday, 7);
      expect(lungoDi(5).date.weekday, 7);

      // Nella settimana dei turni e' il mercoledi' (150 minuti).
      expect(lungoDi(4).date.weekday, 3,
          reason: 'il lungo deve andare dove c\'e\' piu\' tempo');
    });

    test('le sedute cadono solo nei giorni dichiarati per quella settimana',
        () {
      final TrainingPlan piano =
          service.generate(config().withWeekAvailability(4, turni))!;
      final List<int> giorni = piano.weeks[3].sessions
          .map((PlannedSession s) => s.date.weekday)
          .toList()
        ..sort();
      expect(giorni, turni.runDays,
          reason: 'trovati $giorni, attesi ${turni.runDays}');

      // Mentre la settimana prima e dopo usano i giorni normali.
      for (final int w in <int>[2, 4]) {
        final List<int> altri = piano.weeks[w].sessions
            .map((PlannedSession s) => s.date.weekday)
            .toList()
          ..sort();
        expect(altri, normale.runDays, reason: 'settimana ${w + 1}');
      }
    });

    test('la fase e il numero di settimane non cambiano', () {
      // Un turno diverso non e' un motivo per riscrivere la periodizzazione.
      final TrainingPlan prima = service.generate(config())!;
      final TrainingPlan dopo =
          service.generate(config().withWeekAvailability(4, turni))!;

      expect(dopo.weeks.length, prima.weeks.length);
      for (int i = 0; i < prima.weeks.length; i++) {
        expect(dopo.weeks[i].phase, prima.weeks[i].phase,
            reason: 'fase della settimana ${i + 1}');
        expect(dopo.weeks[i].startDate, prima.weeks[i].startDate);
      }
    });

    test('le altre settimane restano identiche, chilometro per chilometro', () {
      // Il controllo piu' importante del file: se cambiare una settimana
      // muovesse anche le altre, l'atleta non potrebbe fidarsi del piano.
      final TrainingPlan prima = service.generate(config())!;
      final TrainingPlan dopo =
          service.generate(config().withWeekAvailability(4, turni))!;

      for (int i = 0; i < prima.weeks.length; i++) {
        if (i == 3) continue; // la settimana cambiata, ovviamente diversa
        expect(
          dopo.weeks[i].plannedKm.toStringAsFixed(2),
          prima.weeks[i].plannedKm.toStringAsFixed(2),
          reason: 'settimana ${i + 1} non doveva muoversi',
        );
      }
    });

    test('la settimana cambiata lo dice', () {
      final TrainingPlan piano =
          service.generate(config().withWeekAvailability(4, turni))!;
      expect(piano.weeks[3].note, isNotNull);
      expect(piano.weeks[3].note!.toLowerCase().contains('cambiati'), isTrue);
      expect(piano.weeks[2].note?.contains('cambiati') ?? false, isFalse);
    });

    test('meno tempo significa meno chilometri, non sedute impossibili', () {
      // La settimana con meno tempo non puo' chiedere lo stesso volume: il
      // tempo dichiarato e' un tetto, e il tetto vale anche per l'eccezione.
      final WeeklyAvailability stretta = WeeklyAvailability(<int, int>{
        2: 40,
        4: 40,
        6: 60,
      });
      final TrainingPlan piano =
          service.generate(config().withWeekAvailability(6, stretta))!;
      final double cambiata = piano.weeks[5].plannedKm;
      final double vicina = piano.weeks[4].plannedKm;
      expect(cambiata < vicina, isTrue,
          reason: 'cambiata $cambiata, vicina $vicina');
    });
  });

  group('il salvataggio', () {
    test('andata e ritorno su disco tiene le eccezioni', () {
      final PlanConfig originale = config()
          .withWeekAvailability(4, turni)
          .withWeekAvailability(9, turni);

      final PlanConfig riletta = PlanConfig.fromJson(originale.toJson());

      expect(riletta.changedWeekCount, 2);
      expect(riletta.availabilityForWeek(4), turni);
      expect(riletta.availabilityForWeek(9), turni);
      expect(riletta.availabilityForWeek(5), normale);
    });

    test('un piano salvato prima di questa funzione si apre uguale', () {
      // Nessuna chiave "weekOverrides" nel file: tutte le settimane usano la
      // settimana normale, come hanno sempre fatto.
      final Map<String, dynamic> vecchio = config().toJson()
        ..remove('weekOverrides');
      final PlanConfig riletta = PlanConfig.fromJson(vecchio);
      expect(riletta.changedWeekCount, 0);
      expect(riletta.availabilityForWeek(4), normale);
    });

    test('un file manomesso non impedisce di aprire il piano', () {
      final Map<String, dynamic> rotto = config().toJson();
      rotto['weekOverrides'] = <String, dynamic>{
        'pippo': <String, dynamic>{'3': 60},
        '0': <String, dynamic>{'3': 60},
        '4': 'non una settimana',
        '5': <String, dynamic>{'3': 90, '5': 60, '7': 120},
      };
      final PlanConfig riletta = PlanConfig.fromJson(rotto);
      expect(riletta.weekOverrides.keys.toList(), <int>[5]);
    });
  });

  group('l\'anteprima dice la verita\'', () {
    test('il conto della qualita\' e\' lo stesso del generatore', () {
      // La schermata che cambia i giorni mostra dove cadranno le sedute
      // mentre si tocca il piu' e il meno. Se usasse un conto suo, prima o
      // poi direbbe due qualita' dove il piano ne mette una.
      final TrainingPlan piano =
          service.generate(config().withWeekAvailability(4, turni))!;

      for (int i = 0; i < piano.weeks.length; i++) {
        final PlanWeek w = piano.weeks[i];
        final WeeklyAvailability usata =
            piano.config.availabilityForWeek(w.number);
        final int atteso = service.qualityWantedFor(
          phase: w.phase,
          dayCount: usata.dayCount,
          isDownWeek: service.isDownWeek(i, w.phase),
        );
        final WeekSchedule s =
            service.scheduleFor(usata, qualityWanted: atteso);
        expect(s.qualityDays.length, w.qualityCount,
            reason: 'settimana ${w.number}');
        expect(
          w.sessions
              .firstWhere((PlannedSession x) => x.kind == SessionKind.long)
              .date
              .weekday,
          s.longDay,
          reason: 'lungo della settimana ${w.number}',
        );
      }
    });

    test('tre giorni soli: una qualita\', non due', () {
      expect(
        service.qualityWantedFor(
          phase: PlanPhase.build,
          dayCount: 3,
          isDownWeek: false,
        ),
        1,
      );
      expect(
        service.qualityWantedFor(
          phase: PlanPhase.build,
          dayCount: 5,
          isDownWeek: false,
        ),
        2,
      );
      expect(
        service.qualityWantedFor(
          phase: PlanPhase.build,
          dayCount: 5,
          isDownWeek: true,
        ),
        1,
        reason: 'scaricare tenendo due qualita\' non e\' scaricare',
      );
    });
  });

  group('due settimane uguali sono uguali', () {
    test('stessi giorni e stessi minuti', () {
      expect(
        WeeklyAvailability(<int, int>{1: 60, 3: 90}),
        WeeklyAvailability(<int, int>{3: 90, 1: 60}),
      );
      expect(
        WeeklyAvailability(<int, int>{1: 60, 3: 90}).hashCode,
        WeeklyAvailability(<int, int>{3: 90, 1: 60}).hashCode,
      );
    });

    test('un giorno sotto il minimo utile e\' riposo, non un giorno', () {
      expect(
        WeeklyAvailability(<int, int>{1: 60, 3: 90, 5: 5}),
        WeeklyAvailability(<int, int>{1: 60, 3: 90}),
      );
    });

    test('quindici minuti di differenza si notano', () {
      expect(
        WeeklyAvailability(<int, int>{1: 60}) ==
            WeeklyAvailability(<int, int>{1: 75}),
        isFalse,
      );
    });
  });
}
