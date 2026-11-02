/// Le chilocalorie di una corsa.
///
/// DA DOVE VIENE IL CONTO
/// ----------------------
/// Dalle equazioni dell'American College of Sports Medicine (ACSM), le stesse
/// che usano i laboratori per i test da sforzo. Dicono quanto ossigeno costa
/// spostare un chilo di corpo:
///
///   corsa:     0,2 ml per metro in piano + 0,9 ml per metro di salita
///   cammino:   0,1 ml per metro in piano + 1,8 ml per metro di salita
///   e in piu', sempre, 3,5 ml al minuto: e' quello che si consuma da fermi.
///
/// Un litro di ossigeno vale circa 5 chilocalorie. Il risultato e' il famoso
/// "un chilocaloria per chilo per chilometro", ma calcolato e non a memoria:
/// per 70 kg e 7 km in 40 minuti fanno circa 540 kcal.
///
/// PERCHE' NON SERVE LA FASCIA CARDIO
/// ----------------------------------
/// Perche' correndo il costo di un chilometro dipende poco dal passo: si
/// sposta lo stesso peso per la stessa strada. Va piu' forte, finisce prima;
/// il conto torna simile. Quello che conta davvero e' il peso, ed e' l'unico
/// dato che l'app chiede. Una fascia renderebbe il numero piu' personale, non
/// cambierebbe l'ordine di grandezza.
///
/// QUANTO CI SI PUO' FIDARE
/// ------------------------
/// E' una stima, giusta entro un dieci per cento per la maggior parte delle
/// persone. Anche gli orologi stimano: non misurano le calorie, le
/// calcolano con formule di questo tipo. Il numero e' "lordo": include quello
/// che avresti consumato comunque stando fermo.
///
/// LA DISCESA NON SI TOGLIE
/// ------------------------
/// L'ACSM non dice di sottrarre niente in discesa, e chi la corre sa perche':
/// frenare costa. Si conta solo la salita.
class CalorieEstimate {
  const CalorieEstimate._();

  /// Sotto questa velocita' (8 km/h, cioe' 7:30 al km) si sta camminando, e
  /// l'equazione della corsa sovrastimerebbe.
  static const double runningMetersPerMinute = 134;

  /// Pesi fuori da questo intervallo sono quasi certamente un errore di
  /// battitura: meglio non dire niente che dire un numero sbagliato.
  static const double minWeightKg = 30;
  static const double maxWeightKg = 250;

  /// Chilocalorie per litro di ossigeno.
  static const double kcalPerLiterO2 = 5.0;

  /// Le chilocalorie stimate. `null` se manca il peso o se i dati non
  /// bastano: un numero inventato sarebbe peggio di nessun numero.
  static int? kcal({
    required double? weightKg,
    required double meters,
    required int seconds,
    double climbMeters = 0,
  }) {
    final double? kg = weightKg;
    if (kg == null || kg < minWeightKg || kg > maxWeightKg) return null;
    if (meters <= 0 || seconds <= 0) return null;

    final double minuti = seconds / 60.0;
    final double velocita = meters / minuti;
    final double salita = climbMeters > 0 ? climbMeters : 0;

    final bool corsa = velocita >= runningMetersPerMinute;
    final double perMetro = corsa ? 0.2 : 0.1;
    final double perMetroDiSalita = corsa ? 0.9 : 1.8;

    // Millilitri di ossigeno per chilo, su tutta l'uscita.
    final double ossigeno =
        perMetro * meters + perMetroDiSalita * salita + 3.5 * minuti;

    final double litri = ossigeno * kg / 1000.0;
    return (litri * kcalPerLiterO2).round();
  }
}
