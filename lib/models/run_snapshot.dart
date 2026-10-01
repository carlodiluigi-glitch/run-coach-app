import 'lap.dart';
import 'running_activity.dart';

/// Una corsa in corso, scritta su disco mentre la si registra.
///
/// PERCHE' ESISTE
/// --------------
/// Fino a ieri una corsa viveva solo nella memoria del processo. Se Android
/// chiudeva l'app - e lo fa: risparmio energetico, memoria finita, il
/// gestore aggressivo di Xiaomi o Huawei, un crash - la corsa spariva.
/// Un'ora e mezza di lavoro persa, e nessun modo di riaverla.
///
/// E' il difetto piu' grave possibile per un'app che vive sul telefono,
/// perche' non e' un numero sbagliato: e' il dato che non c'e' piu'. Una
/// stima imprecisa si corregge, una corsa persa no.
///
/// Quindi ogni pochi secondi la corsa viene scritta qui. Se l'app riparte e
/// trova questo file, non ha perso niente: propone di salvare quello che
/// c'era.
///
/// PERCHE' NON SI RIPRENDE A CORRERE
/// ---------------------------------
/// Sarebbe possibile ma non onesto: fra l'uccisione e il riavvio possono
/// essere passati minuti o ore, e il cronometro non saprebbe cosa farne.
/// Meglio salvare con sicurezza quello che era stato misurato che ricostruire
/// per finta quello che non c'era nessuno a misurare.
class RunSnapshot {
  const RunSnapshot({
    required this.startTime,
    required this.savedAt,
    required this.elapsedSeconds,
    required this.distanceMeters,
    required this.name,
    required this.type,
    required this.laps,
    required this.route,
    this.workoutId,
  });

  final DateTime startTime;

  /// Quando e' stato scritto l'ultimo salvataggio. Serve a capire quanto si
  /// e' perso: fra questo istante e l'uccisione dell'app non c'e' niente.
  final DateTime savedAt;

  final int elapsedSeconds;
  final double distanceMeters;
  final String name;
  final ActivityType type;
  final List<Lap> laps;
  final List<RoutePoint> route;
  final String? workoutId;

  /// Sotto questa soglia non vale la pena proporre il recupero: e' un avvio
  /// per sbaglio, non una corsa.
  static const int minimumSeconds = 120;
  static const double minimumMeters = 200;

  bool get isWorthRecovering =>
      elapsedSeconds >= minimumSeconds && distanceMeters >= minimumMeters;

  /// Trasforma il salvataggio in un'attivita' vera, pronta da mettere in
  /// archivio.
  RunningActivity toActivity() => RunningActivity(
        startTime: startTime,
        name: name,
        type: type,
        durationSeconds: elapsedSeconds,
        distanceMeters: distanceMeters,
        laps: List<Lap>.from(laps),
        route: List<RoutePoint>.from(route),
        workoutId: workoutId,
      );

  Map<String, dynamic> toJson() => <String, dynamic>{
        'startTime': startTime.toIso8601String(),
        'savedAt': savedAt.toIso8601String(),
        'elapsedSeconds': elapsedSeconds,
        'distanceMeters': distanceMeters,
        'name': name,
        'type': type.name,
        'workoutId': workoutId,
        'laps': laps.map((Lap l) => l.toJson()).toList(),
        'route': route.map((RoutePoint p) => p.toJson()).toList(),
      };

  factory RunSnapshot.fromJson(Map<String, dynamic> json) {
    final List<dynamic> rawLaps = (json['laps'] as List<dynamic>?) ?? <dynamic>[];
    final List<dynamic> rawRoute =
        (json['route'] as List<dynamic>?) ?? <dynamic>[];

    return RunSnapshot(
      startTime: DateTime.tryParse(json['startTime'] as String? ?? '') ??
          DateTime.now(),
      savedAt:
          DateTime.tryParse(json['savedAt'] as String? ?? '') ?? DateTime.now(),
      elapsedSeconds: (json['elapsedSeconds'] as num?)?.toInt() ?? 0,
      distanceMeters: (json['distanceMeters'] as num?)?.toDouble() ?? 0,
      name: json['name'] as String? ?? 'Corsa recuperata',
      type: ActivityTypeLabel.fromStorage(json['type'] as String?),
      workoutId: json['workoutId'] as String?,
      laps: rawLaps
          .whereType<Map<dynamic, dynamic>>()
          .map((Map<dynamic, dynamic> e) => Lap.fromJson(e.cast<String, dynamic>()))
          .toList(),
      route: rawRoute
          .whereType<Map<dynamic, dynamic>>()
          .map((Map<dynamic, dynamic> e) =>
              RoutePoint.fromJson(e.cast<String, dynamic>()))
          .toList(),
    );
  }
}
