import 'dart:math' as math;

import '../models/running_activity.dart';
import 'elevation_service.dart';
import 'route_windows.dart';

/// Come e' andata la corsa, metro per metro: il passo e la quota.
///
/// PERCHE' SERVE UN GRAFICO E NON BASTANO I PARZIALI
/// -------------------------------------------------
/// La tabella dei giri dice il passo di ogni chilometro, e va benissimo per un
/// lento regolare. Non serve a niente per capire **dentro** un chilometro: una
/// ripetuta da 400 metri sparisce nella media del suo chilometro, un calo negli
/// ultimi due minuti pure, e una salita che ti ha fatto perdere venti secondi
/// sembra una giornata storta.
///
/// Il grafico mostra quello che la media nasconde per costruzione. E messo
/// sopra il profilo altimetrico, le due cose si spiegano a vicenda: si vede il
/// passo che cede esattamente dove la strada sale, e si capisce che non era una
/// giornata storta, era in pendenza.
///
/// DA DOVE VENGONO I NUMERI
/// ------------------------
/// Da [RouteWindows] e da [ElevationService], cioe' **dagli stessi conti** che
/// producono la distanza, il dislivello, l'intensita' della seduta e il carico.
/// Un grafico che si calcolasse i suoi numeri per conto proprio prima o poi
/// mostrerebbe una corsa diversa da quella scritta sopra, ed e' l'errore che
/// questo progetto ha gia' fatto quattro volte.
class RunProfile {
  const RunProfile._();

  /// Quanti punti al massimo finiscono nel disegno.
  ///
  /// PERCHE' UN TETTO, E PERCHE' PROPRIO QUI
  /// ---------------------------------------
  /// Un'ora di corsa fa centocinquanta finestre da venti secondi. Su un
  /// telefono il grafico e' largo poco piu' di trecento pixel: disegnarle tutte
  /// vuol dire **due pixel a punto**, cioe' mostrare un dettaglio che nessuno
  /// puo' vedere.
  ///
  /// E quel dettaglio invisibile non e' neutro: su una corsa misurata dalle
  /// posizioni e' quasi tutto rumore del GPS. Il risultato e' un pettine fitto
  /// che su un lento a passo costante va da 3:16 a 5:33 - e chi lo guarda non
  /// legge "il GPS balla", legge "sono andato a strappi". Un grafico che
  /// trasforma l'errore di misura in un giudizio sull'atleta e' peggio di
  /// nessun grafico.
  ///
  /// Settanta punti sono circa cinque pixel l'uno: la risoluzione piu' fine che
  /// un occhio distingue davvero su quello schermo.
  static const int defaultMaxSamples = 70;

  /// Il profilo di una corsa. Vuoto se non c'e' abbastanza tracciato.
  static List<ProfileSample> of(
    List<RoutePoint> route, {
    int maxSamples = defaultMaxSamples,
  }) {
    final List<RouteWindow> finestre =
        _raggruppa(RouteWindows.of(route), maxSamples);
    if (finestre.isEmpty) return const <ProfileSample>[];

    final List<double?> quote = const ElevationService().smoothedAltitudes(route);

    final List<ProfileSample> out = <ProfileSample>[];
    double percorsi = 0;
    for (final RouteWindow f in finestre) {
      percorsi += f.meters;
      out.add(ProfileSample(
        meters: percorsi,
        paceSecondsPerKm: f.paceSecondsPerKm,
        altitude: f.endIndex < quote.length ? quote[f.endIndex] : null,
        fromSpeed: f.fromSpeed,
        cadenceStepsPerMinute: f.cadenceStepsPerMinute,
      ));
    }
    return out;
  }

  /// Unisce finestre vicine finche' non ci stanno nel disegno.
  ///
  /// Si sommano **i secondi e i metri**, non si fa la media dei passi: un
  /// chilometro corso in due minuti e uno corso in sei non fanno "quattro
  /// minuti al chilometro" a meta' strada, fanno otto minuti per due
  /// chilometri. Sommare prima e dividere dopo e' la stessa cosa che fare una
  /// finestra piu' lunga - cioe' esattamente quello che serve.
  static List<RouteWindow> _raggruppa(List<RouteWindow> f, int massimo) {
    if (massimo <= 0 || f.length <= massimo) return f;
    final int quante = (f.length / massimo).ceil();

    final List<RouteWindow> out = <RouteWindow>[];
    for (int i = 0; i < f.length; i += quante) {
      final int fine = math.min(i + quante, f.length);
      double secondi = 0;
      double metri = 0;
      int daVelocita = 0;
      // I passi si sommano solo se li hanno TUTTE le finestre del gruppo. Con
      // un buco in mezzo la somma direbbe "meno passi in piu' tempo", cioe'
      // una cadenza bassa che non e' mai esistita: meglio non dire niente.
      int passi = 0;
      bool passiCompleti = true;
      for (int k = i; k < fine; k++) {
        secondi += f[k].seconds;
        metri += f[k].meters;
        if (f[k].fromSpeed) daVelocita++;
        final int? p = f[k].steps;
        if (p == null) {
          passiCompleti = false;
        } else {
          passi += p;
        }
      }
      out.add(RouteWindow(
        seconds: secondi,
        meters: metri,
        fromSpeed: daVelocita * 2 >= (fine - i),
        endIndex: f[fine - 1].endIndex,
        steps: passiCompleti ? passi : null,
      ));
    }
    return out;
  }

  /// `true` se il passo disegnato viene dalla velocita' del chip.
  ///
  /// Serve a dirlo nel grafico: una corsa registrata prima che Falcata usasse
  /// la velocita' ha una linea piu' mossa, e senza una riga che lo spieghi
  /// sembra che quel giorno si fosse corso a strappi.
  static bool mostlyFromSpeed(List<ProfileSample> profilo) {
    if (profilo.isEmpty) return false;
    final int buoni =
        profilo.where((ProfileSample s) => s.fromSpeed).length;
    return buoni * 2 >= profilo.length;
  }

  /// Sotto questo numero di punti non c'e' un andamento da disegnare: sarebbe
  /// una linea con tre spigoli, che non dice niente e sembra un difetto.
  static const int minimumSamples = 8;

  static bool canDraw(List<ProfileSample> profilo) =>
      profilo.where((ProfileSample s) => s.paceSecondsPerKm != null).length >=
      minimumSamples;

  /// `true` se almeno un punto ha la quota: senza, il profilo altimetrico non
  /// si disegna e il passo si prende tutto lo spazio.
  static bool hasAltitude(List<ProfileSample> profilo) =>
      profilo.any((ProfileSample s) => s.altitude != null);

  /// `true` se vale la pena disegnare il riquadro della cadenza.
  ///
  /// Non basta UN punto come per la quota: una cadenza fatta di tre spigoli in
  /// mezzo al vuoto non e' un andamento, e' un difetto. Serve che almeno un
  /// terzo dei punti ce l'abbia.
  static bool hasCadence(List<ProfileSample> profilo) {
    if (profilo.length < minimumSamples) return false;
    final int quanti = profilo
        .where((ProfileSample s) => s.cadenceStepsPerMinute != null)
        .length;
    return quanti * 3 >= profilo.length;
  }
}

/// Un punto del profilo: a che chilometro si era, a che passo si andava, a che
/// quota si stava.
class ProfileSample {
  const ProfileSample({
    required this.meters,
    required this.paceSecondsPerKm,
    required this.altitude,
    this.fromSpeed = false,
    this.cadenceStepsPerMinute,
  });

  /// Metri percorsi dall'inizio.
  final double meters;

  /// `null` dove il passo non si puo' dire: una sosta, un buco di segnale.
  /// Nel grafico diventa un'interruzione della linea, non uno zero - una linea
  /// che scende a zero direbbe "fermo a passo infinito", che non e' quello che
  /// e' successo.
  final double? paceSecondsPerKm;

  final double? altitude;

  /// `true` se il passo viene dalla velocita' del chip e non dalle posizioni.
  final bool fromSpeed;

  /// La cadenza in quel punto, in passi al minuto. `null` dove non si sa: non
  /// uno zero, che vorrebbe dire "non appoggiava i piedi".
  final double? cadenceStepsPerMinute;
}
