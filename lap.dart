import '../utils/formatters.dart';

/// Un "lap" (giro/frazione) di una attivita'.
///
/// Puo' essere generato automaticamente (ogni km, o la distanza impostata
/// nelle impostazioni) oppure manualmente dall'utente con il pulsante LAP.
class Lap {
  const Lap({
    required this.number,
    required this.distanceMeters,
    required this.durationSeconds,
    required this.totalTimeSeconds,
    this.manual = false,
    this.stepLabel,
  });

  /// Numero progressivo del lap (parte da 1).
  final int number;

  /// Distanza percorsa nel solo lap, in metri.
  final double distanceMeters;

  /// Durata del solo lap, in secondi (tempo attivo, pause escluse).
  final int durationSeconds;

  /// Tempo totale trascorso dall'inizio attivita' alla chiusura del lap.
  final int totalTimeSeconds;

  /// `true` se il lap e' stato chiuso manualmente dall'utente.
  final bool manual;

  /// Etichetta della fase di allenamento in cui il lap e' stato chiuso
  /// (es. "Ripetuta 3/10"). Nullo per la corsa libera.
  final String? stepLabel;

  /// Passo del lap in secondi per chilometro. `null` se non calcolabile.
  double? get paceSecondsPerKm =>
      paceFromDistanceAndTime(distanceMeters, durationSeconds);

  Map<String, dynamic> toJson() => <String, dynamic>{
        'number': number,
        'distanceMeters': distanceMeters,
        'durationSeconds': durationSeconds,
        'totalTimeSeconds': totalTimeSeconds,
        'manual': manual,
        'stepLabel': stepLabel,
      };

  factory Lap.fromJson(Map<String, dynamic> json) => Lap(
        number: (json['number'] as num?)?.toInt() ?? 0,
        distanceMeters: (json['distanceMeters'] as num?)?.toDouble() ?? 0.0,
        durationSeconds: (json['durationSeconds'] as num?)?.toInt() ?? 0,
        totalTimeSeconds: (json['totalTimeSeconds'] as num?)?.toInt() ?? 0,
        manual: json['manual'] as bool? ?? false,
        stepLabel: json['stepLabel'] as String?,
      );
}
