import '../models/running_activity.dart';

/// La cadenza di corsa: quanti appoggi al minuto.
///
/// COSA E' E PERCHE' CONTA
/// ----------------------
/// Un passo e' un appoggio - piede destro, poi sinistro: due passi. Un corridore
/// adulto su un lento sta in genere fra i 150 e i 180 passi al minuto, e il
/// numero non dice se si va forte: dice **come** si va. Due persone allo stesso
/// passo, una a 155 e una a 175, stanno facendo due cose diverse: la prima fa
/// falcate piu' lunghe e sta piu' tempo in aria, la seconda appoggi piu' brevi
/// e piu' frequenti.
///
/// La cosa utile da guardare non e' il valore, e' la **costanza**. La cadenza di
/// una persona e' abbastanza sua e abbastanza stabile, e cambia poco fra lento
/// e medio; quando crolla negli ultimi chilometri di un lungo, quello e' il
/// segnale che l'appoggio si e' sfasciato per la stanchezza - e si vede nel
/// grafico molto prima che si veda nel passo, perche' il passo lo si tiene a
/// forza di volonta' e la cadenza no.
///
/// DA DOVE ARRIVA, E PERCHE' NON DAL GPS
/// -------------------------------------
/// Dal sensore di passo del telefono: accelerometri, dentro al telefono,
/// contati dal chip dei sensori. Non c'entrano niente i satelliti, i palazzi,
/// gli alberi. E' l'unica misura di questa app che il GPS non puo' sbagliare,
/// perche' il GPS non la fa.
///
/// QUANTO CI SI PUO' FIDARE
/// ------------------------
/// Il conteggio dei passi di un telefono e' bravo ma non perfetto: tende a
/// contarne qualcuno in meno, e quanto in meno dipende da dove sta il telefono
/// - in mano, in tasca, in fascia da braccio. Quindi una cadenza di 168 va
/// letta come "fra 165 e 172", e **confrontata con se stessa**, non con il
/// numero di un amico che corre con l'orologio.
///
/// PERCHE' UN FILE SOLO PER DUE FUNZIONI
/// -------------------------------------
/// Perche' la cadenza media serve in due posti - la scheda della corsa e il
/// grafico - e questo progetto ha gia' imparato quattro volte che due strade
/// che calcolano la stessa cosa finiscono per divergere. Qui c'e' una strada.
class Cadence {
  const Cadence._();

  /// Sotto questo valore non e' una corsa: e' una camminata, o il sensore che
  /// ha perso dei pezzi.
  static const double minimumSpm = 100.0;

  /// Sopra questo valore non e' un essere umano che corre: e' il telefono che
  /// sbatacchia in uno zaino e conta vibrazioni.
  static const double maximumSpm = 240.0;

  /// Meno di questo e qualsiasi media e' un caso: un minuto scarso di passi
  /// contati non e' la cadenza di una corsa.
  static const int minimumSeconds = 60;

  /// La cadenza media della corsa, in passi al minuto. `null` se non si sa.
  ///
  /// Si prendono il primo e l'ultimo punto che hanno i passi, e si divide la
  /// differenza per il tempo fra quei due. E' il conto giusto proprio perche'
  /// i passi sono cumulativi: non importa se in mezzo qualche punto non li ha.
  /// PERCHE' L'ULTIMO PUNTO NON E' SEMPRE L'ULTIMO
  /// ---------------------------------------------
  /// Si prende l'ultimo punto in cui il conteggio e' **cresciuto**, non
  /// l'ultimo punto che ha un numero.
  ///
  /// Succede che il sensore si fermi prima della corsa: Android chiude la
  /// schermata per fare posto in memoria, il telefono si mette in uno stato di
  /// risparmio spinto. Il conteggio resta allora congelato sull'ultimo valore
  /// letto, e i punti dopo portano tutti quel numero. Prendendo l'ultimo di
  /// quelli, la media diventerebbe "i passi di mezz'ora, divisi per un'ora" -
  /// una cadenza dimezzata, bassissima, e dall'aspetto perfettamente credibile.
  ///
  /// E' lo stesso errore della velocita' GPS zero letta come "sta fermo": un
  /// dato che manca travestito da dato che c'e'. Qui la coda congelata viene
  /// semplicemente lasciata fuori, e la media resta quella del tratto davvero
  /// misurato.
  static double? average(List<RoutePoint> route) {
    RoutePoint? primo;
    RoutePoint? ultimo;
    int? precedente;
    for (final RoutePoint punto in route) {
      final int? p = punto.steps;
      if (p == null) continue;
      if (primo == null) {
        primo = punto;
      } else if (precedente != null && p > precedente) {
        ultimo = punto;
      }
      precedente = p;
    }
    if (primo == null || ultimo == null) return null;

    final int passi = ultimo.steps! - primo.steps!;
    final int secondi = ultimo.elapsedSeconds - primo.elapsedSeconds;
    return averageOver(steps: passi, seconds: secondi);
  }

  /// `true` se questa corsa ha la cadenza: serve a decidere se mostrare il
  /// riquadro, non a calcolarla.
  static bool has(List<RoutePoint> route) => average(route) != null;

  /// I passi totali della corsa. `null` se non si sanno.
  ///
  /// E' il numero piu' concreto che esce da tutto questo: non una stima, non una
  /// media - quante volte un piede ha toccato terra.
  static int? totalSteps(List<RoutePoint> route) {
    int? primo;
    int? ultimo;
    for (final RoutePoint punto in route) {
      final int? p = punto.steps;
      if (p == null) continue;
      primo ??= p;
      ultimo = p;
    }
    if (primo == null || ultimo == null) return null;
    final int totale = ultimo - primo;
    return totale > 0 ? totale : null;
  }

  /// Passi al minuto da un numero di passi e un numero di secondi.
  ///
  /// `null` quando non si puo' dire o quando il risultato e' impossibile. Un
  /// valore impossibile non va mostrato "tanto per": una cadenza di 320
  /// sembrerebbe un dato, e invece e' il telefono che ha preso le buche della
  /// strada per appoggi.
  static double? spm({required int steps, required double seconds}) {
    if (seconds <= 0 || steps <= 0) return null;
    final double valore = steps / seconds * 60.0;
    if (valore < minimumSpm || valore > maximumSpm) return null;
    return valore;
  }

  /// La stessa cosa di [spm], ma con il tetto minimo di durata: per la media di
  /// una corsa intera un minuto e' il minimo sensato, per una finestra di venti
  /// secondi no.
  static double? averageOver({required int steps, required int seconds}) {
    if (seconds < minimumSeconds) return null;
    return spm(steps: steps, seconds: seconds.toDouble());
  }
}
