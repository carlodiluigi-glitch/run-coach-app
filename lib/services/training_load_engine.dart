import 'dart:math' as math;

import '../models/estimate.dart';
import '../models/running_activity.dart';
import 'gps_filter.dart';
import 'pace_zone_engine.dart';

/// Il carico di una seduta, e quanto ne resta nelle gambe.
///
/// PERCHE' NON I CHILOMETRI
/// ------------------------
/// Dieci chilometri lenti e dieci chilometri di ripetute sono la stessa riga
/// sul diario e due cose diverse nelle gambe. Contare i chilometri fa sembrare
/// uguale una settimana da 60 km tutti lenti e una da 60 km con due sedute
/// dure dentro: la prima si regge per mesi, la seconda ti rompe.
///
/// Il carico si misura in **sforzo**: ogni minuto pesa per l'intensita' a cui
/// e' stato corso.
///
/// COME SI CONTA
/// -------------
/// Per ogni finestra del tracciato si calcola quanto si stava andando forte
/// rispetto al proprio passo di soglia:
///
///     intensita' = passo di soglia / passo tenuto
///
/// A ritmo soglia vale 1. Piu' veloce, sopra 1. Piu' lento, sotto.
///
/// Poi il tempo di quella finestra viene pesato per **il quadrato**
/// dell'intensita'. Il quadrato non e' un'invenzione: e' il modo in cui il
/// costo di una corsa cresce davvero rispetto alla velocita', ed e' la stessa
/// forma usata dal TSS di Coggan, il metodo piu' collaudato per misurare il
/// carico senza cardiofrequenzimetro.
///
/// L'unita' e' tarata cosi': **100 punti = un'ora esatta a ritmo soglia**.
/// Un'ora di lento ne fa circa 70, un 5x1000 dentro un'ora ne fa circa 130.
///
/// QUELLO CHE QUESTO NUMERO NON SA
/// -------------------------------
/// Il caldo, il vento, le salite, quanto hai dormito. Il carico misura il
/// lavoro meccanico, non il costo totale della giornata. Per quello serve la
/// fatica percepita, che l'app chiede a fine corsa e che entra nella
/// prontezza (vedi ReadinessEngine) invece che nel carico.
class TrainingLoadEngine {
  const TrainingLoadEngine();

  /// Durata delle finestre di analisi, in secondi.
  ///
  /// Le stesse del SessionClassifier: venti secondi smorzano il rumore del
  /// GPS e restano abbastanza corti da vedere una ripetuta.
  static const int windowSeconds = 20;

  /// Tetto all'intensita' di una singola finestra.
  ///
  /// Nessuno tiene il doppio del passo di soglia per venti secondi: sopra
  /// questo valore e' quasi sempre il GPS che ha saltato. Senza il tetto, un
  /// salto di posizione trasformerebbe un lento in una seduta durissima -
  /// il quadrato amplifica proprio gli errori grandi.
  static const double maxIntensity = 1.35;

  /// Sotto questa intensita' il tempo non conta come allenamento: si sta
  /// camminando, o il tracciato ha perso il segnale.
  static const double minIntensity = 0.45;

  /// Costanti di tempo, in giorni.
  ///
  /// SETTE E VENTOTTO, E PERCHE'
  /// ---------------------------
  /// La fatica se ne va in giorni, la condizione si costruisce in settimane.
  /// Sette giorni e' l'orizzonte entro cui una seduta dura si fa ancora
  /// sentire; ventotto e' il tempo in cui il corpo cambia davvero.
  ///
  /// Sono i valori classici del modello di Banister (che usa 7 e 42): qui il
  /// lungo e' accorciato a 28 perche' un'app usata da chi corre da poco deve
  /// rispondere in un mese, non in sei settimane, altrimenti per tutto il
  /// primo periodo racconta solo che sei fermo.
  static const double fatigueDays = 7;
  static const double fitnessDays = 28;

  // ------------------------------------------------------ carico di una seduta
  /// Il carico di una singola attivita'. `null` se non c'e' abbastanza per
  /// dirlo.
  double? loadOf(RunningActivity activity, TrainingZones zones) {
    final double thresholdPace = zones[TrainingZone.threshold].centre;
    if (thresholdPace <= 0) return null;

    final List<_Slice> slices = _slices(activity, thresholdPace);
    if (slices.isEmpty) return null;

    double punti = 0;
    for (final _Slice s in slices) {
      punti += s.seconds / 3600.0 * s.intensity * s.intensity * 100.0;
    }
    return punti;
  }

  /// Divide l'attivita' in pezzi con la loro intensita'.
  ///
  /// Con il tracciato si usano le finestre; senza, si ripiega sul passo
  /// medio - meno preciso, ma un'attivita' inserita a mano non puo' valere
  /// zero solo perche' non ha il GPS.
  List<_Slice> _slices(RunningActivity activity, double thresholdPace) {
    final List<RoutePoint> route = activity.route;
    final List<_Slice> out = <_Slice>[];

    if (route.length >= 3) {
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

        if (windowMeters > 5 && elapsed > 0) {
          final double pace = elapsed / (windowMeters / 1000.0);
          if (pace > 100 && pace < 1500) {
            final double intensita =
                (thresholdPace / pace).clamp(0.0, maxIntensity);
            if (intensita >= minIntensity) {
              out.add(_Slice(elapsed.toDouble(), intensita));
            }
          }
        }

        windowStart = i;
        windowMeters = 0;
      }
      if (out.isNotEmpty) return out;
    }

    final double? media = activity.averagePaceSecondsPerKm;
    if (media == null || media <= 0 || activity.durationSeconds <= 0) {
      return const <_Slice>[];
    }
    final double intensita = (thresholdPace / media).clamp(0.0, maxIntensity);
    if (intensita < minIntensity) return const <_Slice>[];
    return <_Slice>[
      _Slice(activity.durationSeconds.toDouble(), intensita),
    ];
  }

  // -------------------------------------------------------- carico nel tempo
  /// Fatica, condizione e forma a una certa data.
  TrainingLoadState stateFor(
    List<RunningActivity> activities,
    TrainingZones? zones, {
    DateTime? now,
  }) {
    final List<TrainingLoadPoint> serie = seriesFor(
      activities,
      zones,
      now: now,
      days: 0, // tutta la storia: qui serve solo l'ultimo giorno
    );
    final DateTime reference = _dayOnly(now ?? DateTime.now());
    if (serie.isEmpty) return TrainingLoadState.empty(reference);

    final TrainingLoadPoint ultimo = serie.last;

    // Carico delle ultime sette giornate, in punti: serve per dire "questa
    // settimana" in una frase, che e' piu' leggibile della media al giorno.
    double settimana = 0;
    for (int i = serie.length - 1; i >= 0 && i > serie.length - 8; i--) {
      settimana += serie[i].load;
    }

    DateTime? ultimoCarico;
    for (final TrainingLoadPoint p in serie) {
      if (p.load > 0) ultimoCarico = p.date;
    }

    return TrainingLoadState(
      date: reference,
      fatigue: _arrotonda(ultimo.fatigue),
      fitness: _arrotonda(ultimo.fitness),
      weekLoad: settimana,
      historyDays: serie.length,
      lastLoadDay: ultimoCarico,
    );
  }

  /// Fatica e condizione giorno per giorno.
  ///
  /// PERCHE' SERVE LA SERIE E NON SOLO IL NUMERO DI OGGI
  /// --------------------------------------------------
  /// "Condizione 48, fatica 52" non dice niente da solo. Quello che conta e'
  /// la direzione: 48 dopo essere stato a 30 e' una storia, 48 dopo essere
  /// stato a 65 e' la storia opposta, e il numero di oggi e' identico nelle
  /// due. Il grafico e' l'unico modo di far vedere la differenza.
  ///
  /// [days] = 0 restituisce tutta la storia; un numero restituisce solo gli
  /// ultimi giorni, ma il calcolo parte sempre dal primo allenamento: le medie
  /// esponenziali hanno memoria, e partire tre mesi fa da zero direbbe che a
  /// gennaio eri fermo anche se correvi da due anni.
  List<TrainingLoadPoint> seriesFor(
    List<RunningActivity> activities,
    TrainingZones? zones, {
    DateTime? now,
    int days = 90,
  }) {
    final DateTime reference = _dayOnly(now ?? DateTime.now());
    if (zones == null) return const <TrainingLoadPoint>[];

    // Carico per giorno.
    final Map<DateTime, double> perDay = <DateTime, double>{};
    DateTime? primo;
    for (final RunningActivity a in activities) {
      final double? carico = loadOf(a, zones);
      if (carico == null || carico <= 0) continue;
      final DateTime giorno = _dayOnly(a.startTime);
      if (giorno.isAfter(reference)) continue;
      perDay[giorno] = (perDay[giorno] ?? 0) + carico;
      if (primo == null || giorno.isBefore(primo)) primo = giorno;
    }

    if (perDay.isEmpty || primo == null) return const <TrainingLoadPoint>[];

    // Medie esponenziali, un giorno alla volta dal primo allenamento a oggi.
    //
    // Si cammina giorno per giorno invece di sommare e dividere perche' i
    // giorni di riposo contano: e' li' che la fatica scende. Una media fatta
    // solo sui giorni in cui hai corso direbbe che sei sempre stanco uguale.
    final double kFatica = 1 - math.exp(-1 / fatigueDays);
    final double kCondizione = 1 - math.exp(-1 / fitnessDays);

    final DateTime? daMostrare = days <= 0
        ? null
        : reference.subtract(Duration(days: days - 1));

    double fatica = 0;
    double condizione = 0;
    final List<TrainingLoadPoint> out = <TrainingLoadPoint>[];
    DateTime giorno = primo;
    while (!giorno.isAfter(reference)) {
      final double carico = perDay[giorno] ?? 0;
      fatica += (carico - fatica) * kFatica;
      condizione += (carico - condizione) * kCondizione;

      if (daMostrare == null || !giorno.isBefore(daMostrare)) {
        out.add(TrainingLoadPoint(
          date: giorno,
          load: carico,
          fatigue: fatica,
          fitness: condizione,
        ));
      }
      giorno = giorno.add(const Duration(days: 1));
    }
    return out;
  }

  /// Arrotonda a una cifra: la falsa precisione confonde e basta.
  static double _arrotonda(double value) =>
      double.parse(value.toStringAsFixed(1));

  static DateTime _dayOnly(DateTime d) => DateTime(d.year, d.month, d.day);
}

class _Slice {
  const _Slice(this.seconds, this.intensity);
  final double seconds;
  final double intensity;
}

/// Un giorno nella storia del carico.
class TrainingLoadPoint {
  const TrainingLoadPoint({
    required this.date,
    required this.load,
    required this.fatigue,
    required this.fitness,
  });

  final DateTime date;

  /// Punti di carico fatti in questo giorno. Zero nei giorni di riposo, che
  /// sono quelli in cui la fatica scende.
  final double load;

  final double fatigue;
  final double fitness;

  /// Condizione meno fatica: positiva quando si e' riposati.
  double get freshness => fitness - fatigue;
}

/// Dove sei: quanto sei stanco, quanto sei allenato, e la differenza.
class TrainingLoadState {
  const TrainingLoadState({
    required this.date,
    required this.fatigue,
    required this.fitness,
    required this.weekLoad,
    required this.historyDays,
    required this.lastLoadDay,
  });

  factory TrainingLoadState.empty(DateTime date) => TrainingLoadState(
        date: date,
        fatigue: 0,
        fitness: 0,
        weekLoad: 0,
        historyDays: 0,
        lastLoadDay: null,
      );

  final DateTime date;

  /// Carico medio giornaliero degli ultimi ~7 giorni: quanto sei stanco.
  final double fatigue;

  /// Carico medio giornaliero degli ultimi ~28 giorni: quanto sei allenato.
  final double fitness;

  /// Punti di carico accumulati negli ultimi 7 giorni di calendario.
  final double weekLoad;

  /// Da quanti giorni l'archivio ha allenamenti dentro.
  final int historyDays;

  final DateTime? lastLoadDay;

  bool get isEmpty => historyDays <= 0;

  /// Freschezza: condizione meno fatica.
  ///
  /// Positiva = sei riposato rispetto a quanto ti alleni di solito.
  /// Negativa = stai portando piu' carico del tuo normale.
  double get freshness =>
      double.parse((fitness - fatigue).toStringAsFixed(1));

  /// Rapporto fra carico recente e carico abituale.
  ///
  /// Sopra 1,3 il carico sta salendo piu' in fretta di quanto il corpo si
  /// adatti: e' la soglia oltre la quale, nei lavori sugli infortuni negli
  /// sport di squadra, il rischio cresce in modo netto. Sotto 0,8 si sta
  /// scaricando.
  double? get loadRatio {
    if (fitness <= 1) return null;
    return double.parse((fatigue / fitness).toStringAsFixed(2));
  }

  /// Quanto ci si puo' fidare di questi numeri.
  ///
  /// Con pochi giorni di storico la media lunga non ha ancora senso: non e'
  /// che il numero sia sbagliato, e' che non significa niente. Dirlo e' parte
  /// del lavoro.
  double get confidence {
    if (historyDays <= 0) return 0;
    // Serve almeno un mese perche' la media a 28 giorni sia piena.
    final double quota = historyDays / fitnessDaysForConfidence;
    return quota.clamp(0.0, 1.0);
  }

  static const double fitnessDaysForConfidence = 28;

  bool get isReliable => confidence >= 0.6;

  /// Una riga che dice dove sei, senza numeri.
  String get headline {
    if (isEmpty) return 'Non ci sono ancora allenamenti da cui misurare.';
    if (!isReliable) {
      return 'Sto ancora imparando il tuo carico abituale: servono circa '
          'quattro settimane di corse registrate.';
    }
    final double? ratio = loadRatio;
    if (ratio == null) return 'Carico in costruzione.';
    if (ratio >= 1.35) {
      return 'Stai caricando molto piu\' del tuo solito: e\' la fase in cui '
          'ci si fa male.';
    }
    if (ratio >= 1.15) return 'Stai caricando piu\' del solito.';
    if (ratio <= 0.75) return 'Sei in scarico: il carico e\' sotto il tuo solito.';
    return 'Carico in linea con il tuo solito.';
  }

  /// Stima con confidenza, per chi la vuole nel formato del resto dell'app.
  Estimate<double> get freshnessEstimate => Estimate<double>(
        value: freshness,
        confidence: confidence,
        source: EstimateSource.derived,
        updatedAt: date,
      );
}
