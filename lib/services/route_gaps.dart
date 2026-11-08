import '../models/running_activity.dart';

/// I tratti del tracciato che non sono corsa, e che chi misura sulle
/// posizioni deve saltare.
///
/// IL CASO VERO
/// ------------
/// Un riscaldamento corso chiacchierando con un amico: cronometro in pausa,
/// si continua a correre, poi START di nuovo. Il cronometro non ha contato
/// quei minuti - giusto - ma fra l'ultimo punto prima della pausa e il primo
/// dopo c'erano centinaia di metri fatti "in zero secondi". Il calcolo dei
/// record, che cerca il chilometro piu' veloce dentro il tracciato, li ha
/// trovati e li ha usati: 1 km in 2:27, 3 km in 12:01, 5 km in 21:32.
///
/// DUE REGOLE, PER LE CORSE NUOVE E PER QUELLE GIA' SALVATE
/// --------------------------------------------------------
///  1. Il primo punto dopo una pausa porta il segno [RoutePoint.resumed]: il
///     tratto che lo precede non si conta mai.
///  2. Le corse salvate prima del segno non ce l'hanno. Per quelle vale un
///     limite fisico: un tratto percorso a piu' di [maxMetersPerSecond] non
///     e' corsa. E' sopra il record del mondo dei 100 metri: nessun passo
///     vero lo supera, una pausa o un salto del GPS si'.
///
/// Il limite resta anche sulle corse nuove: un salto del GPS che sfugge al
/// filtro e' lo stesso tipo di errore.
class RouteGaps {
  const RouteGaps._();

  /// 12 metri al secondo, cioe' 43 km/h - 1:23 al km.
  static const double maxMetersPerSecond = 12.0;

  /// `true` se il tratto da [prima] a [dopo], lungo [metri], va saltato.
  static bool skip(RoutePoint prima, RoutePoint dopo, double metri) {
    if (dopo.resumed) return true;
    if (!metri.isFinite) return true;
    final int dt = dopo.elapsedSeconds - prima.elapsedSeconds;
    // Due punti con lo stesso tempo e metri in mezzo: "a tempo zero".
    // Si divide per almeno un secondo, cosi' un metro di rumore non pesa.
    final double secondi = dt < 1 ? 1.0 : dt.toDouble();
    return metri / secondi > maxMetersPerSecond;
  }
}
