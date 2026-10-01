import '../models/daily_checkin.dart';
import '../models/running_activity.dart';
import 'session_classifier.dart';
import 'training_load_engine.dart';

/// Quanto sei pronto oggi, da 0 a 100.
enum ReadinessBand { rest, easy, normal, ready }

extension ReadinessBandInfo on ReadinessBand {
  String get label {
    switch (this) {
      case ReadinessBand.rest:
        return 'Riposo';
      case ReadinessBand.easy:
        return 'Solo facile';
      case ReadinessBand.normal:
        return 'Normale';
      case ReadinessBand.ready:
        return 'Pronto';
    }
  }

  /// Se oggi ha senso fare una seduta di qualita'.
  bool get allowsQuality =>
      this == ReadinessBand.ready || this == ReadinessBand.normal;
}

/// Il risultato: un numero, una fascia, e il perche'.
class Readiness {
  const Readiness({
    required this.score,
    required this.band,
    required this.reasons,
    required this.confidence,
    required this.blockedByPain,
  });

  /// Da 0 a 100.
  final int score;

  final ReadinessBand band;

  /// I motivi che hanno spostato il punteggio, dal piu' pesante al meno.
  /// E' il punto: un numero senza i suoi motivi non si puo' contestare.
  final List<String> reasons;

  final double confidence;

  /// `true` se il punteggio e' stato tenuto basso da un dolore dichiarato.
  final bool blockedByPain;

  String get confidenceLabel {
    if (confidence >= 0.6) return 'buona';
    if (confidence >= 0.3) return 'media';
    return 'debole';
  }
}

/// Decide quanto sei pronto, e lo spiega.
///
/// DA COSA NASCE IL NUMERO
/// -----------------------
/// Da quattro cose, e nessuna vale da sola:
///
/// 1. **La freschezza** - quanto carico stai portando rispetto al tuo
///    abituale. Viene dal TrainingLoadEngine.
/// 2. **Il check-in del mattino** - sonno, gambe, voglia.
/// 3. **Quanto e' passato dall'ultima seduta dura** - due giorni forti
///    attaccati non sono due allenamenti, sono un allenamento e un danno.
/// 4. **Il dolore** - che non e' un punteggio: e' un interruttore.
///
/// PERCHE' IL DOLORE NON SI SOMMA
/// ------------------------------
/// Se il dolore fosse una voce come le altre, un punteggio alto altrove lo
/// potrebbe compensare: hai dormito benissimo, sei fresco, quindi vai a fare
/// le ripetute anche se il ginocchio tira. E' esattamente lo scenario che
/// questo motore deve rendere impossibile. Il dolore porta il punteggio nella
/// fascia "solo facile" o sotto, e nessun altro segnale lo puo' rialzare.
///
/// CON POCHI DATI
/// --------------
/// La freschezza ha bisogno di settimane. Finche' non ce ne sono, pesa meno e
/// il check-in pesa di piu' - ed e' dichiarato nella confidenza. Meglio un
/// numero onesto e incerto che un numero preciso e finto.
class ReadinessEngine {
  const ReadinessEngine();

  /// Quanto pesano le voci, quando ci sono tutte.
  /// VALORI EMPIRICI, TARABILI.
  static const double weightFreshness = 0.45;
  static const double weightCheckIn = 0.40;
  static const double weightRecovery = 0.15;

  /// Il punteggio massimo consentito quando c'e' dolore dichiarato.
  static const int painCeiling = 35;

  /// Ore entro cui una seduta di qualita' pesa ancora sulle gambe.
  static const int qualityShadowHours = 48;

  Readiness compute({
    required TrainingLoadState load,
    DailyCheckIn? checkIn,
    DateTime? lastQualityAt,
    DateTime? now,
  }) {
    final DateTime reference = now ?? DateTime.now();
    final List<String> motivi = <String>[];

    // ------------------------------------------------------- 1. freschezza
    // Si normalizza il rapporto carico recente / carico abituale. A 1,0
    // (carico come il solito) vale 0,5; sotto 0,8 e' riposo pieno; sopra
    // 1,35 e' la zona in cui ci si fa male.
    double? frescoNorm;
    final double? ratio = load.loadRatio;
    if (ratio != null && load.isReliable) {
      frescoNorm = ((1.45 - ratio) / 0.7).clamp(0.0, 1.0);
      if (ratio >= 1.35) {
        motivi.add('Il carico delle ultime settimane e\' molto sopra il tuo '
            'abituale');
      } else if (ratio >= 1.15) {
        motivi.add('Stai portando piu\' carico del solito');
      } else if (ratio <= 0.8) {
        motivi.add('Sei scarico: il carico recente e\' sotto il tuo abituale');
      }
    }

    // ---------------------------------------------------------- 2. check-in
    double? checkNorm;
    if (checkIn != null) {
      checkNorm = checkIn.normalised;
      if (checkIn.legs <= 2) {
        motivi.add('Hai dichiarato gambe pesanti');
      } else if (checkIn.legs >= 5) {
        motivi.add('Hai dichiarato gambe ottime');
      }
      if (checkIn.sleep <= 2) motivi.add('Hai dormito male');
      if (checkIn.motivation <= 2) motivi.add('Poca voglia di correre');
    }

    // --------------------------------------------------------- 3. recupero
    double recuperoNorm = 1.0;
    if (lastQualityAt != null) {
      final int ore = reference.difference(lastQualityAt).inHours;
      if (ore < 0) {
        recuperoNorm = 1.0;
      } else if (ore >= qualityShadowHours) {
        recuperoNorm = 1.0;
      } else {
        recuperoNorm = (ore / qualityShadowHours).clamp(0.0, 1.0);
        if (ore < 24) {
          motivi.add('Ieri hai fatto una seduta di qualita\'');
        } else {
          motivi.add('La seduta dura e\' di due giorni fa');
        }
      }
    }

    // ------------------------------------------------- media di quelle che ci sono
    double somma = 0;
    double pesi = 0;
    if (frescoNorm != null) {
      somma += frescoNorm * weightFreshness;
      pesi += weightFreshness;
    }
    if (checkNorm != null) {
      somma += checkNorm * weightCheckIn;
      pesi += weightCheckIn;
    }
    somma += recuperoNorm * weightRecovery;
    pesi += weightRecovery;

    // SENZA NIENTE DA CUI PARTIRE
    //
    // Il recupero c'e' sempre (vale 1 se non hai fatto niente di duro di
    // recente), quindi la media pesata da sola darebbe 100 su 100 a chi ha
    // appena installato l'app: massima prontezza perche' non si sa niente.
    // E' l'oracolo che tutto il resto dell'app evita.
    //
    // Ma fermarsi a un 55 fisso era sbagliato all'opposto, e si vedeva in
    // Home: la card scriveva "ieri hai fatto una seduta di qualita'" come
    // motivo principale di un numero che quel fatto non aveva spostato di un
    // punto. Una causa che non e' una causa.
    //
    // Quindi: senza carico e senza check-in si parte da 55 - non si sa
    // niente, e "normale" e' l'unica risposta onesta - e l'unica cosa che
    // puo' muoverlo e' una seduta dura recente, che puo' solo abbassarlo.
    // Sapere che ieri hai tirato e' poco, ma non e' niente.
    final double norm;
    if (frescoNorm == null && checkNorm == null) {
      norm = 0.55 - 0.25 * (1 - recuperoNorm);
    } else {
      norm = somma / pesi;
    }
    int punteggio = (norm * 100).round().clamp(0, 100);

    // ----------------------------------------------------------- 4. dolore
    final bool dolore = checkIn?.hasPain ?? false;
    if (dolore) {
      punteggio = punteggio > painCeiling ? painCeiling : punteggio;
      motivi.insert(
        0,
        'Hai dichiarato un dolore: finche\' c\'e\', niente qualita\'. '
        'Nessun altro segnale lo puo\' compensare.',
      );
    }

    if (motivi.isEmpty) {
      motivi.add('Niente di storto: carico, gambe e recupero sono nella norma');
    }

    // ---------------------------------------------------------- confidenza
    double confidenza = 0.25;
    if (load.isReliable) confidenza += 0.4;
    if (checkIn != null) confidenza += 0.25;
    if (load.historyDays >= 14) confidenza += 0.1;
    confidenza = confidenza.clamp(0.0, 0.95);

    if (!load.isReliable) {
      motivi.add('So ancora poco del tuo carico abituale: servono circa '
          'quattro settimane di corse registrate');
    }
    if (checkIn == null) {
      motivi.add('Senza il check-in di stamattina il numero vale meno');
    }

    return Readiness(
      score: punteggio,
      band: _band(punteggio, dolore),
      reasons: motivi,
      confidence: confidenza,
      blockedByPain: dolore,
    );
  }

  ReadinessBand _band(int score, bool pain) {
    if (pain) return score <= 25 ? ReadinessBand.rest : ReadinessBand.easy;
    if (score >= 70) return ReadinessBand.ready;
    if (score >= 50) return ReadinessBand.normal;
    if (score >= 30) return ReadinessBand.easy;
    return ReadinessBand.rest;
  }

  /// Quando e' stata l'ultima seduta di qualita' davvero corsa.
  ///
  /// "Davvero" e' la parola importante: non quella che c'era sul programma,
  /// ma quella che il classificatore ha riconosciuto come dura guardando i
  /// passi. Un facile corso forte conta; una qualita' corsa piano no.
  DateTime? lastQuality(
    List<RunningActivity> activities,
    SessionAnalysis? Function(RunningActivity) analyse,
  ) {
    DateTime? ultima;
    for (final RunningActivity a in activities) {
      final SessionAnalysis? analisi = analyse(a);
      if (analisi == null) continue;
      if (!analisi.intensity.countsAsQuality) continue;
      if (ultima == null || a.startTime.isAfter(ultima)) {
        ultima = a.startTime;
      }
    }
    return ultima;
  }
}
