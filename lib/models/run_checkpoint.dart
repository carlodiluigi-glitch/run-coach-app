import 'lap.dart';
import 'running_activity.dart';
import 'workout.dart';

/// Fotografia di una corsa in corso, salvata periodicamente su file.
///
/// A COSA SERVE
/// ------------
/// Se l'app viene chiusa mentre stai correndo - crash, batteria finita, il
/// sistema che la uccide per liberare memoria - senza questo si perde tutto.
/// Con questo, al riavvio si puo' proporre di riprendere da dove si era.
///
/// COSA CONTIENE E COSA NO
/// -----------------------
/// Contiene tutto cio' che non e' ricostruibile: tempo, distanza, lap,
/// tracciato, e i marcatori interni che tengono allineati lap e fasi.
/// Non contiene le cose che si ricalcolano da sole alla ripresa, come la
/// finestra del passo o lo stato del filtro GPS: al massimo il passo mostrato
/// resta indefinito per una decina di secondi.
///
/// L'allenamento viene salvato per intero, non come riferimento: cosi' una
/// corsa interrotta resta recuperabile anche se nel frattempo quell'
/// allenamento e' stato modificato o cancellato.
class RunCheckpoint {
  const RunCheckpoint({
    required this.savedAt,
    required this.startTime,
    required this.elapsedSeconds,
    required this.distanceMeters,
    required this.paused,
    required this.laps,
    required this.lapStartDistance,
    required this.lapStartSeconds,
    required this.stepBoundaryDistance,
    required this.stepBoundarySeconds,
    required this.route,
    this.workout,
    this.workoutStepIndex = 0,
    this.workoutStarted = false,
    this.workoutFinished = false,
    this.workoutStepStartDistance = 0.0,
    this.workoutStepStartSeconds = 0,
    this.schemaVersion = currentSchemaVersion,
  });

  /// Versione del formato.
  ///
  /// Se un giorno il contenuto cambia, un checkpoint vecchio va scartato
  /// invece che letto male: meglio perdere una corsa interrotta che
  /// ripristinarne una con i numeri sbagliati.
  static const int currentSchemaVersion = 1;

  /// Oltre questa eta' il checkpoint non viene piu' proposto: se l'app e'
  /// rimasta chiusa mezza giornata, quella corsa e' finita comunque.
  static const Duration maxAge = Duration(hours: 12);

  /// Sotto questa soglia non vale la pena proporre il recupero.
  static const double minDistanceMeters = 50.0;

  final int schemaVersion;

  /// Momento in cui il checkpoint e' stato scritto.
  final DateTime savedAt;

  /// Inizio della corsa.
  final DateTime startTime;

  /// Tempo attivo, pause escluse.
  final int elapsedSeconds;

  final double distanceMeters;

  /// `true` se la corsa era in pausa al momento del salvataggio.
  final bool paused;

  final List<Lap> laps;

  /// Distanza e tempo a cui e' iniziato il lap ancora aperto.
  final double lapStartDistance;
  final int lapStartSeconds;

  /// Confine della fase corrente, necessario perche' i lap continuino a
  /// incastrarsi con gli step dopo la ripresa.
  final double stepBoundaryDistance;
  final int stepBoundarySeconds;

  final List<RoutePoint> route;

  /// Allenamento programmato, se la corsa ne aveva uno.
  final Workout? workout;

  /// Posizione del motore dell'allenamento al momento del salvataggio.
  final int workoutStepIndex;
  final bool workoutStarted;
  final bool workoutFinished;
  final double workoutStepStartDistance;
  final int workoutStepStartSeconds;

  bool get hasWorkout => workout != null;

  /// `true` se ha senso proporre il recupero all'utente.
  ///
  /// Un checkpoint troppo vecchio o quasi vuoto verrebbe solo percepito come
  /// una domanda inutile all'avvio.
  bool get isRecoverable {
    if (schemaVersion != currentSchemaVersion) return false;
    if (distanceMeters < minDistanceMeters) return false;
    if (DateTime.now().difference(savedAt) > maxAge) return false;
    return true;
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'schemaVersion': schemaVersion,
        'savedAt': savedAt.toIso8601String(),
        'startTime': startTime.toIso8601String(),
        'elapsedSeconds': elapsedSeconds,
        'distanceMeters': distanceMeters,
        'paused': paused,
        'laps': laps.map((Lap l) => l.toJson()).toList(),
        'lapStartDistance': lapStartDistance,
        'lapStartSeconds': lapStartSeconds,
        'stepBoundaryDistance': stepBoundaryDistance,
        'stepBoundarySeconds': stepBoundarySeconds,
        'route': route.map((RoutePoint p) => p.toJson()).toList(),
        'workout': workout?.toJson(),
        'workoutStepIndex': workoutStepIndex,
        'workoutStarted': workoutStarted,
        'workoutFinished': workoutFinished,
        'workoutStepStartDistance': workoutStepStartDistance,
        'workoutStepStartSeconds': workoutStepStartSeconds,
      };

  factory RunCheckpoint.fromJson(Map<String, dynamic> json) {
    final DateTime now = DateTime.now();

    List<T> parseList<T>(
      String key,
      T Function(Map<String, dynamic>) build,
    ) {
      final List<dynamic> raw = (json[key] as List<dynamic>?) ?? <dynamic>[];
      final List<T> out = <T>[];
      for (final dynamic item in raw) {
        if (item is! Map) continue;
        try {
          out.add(build(item.cast<String, dynamic>()));
        } catch (_) {
          // Elemento corrotto: si scarta quello, non tutta la corsa.
        }
      }
      return out;
    }

    Workout? workout;
    final Object? rawWorkout = json['workout'];
    if (rawWorkout is Map) {
      try {
        workout = Workout.fromJson(rawWorkout.cast<String, dynamic>());
      } catch (_) {
        // Allenamento illeggibile: la corsa resta recuperabile come libera.
        workout = null;
      }
    }

    return RunCheckpoint(
      schemaVersion: (json['schemaVersion'] as num?)?.toInt() ?? 0,
      savedAt: DateTime.tryParse(json['savedAt'] as String? ?? '') ?? now,
      startTime: DateTime.tryParse(json['startTime'] as String? ?? '') ?? now,
      elapsedSeconds: (json['elapsedSeconds'] as num?)?.toInt() ?? 0,
      distanceMeters: (json['distanceMeters'] as num?)?.toDouble() ?? 0.0,
      paused: json['paused'] as bool? ?? false,
      laps: parseList<Lap>('laps', Lap.fromJson),
      lapStartDistance: (json['lapStartDistance'] as num?)?.toDouble() ?? 0.0,
      lapStartSeconds: (json['lapStartSeconds'] as num?)?.toInt() ?? 0,
      stepBoundaryDistance:
          (json['stepBoundaryDistance'] as num?)?.toDouble() ?? 0.0,
      stepBoundarySeconds:
          (json['stepBoundarySeconds'] as num?)?.toInt() ?? 0,
      route: parseList<RoutePoint>('route', RoutePoint.fromJson),
      workout: workout,
      workoutStepIndex: (json['workoutStepIndex'] as num?)?.toInt() ?? 0,
      workoutStarted: json['workoutStarted'] as bool? ?? false,
      workoutFinished: json['workoutFinished'] as bool? ?? false,
      workoutStepStartDistance:
          (json['workoutStepStartDistance'] as num?)?.toDouble() ?? 0.0,
      workoutStepStartSeconds:
          (json['workoutStepStartSeconds'] as num?)?.toInt() ?? 0,
    );
  }
}
