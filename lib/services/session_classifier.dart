import '../models/running_activity.dart';
import 'gps_filter.dart';
import 'pace_zone_engine.dart';

/// Quanto e' stata dura una seduta, guardando cosa e' stato corso davvero.
enum SessionIntensity { recovery, easy, steady, moderate, hard }

extension SessionIntensityInfo on SessionIntensity {
  String get label {
    switch (this) {
      case SessionIntensity.recovery:
        return 'Rigenerante';
      case SessionIntensity.easy:
        return 'Facile';
      case SessionIntensity.steady:
        return 'Scorrevole';
      case SessionIntensity.moderate:
        return 'Impegnativa';
      case SessionIntensity.hard:
        return 'Dura';
    }
  }

  /// `true` se la seduta va contata come qualita' nel calcolo del carico e
  /// nella decisione del giorno dopo.
  bool get countsAsQuality =>
      this == SessionIntensity.moderate || this == SessionIntensity.hard;

  /// Ordine crescente di durezza, per confrontare previsto ed effettivo.
  int get rank => SessionIntensity.values.indexOf(this);
}

/// Il risultato dell'analisi.
class SessionAnalysis {
  const SessionAnalysis({
    required this.intensity,
    required this.qualityMinutes,
    required this.hardMinutes,
    required this.timeInZone,
    required this.totalMinutes,
    required this.averagePaceSecPerKm,
    required this.explanation,
  });

  final SessionIntensity intensity;

  /// Minuti corsi a passo di soglia o piu' veloce, in tratti continui.
  final double qualityMinutes;

  /// Minuti corsi a passo di maratona o piu' veloce, in tratti continui.
  final double hardMinutes;

  /// Minuti passati in ciascuna zona.
  final Map<TrainingZone, double> timeInZone;

  final double totalMinutes;
  final double? averagePaceSecPerKm;

  /// Perche' e' stata classificata cosi'.
  final String explanation;

  double fractionIn(TrainingZone zone) {
    if (totalMinutes <= 0) return 0;
    return (timeInZone[zone] ?? 0) / totalMinutes;
  }

  /// Quota di tempo passata a passo di medio o piu' veloce.
  double get hardFraction {
    if (totalMinutes <= 0) return 0;
    return hardMinutes / totalMinutes;
  }
}

/// Riconosce cosa e' stata **davvero** una seduta.
///
/// PERCHE' NON BASTA IL NOME
/// -------------------------
/// Il programma dice "8 km facili". L'atleta li corre venticinque secondi al
/// chilometro piu' veloce del dovuto perche' si sentiva bene, o perche' aveva
/// fretta. Sulla carta e' stata una corsa facile; nelle gambe e' stata una
/// seduta scorrevole, e programmare ripetute il giorno dopo significa
/// programmarle su un corpo che non ha recuperato.
///
/// Questo modulo guarda i passi realmente corsi e riclassifica la seduta.
///
/// COME MISURA
/// -----------
/// Il tracciato viene diviso in finestre di venti secondi e per ognuna si
/// calcola il passo. Venti secondi sono abbastanza da smorzare il rumore del
/// GPS e abbastanza pochi da non spalmare una ripetuta dentro il recupero.
/// Ogni finestra viene assegnata a una zona, e alla fine si guarda quanto
/// tempo e' stato passato dove.
///
/// Senza tracciato si ripiega sul passo medio: meno preciso, ma meglio di
/// niente e dichiarato come tale nella spiegazione.
///
/// PERCHE' LE FINESTRE NON BASTANO DA SOLE
/// ---------------------------------------
/// Una finestra di venti secondi copre circa cento metri. Fra il passo del
/// lento (5:00 al km) e il passo di soglia (4:34) ci sono sei metri di
/// differenza su una finestra: meno dell'errore del GPS. Quindi su una corsa
/// tranquilla e regolare qualche finestra cade per caso nella zona della
/// soglia, e sommandole veniva fuori "7 minuti a soglia o piu' veloce:
/// seduta impegnativa" per un lento fatto a 5:20.
///
/// La correzione: il tempo di qualita' si conta solo a **blocchi continui di
/// almeno un minuto**. Il rumore del GPS e' sparso - una finestra qui, una
/// la', mai tre di fila - mentre il lavoro vero e' continuo: un mille a 4:18
/// sono tredici finestre attaccate. Le finestre restano di venti secondi,
/// perche' servono per vedere le ripetute; cambia solo come si sommano.
class SessionClassifier {
  const SessionClassifier();

  /// Durata delle finestre di analisi, in secondi.
  static const int windowSeconds = 20;

  /// Quanto deve durare un tratto continuo perche' conti come qualita'.
  ///
  /// Un minuto e' il compromesso: sotto c'e' solo rumore, e non esiste
  /// ripetuta utile piu' corta di un minuto (400 metri a ritmo 1500 sono
  /// circa settanta secondi).
  static const int minQualityBlockSeconds = 60;

  /// Minuti di soglia o piu' veloce oltre i quali la seduta e' dura.
  /// VALORI EMPIRICI, TARABILI.
  static const double hardQualityMinutes = 8;
  static const double moderateQualityMinutes = 3;

  /// Quota di tempo a ritmo medio o piu' veloce che rende impegnativa una
  /// seduta anche senza tratti di soglia.
  static const double moderateHardFraction = 0.40;
  static const double steadyFraction = 0.25;

  SessionAnalysis analyse(RunningActivity activity, TrainingZones zones) {
    final double totalMinutes = activity.durationSeconds / 60.0;
    final double? averagePace = activity.averagePaceSecondsPerKm;

    final Map<TrainingZone, double> timeInZone = <TrainingZone, double>{};
    List<_Window> windows = const <_Window>[];
    bool fromRoute = false;

    if (activity.route.length >= 3) {
      final List<_Window> measured = _windowsFromRoute(activity, zones);
      final Map<TrainingZone, double> perZone = _timeInZone(measured);
      if (perZone.isNotEmpty) {
        windows = measured;
        timeInZone.addAll(perZone);
        fromRoute = true;
      }
    }

    if (!fromRoute) {
      // Ripiego: tutta la seduta nella zona del passo medio.
      if (averagePace == null || totalMinutes <= 0) {
        return SessionAnalysis(
          intensity: SessionIntensity.easy,
          qualityMinutes: 0,
          hardMinutes: 0,
          timeInZone: const <TrainingZone, double>{},
          totalMinutes: totalMinutes,
          averagePaceSecPerKm: averagePace,
          explanation: 'Dati insufficienti per capire l\'intensita\': '
              'la seduta viene contata come facile.',
        );
      }
      timeInZone[zones.zoneFor(averagePace)] = totalMinutes;
    }

    // Minuti di lavoro, contati a blocchi continui.
    //
    // Senza tracciato non ci sono blocchi da guardare: c'e' un solo passo,
    // quello medio, e se e' passo di soglia allora l'intera seduta e' un
    // blocco continuo.
    final double qualityMinutes = fromRoute
        ? _minutiInBlocchi(windows, _isThresholdOrFaster)
        : _minutiPerZona(timeInZone, _isThresholdOrFaster);
    final double hardMinutes = fromRoute
        ? _minutiInBlocchi(windows, (TrainingZone z) => z.isQuality)
        : _minutiPerZona(timeInZone, (TrainingZone z) => z.isQuality);

    double measuredTotal = 0;
    for (final double minutes in timeInZone.values) {
      measuredTotal += minutes;
    }

    final SessionAnalysis draft = SessionAnalysis(
      intensity: SessionIntensity.easy,
      qualityMinutes: qualityMinutes,
      hardMinutes: hardMinutes,
      timeInZone: timeInZone,
      totalMinutes: measuredTotal > 0 ? measuredTotal : totalMinutes,
      averagePaceSecPerKm: averagePace,
      explanation: '',
    );

    final SessionIntensity intensity = _classify(draft);

    return SessionAnalysis(
      intensity: intensity,
      qualityMinutes: qualityMinutes,
      hardMinutes: hardMinutes,
      timeInZone: timeInZone,
      totalMinutes: draft.totalMinutes,
      averagePaceSecPerKm: averagePace,
      explanation: _explain(
        intensity: intensity,
        qualityMinutes: qualityMinutes,
        analysis: draft,
        fromRoute: fromRoute,
      ),
    );
  }

  /// Confronta quello che era previsto con quello che e' successo.
  ///
  /// Restituisce `null` se combaciano. Altrimenti la spiegazione dello
  /// scarto, che e' quello che serve al motore per decidere il giorno dopo.
  String? reclassificationNote({
    required SessionIntensity planned,
    required SessionAnalysis actual,
  }) {
    final int gap = actual.intensity.rank - planned.rank;
    if (gap >= 2) {
      return 'Era previsto ${planned.label.toLowerCase()}, e\' stata '
          '${actual.intensity.label.toLowerCase()}. La conto come seduta di '
          'qualita\': domani serve recupero vero.';
    }
    if (gap == 1) {
      return 'Un po\' piu\' tirata del previsto '
          '(${planned.label.toLowerCase()} -> '
          '${actual.intensity.label.toLowerCase()}).';
    }
    if (gap <= -2) {
      return 'Piu\' tranquilla del previsto: la seduta di qualita\' non e\' '
          'stata fatta davvero.';
    }
    return null;
  }

  // ------------------------------------------------------------- interne
  bool _isThresholdOrFaster(TrainingZone zone) {
    switch (zone) {
      case TrainingZone.threshold:
      case TrainingZone.tenK:
      case TrainingZone.fiveK:
      case TrainingZone.interval:
      case TrainingZone.repetition:
        return true;
      case TrainingZone.recovery:
      case TrainingZone.easy:
      case TrainingZone.steady:
      case TrainingZone.marathon:
        return false;
    }
  }

  /// Divide il tracciato in finestre, **in ordine di tempo**.
  ///
  /// L'ordine e' la parte importante: e' quello che permette di distinguere un
  /// minuto di lavoro continuo da tre finestre veloci sparse in mezz'ora.
  List<_Window> _windowsFromRoute(
    RunningActivity activity,
    TrainingZones zones,
  ) {
    final List<RoutePoint> route = activity.route;
    final List<_Window> out = <_Window>[];

    int windowStart = 0;
    double windowMeters = 0;

    for (int i = 1; i < route.length; i++) {
      final double step = haversineMeters(
        route[i - 1].latitude,
        route[i - 1].longitude,
        route[i].latitude,
        route[i].longitude,
      );
      if (step.isFinite) windowMeters += step;

      final int elapsed =
          route[i].elapsedSeconds - route[windowStart].elapsedSeconds;
      if (elapsed < windowSeconds) continue;

      TrainingZone? zone;
      if (windowMeters > 5 && elapsed > 0) {
        final double pace = elapsed / (windowMeters / 1000.0);
        // Passi impossibili (GPS ballerino, semaforo, pausa non registrata)
        // vengono scartati invece di finire in una zona a caso.
        if (pace > 100 && pace < 1500) {
          zone = zones.zoneFor(pace);
        }
      }
      // zone == null: finestra buttata. Resta nella lista come buco, cosi'
      // una pausa interrompe il blocco invece di saldare insieme due tratti
      // veloci lontani fra loro.
      out.add(_Window(zone, elapsed.toDouble()));

      windowStart = i;
      windowMeters = 0;
    }

    return out;
  }

  Map<TrainingZone, double> _timeInZone(List<_Window> windows) {
    final Map<TrainingZone, double> out = <TrainingZone, double>{};
    for (final _Window w in windows) {
      final TrainingZone? zone = w.zone;
      if (zone == null) continue;
      out[zone] = (out[zone] ?? 0) + w.seconds / 60.0;
    }
    return out;
  }

  /// Somma solo i tratti **continui** lunghi almeno un minuto in cui la zona
  /// soddisfa [vale].
  ///
  /// I blocchi piu' corti non vengono accorciati: vengono buttati. Un tratto
  /// veloce di quaranta secondi dentro un lento non e' mezzo allenamento, e'
  /// un cavalcavia o un incrocio.
  double _minutiInBlocchi(
    List<_Window> windows,
    bool Function(TrainingZone) vale,
  ) {
    double totale = 0;
    double blocco = 0;

    void chiudi() {
      if (blocco >= minQualityBlockSeconds) totale += blocco;
      blocco = 0;
    }

    for (final _Window w in windows) {
      final TrainingZone? zone = w.zone;
      if (zone != null && vale(zone)) {
        blocco += w.seconds;
      } else {
        chiudi();
      }
    }
    chiudi();

    return totale / 60.0;
  }

  /// Versione senza tracciato: non ci sono blocchi, solo zone.
  double _minutiPerZona(
    Map<TrainingZone, double> timeInZone,
    bool Function(TrainingZone) vale,
  ) {
    double totale = 0;
    for (final MapEntry<TrainingZone, double> e in timeInZone.entries) {
      if (vale(e.key)) totale += e.value;
    }
    return totale;
  }

  SessionIntensity _classify(SessionAnalysis a) {
    if (a.qualityMinutes >= hardQualityMinutes) return SessionIntensity.hard;
    if (a.qualityMinutes >= moderateQualityMinutes ||
        a.hardFraction >= moderateHardFraction) {
      return SessionIntensity.moderate;
    }

    final double steady = a.fractionIn(TrainingZone.steady) +
        a.fractionIn(TrainingZone.marathon);
    if (steady >= steadyFraction) return SessionIntensity.steady;

    if (a.fractionIn(TrainingZone.recovery) > 0.6) {
      return SessionIntensity.recovery;
    }
    return SessionIntensity.easy;
  }

  String _explain({
    required SessionIntensity intensity,
    required double qualityMinutes,
    required SessionAnalysis analysis,
    required bool fromRoute,
  }) {
    final StringBuffer buffer = StringBuffer();

    if (qualityMinutes >= 1) {
      buffer.write('${qualityMinutes.toStringAsFixed(0)} minuti a soglia o '
          'piu\' veloce');
    } else {
      final double steady = analysis.fractionIn(TrainingZone.steady) +
          analysis.fractionIn(TrainingZone.marathon);
      if (steady >= 0.15) {
        buffer.write('${(steady * 100).round()}% del tempo sopra il lento');
      } else {
        buffer.write('Quasi tutto a passo facile');
      }
    }

    buffer.write(': seduta ${intensity.label.toLowerCase()}.');

    if (!fromRoute) {
      buffer.write(' Stimata dal passo medio, senza tracciato dettagliato.');
    }

    return buffer.toString();
  }
}

/// Una finestra di analisi: la zona in cui e' caduta e quanto e' durata.
///
/// [zone] a `null` vuol dire finestra scartata (passo impossibile, pausa,
/// GPS perso). Resta nella lista perche' serve come interruzione: due tratti
/// veloci separati da una pausa non sono un unico blocco.
class _Window {
  const _Window(this.zone, this.seconds);

  final TrainingZone? zone;
  final double seconds;
}
