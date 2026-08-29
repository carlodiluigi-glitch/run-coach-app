import 'package:flutter_test/flutter_test.dart';
import 'package:run_coach_app/services/gps_filter.dart';

void main() {
  group('haversineMeters', () {
    test('distanza nota approssimata', () {
      // Un grado di latitudine vale circa 111 km.
      final double d = haversineMeters(45.0, 9.0, 45.001, 9.0);
      expect(d, greaterThan(100));
      expect(d, lessThan(120));
    });

    test('stesso punto = zero', () {
      expect(haversineMeters(45.0, 9.0, 45.0, 9.0), lessThan(0.001));
    });
  });

  group('GpsFilter', () {
    late GpsFilter filter;
    late DateTime t0;

    setUp(() {
      filter = GpsFilter();
      t0 = DateTime(2026, 1, 1, 10);
    });

    test('il primo punto valido non aggiunge distanza', () {
      final GpsFilterResult r = filter.process(
        latitude: 45.0,
        longitude: 9.0,
        accuracy: 5,
        timestamp: t0,
      );
      expect(r.accepted, isTrue);
      expect(r.isFirstFix, isTrue);
      expect(filter.totalMeters, 0);
    });

    test('accuracy scarsa: punto scartato', () {
      final GpsFilterResult r = filter.process(
        latitude: 45.0,
        longitude: 9.0,
        accuracy: 100,
        timestamp: t0,
      );
      expect(r.accepted, isFalse);
      expect(r.reason, GpsRejectReason.poorAccuracy);
    });

    test('micro-spostamenti da fermo non vengono sommati', () {
      filter.process(
          latitude: 45.0, longitude: 9.0, accuracy: 5, timestamp: t0);
      final GpsFilterResult r = filter.process(
        latitude: 45.00001, // circa 1.1 m
        longitude: 9.0,
        accuracy: 5,
        timestamp: t0.add(const Duration(seconds: 2)),
      );
      expect(r.accepted, isFalse);
      expect(r.reason, GpsRejectReason.belowMinDistance);
      expect(filter.totalMeters, 0);
    });

    test('spostamento reale viene sommato', () {
      filter.process(
          latitude: 45.0, longitude: 9.0, accuracy: 5, timestamp: t0);
      final GpsFilterResult r = filter.process(
        latitude: 45.0001, // circa 11 m
        longitude: 9.0,
        accuracy: 5,
        timestamp: t0.add(const Duration(seconds: 4)),
      );
      expect(r.accepted, isTrue);
      expect(r.addedMeters, greaterThan(9));
      expect(filter.totalMeters, greaterThan(9));
    });

    test('velocita impossibile: punto scartato', () {
      filter.process(
          latitude: 45.0, longitude: 9.0, accuracy: 5, timestamp: t0);
      // 50 m in 1 secondo = 50 m/s, impossibile correndo.
      final GpsFilterResult r = filter.process(
        latitude: 45.00045,
        longitude: 9.0,
        accuracy: 5,
        timestamp: t0.add(const Duration(seconds: 1)),
      );
      expect(r.accepted, isFalse);
      expect(r.reason, GpsRejectReason.impossibleSpeed);
      expect(filter.totalMeters, 0);
    });

    test('salto GPS anomalo: punto scartato', () {
      filter.process(
          latitude: 45.0, longitude: 9.0, accuracy: 5, timestamp: t0);
      // Circa 1.1 km di colpo: e' un riaggancio del segnale.
      final GpsFilterResult r = filter.process(
        latitude: 45.01,
        longitude: 9.0,
        accuracy: 5,
        timestamp: t0.add(const Duration(seconds: 30)),
      );
      expect(r.accepted, isFalse);
      expect(r.reason, GpsRejectReason.gpsJump);
      expect(filter.totalMeters, 0);
    });

    test('campioni troppo ravvicinati vengono ignorati', () {
      filter.process(
          latitude: 45.0, longitude: 9.0, accuracy: 5, timestamp: t0);
      final GpsFilterResult r = filter.process(
        latitude: 45.0001,
        longitude: 9.0,
        accuracy: 5,
        timestamp: t0.add(const Duration(milliseconds: 100)),
      );
      expect(r.accepted, isFalse);
      expect(r.reason, GpsRejectReason.tooSoon);
    });

    test('dropReference non azzera la distanza gia percorsa', () {
      filter.process(
          latitude: 45.0, longitude: 9.0, accuracy: 5, timestamp: t0);
      filter.process(
        latitude: 45.0001,
        longitude: 9.0,
        accuracy: 5,
        timestamp: t0.add(const Duration(seconds: 4)),
      );
      final double before = filter.totalMeters;
      expect(before, greaterThan(0));

      filter.dropReference();
      expect(filter.totalMeters, before);
      expect(filter.hasReference, isFalse);

      // Il primo punto dopo la pausa e' solo riferimento: la distanza
      // percorsa durante la pausa non viene sommata.
      final GpsFilterResult r = filter.process(
        latitude: 45.02,
        longitude: 9.0,
        accuracy: 5,
        timestamp: t0.add(const Duration(minutes: 5)),
      );
      expect(r.isFirstFix, isTrue);
      expect(filter.totalMeters, before);
    });

    test('reset azzera tutto', () {
      filter.process(
          latitude: 45.0, longitude: 9.0, accuracy: 5, timestamp: t0);
      filter.reset();
      expect(filter.totalMeters, 0);
      expect(filter.hasReference, isFalse);
    });
  });
}
