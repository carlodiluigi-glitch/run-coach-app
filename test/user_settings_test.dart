import 'package:flutter_test/flutter_test.dart';
import 'package:run_coach_app/models/user_settings.dart';

void main() {
  group('UserSettings', () {
    test('valori predefiniti', () {
      const UserSettings s = UserSettings();
      expect(s.userName, '');
      expect(s.hasUserName, isFalse);
      expect(s.greeting, 'Ciao!');
      expect(s.welcomeDone, isFalse);
    });

    test('il saluto usa il nome, senza spazi di troppo', () {
      const UserSettings s = UserSettings(userName: '  Carlo  ');
      expect(s.hasUserName, isTrue);
      expect(s.greeting, 'Ciao Carlo');
    });

    test('un nome fatto di soli spazi non conta', () {
      const UserSettings s = UserSettings(userName: '   ');
      expect(s.hasUserName, isFalse);
      expect(s.greeting, 'Ciao!');
    });

    test('andata e ritorno da JSON', () {
      const UserSettings s = UserSettings(
        userName: 'Carlo',
        welcomeDone: true,
        autoLapDistanceMeters: 500,
        paceAlertCooldownSeconds: 30,
      );
      final UserSettings back = UserSettings.fromJson(s.toJson());
      expect(back.userName, 'Carlo');
      expect(back.welcomeDone, isTrue);
      expect(back.autoLapDistanceMeters, 500);
      expect(back.paceAlertCooldownSeconds, 30);
    });

    // Chi aveva gia' l'app installata ha un file di impostazioni senza il
    // campo "welcomeDone". Non deve rivedersi il benvenuto se il nome c'era
    // gia': sarebbe una domanda a cui ha gia' risposto.
    test('impostazioni vecchie con il nome: benvenuto considerato fatto', () {
      final UserSettings s =
          UserSettings.fromJson(<String, dynamic>{'userName': 'Carlo'});
      expect(s.welcomeDone, isTrue);
    });

    test('impostazioni vecchie senza nome: benvenuto da mostrare', () {
      final UserSettings s =
          UserSettings.fromJson(<String, dynamic>{'userName': ''});
      expect(s.welcomeDone, isFalse);
    });

    test('file di impostazioni vuoto: si usano i valori predefiniti', () {
      final UserSettings s = UserSettings.fromJson(<String, dynamic>{});
      expect(s.welcomeDone, isFalse);
      expect(s.audioCoachEnabled, isTrue);
      expect(s.autoLapDistanceMeters, 1000);
    });
  });
}
