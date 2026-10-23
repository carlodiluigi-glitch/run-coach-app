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

  // ------------------------------------------------- la cadenza lungo la corsa
  /// Base minima su cui misurare una cadenza locale, in secondi.
  ///
  /// Da trenta a novanta secondi il risultato non cambia: provato su un calo
  /// vero da 170 a 150 negli ultimi venti minuti, tutte e quattro le basi lo
  /// mostrano identico. Quarantacinque sta in mezzo - abbastanza lunga da
  /// reggere un contatore che consegna a lotti, abbastanza corta da vedere la
  /// cadenza cedere dentro un chilometro.
  static const int localBaselineSeconds = 45;

  /// Le letture VERE del contapassi: solo i punti in cui il numero e' cambiato.
  ///
  /// PERCHE' SERVE DISTINGUERLE DAI PUNTI DEL TRACCIATO
  /// --------------------------------------------------
  /// Perche' il contapassi del telefono non risponde a ogni secondo. Il chip
  /// accumula e **consegna a lotti**: il valore resta fermo per dieci,
  /// trenta, a volte sessanta secondi, poi salta in avanti di tutti i passi
  /// di quel tratto. Ogni punto del tracciato porta l'ultimo valore
  /// consegnato, quindi i punti hanno quasi sempre un numero - solo che fra
  /// due punti vicini quel numero spesso e' lo stesso.
  ///
  /// Qui si tengono solo i momenti in cui e' cambiato davvero. Fra due di
  /// quelli, passi e secondi sono tutti e due misurati: il rapporto e' la
  /// cadenza, esatta.
  static List<StepReading> readings(List<RoutePoint> route) {
    final List<StepReading> out = <StepReading>[];
    int? ultimo;
    for (final RoutePoint punto in route) {
      final int? p = punto.steps;
      if (p == null) continue;
      if (ultimo == null || p != ultimo) {
        out.add(StepReading(seconds: punto.elapsedSeconds, steps: p));
        ultimo = p;
      }
    }
    return out;
  }

  /// La cadenza attorno a un istante della corsa, in passi al minuto.
  ///
  /// DA DOVE NASCE QUESTO METODO
  /// ---------------------------
  /// Da un grafico della cadenza spezzettato: una corsa di 16 km a 164 passi
  /// al minuto - media giusta, 14.789 passi totali giusti - disegnata come
  /// cinque frammenti con il vuoto in mezzo.
  ///
  /// La causa non era il sensore. Era che la cadenza di ogni tratto si
  /// calcolava come "i passi apparsi in questa finestra, diviso la durata
  /// della finestra". Con un contatore che consegna a lotti quel conto non
  /// misura niente: dipende da quanti lotti capitano dentro la finestra, che
  /// e' un numero intero piccolo. Riprodotto al calcolatore, con lotti ogni
  /// 45 secondi: **un terzo dei punti fuori scala** (buttati, da cui i
  /// buchi), e quelli rimasti a 122 o 185 invece di 164.
  ///
  /// E il difetto era peggio dei buchi. Anche con lotti ogni 15 o 25 secondi,
  /// dove nessun punto veniva buttato, il grafico mostrava una cadenza che
  /// ballava fra 123 e 206 su una corsa tenuta a 164 fissi. Chi lo guardava
  /// non leggeva "il sensore consegna a lotti", leggeva "la mia cadenza va a
  /// strappi".
  ///
  /// COME SI MISURA INVECE
  /// ---------------------
  /// Fra due **letture vere**, con i loro tempi veri, su una base di almeno
  /// [localBaselineSeconds]. Non importa quando il sensore ha consegnato: se
  /// a una lettura il contatore diceva 3.000 e a quella 50 secondi dopo
  /// diceva 3.137, in quei 50 secondi si sono fatti 137 passi, punto.
  /// Rifatto il conto sugli stessi tracciati simulati: **nessun buco**, e
  /// valori fra 163 e 165 in tutti i casi.
  ///
  /// Resta `null` dove e' giusto: durante una sosta il contatore non cresce,
  /// la cadenza esce sotto il minimo e il grafico mostra il vuoto - che li'
  /// e' la risposta onesta.
  static double? at(
    List<StepReading> readings,
    int seconds, {
    int baseline = localBaselineSeconds,
  }) {
    if (readings.length < 2 || baseline <= 0) return null;

    final int half = baseline ~/ 2;
    int a = _lastNotAfter(readings, seconds - half);
    int b = _firstNotBefore(readings, seconds + half);
    if (b <= a) b = a + 1 < readings.length ? a + 1 : a;

    // Vicino all'inizio o alla fine la base sborda: ci si appoggia al bordo e
    // si allarga dall'altra parte. Una base spostata resta una misura vera;
    // una base corta no.
    while (readings[b].seconds - readings[a].seconds < baseline) {
      if (b < readings.length - 1) {
        b++;
      } else if (a > 0) {
        a--;
      } else {
        break;
      }
    }

    // NON SI MISURA DOVE NON SI E' MISURATO.
    //
    // Se il sensore si e' fermato a meta' corsa - schermo spento, risparmio
    // energetico spinto, permesso revocato - le letture finiscono li'. Senza
    // questo controllo, ogni punto successivo si appoggerebbe alle ultime due
    // letture disponibili e uscirebbe con la cadenza di allora: una linea
    // piatta e credibile su mezz'ora in cui non si e' contato niente.
    //
    // E' lo stesso errore della coda congelata in [average], un passo piu' in
    // la'. Fuori dal tratto davvero misurato la risposta e' il vuoto.
    final int inizio = readings[a].seconds;
    final int fine = readings[b].seconds;
    if (seconds < inizio - baseline || seconds > fine + baseline) return null;

    return spm(
      steps: readings[b].steps - readings[a].steps,
      seconds: (fine - inizio).toDouble(),
    );
  }

  /// Ultima lettura che non va oltre [seconds]. La prima, se non ce n'e'.
  static int _lastNotAfter(List<StepReading> readings, int seconds) {
    int low = 0;
    int high = readings.length - 1;
    int out = 0;
    while (low <= high) {
      final int mid = (low + high) ~/ 2;
      if (readings[mid].seconds <= seconds) {
        out = mid;
        low = mid + 1;
      } else {
        high = mid - 1;
      }
    }
    return out;
  }

  /// Prima lettura che non precede [seconds]. L'ultima, se non ce n'e'.
  static int _firstNotBefore(List<StepReading> readings, int seconds) {
    int low = 0;
    int high = readings.length - 1;
    int out = readings.length - 1;
    while (low <= high) {
      final int mid = (low + high) ~/ 2;
      if (readings[mid].seconds >= seconds) {
        out = mid;
        high = mid - 1;
      } else {
        low = mid + 1;
      }
    }
    return out;
  }
}

/// Un momento in cui il contapassi del telefono e' cambiato davvero.
///
/// Non un punto del tracciato: quelli hanno tutti un numero di passi, ma per
/// lunghi tratti e' lo stesso numero, perche' il sensore consegna a lotti.
/// Vedi [Cadence.readings].
class StepReading {
  const StepReading({required this.seconds, required this.steps});

  /// Secondi dall'inizio della corsa.
  final int seconds;

  /// Passi contati dall'inizio della corsa, cumulativi.
  final int steps;
}
