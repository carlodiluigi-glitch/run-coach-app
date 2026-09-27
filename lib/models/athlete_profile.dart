/// Chi e' il corridore.
///
/// COSA SERVE E COSA NON SERVE
/// ---------------------------
/// Eta', peso e altezza **non** entrano nel calcolo dei ritmi. I ritmi si
/// ricavano da quello che l'atleta ha davvero corso: una formula che stima la
/// velocita' dal peso direbbe a due persone con la stessa prestazione di
/// allenarsi a ritmi diversi, il che e' semplicemente falso.
///
/// Questi dati servono invece a decidere **quanto in fretta caricare**: a
/// parita' di prestazione, un cinquantenne che corre da un anno recupera piu'
/// lentamente di un venticinquenne che corre da dieci. Cambia la progressione,
/// non il passo.
library;

import 'estimate.dart';

/// Sesso biologico. Facoltativo: serve solo alla stima della frequenza
/// cardiaca massima quando non e' misurata, e a niente altro.
enum AthleteSex { unspecified, female, male }

extension AthleteSexInfo on AthleteSex {
  String get label {
    switch (this) {
      case AthleteSex.unspecified:
        return 'Preferisco non dirlo';
      case AthleteSex.female:
        return 'Femmina';
      case AthleteSex.male:
        return 'Maschio';
    }
  }

  String get storageKey => name;

  static AthleteSex fromStorage(String? value) {
    for (final AthleteSex s in AthleteSex.values) {
      if (s.name == value) return s;
    }
    return AthleteSex.unspecified;
  }
}

/// Un personal best dichiarato dall'atleta.
class PersonalBest {
  const PersonalBest({
    required this.meters,
    required this.seconds,
    this.date,
    this.wasRace = true,
  });

  final double meters;
  final int seconds;

  /// Quando e' stato fatto. Se manca viene trattato come vecchio, quindi
  /// conta poco: meglio prudenti che ottimisti.
  final DateTime? date;

  /// `true` se in gara. Una prestazione in allenamento vale meno.
  final bool wasRace;

  EstimateSource get source =>
      wasRace ? EstimateSource.race : EstimateSource.timeTrial;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'meters': meters,
        'seconds': seconds,
        'date': date?.toIso8601String(),
        'wasRace': wasRace,
      };

  factory PersonalBest.fromJson(Map<String, dynamic> json) => PersonalBest(
        meters: (json['meters'] as num?)?.toDouble() ?? 0,
        seconds: (json['seconds'] as num?)?.toInt() ?? 0,
        date: DateTime.tryParse(json['date'] as String? ?? ''),
        wasRace: json['wasRace'] as bool? ?? true,
      );
}

/// Il profilo dell'atleta.
class AthleteProfile {
  const AthleteProfile({
    this.birthYear,
    this.sex = AthleteSex.unspecified,
    this.heightCm,
    this.weightKg,
    this.runningYears,
    this.availableDays = 4,
    this.restingHeartRate,
    this.maxHeartRate,
    this.inactiveSinceWeeks,
    this.personalBests = const <PersonalBest>[],
  });

  final int? birthYear;
  final AthleteSex sex;
  final double? heightCm;
  final double? weightKg;

  /// Da quanti anni corre con continuita'.
  final int? runningYears;

  /// Giorni a settimana in cui puo' allenarsi.
  final int availableDays;

  final int? restingHeartRate;
  final int? maxHeartRate;

  /// Settimane di stop recente, se c'e' stato.
  final int? inactiveSinceWeeks;

  final List<PersonalBest> personalBests;

  int? get age {
    final int? year = birthYear;
    if (year == null || year < 1900) return null;
    final int value = DateTime.now().year - year;
    return (value >= 5 && value <= 110) ? value : null;
  }

  bool get hasBasics => birthYear != null && runningYears != null;

  /// Frequenza cardiaca massima stimata, quando non e' misurata.
  ///
  /// Formula di Tanaka (208 - 0.7 x eta'), piu' accurata della vecchia
  /// "220 meno l'eta'" soprattutto sopra i quarant'anni. Resta comunque una
  /// stima con un margine di dieci-dodici battiti: per questo la confidenza
  /// e' bassa e il motore non ci costruisce sopra decisioni importanti.
  Estimate<int>? get estimatedMaxHeartRate {
    final int? measured = maxHeartRate;
    if (measured != null && measured > 120) {
      return Estimate<int>(
        value: measured,
        confidence: 0.9,
        source: EstimateSource.userEntered,
        updatedAt: DateTime.now(),
      );
    }
    final int? years = age;
    if (years == null) return null;
    return Estimate<int>(
      value: (208 - 0.7 * years).round(),
      confidence: 0.3,
      source: EstimateSource.derived,
      updatedAt: DateTime.now(),
      note: 'Stimata dall\'eta\': puo\' sbagliare di dieci battiti.',
    );
  }

  /// Quanto in fretta questo atleta puo' aumentare il carico, da 0 a 1.
  ///
  /// COME SI LEGGE
  /// 1.0 = puo' seguire la progressione piena
  /// 0.5 = meta' della progressione
  ///
  /// I fattori sono quelli con letteratura alle spalle: l'eta' allunga i
  /// tempi di recupero, gli anni di corsa costruiscono tolleranza al carico
  /// (tessuti, tendini, ossa), e uno stop recente azzera parte di quella
  /// tolleranza.
  ///
  /// VALORI EMPIRICI, TARABILI. Sono volutamente prudenti: sbagliare per
  /// eccesso di cautela costa qualche settimana, sbagliare per eccesso di
  /// entusiasmo costa un infortunio.
  double get loadToleranceFactor {
    double factor = 1.0;

    final int? years = age;
    if (years != null) {
      if (years >= 60) {
        factor *= 0.75;
      } else if (years >= 50) {
        factor *= 0.85;
      } else if (years >= 40) {
        factor *= 0.93;
      }
    }

    final int? experience = runningYears;
    if (experience != null) {
      if (experience < 1) {
        factor *= 0.70;
      } else if (experience < 3) {
        factor *= 0.85;
      } else if (experience >= 8) {
        factor *= 1.05;
      }
    } else {
      // Senza sapere da quanto corre si resta prudenti.
      factor *= 0.85;
    }

    final int? stop = inactiveSinceWeeks;
    if (stop != null && stop > 0) {
      if (stop >= 8) {
        factor *= 0.60;
      } else if (stop >= 4) {
        factor *= 0.75;
      } else if (stop >= 2) {
        factor *= 0.90;
      }
    }

    return factor.clamp(0.45, 1.10);
  }

  /// Spiegazione a parole del fattore sopra, per l'interfaccia.
  String get loadToleranceExplanation {
    final List<String> reasons = <String>[];
    final int? years = age;
    if (years != null && years >= 40) {
      reasons.add('a $years anni il recupero e\' piu\' lento');
    }
    final int? experience = runningYears;
    if (experience == null) {
      reasons.add('non so da quanto corri');
    } else if (experience < 3) {
      reasons.add('corri da $experience ${experience == 1 ? 'anno' : 'anni'}: '
          'tendini e ossa si adattano piu\' lentamente dei muscoli');
    } else if (experience >= 8) {
      reasons.add('$experience anni di corsa sono una base solida');
    }
    final int? stop = inactiveSinceWeeks;
    if (stop != null && stop >= 2) {
      reasons.add('hai ripreso da poco dopo $stop settimane di stop');
    }

    if (reasons.isEmpty) {
      return 'Progressione standard.';
    }
    return 'Progressione calibrata perche\' ${reasons.join('; ')}.';
  }

  AthleteProfile copyWith({
    int? birthYear,
    AthleteSex? sex,
    double? heightCm,
    double? weightKg,
    int? runningYears,
    int? availableDays,
    int? restingHeartRate,
    int? maxHeartRate,
    int? inactiveSinceWeeks,
    bool clearInactive = false,
    bool clearBirthYear = false,
    bool clearRunningYears = false,
    List<PersonalBest>? personalBests,
  }) =>
      AthleteProfile(
        birthYear: clearBirthYear ? null : (birthYear ?? this.birthYear),
        sex: sex ?? this.sex,
        heightCm: heightCm ?? this.heightCm,
        weightKg: weightKg ?? this.weightKg,
        runningYears:
            clearRunningYears ? null : (runningYears ?? this.runningYears),
        availableDays: availableDays ?? this.availableDays,
        restingHeartRate: restingHeartRate ?? this.restingHeartRate,
        maxHeartRate: maxHeartRate ?? this.maxHeartRate,
        inactiveSinceWeeks:
            clearInactive ? null : (inactiveSinceWeeks ?? this.inactiveSinceWeeks),
        personalBests: personalBests ?? this.personalBests,
      );

  Map<String, dynamic> toJson() => <String, dynamic>{
        'birthYear': birthYear,
        'sex': sex.storageKey,
        'heightCm': heightCm,
        'weightKg': weightKg,
        'runningYears': runningYears,
        'availableDays': availableDays,
        'restingHeartRate': restingHeartRate,
        'maxHeartRate': maxHeartRate,
        'inactiveSinceWeeks': inactiveSinceWeeks,
        'personalBests':
            personalBests.map((PersonalBest b) => b.toJson()).toList(),
      };

  factory AthleteProfile.fromJson(Map<String, dynamic> json) {
    final List<dynamic> rawBests =
        (json['personalBests'] as List<dynamic>?) ?? <dynamic>[];
    return AthleteProfile(
      birthYear: (json['birthYear'] as num?)?.toInt(),
      sex: AthleteSexInfo.fromStorage(json['sex'] as String?),
      heightCm: (json['heightCm'] as num?)?.toDouble(),
      weightKg: (json['weightKg'] as num?)?.toDouble(),
      runningYears: (json['runningYears'] as num?)?.toInt(),
      availableDays: (json['availableDays'] as num?)?.toInt() ?? 4,
      restingHeartRate: (json['restingHeartRate'] as num?)?.toInt(),
      maxHeartRate: (json['maxHeartRate'] as num?)?.toInt(),
      inactiveSinceWeeks: (json['inactiveSinceWeeks'] as num?)?.toInt(),
      personalBests: rawBests
          .whereType<Map<dynamic, dynamic>>()
          .map((Map<dynamic, dynamic> e) =>
              PersonalBest.fromJson(e.cast<String, dynamic>()))
          .toList(),
    );
  }
}
