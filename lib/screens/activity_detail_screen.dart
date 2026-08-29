import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/running_activity.dart';
import '../models/running_shoe.dart';
import '../providers/activity_provider.dart';
import '../providers/shoe_provider.dart';
import '../utils/formatters.dart';
import '../widgets/app_card.dart';
import '../widgets/empty_state.dart';
import '../widgets/lap_table.dart';
import '../widgets/metric_card.dart';

/// Dettaglio di una attivita' salvata.
class ActivityDetailScreen extends StatelessWidget {
  const ActivityDetailScreen({super.key, required this.activityId});

  final String activityId;

  @override
  Widget build(BuildContext context) {
    final ActivityProvider provider = context.watch<ActivityProvider>();
    final ShoeProvider shoes = context.watch<ShoeProvider>();
    final RunningActivity? activity = provider.byId(activityId);

    if (activity == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Attivita')),
        body: const EmptyState(
          icon: Icons.search_off,
          title: 'Attivita non trovata',
          message: 'Potrebbe essere stata eliminata.',
        ),
      );
    }

    final RunningShoe? shoe = shoes.byId(activity.shoeId);
    final ColorScheme scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(activity.name),
        actions: <Widget>[
          IconButton(
            tooltip: 'Elimina',
            icon: const Icon(Icons.delete_outline),
            onPressed: () => _confirmDelete(context, provider, activity),
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
          children: <Widget>[
            Text(
              formatDateLong(activity.startTime),
              style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 14),
            ),
            Text(
              'Inizio ore ${formatTimeShort(activity.startTime)}',
              style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 14),
            ),
            const SizedBox(height: 16),

            Row(
              children: <Widget>[
                Expanded(
                  child: MetricCard(
                    label: 'Distanza',
                    value: formatDistanceKm(activity.distanceMeters),
                    unit: 'km',
                    emphasized: true,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: MetricCard(
                    label: 'Durata',
                    value: formatDuration(activity.duration),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: <Widget>[
                Expanded(
                  child: MetricCard(
                    label: 'Passo medio',
                    value: formatPace(activity.averagePaceSecondsPerKm),
                    unit: '/km',
                    valueFontSize: 30,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: MetricCard(
                    label: 'Lap',
                    value: '${activity.laps.length}',
                    valueFontSize: 30,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 20),
            const SectionTitle('Informazioni'),
            AppCard(
              child: Column(
                children: <Widget>[
                  MetricRow(label: 'Tipo', value: activity.type.label),
                  MetricRow(
                    label: 'Scarpa',
                    value: shoe?.displayName ?? 'Non assegnata',
                  ),
                  MetricRow(
                    label: 'Punti GPS registrati',
                    value: '${activity.route.length}',
                  ),
                  if (activity.heartRateAverage != null)
                    MetricRow(
                      label: 'FC media',
                      value: '${activity.heartRateAverage} bpm',
                    ),
                  if (activity.dynamics?.cadenceSpm != null)
                    MetricRow(
                      label: 'Cadenza',
                      value: '${activity.dynamics!.cadenceSpm} passi/min',
                    ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 52,
              child: OutlinedButton.icon(
                onPressed: () => _changeShoe(context, provider, shoes, activity),
                icon: const Icon(Icons.hiking),
                label: Text(shoe == null
                    ? 'Assegna una scarpa'
                    : 'Cambia scarpa'),
              ),
            ),

            const SizedBox(height: 20),
            const SectionTitle('Lap'),
            AppCard(
              child: LapTable(
                laps: activity.laps,
                showStepColumn: activity.type == ActivityType.workout,
              ),
            ),

            const SizedBox(height: 20),
            AppCard(
              color: scheme.surfaceContainerHigh,
              child: Row(
                children: <Widget>[
                  Icon(Icons.favorite_border, color: scheme.onSurfaceVariant),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Frequenza cardiaca, cadenza, oscillazione verticale, HRV e sonno sono gia previsti nel modello dati: verranno mostrati qui quando sara collegata una sorgente reale (fascia cardio o orologio).',
                      style: TextStyle(
                          fontSize: 13, color: scheme.onSurfaceVariant),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmDelete(
    BuildContext context,
    ActivityProvider provider,
    RunningActivity activity,
  ) async {
    final bool? ok = await showDialog<bool>(
      context: context,
      builder: (BuildContext ctx) => AlertDialog(
        title: const Text('Eliminare l\'attivita?'),
        content: const Text(
            'I chilometri verranno scalati anche dalla scarpa associata.'),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Annulla'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Elimina'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await provider.remove(activity.id);
    if (!context.mounted) return;
    Navigator.of(context).pop();
  }

  Future<void> _changeShoe(
    BuildContext context,
    ActivityProvider provider,
    ShoeProvider shoes,
    RunningActivity activity,
  ) async {
    final List<RunningShoe> available = shoes.activeShoes;
    if (available.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Nessuna scarpa disponibile: aggiungila da SCARPE.')),
      );
      return;
    }

    final String? selected = await showDialog<String>(
      context: context,
      builder: (BuildContext ctx) => AlertDialog(
        title: const Text('Quali scarpe hai usato?'),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: available.length,
            itemBuilder: (BuildContext c, int index) {
              final RunningShoe shoe = available[index];
              return ListTile(
                leading: const Icon(Icons.hiking),
                title: Text(shoe.displayName),
                subtitle: Text('${shoe.totalKm.toStringAsFixed(0)} km'),
                selected: shoe.id == activity.shoeId,
                onTap: () => Navigator.of(ctx).pop(shoe.id),
              );
            },
          ),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(ctx).pop('__none__'),
            child: const Text('Nessuna'),
          ),
        ],
      ),
    );

    if (selected == null) return;
    if (selected == '__none__') {
      await provider.update(activity.copyWith(clearShoe: true));
    } else {
      await provider.update(activity.copyWith(shoeId: selected));
    }
  }
}
