import 'health_data.dart';
import 'lap.dart';
import '../utils/formatters.dart';
import '../utils/id_generator.dart';

/// Tipo di attivita' registrata.
enum ActivityType { free, workout }

extension ActivityTypeLabel on ActivityType {
  String get label => this == ActivityType.free ? 'Corsa libera' : 'Allenamento';

  static ActivityType fromStorage(String? value) =>
      value == 'workout' ? ActivityType.workout : ActivityType.free;
}

/// Punto del tracciato GPS accettato dal filtro.
class RoutePoint {
  const RoutePoint({
    required this.latitude,
    required this.longitude,
    required this.elapsedSeconds,
    this.altitude,
  });

  final double latitude;
  final double longitude;

  /// Secondi di tempo attivo dall'inizio dell'attivita'.
  final int elapsedSeconds;

  final double? altitude;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'lat': latitude,
        'lon': longitude,
        't': elapsedSeconds,
        'alt': altitude,
      };

  factory RoutePoint.fromJson(Map<String, dynamic> json) => RoutePoint(
        latitude: (json['lat'] as num?)?.toDouble() ?? 0.0,
        longitude: (json['lon'] as num?)?.toDouble() ?? 0.0,
        elapsedSeconds: (json['t'] as num?)?.toInt() ?? 0,
        altitude: (json['alt'] as num?)?.toDouble(),
      );
}

/// Una attivita' di corsa salvata nello storico.
class RunningActivity {
  RunningActivity({
    String? id,
    required this.startTime,
    required this.name,
    required this.type,
    required this.durationSeconds,
    required this.distanceMeters,
    List<Lap>? laps,
    List<RoutePoint>? route,
    this.shoeId,
    this.workoutId,
    this.note,
    // --- Campi predisposti per il futuro (mai inventati) ---
    this.dynamics,
    this.heartRateAverage,
    this.heartRateMax,
    List<HeartRateSample>? heartRateSamples,
    this.hrv,
    this.sleep,
  })  : id = id ?? IdGenerator.newId('act'),
        laps = laps ?? <Lap>[],
        route = route ?? <RoutePoint>[],
        heartRateSamples = heartRateSamples ?? <HeartRateSample>[];

  final String id;
  final DateTime startTime;
  final String name;
  final ActivityType type;

  /// Tempo attivo in secondi (le pause NON sono conteggiate).
  final int durationSeconds;

  final double distanceMeters;
  final List<Lap> laps;
  final List<RoutePoint> route;

  /// Id della scarpa usata (vedi `RunningShoe`).
  final String? shoeId;

  /// Id dell'allenamento programmato eseguito, se presente.
  final String? workoutId;

  final String? note;

  // ---- Predisposizione funzioni future -------------------------------------
  /// Cadenza, lunghezza passo, oscillazione verticale. `null` se non misurate.
  final RunningDynamics? dynamics;

  final int? heartRateAverage;
  final int? heartRateMax;
  final List<HeartRateSample> heartRateSamples;
  final HrvData? hrv;
  final SleepData? sleep;

  /// Passo medio in secondi per chilometro (`null` se non calcolabile).
  double? get averagePaceSecondsPerKm =>
      paceFromDistanceAndTime(distanceMeters, durationSeconds);

  double get distanceKm => distanceMeters / 1000.0;

  Duration get duration => Duration(seconds: durationSeconds);

  RunningActivity copyWith({
    String? name,
    String? shoeId,
    bool clearShoe = false,
    String? note,
  }) =>
      RunningActivity(
        id: id,
        startTime: startTime,
        name: name ?? this.name,
        type: type,
        durationSeconds: durationSeconds,
        distanceMeters: distanceMeters,
        laps: laps,
        route: route,
        shoeId: clearShoe ? null : (shoeId ?? this.shoeId),
        workoutId: workoutId,
        note: note ?? this.note,
        dynamics: dynamics,
        heartRateAverage: heartRateAverage,
        heartRateMax: heartRateMax,
        heartRateSamples: heartRateSamples,
        hrv: hrv,
        sleep: sleep,
      );

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'startTime': startTime.toIso8601String(),
        'name': name,
        'type': type.name,
        'durationSeconds': durationSeconds,
        'distanceMeters': distanceMeters,
        'laps': laps.map((Lap l) => l.toJson()).toList(),
        'route': route.map((RoutePoint p) => p.toJson()).toList(),
        'shoeId': shoeId,
        'workoutId': workoutId,
        'note': note,
        'dynamics': dynamics?.toJson(),
        'heartRateAverage': heartRateAverage,
        'heartRateMax': heartRateMax,
        'heartRateSamples':
            heartRateSamples.map((HeartRateSample s) => s.toJson()).toList(),
        'hrv': hrv?.toJson(),
        'sleep': sleep?.toJson(),
      };

  factory RunningActivity.fromJson(Map<String, dynamic> json) {
    final List<dynamic> rawLaps = (json['laps'] as List<dynamic>?) ?? <dynamic>[];
    final List<dynamic> rawRoute =
        (json['route'] as List<dynamic>?) ?? <dynamic>[];
    final List<dynamic> rawHr =
        (json['heartRateSamples'] as List<dynamic>?) ?? <dynamic>[];
    final Map<String, dynamic>? rawDynamics =
        (json['dynamics'] as Map?)?.cast<String, dynamic>();
    final Map<String, dynamic>? rawHrv =
        (json['hrv'] as Map?)?.cast<String, dynamic>();
    final Map<String, dynamic>? rawSleep =
        (json['sleep'] as Map?)?.cast<String, dynamic>();

    return RunningActivity(
      id: json['id'] as String?,
      startTime: DateTime.tryParse(json['startTime'] as String? ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
      name: json['name'] as String? ?? 'Corsa',
      type: ActivityTypeLabel.fromStorage(json['type'] as String?),
      durationSeconds: (json['durationSeconds'] as num?)?.toInt() ?? 0,
      distanceMeters: (json['distanceMeters'] as num?)?.toDouble() ?? 0.0,
      laps: rawLaps
          .map((dynamic e) => Lap.fromJson((e as Map).cast<String, dynamic>()))
          .toList(),
      route: rawRoute
          .map((dynamic e) =>
              RoutePoint.fromJson((e as Map).cast<String, dynamic>()))
          .toList(),
      shoeId: json['shoeId'] as String?,
      workoutId: json['workoutId'] as String?,
      note: json['note'] as String?,
      dynamics:
          rawDynamics == null ? null : RunningDynamics.fromJson(rawDynamics),
      heartRateAverage: (json['heartRateAverage'] as num?)?.toInt(),
      heartRateMax: (json['heartRateMax'] as num?)?.toInt(),
      heartRateSamples: rawHr
          .map((dynamic e) =>
              HeartRateSample.fromJson((e as Map).cast<String, dynamic>()))
          .toList(),
      hrv: rawHrv == null ? null : HrvData.fromJson(rawHrv),
      sleep: rawSleep == null ? null : SleepData.fromJson(rawSleep),
    );
  }
}
