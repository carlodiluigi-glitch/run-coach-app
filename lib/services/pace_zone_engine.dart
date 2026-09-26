import '../models/estimate.dart';
import 'fitness_service.dart';

/// Le zone di allenamento.
enum TrainingZone {
  recovery,
  easy,
  steady,
  marathon,
  threshold,
  tenK,
  fiveK,
  interval,
  repetition,
}

extension TrainingZoneInfo on TrainingZone {
  String get label {
    switch (this) {
      case TrainingZone.recovery:
        return 'Rigenerante';
      case TrainingZone.easy:
        return 'Lento';
      case TrainingZone.steady:
        return 'Medio facile';
      case TrainingZone.marathon:
        return 'Medio';
      case TrainingZone.threshold:
        return 'Soglia';
      case TrainingZone.tenK:
        return 'Ritmo 10 km';
      case TrainingZone.fiveK:
        return 'Ritmo 5 km';
      case TrainingZone.interval:
        return 'Ripetute';
      case TrainingZone.repetition:
        return 'Veloci';
    }
  }

  String get purpose {
    switch (this) {
      case TrainingZone.recovery:
        return 'Far girare le gambe senza aggiungere fatica.';
      case TrainingZone.easy:
        return 'Il pane quotidiano: costruisce il motore aerobico.';
      case TrainingZone.steady:
        return 'Un filo sopra il lento, ancora tranquillo.';
      case TrainingZone.marathon:
        return 'Il passo che terresti per ore. Resistenza specifica.';
      case TrainingZone.threshold:
        return 'Il lavoro che sposta di piu\' su ogni distanza dai 5 km in su.';
      case TrainingZone.tenK:
        return 'Ritmo di gara sui 10 km.';
      case TrainingZone.fiveK:
        return 'Ritmo di gara sui 5 km.';
      case TrainingZone.interval:
        return 'Alza il tetto del consumo di ossigeno.';
      case TrainingZone.repetition:
        return 'Meccanica di corsa ed economia. Non deve stancare.';
    }
  }

  /// `true` se correre in questa zona costa davvero.
  bool get isQuality {
    switch (this) {
      case TrainingZone.recovery:
      case TrainingZone.easy:
      case TrainingZone.steady:
        return false;
      case TrainingZone.marathon:
      case TrainingZone.threshold:
      case TrainingZone.tenK:
      case TrainingZone.fiveK:
      case TrainingZone.interval:
      case TrainingZone.repetition:
        return true;
    }
  }
}

/// Una zona con il suo intervallo di passo.
class ZonePace {
  const ZonePace({
    required this.zone,
    required this.range,
    required this.confidence,
  });

  final TrainingZone zone;

  /// Intervallo in secondi per chilometro. [Range.low] e' il piu' veloce.
  final Range range;

  final double confidence;

  double get centre => range.centre;
  String get label => zone.label;
  String get purpose => zone.purpose;
}

/// Tutte le zone, ricavate dall'indice di forma.
class TrainingZones {
  const TrainingZones({required this.zones, required this.confidence});

  final Map<TrainingZone, ZonePace> zones;
  final double confidence;

  ZonePace operator [](TrainingZone zone) => zones[zone]!;

  List<ZonePace> get all => TrainingZone.values
      .map((TrainingZone z) => zones[z])
      .whereType<ZonePace>()
      .toList();

  /// In quale zona cade un passo.
  ///
  /// Le zone si sovrappongono un po', come nella realta': si sceglie quella
  /// il cui centro e' piu' vicino. Un passo piu' lento di tutto e' comunque
  /// rigenerante; uno piu' veloce di tutto e' comunque velocita'.
  TrainingZone zoneFor(double paceSecPerKm) {
    TrainingZone best = TrainingZone.easy;
    double bestDistance = double.infinity;
    for (final ZonePace zone in all) {
      final double distance = zone.range.contains(paceSecPerKm)
          ? 0
          : zone.range.distanceFrom(paceSecPerKm);
      if (distance < bestDistance) {
        bestDistance = distance;
        best = zone.zone;
      }
    }
    return best;
  }

  /// Passo al di sotto del quale si sta facendo qualita' (soglia o piu'
  /// veloce), in secondi per chilometro.
  double get qualityThresholdPace => zones[TrainingZone.threshold]!.range.high;
}

/// Calcola le zone di allenamento a partire dall'indice di forma.
///
/// PERCHE' INTERVALLI E NON NUMERI SECCHI
/// --------------------------------------
/// Dire "soglia 4:25" e' falsa precisione: il passo di soglia di una persona
/// cambia con il caldo, il vento, il sonno e il terreno, e la stima stessa ha
/// un margine. Le zone sono quindi fasce.
///
/// E la fascia **si allarga quando la confidenza e' bassa**. Con due corse in
/// archivio il motore sa poco, e lo dice dando un intervallo largo invece di
/// fingere una precisione che non ha. Man mano che arrivano dati la fascia si
/// stringe.
class PaceZoneEngine {
  const PaceZoneEngine({this.fitness = const FitnessService()});

  final FitnessService fitness;

  /// Semiampiezza di base delle fasce, in secondi al chilometro.
  /// VALORI EMPIRICI, TARABILI.
  static const Map<TrainingZone, double> baseHalfWidth =
      <TrainingZone, double>{
    TrainingZone.marathon: 7,
    TrainingZone.threshold: 5,
    TrainingZone.tenK: 5,
    TrainingZone.fiveK: 4,
    TrainingZone.interval: 4,
    TrainingZone.repetition: 4,
  };

  /// Di quanto si allarga la fascia quando la confidenza e' nulla.
  static const double uncertaintyStretch = 1.6;

  /// Calcola le zone. `null` se l'indice non e' disponibile.
  TrainingZones? zonesFor(Estimate<double>? index) {
    if (index == null || index.value <= 0) return null;

    final double vdot = index.value;
    final double confidence = index.confidence;

    final int? marathonTime = fitness.predictSeconds(vdot, 42195);
    final double? hourDistance = fitness.distanceForDuration(vdot, 3600);
    final int? tenKTime = fitness.predictSeconds(vdot, 10000);
    final int? fiveKTime = fitness.predictSeconds(vdot, 5000);
    final int? threeKTime = fitness.predictSeconds(vdot, 3000);
    final int? fifteenTime = fitness.predictSeconds(vdot, 1500);

    if (marathonTime == null ||
        hourDistance == null ||
        hourDistance <= 0 ||
        tenKTime == null ||
        fiveKTime == null ||
        threeKTime == null ||
        fifteenTime == null) {
      return null;
    }

    // Piu' bassa la confidenza, piu' larghe le fasce.
    final double stretch = 1 + uncertaintyStretch * (1 - confidence);

    Range band(TrainingZone zone, double centre) {
      final double half = (baseHalfWidth[zone] ?? 5) * stretch;
      return Range(centre - half, centre + half);
    }

    final double marathonPace = marathonTime / 42.195;
    final double thresholdPace = 3600.0 / (hourDistance / 1000.0);
    final double tenKPace = tenKTime / 10.0;
    final double fiveKPace = fiveKTime / 5.0;
    final double intervalPace = threeKTime / 3.0;
    final double repetitionPace = fifteenTime / 1.5;

    // Il lento nasce dal costo di ossigeno, fra il 55% e il 62% dell'indice:
    // e' l'unica zona definita da una fascia fisiologica invece che da una
    // gara equivalente, perche' "il passo che terresti per sempre" non e' una
    // gara.
    final double easySlow = _paceForOxygenFraction(vdot, 0.55);
    final double easyFast = _paceForOxygenFraction(vdot, 0.62);
    if (easySlow <= 0 || easyFast <= 0) return null;

    final double easyStretch = 5 * (stretch - 1);
    final Range easy = Range(easyFast - easyStretch, easySlow + easyStretch);

    final Map<TrainingZone, ZonePace> zones = <TrainingZone, ZonePace>{
      TrainingZone.recovery: ZonePace(
        zone: TrainingZone.recovery,
        range: Range(easy.high + 10, easy.high + 50),
        confidence: confidence,
      ),
      TrainingZone.easy: ZonePace(
        zone: TrainingZone.easy,
        range: easy,
        confidence: confidence,
      ),
      TrainingZone.steady: ZonePace(
        zone: TrainingZone.steady,
        // Fra il lento veloce e il medio: la zona "scorrevole".
        range: Range(marathonPace + 10, easy.low - 3),
        confidence: confidence,
      ),
      TrainingZone.marathon: ZonePace(
        zone: TrainingZone.marathon,
        range: band(TrainingZone.marathon, marathonPace),
        confidence: confidence,
      ),
      TrainingZone.threshold: ZonePace(
        zone: TrainingZone.threshold,
        range: band(TrainingZone.threshold, thresholdPace),
        confidence: confidence,
      ),
      TrainingZone.tenK: ZonePace(
        zone: TrainingZone.tenK,
        range: band(TrainingZone.tenK, tenKPace),
        confidence: confidence,
      ),
      TrainingZone.fiveK: ZonePace(
        zone: TrainingZone.fiveK,
        range: band(TrainingZone.fiveK, fiveKPace),
        confidence: confidence,
      ),
      TrainingZone.interval: ZonePace(
        zone: TrainingZone.interval,
        range: band(TrainingZone.interval, intervalPace),
        confidence: confidence,
      ),
      TrainingZone.repetition: ZonePace(
        zone: TrainingZone.repetition,
        range: band(TrainingZone.repetition, repetitionPace),
        confidence: confidence,
      ),
    };

    return TrainingZones(zones: zones, confidence: confidence);
  }

  double _paceForOxygenFraction(double vdot, double fraction) {
    final double velocity = fitness.velocityForOxygen(fraction * vdot);
    if (velocity <= 0) return 0;
    return 1000.0 / velocity * 60.0;
  }
}
