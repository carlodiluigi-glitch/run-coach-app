/// Funzioni di formattazione usate in tutta l'app.
///
/// Tutte le funzioni sono "pure" (nessuna dipendenza da Flutter o da plugin)
/// cosi' possono essere testate con `flutter test` senza inizializzare nulla.
library;

/// Placeholder mostrato quando il dato non e' ancora disponibile.
const String kEmptyPace = '--:--';
const String kEmptyValue = '--';

String _two(int value) => value.toString().padLeft(2, '0');

/// Formatta una durata in `H:MM:SS` (oppure `MM:SS` se sotto l'ora).
String formatDuration(Duration duration) {
  final int totalSeconds = duration.inSeconds.abs();
  final int hours = totalSeconds ~/ 3600;
  final int minutes = (totalSeconds % 3600) ~/ 60;
  final int seconds = totalSeconds % 60;
  if (hours > 0) {
    return '$hours:${_two(minutes)}:${_two(seconds)}';
  }
  return '${_two(minutes)}:${_two(seconds)}';
}

/// Formatta una durata espressa in secondi.
String formatSeconds(int seconds) => formatDuration(Duration(seconds: seconds));

/// Formatta una durata in forma "parlata"/compatta, es. `15 min`, `1h 05min`.
String formatDurationShort(int seconds) {
  if (seconds < 60) {
    return '$seconds s';
  }
  final int minutes = seconds ~/ 60;
  if (minutes < 60) {
    final int rest = seconds % 60;
    return rest == 0 ? '$minutes min' : '$minutes:${_two(rest)} min';
  }
  final int hours = minutes ~/ 60;
  final int restMinutes = minutes % 60;
  return '${hours}h ${_two(restMinutes)}min';
}

/// Converte metri in chilometri con [decimals] decimali (default 2).
///
/// Esempio: `8543.2` -> `8.54`
String formatDistanceKm(double meters, {int decimals = 2}) {
  if (meters.isNaN || meters.isInfinite || meters < 0) {
    return (0.0).toStringAsFixed(decimals);
  }
  return (meters / 1000.0).toStringAsFixed(decimals);
}

/// Come [formatDistanceKm] ma con l'unita': `8.54 km`.
String formatDistanceKmWithUnit(double meters, {int decimals = 2}) =>
    '${formatDistanceKm(meters, decimals: decimals)} km';

/// Formatta una distanza scegliendo automaticamente metri o chilometri.
///
/// Sotto i 1000 m mostra i metri interi (utile per le ripetute: `400 m`).
String formatDistanceAuto(double meters) {
  if (meters.isNaN || meters.isInfinite) {
    return kEmptyValue;
  }
  if (meters < 1000) {
    return '${meters.round()} m';
  }
  return formatDistanceKmWithUnit(meters);
}

/// Formatta un passo espresso in secondi per chilometro come `m:ss`.
///
/// Restituisce `--:--` quando il dato non e' attendibile (null, zero, valori
/// assurdi). Serve per evitare divisioni per zero e numeri impossibili quando
/// il GPS non ha ancora dati sufficienti.
String formatPace(double? secondsPerKm) {
  if (secondsPerKm == null ||
      secondsPerKm.isNaN ||
      secondsPerKm.isInfinite ||
      secondsPerKm <= 0 ||
      secondsPerKm > 3599) {
    return kEmptyPace;
  }
  final int total = secondsPerKm.round();
  final int minutes = total ~/ 60;
  final int seconds = total % 60;
  return '$minutes:${_two(seconds)}';
}

/// Come [formatPace] ma con l'unita': `5:23 /km`.
String formatPaceWithUnit(double? secondsPerKm) => '${formatPace(secondsPerKm)} /km';

/// Formatta un intervallo di passo target: `4:00-4:10 /km`.
String formatPaceRange(double? fastestSecPerKm, double? slowestSecPerKm) {
  if (fastestSecPerKm == null && slowestSecPerKm == null) {
    return kEmptyValue;
  }
  if (fastestSecPerKm != null && slowestSecPerKm != null) {
    return '${formatPace(fastestSecPerKm)}-${formatPace(slowestSecPerKm)} /km';
  }
  if (fastestSecPerKm != null) {
    return 'max ${formatPaceWithUnit(fastestSecPerKm)}';
  }
  return 'min ${formatPaceWithUnit(slowestSecPerKm)}';
}

/// Velocita' in km/h a partire da m/s.
String formatSpeedKmh(double? metersPerSecond) {
  if (metersPerSecond == null ||
      metersPerSecond.isNaN ||
      metersPerSecond.isInfinite ||
      metersPerSecond < 0) {
    return kEmptyValue;
  }
  return '${(metersPerSecond * 3.6).toStringAsFixed(1)} km/h';
}

/// Converte un passo (sec/km) nella velocita' corrispondente (m/s).
double? paceToSpeed(double? secondsPerKm) {
  if (secondsPerKm == null || secondsPerKm <= 0) return null;
  return 1000.0 / secondsPerKm;
}

/// Converte una velocita' (m/s) nel passo corrispondente (sec/km).
///
/// Restituisce `null` se la velocita' e' troppo bassa per essere significativa
/// (evita divisioni per zero e passi di ore per chilometro).
double? speedToPace(double? metersPerSecond) {
  if (metersPerSecond == null || metersPerSecond <= 0.28) return null;
  return 1000.0 / metersPerSecond;
}

/// Calcola il passo medio in sec/km da metri e secondi.
double? paceFromDistanceAndTime(double meters, int seconds) {
  if (meters < 20 || seconds <= 0) return null;
  final double pace = seconds / (meters / 1000.0);
  if (pace <= 0 || pace > 3599) return null;
  return pace;
}

const List<String> _mesiIt = <String>[
  'gennaio',
  'febbraio',
  'marzo',
  'aprile',
  'maggio',
  'giugno',
  'luglio',
  'agosto',
  'settembre',
  'ottobre',
  'novembre',
  'dicembre',
];

const List<String> _giorniIt = <String>[
  'lunedi',
  'martedi',
  'mercoledi',
  'giovedi',
  'venerdi',
  'sabato',
  'domenica',
];

/// Data in formato `28/08/2026`.
String formatDateShort(DateTime date) =>
    '${_two(date.day)}/${_two(date.month)}/${date.year}';

/// Data e ora in formato `28/08/2026 18:30`.
String formatDateTimeShort(DateTime date) =>
    '${formatDateShort(date)} ${_two(date.hour)}:${_two(date.minute)}';

/// Data estesa in italiano: `venerdi 28 agosto 2026`.
String formatDateLong(DateTime date) {
  final String giorno = _giorniIt[(date.weekday - 1).clamp(0, 6)];
  final String mese = _mesiIt[(date.month - 1).clamp(0, 11)];
  return '$giorno ${date.day} $mese ${date.year}';
}

/// Ora in formato `18:30`.
String formatTimeShort(DateTime date) => '${_two(date.hour)}:${_two(date.minute)}';

/// Descrizione relativa semplice: `oggi`, `ieri`, `3 giorni fa`, oppure la data.
String formatRelativeDay(DateTime date, {DateTime? now}) {
  final DateTime reference = now ?? DateTime.now();
  final DateTime a = DateTime(date.year, date.month, date.day);
  final DateTime b = DateTime(reference.year, reference.month, reference.day);
  final int days = b.difference(a).inDays;
  if (days == 0) return 'oggi';
  if (days == 1) return 'ieri';
  if (days > 1 && days < 7) return '$days giorni fa';
  return formatDateShort(date);
}
