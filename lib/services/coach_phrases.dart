import 'dart:math';

import '../models/user_settings.dart';

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
  CoachPhrases(this.personality, {Random? random})
      : _random = random ?? Random();

  final CoachPersonality personality;
  final Random _random;

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
        normal: <String>['Partenza.'],
        motivational: <String>[
          'Partenza! Buon allenamento.',
          'Si parte. Goditela.',
        ],
        sergeant: <String>[
          'Si parte. Niente scuse.',
          'Partenza. Voglio vedere impegno.',
        ],
      ));

  String freeRunStart() => _pick(_byPersonality(
        normal: <String>['Corsa libera avviata.'],
        motivational: <String>['Corsa libera. Divertiti e resta sciolto.'],
        sergeant: <String>['Corsa libera. Vediamo cosa sai fare.'],
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

  String workoutCompleted() => _pick(_byPersonality(
        normal: <String>['Allenamento completato.'],
        motivational: <String>[
          'Allenamento completato. Ottimo lavoro!',
          'Fatto! Grande allenamento.',
        ],
        sergeant: <String>[
          'Allenamento completato. Per oggi puo\' bastare.',
          'Finito. Non era male.',
        ],
      ));

  // ------------------------------------------------------------------- lap
  String lapCompleted({
    required int lapNumber,
    required String distanceLabel,
    required String timeLabel,
    required String paceLabel,
  }) =>
      'Giro $lapNumber. $distanceLabel in $timeLabel. Passo $paceLabel al chilometro.';

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
