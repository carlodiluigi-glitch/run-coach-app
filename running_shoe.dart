import '../utils/id_generator.dart';

/// Una scarpa da running con i chilometri accumulati.
class RunningShoe {
  RunningShoe({
    String? id,
    required this.brand,
    required this.model,
    DateTime? firstUseDate,
    this.initialKm = 0.0,
    this.accumulatedMeters = 0.0,
    this.thresholdKm,
    this.runCount = 0,
    this.lastUsed,
    this.retired = false,
  })  : id = id ?? IdGenerator.newId('shoe'),
        firstUseDate = firstUseDate ?? DateTime.now();

  final String id;
  final String brand;
  final String model;
  final DateTime firstUseDate;

  /// Chilometri gia' percorsi prima di inserire la scarpa nell'app.
  final double initialKm;

  /// Metri accumulati registrando attivita' con questa scarpa.
  final double accumulatedMeters;

  /// Soglia consigliata di sostituzione, in chilometri (opzionale).
  final double? thresholdKm;

  /// Numero di attivita' registrate con questa scarpa.
  final int runCount;

  final DateTime? lastUsed;

  /// Scarpa messa a riposo: resta nello storico ma non e' piu' proposta.
  final bool retired;

  String get displayName => '$brand $model'.trim();

  /// Chilometri totali = km iniziali + metri accumulati.
  double get totalKm => initialKm + accumulatedMeters / 1000.0;

  /// Percentuale di usura rispetto alla soglia (0..1), `null` senza soglia.
  double? get wearRatio {
    final double? threshold = thresholdKm;
    if (threshold == null || threshold <= 0) return null;
    final double ratio = totalKm / threshold;
    return ratio < 0 ? 0 : (ratio > 1 ? 1 : ratio);
  }

  bool get isOverThreshold {
    final double? threshold = thresholdKm;
    return threshold != null && threshold > 0 && totalKm >= threshold;
  }

  /// Restituisce una copia con i metri di una nuova attivita' aggiunti.
  RunningShoe withActivityAdded(double meters, DateTime when) => copyWith(
        accumulatedMeters: accumulatedMeters + (meters < 0 ? 0 : meters),
        runCount: runCount + 1,
        lastUsed: when,
      );

  /// Restituisce una copia con i metri di una attivita' rimossi.
  RunningShoe withActivityRemoved(double meters) {
    final double next = accumulatedMeters - (meters < 0 ? 0 : meters);
    return copyWith(
      accumulatedMeters: next < 0 ? 0 : next,
      runCount: runCount > 0 ? runCount - 1 : 0,
    );
  }

  RunningShoe copyWith({
    String? brand,
    String? model,
    DateTime? firstUseDate,
    double? initialKm,
    double? accumulatedMeters,
    double? thresholdKm,
    bool clearThreshold = false,
    int? runCount,
    DateTime? lastUsed,
    bool? retired,
  }) =>
      RunningShoe(
        id: id,
        brand: brand ?? this.brand,
        model: model ?? this.model,
        firstUseDate: firstUseDate ?? this.firstUseDate,
        initialKm: initialKm ?? this.initialKm,
        accumulatedMeters: accumulatedMeters ?? this.accumulatedMeters,
        thresholdKm: clearThreshold ? null : (thresholdKm ?? this.thresholdKm),
        runCount: runCount ?? this.runCount,
        lastUsed: lastUsed ?? this.lastUsed,
        retired: retired ?? this.retired,
      );

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'brand': brand,
        'model': model,
        'firstUseDate': firstUseDate.toIso8601String(),
        'initialKm': initialKm,
        'accumulatedMeters': accumulatedMeters,
        'thresholdKm': thresholdKm,
        'runCount': runCount,
        'lastUsed': lastUsed?.toIso8601String(),
        'retired': retired,
      };

  factory RunningShoe.fromJson(Map<String, dynamic> json) => RunningShoe(
        id: json['id'] as String?,
        brand: json['brand'] as String? ?? '',
        model: json['model'] as String? ?? '',
        firstUseDate: DateTime.tryParse(json['firstUseDate'] as String? ?? ''),
        initialKm: (json['initialKm'] as num?)?.toDouble() ?? 0.0,
        accumulatedMeters: (json['accumulatedMeters'] as num?)?.toDouble() ?? 0.0,
        thresholdKm: (json['thresholdKm'] as num?)?.toDouble(),
        runCount: (json['runCount'] as num?)?.toInt() ?? 0,
        lastUsed: DateTime.tryParse(json['lastUsed'] as String? ?? ''),
        retired: json['retired'] as bool? ?? false,
      );
}
