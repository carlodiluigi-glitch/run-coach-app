/// Un valore stimato, con quanto ci si puo' fidare, da dove viene e quando e'
/// stato calcolato.
///
/// PERCHE' ESISTE QUESTA CLASSE
/// ----------------------------
/// Un motore di allenamento passa il tempo a stimare cose che non puo'
/// misurare: la forma, il passo di soglia, quanto sei recuperato. Se queste
/// stime girano per il codice come semplici numeri, nessuno sa piu' se il
/// 4:25 al chilometro viene da una gara di domenica scorsa o da un'ipotesi
/// fatta su due corse lente di tre mesi fa.
///
/// Portandosi dietro la confidenza, il motore puo' fare la cosa giusta:
/// essere prudente quando sa poco, e diventare piu' preciso man mano che
/// raccoglie dati. E l'app puo' dirlo all'utente invece di fingere certezze.
///
/// Regola che vale in tutto il motore: **mai inventare un dato**. Se un valore
/// non c'e', il campo e' `null` e chi lo usa deve gestirlo.
library;

/// Da dove arriva una stima.
enum EstimateSource {
  /// Inserito a mano dall'utente (peso, personal best, eta').
  userEntered,

  /// Da una gara vera.
  race,

  /// Da un test o da un tratto tirato apposta.
  timeTrial,

  /// Da una seduta di qualita' registrata.
  workout,

  /// Dal tratto piu' veloce dentro una corsa normale.
  runSegment,

  /// Calcolato a partire da altre stime.
  derived,

  /// Valore di partenza usato finche' non ci sono dati.
  defaultValue,
}

extension EstimateSourceInfo on EstimateSource {
  String get label {
    switch (this) {
      case EstimateSource.userEntered:
        return 'inserito da te';
      case EstimateSource.race:
        return 'da una gara';
      case EstimateSource.timeTrial:
        return 'da un test';
      case EstimateSource.workout:
        return 'da un allenamento';
      case EstimateSource.runSegment:
        return 'da un tratto in allenamento';
      case EstimateSource.derived:
        return 'calcolato';
      case EstimateSource.defaultValue:
        return 'valore di partenza';
    }
  }

  /// Quanto vale una prestazione di questa provenienza come misura della
  /// forma, da 0 a 1.
  ///
  /// VALORI EMPIRICI, TARABILI. Il ragionamento: in gara ci si spreme davvero,
  /// in allenamento quasi mai fino in fondo. Un tratto veloce dentro una corsa
  /// normale e' il segnale piu' debole, perche' non si sa se stavi spingendo o
  /// se era solo una discesa.
  double get reliability {
    switch (this) {
      case EstimateSource.race:
        return 1.0;
      case EstimateSource.timeTrial:
        return 0.85;
      case EstimateSource.workout:
        return 0.65;
      case EstimateSource.runSegment:
        return 0.45;
      case EstimateSource.userEntered:
        return 0.80;
      case EstimateSource.derived:
        return 0.50;
      case EstimateSource.defaultValue:
        return 0.10;
    }
  }

  String get storageKey => name;

  static EstimateSource fromStorage(String? value) {
    for (final EstimateSource s in EstimateSource.values) {
      if (s.name == value) return s;
    }
    return EstimateSource.defaultValue;
  }
}

/// Un valore con la sua incertezza.
class Estimate<T> {
  const Estimate({
    required this.value,
    required this.confidence,
    required this.source,
    required this.updatedAt,
    this.note,
  });

  final T value;

  /// Da 0 a 1. Non arriva mai a 1: su un corpo umano non si e' mai certi.
  final double confidence;

  final EstimateSource source;
  final DateTime updatedAt;

  /// Spiegazione breve, da mostrare all'utente.
  final String? note;

  /// Soglie di lettura della confidenza. Sotto [low] il motore deve essere
  /// prudente e l'app deve dirlo apertamente.
  static const double low = 0.35;
  static const double good = 0.65;

  bool get isWeak => confidence < low;
  bool get isStrong => confidence >= good;

  /// Etichetta leggibile: "buona", "media", "debole".
  String get confidenceLabel {
    if (isStrong) return 'buona';
    if (confidence >= low) return 'media';
    return 'debole';
  }

  Estimate<T> copyWith({
    T? value,
    double? confidence,
    EstimateSource? source,
    DateTime? updatedAt,
    String? note,
  }) =>
      Estimate<T>(
        value: value ?? this.value,
        confidence: confidence ?? this.confidence,
        source: source ?? this.source,
        updatedAt: updatedAt ?? this.updatedAt,
        note: note ?? this.note,
      );

  @override
  String toString() =>
      'Estimate($value, confidenza ${(confidence * 100).round()}%, '
      '${source.label})';
}

/// Un intervallo di valori: il modo onesto di esprimere un passo o una
/// previsione.
///
/// L'ampiezza non e' fissa: si allarga quando la confidenza e' bassa. Dire
/// "soglia 4:25" quando si hanno due corse in archivio e' falsa precisione;
/// dire "fra 4:15 e 4:35" e' la verita'.
class Range {
  const Range(this.low, this.high);

  final double low;
  final double high;

  double get centre => (low + high) / 2;
  double get width => high - low;

  bool contains(double value) => value >= low && value <= high;

  /// Quanto un valore sta fuori dall'intervallo, in unita' assolute.
  /// Zero se e' dentro.
  double distanceFrom(double value) {
    if (value < low) return low - value;
    if (value > high) return value - high;
    return 0;
  }

  Range shifted(double delta) => Range(low + delta, high + delta);

  /// Allarga l'intervallo di [amount] per lato.
  Range widened(double amount) => Range(low - amount, high + amount);

  @override
  String toString() => '${low.toStringAsFixed(1)} - ${high.toStringAsFixed(1)}';
}
