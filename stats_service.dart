import '../models/running_activity.dart';
import '../utils/formatters.dart';

/// Riepilogo statistico calcolato dallo storico attivita'.
class RunningStats {
  const RunningStats({
    required this.weekKm,
    required this.weekActivities,
    required this.lastFourWeeksKm,
    required this.lastFourWeeksActivities,
    required this.totalKm,
    required this.totalActivities,
    required this.averagePaceSecPerKm,
    required this.longestRunMeters,
    required this.weeklyKm,
    this.lastActivity,
  });

  /// Chilometri della settimana corrente (da lunedi').
  final double weekKm;
  final int weekActivities;

  /// Chilometri delle ultime 4 settimane (settimana corrente inclusa).
  final double lastFourWeeksKm;
  final int lastFourWeeksActivities;

  final double totalKm;
  final int totalActivities;

  /// Passo medio recente (ultime 4 settimane) in secondi per km.
  final double? averagePaceSecPerKm;

  final double longestRunMeters;

  /// Chilometri per settimana, dalla piu' vecchia alla piu' recente
  /// (ultime 8 settimane). Utile per il grafico a barre.
  final List<double> weeklyKm;

  final RunningActivity? lastActivity;

  bool get isEmpty => totalActivities == 0;
}

/// Esito dell'analisi di miglioramento.
class ImprovementResult {
  const ImprovementResult({
    required this.hasEnoughData,
    required this.message,
    this.percentChange,
  });

  final bool hasEnoughData;
  final String message;

  /// Variazione percentuale del passo medio (negativa = piu' veloce).
  final double? percentChange;
}

/// Calcolo di statistiche e trend a partire dallo storico attivita'.
///
/// Tutti i metodi sono puri: ricevono la lista di attivita' e restituiscono i
/// risultati, senza dipendenze da Flutter o dai plugin.
class StatsService {
  const StatsService();

  /// Lunedi' della settimana della data indicata, a mezzanotte.
  static DateTime startOfWeek(DateTime date) {
    final DateTime day = DateTime(date.year, date.month, date.day);
    return day.subtract(Duration(days: day.weekday - 1));
  }

  RunningStats compute(List<RunningActivity> activities, {DateTime? now}) {
    final DateTime reference = now ?? DateTime.now();
    final DateTime weekStart = startOfWeek(reference);
    final DateTime fourWeeksStart =
        weekStart.subtract(const Duration(days: 21));

    double weekMeters = 0;
    int weekCount = 0;
    double fourWeeksMeters = 0;
    int fourWeeksCount = 0;
    int fourWeeksSeconds = 0;
    double totalMeters = 0;
    double longest = 0;

    final List<double> weekly = List<double>.filled(8, 0.0);
    final DateTime eightWeeksStart =
        weekStart.subtract(const Duration(days: 49));

    for (final RunningActivity activity in activities) {
      totalMeters += activity.distanceMeters;
      if (activity.distanceMeters > longest) {
        longest = activity.distanceMeters;
      }

      if (!activity.startTime.isBefore(weekStart)) {
        weekMeters += activity.distanceMeters;
        weekCount++;
      }
      if (!activity.startTime.isBefore(fourWeeksStart)) {
        fourWeeksMeters += activity.distanceMeters;
        fourWeeksCount++;
        fourWeeksSeconds += activity.durationSeconds;
      }
      if (!activity.startTime.isBefore(eightWeeksStart)) {
        final int weeksAgo =
            startOfWeek(activity.startTime).difference(eightWeeksStart).inDays ~/
                7;
        if (weeksAgo >= 0 && weeksAgo < weekly.length) {
          weekly[weeksAgo] += activity.distanceMeters / 1000.0;
        }
      }
    }

    final List<RunningActivity> sorted = List<RunningActivity>.from(activities)
      ..sort((RunningActivity a, RunningActivity b) =>
          b.startTime.compareTo(a.startTime));

    return RunningStats(
      weekKm: weekMeters / 1000.0,
      weekActivities: weekCount,
      lastFourWeeksKm: fourWeeksMeters / 1000.0,
      lastFourWeeksActivities: fourWeeksCount,
      totalKm: totalMeters / 1000.0,
      totalActivities: activities.length,
      averagePaceSecPerKm:
          paceFromDistanceAndTime(fourWeeksMeters, fourWeeksSeconds),
      longestRunMeters: longest,
      weeklyKm: weekly,
      lastActivity: sorted.isEmpty ? null : sorted.first,
    );
  }

  /// Analisi semplice del miglioramento del passo.
  ///
  /// METODO (volutamente prudente e non medico)
  /// ------------------------------------------
  /// Si confronta il passo medio delle corse "confrontabili" (distanza fra
  /// [minMeters] e [maxMeters]) delle ultime 4 settimane con quello delle 4
  /// settimane precedenti. Servono almeno [minSamples] corse per periodo:
  /// sotto quella soglia l'app dichiara semplicemente che i dati non bastano,
  /// senza inventare percentuali.
  ImprovementResult computePaceImprovement(
    List<RunningActivity> activities, {
    DateTime? now,
    double minMeters = 4000,
    double maxMeters = 12000,
    int minSamples = 2,
  }) {
    final DateTime reference = now ?? DateTime.now();
    final DateTime recentStart = reference.subtract(const Duration(days: 28));
    final DateTime previousStart = reference.subtract(const Duration(days: 56));

    final List<double> recentPaces = <double>[];
    final List<double> previousPaces = <double>[];

    for (final RunningActivity activity in activities) {
      if (activity.distanceMeters < minMeters ||
          activity.distanceMeters > maxMeters) {
        continue;
      }
      final double? pace = activity.averagePaceSecondsPerKm;
      if (pace == null) continue;

      if (!activity.startTime.isBefore(recentStart)) {
        recentPaces.add(pace);
      } else if (!activity.startTime.isBefore(previousStart)) {
        previousPaces.add(pace);
      }
    }

    if (recentPaces.length < minSamples || previousPaces.length < minSamples) {
      return const ImprovementResult(
        hasEnoughData: false,
        message: 'Servono piu\' allenamenti per calcolare il trend.',
      );
    }

    final double recentAvg = _average(recentPaces);
    final double previousAvg = _average(previousPaces);
    if (previousAvg <= 0) {
      return const ImprovementResult(
        hasEnoughData: false,
        message: 'Servono piu\' allenamenti per calcolare il trend.',
      );
    }

    // Passo piu' basso = piu' veloce, quindi una variazione negativa e' un
    // miglioramento.
    final double change = (recentAvg - previousAvg) / previousAvg * 100.0;
    final double absChange = change.abs();

    if (absChange < 1.0) {
      return ImprovementResult(
        hasEnoughData: true,
        percentChange: change,
        message:
            'Il tuo ritmo medio sui 5-10 km e\' stabile rispetto alle 4 settimane precedenti.',
      );
    }

    if (change < 0) {
      return ImprovementResult(
        hasEnoughData: true,
        percentChange: change,
        message:
            'Il tuo ritmo medio sui 5-10 km e\' migliorato del ${absChange.toStringAsFixed(1)}% rispetto alle 4 settimane precedenti.',
      );
    }

    return ImprovementResult(
      hasEnoughData: true,
      percentChange: change,
      message:
          'Il tuo ritmo medio sui 5-10 km e\' peggiorato del ${absChange.toStringAsFixed(1)}% rispetto alle 4 settimane precedenti.',
    );
  }

  /// Confronto del volume settimanale: settimana corrente vs media delle
  /// 4 settimane precedenti.
  ImprovementResult computeVolumeTrend(
    List<RunningActivity> activities, {
    DateTime? now,
  }) {
    final DateTime reference = now ?? DateTime.now();
    final DateTime weekStart = startOfWeek(reference);
    final DateTime previousStart = weekStart.subtract(const Duration(days: 28));

    double currentKm = 0;
    double previousKm = 0;
    int previousWeeksWithData = 0;
    final Set<int> weeksSeen = <int>{};

    for (final RunningActivity activity in activities) {
      if (!activity.startTime.isBefore(weekStart)) {
        currentKm += activity.distanceMeters / 1000.0;
      } else if (!activity.startTime.isBefore(previousStart)) {
        previousKm += activity.distanceMeters / 1000.0;
        final int weekIndex =
            startOfWeek(activity.startTime).difference(previousStart).inDays ~/ 7;
        weeksSeen.add(weekIndex);
      }
    }
    previousWeeksWithData = weeksSeen.length;

    if (previousWeeksWithData == 0) {
      return const ImprovementResult(
        hasEnoughData: false,
        message: 'Servono piu\' allenamenti per calcolare il trend.',
      );
    }

    final double average = previousKm / previousWeeksWithData;
    if (average <= 0) {
      return const ImprovementResult(
        hasEnoughData: false,
        message: 'Servono piu\' allenamenti per calcolare il trend.',
      );
    }

    final double change = (currentKm - average) / average * 100.0;
    final String direction = change >= 0 ? 'sopra' : 'sotto';
    return ImprovementResult(
      hasEnoughData: true,
      percentChange: change,
      message:
          'Questa settimana sei ${change.abs().toStringAsFixed(0)}% $direction la tua media delle ultime 4 settimane (${average.toStringAsFixed(1)} km).',
    );
  }

  static double _average(List<double> values) {
    if (values.isEmpty) return 0;
    double sum = 0;
    for (final double v in values) {
      sum += v;
    }
    return sum / values.length;
  }
}
