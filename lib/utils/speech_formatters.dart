/// Formattazione dei numeri **per la voce**, non per lo schermo.
///
/// PERCHE' SERVE UN FILE A PARTE
/// -----------------------------
/// Quello che si legge bene sullo schermo si ascolta male. Se al motore vocale
/// si passa "5:23" la sintesi italiana legge "cinque due tre" oppure "cinque
/// e ventitre" senza unita' di misura, e mentre si corre non si capisce.
/// Se si passa "8.54" legge "otto punto cinquantaquattro".
///
/// Qui i numeri vengono trasformati in frasi pronunciabili:
///   5:23  ->  "cinque e ventitre al chilometro"
///   8540  ->  "otto chilometri e cinquecento metri"
///   900 s ->  "quindici minuti"
///
/// Tutte le funzioni sono pure: nessuna dipendenza da Flutter o dai plugin,
/// quindi sono testabili con `flutter test`.
///
/// Come per lo schermo, i numeri arrivano in metri e in secondi al chilometro
/// e vengono convertiti qui secondo l'unita' scelta: il coach dice "al
/// miglio" se e' quello che l'atleta ha chiesto, ma dentro l'app resta tutto
/// metrico.
library;

import '../models/user_settings.dart';
import 'units.dart';

/// Numeri da zero a venti scritti in lettere: la sintesi vocale li pronuncia
/// meglio delle cifre quando sono isolati (es. "quattrocento metri").
const List<String> _unita = <String>[
  'zero',
  'uno',
  'due',
  'tre',
  'quattro',
  'cinque',
  'sei',
  'sette',
  'otto',
  'nove',
  'dieci',
  'undici',
  'dodici',
  'tredici',
  'quattordici',
  'quindici',
  'sedici',
  'diciassette',
  'diciotto',
  'diciannove',
  'venti',
];

/// Scrive in lettere i numeri piccoli (0-20); sopra restituisce la cifra.
///
/// Non serve un convertitore completo: oltre il venti la sintesi vocale legge
/// correttamente le cifre.
String spokenNumber(int value) {
  if (value >= 0 && value < _unita.length) return _unita[value];
  return value.toString();
}

/// Durata parlata: `900` -> "quindici minuti", `95` -> "un minuto e
/// trentacinque secondi", `45` -> "quarantacinque secondi".
String spokenDuration(int totalSeconds) {
  final int seconds = totalSeconds < 0 ? 0 : totalSeconds;

  if (seconds < 60) {
    return '$seconds second${seconds == 1 ? 'o' : 'i'}';
  }

  final int hours = seconds ~/ 3600;
  final int minutes = (seconds % 3600) ~/ 60;
  final int rest = seconds % 60;

  final List<String> parts = <String>[];
  if (hours > 0) {
    parts.add(hours == 1 ? 'un\'ora' : '$hours ore');
  }
  if (minutes > 0) {
    parts.add(minutes == 1 ? 'un minuto' : '$minutes minuti');
  }
  if (rest > 0 && hours == 0) {
    parts.add('$rest second${rest == 1 ? 'o' : 'i'}');
  }
  if (parts.isEmpty) return 'zero secondi';
  return parts.join(' e ');
}

/// Distanza parlata: `400` -> "quattrocento metri",
/// `8540` -> "otto chilometri e cinquecento metri", `2000` -> "due chilometri".
String spokenDistance(double meters, {UnitSystem? units}) {
  if (meters.isNaN || meters.isInfinite || meters < 0) return 'zero metri';

  final UnitSystem u = units ?? activeUnits;

  if (meters < shortDistanceLimitMeters) {
    final int rounded = meters.round();
    return '$rounded metr${rounded == 1 ? 'o' : 'i'}';
  }

  final double per = u.metersPerUnit;
  final int whole = (meters ~/ per).toInt();
  // Il resto si arrotonda ai cento metri: "e cinquecento metri" e' piu'
  // naturale di "e cinquecentoquarantadue metri". In miglia si arrotonda al
  // decimo, che e' come si parla ("otto virgola tre miglia").
  if (u.isImperial) {
    final double value = u.distanceFrom(meters);
    final String text = value.toStringAsFixed(1).replaceAll('.', ',');
    return value < 1.05 && value > 0.95 ? 'un miglio' : '$text miglia';
  }

  final int restMeters = ((meters % per) / 100).round() * 100;
  final String wholePart = whole == 1 ? u.spokenOne : '$whole ${u.spokenMany}';
  if (restMeters <= 0) return wholePart;
  if (restMeters >= per) {
    final int next = whole + 1;
    return next == 1 ? u.spokenOne : '$next ${u.spokenMany}';
  }
  return '$wholePart e $restMeters metri';
}

/// Passo parlato: `323` -> "cinque e ventitre al chilometro".
///
/// Restituisce `null` quando il passo non e' attendibile: in quel caso il
/// coach semplicemente non lo annuncia, invece di dire un numero inventato.
String? spokenPace(double? secondsPerKm, {UnitSystem? units}) {
  if (secondsPerKm == null ||
      secondsPerKm.isNaN ||
      secondsPerKm.isInfinite ||
      secondsPerKm <= 0 ||
      secondsPerKm > 3599) {
    return null;
  }
  final UnitSystem u = units ?? activeUnits;
  final int total = u.paceFrom(secondsPerKm).round();
  final int minutes = total ~/ 60;
  final int seconds = total % 60;

  if (seconds == 0) {
    return '$minutes minuti netti ${u.spokenPer}';
  }
  // "cinque e ventitre" e' il modo in cui un corridore legge 5:23.
  return '$minutes e ${seconds.toString().padLeft(2, '0')} ${u.spokenPer}';
}

/// Velocita' parlata, con una cifra decimale letta con la virgola.
String spokenSpeed(double? metersPerSecond, {UnitSystem? units}) {
  if (metersPerSecond == null ||
      metersPerSecond.isNaN ||
      metersPerSecond.isInfinite ||
      metersPerSecond <= 0) {
    return 'velocita non disponibile';
  }
  final UnitSystem u = units ?? activeUnits;
  final String text =
      u.speedFrom(metersPerSecond).toStringAsFixed(1).replaceAll('.', ',');
  return '$text ${u.spokenSpeed}';
}
