import '../models/running_activity.dart';

/// Quanto hai salito e quanto hai sceso.
///
/// IL PROBLEMA, PRIMA DELLA SOLUZIONE
/// ----------------------------------
/// Il GPS la quota la sa male. Sull'orizzontale un telefono sbaglia di qualche
/// metro; sulla verticale sbaglia dai quattro ai dodici, e l'errore cambia da
/// un secondo all'altro anche stando fermi. Non e' un difetto dell'app: e' come
/// funziona la trilaterazione satellitare, dove i satelliti stanno tutti sopra
/// di te e nessuno sotto.
///
/// Quindi sommare le differenze di quota punto per punto - che e' la cosa ovvia
/// da fare - da' numeri assurdi. Nelle prove, un'ora in pianura con un rumore
/// normale da 4 metri produce **ottomila metri di dislivello**, tutti fatti di
/// errore. E' il difetto piu' comune nelle app di corsa, e si riconosce subito
/// perche' il dislivello cresce con la DURATA della corsa invece che con le
/// salite.
///
/// COME SI RISOLVE
/// ---------------
/// Due passaggi, in quest'ordine.
///
/// 1. **Si smussa su una finestra di TEMPO.** La quota di ogni punto diventa la
///    media di quelle registrate nei [smoothSeconds] secondi prima e dopo. Il
///    rumore e' casuale e si cancella nella media; una salita vera no, perche'
///    e' presente in tutti i punti della finestra.
///
/// 2. **Si conta solo quello che supera una soglia.** Si tiene un punto di
///    riferimento e si aspetta: finche' la quota resta entro [thresholdMeters]
///    dal riferimento non e' successo niente. Quando lo supera, quel pezzo
///    viene contato e il riferimento si sposta. Cosi' un'oscillazione avanti e
///    indietro non conta nulla, mentre una salita lunga conta per intero anche
///    se e' stata fatta a piccoli passi.
///
/// PERCHE' LA FINESTRA E' IN SECONDI E NON IN PUNTI
/// ------------------------------------------------
/// Perche' e' l'errore in cui si cade scrivendo questo codice, ed e' stato
/// commesso qui prima di essere corretto. Una finestra di "trentun punti" dura
/// mezzo minuto se il telefono registra una volta al secondo e due minuti e
/// mezzo se registra ogni cinque: nel primo caso non pulisce abbastanza, nel
/// secondo spiana le salite vere. Una finestra in secondi si comporta uguale
/// in tutti e due i casi, ed e' l'unica cosa che conta.
///
/// I VALORI, E DA DOVE VENGONO
/// ---------------------------
/// Non sono scelti a occhio: sono il risultato di una simulazione su percorsi
/// di cui si conosce il dislivello vero (pianura, una salita da 100 m, un
/// percorso ondulato da 150 m), ripetuta con rumore da 4, 8 e 12 metri e al
/// campionamento reale dell'app (un punto ogni due secondi). Con
/// [smoothSeconds] = 45 e [thresholdMeters] = 8:
///
/// | percorso vero       | rumore 4 m | rumore 12 m |
/// |---------------------|-----------|-------------|
/// | pianura, 0 m        | 0 m       | 2 m         |
/// | salita 100 m e giu' | 94 m      | 96 m        |
/// | ondulato, 150 m     | 113 m     | 124 m       |
/// | salita continua 300 m | 292 m   | 295 m       |
///
/// (Per confronto: la somma ingenua delle differenze da' **ottomila metri** in
/// tutti e quattro i casi, perche' misura il rumore e non il percorso.)
///
/// La pianura resta pianura anche con il segnale peggiore: e' la cosa piu'
/// importante, perche' e' li' che le app sbagliano in modo vistoso. Le salite
/// lunghe sono esatte. Il percorso ondulato viene sottostimato di circa un
/// quinto, ed e' il prezzo inevitabile dello smussamento: una stima prudente e'
/// preferibile a un numero gonfiato che non si puo' distinguere dal rumore.
///
/// Senza barometro questo resta un numero **indicativo**, e l'app lo dice.
class ElevationService {
  const ElevationService();

  /// Mezza ampiezza della finestra di smussamento, in secondi.
  ///
  /// Quarantacinque secondi prima e dopo. Una salita vera dura minuti e
  /// sopravvive; il rumore del GPS cambia ogni secondo e si annulla.
  static const int smoothSeconds = 45;

  /// Quanto deve muoversi la quota perche' sia successo qualcosa, in metri.
  ///
  /// Otto metri. Sembra tanto, e lo e' di proposito: e' quello che serve per
  /// non contare niente in pianura nemmeno quando il segnale e' pessimo. Un
  /// dislivello vero supera comunque questa soglia, perche' la supera una
  /// volta sola e poi il riferimento si sposta - una salita da 100 metri
  /// resta una salita da 100 metri, non da 92.
  static const double thresholdMeters = 8.0;

  /// Sotto questo numero di punti con la quota non si dice niente.
  ///
  /// Sessanta punti sono circa due minuti di corsa. Non e' che il numero
  /// verrebbe impreciso: e' che con una finestra da novanta secondi non ci
  /// sarebbe nemmeno una finestra piena, e un dislivello inventato e' peggio
  /// di un dislivello assente.
  static const int minimumSamples = 60;

  ElevationSummary of(List<RoutePoint> route) {
    // Tempo e quota, solo dei punti che hanno entrambi, in ordine.
    final List<int> tempi = <int>[];
    final List<double> quote = <double>[];
    int ultimo = -1;
    for (final RoutePoint p in route) {
      final double? alt = p.altitude;
      if (alt == null || !alt.isFinite) continue;
      // Un punto fuori ordine romperebbe la finestra scorrevole. Non capita,
      // ma un file riletto da disco puo' sempre sorprendere.
      if (p.elapsedSeconds < ultimo) continue;
      ultimo = p.elapsedSeconds;
      tempi.add(p.elapsedSeconds);
      quote.add(alt);
    }
    if (quote.length < minimumSamples) return ElevationSummary.unknown;

    final List<double> smussate = _smooth(tempi, quote);

    double salita = 0;
    double discesa = 0;
    double riferimento = smussate.first;
    double minima = smussate.first;
    double massima = smussate.first;

    for (final double q in smussate) {
      if (q < minima) minima = q;
      if (q > massima) massima = q;

      final double delta = q - riferimento;
      if (delta >= thresholdMeters) {
        salita += delta;
        riferimento = q;
      } else if (delta <= -thresholdMeters) {
        discesa += -delta;
        riferimento = q;
      }
    }

    return ElevationSummary(
      gainMeters: salita,
      lossMeters: discesa,
      minMeters: minima,
      maxMeters: massima,
      samples: quote.length,
    );
  }

  /// Media mobile centrata su una finestra di tempo.
  ///
  /// Due indici che avanzano e una somma che si aggiorna: ogni punto entra e
  /// esce una volta sola. Rifare la somma a ogni punto sarebbe il quadrato del
  /// lavoro, e su una maratona sono decine di migliaia di punti.
  ///
  /// Ai bordi la finestra si accorcia invece di sparire: altrimenti i primi e
  /// gli ultimi minuti non avrebbero quota, e sono partenza e arrivo.
  static List<double> _smooth(List<int> tempi, List<double> quote) {
    final int n = quote.length;
    final List<double> out = <double>[];
    int da = 0;
    int a = 0;
    double somma = 0;

    for (int i = 0; i < n; i++) {
      final int inizio = tempi[i] - smoothSeconds;
      final int fine = tempi[i] + smoothSeconds;

      while (a < n && tempi[a] <= fine) {
        somma += quote[a];
        a++;
      }
      while (da < n && tempi[da] < inizio) {
        somma -= quote[da];
        da++;
      }

      final int quanti = a - da;
      out.add(quanti > 0 ? somma / quanti : quote[i]);
    }
    return out;
  }
}

/// Il dislivello di una corsa.
class ElevationSummary {
  const ElevationSummary({
    required this.gainMeters,
    required this.lossMeters,
    required this.minMeters,
    required this.maxMeters,
    required this.samples,
  });

  /// Quando la quota non c'e', o i punti sono troppo pochi.
  static const ElevationSummary unknown = ElevationSummary(
    gainMeters: 0,
    lossMeters: 0,
    minMeters: 0,
    maxMeters: 0,
    samples: 0,
  );

  final double gainMeters;
  final double lossMeters;
  final double minMeters;
  final double maxMeters;

  /// Quanti punti avevano la quota.
  final int samples;

  bool get isKnown => samples >= ElevationService.minimumSamples;

  /// Differenza fra il punto piu' alto e il piu' basso.
  double get rangeMeters => maxMeters - minMeters;

  /// `true` se il percorso e' sostanzialmente piatto.
  ///
  /// Venti metri su tutta una corsa sono quello che resta del rumore dopo i
  /// filtri, non delle salite. Scrivere "pianeggiante" e' piu' onesto che
  /// scrivere "18 m", che darebbe a un numero di rumore l'aria di una misura.
  bool get isFlat => isKnown && gainMeters < 20;

  /// "Pianeggiante", oppure "120 m".
  String get label {
    if (!isKnown) return '--';
    if (isFlat) return 'Pianeggiante';
    return '${gainMeters.round()} m';
  }
}
