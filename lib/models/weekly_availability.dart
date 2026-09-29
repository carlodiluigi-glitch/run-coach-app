/// Quanto tempo hai per correre, giorno per giorno.
///
/// PERCHE' SERVE
/// -------------
/// I piani di allenamento sono scritti per una settimana da ufficio: qualita'
/// il martedi' e il giovedi', lungo la domenica, perche' la domenica "sei
/// libero". Chi lavora nella ristorazione ha la settimana esattamente al
/// contrario: il sabato e la domenica sono i giorni pieni, e il tempo per
/// correre sta in mezzo alla settimana.
///
/// Un piano che mette il lungo dove non c'e' tempo non e' un piano difficile:
/// e' un piano che non si fa. Quindi il calendario non lo decide lo schema,
/// lo decide il tempo disponibile.
///
/// COME E' FATTA
/// -------------
/// Una mappa da giorno della settimana (1 = lunedi', 7 = domenica) ai minuti
/// che hai quel giorno. Un giorno assente, o a zero, e' un giorno di riposo.
/// I minuti sono il tempo per CORRERE, non il tempo libero: chi mette 60
/// intende un'ora di corsa.
class WeeklyAvailability {
  const WeeklyAvailability(this.minutesByDay);

  /// Giorno della settimana (1-7) -> minuti disponibili.
  final Map<int, int> minutesByDay;

  /// Lo schema classico, ricavato dal solo numero di giorni.
  ///
  /// Serve per i piani creati prima che esistesse questa impostazione: si
  /// continuano ad aprire e a leggere come sono sempre stati.
  factory WeeklyAvailability.fromDaysPerWeek(int daysPerWeek) {
    const Map<int, List<int>> schema = <int, List<int>>{
      3: <int>[2, 4, 7],
      4: <int>[2, 4, 6, 7],
      5: <int>[2, 3, 4, 6, 7],
      6: <int>[1, 2, 3, 4, 6, 7],
    };
    final List<int> days = schema[daysPerWeek.clamp(3, 6)] ?? schema[4]!;
    return WeeklyAvailability(<int, int>{
      for (final int d in days) d: d == 7 ? 120 : 60,
    });
  }

  /// La proposta di partenza per chi apre la schermata la prima volta.
  ///
  /// Non e' una raccomandazione medica, e' solo un punto da cui muoversi: la
  /// prima cosa che l'atleta fa e' cambiarla.
  factory WeeklyAvailability.suggested() => WeeklyAvailability.fromDaysPerWeek(4);

  /// Minimo e massimo accettati, in minuti, e il passo del regolatore.
  static const int minMinutes = 20;
  static const int maxMinutes = 210;
  static const int stepMinutes = 15;

  /// Sotto questo tempo un giorno non regge una seduta vera.
  static const int minUsefulMinutes = 20;

  int minutesOn(int weekday) => minutesByDay[weekday] ?? 0;

  bool runsOn(int weekday) => minutesOn(weekday) >= minUsefulMinutes;

  /// I giorni in cui si corre, dal lunedi' alla domenica.
  List<int> get runDays =>
      <int>[for (int d = 1; d <= 7; d++) if (runsOn(d)) d];

  int get dayCount => runDays.length;

  int get totalMinutes {
    int total = 0;
    for (final int d in runDays) {
      total += minutesOn(d);
    }
    return total;
  }

  bool get isEmpty => runDays.isEmpty;

  /// Il giorno con piu' tempo: e' li' che va il lungo.
  ///
  /// A pari tempo vince la domenica, poi il sabato, poi il giorno piu' tardo
  /// nella settimana. Non e' un vezzo: se il tempo e' lo stesso, il lungo sta
  /// meglio a fine settimana, dove ha piu' giorni facili prima.
  int? get longestDay {
    int? best;
    for (final int d in runDays) {
      if (best == null) {
        best = d;
        continue;
      }
      if (minutesOn(d) > minutesOn(best)) {
        best = d;
      } else if (minutesOn(d) == minutesOn(best) &&
          _tiePriority(d) < _tiePriority(best)) {
        best = d;
      }
    }
    return best;
  }

  static int _tiePriority(int weekday) {
    if (weekday == 7) return 0;
    if (weekday == 6) return 1;
    return 2 + (7 - weekday);
  }

  WeeklyAvailability withDay(int weekday, int minutes) {
    final Map<int, int> next = Map<int, int>.from(minutesByDay);
    if (minutes < minUsefulMinutes) {
      next.remove(weekday);
    } else {
      next[weekday] = minutes.clamp(minMinutes, maxMinutes);
    }
    return WeeklyAvailability(next);
  }

  /// Nome del giorno. 1 = lunedi'.
  static String dayName(int weekday) {
    const List<String> names = <String>[
      'Lunedi\'',
      'Martedi\'',
      'Mercoledi\'',
      'Giovedi\'',
      'Venerdi\'',
      'Sabato',
      'Domenica',
    ];
    return names[(weekday - 1).clamp(0, 6)];
  }

  static String dayShort(int weekday) {
    const List<String> names = <String>[
      'Lun',
      'Mar',
      'Mer',
      'Gio',
      'Ven',
      'Sab',
      'Dom',
    ];
    return names[(weekday - 1).clamp(0, 6)];
  }

  /// Come si legge un tempo: "1:30" invece di "90 minuti".
  static String formatMinutes(int minutes) {
    if (minutes <= 0) return 'Riposo';
    if (minutes < 60) return '$minutes min';
    final int h = minutes ~/ 60;
    final int m = minutes % 60;
    if (m == 0) return '${h}h';
    return '${h}h $m\'';
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        for (final MapEntry<int, int> e in minutesByDay.entries)
          e.key.toString(): e.value,
      };

  factory WeeklyAvailability.fromJson(Map<String, dynamic> json) {
    final Map<int, int> out = <int, int>{};
    for (final MapEntry<String, dynamic> e in json.entries) {
      final int? day = int.tryParse(e.key);
      final int minutes = (e.value as num?)?.toInt() ?? 0;
      if (day == null || day < 1 || day > 7) continue;
      if (minutes >= minUsefulMinutes) out[day] = minutes;
    }
    return WeeklyAvailability(out);
  }
}
