import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:run_coach_app/models/athlete_profile.dart';
import 'package:run_coach_app/models/estimate.dart';
import 'package:run_coach_app/services/fitness_service.dart';
import 'package:run_coach_app/services/run_index_engine.dart';
import 'package:run_coach_app/services/storage_service.dart';

/// Il profilo esiste per una ragione sola: permettere all'atleta di dire al
/// motore cosa sa fare, quando l'archivio non basta a dimostrarlo. Quindi i
/// test guardano due cose - che il profilo sopravviva alla chiusura dell'app,
/// e che un personale dichiarato sposti davvero la stima.
void main() {
  late Directory tempDir;
  late StorageService storage;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('run_coach_profile');
    storage = StorageService(overrideDirectory: tempDir);
  });

  tearDown(() async {
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  group('salvataggio', () {
    test('senza file si parte da un profilo vuoto', () async {
      final AthleteProfile loaded = await storage.loadAthleteProfile();
      expect(loaded.birthYear, isNull);
      expect(loaded.runningYears, isNull);
      expect(loaded.personalBests, isEmpty);
      expect(loaded.availableDays, 4);
    });

    test('profilo e personali sopravvivono alla riapertura', () async {
      final AthleteProfile profile = AthleteProfile(
        birthYear: 1985,
        runningYears: 6,
        availableDays: 5,
        inactiveSinceWeeks: 3,
        personalBests: <PersonalBest>[
          PersonalBest(
            meters: 10000,
            seconds: 2730,
            date: DateTime(2026, 5, 17),
          ),
          const PersonalBest(meters: 5000, seconds: 1320, wasRace: false),
        ],
      );
      expect(await storage.saveAthleteProfile(profile), isTrue);

      final AthleteProfile loaded = await storage.loadAthleteProfile();
      expect(loaded.birthYear, 1985);
      expect(loaded.runningYears, 6);
      expect(loaded.availableDays, 5);
      expect(loaded.inactiveSinceWeeks, 3);
      expect(loaded.personalBests.length, 2);

      final PersonalBest tenK = loaded.personalBests.first;
      expect(tenK.meters, 10000);
      expect(tenK.seconds, 2730);
      expect(tenK.date, DateTime(2026, 5, 17));
      expect(tenK.wasRace, isTrue);
      expect(tenK.source, EstimateSource.race);

      expect(loaded.personalBests[1].wasRace, isFalse);
      expect(loaded.personalBests[1].source, EstimateSource.timeTrial);
    });

    test('file corrotto: profilo vuoto invece di un crash', () async {
      final Directory dir = Directory('${tempDir.path}/run_coach');
      await dir.create(recursive: true);
      await File('${dir.path}/${StorageService.profileFileName}')
          .writeAsString('{ non e json ');

      final AthleteProfile loaded = await storage.loadAthleteProfile();
      expect(loaded.personalBests, isEmpty);
      expect(storage.lastError, isNotNull);
    });
  });

  group('cancellazione dei campi', () {
    test('copyWith puo\' togliere anno di nascita e anni di corsa', () {
      const AthleteProfile full =
          AthleteProfile(birthYear: 1990, runningYears: 4);
      expect(full.copyWith(clearBirthYear: true).birthYear, isNull);
      expect(full.copyWith(clearBirthYear: true).runningYears, 4);
      expect(full.copyWith(clearRunningYears: true).runningYears, isNull);
      expect(full.copyWith(clearRunningYears: true).birthYear, 1990);
    });
  });

  group('effetto sul motore di forma', () {
    const RunIndexEngine engine = RunIndexEngine();
    final DateTime now = DateTime(2026, 9, 27);

    test('una gara dichiarata di recente alza la stima', () {
      // Una sola corsa tranquilla in archivio: 5 km in 28:00 dentro
      // un'uscita normale, senza fatica dichiarata.
      final List<PerformanceSample> soloArchivio = <PerformanceSample>[
        PerformanceSample(
          meters: 5000,
          seconds: 1680,
          date: now.subtract(const Duration(days: 2)),
          source: EstimateSource.runSegment,
          activityId: 'a1',
        ),
      ];
      final RunIndexResult prima = engine.estimate(soloArchivio, now: now);
      expect(prima.index, isNotNull);

      // Lo stesso atleta dichiara una 10 km in gara da 45:00.
      final AthleteProfile profile = AthleteProfile(
        personalBests: <PersonalBest>[
          PersonalBest(
            meters: 10000,
            seconds: 2700,
            date: now.subtract(const Duration(days: 20)),
          ),
        ],
      );
      final RunIndexResult dopo = engine.estimate(
        <PerformanceSample>[
          ...soloArchivio,
          ...engine.samplesFromProfile(profile),
        ],
        now: now,
      );

      expect(dopo.index!.value > prima.index!.value, isTrue,
          reason: 'prima ${prima.index!.value}, dopo ${dopo.index!.value}');
      expect(dopo.index!.confidence > prima.index!.confidence, isTrue,
          reason: 'una gara deve anche alzare la fiducia');
    });

    test('una gara pesa piu\' di un test fatto lo stesso giorno', () {
      final AthleteProfile gara = AthleteProfile(
        personalBests: <PersonalBest>[
          PersonalBest(
            meters: 10000,
            seconds: 2700,
            date: now.subtract(const Duration(days: 5)),
          ),
        ],
      );
      final AthleteProfile prova = AthleteProfile(
        personalBests: <PersonalBest>[
          PersonalBest(
            meters: 10000,
            seconds: 2700,
            date: now.subtract(const Duration(days: 5)),
            wasRace: false,
          ),
        ],
      );
      final double pesoGara =
          engine.weightOf(engine.samplesFromProfile(gara).first, now: now);
      final double pesoTest =
          engine.weightOf(engine.samplesFromProfile(prova).first, now: now);
      expect(pesoGara > pesoTest, isTrue);
    });
  });

  group('tolleranza al carico', () {
    test('non tocca i ritmi, solo la progressione', () {
      // Due atleti molto diversi con la stessa prestazione devono avere gli
      // stessi passi. E' il principio dichiarato del motore.
      const FitnessService fitness = FitnessService();
      final TrainingPaces? paces = fitness.pacesFor(50);
      expect(paces, isNotNull);

      const AthleteProfile giovane =
          AthleteProfile(birthYear: 2000, runningYears: 10);
      const AthleteProfile anziano =
          AthleteProfile(birthYear: 1960, runningYears: 1);
      // Nessuno dei due entra nel calcolo dei passi: il confronto e' solo
      // sulla tolleranza al carico.
      expect(giovane.loadToleranceFactor > anziano.loadToleranceFactor, isTrue);
      expect(anziano.loadToleranceFactor >= 0.45, isTrue);
      expect(giovane.loadToleranceFactor <= 1.10, isTrue);
    });

    test('uno stop lungo abbassa la tolleranza', () {
      const AthleteProfile base =
          AthleteProfile(birthYear: 1990, runningYears: 5);
      final AthleteProfile fermo = base.copyWith(inactiveSinceWeeks: 10);
      expect(fermo.loadToleranceFactor < base.loadToleranceFactor, isTrue);
    });
  });
}
