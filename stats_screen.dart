import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/activity_provider.dart';
import '../services/stats_service.dart';
import '../utils/formatters.dart';
import '../widgets/app_card.dart';
import '../widgets/empty_state.dart';
import '../widgets/metric_card.dart';

/// Statistiche di running e primo indicatore di miglioramento.
class StatsScreen extends StatelessWidget {
  const StatsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final ActivityProvider provider = context.watch<ActivityProvider>();
    final RunningStats stats = provider.stats;
    final ColorScheme scheme = Theme.of(context).colorScheme;

    if (stats.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('Statistiche')),
        body: const EmptyState(
          icon: Icons.insights,
          title: 'Nessun dato disponibile',
          message: 'Registra la tua prima corsa per vedere le statistiche.',
        ),
      );
    }

    final ImprovementResult pace = provider.paceImprovement;
    final ImprovementResult volume = provider.volumeTrend;

    return Scaffold(
      appBar: AppBar(title: const Text('Statistiche')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
          children: <Widget>[
            Row(
              children: <Widget>[
                Expanded(
                  child: MetricCard(
                    label: 'Settimana corrente',
                    value: stats.weekKm.toStringAsFixed(1),
                    unit: 'km',
                    secondary: '${stats.weekActivities} allenamenti',
                    emphasized: true,
                    valueFontSize: 30,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: MetricCard(
                    label: 'Ultime 4 settimane',
                    value: stats.lastFourWeeksKm.toStringAsFixed(1),
                    unit: 'km',
                    secondary: '${stats.lastFourWeeksActivities} allenamenti',
                    valueFontSize: 30,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: <Widget>[
                Expanded(
                  child: MetricCard(
                    label: 'Passo medio recente',
                    value: formatPace(stats.averagePaceSecPerKm),
                    unit: '/km',
                    valueFontSize: 30,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: MetricCard(
                    label: 'Corsa piu lunga',
                    value: formatDistanceKm(stats.longestRunMeters),
                    unit: 'km',
                    valueFontSize: 30,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 24),
            const SectionTitle('Volume settimanale (ultime 8 settimane)'),
            AppCard(
              child: SizedBox(
                height: 160,
                child: _WeeklyBarChart(
                  values: stats.weeklyKm,
                  barColor: scheme.primary,
                  labelColor: scheme.onSurfaceVariant,
                ),
              ),
            ),

            const SizedBox(height: 24),
            const SectionTitle('Andamento'),
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Icon(Icons.speed, color: scheme.primary),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(pace.message,
                            style: const TextStyle(fontSize: 15)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Icon(Icons.stacked_line_chart, color: scheme.primary),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(volume.message,
                            style: const TextStyle(fontSize: 15)),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Le indicazioni sono confronti statistici sui tuoi dati di allenamento. Non sono valutazioni mediche.',
              style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
            ),

            const SizedBox(height: 24),
            const SectionTitle('Totali'),
            AppCard(
              child: Column(
                children: <Widget>[
                  MetricRow(
                    label: 'Distanza totale',
                    value: '${stats.totalKm.toStringAsFixed(1)} km',
                  ),
                  MetricRow(
                    label: 'Attivita registrate',
                    value: '${stats.totalActivities}',
                  ),
                  MetricRow(
                    label: 'Ultima attivita',
                    value: stats.lastActivity == null
                        ? kEmptyValue
                        : formatDateShort(stats.lastActivity!.startTime),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Grafico a barre del volume settimanale, disegnato senza dipendenze esterne.
class _WeeklyBarChart extends StatelessWidget {
  const _WeeklyBarChart({
    required this.values,
    required this.barColor,
    required this.labelColor,
  });

  final List<double> values;
  final Color barColor;
  final Color labelColor;

  @override
  Widget build(BuildContext context) {
    double maxValue = 0;
    for (final double v in values) {
      if (v > maxValue) maxValue = v;
    }
    if (maxValue <= 0) {
      return Center(
        child: Text(
          'Nessun chilometro registrato nelle ultime 8 settimane.',
          textAlign: TextAlign.center,
          style: TextStyle(color: labelColor),
        ),
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: <Widget>[
        for (int i = 0; i < values.length; i++)
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 3),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                children: <Widget>[
                  Text(
                    values[i] <= 0 ? '' : values[i].toStringAsFixed(0),
                    style: TextStyle(fontSize: 11, color: labelColor),
                  ),
                  const SizedBox(height: 4),
                  Container(
                    height: 100 * (values[i] / maxValue),
                    decoration: BoxDecoration(
                      color: i == values.length - 1
                          ? barColor
                          : barColor.withAlpha(120),
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(6),
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    i == values.length - 1 ? 'ora' : '-${values.length - 1 - i}',
                    style: TextStyle(fontSize: 10, color: labelColor),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}
