import 'package:flutter_test/flutter_test.dart';
import 'package:run_coach_app/models/athlete_profile.dart';
import 'package:run_coach_app/models/estimate.dart';
import 'package:run_coach_app/services/run_index_engine.dart';

/// Gli scenari qui sotto sono quelli richiesti dalla specifica del motore:
/// D (miglioramento costante), E (singola prestazione eccezionale),
/// F (corsa facile che non deve alterare la stima), piu' i casi limite.
void main() {
  const RunIndexEngine engine = RunIndexEngine();

  final DateTime now = DateTime(2026, 9, 26);

  int mmss(int m, int s) => m * 60 + s;

  PerformanceSample sample({
    double meters = 5000,
    required int seconds,
    required int daysAgo,
    EstimateSource source = EstimateSource.runSegment,
    int? rpe = 8,
    String? activityId,
  }) =>
      PerformanceSample(
        meters: meters,
        seconds: seconds,
        date: now.subtract(Duration(days: daysAgo)),
        source: source,
        rpe: rpe,
        activityId: activityId ?? 'act-$daysAgo-${meters.round()}',
      );

  group('pesi', () {
    test('una prestazione vecchia pesa meno di una recente', () {
      final double fresh =
          engine.weightOf(sample(seconds: mmss(20, 0), daysAgo: 2), now: now);
      final double old =
          engine.weightOf(sample(seconds: mmss(20, 0), daysAgo: 84), now: now);
      expect(fresh > old, isTrue);
      // Sei settimane dimezzano il peso.
      final double sixWeeks =
          engine.weightOf(sample(seconds: mmss(20, 0), daysAgo: 42), now: now);
      expect(sixWeeks / fresh, closeTo(0.5, 0.06));
    });

    test('oltre la soglia di eta\' la prestazione sparisce', () {
      expect(engine.ageWeight(RunIndexEngine.maxAgeDays + 1), 0);
    });

    test('sotto 1,5 km non conta niente', () {
      expect(engine.distanceWeight(800), 0);
      expect(engine.distanceWeight(1400), 0);
      expect(engine.distanceWeight(1500) > 0, isTrue);
      expect(engine.distanceWeight(3000), 1.0);
      expect(engine.distanceWeight(10000), 1.0);
    });

    test('una corsa dichiarata facile pesa pochissimo', () {
      final double hard =
          engine.weightOf(sample(seconds: mmss(20, 0), daysAgo: 3, rpe: 9),
              now: now);
      final double easy =
          engine.weightOf(sample(seconds: mmss(20, 0), daysAgo: 3, rpe: 3),
              now: now);
      expect(easy < hard * 0.2, isTrue, reason: 'facile $easy, tirata $hard');
    });

    test('una gara pesa piu\' di un tratto in allenamento', () {
      final double race = engine.weightOf(
        sample(
            seconds: mmss(20, 0), daysAgo: 3, source: EstimateSource.race),
        now: now,
      );
      final double segment = engine.weightOf(
        sample(
            seconds: mmss(20, 0),
            daysAgo: 3,
            source: EstimateSource.runSegment),
        now: now,
      );
      expect(race > segment, isTrue);
    });
  });

  group('SCENARIO E - una singola prestazione eccezionale', () {
    test('non fa saltare l\'indice', () {
      final List<PerformanceSample> base = <PerformanceSample>[
        sample(seconds: mmss(25, 12), daysAgo: 60, rpe: 7),
        sample(seconds: mmss(25, 0), daysAgo: 40, rpe: 7),
        sample(seconds: mmss(24, 50), daysAgo: 20, rpe: 7),
      ];

      final RunIndexResult before = engine.estimate(base, now: now);
      expect(before.index, isNotNull);

      final RunIndexResult after = engine.estimate(
        <PerformanceSample>[
          ...base,
          // Una domenica da 21 minuti: quattro minuti meglio del solito.
          sample(seconds: mmss(21, 0), daysAgo: 0, rpe: 9),
        ],
        now: now,
      );

      final double jump = after.index!.value - before.index!.value;
      // Quella prova da sola direbbe circa 47, cioe' nove punti sopra.
      // Per un tratto dentro una corsa il freno resta stretto: non e' detto
      // che stesse spingendo, poteva essere una discesa.
      expect(jump > 0, isTrue, reason: 'deve salire un po\'');
      expect(
          jump <=
              RunIndexEngine.maxUpStepFor(EstimateSource.runSegment) + 0.01,
          isTrue,
          reason: 'salto di $jump punti: troppo');
    });
  });

  group('SCENARIO D - miglioramento costante', () {
    test('l\'indice sale, e piu\' in fretta di un picco isolato', () {
      final List<PerformanceSample> steady = <PerformanceSample>[
        sample(seconds: mmss(25, 0), daysAgo: 70),
        sample(seconds: mmss(24, 20), daysAgo: 56),
        sample(seconds: mmss(23, 40), daysAgo: 42),
        sample(seconds: mmss(23, 0), daysAgo: 28),
        sample(seconds: mmss(22, 20), daysAgo: 14),
        sample(seconds: mmss(21, 40), daysAgo: 0),
      ];

      final RunIndexResult result = engine.estimate(steady, now: now);
      expect(result.index, isNotNull);

      final RunIndexResult onlyFirst = engine.estimate(
        <PerformanceSample>[steady.first],
        now: now,
      );

      // Sei conferme consecutive spostano l'indice di piu' di un singolo
      // salto massimo: e' la conferma ripetuta che fa il suo lavoro.
      final double growth = result.index!.value - onlyFirst.index!.value;
      expect(growth > RunIndexEngine.maxUpStepFor(EstimateSource.runSegment),
          isTrue,
          reason: 'cresciuto solo di $growth punti');

      // Ma resta comunque sotto quello che l'ultima prova direbbe da sola:
      // il motore e' prudente di proposito.
      final RunIndexResult onlyLast =
          engine.estimate(<PerformanceSample>[steady.last], now: now);
      expect(result.index!.value < onlyLast.index!.value, isTrue);
    });
  });

  group('SCENARIO F - la corsa facile non altera la stima', () {
    test('una corsa lenta a fatica bassa lascia l\'indice dov\'e\'', () {
      final List<PerformanceSample> hard = <PerformanceSample>[
        sample(seconds: mmss(20, 0), daysAgo: 10, rpe: 9),
      ];
      final RunIndexResult before = engine.estimate(hard, now: now);

      final RunIndexResult after = engine.estimate(
        <PerformanceSample>[
          ...hard,
          // Trenta minuti sui 5 km: una corsa di scarico.
          sample(seconds: mmss(30, 0), daysAgo: 1, rpe: 3),
        ],
        now: now,
      );

      final double drop = before.index!.value - after.index!.value;
      expect(drop < 0.5, isTrue,
          reason: 'la corsa lenta ha abbassato l\'indice di $drop punti');
    });

    test('nemmeno tante corse lente lo affossano', () {
      final List<PerformanceSample> samples = <PerformanceSample>[
        sample(seconds: mmss(20, 0), daysAgo: 20, rpe: 9),
      ];
      for (int i = 1; i <= 8; i++) {
        samples.add(sample(seconds: mmss(29, 0), daysAgo: i, rpe: 3));
      }

      final RunIndexResult result = engine.estimate(samples, now: now);
      final RunIndexResult solo = engine.estimate(
        <PerformanceSample>[samples.first],
        now: now,
      );
      expect(solo.index!.value - result.index!.value < 2.0, isTrue);
    });
  });

  group('decadimento per inattivita\'', () {
    test('sotto le quattro settimane non si toglie niente', () {
      final RunIndexResult result = engine.estimate(
        <PerformanceSample>[sample(seconds: mmss(20, 0), daysAgo: 20)],
        now: now,
      );
      expect(result.decayPoints, 0);
    });

    test('oltre, l\'indice scende piano', () {
      final RunIndexResult fresh = engine.estimate(
        <PerformanceSample>[sample(seconds: mmss(20, 0), daysAgo: 10)],
        now: now,
      );
      final RunIndexResult stale = engine.estimate(
        <PerformanceSample>[sample(seconds: mmss(20, 0), daysAgo: 100)],
        now: now,
      );
      expect(stale.decayPoints > 0, isTrue);
      expect(stale.index!.value < fresh.index!.value, isTrue);
      // Ma non crolla: e' un decadimento, non un azzeramento.
      expect(stale.decayPoints <= RunIndexEngine.maxDecayPoints, isTrue);
    });
  });

  group('confidenza', () {
    test('una sola prova vale meno di tre', () {
      final RunIndexResult one = engine.estimate(
        <PerformanceSample>[sample(seconds: mmss(22, 0), daysAgo: 5)],
        now: now,
      );
      final RunIndexResult three = engine.estimate(
        <PerformanceSample>[
          sample(seconds: mmss(22, 0), daysAgo: 5),
          sample(seconds: mmss(22, 10), daysAgo: 12),
          sample(seconds: mmss(21, 55), daysAgo: 19),
        ],
        now: now,
      );
      expect(three.index!.confidence > one.index!.confidence, isTrue);
    });

    test('prestazioni che si contraddicono abbassano la fiducia', () {
      final RunIndexResult agreeing = engine.estimate(
        <PerformanceSample>[
          sample(seconds: mmss(22, 0), daysAgo: 5),
          sample(seconds: mmss(22, 5), daysAgo: 15),
          sample(seconds: mmss(21, 58), daysAgo: 25),
        ],
        now: now,
      );
      final RunIndexResult conflicting = engine.estimate(
        <PerformanceSample>[
          sample(seconds: mmss(22, 0), daysAgo: 5),
          sample(seconds: mmss(28, 0), daysAgo: 15),
          sample(seconds: mmss(19, 30), daysAgo: 25),
        ],
        now: now,
      );
      expect(conflicting.index!.confidence < agreeing.index!.confidence,
          isTrue);
    });

    test('non si arriva mai alla certezza', () {
      final List<PerformanceSample> many = <PerformanceSample>[];
      for (int i = 0; i < 20; i++) {
        many.add(sample(
          seconds: mmss(20, 0),
          daysAgo: i,
          source: EstimateSource.race,
          rpe: 10,
        ));
      }
      final RunIndexResult result = engine.estimate(many, now: now);
      expect(result.index!.confidence < 1.0, isTrue);
      expect(result.index!.confidence <= 0.92, isTrue);
    });
  });

  group('una corsa e\' una prova sola', () {
    test('i tratti dentro la stessa uscita non si contano piu\' volte', () {
      // Stessa attivita', cinque tratti: non deve valere come cinque prove.
      final List<PerformanceSample> oneRun = <PerformanceSample>[
        sample(meters: 1500, seconds: mmss(6, 0), daysAgo: 3, activityId: 'a1'),
        sample(meters: 3000, seconds: mmss(12, 20), daysAgo: 3, activityId: 'a1'),
        sample(meters: 5000, seconds: mmss(21, 0), daysAgo: 3, activityId: 'a1'),
        sample(
            meters: 10000, seconds: mmss(44, 0), daysAgo: 3, activityId: 'a1'),
      ];

      final RunIndexResult result = engine.estimate(oneRun, now: now);
      expect(result.samples.length, 1,
          reason: 'quattro tratti della stessa corsa devono diventare uno');

      // E il tratto scelto non deve essere quello corto: sotto i 3 km la
      // stima e' troppo sensibile a uno sprint in discesa.
      expect(result.samples.first.sample.meters >= 3000, isTrue);
    });

    test('corse diverse contano separatamente', () {
      final RunIndexResult result = engine.estimate(
        <PerformanceSample>[
          sample(seconds: mmss(22, 0), daysAgo: 3, activityId: 'a1'),
          sample(seconds: mmss(22, 0), daysAgo: 10, activityId: 'a2'),
          sample(seconds: mmss(22, 0), daysAgo: 17, activityId: 'a3'),
        ],
        now: now,
      );
      expect(result.samples.length, 3);
    });
  });

  group('spettro velocista - fondista', () {
    test('chi va forte sul corto e cede sul lungo viene riconosciuto', () {
      final RunIndexResult result = engine.estimate(
        <PerformanceSample>[
          // 3 km molto buono.
          sample(meters: 3000, seconds: mmss(11, 0), daysAgo: 10, activityId: 'a1'),
          // 10 km relativamente scarso.
          sample(meters: 10000, seconds: mmss(46, 0), daysAgo: 17, activityId: 'a2'),
        ],
        now: now,
      );

      expect(result.profileBias, isNotNull);
      expect(result.profileBias!.value < 0, isTrue,
          reason: 'bias ${result.profileBias!.value}: doveva essere negativo');
      // La confidenza dello spettro resta sempre piu' bassa di quella
      // dell'indice: serve molta piu' evidenza per dire che tipo sei.
      expect(result.profileBias!.confidence < result.index!.confidence, isTrue);
    });

    test('senza prove su entrambi i lati non si dice niente', () {
      final RunIndexResult result = engine.estimate(
        <PerformanceSample>[
          sample(meters: 3000, seconds: mmss(11, 0), daysAgo: 10),
        ],
        now: now,
      );
      expect(result.profileBias, isNull);
    });
  });

  group('casi limite', () {
    test('storico vuoto', () {
      final RunIndexResult result =
          engine.estimate(<PerformanceSample>[], now: now);
      expect(result.isEmpty, isTrue);
      expect(result.index, isNull);
      expect(result.explanation.isNotEmpty, isTrue);
    });

    test('solo prestazioni troppo corte', () {
      final RunIndexResult result = engine.estimate(
        <PerformanceSample>[
          sample(meters: 800, seconds: mmss(2, 40), daysAgo: 2),
          sample(meters: 1000, seconds: mmss(3, 30), daysAgo: 5),
        ],
        now: now,
      );
      expect(result.isEmpty, isTrue);
    });

    test('solo prestazioni troppo vecchie', () {
      final RunIndexResult result = engine.estimate(
        <PerformanceSample>[
          sample(seconds: mmss(20, 0), daysAgo: 400),
        ],
        now: now,
      );
      expect(result.isEmpty, isTrue);
    });

    test('la spiegazione c\'e\' sempre', () {
      final RunIndexResult result = engine.estimate(
        <PerformanceSample>[sample(seconds: mmss(22, 0), daysAgo: 5)],
        now: now,
      );
      expect(result.explanation.isNotEmpty, isTrue);
      expect(result.explanation.contains('prestazion'), isTrue);
    });
  });

  group('personali dal profilo', () {
    test('un personale senza data pesa poco', () {
      const AthleteProfile profile = AthleteProfile(
        personalBests: <PersonalBest>[
          PersonalBest(meters: 10000, seconds: 2400), // 40:00, senza data
        ],
      );
      final List<PerformanceSample> samples =
          engine.samplesFromProfile(profile);
      expect(samples.length, 1);
      // Viene trattato come vecchio di un anno: peso sotto la soglia utile.
      expect(engine.weightOf(samples.first, now: now) < 0.05, isTrue);
    });

    test('un personale recente in gara pesa molto', () {
      final AthleteProfile profile = AthleteProfile(
        personalBests: <PersonalBest>[
          PersonalBest(
            meters: 10000,
            seconds: 2400,
            date: now.subtract(const Duration(days: 7)),
          ),
        ],
      );
      final List<PerformanceSample> samples =
          engine.samplesFromProfile(profile);
      expect(samples.length, 1);
      expect(samples.first.source, EstimateSource.race);
      expect(engine.weightOf(samples.first, now: now) > 0.5, isTrue);
    });

    test('i personali troppo corti vengono scartati', () {
      const AthleteProfile profile = AthleteProfile(
        personalBests: <PersonalBest>[
          PersonalBest(meters: 1000, seconds: 200),
        ],
      );
      expect(engine.samplesFromProfile(profile), isEmpty);
    });
  });

  // --------------------------------------------------------------- le gare
  //
  // Questo gruppo nasce da un errore vero, trovato al primo uso serio: un
  // atleta ha dichiarato il suo 10 km in 44:00 (indice 46,5) e il motore si
  // e' mosso da 36,2 a 37,7. Gli avrebbe fatto correre il lento quasi un
  // minuto al chilometro piu' piano del dovuto. Due regole tarate sui tratti
  // GPS erano state applicate anche alle gare.
  group('una gara dichiarata viene creduta', () {
    PerformanceSample gara({
      double meters = 10000,
      required int seconds,
      required int daysAgo,
    }) =>
        PerformanceSample(
          meters: meters,
          seconds: seconds,
          date: now.subtract(Duration(days: daysAgo)),
          source: EstimateSource.race,
        );

    test('non viene punita per la fatica non dichiarata', () {
      // In gara si spinge per definizione: non avere l'RPE non deve costarle
      // niente. Prima valeva il 60% del suo peso.
      final double peso = engine.weightOf(
        gara(seconds: mmss(44, 0), daysAgo: 1),
        now: now,
      );
      expect(peso > 0.95, isTrue, reason: 'peso $peso: una gara deve pesare '
          'quasi uno, anche senza fatica dichiarata');
    });

    test('porta l\'indice vicino a quello che la gara dice', () {
      final List<PerformanceSample> soloCorse = <PerformanceSample>[
        sample(seconds: mmss(26, 13), daysAgo: 0, rpe: null),
      ];
      final RunIndexResult prima = engine.estimate(soloCorse, now: now);

      final RunIndexResult dopo = engine.estimate(
        <PerformanceSample>[...soloCorse, gara(seconds: mmss(44, 0), daysAgo: 0)],
        now: now,
      );

      final double dice = engine.fitness.vdotFromPerformance(10000, 44 * 60)!;
      expect(dopo.index!.value > prima.index!.value + 5, isTrue,
          reason: 'la gara vale $dice ma l\'indice si e\' fermato a '
              '${dopo.index!.value}');
      // Resta comunque un filo sotto: il motore e' prudente, non ottimista.
      expect(dopo.index!.value <= dice, isTrue);
      expect(dopo.index!.value > dice - 2.0, isTrue,
          reason: 'troppo lontano da quello che la gara dice');
    });

    test('una corsa lenta non fa crollare la fiducia nella gara', () {
      // Non si dimostra di essere lenti correndo piano: una corsa tranquilla
      // non contraddice una gara, e non deve abbassare la fiducia.
      final RunIndexResult solaGara = engine.estimate(
        <PerformanceSample>[gara(seconds: mmss(44, 0), daysAgo: 0)],
        now: now,
      );
      final RunIndexResult conLenta = engine.estimate(
        <PerformanceSample>[
          gara(seconds: mmss(44, 0), daysAgo: 0),
          sample(seconds: mmss(32, 0), daysAgo: 2, rpe: 3),
        ],
        now: now,
      );
      expect(conLenta.index!.confidence >= solaGara.index!.confidence - 0.02,
          isTrue,
          reason: 'fiducia scesa da ${solaGara.index!.confidence} a '
              '${conLenta.index!.confidence} per una corsa lenta');
    });

    test('nemmeno l\'indice crolla per una corsa lenta', () {
      // L'ALTRA META' DELLO STESSO GUASTO, E LA PEGGIORE.
      //
      // Non era solo la fiducia: era l'indice. Una gara di 10 km in 44:00
      // corsa ieri (indice 46,5) con una corsa di scarico due giorni prima
      // dava 38,5. Otto punti: tradotti in passo, sono quasi cinquanta
      // secondi al chilometro di lento in meno del dovuto, su tutto il
      // piano di allenamento.
      //
      // Il motivo era il punto di partenza del filtro: prendeva la
      // prestazione piu' vecchia e la usava come stima iniziale senza
      // guardarne il peso. Quella corsa di scarico pesa 0,04 su 1 - cioe'
      // non dice niente - e decideva da dove si parte.
      final RunIndexResult solaGara = engine.estimate(
        <PerformanceSample>[gara(seconds: mmss(44, 0), daysAgo: 0)],
        now: now,
      );
      final RunIndexResult conLenta = engine.estimate(
        <PerformanceSample>[
          gara(seconds: mmss(44, 0), daysAgo: 0),
          sample(seconds: mmss(32, 0), daysAgo: 2, rpe: 3),
        ],
        now: now,
      );

      final double calo = solaGara.index!.value - conLenta.index!.value;
      expect(calo < 1.0, isTrue,
          reason: 'indice scivolato da ${solaGara.index!.value} a '
              '${conLenta.index!.value} per una corsa di scarico');
    });

    test('una brutta prova TIRATA abbassa la fiducia, una lenta no', () {
      // LA DISTINZIONE CHE IL MOTORE DEVE SAPER FARE.
      //
      // Due prestazioni identiche - 5 km in 32:00 due giorni prima di una
      // 10 km in 44:00 - valgono una il contrario dell'altra a seconda di
      // quanto sono costate:
      //
      //   a fatica 3  ->  stava corricchiando. Non contraddice niente.
      //   a fatica 9  ->  ci stava provando, e tanto e' venuto fuori.
      //                   Quello contraddice la gara, e la fiducia deve
      //                   scendere.
      //
      // Serve perche' il motore ha sbagliato in tutte e due le direzioni:
      // prima scartava le prove tirate andate male (contavano solo le gare),
      // poi, correggendo, ha iniziato a contare anche le lente - e allora
      // dichiarare una gara ABBASSAVA la fiducia.
      final RunIndexResult solaGara = engine.estimate(
        <PerformanceSample>[gara(seconds: mmss(44, 0), daysAgo: 0)],
        now: now,
      );
      final RunIndexResult conLenta = engine.estimate(
        <PerformanceSample>[
          gara(seconds: mmss(44, 0), daysAgo: 0),
          sample(seconds: mmss(32, 0), daysAgo: 2, rpe: 3),
        ],
        now: now,
      );
      final RunIndexResult conTirata = engine.estimate(
        <PerformanceSample>[
          gara(seconds: mmss(44, 0), daysAgo: 0),
          sample(seconds: mmss(32, 0), daysAgo: 2, rpe: 9),
        ],
        now: now,
      );

      expect(conTirata.index!.confidence < solaGara.index!.confidence, isTrue,
          reason: 'una 5 km tirata in 32:00 contraddice una 10 km in 44:00: '
              'fiducia ${solaGara.index!.confidence} -> '
              '${conTirata.index!.confidence}');
      expect(
          conLenta.index!.confidence >= solaGara.index!.confidence - 0.02,
          isTrue,
          reason: 'la stessa corsa a fatica 3 non contraddice niente');
      expect(conTirata.index!.confidence < conLenta.index!.confidence, isTrue,
          reason: 'la fatica dichiarata deve fare la differenza');
    });

    test('una lenta vecchia non tiene in ostaggio una prova tirata', () {
      // La stessa cosa in forma piu' estrema: una corsa tranquilla di
      // quaranta giorni prima teneva un 5 km tirato di ieri a indice 29,7
      // invece di 49,7. Venti punti.
      final RunIndexResult result = engine.estimate(
        <PerformanceSample>[
          sample(seconds: mmss(32, 0), daysAgo: 40, rpe: 3),
          sample(seconds: mmss(20, 0), daysAgo: 1, rpe: 9),
        ],
        now: now,
      );
      final RunIndexResult solaTirata = engine.estimate(
        <PerformanceSample>[sample(seconds: mmss(20, 0), daysAgo: 1, rpe: 9)],
        now: now,
      );

      expect(result.index!.value > solaTirata.index!.value - 1.0, isTrue,
          reason: 'la prova tirata vale ${solaTirata.index!.value} ma con '
              'una lenta vecchia in archivio l\'indice e\' '
              '${result.index!.value}');
    });

    test('la corsa lenta resta nel conto, non viene cancellata', () {
      // La correzione non e' "ignorare le corse lente": e' "non lasciare che
      // decidano il punto di partenza". Continuano a pesare, poco, e a
      // contare come evidenza del fatto che si sta correndo.
      final RunIndexResult solaGara = engine.estimate(
        <PerformanceSample>[gara(seconds: mmss(44, 0), daysAgo: 0)],
        now: now,
      );
      final RunIndexResult conLenta = engine.estimate(
        <PerformanceSample>[
          gara(seconds: mmss(44, 0), daysAgo: 0),
          sample(seconds: mmss(32, 0), daysAgo: 2, rpe: 3),
        ],
        now: now,
      );

      expect(conLenta.samples.length, 2);
      // Un filo sotto la gara pura: la lenta tira in giu' di poco, com'e'
      // giusto, invece di decidere tutto.
      expect(conLenta.index!.value < solaGara.index!.value, isTrue);
    });

    test('una gara andata male viene ascoltata, ma con calma', () {
      final RunIndexResult buona = engine.estimate(
        <PerformanceSample>[gara(seconds: mmss(44, 0), daysAgo: 30)],
        now: now,
      );
      final RunIndexResult poi = engine.estimate(
        <PerformanceSample>[
          gara(seconds: mmss(44, 0), daysAgo: 30),
          gara(seconds: mmss(50, 0), daysAgo: 0),
        ],
        now: now,
      );
      final double calo = buona.index!.value - poi.index!.value;
      expect(calo > 0, isTrue, reason: 'una gara peggiore deve contare');
      expect(calo <= RunIndexEngine.maxDownStepFor(EstimateSource.race) + 0.01,
          isTrue, reason: 'caduta di $calo punti: troppo di colpo');
    });

    test('il freno sui tratti GPS resta stretto', () {
      expect(RunIndexEngine.maxUpStepFor(EstimateSource.runSegment) <= 1.5,
          isTrue);
      expect(
          RunIndexEngine.maxUpStepFor(EstimateSource.race) >
              RunIndexEngine.maxUpStepFor(EstimateSource.runSegment) * 3,
          isTrue);
      expect(
          RunIndexEngine.upGainFor(EstimateSource.race) >
              RunIndexEngine.upGainFor(EstimateSource.runSegment),
          isTrue);
    });
  });
}
