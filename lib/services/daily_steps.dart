import '../utils/giorni.dart';

/// I passi della giornata, fuori dalla corsa.
///
/// A COSA SERVE
/// ------------
/// A sapere quanto si e' stati in piedi. Un turno da cameriere puo' valere
/// quindici o ventimila passi, e le gambe il giorno dopo lo sentono: e' un
/// carico che la corsa non vede. Qui si misura e si mostra; il coach lo
/// riceve nel testo esportato.
///
/// COME SI MISURA, SENZA TENERE L'APP ACCESA
/// -----------------------------------------
/// Il telefono ha un contatore di passi che conta dall'accensione, sempre,
/// anche ad app chiusa: lo tiene il chip dei sensori, non costa batteria.
/// L'app lo legge ogni volta che la si apre e si salva la lettura. La
/// differenza fra due letture sono i passi fatti in mezzo.
///
/// Due casi da trattare:
///
///  - IL RIAVVIO. Il contatore riparte da zero. Lo si riconosce dall'ora di
///    accensione, che cambia: in quel caso i passi in mezzo sono quelli
///    della lettura nuova, contati dall'accensione.
///  - LA MEZZANOTTE. Se l'ultima lettura e' delle 23 e la successiva delle
///    9, i passi in mezzo sono di due giorni. Si dividono in proporzione al
///    tempo: e' una stima, e la giornata lo dice ([DaySteps.estimated]).
///    Aprire l'app la mattina (per il check-in) la rende quasi esatta.
class DailySteps {
  const DailySteps._();

  /// Due accensioni piu' vicine di cosi' sono la stessa: l'ora di accensione
  /// e' ricavata da due orologi letti in istanti diversi e balla di poco.
  static const Duration sameBoot = Duration(minutes: 2);

  /// Oltre questi passi fra due letture il dato e' rotto, non un turno.
  static const int maxPlausible = 120000;

  /// Un intervallo piu' lungo di cosi' che attraversa la mezzanotte rende la
  /// divisione fra i due giorni una stima vera e propria.
  static const Duration longGap = Duration(hours: 3);

  /// I passi giorno per giorno, dalle letture salvate.
  static Map<DateTime, DaySteps> perDay(List<StepSample> samples) {
    final List<StepSample> s = List<StepSample>.from(samples)
      ..sort((StepSample a, StepSample b) => a.at.compareTo(b.at));

    final Map<DateTime, _Accumulo> giorni = <DateTime, _Accumulo>{};

    for (int i = 1; i < s.length; i++) {
      final StepSample a = s[i - 1];
      final StepSample b = s[i];
      final bool stessaAccensione =
          a.bootAt.difference(b.bootAt).abs() <= sameBoot;

      int passi;
      DateTime da;
      if (stessaAccensione && b.steps >= a.steps) {
        passi = b.steps - a.steps;
        da = a.at;
      } else {
        // Riavvio: la lettura nuova conta dall'accensione.
        passi = b.steps;
        da = b.bootAt.isAfter(a.at) ? b.bootAt : a.at;
      }
      if (passi < 0 || passi > maxPlausible) continue;
      if (!b.at.isAfter(da)) continue;

      _distribuisci(giorni, da, b.at, passi);
    }

    return giorni.map((DateTime k, _Accumulo v) => MapEntry<DateTime, DaySteps>(
          k,
          DaySteps(
            day: k,
            steps: v.passi.round(),
            coveredFrom: v.da,
            coveredTo: v.a,
            estimated: v.stima,
          ),
        ));
  }

  static void _distribuisci(
    Map<DateTime, _Accumulo> giorni,
    DateTime da,
    DateTime a,
    int passi,
  ) {
    final double totaleMs = a.difference(da).inMilliseconds.toDouble();
    if (totaleMs <= 0) return;
    final bool lungo = a.difference(da) > longGap;

    DateTime inizio = da;
    while (inizio.isBefore(a)) {
      final DateTime giorno = soloGiorno(inizio);
      final DateTime domani = piuGiorni(giorno, 1);
      final DateTime fine = domani.isBefore(a) ? domani : a;
      final double quota =
          fine.difference(inizio).inMilliseconds.toDouble() / totaleMs;
      final bool attraversa = giorniFra(da, a) != 0;

      final _Accumulo acc = giorni.putIfAbsent(giorno, () => _Accumulo());
      acc.passi += passi * quota;
      if (acc.da == null || inizio.isBefore(acc.da!)) acc.da = inizio;
      if (acc.a == null || fine.isAfter(acc.a!)) acc.a = fine;
      if (attraversa && lungo) acc.stima = true;

      inizio = fine;
    }
  }
}

class _Accumulo {
  double passi = 0;
  DateTime? da;
  DateTime? a;
  bool stima = false;
}

/// Una lettura del contatore, salvata.
class StepSample {
  const StepSample({
    required this.at,
    required this.steps,
    required this.bootAt,
  });

  /// Quando e' stata fatta la lettura.
  final DateTime at;

  /// Passi dall'accensione del telefono.
  final int steps;

  /// Quando si era acceso il telefono.
  final DateTime bootAt;

  Map<String, dynamic> toJson() => <String, dynamic>{
        't': at.millisecondsSinceEpoch,
        'p': steps,
        'b': bootAt.millisecondsSinceEpoch,
      };

  static StepSample? fromJson(Map<String, dynamic> json) {
    final Object? t = json['t'];
    final Object? p = json['p'];
    final Object? b = json['b'];
    if (t is! int || p is! int || b is! int) return null;
    return StepSample(
      at: DateTime.fromMillisecondsSinceEpoch(t),
      steps: p,
      bootAt: DateTime.fromMillisecondsSinceEpoch(b),
    );
  }
}

/// I passi di un giorno.
class DaySteps {
  const DaySteps({
    required this.day,
    required this.steps,
    required this.coveredFrom,
    required this.coveredTo,
    required this.estimated,
  });

  final DateTime day;
  final int steps;

  /// Da quando a quando il giorno e' coperto dalle letture. Se comincia
  /// dopo mezzanotte, i passi prima non sono contati: "dalle 9:12".
  final DateTime? coveredFrom;
  final DateTime? coveredTo;

  /// Una parte dei passi viene da un intervallo lungo diviso fra due giorni.
  final bool estimated;

  /// Il giorno e' coperto dalla mezzanotte in poi.
  bool get fromMidnight =>
      coveredFrom != null && !coveredFrom!.isAfter(soloGiorno(day));
}
