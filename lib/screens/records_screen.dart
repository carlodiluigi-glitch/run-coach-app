import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../app/routes.dart';
import '../providers/activity_provider.dart';
import '../services/records_service.dart';
import '../utils/formatters.dart';
import '../widgets/app_card.dart';
import '../widgets/empty_state.dart';
import '../widgets/metric_card.dart';

/// Record personali: miglior tempo su ogni distanza classica, corsa piu'
/// lunga, settimana migliore.
class RecordsScreen extends StatelessWidget {
  const RecordsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final ActivityProvider provider = context.watch<ActivityProvider>();
    final PersonalRecords records = provider.records;
    final ColorScheme scheme = Theme.of(context).colorScheme;

    if (records.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('Record personali')),
        body: const EmptyState(
          icon: Icons.emoji_events_outlined,
          title: 'Nessun record ancora',
          message:
              'I record si calcolano dalle corse registrate. Dopo la prima uscita compariranno qui.',
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Record personali')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
          children: <Widget>[
            const SectionTitle('Migliori tempi'),

            if (records.byDistance.isEmpty)
              AppCard(
                child: Row(
                  children: <Widget>[
                    Icon(Icons.info_outline, color: scheme.primary),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        records.activitiesWithGps == 0
                            ? 'Nessuna corsa ha ancora un tracciato GPS utilizzabile.'
                            : 'Nessuna corsa ha ancora raggiunto una distanza da record. Il primo traguardo e\' il chilometro.',
                        style: TextStyle(color: scheme.onSurfaceVariant),
                      ),
                    ),
                  ],
                ),
              )
            else
              for (final DistanceRecord record in records.byDistance)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _RecordCard(record: record),
                ),

            const SizedBox(height: 12),
            AppCard(
              color: scheme.surfaceContainerHigh,
              child: Row(
                children: <Widget>[
                  Icon(Icons.lightbulb_outline,
                      size: 20, color: scheme.onSurfaceVariant),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Il record non e\' la corsa piu\' veloce su quella distanza, ma il tratto piu\' veloce dentro una corsa qualsiasi: se durante un lungo hai spinto per 5 km, quel tratto conta.',
                      style: TextStyle(
                          fontSize: 13, color: scheme.onSurfaceVariant),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),
            const SectionTitle('Altri primati'),
            Row(
              children: <Widget>[
                Expanded(
                  child: MetricCard(
                    label: 'Corsa piu lunga',
                    value: records.longestRun == null
                        ? kEmptyValue
                        : formatDistanceKm(records.longestRun!.distanceMeters),
                    unit: records.longestRun == null ? null : 'km',
                    secondary: records.longestRun == null
                        ? null
                        : formatDateShort(records.longestRun!.startTime),
                    valueFontSize: 30,
                    emphasized: true,
                    onTap: records.longestRun == null
                        ? null
                        : () => Navigator.of(context).pushNamed(
                              AppRoutes.activityDetail,
                              arguments: records.longestRun!.id,
                            ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: MetricCard(
                    label: 'Settimana migliore',
                    value: records.bestWeekKm <= 0
                        ? kEmptyValue
                        : records.bestWeekKm.toStringAsFixed(1),
                    unit: records.bestWeekKm <= 0 ? null : 'km',
                    secondary: records.bestWeekStart == null
                        ? null
                        : 'dal ${formatDateShort(records.bestWeekStart!)}',
                    valueFontSize: 30,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),
            AppCard(
              child: MetricRow(
                label: 'Attivita registrate',
                value: '${records.totalActivities}',
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RecordCard extends StatelessWidget {
  const _RecordCard({required this.record});

  final DistanceRecord record;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;

    return AppCard(
      onTap: () => Navigator.of(context)
          .pushNamed(AppRoutes.activityDetail, arguments: record.activityId),
      child: Row(
        children: <Widget>[
          Container(
            width: 56,
            height: 56,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: scheme.primaryContainer,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(Icons.emoji_events,
                color: scheme.onPrimaryContainer, size: 28),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text(
                  record.distance.label.toUpperCase(),
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.0,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  formatDuration(Duration(seconds: record.seconds)),
                  style: const TextStyle(
                    fontSize: 30,
                    fontWeight: FontWeight.w800,
                    height: 1.1,
                    fontFeatures: <FontFeature>[FontFeature.tabularFigures()],
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${formatPaceWithUnit(record.paceSecPerKm)} - ${formatDateShort(record.date)}',
                  style:
                      TextStyle(fontSize: 13, color: scheme.onSurfaceVariant),
                ),
              ],
            ),
          ),
          Icon(Icons.chevron_right, color: scheme.onSurfaceVariant),
        ],
      ),
    );
  }
}
