import '../models/running_activity.dart';
import 'gps_filter.dart';
import 'stats_service.dart';

/// Una distanza per cui l'app tiene il record personale.
class RecordDistance {
  const RecordDistance({
    required this.key,
    required this.label,
    required this.meters,
  });

  /// Chiave stabile, usata per il salvataggio e i confronti.
  final String key;

  /// Etichetta mostrata all'utente.
  final String label;

  final double meters;
}

/// Distanze classiche della corsa su strada.
const List<RecordDistance> kRecordDistances = <RecordDistance>[
  RecordDistance(key: '1k', label: '1 km', meters: 1000),
  RecordDistance(key: '3k', label: '3 km', meters: 3000),
  RecordDistance(key: '5k', label: '5 km', meters: 5000),
  RecordDistance(key: '10k', label: '10 km', meters: 10000),
  RecordDistance(key: 'half', label: 'Mezza maratona', meters: 21097.5),
  RecordDistance(key: 'marathon', label: 'Maratona', meters: 42195),
];

/// Il miglior tempo ottenuto su una distanza, con l'attivita' in cui e' stato
/// fatto.
class DistanceRecord {
  const DistanceRecord({
    required this.distance,
    required this.seconds,
    required this.activityId,
    required this.activityName,
    required this.date,
  });

  final RecordDistance distance;

  /// Tempo impiegato, in secondi.
  final int seconds;

  final String activityId;
  final String activityName;
  final DateTime date;

  /// Passo medio del record, in secondi per chilometro.
  double get paceSecPerKm => seconds / (distance.meters / 1000.0);
}

/// Insieme dei record personali calcolati sullo storico.
class PersonalRecords {
  const PersonalRecords({
    required this.byDistance,
    required this.longestRun,
    required this.bestWeekKm,
    required this.bestWeekStart,
    required this.totalActivities,
    required this.activitiesWithGps,
  });

  /// Record per distanza, in ordine di distanza crescente. Contiene solo le
  /// distanze effettivamente raggiunte almeno una volta.
  final List<DistanceRecord> byDistance;

  /// Attivita' piu' lunga mai registrata.
  final RunningActivity? longestRun;

  /// Settimana con piu' chilometri, e il lunedi' di quella settimana.
  final double bestWeekKm;
  final DateTime? bestWeekStart;

  final int totalActivities;

  /// Quante attivita' hanno un tracciato utilizzabile per i record di
  /// distanza: serve a spiegare all'utente perche' certi record mancano.
  final int activitiesWithGps;

  bool get isEmpty => byDistance.isEmpty && longestRun == null;

  DistanceRecord? recordFor(String key) {
    for (final DistanceRecord r in byDistance) {
      if (r.distance.key == key) return r;
    }
    return null;
  }
}

/// Calcolo dei record personali a partire dalle attivita' salvate.
///
/// COME FUNZIONA IL RECORD DI DISTANZA
/// -----------------------------------
/// Il record sui 5 km non e' "la corsa di 5 km piu' veloce": e' il tratto di 5
/// km piu' veloce percorso in una qualsiasi corsa. Se durante un lungo da 15 km
/// hai spinto per 5 km, quel tratto conta.
///
/// Per trovarlo si scorre il tracciato con una finestra scorrevole: per ogni
/// punto di arrivo si cerca il punto di partenza esattamente a N metri di
/// distanza, si misura il tempo impiegato e si tiene il minore. Il punto di
/// partenza viene interpolato dentro il segmento, cosi' il risultato non
/// dipende da dove sono caduti i campioni GPS.
///
/// L'algoritmo e' lineare nel numero di punti: anche con corse lunghe resta
/// istantaneo. Tutto puro Dart, quindi testabile.
class RecordsService {
  const RecordsService();

  /// Tempo piu' veloce impiegato per coprire [targetMeters] consecutivi dentro
  /// il tracciato. Restituisce `null` se la corsa e' piu' corta del target o se
  /// il tracciato non e' utilizzabile.
  int? fastestTimeForDistance(List<RoutePoint> route, double targetMeters) {
    if (targetMeters <= 0 || route.length < 2) return null;

    final int n = route.length;

    // Distanza cumulata e tempo di ogni punto.
    final List<double> cumulative = List<double>.filled(n, 0.0);
    final List<double> time = List<double>.filled(n, 0.0);
    time[0] = route[0].elapsedSeconds.toDouble();

    for (int i = 1; i < n; i++) {
      final double step = haversineMeters(
        route[i - 1].latitude,
        route[i - 1].longitude,
        route[i].latitude,
        route[i].longitude,
      );
      cumulative[i] = cumulative[i - 1] + (step.isFinite ? step : 0.0);
      final double t = route[i].elapsedSeconds.toDouble();
      // Il tempo deve essere monotono: se il tracciato e' corrotto si ignora
      // l'indietreggiamento invece di produrre record impossibili.
      time[i] = t < time[i - 1] ? time[i - 1] : t;
    }

    if (cumulative[n - 1] < targetMeters) return null;

    double? best;
    int start = 0;

    for (int end = 1; end < n; end++) {
      if (cumulative[end] - cumulative[0] < targetMeters) continue;

      // Si sposta l'inizio in avanti finche' la finestra copre ancora il target.
      while (start + 1 < end &&
          cumulative[end] - cumulative[start + 1] >= targetMeters) {
        start++;
      }

      // A questo punto la partenza esatta cade fra start e start+1.
      final double segment = cumulative[start + 1] - cumulative[start];
      final double excess =
          (cumulative[end] - cumulative[start]) - targetMeters;

      double startTime = time[start];
      if (segment > 0) {
        double fraction = excess / segment;
        if (fraction < 0) fraction = 0;
        if (fraction > 1) fraction = 1;
        startTime = time[start] + (time[start + 1] - time[start]) * fraction;
      }

      final double elapsed = time[end] - startTime;
      if (elapsed > 0 && (best == null || elapsed < best)) {
        best = elapsed;
      }
    }

    if (best == null) return null;
    return best.round();
  }

  /// Calcola tutti i record personali sullo storico fornito.
  PersonalRecords compute(List<RunningActivity> activities) {
    final Map<String, DistanceRecord> best = <String, DistanceRecord>{};
    RunningActivity? longest;
    int withGps = 0;

    for (final RunningActivity activity in activities) {
      if (longest == null || activity.distanceMeters > longest.distanceMeters) {
        longest = activity;
      }

      if (activity.route.length < 2) continue;
      withGps++;

      for (final RecordDistance distance in kRecordDistances) {
        // Salto veloce: se la corsa e' piu' corta del target non puo' avere
        // quel record.
        if (activity.distanceMeters < distance.meters) continue;

        final int? seconds =
            fastestTimeForDistance(activity.route, distance.meters);
        if (seconds == null || seconds <= 0) continue;

        final DistanceRecord candidate = DistanceRecord(
          distance: distance,
          seconds: seconds,
          activityId: activity.id,
          activityName: activity.name,
          date: activity.startTime,
        );

        final DistanceRecord? current = best[distance.key];
        if (current == null || candidate.seconds < current.seconds) {
          best[distance.key] = candidate;
        }
      }
    }

    // Settimana migliore.
    final Map<DateTime, double> weekly = <DateTime, double>{};
    for (final RunningActivity activity in activities) {
      final DateTime week = StatsService.startOfWeek(activity.startTime);
      weekly[week] = (weekly[week] ?? 0) + activity.distanceMeters / 1000.0;
    }
    double bestWeek = 0;
    DateTime? bestWeekStart;
    weekly.forEach((DateTime week, double km) {
      if (km > bestWeek) {
        bestWeek = km;
        bestWeekStart = week;
      }
    });

    // Ordinati per distanza crescente, come in kRecordDistances.
    final List<DistanceRecord> ordered = <DistanceRecord>[];
    for (final RecordDistance distance in kRecordDistances) {
      final DistanceRecord? record = best[distance.key];
      if (record != null) ordered.add(record);
    }

    return PersonalRecords(
      byDistance: ordered,
      longestRun: longest,
      bestWeekKm: bestWeek,
      bestWeekStart: bestWeekStart,
      totalActivities: activities.length,
      activitiesWithGps: withGps,
    );
  }
}
