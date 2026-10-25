import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../app/routes.dart';
import '../models/running_activity.dart';
import '../models/running_shoe.dart';
import '../providers/activity_provider.dart';
import '../providers/shoe_provider.dart';
import '../utils/formatters.dart';
import '../widgets/app_card.dart';
import '../widgets/empty_state.dart';

/// Storico di tutte le attivita' salvate.
class ActivityHistoryScreen extends StatelessWidget {
  const ActivityHistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final ActivityProvider provider = context.watch<ActivityProvider>();
    final ShoeProvider shoes = context.watch<ShoeProvider>();
    final List<RunningActivity> activities = provider.activities;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Storico'),
        actions: <Widget>[
          // AGGIUNGERE UNA CORSA A MANO.
          //
          // Sta qui, nello storico, e non nella schermata della corsa: non e'
          // un modo di correre, e' un modo di RACCONTARE una corsa gia' fatta.
          // Metterlo accanto al pulsante di avvio avrebbe invitato a sbagliare
          // proprio chi ha fretta.
          IconButton(
            tooltip: 'Aggiungi una corsa a mano',
            icon: const Icon(Icons.add),
            onPressed: () =>
                Navigator.of(context).pushNamed(AppRoutes.manualRun),
          ),
          IconButton(
            tooltip: 'Statistiche',
            icon: const Icon(Icons.insights),
            onPressed: () => Navigator.of(context).pushNamed(AppRoutes.stats),
          ),
        ],
      ),
      body: activities.isEmpty
          ? const EmptyState(
              icon: Icons.history,
              title: 'Nessuna attivita salvata',
              message:
                  'Le corse registrate compariranno qui, con lap, passo e '
                  'scarpa utilizzata. Con il + in alto puoi aggiungerne una a '
                  'mano: il tapis roulant, o un\'uscita fatta senza telefono.',
            )
          : ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
              itemCount: activities.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (BuildContext context, int index) {
                final RunningActivity activity = activities[index];
                final RunningShoe? shoe = shoes.byId(activity.shoeId);
                return _ActivityTile(activity: activity, shoe: shoe);
              },
            ),
    );
  }
}

class _ActivityTile extends StatelessWidget {
  const _ActivityTile({required this.activity, this.shoe});

  final RunningActivity activity;
  final RunningShoe? shoe;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;

    return AppCard(
      onTap: () => Navigator.of(context)
          .pushNamed(AppRoutes.activityDetail, arguments: activity.id),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Icon(
                _icona(activity.type),
                color: scheme.primary,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  activity.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      fontSize: 17, fontWeight: FontWeight.w700),
                ),
              ),
              Text(
                formatDateShort(activity.startTime),
                style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 13),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: <Widget>[
              Expanded(
                child: _Cell(
                  label: 'Distanza',
                  value: formatDistanceWithUnit(activity.distanceMeters),
                ),
              ),
              Expanded(
                child: _Cell(
                  label: 'Tempo',
                  value: formatDuration(activity.duration),
                ),
              ),
              Expanded(
                child: _Cell(
                  label: 'Passo',
                  value: formatPaceWithUnit(activity.averagePaceSecondsPerKm),
                ),
              ),
            ],
          ),
          if (shoe != null) ...<Widget>[
            const SizedBox(height: 8),
            Row(
              children: <Widget>[
                Icon(Icons.hiking, size: 16, color: scheme.onSurfaceVariant),
                const SizedBox(width: 6),
                Text(
                  shoe!.displayName,
                  style:
                      TextStyle(fontSize: 13, color: scheme.onSurfaceVariant),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _Cell extends StatelessWidget {
  const _Cell({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(label,
            style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant)),
        const SizedBox(height: 2),
        Text(value,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
      ],
    );
  }
}

/// L'icona che distingue i tre tipi a colpo d'occhio.
///
/// Il tapis roulant deve avere la sua, e non per estetica: i suoi chilometri
/// contano nel volume ma non nell'indice di forma, e chi guarda lo storico fra
/// sei mesi deve poter capire subito perche' una certa settimana pesa nei
/// chilometri e non si vede nella stima. Vedi ActivityTypeLabel.isManual.
IconData _icona(ActivityType tipo) {
  switch (tipo) {
    case ActivityType.workout:
      return Icons.list_alt;
    case ActivityType.treadmill:
      return Icons.fitness_center;
    case ActivityType.free:
      return Icons.directions_run;
  }
}
