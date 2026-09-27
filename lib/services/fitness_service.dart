import 'dart:math' as math;

import '../models/workout_step.dart';
import 'records_service.dart';

/// Stima della forma attuale e di tutto quello che se ne ricava: i passi di
/// allenamento e le previsioni sulle gare.
///
/// DA DOVE VIENE IL NUMERO
/// -----------------------
/// Il metodo e' quello di Jack Daniels (VDOT). Da una singola prestazione si
/// ricava un indice di forma, e da quell'indice si ricavano tutte le altre
/// prestazioni equivalenti: se corri 5 km in venti minuti, il tuo VDOT e' 50,
/// e un VDOT 50 corrisponde a 41:20 sui 10 km e a 3:10 in maratona.
///
/// Le due formule sotto sono quelle pubblicate da Daniels e Gilbert: una dice
/// quanto ossigeno costa correre a una certa velocita', l'altra quale
/// percentuale del massimo si riesce a tenere per una certa durata. Il VDOT e'
/// il rapporto fra le due.
///
/// I PASSI DI ALLENAMENTO
/// ----------------------
/// Non sono percentuali inventate: ognuno e' il passo di una gara equivalente,
/// che e' anche il modo in cui si spiegano a parole.
///  - medio (M): il passo della tua maratona;
///  - soglia (T): il passo che terresti per un'ora esatta;
///  - ripetute (I): il passo dei tuoi 3000 metri;
///  - veloci (R): il passo dei tuoi 1500 metri;
///  - lento (E): ricavato dal costo di ossigeno, fra il 55% e il 62% del VDOT.
///
/// LIMITI, DETTI CHIARAMENTE
/// -------------------------
/// La stima nasce dal tratto piu' veloce registrato, non da una gara vera. Se
/// quel tratto non era tirato al massimo, il VDOT e' piu' basso del reale. E
/// una previsione di maratona ricavata da 5 km resta una previsione: dice cosa
/// permette il tuo motore, non se hai fatto i chilometri per arrivare in
/// fondo. Per questo ogni previsione porta con se' un margine, che si allarga
/// man mano che ci si allontana dalla distanza di partenza.
class FitnessService {
  const FitnessService();

  /// Distanza minima perche' un tratto valga come misura della forma.
  ///
  /// Sotto i 3 km il risultato e' troppo sensibile a uno sprint fortunato in
  /// discesa o a un errore del GPS, e finirebbe per gonfiare tutti i passi di
  /// allenamento.
  static const double minReliableMeters = 3000;

  /// Un tratto piu' vecchio di questo non descrive piu' la forma di adesso.
  static const int freshnessDays = 120;

  /// Percentuale del massimo consumo di ossigeno sostenibile per una durata
  /// data, in minuti (Daniels-Gilbert).
  double percentOfMax(double minutes) {
    if (minutes <= 0) return 1.0;
    return 0.8 +
        0.1894393 * math.exp(-0.012778 * minutes) +
        0.2989558 * math.exp(-0.1932605 * minutes);
  }

  /// Ossigeno consumato correndo a [metersPerMinute] (Daniels-Gilbert).
  double oxygenCost(double metersPerMinute) {
    return -4.60 +
        0.182258 * metersPerMinute +
        0.000104 * metersPerMinute * metersPerMinute;
  }

  /// Velocita' (m/min) che corrisponde a un dato consumo di ossigeno.
  ///
  /// E' l'inversa di [oxygenCost], risolta come equazione di secondo grado.
  double velocityForOxygen(double oxygen) {
    const double a = 0.000104;
    const double b = 0.182258;
    final double c = -(4.60 + oxygen);
    final double disc = b * b - 4 * a * c;
    if (disc <= 0) return 0;
    return (-b + math.sqrt(disc)) / (2 * a);
  }

  /// VDOT ricavato da una prestazione. `null` se i dati non sono usabili.
  double? vdotFromPerformance(double meters, int seconds) {
    if (meters < 400 || seconds <= 0) return null;
    final double minutes = seconds / 60.0;
    final double velocity = meters / minutes;
    final double pct = percentOfMax(minutes);
    if (pct <= 0) return null;
    final double vdot = oxygenCost(velocity) / pct;
    if (!vdot.isFinite || vdot <= 0 || vdot > 100) return null;
    return vdot;
  }

  /// Tempo previsto su una distanza, per un dato VDOT.
  ///
  /// Si cerca per bisezione il tempo in cui l'ossigeno richiesto dalla
  /// velocita' media coincide con quello disponibile per quella durata.
  int? predictSeconds(double vdot, double meters) {
    if (vdot <= 0 || meters < 400) return null;
    double low = 1.0;
    double high = 60000.0;
    for (int i = 0; i < 80; i++) {
      final double mid = (low + high) / 2;
      final double velocity = meters / (mid / 60.0);
      if (oxygenCost(velocity) > vdot * percentOfMax(mid / 60.0)) {
        // Troppo veloce per essere sostenibile: serve piu' tempo.
        low = mid;
      } else {
        high = mid;
      }
    }
    final int seconds = ((low + high) / 2).round();
    return seconds > 0 ? seconds : null;
  }

  /// Distanza che si copre in un tempo dato: l'inversa di [predictSeconds].
  double? distanceForDuration(double vdot, int seconds) {
    if (vdot <= 0 || seconds <= 0) return null;
    double low = 100.0;
    double high = 100000.0;
    for (int i = 0; i < 80; i++) {
      final double mid = (low + high) / 2;
      final int? time = predictSeconds(vdot, mid);
      if (time == null) return null;
      if (time < seconds) {
        low = mid;
      } else {
        high = mid;
      }
    }
    return (low + high) / 2;
  }

  /// I cinque passi di allenamento per un dato VDOT.
  TrainingPaces? pacesFor(double vdot) {
    if (vdot <= 0) return null;

    final int? marathon = predictSeconds(vdot, 42195);
    final double? hourDistance = distanceForDuration(vdot, 3600);
    final int? threeK = predictSeconds(vdot, 3000);
    final int? fifteenHundred = predictSeconds(vdot, 1500);
    if (marathon == null ||
        hourDistance == null ||
        hourDistance <= 0 ||
        threeK == null ||
        fifteenHundred == null) {
      return null;
    }

    final double easySlow = easyPaceSlowest(vdot);
    final double easyFast = easyPaceFastest(vdot);
    if (easySlow <= 0 || easyFast <= 0) return null;

    return TrainingPaces(
      easy: TrainingPace(
        key: 'E',
        label: 'Lento',
        description: 'La base di tutto: deve restare una conversazione.',
        secondsPerKm: (easyFast + easySlow) / 2,
        fastestSecPerKm: easyFast,
        slowestSecPerKm: easySlow,
      ),
      marathon: _band(
        key: 'M',
        label: 'Medio',
        description: 'Il passo della tua maratona.',
        pace: marathon / 42.195,
      ),
      threshold: _band(
        key: 'T',
        label: 'Soglia',
        description: 'Il passo che terresti per un\'ora esatta.',
        pace: 3600.0 / (hourDistance / 1000.0),
      ),
      interval: _band(
        key: 'I',
        label: 'Ripetute',
        description: 'Il passo dei tuoi 3000 metri.',
        pace: threeK / 3.0,
      ),
      repetition: _band(
        key: 'R',
        label: 'Veloci',
        description: 'Il passo dei tuoi 1500 metri.',
        pace: fifteenHundred / 1.5,
      ),
    );
  }

  double _paceFromOxygenFraction(double vdot, double fraction) {
    final double velocity = velocityForOxygen(fraction * vdot);
    if (velocity <= 0) return 0;
    return 1000.0 / velocity * 60.0;
  }

  /// A che frazione del proprio consumo massimo si corre il lento.
  ///
  /// PERCHE' NON E' UN NUMERO FISSO
  /// ------------------------------
  /// La prima versione usava due frazioni fisse (0,55 e 0,62) per tutti. Il
  /// risultato: per un atleta da indice 36 il lento usciva mezzo minuto al
  /// chilometro piu' lento del dovuto, mentre per uno da indice 65 era
  /// giusto. Non era un errore di arrotondamento, era il modello sbagliato.
  ///
  /// Il motivo e' fisiologico: piu' uno e' allenato, piu' il suo lento e'
  /// una percentuale BASSA del suo massimo. Un principiante che corre piano
  /// sta gia' al 72% del suo consumo; un atleta evoluto allo stesso sforzo
  /// percepito sta al 62%. Il lento non e' "una percentuale", e' "lo sforzo
  /// che puoi sostenere chiacchierando", e quella percentuale cambia.
  ///
  /// I due coefficienti sono ricavati per regressione dai passi lenti della
  /// tabella di Daniels fra indice 30 e 65: lo scarto medio e' di 2,5
  /// secondi al chilometro, il massimo di 5. Fuori da quell'intervallo la
  /// retta viene tagliata, per non estrapolare all'infinito.
  ///
  /// [fast] sceglie l'estremo veloce della fascia invece di quello lento.
  double easyOxygenFraction(double vdot, {required bool fast}) {
    if (fast) {
      final double raw = 0.812 - 0.00291 * vdot;
      if (raw < 0.50) return 0.50;
      if (raw > 0.78) return 0.78;
      return raw;
    }
    final double raw = 0.712 - 0.00254 * vdot;
    if (raw < 0.45) return 0.45;
    if (raw > 0.70) return 0.70;
    return raw;
  }

  /// Estremo veloce della fascia del lento, in secondi al chilometro.
  double easyPaceFastest(double vdot) =>
      _paceFromOxygenFraction(vdot, easyOxygenFraction(vdot, fast: true));

  /// Estremo lento della fascia del lento, in secondi al chilometro.
  double easyPaceSlowest(double vdot) =>
      _paceFromOxygenFraction(vdot, easyOxygenFraction(vdot, fast: false));

  /// Costruisce un passo con una banda di tolleranza stretta ma umana.
  ///
  /// Quattro secondi piu' veloce e sei ancora nel giusto; sei piu' lento
  /// anche. La banda e' asimmetrica di proposito: nelle sedute di qualita'
  /// andare troppo forte rovina la seduta piu' che andare un po' piano.
  TrainingPace _band({
    required String key,
    required String label,
    required String description,
    required double pace,
  }) {
    return TrainingPace(
      key: key,
      label: label,
      description: description,
      secondsPerKm: pace,
      fastestSecPerKm: pace - 4,
      slowestSecPerKm: pace + 6,
    );
  }

  /// Distanze su cui l'app fa le previsioni.
  static const List<RecordDistance> predictionDistances = <RecordDistance>[
    RecordDistance(key: '5k', label: '5 km', meters: 5000),
    RecordDistance(key: '10k', label: '10 km', meters: 10000),
    RecordDistance(key: 'half', label: 'Mezza maratona', meters: 21097.5),
    RecordDistance(key: 'marathon', label: 'Maratona', meters: 42195),
  ];

  /// Previsioni di gara, con il margine che si allarga allontanandosi dalla
  /// distanza su cui la stima e' stata fatta.
  List<RacePrediction> predictions(double vdot, double sourceMeters) {
    final List<RacePrediction> out = <RacePrediction>[];
    for (final RecordDistance distance in predictionDistances) {
      final int? seconds = predictSeconds(vdot, distance.meters);
      if (seconds == null) continue;

      // Ogni raddoppio di distanza rispetto alla misura di partenza aggiunge
      // incertezza: un'ora e mezza di gara dipende da cose che un tratto di
      // cinque minuti non puo' sapere.
      double doublings = 0;
      if (sourceMeters > 0 && distance.meters > sourceMeters) {
        doublings = math.log(distance.meters / sourceMeters) / math.ln2;
      }
      double margin = 0.015 + 0.015 * doublings;
      if (margin > 0.08) margin = 0.08;

      out.add(RacePrediction(
        distance: distance,
        seconds: seconds,
        // Piu' facile andare piu' piano del previsto che piu' veloce, quindi
        // il margine verso il lento e' il doppio.
        bestCaseSeconds: (seconds * (1 - margin)).round(),
        worstCaseSeconds: (seconds * (1 + 2 * margin)).round(),
        marginPercent: margin * 100,
      ));
    }
    return out;
  }

  /// Stima completa a partire dai record personali.
  ///
  /// Si prende il VDOT piu' alto fra i record abbastanza lunghi e abbastanza
  /// recenti. Il piu' alto e non la media: la forma e' quello che sai fare
  /// quando spingi, non quello che fai in media.
  /// Non restituisce mai `null`: quando la stima non si puo' fare torna una
  /// stima vuota, che sa spiegare perche' (vedi [FitnessEstimate.isEmpty] e
  /// [FitnessEstimate.missingReason]).
  FitnessEstimate estimateFromRecords(
    PersonalRecords records, {
    DateTime? now,
  }) {
    final DateTime reference = now ?? DateTime.now();

    DistanceRecord? bestRecord;
    double bestVdot = 0;
    bool ignoredForAge = false;

    for (final DistanceRecord record in records.byDistance) {
      if (record.distance.meters < minReliableMeters) continue;

      final double? vdot =
          vdotFromPerformance(record.distance.meters, record.seconds);
      if (vdot == null) continue;

      if (reference.difference(record.date).inDays > freshnessDays) {
        ignoredForAge = true;
        continue;
      }

      if (vdot > bestVdot) {
        bestVdot = vdot;
        bestRecord = record;
      }
    }

    if (bestRecord == null || bestVdot <= 0) {
      return FitnessEstimate.empty(
        hasOldRecords: ignoredForAge,
        hasAnyRecord: records.byDistance.isNotEmpty,
      );
    }

    final TrainingPaces? paces = pacesFor(bestVdot);
    if (paces == null) {
      return FitnessEstimate.empty(
        hasOldRecords: ignoredForAge,
        hasAnyRecord: true,
      );
    }

    return FitnessEstimate(
      vdot: bestVdot,
      paces: paces,
      predictions: predictions(bestVdot, bestRecord.distance.meters),
      sourceLabel: bestRecord.distance.label,
      sourceMeters: bestRecord.distance.meters,
      sourceSeconds: bestRecord.seconds,
      sourceDate: bestRecord.date,
      sourceActivityId: bestRecord.activityId,
      hasOldRecords: ignoredForAge,
      hasAnyRecord: true,
    );
  }
}

/// Un passo di allenamento, con la sua banda.
class TrainingPace {
  const TrainingPace({
    required this.key,
    required this.label,
    required this.description,
    required this.secondsPerKm,
    required this.fastestSecPerKm,
    required this.slowestSecPerKm,
  });

  /// Sigla di Daniels: E, M, T, I, R.
  final String key;

  final String label;
  final String description;

  /// Passo centrale, in secondi per chilometro.
  final double secondsPerKm;

  final double fastestSecPerKm;
  final double slowestSecPerKm;

  /// Lo stesso passo nella forma che usa il motore degli allenamenti.
  PaceTarget get target => PaceTarget(
        fastestSecPerKm: fastestSecPerKm,
        slowestSecPerKm: slowestSecPerKm,
      );
}

/// I cinque passi di allenamento.
class TrainingPaces {
  const TrainingPaces({
    required this.easy,
    required this.marathon,
    required this.threshold,
    required this.interval,
    required this.repetition,
  });

  final TrainingPace easy;
  final TrainingPace marathon;
  final TrainingPace threshold;
  final TrainingPace interval;
  final TrainingPace repetition;

  /// Dal piu' lento al piu' veloce.
  List<TrainingPace> get all => <TrainingPace>[
        easy,
        marathon,
        threshold,
        interval,
        repetition,
      ];
}

/// Previsione su una distanza di gara.
class RacePrediction {
  const RacePrediction({
    required this.distance,
    required this.seconds,
    required this.bestCaseSeconds,
    required this.worstCaseSeconds,
    required this.marginPercent,
  });

  final RecordDistance distance;

  /// Tempo previsto.
  final int seconds;

  final int bestCaseSeconds;
  final int worstCaseSeconds;

  /// Ampiezza del margine, in percento: serve a dirlo all'utente.
  final double marginPercent;

  /// Passo previsto, in secondi per chilometro.
  double get paceSecPerKm => seconds / (distance.meters / 1000.0);
}

/// Il risultato completo: forma, passi, previsioni e da dove vengono.
class FitnessEstimate {
  const FitnessEstimate({
    required this.vdot,
    required this.paces,
    required this.predictions,
    required this.sourceLabel,
    required this.sourceMeters,
    required this.sourceSeconds,
    required this.sourceDate,
    required this.sourceActivityId,
    required this.hasOldRecords,
    required this.hasAnyRecord,
  });

  const FitnessEstimate.empty({
    required this.hasOldRecords,
    required this.hasAnyRecord,
  })  : vdot = 0,
        paces = null,
        predictions = const <RacePrediction>[],
        sourceLabel = '',
        sourceMeters = 0,
        sourceSeconds = 0,
        sourceDate = null,
        sourceActivityId = null;

  /// Indice di forma. 0 se non calcolabile.
  final double vdot;

  final TrainingPaces? paces;
  final List<RacePrediction> predictions;

  /// Su quale record e' stata fatta la stima.
  final String sourceLabel;
  final double sourceMeters;
  final int sourceSeconds;
  final DateTime? sourceDate;
  final String? sourceActivityId;

  /// `true` se esistono record ma sono tutti troppo vecchi.
  final bool hasOldRecords;

  /// `true` se esiste almeno un record, di qualunque distanza.
  final bool hasAnyRecord;

  bool get isEmpty => vdot <= 0 || paces == null;

  /// Spiegazione in una riga del perche' la stima manca.
  String get missingReason {
    if (!hasAnyRecord) {
      return 'Serve almeno una corsa con tracciato GPS.';
    }
    if (hasOldRecords) {
      return 'I tuoi record hanno piu\' di quattro mesi: non descrivono piu\' '
          'la forma di adesso. Basta una corsa tirata per aggiornare la stima.';
    }
    return 'Serve un tratto tirato di almeno 3 km. Sotto quella distanza la '
        'stima sarebbe troppo sensibile a uno sprint fortunato.';
  }
}
