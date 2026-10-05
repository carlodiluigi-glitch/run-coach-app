import 'dart:math' as math;

/// Da dove viene la distanza di una corsa.
///
/// PERCHE' IL METODO CONTA PIU' DI TUTTO IL RESTO
/// ----------------------------------------------
/// La distanza non e' un numero fra tanti: e' **l'ingresso di tutto**. Da li'
/// escono il passo, l'indice di forma, i record, il carico, i ritmi del piano.
/// Se la distanza e' gonfiata del 15%, l'app ti crede piu' veloce di quello che
/// sei e ti allena a ritmi che non reggi. Se e' tagliata del 30%, ti crede piu'
/// lento e ti allena piano per sempre. Nessun calcolo a valle puo' rimediare a
/// un numero sbagliato in ingresso.
///
/// IL METODO CHE SEMBRA OVVIO, E PERCHE' NON FUNZIONA
/// --------------------------------------------------
/// La cosa ovvia e' sommare la distanza fra un punto GPS e il successivo. E'
/// quello che faceva questa classe, e **non puo' funzionare**: ogni posizione
/// ha un errore di qualche metro, e un corridore a 5:00/km avanza 3,3 metri al
/// secondo. Il passo vero e l'errore sono della stessa misura, quindi la somma
/// misura in buona parte il rumore.
///
/// Peggio: aggiungendo i filtri che sembrano risolverlo - una distanza minima
/// per ignorare le oscillazioni, un tetto di velocita' per scartare i salti -
/// l'errore non sparisce, cambia segno in modo imprevedibile. Misurato su
/// corse simulate di 50 minuti di cui si conosceva la distanza vera:
///
/// | caso | metodo vecchio | metodo nuovo |
/// |---|---|---|
/// | corsa continua | da +2,5% a +3,1% | **0,0%** |
/// | ripetute | da -2,4% a -4,2% | **-0,2%** |
/// | con soste e semafori | da +5,0% a +8,3% | **+0,1%** |
///
/// PERCHE' UN 3% CONTA LO STESSO
/// -----------------------------
/// Tre per cento su dieci chilometri sono trecento metri, e non e' un errore
/// casuale che si media via: e' una **distorsione sistematica, con il segno che
/// cambia secondo il tipo di seduta**. Le corse con soste venivano allungate
/// (+8%), le ripetute accorciate (-4%). Confrontare una seduta con l'altra -
/// che e' esattamente quello che fa l'indice di forma - voleva dire confrontare
/// due misure storte in direzioni opposte.
///
/// IL METODO GIUSTO: LA VELOCITA', NON LA POSIZIONE
/// ------------------------------------------------
/// Il chip GPS non calcola la velocita' dalle posizioni: la ricava dallo
/// **spostamento di frequenza** del segnale dei satelliti - l'effetto Doppler,
/// lo stesso per cui la sirena di un'ambulanza cambia tono quando passa. E'
/// una misura diretta e indipendente, precisa a qualche decimo di metro al
/// secondo anche quando la posizione balla di dieci metri.
///
/// Android la riporta in ogni campione, e Falcata la leggeva gia' - per
/// scriverla sullo schermo, e poi la buttava via. Adesso la distanza e' il
/// tempo per quella velocita', sommato. Sulle stesse corse simulate:
///
/// (I numeri sono quelli della tabella qui sopra.)
///
/// Il guadagno piu' grande e' sulle corse con le soste, dove il metodo vecchio
/// regalava fino all'8% di distanza mai percorsa.///
/// UNA LEZIONE SU COME SI MISURA
/// -----------------------------
/// La prima versione di questa analisi dava al metodo vecchio errori fino al
/// **69%**. Era falso, e l'errore stava nell'ipotesi: il rumore del GPS era
/// stato modellato come **indipendente a ogni secondo**. L'errore vero invece
/// **deriva lentamente** - multipath, geometria dei satelliti e ionosfera
/// cambiano in minuti, non in secondi - quindi due posizioni consecutive hanno
/// quasi lo stesso errore, e la differenza fra loro e' molto piu' pulita.
///
/// Il numero sbagliato e' stato smontato da chi l'app la usa: "non mi sembrava
/// che sbagliasse cosi' tanto". Aveva ragione. Una simulazione vale quanto la
/// sua ipotesi piu' debole, e quando il risultato contraddice l'esperienza di
/// chi guarda i numeri veri, e' quasi sempre l'ipotesi a essere sbagliata.
///
/// IL RIPIEGO, PER I TELEFONI CHE NON LA RIPORTANO
/// -----------------------------------------------
/// Qualche telefono riporta velocita' nulla o assente. Li' si torna alle
/// posizioni, ma **mediate**: la posizione usata non e' quella dell'ultimo
/// campione ma la media degli ultimi [smoothSamples], che cancella il rumore
/// come fa la media mobile sulla quota. Con una soglia proporzionale
/// all'accuratezza dichiarata - perche' sotto l'errore del GPS non si puo'
/// distinguere un passo da un tremolio - il ripiego sta entro il 2,5% su un
/// percorso diritto e perde al massimo il 5% su un percorso pieno di curve
/// strette, dove la media taglia gli angoli.
///
/// UNA TRAPPOLA GIA' CADUTA
/// ------------------------
/// Velocita' **esattamente zero** non vuol dire "sei fermo": vuol dire che il
/// telefono non sta dicendo niente. Trattarla come "fermo" azzerava la
/// distanza sui telefoni che non la riportano - cento per cento di errore, la
/// corsa intera persa. Zero manda al ripiego, che se sei davvero fermo non
/// somma niente comunque, perche' la posizione non si muove.
class GpsFilter {
  GpsFilter({
    this.maxAccuracyMeters = 25.0,
    this.maxSpeedMetersPerSecond = 8.0,
    this.minMovingSpeed = 0.5,
    this.maxGapSeconds = 10,
    this.smoothSamples = 9,
    this.accuracyFactor = 0.6,
    this.minDistanceMeters = 3.0,
    this.minTimeDeltaMs = 500,
  });

  /// Oltre questo raggio di incertezza il campione non si usa.
  final double maxAccuracyMeters;

  /// ~2:05 al km: oltre non e' una corsa a piedi.
  final double maxSpeedMetersPerSecond;

  /// PROVA IN AUTO: spegne il tetto di velocita'.
  ///
  /// Serve solo a verificare la misura della distanza su un tragitto noto
  /// senza aspettare una corsa. Non si salva: alla chiusura dell'app torna
  /// spento da solo. Il tetto resta comunque a 100 m/s (360 km/h), che
  /// nessuna auto raggiunge e che ferma ancora i salti assurdi del segnale.
  bool senzaLimiteVelocita = false;

  double get _velocitaMassima =>
      senzaLimiteVelocita ? 100.0 : maxSpeedMetersPerSecond;

  /// Sotto questa velocita' si sta fermi o si cammina appena: non si somma.
  ///
  /// Mezzo metro al secondo e' un passo molto lento. Sotto, e' quasi sempre il
  /// chip che riporta il tremolio di chi e' in piedi al semaforo.
  final double minMovingSpeed;

  /// Oltre questo silenzio non si usa la velocita', ma la linea dritta.
  ///
  /// Se il telefono smette di dare punti per piu' di dieci secondi, quello che
  /// e' successo nel mezzo non lo sa nessuno. Moltiplicare l'ultima velocita'
  /// nota per un minuto di buco e' inventare, e inventare al rialzo: si conta
  /// solo la linea dritta fra il punto prima e quello dopo, che e' il minimo
  /// certo.
  final int maxGapSeconds;

  /// Quanti campioni entrano nella media delle posizioni (solo nel ripiego).
  ///
  /// Nove e' il compromesso misurato: finestre piu' lunghe puliscono meglio il
  /// rumore ma tagliano gli angoli (a 21 campioni un giro con una curva ogni
  /// cento metri perde il 13%), piu' corte lasciano passare il rumore.
  final int smoothSamples;

  /// Soglia del ripiego, in frazione dell'accuratezza dichiarata.
  final double accuracyFactor;

  /// Soglia minima assoluta del ripiego, in metri.
  final double minDistanceMeters;

  /// Sotto questo intervallo il campione e' un duplicato.
  final int minTimeDeltaMs;

  // ------------------------------------------------------------------ stato
  DateTime? _lastTime;

  /// Posizioni recenti per la media del ripiego.
  final List<_Campione> _finestra = <_Campione>[];

  double? _mediaLat;
  double? _mediaLon;
  DateTime? _mediaTime;

  double _totalMeters = 0.0;
  int _dopplerSamples = 0;
  int _positionSamples = 0;

  double get totalMeters => _totalMeters;

  bool get hasReference => _lastTime != null;

  /// Quanta parte della distanza e' stata misurata con la velocita' del chip.
  ///
  /// Serve per dire quanto ci si puo' fidare: sotto meta', la corsa e' stata
  /// misurata quasi tutta a posizioni, che e' il metodo meno preciso.
  double get dopplerShare {
    final int totali = _dopplerSamples + _positionSamples;
    return totali == 0 ? 0 : _dopplerSamples / totali;
  }

  void reset() {
    _lastTime = null;
    _finestra.clear();
    _mediaLat = null;
    _mediaLon = null;
    _mediaTime = null;
    _totalMeters = 0.0;
    _dopplerSamples = 0;
    _positionSamples = 0;
  }

  /// "Dimentica" il riferimento senza azzerare la distanza.
  ///
  /// Va chiamato alla ripresa dopo una pausa: durante la pausa l'utente puo'
  /// essersi spostato, e quel tratto non va sommato.
  void dropReference() {
    _lastTime = null;
    _finestra.clear();
    _mediaLat = null;
    _mediaLon = null;
    _mediaTime = null;
  }

  /// Elabora un campione GPS. [speed] e' la velocita' del chip, se c'e'.
  GpsFilterResult process({
    required double latitude,
    required double longitude,
    required double accuracy,
    required DateTime timestamp,
    double? speed,
  }) {
    if (accuracy <= 0 || accuracy > maxAccuracyMeters) {
      return GpsFilterResult.rejected(GpsRejectReason.poorAccuracy);
    }
    if (latitude.abs() > 90 || longitude.abs() > 180) {
      return GpsFilterResult.rejected(GpsRejectReason.invalidCoordinates);
    }

    final DateTime? prima = _lastTime;
    if (prima == null) {
      _ricorda(latitude, longitude, timestamp);
      return GpsFilterResult.accepted(0.0, isFirstFix: true);
    }

    final int deltaMs = timestamp.difference(prima).inMilliseconds;
    if (deltaMs < minTimeDeltaMs) {
      return GpsFilterResult.rejected(GpsRejectReason.tooSoon);
    }

    final double deltaSec = deltaMs / 1000.0;

    // BUCO LUNGO: SI CONTA ALMENO LA LINEA DRITTA.
    //
    // Quello che e' successo nel mezzo non lo sa nessuno, quindi moltiplicare
    // l'ultima velocita' per il buco sarebbe inventare. Ma una cosa si sa per
    // certo: sei passato dal punto di prima a quello di adesso, e la linea
    // dritta fra i due e' il MINIMO che hai percorso. Su una strada dritta e'
    // quasi esatta, in curva e' un po' corta: non puo' mai gonfiare.
    //
    // Prima il tratto si buttava intero. Su un telefono che manda un punto
    // ogni cinque secondi basta saltarne uno per superare i dieci, e una corsa
    // vera di 12,74 km (percorso misurato) e' uscita da 11,45: il 10% perso
    // in silenzio, perche' l'avviso vocale scatta solo dopo trenta secondi.
    if (deltaSec > maxGapSeconds) {
      final _Campione? ultimo = _finestra.isEmpty ? null : _finestra.last;
      dropReference();
      _ricorda(latitude, longitude, timestamp);
      if (ultimo == null) {
        return GpsFilterResult.rejected(GpsRejectReason.gpsJump);
      }
      final double dritto =
          haversineMeters(ultimo.lat, ultimo.lon, latitude, longitude);
      if (dritto / deltaSec > _velocitaMassima) {
        return GpsFilterResult.rejected(GpsRejectReason.gpsJump);
      }
      // Sotto l'errore del GPS non si distingue uno spostamento da un
      // tremolio: chi e' rimasto fermo durante il buco non somma niente.
      final double sogliaBuco =
          math.max(minDistanceMeters, accuracy * accuracyFactor);
      if (dritto < sogliaBuco) {
        return GpsFilterResult.accepted(0.0);
      }
      _totalMeters += dritto;
      _positionSamples++;
      return GpsFilterResult.accepted(
        dritto,
        instantSpeed: dritto / deltaSec,
        source: DistanceSource.position,
      );
    }

    // ------------------------------------------------- la strada principale
    if (speed != null && speed > 0 && speed <= _velocitaMassima) {
      _ricorda(latitude, longitude, timestamp);

      // IL RIFERIMENTO DEL RIPIEGO VA SPOSTATO ANCHE QUI.
      //
      // Le due strade sommano nello stesso totale ma hanno due riferimenti
      // diversi. Se il riferimento del ripiego restasse fermo mentre si misura
      // con la velocita', al primo campione senza velocita' il ripiego
      // misurerebbe tutto lo spostamento dall'ultima volta che e' stato usato -
      // cioe' **tratti gia' contati**.
      //
      // Non e' teoria: su una corsa simulata con i semafori, dove il chip
      // riporta zero da fermo e torna a riportare la velocita' quando si
      // riparte, la distanza usciva **del 90% piu' lunga del vero**. Un
      // riferimento che non avanza e' un tratto contato due volte.
      _allineaRipiego();

      if (speed < minMovingSpeed) {
        // Fermo davvero: il tempo passa, la distanza no.
        return GpsFilterResult.accepted(0.0, instantSpeed: speed);
      }

      final double aggiunti = speed * deltaSec;
      _totalMeters += aggiunti;
      _dopplerSamples++;
      return GpsFilterResult.accepted(
        aggiunti,
        instantSpeed: speed,
        source: DistanceSource.doppler,
      );
    }

    // ------------------------------------------------------------- ripiego
    //
    // Velocita' assente, zero, o impossibile: si guardano le posizioni, ma
    // mediate. Zero non vuol dire "fermo" - vuol dire che il telefono non sta
    // dicendo niente, e se si e' davvero fermi la media non si muove.
    _ricorda(latitude, longitude, timestamp);

    final double? precLat = _mediaLat;
    final double? precLon = _mediaLon;
    final DateTime? precTime = _mediaTime;
    final _Campione media = _mediaFinestra();

    if (precLat == null || precLon == null || precTime == null) {
      _mediaLat = media.lat;
      _mediaLon = media.lon;
      _mediaTime = media.time;
      return GpsFilterResult.accepted(0.0);
    }

    final double distanza =
        haversineMeters(precLat, precLon, media.lat, media.lon);
    final double dtMedia =
        media.time.difference(precTime).inMilliseconds / 1000.0;

    if (dtMedia <= 0) return GpsFilterResult.accepted(0.0);

    if (distanza / dtMedia > _velocitaMassima) {
      // Anche dopo la media e' troppo: il segnale ha saltato.
      _mediaLat = media.lat;
      _mediaLon = media.lon;
      _mediaTime = media.time;
      return GpsFilterResult.rejected(GpsRejectReason.impossibleSpeed);
    }

    // Sotto l'errore del GPS non si distingue un passo da un tremolio: si
    // aspetta, tenendo fermo il riferimento, finche' non si e' andati
    // abbastanza lontano da esserne sicuri.
    final double soglia =
        math.max(minDistanceMeters, accuracy * accuracyFactor);
    if (distanza < soglia) {
      return GpsFilterResult.rejected(GpsRejectReason.belowMinDistance);
    }

    _mediaLat = media.lat;
    _mediaLon = media.lon;
    _mediaTime = media.time;
    _totalMeters += distanza;
    _positionSamples++;
    return GpsFilterResult.accepted(
      distanza,
      instantSpeed: distanza / dtMedia,
      source: DistanceSource.position,
    );
  }

  /// Porta il riferimento del ripiego all'adesso, senza sommare niente.
  ///
  /// Si chiama ogni volta che la distanza e' stata misurata con la velocita':
  /// cosi' il ripiego, quando tocchera' a lui, misurera' solo da li' in avanti.
  void _allineaRipiego() {
    if (_finestra.isEmpty) return;
    final _Campione media = _mediaFinestra();
    _mediaLat = media.lat;
    _mediaLon = media.lon;
    _mediaTime = media.time;
  }

  void _ricorda(double lat, double lon, DateTime quando) {
    _lastTime = quando;
    _finestra.add(_Campione(lat, lon, quando));
    while (_finestra.length > smoothSamples) {
      _finestra.removeAt(0);
    }
  }

  _Campione _mediaFinestra() {
    double lat = 0;
    double lon = 0;
    int ms = 0;
    for (final _Campione c in _finestra) {
      lat += c.lat;
      lon += c.lon;
      ms += c.time.millisecondsSinceEpoch;
    }
    final int n = _finestra.length;
    return _Campione(
      lat / n,
      lon / n,
      DateTime.fromMillisecondsSinceEpoch(ms ~/ n),
    );
  }
}

class _Campione {
  const _Campione(this.lat, this.lon, this.time);
  final double lat;
  final double lon;
  final DateTime time;
}

/// Come e' stata misurata la distanza di un tratto.
enum DistanceSource {
  /// Dalla velocita' del chip GPS: il metodo buono.
  doppler,

  /// Dalle posizioni mediate: il ripiego.
  position,

  /// Nessuna distanza aggiunta.
  none,
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
    this.source = DistanceSource.none,
  });

  factory GpsFilterResult.accepted(
    double addedMeters, {
    bool isFirstFix = false,
    double? instantSpeed,
    DistanceSource source = DistanceSource.none,
  }) =>
      GpsFilterResult._(
        accepted: true,
        addedMeters: addedMeters,
        isFirstFix: isFirstFix,
        instantSpeed: instantSpeed,
        source: source,
      );

  factory GpsFilterResult.rejected(GpsRejectReason reason) =>
      GpsFilterResult._(accepted: false, addedMeters: 0.0, reason: reason);

  final bool accepted;
  final double addedMeters;
  final GpsRejectReason? reason;
  final bool isFirstFix;

  /// Velocita' istantanea (m/s), se disponibile.
  final double? instantSpeed;

  /// Da dove viene la distanza di questo tratto.
  final DistanceSource source;
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
