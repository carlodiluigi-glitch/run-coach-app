/// Come e' andata una seduta secondo chi l'ha corsa.
///
/// PERCHE' SERVE
/// -------------
/// Il cronometro dice cosa hai fatto, non quanto ti e' costato. Due sedute
/// identiche sulla carta possono essere una passeggiata o un massacro a
/// seconda di come hai dormito, di che temperatura c'era e di quanto avevi
/// nelle gambe.
///
/// Il confronto fra passo previsto e fatica percepita e' il segnale piu'
/// informativo che un'app di corsa possa raccogliere senza sensori:
///
///  - 4:25 al km con fatica 6 -> stai migliorando;
///  - 4:25 al km con fatica 9 -> sei stanco, o stai covando qualcosa.
///
/// Stesso passo, significato opposto. Nessun GPS puo' distinguerli.
library;

/// Scala di fatica percepita, da 1 a 10.
///
/// E' la scala RPE usata in allenamento (una versione compatta della scala di
/// Borg CR10). Le descrizioni sono scritte per essere scelte in due secondi
/// alla fine di una corsa, non per essere esatte.
class PerceivedEffort {
  const PerceivedEffort._();

  static const int min = 1;
  static const int max = 10;

  /// Descrizione breve di un valore.
  static String label(int value) {
    switch (value.clamp(min, max)) {
      case 1:
        return 'Niente';
      case 2:
        return 'Facilissimo';
      case 3:
        return 'Facile';
      case 4:
        return 'Scorrevole';
      case 5:
        return 'Moderato';
      case 6:
        return 'Sostenuto';
      case 7:
        return 'Impegnativo';
      case 8:
        return 'Molto duro';
      case 9:
        return 'Quasi al limite';
      default:
        return 'Al limite';
    }
  }

  /// Spiegazione concreta, nei termini in cui la si riconosce correndo.
  static String description(int value) {
    switch (value.clamp(min, max)) {
      case 1:
      case 2:
        return 'Potresti andare avanti per ore chiacchierando.';
      case 3:
      case 4:
        return 'Parli a frasi intere senza problemi.';
      case 5:
        return 'Parli, ma a frasi corte.';
      case 6:
        return 'Qualche parola alla volta.';
      case 7:
        return 'Poche parole, e le paghi.';
      case 8:
        return 'Una parola per volta. Contavi i minuti.';
      case 9:
        return 'Non parlavi. Volevi che finisse.';
      default:
        return 'Non avresti retto un minuto in piu\'.';
    }
  }

  /// Quanto la fatica dichiarata rende affidabile la prestazione come misura
  /// della forma, da 0 a 1.
  ///
  /// Una corsa a fatica 4 non dice niente su quanto vai forte: stavi
  /// passeggiando. Una a fatica 9 dice molto.
  ///
  /// VALORI EMPIRICI, TARABILI.
  static double reliabilityWeight(int? rpe) {
    if (rpe == null) return 0.6; // senza dato: prudenza, ne' premio ne' castigo
    final int v = rpe.clamp(min, max);
    if (v >= 9) return 1.0;
    if (v == 8) return 0.9;
    if (v == 7) return 0.7;
    if (v == 6) return 0.5;
    if (v == 5) return 0.3;
    return 0.1;
  }

  /// Quanta fatica residua lascia, da 0 a 1. Serve al motore della fatica.
  static double residualFatigue(int? rpe) {
    if (rpe == null) return 0.4;
    final int v = rpe.clamp(min, max);
    return ((v - 1) / 9.0).clamp(0.0, 1.0);
  }
}

/// Come stavano le gambe.
enum LegsFeel { fresh, normal, heavy }

extension LegsFeelInfo on LegsFeel {
  String get label {
    switch (this) {
      case LegsFeel.fresh:
        return 'Leggere';
      case LegsFeel.normal:
        return 'Normali';
      case LegsFeel.heavy:
        return 'Pesanti';
    }
  }

  String get storageKey => name;

  static LegsFeel fromStorage(String? value) {
    for (final LegsFeel f in LegsFeel.values) {
      if (f.name == value) return f;
    }
    return LegsFeel.normal;
  }
}

/// Il riscontro dell'atleta su una seduta.
///
/// Tutti i campi tranne [rpe] sono facoltativi: la domanda a fine corsa deve
/// poter essere chiusa in due secondi.
class SessionFeedback {
  const SessionFeedback({
    required this.rpe,
    this.legs,
    this.hasPain = false,
    this.painNote,
    this.note,
  });

  /// Fatica percepita, 1-10.
  final int rpe;

  final LegsFeel? legs;

  /// Dolore o fastidio dichiarato.
  ///
  /// NON e' un segnale come gli altri. Nel motore del rischio il dolore chiude
  /// la porta alla qualita': nessun punteggio lo puo' compensare. Un algoritmo
  /// che manda a fare ripetute su un ginocchio che tira fa un danno che
  /// nessun guadagno di forma ripaga.
  final bool hasPain;

  final String? painNote;
  final String? note;

  /// Peso di affidabilita' della prestazione, vedi [PerceivedEffort].
  double get reliabilityWeight => PerceivedEffort.reliabilityWeight(rpe);

  /// Fatica residua lasciata dalla seduta, 0-1.
  double get residualFatigue => PerceivedEffort.residualFatigue(rpe);

  /// `true` se la seduta e' stata dichiarata dura.
  bool get wasHard => rpe >= 7;

  String get rpeLabel => PerceivedEffort.label(rpe);

  SessionFeedback copyWith({
    int? rpe,
    LegsFeel? legs,
    bool? hasPain,
    String? painNote,
    String? note,
  }) =>
      SessionFeedback(
        rpe: rpe ?? this.rpe,
        legs: legs ?? this.legs,
        hasPain: hasPain ?? this.hasPain,
        painNote: painNote ?? this.painNote,
        note: note ?? this.note,
      );

  Map<String, dynamic> toJson() => <String, dynamic>{
        'rpe': rpe,
        'legs': legs?.storageKey,
        'hasPain': hasPain,
        'painNote': painNote,
        'note': note,
      };

  factory SessionFeedback.fromJson(Map<String, dynamic> json) =>
      SessionFeedback(
        rpe: (json['rpe'] as num?)?.toInt().clamp(
                  PerceivedEffort.min,
                  PerceivedEffort.max,
                ) ??
            5,
        legs: json['legs'] == null
            ? null
            : LegsFeelInfo.fromStorage(json['legs'] as String?),
        hasPain: json['hasPain'] as bool? ?? false,
        painNote: json['painNote'] as String?,
        note: json['note'] as String?,
      );
}
