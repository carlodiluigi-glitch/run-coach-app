import 'package:flutter/material.dart';

import '../app/tokens.dart';
import '../models/workout_step.dart';
import '../utils/formatters.dart';

/// Riga che dice se stai tenendo il passo richiesto dalla fase.
///
/// ACCESSIBILITA': lo stato e' scritto a parole e accompagnato da un simbolo
/// ("in ritmo", "troppo lento", "troppo veloce"). Il colore e' solo un
/// rinforzo: chi non distingue i colori legge comunque l'informazione.
class PaceIndicator extends StatelessWidget {
  const PaceIndicator({
    super.key,
    required this.status,
    required this.currentPaceSecPerKm,
    this.target,

    /// Usa la palette scura fissa (schermata di corsa).
    this.dark = true,
  });

  final PaceStatus status;
  final double? currentPaceSecPerKm;
  final PaceTarget? target;
  final bool dark;

  @override
  Widget build(BuildContext context) {
    final AppPalette p = dark ? AppPalette.run : AppPalette.of(context);
    final PaceTarget? paceTarget = target;

    Color color;
    IconData icon;
    String text;
    switch (status) {
      case PaceStatus.onTarget:
        color = p.green;
        icon = Icons.check_rounded;
        text = 'Sei in ritmo';
        break;
      case PaceStatus.tooFast:
        color = p.orange;
        icon = Icons.keyboard_arrow_up_rounded;
        text = 'Stai spingendo troppo';
        break;
      case PaceStatus.tooSlow:
        color = p.orange;
        icon = Icons.keyboard_arrow_down_rounded;
        text = 'Stai rallentando';
        break;
      case PaceStatus.unknown:
        color = p.inkFaint;
        icon = Icons.more_horiz_rounded;
        text = paceTarget == null || paceTarget.isEmpty
            ? 'Nessun passo obiettivo'
            : 'In attesa del passo';
        break;
    }

    return Row(
      children: <Widget>[
        Icon(icon, size: 19, color: color),
        const SizedBox(width: 6),
        Flexible(
          child: Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              letterSpacing: -0.2,
              color: color,
            ),
          ),
        ),
        if (paceTarget != null && paceTarget.isNotEmpty) ...<Widget>[
          const SizedBox(width: 10),
          Text(
            'obiettivo ${paceTarget.label}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppText.caption.copyWith(color: p.inkFaint),
          ),
        ] else ...<Widget>[
          const SizedBox(width: 10),
          Text(
            formatPaceWithUnit(currentPaceSecPerKm),
            style: AppText.caption.copyWith(color: p.inkFaint),
          ),
        ],
      ],
    );
  }
}
