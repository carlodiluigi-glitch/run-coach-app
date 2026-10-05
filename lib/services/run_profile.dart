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

  /// Il profilo di una corsa. Vuoto se non c'e' abbastanza tracciato.
  static List<ProfileSample> of(List<RoutePoint> route) {
    final List<RouteWindow> finestre = RouteWindows.of(route);
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
      ));
    }
    return out;
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
}

/// Un punto del profilo: a che chilometro si era, a che passo si andava, a che
/// quota si stava.
class ProfileSample {
  const ProfileSample({
    required this.meters,
    required this.paceSecondsPerKm,
    required this.altitude,
  });

  /// Metri percorsi dall'inizio.
  final double meters;

  /// `null` dove il passo non si puo' dire: una sosta, un buco di segnale.
  /// Nel grafico diventa un'interruzione della linea, non uno zero - una linea
  /// che scende a zero direbbe "fermo a passo infinito", che non e' quello che
  /// e' successo.
  final double? paceSecondsPerKm;

  final double? altitude;
}
