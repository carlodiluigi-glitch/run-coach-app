/// Come stai stamattina, prima di correre.
///
/// PERCHE' TRE DOMANDE E NON DIECI
/// -------------------------------
/// Un questionario lungo si compila due volte e poi si salta. Tre domande da
/// un tocco si compilano anche il giorno in cui si e' di corsa - e un dato
/// mediocre raccolto tutti i giorni vale infinitamente piu' di un dato
/// perfetto raccolto tre volte.
///
/// Le tre scelte non sono casuali. Sonno, gambe e voglia sono le voci che nei
/// questionari di benessere usati nello sport (tipo l'Hooper) spiegano da sole
/// quasi tutto: aggiungere altre domande aggiunge attrito, non informazione.
///
/// Il dolore sta a parte, e non e' un punteggio. Non si somma e non si media
/// con il resto: chiude la porta alla qualita' e basta. Un motore che manda a
/// fare ripetute su un ginocchio che tira fa un danno che nessun guadagno di
/// forma ripaga.
class DailyCheckIn {
  const DailyCheckIn({
    required this.date,
    required this.sleep,
    required this.legs,
    required this.motivation,
    this.hasPain = false,
    this.painNote,
  });

  /// Il giorno a cui si riferisce, senza orario.
  final DateTime date;

  /// Come hai dormito, 1-5.
  final int sleep;

  /// Come sono le gambe, 1-5.
  final int legs;

  /// Quanta voglia hai di correre, 1-5.
  final int motivation;

  /// Dolore o fastidio dichiarato.
  final bool hasPain;

  final String? painNote;

  static const int min = 1;
  static const int max = 5;

  /// Media delle tre voci, da 1 a 5.
  ///
  /// Le gambe pesano doppio: sono la voce piu' vicina a quello che succede
  /// correndo. Si puo' correre bene dopo una notte storta, molto meno con le
  /// gambe piene.
  double get score {
    final double somma =
        sleep.toDouble() + legs.toDouble() * 2 + motivation.toDouble();
    return somma / 4.0;
  }

  /// Da 0 a 1, per entrare nei conti della prontezza.
  double get normalised => ((score - min) / (max - min)).clamp(0.0, 1.0);

  static String scaleLabel(int value) {
    switch (value.clamp(min, max)) {
      case 1:
        return 'Male';
      case 2:
        return 'Cosi\' cosi\'';
      case 3:
        return 'Normale';
      case 4:
        return 'Bene';
      default:
        return 'Benissimo';
    }
  }

  DailyCheckIn copyWith({
    int? sleep,
    int? legs,
    int? motivation,
    bool? hasPain,
    String? painNote,
    bool clearPainNote = false,
  }) =>
      DailyCheckIn(
        date: date,
        sleep: sleep ?? this.sleep,
        legs: legs ?? this.legs,
        motivation: motivation ?? this.motivation,
        hasPain: hasPain ?? this.hasPain,
        painNote: clearPainNote ? null : (painNote ?? this.painNote),
      );

  Map<String, dynamic> toJson() => <String, dynamic>{
        'date': DateTime(date.year, date.month, date.day).toIso8601String(),
        'sleep': sleep,
        'legs': legs,
        'motivation': motivation,
        'hasPain': hasPain,
        if (painNote != null && painNote!.trim().isNotEmpty)
          'painNote': painNote,
      };

  factory DailyCheckIn.fromJson(Map<String, dynamic> json) {
    final DateTime giorno =
        DateTime.tryParse(json['date'] as String? ?? '') ?? DateTime.now();
    int voce(String chiave) =>
        ((json[chiave] as num?)?.toInt() ?? 3).clamp(min, max);

    return DailyCheckIn(
      date: DateTime(giorno.year, giorno.month, giorno.day),
      sleep: voce('sleep'),
      legs: voce('legs'),
      motivation: voce('motivation'),
      hasPain: json['hasPain'] as bool? ?? false,
      painNote: json['painNote'] as String?,
    );
  }

  /// Il check-in "neutro" da cui parte la schermata: tutto normale, nessun
  /// dolore. Non e' una misura, e' il punto da cui l'atleta si muove.
  factory DailyCheckIn.neutral(DateTime day) => DailyCheckIn(
        date: DateTime(day.year, day.month, day.day),
        sleep: 3,
        legs: 3,
        motivation: 3,
      );
}
