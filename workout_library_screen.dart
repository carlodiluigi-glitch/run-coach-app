import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../app/routes.dart';
import '../models/workout.dart';
import '../models/workout_step.dart';
import '../providers/workout_provider.dart';
import '../utils/formatters.dart';
import '../widgets/app_card.dart';
import '../widgets/empty_state.dart';

/// Libreria degli allenamenti programmati.
class WorkoutLibraryScreen extends StatelessWidget {
  const WorkoutLibraryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final WorkoutProvider provider = context.watch<WorkoutProvider>();
    final List<Workout> workouts = provider.workouts;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Allenamenti'),
        actions: <Widget>[
          IconButton(
            tooltip: 'Aggiungi esempio',
            icon: const Icon(Icons.auto_awesome_outlined),
            onPressed: () async {
              await provider.save(WorkoutProvider.sampleIntervalWorkout());
              if (!context.mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                    content: Text('Allenamento di esempio aggiunto.')),
              );
            },
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () =>
            Navigator.of(context).pushNamed(AppRoutes.workoutBuilder),
        icon: const Icon(Icons.add),
        label: const Text('Nuovo'),
      ),
      body: workouts.isEmpty
          ? EmptyState(
              icon: Icons.list_alt,
              title: 'Nessun allenamento salvato',
              message:
                  'Crea il tuo primo allenamento a intervalli, oppure aggiungi quello di esempio dal pulsante in alto a destra.',
              actionLabel: 'Crea allenamento',
              onAction: () =>
                  Navigator.of(context).pushNamed(AppRoutes.workoutBuilder),
            )
          : ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
              itemCount: workouts.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (BuildContext context, int index) {
                final Workout workout = workouts[index];
                return _WorkoutCard(workout: workout);
              },
            ),
    );
  }
}

class _WorkoutCard extends StatelessWidget {
  const _WorkoutCard({required this.workout});

  final Workout workout;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final WorkoutProvider provider = context.read<WorkoutProvider>();

    return AppCard(
      onTap: () => Navigator.of(context)
          .pushNamed(AppRoutes.workoutBuilder, arguments: workout),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  workout.name,
                  style: const TextStyle(
                      fontSize: 18, fontWeight: FontWeight.w700),
                ),
              ),
              PopupMenuButton<String>(
                onSelected: (String value) async {
                  switch (value) {
                    case 'edit':
                      Navigator.of(context).pushNamed(
                        AppRoutes.workoutBuilder,
                        arguments: workout,
                      );
                      break;
                    case 'duplicate':
                      await provider.duplicate(workout);
                      break;
                    case 'delete':
                      final bool? ok = await showDialog<bool>(
                        context: context,
                        builder: (BuildContext ctx) => AlertDialog(
                          title: const Text('Eliminare l\'allenamento?'),
                          content: Text(
                              'L\'allenamento "${workout.name}" verra rimosso.'),
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
                      if (ok == true) await provider.remove(workout.id);
                      break;
                  }
                },
                itemBuilder: (BuildContext ctx) => const <PopupMenuEntry<String>>[
                  PopupMenuItem<String>(value: 'edit', child: Text('Modifica')),
                  PopupMenuItem<String>(
                      value: 'duplicate', child: Text('Duplica')),
                  PopupMenuItem<String>(
                      value: 'delete', child: Text('Elimina')),
                ],
              ),
            ],
          ),
          Text(
            '${workout.totalSteps} fasi - stima ${formatDistanceKmWithUnit(workout.estimatedMeters, decimals: 1)} / ${formatDurationShort(workout.estimatedSeconds)}',
            style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 14),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: <Widget>[
              for (final WorkoutBlock block in workout.blocks)
                Chip(
                  visualDensity: VisualDensity.compact,
                  label: Text(
                    block.isRepeated
                        ? '${block.repeat}x ${_blockSummary(block)}'
                        : _blockSummary(block),
                    style: const TextStyle(fontSize: 12),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 52,
            child: FilledButton.icon(
              onPressed: () => Navigator.of(context)
                  .pushNamed(AppRoutes.run, arguments: workout),
              icon: const Icon(Icons.play_arrow),
              label: const Text('AVVIA ALLENAMENTO'),
            ),
          ),
        ],
      ),
    );
  }

  static String _blockSummary(WorkoutBlock block) {
    if (block.steps.isEmpty) return 'vuoto';
    return block.steps.map((WorkoutStep s) => s.goalLabel).join(' + ');
  }
}
