import '../models/running_activity.dart';
import 'cadence.dart';
import 'gps_filter.dart';

/// Il tracciato di una corsa, diviso in finestre di tempo con i metri fatti.
///
/// PERCHE' ESISTE UN FILE SOLO PER QUESTO
/// --------------------------------------
/// Perche' lo stesso conto era scritto due volte: nel classificatore, che
/// decide se una seduta e' stata soglia o lento, e nel motore del carico, che
/// decide quanto e' costata. Due copie della stessa funzione, scritte in
/// momenti diversi, che prima o poi divergono - e' gia' successo tre volte in
/// questo progetto (il piano che leggeva un indice diverso da quello della
/// schermata Forma, il trofeo che non sapeva dei personali dichiarati, la media
/// settimanale che non era quella del punto di partenza).
///
/// Qui diventa una strada sola, e correggerla significa correggerla per tutti.
///
/// DA DOVE VENGONO I METRI
/// -----------------------
/// Questo e' il motivo vero per cui il file e' stato scritto adesso.
///
/// La distanza di una corsa non si misura piu' dalle posizioni ma dalla
/// **velocita' che il chip ricava dall'effetto Doppler** - una misura diretta,
/// precisa a qualche decimo di metro al secondo anche quando la posizione balla
/// di dieci metri (vedi [GpsFilter], dove il metodo vecchio sbagliava dal 2
/// all'8% su una corsa intera, con il segno che cambiava secondo il tipo di
/// seduta).
///
/// Ma a corsa finita l'app rilegge il tracciato per capire che seduta e' stata,
/// e lo faceva **misurando il passo dalle posizioni** - lo stesso difetto, un
/// passo piu' in la'. Misurato con un errore GPS realistico (che deriva piano
/// invece di cambiare a ogni secondo), su ripetute con passo vero 3:50/km sul
/// forte e 6:00/km sul recupero, le finestre lette dalle posizioni davano
/// **3:47 / 5:38** contro i **3:52 / 5:54** lette dalla velocita'. Pochi
/// secondi, ma sempre nella stessa direzione: il forte sembra piu' veloce e il
/// recupero pure, cioe' la seduta sembra piu' dura di com'e' stata. Nel motore
/// del carico quello scarto viene elevato al quadrato.
///
/// Adesso, se i punti portano con se' la velocita' del chip, i metri sono la
/// somma di velocita' per tempo. Altrimenti - tracciati vecchi, telefoni che
/// non la riportano - si torna alle posizioni, che e' il comportamento di
/// prima: peggio, ma mai peggio di prima.
class RouteWindows {
  const RouteWindows._();

  /// Durata di una finestra, in secondi.
  ///
  /// Venti secondi smorzano il rumore e restano abbastanza corti da vedere una
  /// ripetuta. E' lo stesso valore in tutti e due i motori, e adesso e' scritto
  /// in un posto solo.
  static const int defaultWindowSeconds = 20;

  /// Quanta parte dei punti di una finestra deve avere la velocita' del chip
  /// perche' la finestra si fidi di quella.
  ///
  /// Meta'. Sotto, la somma avrebbe dei buchi coperti a caso e sarebbe peggio
  /// di una misura coerente, anche se piu' rumorosa.
  static const double minSpeedShare = 0.5;

  /// Divide il tracciato in finestre consecutive.
  ///
  /// Le finestre escono **in ordine**, ed e' una parte del contratto: e' quello
  /// che permette di distinguere un minuto di lavoro continuo da tre finestre
  /// veloci sparse in mezz'ora.
  static List<RouteWindow> of(
    List<RoutePoint> route, {
    int windowSeconds = defaultWindowSeconds,
  }) {
    final List<RouteWindow> out = <RouteWindow>[];
    if (route.length < 2) return out;

    int inizio = 0;
    double metriDaPosizione = 0;
    double metriDaVelocita = 0;
    int conVelocita = 0;
    int passi = 0;

    for (int i = 1; i < route.length; i++) {
      final RoutePoint prima = route[i - 1];
      final RoutePoint adesso = route[i];

      final int dt = adesso.elapsedSeconds - prima.elapsedSeconds;
      passi++;

      final double passo = haversineMeters(
        prima.latitude,
        prima.longitude,
        adesso.latitude,
        adesso.longitude,
      );
      if (passo.isFinite) metriDaPosizione += passo;

      // La velocita' del punto vale per il tratto che lo precede.
      final double? v = adesso.speed;
      if (v != null && v.isFinite && v >= 0 && dt > 0) {
        metriDaVelocita += v * dt;
        conVelocita++;
      }

      final int trascorsi = adesso.elapsedSeconds - route[inizio].elapsedSeconds;
      if (trascorsi < windowSeconds) continue;

      final bool fidatiDellaVelocita =
          passi > 0 && conVelocita / passi >= minSpeedShare;

      // I passi della finestra: la differenza fra il totale di adesso e quello
      // di quando la finestra si e' aperta. Si somma solo se entrambi i punti
      // li hanno - su una corsa senza cadenza restano `null` e il grafico
      // semplicemente non la disegna.
      final int? passiInizio = route[inizio].steps;
      final int? passiFine = adesso.steps;
      final int? passiFinestra =
          (passiInizio != null && passiFine != null && passiFine >= passiInizio)
              ? passiFine - passiInizio
              : null;

      out.add(RouteWindow(
        seconds: trascorsi.toDouble(),
        meters: fidatiDellaVelocita ? metriDaVelocita : metriDaPosizione,
        fromSpeed: fidatiDellaVelocita,
        endIndex: i,
        steps: passiFinestra,
      ));

      inizio = i;
      metriDaPosizione = 0;
      metriDaVelocita = 0;
      conVelocita = 0;
      passi = 0;
    }

    return out;
  }
}

/// Una finestra di tracciato: quanto e' durata e quanti metri ci sono dentro.
class RouteWindow {
  const RouteWindow({
    required this.seconds,
    required this.meters,
    required this.fromSpeed,
    this.endIndex = 0,
    this.steps,
  });

  final double seconds;
  final double meters;

  /// `true` se i metri vengono dalla velocita' del chip (la misura buona).
  final bool fromSpeed;

  /// Posizione, dentro il tracciato, del punto in cui la finestra si chiude.
  ///
  /// Serve per appaiare la finestra a qualcosa che sta nel tracciato e non qui
  /// dentro - la quota, per esempio - senza rifare il conto di dove si era.
  final int endIndex;

  /// I passi fatti dentro la finestra. `null` se non si sanno: corsa
  /// registrata prima della cadenza, telefono senza sensore, permesso negato.
  final int? steps;

  /// Il passo della finestra, in secondi al chilometro.
  ///
  /// `null` quando non si puo' dire: troppo pochi metri, o un valore
  /// impossibile. Un passo impossibile non va messo in una zona a caso - va
  /// buttato, e la finestra resta come buco. E' quello che permette a una
  /// pausa di interrompere un blocco invece di saldare insieme due tratti
  /// veloci lontani fra loro.
  double? get paceSecondsPerKm {
    if (meters <= 5 || seconds <= 0) return null;
    final double pace = seconds / (meters / 1000.0);
    if (pace <= 100 || pace >= 1500) return null;
    return pace;
  }

  /// La cadenza della finestra, in passi al minuto. `null` se non si sa.
  ///
  /// Niente tetto di durata qui: una finestra da venti secondi e' corta per
  /// definizione, ed e' quello che serve per vedere la cadenza cedere dentro
  /// un chilometro. I limiti del verosimile - sotto i 100 e sopra i 240 - li
  /// mette [Cadence], in un posto solo.
  double? get cadenceStepsPerMinute {
    final int? p = steps;
    if (p == null) return null;
    return Cadence.spm(steps: p, seconds: seconds);
  }
}
