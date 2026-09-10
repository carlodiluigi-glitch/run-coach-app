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
/// 2. **Distanza minima**: spostamenti troppo piccoli per essere credibili
///    sono rumore e non vengono sommati. La soglia non e' fissa ma cresce con
///    l'incertezza della misura: vedi [minDistanceFor].
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
    this.accuracyFactor = 1.8,
    this.maxMinDistanceMeters = 15.0,
    this.stationarySpeed = 0.5,
    this.trustSpeedAbove = 1.5,
    this.maxSpeedMetersPerSecond = 8.0, // ~2:05 min/km: oltre non e' umano
    this.maxJumpMeters = 80.0,
    this.minTimeDeltaMs = 500,
  });

  final double maxAccuracyMeters;

  /// Soglia minima assoluta, usata quando il segnale e' ottimo.
  final double minDistanceMeters;

  /// Quanto la soglia minima segue l'incertezza della misura.
  ///
  /// Il rumore fra due letture consecutive ha ampiezza paragonabile
  /// all'accuratezza dichiarata, non molto minore: una soglia pari
  /// all'accuratezza ne taglierebbe solo circa la meta'. Da qui un fattore
  /// nettamente sopra 1.
  final double accuracyFactor;

  /// Tetto della soglia minima.
  ///
  /// Senza, con segnale pessimo la soglia diventerebbe cosi' alta da non
  /// registrare piu' nulla.
  final double maxMinDistanceMeters;

  /// Sotto questa velocita' riportata dal chip si considera di essere fermi.
  ///
  /// 0.5 m/s sono 1.8 km/h: piu' lento di qualsiasi camminata.
  final double stationarySpeed;

  /// Velocita' oltre la quale si conclude che il chip riporta davvero la
  /// velocita'. Vedi [_speedIsTrustworthy].
  final double trustSpeedAbove;

  final double maxSpeedMetersPerSecond;
  final double maxJumpMeters;
  final int minTimeDeltaMs;

  /// Diventa vero quando il dispositivo ha riportato almeno una velocita'
  /// chiaramente in movimento.
  ///
  /// PERCHE' QUESTA CAUTELA: la velocita' del chip, ricavata dall'effetto
  /// Doppler, e' molto piu' affidabile della differenza fra due posizioni per
  /// capire se si e' fermi. Ma non tutti i dispositivi la forniscono, e uno
  /// che riportasse sempre zero farebbe scartare ogni punto, cioe' una corsa
  /// che non registra nulla. Quindi il controllo si accende solo dopo aver
  /// visto una prova che quel dato funziona. Nel caso tipico - si corre e a un
  /// certo punto ci si ferma - la prova e' gia' arrivata da un pezzo.
  bool _speedIsTrustworthy = false;

  bool get speedIsTrustworthy => _speedIsTrustworthy;

  /// Soglia minima di spostamento per una data accuratezza.
  ///
  /// NOTA IMPORTANTE: alzare questa soglia non fa perdere distanza vera. Un
  /// punto scartato qui non sposta il riferimento, quindi camminando la
  /// distanza dal riferimento cresce campione dopo campione finche' supera la
  /// soglia, e a quel punto viene sommata per intero. Il rumore invece oscilla
  /// intorno a un punto senza mai allontanarsi, quindi non supera mai la
  /// soglia e non viene mai contato. E' proprio questa la differenza fra stare
  /// fermi e muoversi piano.
  double minDistanceFor(double accuracy) {
    final double scaled = accuracy * accuracyFactor;
    final double threshold =
        scaled > minDistanceMeters ? scaled : minDistanceMeters;
    return threshold > maxMinDistanceMeters ? maxMinDistanceMeters : threshold;
  }

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
    _speedIsTrustworthy = false;
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
  ///
  /// [speed] e' la velocita' riportata dal chip in m/s, se disponibile.
  GpsFilterResult process({
    required double latitude,
    required double longitude,
    required double accuracy,
    required DateTime timestamp,
    double? speed,
  }) {
    // 1) Accuratezza insufficiente -> punto inutilizzabile.
    if (accuracy <= 0 || accuracy > maxAccuracyMeters) {
      return GpsFilterResult.rejected(GpsRejectReason.poorAccuracy);
    }

    // Coordinate non valide (puo' capitare con fix parziali).
    if (latitude.abs() > 90 || longitude.abs() > 180) {
      return GpsFilterResult.rejected(GpsRejectReason.invalidCoordinates);
    }

    // Una velocita' chiaramente in movimento dimostra che il dato e' fornito.
    if (speed != null && speed > trustSpeedAbove) {
      _speedIsTrustworthy = true;
    }

    // 0) Fermi secondo il chip.
    //
    // Questo controllo vale piu' di tutti gli altri messi insieme: da fermo la
    // posizione continua a oscillare di qualche metro, e nessuna soglia
    // geometrica riesce a distinguere quelle oscillazioni da una camminata
    // molto lenta. La velocita' Doppler invece va a zero, perche' non dipende
    // dal rumore sulle coordinate.
    //
    // Non si aggiorna il riferimento: se poi si riparte davvero, il tratto
    // percorso viene contato per intero dal punto in cui ci si era fermati.
    if (_speedIsTrustworthy && speed != null && speed < stationarySpeed) {
      return GpsFilterResult.rejected(GpsRejectReason.stationary);
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

    // 2) Spostamento non credibile per l'accuratezza corrente: e' rumore.
    //
    // Non si aggiorna NIENTE, ne' posizione ne' orario. E' il punto chiave:
    // tenendo fermi entrambi, camminando la distanza e il tempo dal
    // riferimento crescono insieme, cosi' quando la soglia viene superata la
    // velocita' calcolata resta quella vera. Aggiornando solo l'orario si
    // otterrebbe una distanza grande su un intervallo corto, cioe' una
    // velocita' apparente assurda, e il punto verrebbe buttato al controllo
    // successivo facendo perdere distanza reale.
    if (distance < minDistanceFor(accuracy)) {
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

  /// Il chip riporta velocita' praticamente nulla: si e' fermi.
  stationary,
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
