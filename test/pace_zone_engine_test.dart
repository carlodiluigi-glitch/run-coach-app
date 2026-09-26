import 'package:flutter_test/flutter_test.dart';
import 'package:run_coach_app/models/estimate.dart';
import 'package:run_coach_app/models/running_activity.dart';
import 'package:run_coach_app/services/pace_zone_engine.dart';
import 'package:run_coach_app/services/session_classifier.dart';

/// Costruisce un tracciato rettilineo composto da tratti a ritmo diverso.
///
/// Ogni voce di [segments] e' `[metri, passo in secondi al km]`.
List<RoutePoint> buildRoute(List<List<double>> segments) {
  const double metersPerDegree = 111195.0;
  const double stepMeters = 10;

  final List<RoutePoint> points = <RoutePoint>[];
  double covered = 0;
  double elapsed = 0;

  points.add(const RoutePoint(latitude: 45, longitude: 9, elapsedSeconds: 0));

  for (final List<double> segment in segments) {
    final double meters = segment[0];
    final double pace = segment[1];
    double done = 0;
    while (done < meters) {
      done += stepMeters;
      covered += stepMeters;
      elapsed += stepMeters / 1000.0 * pace;
      points.add(RoutePoint(
        latitude: 45 + covered / metersPerDegree,
        longitude: 9,
        elapsedSeconds: elapsed.round(),
      ));
    }
  }
  return points;
}

RunningActivity activityFrom(List<List<double>> segments) {
  final List<RoutePoint> route = buildRoute(segments);
  double meters = 0;
  for (final List<double> s in segments) {
    meters += s[0];
  }
  return RunningActivity(
    id: 'test',
    startTime: DateTime(2026, 9, 26, 7),
    name: 'Corsa',
    type: ActivityType.free,
    durationSeconds: route.last.elapsedSeconds,
    distanceMeters: meters,
    route: route,
  );
}

void main() {
  const PaceZoneEngine engine = PaceZoneEngine();
  const SessionClassifier classifier = SessionClassifier();

  final DateTime now = DateTime(2026, 9, 26);

  Estimate<double> index(double value, {double confidence = 0.8}) =>
      Estimate<double>(
        value: value,
        confidence: confidence,
        source: EstimateSource.runSegment,
        updatedAt: now,
      );

  group('zone di allenamento', () {
    test('le zone sono ordinate dalla piu\' lenta alla piu\' veloce', () {
      for (final double vdot in <double>[30, 32, 40, 50, 60, 70, 80]) {
        for (final double conf in <double>[0.1, 0.5, 0.9]) {
          final TrainingZones? zones =
              engine.zonesFor(index(vdot, confidence: conf));
          expect(zones, isNotNull, reason: 'VDOT $vdot');

          // Passo in secondi al km: piu' alto = piu' lento.
          void ordered(List<TrainingZone> chain) {
            for (int i = 1; i < chain.length; i++) {
              final double slower = zones![chain[i - 1]].centre;
              final double faster = zones[chain[i]].centre;
              expect(slower > faster, isTrue,
                  reason: 'VDOT $vdot fiducia $conf: '
                      '${chain[i - 1].label} ($slower) deve essere piu\' '
                      'lento di ${chain[i].label} ($faster)');
            }
          }

          ordered(<TrainingZone>[
            TrainingZone.recovery,
            TrainingZone.easy,
            TrainingZone.steady,
            TrainingZone.marathon,
            TrainingZone.threshold,
          ]);
          ordered(<TrainingZone>[
            TrainingZone.fiveK,
            TrainingZone.interval,
            TrainingZone.repetition,
          ]);

          // Il ritmo 10 km sta sempre fra il medio e il ritmo 5 km.
          ordered(<TrainingZone>[
            TrainingZone.marathon,
            TrainingZone.tenK,
            TrainingZone.fiveK,
          ]);
        }
      }
    });

    // NON si puo' pretendere che la soglia sia sempre piu' lenta del ritmo
    // 10 km. La soglia e' il passo che si tiene per un'ora: chi in un'ora non
    // arriva a dieci chilometri corre la 10 km piu' piano della soglia, ed e'
    // giusto cosi'. Succede sotto un indice di circa 33.
    test('la soglia sta fra il medio e il ritmo 5 km, sempre', () {
      for (final double vdot in <double>[30, 32, 35, 45, 60, 80]) {
        final TrainingZones zones = engine.zonesFor(index(vdot))!;
        expect(zones[TrainingZone.marathon].centre >
            zones[TrainingZone.threshold].centre, isTrue,
            reason: 'VDOT $vdot');
        expect(zones[TrainingZone.threshold].centre >
            zones[TrainingZone.fiveK].centre, isTrue,
            reason: 'VDOT $vdot');
      }
    });

    test('VDOT 50: i valori coincidono con le tabelle', () {
      final TrainingZones? zones = engine.zonesFor(index(50));
      expect(zones, isNotNull);
      // Tolleranza di 8 secondi al km.
      expect(zones![TrainingZone.marathon].centre, closeTo(271, 8));
      expect(zones[TrainingZone.threshold].centre, closeTo(253, 8));
      expect(zones[TrainingZone.interval].centre, closeTo(231, 8));
      expect(zones[TrainingZone.repetition].centre, closeTo(216, 8));
    });

    test('con poca fiducia le fasce si allargano', () {
      final TrainingZones? sure = engine.zonesFor(index(50, confidence: 0.9));
      final TrainingZones? unsure = engine.zonesFor(index(50, confidence: 0.1));
      expect(sure, isNotNull);
      expect(unsure, isNotNull);

      final double sureWidth = sure![TrainingZone.threshold].range.width;
      final double unsureWidth = unsure![TrainingZone.threshold].range.width;
      expect(unsureWidth > sureWidth * 1.5, isTrue,
          reason: 'sicuro $sureWidth, incerto $unsureWidth');

      // Ma il centro non si sposta: cambia l'incertezza, non la stima.
      expect(unsure[TrainingZone.threshold].centre,
          closeTo(sure[TrainingZone.threshold].centre, 0.5));
    });

    test('un passo viene assegnato alla zona giusta', () {
      final TrainingZones zones = engine.zonesFor(index(50))!;

      expect(zones.zoneFor(zones[TrainingZone.threshold].centre),
          TrainingZone.threshold);
      expect(zones.zoneFor(zones[TrainingZone.easy].centre), TrainingZone.easy);
      expect(zones.zoneFor(zones[TrainingZone.interval].centre),
          TrainingZone.interval);

      // Fuori scala da entrambi i lati.
      expect(zones.zoneFor(900), TrainingZone.recovery);
      expect(zones.zoneFor(120), TrainingZone.repetition);
    });

    test('senza indice non ci sono zone', () {
      expect(engine.zonesFor(null), isNull);
      expect(engine.zonesFor(index(0)), isNull);
    });
  });

  group('SCENARIO F - riconoscere cosa e\' stato corso davvero', () {
    final TrainingZones zones = engine.zonesFor(index(50))!;
    final double easyPace = zones[TrainingZone.easy].centre;
    final double thresholdPace = zones[TrainingZone.threshold].centre;
    final double intervalPace = zones[TrainingZone.interval].centre;
    final double marathonPace = zones[TrainingZone.marathon].centre;

    test('una corsa facile resta facile', () {
      final SessionAnalysis result = classifier.analyse(
        activityFrom(<List<double>>[
          <double>[8000, easyPace],
        ]),
        zones,
      );
      expect(result.intensity, SessionIntensity.easy);
      expect(result.qualityMinutes < 1, isTrue);
      expect(result.intensity.countsAsQuality, isFalse);
    });

    test('un lento corso a ritmo medio diventa scorrevole o peggio', () {
      final SessionAnalysis result = classifier.analyse(
        activityFrom(<List<double>>[
          <double>[8000, marathonPace],
        ]),
        zones,
      );
      expect(result.intensity.rank >= SessionIntensity.steady.rank, isTrue,
          reason: 'classificata ${result.intensity.label}');
    });

    test('cinque ripetute da mille sono una seduta dura', () {
      final List<List<double>> segments = <List<double>>[
        <double>[2000, easyPace],
      ];
      for (int i = 0; i < 5; i++) {
        segments.add(<double>[1000, intervalPace]);
        segments.add(<double>[400, easyPace + 60]);
      }
      segments.add(<double>[2000, easyPace]);

      final SessionAnalysis result =
          classifier.analyse(activityFrom(segments), zones);

      expect(result.intensity, SessionIntensity.hard);
      expect(result.qualityMinutes > 15, isTrue,
          reason: 'solo ${result.qualityMinutes} minuti di qualita\'');
      expect(result.intensity.countsAsQuality, isTrue);
    });

    test('venti minuti di soglia sono una seduta dura', () {
      final SessionAnalysis result = classifier.analyse(
        activityFrom(<List<double>>[
          <double>[2000, easyPace],
          // Circa venti minuti a ritmo soglia.
          <double>[20 * 60 / thresholdPace * 1000, thresholdPace],
          <double>[2000, easyPace],
        ]),
        zones,
      );
      expect(result.intensity, SessionIntensity.hard);
    });

    test('la spiegazione dice sempre perche\'', () {
      final SessionAnalysis result = classifier.analyse(
        activityFrom(<List<double>>[
          <double>[6000, easyPace],
        ]),
        zones,
      );
      expect(result.explanation.isNotEmpty, isTrue);
      expect(result.explanation.contains('facile'), isTrue);
    });

    test('senza tracciato si ripiega sul passo medio e lo dichiara', () {
      final RunningActivity noGps = RunningActivity(
        id: 'x',
        startTime: now,
        name: 'Inserita a mano',
        type: ActivityType.free,
        durationSeconds: 3000,
        distanceMeters: 10000,
      );
      final SessionAnalysis result = classifier.analyse(noGps, zones);
      expect(result.explanation.contains('passo medio'), isTrue);
    });

    test('attivita\' vuota non fa esplodere niente', () {
      final RunningActivity empty = RunningActivity(
        id: 'y',
        startTime: now,
        name: 'Vuota',
        type: ActivityType.free,
        durationSeconds: 0,
        distanceMeters: 0,
      );
      final SessionAnalysis result = classifier.analyse(empty, zones);
      expect(result.intensity, SessionIntensity.easy);
      expect(result.qualityMinutes, 0);
    });
  });

  group('previsto contro effettivo', () {
    final TrainingZones zones = engine.zonesFor(index(50))!;

    test('un facile corso duro viene segnalato come qualita\'', () {
      final SessionAnalysis hard = classifier.analyse(
        activityFrom(<List<double>>[
          <double>[2000, zones[TrainingZone.easy].centre],
          <double>[5000, zones[TrainingZone.threshold].centre],
          <double>[1000, zones[TrainingZone.easy].centre],
        ]),
        zones,
      );

      final String? note = classifier.reclassificationNote(
        planned: SessionIntensity.easy,
        actual: hard,
      );
      expect(note, isNotNull);
      expect(note!.contains('qualita'), isTrue);
    });

    test('quando combacia non si dice niente', () {
      final SessionAnalysis easy = classifier.analyse(
        activityFrom(<List<double>>[
          <double>[8000, zones[TrainingZone.easy].centre],
        ]),
        zones,
      );
      expect(
        classifier.reclassificationNote(
          planned: SessionIntensity.easy,
          actual: easy,
        ),
        isNull,
      );
    });

    test('una qualita\' non fatta viene segnalata', () {
      final SessionAnalysis easy = classifier.analyse(
        activityFrom(<List<double>>[
          <double>[8000, zones[TrainingZone.easy].centre],
        ]),
        zones,
      );
      final String? note = classifier.reclassificationNote(
        planned: SessionIntensity.hard,
        actual: easy,
      );
      expect(note, isNotNull);
      expect(note!.contains('tranquilla'), isTrue);
    });
  });
}
