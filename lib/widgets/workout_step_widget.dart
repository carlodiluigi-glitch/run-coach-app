import 'package:flutter/material.dart';

import '../models/workout.dart';
import '../models/workout_step.dart';
import 'app_card.dart';

/// Icona associata al tipo di fase.
IconData iconForStepType(StepType type) {
  switch (type) {
    case StepType.warmup:
      return Icons.wb_sunny_outlined;
    case StepType.run:
      return Icons.directions_run;
    case StepType.interval:
      return Icons.bolt;
    case StepType.recovery:
      return Icons.self_improvement;
    case StepType.cooldown:
      return Icons.ac_unit;
    case StepType.generic:
      return Icons.circle_outlined;
  }
}

/// Riga che rappresenta un singolo step nell'editor o nel riepilogo.
class WorkoutStepTile extends StatelessWidget {
  const WorkoutStepTile({
    super.key,
    required this.step,
    this.onTap,
    this.onDelete,
    this.onMoveUp,
    this.onMoveDown,
    this.dense = false,
  });

  final WorkoutStep step;
  final VoidCallback? onTap;
  final VoidCallback? onDelete;
  final VoidCallback? onMoveUp;
  final VoidCallback? onMoveDown;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final PaceTarget? target = step.paceTarget;

    return AppCard(
      onTap: onTap,
      color: scheme.surfaceContainerHigh,
      padding: EdgeInsets.symmetric(horizontal: 14, vertical: dense ? 10 : 14),
      child: Row(
        children: <Widget>[
          Icon(iconForStepType(step.type), size: 26, color: scheme.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text(
                  step.type.label,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  step.goalLabel,
                  style: TextStyle(fontSize: 15, color: scheme.onSurfaceVariant),
                ),
                if (target != null && target.isNotEmpty)
                  Text(
                    'Target ${target.label}',
                    style: TextStyle(fontSize: 13, color: scheme.primary),
                  ),
              ],
            ),
          ),
          if (onMoveUp != null)
            IconButton(
              onPressed: onMoveUp,
              icon: const Icon(Icons.keyboard_arrow_up),
              tooltip: 'Sposta su',
            ),
          if (onMoveDown != null)
            IconButton(
              onPressed: onMoveDown,
              icon: const Icon(Icons.keyboard_arrow_down),
              tooltip: 'Sposta giu',
            ),
          if (onDelete != null)
            IconButton(
              onPressed: onDelete,
              icon: const Icon(Icons.delete_outline),
              tooltip: 'Elimina',
            ),
        ],
      ),
    );
  }
}

/// Card che rappresenta un blocco (eventualmente ripetuto) nell'editor.
class WorkoutBlockCard extends StatelessWidget {
  const WorkoutBlockCard({
    super.key,
    required this.block,
    required this.index,
    this.onEditRepeat,
    this.onAddStep,
    this.onDeleteBlock,
    this.onMoveUp,
    this.onMoveDown,
    this.onEditStep,
    this.onDeleteStep,
    this.onMoveStepUp,
    this.onMoveStepDown,
  });

  final WorkoutBlock block;
  final int index;
  final VoidCallback? onEditRepeat;
  final VoidCallback? onAddStep;
  final VoidCallback? onDeleteBlock;
  final VoidCallback? onMoveUp;
  final VoidCallback? onMoveDown;
  final void Function(int stepIndex)? onEditStep;
  final void Function(int stepIndex)? onDeleteStep;
  final void Function(int stepIndex)? onMoveStepUp;
  final void Function(int stepIndex)? onMoveStepDown;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;

    return AppCard(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            children: <Widget>[
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: block.isRepeated
                      ? scheme.primary
                      : scheme.surfaceContainerHigh,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  block.isRepeated ? '${block.repeat} ×' : 'Blocco ${index + 1}',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                    color: block.isRepeated
                        ? scheme.onPrimary
                        : scheme.onSurfaceVariant,
                  ),
                ),
              ),
              const Spacer(),
              if (onEditRepeat != null)
                IconButton(
                  onPressed: onEditRepeat,
                  icon: const Icon(Icons.repeat),
                  tooltip: 'Ripetizioni',
                ),
              if (onMoveUp != null)
                IconButton(
                  onPressed: onMoveUp,
                  icon: const Icon(Icons.keyboard_arrow_up),
                  tooltip: 'Sposta su',
                ),
              if (onMoveDown != null)
                IconButton(
                  onPressed: onMoveDown,
                  icon: const Icon(Icons.keyboard_arrow_down),
                  tooltip: 'Sposta giu',
                ),
              if (onDeleteBlock != null)
                IconButton(
                  onPressed: onDeleteBlock,
                  icon: const Icon(Icons.delete_outline),
                  tooltip: 'Elimina blocco',
                ),
            ],
          ),
          const SizedBox(height: 8),
          if (block.steps.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Text(
                'Nessuna fase in questo blocco.',
                style: TextStyle(color: scheme.onSurfaceVariant),
              ),
            )
          else
            for (int i = 0; i < block.steps.length; i++)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: WorkoutStepTile(
                  step: block.steps[i],
                  dense: true,
                  onTap: onEditStep == null ? null : () => onEditStep!(i),
                  onDelete: onDeleteStep == null ? null : () => onDeleteStep!(i),
                  onMoveUp: (onMoveStepUp == null || i == 0)
                      ? null
                      : () => onMoveStepUp!(i),
                  onMoveDown:
                      (onMoveStepDown == null || i == block.steps.length - 1)
                          ? null
                          : () => onMoveStepDown!(i),
                ),
              ),
          if (onAddStep != null)
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: onAddStep,
                icon: const Icon(Icons.add),
                label: const Text('Aggiungi fase'),
              ),
            ),
        ],
      ),
    );
  }
}
