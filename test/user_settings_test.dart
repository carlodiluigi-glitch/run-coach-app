import 'package:flutter_test/flutter_test.dart';
import 'package:run_coach_app/models/user_settings.dart';
import 'package:run_coach_app/models/weekly_availability.dart';

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

  /// I giorni in cui si puo' correre vivono qui, non nel piano.
  ///
  /// Nascono da un difetto vero: la settimana dichiarata (lungo il mercoledi',
  /// perche' sabato e domenica si lavora) spariva e tornava lo schema
  /// standard - lungo la domenica - non appena il piano non c'era piu'. La
  /// settimana di una persona non e' una proprieta' del suo piano.
  group('la settimana dell\'atleta', () {
    test('di partenza non c\'e\'', () {
      expect(const UserSettings().weeklyAvailability, isNull);
    });

    test('sopravvive al salvataggio', () {
      final UserSettings s = const UserSettings().copyWith(
        weeklyAvailability: WeeklyAvailability(<int, int>{
          1: 60,
          2: 75,
          3: 90,
          4: 75,
          5: 60,
          6: 60,
          7: 60,
        }),
      );

      final UserSettings riletto = UserSettings.fromJson(s.toJson());
      expect(riletto.weeklyAvailability, isNotNull);
      expect(riletto.weeklyAvailability!.minutesOn(3), 90);
      expect(riletto.weeklyAvailability!.longestDay, 3,
          reason: 'il lungo deve restare dove c\'e\' piu\' tempo');
      expect(riletto.weeklyAvailability!.dayCount, 7);
    });

    test('chi non l\'ha mai dichiarata rilegge null, non una settimana vuota',
        () {
      final Map<String, dynamic> json = const UserSettings().toJson();
      expect(json.containsKey('weeklyAvailability'), isFalse);
      expect(UserSettings.fromJson(json).weeklyAvailability, isNull);
    });

    test('le altre impostazioni non si perdono per strada', () {
      final UserSettings s = const UserSettings(userName: 'Carlo').copyWith(
        weeklyAvailability: WeeklyAvailability(<int, int>{2: 60, 4: 60, 7: 90}),
      );
      final UserSettings riletto = UserSettings.fromJson(s.toJson());
      expect(riletto.userName, 'Carlo');
      expect(riletto.weeklyAvailability!.longestDay, 7);
    });
  });
}
