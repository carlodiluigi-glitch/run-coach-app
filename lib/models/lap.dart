import '../utils/formatters.dart';
import 'workout_step.dart';

/// Un "lap" (giro/frazione) di una attivita'.
///
/// COME NASCE UN LAP
/// -----------------
/// Un lap puo' avere tre origini diverse, e distinguerle conta perche' nello
/// storico hanno significati diversi:
///
///  1. **Automatico a distanza** - ogni chilometro (o la distanza scelta nelle
///     impostazioni). Ha senso solo nella corsa libera: durante un allenamento
///     strutturato taglierebbe le ripetute a meta'.
///  2. **Da step di allenamento** - la fine di ogni ripetuta o recupero chiude
///     il lap, cosi' le frazioni coincidono con l'allenamento reale.
///  3. **Manuale** - premendo il pulsante LAP, in qualsiasi momento, anche
///     durante un allenamento strutturato.
class Lap {
  const Lap({
    required this.number,
    required this.distanceMeters,
    required this.durationSeconds,
    required this.totalTimeSeconds,
    this.manual = false,
    this.stepLabel,
    this.stepType,
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

  /// Etichetta leggibile della fase in cui il lap e' stato chiuso
  /// (es. "Ripetuta 3/10"). Nullo per la corsa libera.
  ///
  /// E' pensata per essere mostrata cosi' com'e': include il numero di
  /// ripetizione, che [stepType] da solo non puo' esprimere.
  final String? stepLabel;

  /// Tipo della fase in cui il lap e' stato chiuso. Nullo per la corsa libera.
  ///
  /// PERCHE' OLTRE A [stepLabel]: l'etichetta e' testo, buono da mostrare ma
  /// inservibile per confrontare o raggruppare. Con il tipo si possono
  /// selezionare tutte le ripetute di una sessione e calcolarne il passo
  /// medio, cosa impossibile facendo il parsing di una stringa.
  final StepType? stepType;

  /// `true` se il lap e' stato chiuso dalla fine di uno step di allenamento
  /// (non da un chilometro automatico ne' dal pulsante).
  bool get isFromWorkoutStep => stepType != null && !manual;

  /// Etichetta di provenienza da mostrare nello storico.
  ///
  /// Restituisce `null` per i lap automatici della corsa libera: li' il numero
  /// del lap dice gia' tutto e aggiungere testo sarebbe solo rumore.
  String? get sourceLabel {
    if (manual) {
      final String? step = stepLabel;
      return step == null ? 'Frazione manuale' : 'Frazione manuale - $step';
    }
    return stepLabel ?? stepType?.label;
  }

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
        'stepType': stepType?.name,
      };

  /// Ricostruisce un lap dal JSON salvato.
  ///
  /// Le attivita' registrate prima dell'introduzione di [stepType] non hanno
  /// quel campo: restano leggibili e il tipo resta nullo. Il controllo sul
  /// null e' necessario perche' `fromStorage` interpreta un valore
  /// sconosciuto come `generic`, che qui sarebbe un'informazione inventata.
  factory Lap.fromJson(Map<String, dynamic> json) {
    final Object? rawStepType = json['stepType'];
    return Lap(
      number: (json['number'] as num?)?.toInt() ?? 0,
      distanceMeters: (json['distanceMeters'] as num?)?.toDouble() ?? 0.0,
      durationSeconds: (json['durationSeconds'] as num?)?.toInt() ?? 0,
      totalTimeSeconds: (json['totalTimeSeconds'] as num?)?.toInt() ?? 0,
      manual: json['manual'] as bool? ?? false,
      stepLabel: json['stepLabel'] as String?,
      stepType: rawStepType == null
          ? null
          : StepTypeLabel.fromStorage(rawStepType as String?),
    );
  }
}
