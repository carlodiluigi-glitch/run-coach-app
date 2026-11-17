import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:run_coach_app/app/theme.dart';
import 'package:run_coach_app/models/user_settings.dart';
import 'package:run_coach_app/utils/tempo_digitato.dart';
import 'package:run_coach_app/widgets/fumetto.dart';
import 'package:run_coach_app/widgets/omino.dart';

void main() {
  group('Tempo scritto a mano', () {
    test('minuti e secondi', () {
      expect(secondiDaTesto('44:30'), 44 * 60 + 30);
      expect(secondiDaTesto(' 21:05 '), 21 * 60 + 5);
    });

    test('ore, minuti e secondi', () {
      expect(secondiDaTesto('1:42:05'), 3600 + 42 * 60 + 5);
    });

    test('piu\' di 59 minuti senza le ore', () {
      expect(secondiDaTesto('95:10'), 95 * 60 + 10);
    });

    test('punto e virgola al posto dei due punti', () {
      expect(secondiDaTesto('44.30'), 44 * 60 + 30);
      expect(secondiDaTesto('44,30'), 44 * 60 + 30);
    });

    test('un numero solo sono minuti interi', () {
      expect(secondiDaTesto('45'), 45 * 60);
    });

    test('rifiuta quello che non e\' un tempo', () {
      expect(secondiDaTesto(''), isNull);
      expect(secondiDaTesto('44:75'), isNull);
      expect(secondiDaTesto('1:75:00'), isNull);
      expect(secondiDaTesto('ab:cd'), isNull);
      expect(secondiDaTesto('44:'), isNull);
      expect(secondiDaTesto('1:2:3:4'), isNull);
      expect(secondiDaTesto('0:00'), isNull);
    });

    test('un tempo impossibile sulla distanza viene segnalato', () {
      // 10 km in 20 minuti = 2:00/km: nessuno.
      expect(problemaTempo(10000, 20 * 60), isNotNull);
      // 5 km in 3 ore: e' camminare.
      expect(problemaTempo(5000, 3 * 3600), isNotNull);
      // 10 km in 44:30: normale.
      expect(problemaTempo(10000, 44 * 60 + 30), isNull);
      // mezza in 1:42:05: normale.
      expect(problemaTempo(21097.5, 3600 + 42 * 60 + 5), isNull);
      expect(problemaTempo(10000, null), isNotNull);
    });

    test('peso in chili, anche con la virgola', () {
      expect(chiliDaTesto('72'), 72);
      expect(chiliDaTesto('72,5'), 72.5);
      expect(chiliDaTesto(''), isNull);
      expect(chiliDaTesto('7'), isNull);
      expect(chiliDaTesto('400'), isNull);
      expect(chiliDaTesto('abc'), isNull);
    });
  });

  group('Guida e fumetti nelle impostazioni', () {
    test('di partenza la guida non e\' vista e nessun fumetto e\' letto', () {
      const UserSettings s = UserSettings();
      expect(s.guideDone, isFalse);
      expect(s.tipsSeen, isEmpty);
      expect(s.tipSeen('forma'), isFalse);
    });

    test('andata e ritorno da JSON', () {
      const UserSettings s = UserSettings(
        welcomeDone: true,
        guideDone: true,
        tipsSeen: <String>['forma', 'coach'],
      );
      final UserSettings back = UserSettings.fromJson(s.toJson());
      expect(back.guideDone, isTrue);
      expect(back.tipsSeen, <String>['forma', 'coach']);
      expect(back.tipSeen('coach'), isTrue);
      expect(back.tipSeen('piano'), isFalse);
    });

    test('chi aggiorna da una versione senza guida la deve vedere', () {
      // Un file di impostazioni di prima: benvenuto fatto, guida mai vista.
      final UserSettings vecchie = UserSettings.fromJson(<String, dynamic>{
        'userName': 'Carlo',
        'welcomeDone': true,
      });
      expect(vecchie.welcomeDone, isTrue);
      expect(vecchie.guideDone, isFalse);
      expect(vecchie.tipsSeen, isEmpty);
      expect(vecchie.userName, 'Carlo');
    });

    test('valori sporchi nella lista dei fumetti non rompono la lettura', () {
      final UserSettings s = UserSettings.fromJson(<String, dynamic>{
        'tipsSeen': <dynamic>['forma', 3, null, 'piano'],
      });
      expect(s.tipsSeen, <String>['forma', 'piano']);
    });

    test('copyWith tiene i campi della guida', () {
      const UserSettings s = UserSettings(
        guideDone: true,
        tipsSeen: <String>['forma'],
      );
      final UserSettings dopo = s.copyWith(userName: 'Carlo');
      expect(dopo.guideDone, isTrue);
      expect(dopo.tipsSeen, <String>['forma']);
    });

    test('i fumetti hanno chiavi diverse', () {
      final Set<String> chiavi = <String>{
        Fumetti.forma.chiave,
        Fumetti.piano.chiave,
        Fumetti.coach.chiave,
      };
      expect(chiavi.length, 3);
    });
  });

  group('Omino', () {
    for (final OminoPose posa in OminoPose.values) {
      testWidgets('si disegna nella posa ${posa.name}',
          (WidgetTester tester) async {
        await tester.pumpWidget(MaterialApp(
          theme: AppTheme.dark(),
          home: Scaffold(
            body: Center(child: Omino(pose: posa, size: 120)),
          ),
        ));
        expect(find.byType(Omino), findsOneWidget);
        expect(tester.getSize(find.byType(Omino)), const Size(120, 120));
        expect(tester.takeException(), isNull);
      });
    }
  });
}
