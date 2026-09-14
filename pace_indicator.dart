import 'package:flutter/material.dart';

import '../models/workout_step.dart';
import '../utils/formatters.dart';
import 'app_card.dart';

/// Indicatore del ritmo rispetto al target.
///
/// ACCESSIBILITA': lo stato e' comunicato prima di tutto da un simbolo e da
/// una parola ("↓ troppo lento", "✓ ritmo corretto", "↑ troppo veloce").
/// Il colore e' solo un supporto: chi non distingue i colori legge comunque
/// l'informazione.
class PaceIndicator extends StatelessWidget {
  const PaceIndicator({
    super.key,
    required this.status,
    required this.currentPaceSecPerKm,
    this.target,
  });

  final PaceStatus status;
  final double? currentPaceSecPerKm;
  final PaceTarget? target;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;

    Color background;
    Color foreground;
    switch (status) {
      case PaceStatus.onTarget:
        background = scheme.primaryContainer;
        foreground = scheme.onPrimaryContainer;
        break;
      case PaceStatus.tooFast:
      case PaceStatus.tooSlow:
        background = scheme.tertiaryContainer;
        foreground = scheme.onTertiaryContainer;
        break;
      case PaceStatus.unknown:
        background = scheme.surfaceContainerHighest;
        foreground = scheme.onSurfaceVariant;
        break;
    }

    final PaceTarget? paceTarget = target;

    return AppCard(
      color: background,
      child: Row(
        children: <Widget>[
          Text(
            status.symbol,
            style: TextStyle(
              fontSize: 40,
              height: 1.0,
              fontWeight: FontWeight.w700,
              color: foreground,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text(
                  status.label.toUpperCase(),
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.8,
                    color: foreground,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  paceTarget == null || paceTarget.isEmpty
                      ? 'Nessun target impostato'
                      : 'Target ${paceTarget.label}',
                  style: TextStyle(fontSize: 14, color: foreground),
                ),
                Text(
                  'Attuale ${formatPaceWithUnit(currentPaceSecPerKm)}',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: foreground,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
