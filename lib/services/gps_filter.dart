import 'dart:math' as math;

/// Filtro dei punti GPS.
///
/// PERCHE' SERVE
/// -------------
/// Sommare la distanza fra tutti i punti restituiti dal GPS produce una
/// distanza gonfiata: quando si e' fermi o il segnale e' debole, il ricevitore
/// continua a "ballare" di qualche metro e ogni oscillazione verrebbe contata.
/// Questo filtro scarta i punti non attendibili prima di sommarli.
///
/// CONTROLLI APPLICATI
/// -------------------
/// 1. **Accuratezza**: se `accuracy` (raggio di incertezza in metri) e' peggiore
///    di [maxAccuracyMeters] il punto viene ignorato.
/// 2. **Distanza minima**: spostamenti sotto [minDistanceMeters] sono rumore e
///    non vengono sommati (il punto resta pero' come riferimento temporale).
/// 3. **Velocita' impossibile**: se il punto implica una velocita' superiore a
///    [maxSpeedMetersPerSecond] (velocita' non umana di corsa) viene ignorato.
/// 4. **Salto GPS**: uno spostamento singolo superiore a [maxJumpMeters] e'
///    quasi sempre un riaggancio del segnale, non una corsa: viene ignorato.
/// 5. **Punti troppo ravvicinati nel tempo**: sotto [minTimeDeltaMs] il calcolo
///    della velocita' e' instabile, il punto viene ignorato.
///
/// La classe e' pura Dart (nessuna dipendenza da plugin) cosi' e' testabile.
class GpsFilter {
  GpsFilter({
    this.maxAccuracyMeters = 25.0,
    this.minDistanceMeters = 3.0,
    this.maxSpeedMetersPerSecond = 8.0, // ~2:05 min/km: oltre non e' umano
    this.maxJumpMeters = 80.0,
    this.minTimeDeltaMs = 500,
  });

  final double maxAccuracyMeters;
  final double minDistanceMeters;
  final double maxSpeedMetersPerSecond;
  final double maxJumpMeters;
  final int minTimeDeltaMs;

  double? _lastLat;
  double? _lastLon;
  DateTime? _lastTime;

  /// Distanza totale accettata dall'inizio (metri).
  double _totalMeters = 0.0;

  double get totalMeters => _totalMeters;

  bool get hasReference => _lastLat != null;

  /// Azzera lo stato del filtro (nuova attivita').
  void reset() {
    _lastLat = null;
    _lastLon = null;
    _lastTime = null;
    _totalMeters = 0.0;
  }

  /// "Dimentica" solo il punto di riferimento senza azzerare la distanza.
  ///
  /// Va chiamato alla ripresa dopo una pausa: durante la pausa l'utente puo'
  /// essersi spostato e quel tratto non deve essere sommato.
  void dropReference() {
    _lastLat = null;
    _lastLon = null;
    _lastTime = null;
  }

  /// Elabora un nuovo campione GPS.
  GpsFilterResult process({
    required double latitude,
    required double longitude,
    required double accuracy,
    required DateTime timestamp,
  }) {
    // 1) Accuratezza insufficiente -> punto inutilizzabile.
    if (accuracy <= 0 || accuracy > maxAccuracyMeters) {
      return GpsFilterResult.rejected(GpsRejectReason.poorAccuracy);
    }

    // Coordinate non valide (puo' capitare con fix parziali).
    if (latitude.abs() > 90 || longitude.abs() > 180) {
      return GpsFilterResult.rejected(GpsRejectReason.invalidCoordinates);
    }

    final double? prevLat = _lastLat;
    final double? prevLon = _lastLon;
    final DateTime? prevTime = _lastTime;

    // Primo punto valido: diventa solo riferimento, non aggiunge distanza.
    if (prevLat == null || prevLon == null || prevTime == null) {
      _lastLat = latitude;
      _lastLon = longitude;
      _lastTime = timestamp;
      return GpsFilterResult.accepted(0.0, isFirstFix: true);
    }

    final int deltaMs = timestamp.difference(prevTime).inMilliseconds;
    // 5) Campioni troppo ravvicinati o timestamp all'indietro.
    if (deltaMs < minTimeDeltaMs) {
      return GpsFilterResult.rejected(GpsRejectReason.tooSoon);
    }

    final double distance =
        haversineMeters(prevLat, prevLon, latitude, longitude);

    // 4) Salto anomalo (riaggancio del segnale).
    if (distance > maxJumpMeters) {
      // Il vecchio riferimento non e' piu' affidabile: aggiorno la posizione
      // ma non sommo il tratto.
      _lastLat = latitude;
      _lastLon = longitude;
      _lastTime = timestamp;
      return GpsFilterResult.rejected(GpsRejectReason.gpsJump);
    }

    // 3) Velocita' impossibile per una corsa a piedi.
    final double speed = distance / (deltaMs / 1000.0);
    if (speed > maxSpeedMetersPerSecond) {
      _lastLat = latitude;
      _lastLon = longitude;
      _lastTime = timestamp;
      return GpsFilterResult.rejected(GpsRejectReason.impossibleSpeed);
    }

    // 2) Micro-spostamenti: rumore da fermo. Aggiorno solo il tempo, cosi' la
    // prossima misura di velocita' resta corretta, ma non sommo la distanza.
    if (distance < minDistanceMeters) {
      _lastTime = timestamp;
      return GpsFilterResult.rejected(GpsRejectReason.belowMinDistance);
    }

    // Punto valido.
    _lastLat = latitude;
    _lastLon = longitude;
    _lastTime = timestamp;
    _totalMeters += distance;
    return GpsFilterResult.accepted(distance, instantSpeed: speed);
  }
}

/// Motivo per cui un punto GPS e' stato scartato.
enum GpsRejectReason {
  poorAccuracy,
  invalidCoordinates,
  tooSoon,
  gpsJump,
  impossibleSpeed,
  belowMinDistance,
}

/// Esito dell'elaborazione di un punto GPS.
class GpsFilterResult {
  const GpsFilterResult._({
    required this.accepted,
    required this.addedMeters,
    this.reason,
    this.isFirstFix = false,
    this.instantSpeed,
  });

  factory GpsFilterResult.accepted(
    double addedMeters, {
    bool isFirstFix = false,
    double? instantSpeed,
  }) =>
      GpsFilterResult._(
        accepted: true,
        addedMeters: addedMeters,
        isFirstFix: isFirstFix,
        instantSpeed: instantSpeed,
      );

  factory GpsFilterResult.rejected(GpsRejectReason reason) =>
      GpsFilterResult._(accepted: false, addedMeters: 0.0, reason: reason);

  final bool accepted;
  final double addedMeters;
  final GpsRejectReason? reason;
  final bool isFirstFix;

  /// Velocita' istantanea calcolata dai due punti (m/s), se disponibile.
  final double? instantSpeed;
}

const double _earthRadiusMeters = 6371008.8;

/// Distanza in metri fra due coordinate (formula dell'emisenoverso).
double haversineMeters(double lat1, double lon1, double lat2, double lon2) {
  final double dLat = _toRadians(lat2 - lat1);
  final double dLon = _toRadians(lon2 - lon1);
  final double a = math.sin(dLat / 2) * math.sin(dLat / 2) +
      math.cos(_toRadians(lat1)) *
          math.cos(_toRadians(lat2)) *
          math.sin(dLon / 2) *
          math.sin(dLon / 2);
  final double c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
  return _earthRadiusMeters * c;
}

double _toRadians(double degrees) => degrees * math.pi / 180.0;
