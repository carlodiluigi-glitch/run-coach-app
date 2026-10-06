import 'package:flutter_test/flutter_test.dart';
import 'package:run_coach_app/models/user_settings.dart';
import 'package:run_coach_app/services/coach_phrases.dart';

/// Cosa dice la voce a fine giro.
///
/// DA DOVE NASCE QUESTO FILE
/// -------------------------
/// L'annuncio di fine giro diceva «Giro 3. Un chilometro in cinque e dieci.
/// Passo cinque e dieci.» - cioe' lo stesso numero due volte, perche' su un
/// giro da un chilometro il tempo *e'* il passo.
///
/// Adesso dice di piu' e si ripete di meno, e le regole che lo governano sono
/// tutte del tipo "in questo caso non dirlo". Sono esattamente le regole che
/// si perdono per strada riscrivendo una frase, quindi stanno qui.
void main() {
  final CoachPhrases frasi = CoachPhrases(CoachPersonality.normal);

  group('il giro da un chilometro', () {
    test('non ripete il passo quando il giro e\' quello standard', () {
      final String detto = frasi.lapFull(
        lapNumber: 3,
        distanceLabel: 'un chilometro',
        timeLabel: 'cinque minuti e dieci secondi',
        standardLength: true,
        paceLabel: 'cinque e 10 al chilometro',
      );
      expect(detto, contains('Giro 3'));
      expect(detto, contains('Un chilometro'));
      expect(detto, isNot(contains('Passo')));
    });

    test('il passo lo dice quando il giro non e\' standard', () {
      // Un parziale chiuso a mano dopo 600 metri: li' il tempo da solo non
      // dice l'andatura, e il passo serve.
      final String detto = frasi.lapFull(
        lapNumber: 4,
        distanceLabel: '600 metri',
        timeLabel: 'tre minuti',
        standardLength: false,
        paceLabel: 'cinque minuti netti al chilometro',
      );
      expect(detto, contains('Passo cinque minuti netti al chilometro'));
    });
  });

  group('il confronto col giro prima', () {
    test('piu\' veloce', () {
      final String detto = frasi.lapFull(
        lapNumber: 2,
        distanceLabel: 'un chilometro',
        timeLabel: 'cinque minuti',
        standardLength: true,
        deltaSeconds: -4,
      );
      expect(detto, contains('Quattro secondi piu\' veloce'));
    });

    test('piu\' lento', () {
      final String detto = frasi.lapFull(
        lapNumber: 2,
        distanceLabel: 'un chilometro',
        timeLabel: 'cinque minuti',
        standardLength: true,
        deltaSeconds: 7,
      );
      expect(detto, contains('Sette secondi piu\' lento'));
    });

    test('uno scarto minimo diventa "stesso passo", non un numero', () {
      // Due secondi su un chilometro sono mezzo secondo al giro di orologio:
      // annunciarli vorrebbe dire far correggere l'andatura a chi sta gia'
      // andando giusto.
      for (final double scarto in <double>[0, 1, -1, 1.4]) {
        final String detto = frasi.lapFull(
          lapNumber: 2,
          distanceLabel: 'un chilometro',
          timeLabel: 'cinque minuti',
          standardLength: true,
          deltaSeconds: scarto,
        );
        expect(detto, contains('Stesso passo di prima'), reason: 'scarto $scarto');
      }
    });

    test('senza giro prima non si confronta niente', () {
      final String detto = frasi.lapFull(
        lapNumber: 1,
        distanceLabel: 'un chilometro',
        timeLabel: 'cinque minuti',
        standardLength: true,
      );
      expect(detto, isNot(contains('piu\' veloce')));
      expect(detto, isNot(contains('piu\' lento')));
      expect(detto, isNot(contains('Stesso passo')));
    });
  });

  group('le aggiunte', () {
    test('cadenza e totale compaiono solo se glieli dai', () {
      final String senza = frasi.lapFull(
        lapNumber: 2,
        distanceLabel: 'un chilometro',
        timeLabel: 'cinque minuti',
        standardLength: true,
      );
      expect(senza, isNot(contains('Cadenza')));
      expect(senza, isNot(contains('Totale')));

      final String con = frasi.lapFull(
        lapNumber: 2,
        distanceLabel: 'un chilometro',
        timeLabel: 'cinque minuti',
        standardLength: true,
        cadence: 168,
        totalDistanceLabel: 'due chilometri',
        totalTimeLabel: 'dieci minuti',
      );
      expect(con, contains('Cadenza 168'));
      expect(con, contains('Totale due chilometri in dieci minuti'));
    });

    test('tutto insieme resta una frase sola e sensata', () {
      final String detto = frasi.lapFull(
        lapNumber: 5,
        distanceLabel: 'un chilometro',
        timeLabel: 'cinque minuti e dieci secondi',
        standardLength: true,
        deltaSeconds: -4,
        cadence: 168,
        totalDistanceLabel: 'cinque chilometri',
        totalTimeLabel: 'ventisei minuti',
        remainingLabel: 'A fine fase mancano 400 metri.',
      );
      expect(detto, startsWith('Giro 5.'));
      expect(detto, endsWith('A fine fase mancano 400 metri.'));
      expect(detto, contains('Quattro secondi piu\' veloce'));
      expect(detto, contains('Cadenza 168'));
      // Nessun doppio spazio e nessun punto doppio: sono i difetti tipici di
      // una frase composta a pezzi, e si sentono tutti.
      expect(detto.contains('  '), isFalse);
      expect(detto.contains('..'), isFalse);
    });
  });

  group('quanto deve dire', () {
    test('i tre livelli si rileggono dal disco', () {
      for (final SpokenDetail d in SpokenDetail.values) {
        expect(SpokenDetailLabel.fromStorage(d.storageKey), d);
      }
    });

    test('un valore sconosciuto torna a "completo"', () {
      expect(SpokenDetailLabel.fromStorage(null), SpokenDetail.completo);
      expect(SpokenDetailLabel.fromStorage('boh'), SpokenDetail.completo);
    });
  });

  group('le impostazioni della voce', () {
    test('voce e dettaglio sopravvivono al giro su disco', () {
      const UserSettings prima = UserSettings(
        ttsVoice: 'it-it-x-kda-local',
        ttsEngine: 'com.google.android.tts',
        spokenDetail: SpokenDetail.tutto,
      );
      final UserSettings dopo = UserSettings.fromJson(prima.toJson());
      expect(dopo.ttsVoice, 'it-it-x-kda-local');
      expect(dopo.ttsEngine, 'com.google.android.tts');
      expect(dopo.spokenDetail, SpokenDetail.tutto);
    });

    test('chi aggiorna da una versione vecchia non trova niente di rotto', () {
      final UserSettings vecchie = UserSettings.fromJson(<String, dynamic>{
        'userName': 'Carlo',
        'audioCoachEnabled': true,
      });
      expect(vecchie.ttsVoice, '');
      expect(vecchie.ttsEngine, '');
      expect(vecchie.spokenDetail, SpokenDetail.completo);
    });
  });
}
