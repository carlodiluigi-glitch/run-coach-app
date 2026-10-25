import 'dart:math';

import '../models/user_settings.dart';
import '../utils/speech_formatters.dart';

/// Tutte le frasi del coach vocale, centralizzate in un unico posto.
///
/// Per aggiungere o modificare le frasi basta intervenire qui: la logica di
/// riproduzione (`AudioCoachService`) e quella dell'allenamento
/// (`WorkoutEngine`) non vanno toccate.
///
/// Le personalita' disponibili sono definite in [CoachPersonality]. Nessuna
/// frase fa riferimento a film, personaggi o marchi protetti, e nessuna
/// contiene insulti o contenuti discriminatori: il "Sergente" e' duro e
/// ironico, mai offensivo.
class CoachPhrases {
  CoachPhrases(this.personality, {Random? random, this.athleteName = ''})
      : _random = random ?? Random();

  final CoachPersonality personality;

  /// Il nome dell'atleta, se l'ha dato. Vuoto se ha preferito non dirlo.
  ///
  /// Viene usato **solo alla partenza**. Un coach che ti chiama per nome a
  /// ogni chilometro diventa insopportabile dopo dieci minuti: il nome serve
  /// a far capire che sta parlando a te, e per quello basta una volta.
  final String athleteName;

  final Random _random;

  /// ", Carlo" - oppure niente, se il nome non c'e'. Si incolla dentro la
  /// frase, non dopo: "Partenza, Carlo." suona come una persona, "Partenza.
  /// Carlo." suona come un elenco.
  String get _vocativo => athleteName.trim().isEmpty ? '' : ', ${athleteName.trim()}';

  String _pick(List<String> options) {
    if (options.isEmpty) return '';
    if (options.length == 1) return options.first;
    return options[_random.nextInt(options.length)];
  }

  List<String> _byPersonality({
    required List<String> normal,
    required List<String> motivational,
    required List<String> sergeant,
  }) {
    switch (personality) {
      case CoachPersonality.normal:
        return normal;
      case CoachPersonality.motivational:
        return motivational;
      case CoachPersonality.sergeant:
        return sergeant;
    }
  }

  // ------------------------------------------------------------------ avvio
  String start() => _pick(_byPersonality(
        normal: <String>[
          'Partenza$_vocativo.',
          'Si comincia$_vocativo.',
          'Via$_vocativo. Buon allenamento.',
        ],
        motivational: <String>[
          'Partenza$_vocativo! Buon allenamento.',
          'Si parte$_vocativo. Goditela.',
          'Eccoci$_vocativo. Questa e\' la parte facile: sei gia\' uscito.',
          'Via$_vocativo! Un passo alla volta.',
        ],
        sergeant: <String>[
          'Si parte$_vocativo. Niente scuse.',
          'Partenza$_vocativo. Voglio vedere impegno.',
          'In piedi e via$_vocativo. Il piano non si corre da solo.',
          'Si comincia$_vocativo. Vediamo se oggi fai sul serio.',
        ],
      ));

  String freeRunStart() => _pick(_byPersonality(
        normal: <String>[
          'Corsa libera avviata$_vocativo.',
          'Corsa libera$_vocativo. Registro tutto.',
          'Si parte$_vocativo. Nessun programma, solo chilometri.',
        ],
        motivational: <String>[
          'Corsa libera$_vocativo. Divertiti e resta sciolto.',
          'Corsa libera$_vocativo. Oggi decidi tu.',
          'Via$_vocativo. Ascolta le gambe e lascia andare la testa.',
        ],
        sergeant: <String>[
          'Corsa libera$_vocativo. Vediamo cosa sai fare.',
          'Nessun programma$_vocativo. Non e\' una scusa per passeggiare.',
          'Corsa libera$_vocativo. Decidi tu, ma decidi qualcosa.',
        ],
      ));

  // ------------------------------------------------ i primi metri
  /// Il richiamo a non partire forte, qualche centinaio di metri dopo il via.
  ///
  /// PERCHE' ESISTE
  /// --------------
  /// Perche' e' l'errore piu' comune di chi corre da solo, ed e' anche quello
  /// che nessuno gli fa notare. In gruppo qualcuno te lo dice; da soli i primi
  /// cinquecento metri si corrono sempre troppo forte, perche' le gambe sono
  /// fresche e il fiato non si e' ancora fatto sentire. Il conto arriva al
  /// settimo chilometro, quando sembra una giornata storta e invece era solo
  /// una partenza sbagliata.
  ///
  /// Arriva una volta sola, e presto: dopo e' tardi, il danno e' fatto.
  String doNotStartTooFast() => _pick(_byPersonality(
        normal: <String>[
          'Primi metri. Non partire forte: il tempo si guadagna alla fine.',
          'Tieni il freno adesso. Le gambe fresche ingannano.',
          'Parti piano. Oggi i conti si fanno all\'ultimo chilometro.',
        ],
        motivational: <String>[
          'Piano all\'inizio: cosi\' alla fine ne hai ancora.',
          'Non farti ingannare dalle gambe fresche. Il bello viene dopo.',
          'Tranquillo nei primi metri. Chi parte piano arriva forte.',
        ],
        sergeant: <String>[
          'Rallenta. Partire forte non e\' coraggio, e\' inesperienza.',
          'Freno. Tutti partono forte, quasi nessuno finisce bene.',
          'Piano adesso. Il conto lo paghi dopo, e lo paghi caro.',
        ],
      ));

  String paused() => 'Allenamento in pausa.';

  String resumed() => _pick(_byPersonality(
        normal: <String>['Riprendiamo.'],
        motivational: <String>['Si riparte, forza!'],
        sergeant: <String>['Pausa finita. Si riparte.'],
      ));

  String stopped() => 'Registrazione terminata.';

  // ------------------------------------------------------------------- step
  /// Annuncio di inizio fase, es. "Riscaldamento, quindici minuti."
  String stepStart({
    required String typeLabel,
    required String goalLabel,
    int? repetitionIndex,
    int? repetitionTotal,
  }) {
    final StringBuffer buffer = StringBuffer();
    buffer.write(typeLabel);
    if (repetitionIndex != null &&
        repetitionTotal != null &&
        repetitionTotal > 1) {
      buffer.write(', ripetizione $repetitionIndex di $repetitionTotal');
    }
    buffer.write(', $goalLabel.');
    return buffer.toString();
  }

  String go() => _pick(_byPersonality(
        normal: <String>['Vai.'],
        motivational: <String>['Vai! Dai il meglio.', 'Vai, ci sei!'],
        sergeant: <String>['Vai! Muoviti!', 'Vai. Adesso si fa sul serio.'],
      ));

  /// Countdown: 10, 5, 3, 2, 1 secondi.
  String countdown(int seconds) {
    switch (seconds) {
      case 10:
        return 'Tra dieci secondi si cambia.';
      case 5:
        return 'Cinque.';
      case 3:
        return 'Tre.';
      case 2:
        return 'Due.';
      case 1:
        return 'Uno.';
      default:
        return 'Tra $seconds secondi.';
    }
  }

  String lastMeters(int meters) => _pick(_byPersonality(
        normal: <String>['Ultimi $meters metri.'],
        motivational: <String>[
          'Ultimi $meters metri, tieni duro!',
          'Solo $meters metri, resisti!',
        ],
        sergeant: <String>[
          'Ultimi $meters metri. Non mollare adesso.',
          '$meters metri. Stringi i denti.',
        ],
      ));

  /// La frase di fine allenamento: un complimento e una coda che cambia.
  ///
  /// PERCHE' DUE PEZZI INVECE DI UNO
  /// -------------------------------
  /// Perche' il complimento e' questione di carattere - il sergente non dice
  /// "bravo" come il motivatore - mentre la coda e' questione di fatti, e i
  /// fatti sono gli stessi per tutti e tre. Tenendoli separati si ottengono
  /// decine di frasi diverse da due elenchi corti, invece di dover scrivere
  /// tre volte le stesse cose.
  ///
  /// E' il momento in cui l'atleta ascolta davvero: ha finito, e' contento, e
  /// sta ancora camminando. Sprecarlo con "allenamento completato" e basta
  /// era un peccato.
  String workoutCompleted() {
    final String complimento = _pick(_byPersonality(
      normal: <String>[
        'Allenamento completato.',
        'Seduta finita.',
        'Fatto.',
      ],
      motivational: <String>[
        'Allenamento completato. Ottimo lavoro!',
        'Fatto! Grande allenamento.',
        'Finito, e bene. Bravo.',
        'Chiuso. Questa te la sei guadagnata.',
      ],
      sergeant: <String>[
        'Allenamento completato. Per oggi puo\' bastare.',
        'Finito. Non era male.',
        'Fatto. Domani se ne riparla.',
        'Chiuso. Hai fatto il tuo.',
      ],
    ));
    return '$complimento ${_pick(_codeDiChiusura)}';
  }

  /// Le code della frase finale: meta' promemoria pratici, meta' mestiere.
  ///
  /// Niente qui dentro e' inventato per fare scena: il lento piano, il
  /// recupero che vale quanto il carico, la distribuzione ottanta-venti e la
  /// cadenza che cede prima del passo sono le stesse quattro cose su cui e'
  /// costruito il motore di allenamento di questa applicazione. Il coach dice
  /// a voce quello che il piano fa in silenzio.
  static const List<String> _codeDiChiusura = <String>[
    // -- promemoria pratici
    'Ricorda di bere: la sete arriva dopo, la disidratazione prima.',
    'Due minuti di allungamento adesso valgono piu\' di dieci domani.',
    'Segna come e\' andata: la fatica di oggi spiega la corsa di giovedi\'.',
    'Controlla i chilometri delle scarpe, ogni tanto.',
    'Mangia qualcosa nella prossima mezz\'ora, se puoi.',
    // -- il mestiere
    'Il lento serve a costruire il motore, non a stancarti: quando e\' lento, corrilo piano davvero.',
    'Il recupero non e\' tempo perso: l\'adattamento avviene adesso, non durante.',
    'Quello che conta non e\' la singola seduta, e\' la somma di tre settimane.',
    'Piano quasi sempre e forte ogni tanto: il medio tutti i giorni e\' l\'errore piu\' comune.',
    'Quando sei stanco la cadenza cede prima del passo: e\' il segnale piu\' onesto che hai.',
    'Un giorno storto non cancella un mese buono.',
    'Dormire e\' la parte dell\'allenamento che nessuno si ricorda di fare.',
  ];

  // ------------------------------------------------------------------- lap
  /// Annuncio di fine giro.
  ///
  /// Le etichette arrivano gia' in forma pronunciabile da
  /// `utils/speech_formatters.dart` (es. "cinque e ventitre al chilometro"):
  /// qui si compone solo la frase.
  ///
  /// [paceLabel] puo' essere `null` quando il passo non e' attendibile: in quel
  /// caso non viene annunciato nessun numero, invece di inventarlo.
  String lapCompleted({
    required int lapNumber,
    required String distanceLabel,
    required String timeLabel,
    String? paceLabel,
  }) {
    final StringBuffer buffer = StringBuffer();
    buffer.write('Giro $lapNumber. $distanceLabel in $timeLabel.');
    if (paceLabel != null) {
      buffer.write(' Passo $paceLabel.');
    }
    return buffer.toString();
  }

  /// L'annuncio completo di fine giro.
  ///
  /// PERCHE' NON DICE PIU' "PASSO CINQUE E DIECI" DOPO "UN CHILOMETRO IN
  /// CINQUE E DIECI"
  /// -------------------------------------------------------------------
  /// Perche' su un giro da un chilometro quelle due frasi sono lo stesso
  /// numero detto due volte. Il passo si annuncia solo quando il giro **non**
  /// e' della lunghezza standard - un parziale chiuso a mano, una ripetuta da
  /// 400 metri - cioe' quando il tempo da solo non basta a capire l'andatura.
  ///
  /// PERCHE' IL CONFRONTO COL GIRO PRIMA VIENE SUBITO DOPO
  /// -----------------------------------------------------
  /// Perche' e' l'unica informazione su cui si puo' ancora agire. Il tempo del
  /// chilometro appena fatto e' storia; "quattro secondi piu' lento" dice cosa
  /// fare nel chilometro che comincia adesso, mentre si e' ancora in tempo.
  ///
  /// [deltaSeconds] e' positivo se questo giro e' stato **piu' lento**.
  /// La prima lettera maiuscola.
  ///
  /// Le etichette arrivano in minuscolo perche' nascono in mezzo a una frase
  /// ("in un chilometro"), ma qui a volte una frase ci comincia. Non cambia
  /// come suona - cambia che la frase e' scritta giusta, e un giorno queste
  /// stringhe finiranno anche sullo schermo.
  static String _maiuscola(String testo) {
    if (testo.isEmpty) return testo;
    return testo[0].toUpperCase() + testo.substring(1);
  }

  String lapFull({
    required int lapNumber,
    required String distanceLabel,
    required String timeLabel,
    required bool standardLength,
    String? paceLabel,
    double? deltaSeconds,
    String? totalDistanceLabel,
    String? totalTimeLabel,
    int? cadence,
    String? remainingLabel,
  }) {
    final StringBuffer b = StringBuffer();
    b.write('Giro $lapNumber. ${_maiuscola(distanceLabel)} in $timeLabel.');
    if (!standardLength && paceLabel != null) {
      b.write(' Passo $paceLabel.');
    }

    if (deltaSeconds != null) {
      final int scarto = deltaSeconds.round();
      // Sotto i due secondi non e' un cambio di passo, e' rumore: annunciarlo
      // farebbe correggere l'andatura a chi sta gia' andando giusto. Per
      // questo il singolare non serve: il numero piu' piccolo che esce e' due.
      if (scarto.abs() < 2) {
        b.write(' Stesso passo di prima.');
      } else if (scarto < 0) {
        b.write(' ${_maiuscola(spokenNumber(scarto.abs()))} secondi piu\' '
            'veloce.');
      } else {
        b.write(' ${_maiuscola(spokenNumber(scarto))} secondi piu\' lento.');
      }
    }

    if (cadence != null) {
      b.write(' Cadenza $cadence.');
    }

    if (totalDistanceLabel != null && totalTimeLabel != null) {
      b.write(' Totale $totalDistanceLabel in $totalTimeLabel.');
    }

    if (remainingLabel != null) {
      b.write(' $remainingLabel');
    }

    return b.toString();
  }

  /// Annuncio di fine fase in un allenamento programmato.
  ///
  /// Serve a sentire subito il tempo della ripetuta appena chiusa, senza
  /// guardare il telefono. Viene detto prima dell'annuncio della fase nuova.
  String stepCompleted({
    required String stepLabel,
    required String distanceLabel,
    required String timeLabel,
    String? paceLabel,
  }) {
    final StringBuffer buffer = StringBuffer();
    buffer.write('$stepLabel: $distanceLabel in $timeLabel.');
    if (paceLabel != null) {
      buffer.write(' Passo $paceLabel.');
    }
    return buffer.toString();
  }

  // ---------------------------------------------------------- avvisi ritmo
  String tooSlow() => _pick(_byPersonality(
        normal: <String>['Stai rallentando.'],
        motivational: <String>[
          'Stai rallentando, riprendi il ritmo!',
          'Un po\' piu\' di spinta, puoi farcela.',
        ],
        sergeant: <String>[
          'Muoviti, stai perdendo il ritmo.',
          'Questo passo non basta.',
          'Cosi\' non ci siamo. Accelera.',
        ],
      ));

  String tooFast() => _pick(_byPersonality(
        normal: <String>['Stai andando troppo forte.'],
        motivational: <String>[
          'Troppo veloce, gestisci le energie.',
          'Rallenta un attimo, ne avrai bisogno dopo.',
        ],
        sergeant: <String>[
          'Troppo forte. Cosi\' scoppi prima della fine.',
          'Frena. Non serve bruciarsi adesso.',
        ],
      ));

  String backOnTarget() => _pick(_byPersonality(
        normal: <String>['Ritmo corretto.'],
        motivational: <String>['Ritmo corretto, cosi\' va benissimo!'],
        sergeant: <String>['Ritmo corretto. Adesso tienilo.'],
      ));

  // ------------------------------------------------------ incoraggiamenti
  String encouragementRepetition(int index, int total) {
    final int left = total - index;
    if (left <= 0) return workoutCompleted();
    return _pick(_byPersonality(
      normal: <String>['Ripetizione $index di $total.'],
      motivational: <String>[
        'Ripetizione $index di $total, stai andando bene!',
        'Siamo a $index su $total, continua cosi\'!',
      ],
      sergeant: <String>[
        'Ripetizione $index di $total. Mancano $left ripetute.',
        'Forza, mancano solo $left ripetute.',
      ],
    ));
  }
}
