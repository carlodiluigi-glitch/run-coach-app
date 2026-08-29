/// Modelli predisposti per funzioni future (cardio, HRV, sonno).
///
/// IMPORTANTE: questi modelli servono solo a preparare l'architettura.
/// L'app **non** inventa e **non** stima nessuno di questi valori: restano
/// `null` finche' non sara' collegata una sorgente dati reale (fascia cardio
/// Bluetooth, orologio, ecc.).
library;

/// Campione di frequenza cardiaca istantanea.
class HeartRateSample {
  const HeartRateSample({required this.elapsedSeconds, required this.bpm});

  /// Secondi dall'inizio dell'attivita'.
  final int elapsedSeconds;

  /// Battiti per minuto misurati.
  final int bpm;

  Map<String, dynamic> toJson() =>
      <String, dynamic>{'t': elapsedSeconds, 'bpm': bpm};

  factory HeartRateSample.fromJson(Map<String, dynamic> json) => HeartRateSample(
        elapsedSeconds: (json['t'] as num?)?.toInt() ?? 0,
        bpm: (json['bpm'] as num?)?.toInt() ?? 0,
      );
}

/// Dati di variabilita' cardiaca (HRV). Nessun valore viene calcolato senza
/// una misurazione reale battito-battito.
class HrvData {
  const HrvData({
    this.rmssd,
    this.sdnn,
    this.restingHeartRate,
    this.measuredAt,
  });

  /// RMSSD in millisecondi.
  final double? rmssd;

  /// SDNN in millisecondi.
  final double? sdnn;

  /// Frequenza cardiaca a riposo in bpm.
  final int? restingHeartRate;

  final DateTime? measuredAt;

  bool get hasData => rmssd != null || sdnn != null || restingHeartRate != null;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'rmssd': rmssd,
        'sdnn': sdnn,
        'restingHeartRate': restingHeartRate,
        'measuredAt': measuredAt?.toIso8601String(),
      };

  factory HrvData.fromJson(Map<String, dynamic> json) => HrvData(
        rmssd: (json['rmssd'] as num?)?.toDouble(),
        sdnn: (json['sdnn'] as num?)?.toDouble(),
        restingHeartRate: (json['restingHeartRate'] as num?)?.toInt(),
        measuredAt: DateTime.tryParse(json['measuredAt'] as String? ?? ''),
      );
}

/// Dati di una notte di sonno. Predisposto per integrazioni future.
class SleepData {
  const SleepData({
    this.night,
    this.sleepDurationMinutes,
    this.deepSleepMinutes,
    this.remSleepMinutes,
    this.lightSleepMinutes,
    this.awakeMinutes,
    this.sleepScore,
  });

  final DateTime? night;
  final int? sleepDurationMinutes;
  final int? deepSleepMinutes;
  final int? remSleepMinutes;
  final int? lightSleepMinutes;
  final int? awakeMinutes;

  /// Punteggio 0-100 fornito dalla sorgente esterna (mai stimato dall'app).
  final int? sleepScore;

  bool get hasData => sleepDurationMinutes != null || sleepScore != null;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'night': night?.toIso8601String(),
        'sleepDurationMinutes': sleepDurationMinutes,
        'deepSleepMinutes': deepSleepMinutes,
        'remSleepMinutes': remSleepMinutes,
        'lightSleepMinutes': lightSleepMinutes,
        'awakeMinutes': awakeMinutes,
        'sleepScore': sleepScore,
      };

  factory SleepData.fromJson(Map<String, dynamic> json) => SleepData(
        night: DateTime.tryParse(json['night'] as String? ?? ''),
        sleepDurationMinutes: (json['sleepDurationMinutes'] as num?)?.toInt(),
        deepSleepMinutes: (json['deepSleepMinutes'] as num?)?.toInt(),
        remSleepMinutes: (json['remSleepMinutes'] as num?)?.toInt(),
        lightSleepMinutes: (json['lightSleepMinutes'] as num?)?.toInt(),
        awakeMinutes: (json['awakeMinutes'] as num?)?.toInt(),
        sleepScore: (json['sleepScore'] as num?)?.toInt(),
      );
}

/// Metriche di corsa avanzate. Tutte opzionali e mai simulate.
class RunningDynamics {
  const RunningDynamics({
    this.cadenceSpm,
    this.strideLengthMeters,
    this.verticalOscillationCm,
    this.groundContactTimeMs,
  });

  /// Cadenza in passi al minuto.
  final int? cadenceSpm;

  /// Lunghezza del passo in metri.
  final double? strideLengthMeters;

  /// Oscillazione verticale in centimetri.
  final double? verticalOscillationCm;

  /// Tempo di contatto al suolo in millisecondi.
  final int? groundContactTimeMs;

  bool get hasData =>
      cadenceSpm != null ||
      strideLengthMeters != null ||
      verticalOscillationCm != null ||
      groundContactTimeMs != null;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'cadenceSpm': cadenceSpm,
        'strideLengthMeters': strideLengthMeters,
        'verticalOscillationCm': verticalOscillationCm,
        'groundContactTimeMs': groundContactTimeMs,
      };

  factory RunningDynamics.fromJson(Map<String, dynamic> json) => RunningDynamics(
        cadenceSpm: (json['cadenceSpm'] as num?)?.toInt(),
        strideLengthMeters: (json['strideLengthMeters'] as num?)?.toDouble(),
        verticalOscillationCm:
            (json['verticalOscillationCm'] as num?)?.toDouble(),
        groundContactTimeMs: (json['groundContactTimeMs'] as num?)?.toInt(),
      );
}
