import 'dart:math' as math;

import '../models/athlete_profile.dart';
import '../models/effort.dart';
import '../models/estimate.dart';
import '../models/running_activity.dart';
import 'fitness_service.dart';
import 'records_service.dart';

/// Una prestazione utilizzabile per stimare la forma.
class PerformanceSample {
  const PerformanceSample({
    required this.meters,
    required this.seconds,
    required this.date,
    required this.source,
    this.rpe,
    this.activityId,
    this.label,
  });

  final double meters;
  final int seconds;
  final DateTime date;
  final EstimateSource source;

  /// Fatica percepita dichiarata, se c'e'.
  final int? rpe;

  final String? activityId;

  /// Descrizione breve per la spiegazione ("5 km del 12 settembre").
  final String? label;

  double get paceSecPerKm => seconds / (meters / 1000.0);
}

/// Una prestazione con il peso che il motore le ha dato.
class WeightedSample {
  const WeightedSample({
    required this.sample,
    required this.rawIndex,
    required this.weight,
    required this.ageDays,
  });

  final PerformanceSample sample;

  /// Indice che quella singola prestazione, da sola, suggerirebbe.
  final double rawIndex;

  /// Quanto pesa, da 0 a 1.
  final double weight;

  final int ageDays;
}

/// Il risultato del motore.
class RunIndexResult {
  const RunIndexResult({
    required this.index,
    required this.samples,
    required this.speedIndex,
    required this.enduranceIndex,
    required this.profileBias,
    required this.lastEvidence,
    required this.decayPoints,
    required this.explanation,
  });

  /// L'indice di forma, con la sua confidenza.
  final Estimate<double>? index;

  /// Le prestazioni considerate, dalla piu' pesante alla piu' leggera.
  final List<WeightedSample> samples;

  /// Indice suggerito dalle prove brevi (sotto i 5 km).
  final double? speedIndex;

  /// Indice suggerito dalle prove lunghe (dai 10 km in su).
  final double? enduranceIndex;

  /// Differenza fra i due: positiva = tipo resistente, negativa = tipo veloce.
  ///
  /// E' la versione onesta dello "spettro velocista-fondista": un numero con
  /// la sua confidenza, che resta `null` finche' non ci sono prove su
  /// entrambi i lati.
  final Estimate<double>? profileBias;

  /// Data dell'ultima prestazione considerata.
  final DateTime? lastEvidence;

  /// Punti tolti per inattivita'.
  final double decayPoints;

  /// Perche' l'indice vale quello che vale.
  final String explanation;

  bool get isEmpty => index == null;
}

/// Stima della forma attuale a partire dalle prestazioni.
///
/// COME FUNZIONA, E PERCHE' COSI'
/// ------------------------------
/// Ogni prestazione viene convertita nell'indice che, da sola, suggerirebbe
/// (la matematica e' quella di [FitnessService]). Poi le prestazioni vengono
/// pesate e fuse in un unico numero.
///
/// Il peso di una prestazione dipende da quattro cose:
///
///  1. **da dove viene** - una gara vale piu' di un tratto veloce dentro una
///     corsa normale;
///  2. **quanto ti e' costata** - se l'hai dichiarata facile, non dice niente
///     su quanto vai forte: stavi passeggiando;
///  3. **quanto e' vecchia** - il peso si dimezza ogni sei settimane;
///  4. **quanto e' lunga** - sotto i 1500 metri il modello non regge, e uno
///     sprint in discesa gonfierebbe tutti i ritmi di allenamento.
///
/// La fusione e' un filtro sequenziale, non una media: si parte dalla
/// prestazione piu' vecchia e ogni successiva sposta l'indice di un passo
/// proporzionale al suo peso. Con due limiti che contano:
///
///  - **si sale piu' facilmente di quanto si scenda.** Una prestazione
///    eccellente e' una prova di cosa sai fare; una prestazione scarsa puo'
///    essere caldo, stanchezza, una brutta giornata. La prima e' un'evidenza
///    forte, la seconda debole;
///  - **nessuna singola prestazione puo' spostare l'indice di piu' di 1,5
///    punti.** Una domenica eccezionale non deve cambiare tutti i ritmi di
///    allenamento del mese: serve conferma.
///
/// L'indice **non scende mai** perche' hai corso piano. Scende solo per il
/// passare del tempo senza prove: e' il decadimento dell'allenamento, che e'
/// una cosa reale, mentre "oggi ero lento quindi sono peggiorato" non lo e'.
class RunIndexEngine {
  const RunIndexEngine({this.fitness = const FitnessService()});

  final FitnessService fitness;

  // ---------------------------------------------------------------- costanti
  // VALORI EMPIRICI, TARABILI. Ognuno ha il suo perche' scritto accanto.

  /// Dopo quanti giorni il peso di una prestazione si dimezza.
  /// Sei settimane: e' l'ordine di grandezza in cui la forma cambia davvero.
  static const double halfLifeDays = 42;

  /// Oltre questa eta' una prestazione viene ignorata del tutto.
  static const int maxAgeDays = 240;

  /// Sotto questa distanza il modello di equivalenza non e' affidabile.
  static const double minUsableMeters = 1500;

  /// Da questa distanza in su la prestazione conta pieno.
  static const double fullWeightMeters = 3000;

  /// Quanto in fretta l'indice segue una prestazione migliore del previsto.
  static const double upGain = 0.55;

  /// Quanto in fretta segue una peggiore. Molto meno: una giornata storta non
  /// e' una perdita di forma.
  static const double downGain = 0.20;

  /// Massimo spostamento in punti che una singola prestazione puo' produrre.
  ///
  /// Il limite viene poi ridotto per le prestazioni meno affidabili: una gara
  /// puo' spostare l'indice di 1,5 punti, un tratto veloce dentro una corsa
  /// normale di circa 1,2. Senza questo, per le prestazioni molto fuori scala
  /// il limite sarebbe l'unico vincolo e una gara varrebbe quanto un allungo.
  static const double maxUpStep = 1.5;
  static const double maxDownStep = 1.0;

  /// Quanto aumenta il passo quando piu' prestazioni di fila confermano il
  /// miglioramento. Una domenica buona puo' essere fortuna; quattro di fila
  /// no, e a quel punto tenere l'indice basso vuol dire far allenare l'atleta
  /// troppo piano.
  static const double corroborationBonus = 0.25;
  static const int corroborationMaxSteps = 3;

  /// Dopo quanti giorni senza prove inizia il decadimento.
  static const int decayStartsAfterDays = 28;

  /// Punti persi ogni due settimane di inattivita' oltre la soglia.
  static const double decayPointsPerFortnight = 0.35;

  /// Massimo decadimento applicabile: oltre, la stima va rifatta da capo con
  /// una prova nuova, non estrapolata all'infinito.
  static const double maxDecayPoints = 6.0;

  /// Distanze su cui si cerca il tratto migliore dentro ogni corsa.
  static const List<double> segmentDistances = <double>[
    1500,
    3000,
    5000,
    10000,
    21097.5,
  ];

  // ------------------------------------------------------------------ pesi
  /// Peso legato all'eta' della prestazione.
  double ageWeight(int days) {
    if (days < 0) return 1.0;
    if (days > maxAgeDays) return 0.0;
    return math.pow(0.5, days / halfLifeDays).toDouble();
  }

  /// Peso legato alla distanza.
  double distanceWeight(double meters) {
    if (meters < minUsableMeters) return 0.0;
    if (meters >= fullWeightMeters) return 1.0;
    // Fra 1500 e 3000 si sale in modo lineare: la fiducia cresce con la
    // distanza invece di scattare da zero a uno.
    return 0.4 +
        0.6 * ((meters - minUsableMeters) / (fullWeightMeters - minUsableMeters));
  }

  /// Peso complessivo di una prestazione, da 0 a 1.
  double weightOf(PerformanceSample sample, {DateTime? now}) {
    final DateTime reference = now ?? DateTime.now();
    final int days = reference.difference(sample.date).inDays;
    final double w = sample.source.reliability *
        PerceivedEffort.reliabilityWeight(sample.rpe) *
        ageWeight(days) *
        distanceWeight(sample.meters);
    return w.clamp(0.0, 1.0);
  }

  // -------------------------------------------------------------- estrazione
  /// Ricava le prestazioni utilizzabili dallo storico delle attivita'.
  ///
  /// Per ogni corsa si cerca il tratto piu' veloce su ciascuna distanza
  /// standard che la corsa contiene. Non sono gare, ma sono la migliore
  /// evidenza disponibile a chi non ne fa.
  List<PerformanceSample> samplesFromActivities(
    List<RunningActivity> activities, {
    DateTime? now,
    RecordsService records = const RecordsService(),
  }) {
    final DateTime reference = now ?? DateTime.now();
    final List<PerformanceSample> out = <PerformanceSample>[];

    for (final RunningActivity activity in activities) {
      if (reference.difference(activity.startTime).inDays > maxAgeDays) {
        continue;
      }
      if (activity.route.length < 2) continue;

      final EstimateSource source = activity.type == ActivityType.workout
          ? EstimateSource.workout
          : EstimateSource.runSegment;

      for (final double meters in segmentDistances) {
        if (activity.distanceMeters < meters) continue;
        final int? seconds =
            records.fastestTimeForDistance(activity.route, meters);
        if (seconds == null || seconds <= 0) continue;

        out.add(PerformanceSample(
          meters: meters,
          seconds: seconds,
          date: activity.startTime,
          source: source,
          rpe: activity.rpe,
          activityId: activity.id,
          label: _distanceLabel(meters),
        ));
      }
    }

    return out;
  }

  /// Prestazioni ricavate dai personal best dichiarati nel profilo.
  List<PerformanceSample> samplesFromProfile(AthleteProfile profile) {
    final List<PerformanceSample> out = <PerformanceSample>[];
    for (final PersonalBest best in profile.personalBests) {
      if (best.meters < minUsableMeters || best.seconds <= 0) continue;
      out.add(PerformanceSample(
        meters: best.meters,
        seconds: best.seconds,
        // Un personal best senza data viene trattato come vecchio di un anno:
        // cosi' pesa poco invece di fingere di essere di ieri.
        date: best.date ?? DateTime.now().subtract(const Duration(days: 365)),
        source: best.source,
        label: '${_distanceLabel(best.meters)} (personale)',
      ));
    }
    return out;
  }

  // ---------------------------------------------------------------- stima
  /// Calcola l'indice di forma.
  RunIndexResult estimate(
    List<PerformanceSample> rawSamples, {
    DateTime? now,
  }) {
    final DateTime reference = now ?? DateTime.now();

    // 1. Converte ogni prestazione nel suo indice e le pesa.
    final List<WeightedSample> weighted = <WeightedSample>[];
    for (final PerformanceSample sample in rawSamples) {
      final double? raw =
          fitness.vdotFromPerformance(sample.meters, sample.seconds);
      if (raw == null) continue;
      final double w = weightOf(sample, now: reference);
      if (w <= 0.01) continue;
      weighted.add(WeightedSample(
        sample: sample,
        rawIndex: raw,
        weight: w,
        ageDays: reference.difference(sample.date).inDays,
      ));
    }

    // Una corsa e' una prova sola, non cinque. Dentro la stessa attivita' i
    // tratti da 1,5 / 3 / 5 / 10 km sono lo stesso sforzo guardato con lenti
    // diverse: tenerli tutti farebbe scattare la conferma ripetuta dentro una
    // singola uscita, che e' esattamente il contrario di quello che la
    // conferma deve significare.
    final List<WeightedSample> collapsed = _onePerActivity(weighted);

    if (weighted.isEmpty) {
      return RunIndexResult(
        index: null,
        samples: const <WeightedSample>[],
        speedIndex: null,
        enduranceIndex: null,
        profileBias: null,
        lastEvidence: null,
        decayPoints: 0,
        explanation: 'Non ci sono ancora prestazioni utilizzabili. Serve un '
            'tratto tirato di almeno 1,5 km con il GPS acceso, oppure un '
            'personale inserito a mano nel profilo.',
      );
    }

    // 2. Filtro sequenziale, dalla prestazione piu' vecchia alla piu' recente.
    final List<WeightedSample> byDate = List<WeightedSample>.from(collapsed)
      ..sort((WeightedSample a, WeightedSample b) =>
          a.sample.date.compareTo(b.sample.date));

    double current = byDate.first.rawIndex;
    int streak = 0;
    for (int i = 1; i < byDate.length; i++) {
      final WeightedSample s = byDate[i];
      final bool improving = s.rawIndex > current;
      streak = improving ? streak + 1 : 0;

      double gain = improving ? upGain : downGain;
      if (improving && streak > 1) {
        gain *= 1 +
            corroborationBonus *
                math.min(streak - 1, corroborationMaxSteps);
      }

      // Il limite per singola prestazione dipende da quanto e' affidabile.
      final double cap =
          maxUpStep * (0.6 + 0.4 * s.sample.source.reliability);

      final double delta = (s.rawIndex - current) * s.weight * gain;
      final double capped =
          improving ? math.min(delta, cap) : math.max(delta, -maxDownStep);
      current += capped;
    }

    // 3. Decadimento per inattivita'.
    final DateTime lastEvidence = byDate.last.sample.date;
    final int idleDays = reference.difference(lastEvidence).inDays;
    double decay = 0;
    if (idleDays > decayStartsAfterDays) {
      decay = (idleDays - decayStartsAfterDays) / 14.0 * decayPointsPerFortnight;
      decay = math.min(decay, maxDecayPoints);
      current -= decay;
    }
    if (current < 20) current = 20;

    // 4. Confidenza.
    final double confidence =
        _confidence(byDate, current, idleDays: idleDays);

    // 5. Spettro velocista - fondista.
    final double? speed = _weightedMean(byDate
        .where((WeightedSample s) => s.sample.meters < 5000)
        .toList());
    final double? endurance = _weightedMean(byDate
        .where((WeightedSample s) => s.sample.meters >= 10000)
        .toList());

    Estimate<double>? bias;
    if (speed != null && endurance != null) {
      // La confidenza dello spettro e' sempre piu' bassa di quella
      // dell'indice: serve piu' evidenza per dire "sei un fondista" che per
      // dire "vai a questo ritmo".
      bias = Estimate<double>(
        value: endurance - speed,
        confidence: (confidence * 0.6).clamp(0.05, 0.75),
        source: EstimateSource.derived,
        updatedAt: reference,
        note: _biasNote(endurance - speed),
      );
    }

    final List<WeightedSample> byWeight = List<WeightedSample>.from(collapsed)
      ..sort((WeightedSample a, WeightedSample b) =>
          b.weight.compareTo(a.weight));

    return RunIndexResult(
      index: Estimate<double>(
        value: double.parse(current.toStringAsFixed(2)),
        confidence: confidence,
        source: byWeight.first.sample.source,
        updatedAt: reference,
      ),
      samples: byWeight,
      speedIndex: speed,
      enduranceIndex: endurance,
      profileBias: bias,
      lastEvidence: lastEvidence,
      decayPoints: decay,
      explanation: _explain(
        best: byWeight.first,
        count: collapsed.length,
        confidence: confidence,
        decay: decay,
        idleDays: idleDays,
      ),
    );
  }

  /// Tiene una sola prestazione per attivita'.
  ///
  /// Quale? Fra i tratti abbastanza lunghi da contare pieno (dai 3 km) si
  /// tiene quello che esprime l'indice piu' alto: e' lo sforzo che meglio
  /// rappresenta cosa l'atleta sapeva fare quel giorno. Se la corsa era troppo
  /// corta per avere tratti pieni, si ripiega su quello di peso maggiore.
  ///
  /// Le prestazioni senza attivita' (i personali dichiarati a mano) restano
  /// tutte: sono prove distinte, non lo stesso sforzo.
  List<WeightedSample> _onePerActivity(List<WeightedSample> samples) {
    final Map<String, WeightedSample> best = <String, WeightedSample>{};
    final List<WeightedSample> standalone = <WeightedSample>[];

    for (final WeightedSample s in samples) {
      final String? key = s.sample.activityId;
      if (key == null) {
        standalone.add(s);
        continue;
      }

      final WeightedSample? current = best[key];
      if (current == null) {
        best[key] = s;
        continue;
      }

      final bool sFull = s.sample.meters >= fullWeightMeters;
      final bool currentFull = current.sample.meters >= fullWeightMeters;

      if (sFull && !currentFull) {
        best[key] = s;
      } else if (sFull == currentFull) {
        if (s.rawIndex > current.rawIndex) best[key] = s;
      }
    }

    return <WeightedSample>[...best.values, ...standalone];
  }

  // ------------------------------------------------------------- confidenza
  /// La confidenza nasce da tre cose: quanta evidenza c'e', quanto e'
  /// recente, e quanto le prestazioni sono d'accordo fra loro.
  double _confidence(
    List<WeightedSample> samples,
    double current, {
    required int idleDays,
  }) {
    double mass = 0;
    for (final WeightedSample s in samples) {
      mass += s.weight;
    }

    // Quanta evidenza: una sola prova pesante arriva a ~0,55, tre a ~0,90.
    // Non arriva mai a 1: non si e' mai certi.
    final double coverage = 1 - math.exp(-mass / 1.2);

    // Quanto e' recente: si dimezza ogni due mesi.
    final double recency = math.pow(0.5, idleDays / 60.0).toDouble();

    // Quanto sono d'accordo: si guarda la dispersione pesata attorno al
    // valore stimato. Prestazioni che si contraddicono abbassano la fiducia.
    double variance = 0;
    double weightSum = 0;
    for (final WeightedSample s in samples) {
      variance += s.weight * math.pow(s.rawIndex - current, 2).toDouble();
      weightSum += s.weight;
    }
    final double stdev =
        weightSum <= 0 ? 0 : math.sqrt(variance / weightSum);
    final double agreement = 1 / (1 + stdev / 2.5);

    final double value =
        coverage * (0.40 + 0.60 * recency) * agreement;
    return value.clamp(0.05, 0.92);
  }

  double? _weightedMean(List<WeightedSample> samples) {
    if (samples.isEmpty) return null;
    double sum = 0;
    double weights = 0;
    for (final WeightedSample s in samples) {
      sum += s.rawIndex * s.weight;
      weights += s.weight;
    }
    if (weights <= 0) return null;
    return sum / weights;
  }

  String _biasNote(double bias) {
    if (bias > 1.5) {
      return 'Tieni meglio sulle distanze lunghe che sulle brevi.';
    }
    if (bias < -1.5) {
      return 'Vai piu\' forte sulle distanze brevi che sulle lunghe.';
    }
    return 'Sei equilibrato fra brevi e lunghe.';
  }

  String _explain({
    required WeightedSample best,
    required int count,
    required double confidence,
    required double decay,
    required int idleDays,
  }) {
    final StringBuffer buffer = StringBuffer();
    buffer.write('Calcolato su $count ');
    buffer.write(count == 1 ? 'prestazione' : 'prestazioni');
    buffer.write('. La piu\' significativa e\' ');
    buffer.write(best.sample.label ?? _distanceLabel(best.sample.meters));
    if (best.ageDays <= 1) {
      buffer.write(' di oggi');
    } else if (best.ageDays < 14) {
      buffer.write(' di ${best.ageDays} giorni fa');
    } else {
      buffer.write(' di ${(best.ageDays / 7).round()} settimane fa');
    }
    buffer.write('. ');

    if (decay > 0.05) {
      buffer.write('Tolti ${decay.toStringAsFixed(1)} punti perche\' sono '
          'passati $idleDays giorni dall\'ultima prova. ');
    }

    if (confidence < Estimate.low) {
      buffer.write('Fiducia bassa: i ritmi sono volutamente larghi finche\' '
          'non ci sono piu\' dati.');
    } else if (confidence < Estimate.good) {
      buffer.write('Fiducia media.');
    } else {
      buffer.write('Fiducia buona.');
    }
    return buffer.toString();
  }

  static String _distanceLabel(double meters) {
    if (meters >= 42000) return 'maratona';
    if (meters >= 21000) return 'mezza maratona';
    if (meters >= 1000) {
      final double km = meters / 1000.0;
      final String text =
          km == km.roundToDouble() ? km.round().toString() : km.toStringAsFixed(1);
      return '$text km';
    }
    return '${meters.round()} m';
  }
}
