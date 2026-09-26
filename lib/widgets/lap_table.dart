import 'package:flutter/material.dart';

import '../app/tokens.dart';
import '../models/lap.dart';
import '../utils/formatters.dart';

/// Elenco dei parziali.
///
/// COME SI LEGGE
/// -------------
/// Ogni riga ha a sinistra la fase e la distanza, a destra il tempo e il
/// passo. Le fasi di lavoro (ripetute, corsa) sono nel colore dell'app, i
/// recuperi sono grigi: cosi' scorrendo l'occhio salta i recuperi e legge
/// solo i tempi che contano.
///
/// Nella corsa libera, dove non ci sono fasi, al loro posto compare il numero
/// del giro.
class LapTable extends StatelessWidget {
  const LapTable({
    super.key,
    required this.laps,
    this.showStepColumn = false,
    this.dark = false,
  });

  final List<Lap> laps;

  /// Mostra l'etichetta della fase di allenamento sopra ogni riga.
  final bool showStepColumn;

  /// Usa la palette scura fissa (schermata di corsa).
  final bool dark;

  @override
  Widget build(BuildContext context) {
    final AppPalette p = dark ? AppPalette.run : AppPalette.of(context);

    if (laps.isEmpty) {
      return Container(
        decoration: BoxDecoration(
          color: p.surface,
          borderRadius: BorderRadius.circular(AppRadius.card),
        ),
        padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 16),
        child: Text(
          'Nessun parziale registrato.',
          style: AppText.body.copyWith(color: p.inkFaint),
        ),
      );
    }

    final List<Widget> rows = <Widget>[];
    for (int i = 0; i < laps.length; i++) {
      if (i > 0) {
        rows.add(Padding(
          padding: const EdgeInsets.only(left: 16),
          child: Container(height: 0.5, color: p.separator),
        ));
      }
      rows.add(_LapRow(
        lap: laps[i],
        palette: p,
        showStep: showStepColumn,
      ));
    }

    return Container(
      decoration: BoxDecoration(
        color: p.surface,
        borderRadius: BorderRadius.circular(AppRadius.card),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: rows,
      ),
    );
  }
}

class _LapRow extends StatelessWidget {
  const _LapRow({
    required this.lap,
    required this.palette,
    required this.showStep,
  });

  final Lap lap;
  final AppPalette palette;
  final bool showStep;

  /// Il recupero si riconosce dall'etichetta della fase, che e' l'unica cosa
  /// che il lap conserva. E' anche l'etichetta che l'utente vede, quindi se
  /// un giorno cambia il nome della fase cambia insieme in tutti e due i
  /// posti.
  bool get _isRecovery {
    final String? label = lap.stepLabel;
    if (label == null) return false;
    return label.toLowerCase().startsWith('recupero');
  }

  @override
  Widget build(BuildContext context) {
    final AppPalette p = palette;
    final String? step = showStep ? lap.stepLabel : null;

    final bool muted = _isRecovery;
    final Color headingColor = step == null
        ? p.inkFaint
        : (muted ? p.inkFaint : p.accent);
    final Color timeColor = muted ? p.inkSoft : p.ink;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 11, 16, 11),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: <Widget>[
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Flexible(
                      child: Text(
                        (step ?? 'Giro ${lap.number}').toUpperCase(),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppText.label.copyWith(color: headingColor),
                      ),
                    ),
                    if (lap.manual)
                      Padding(
                        padding: const EdgeInsets.only(left: 5),
                        child: Icon(
                          Icons.touch_app_outlined,
                          size: 13,
                          color: p.inkFaint,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  formatDistanceAuto(lap.distanceMeters),
                  style: AppText.row.copyWith(color: p.ink),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Text(
                formatDuration(Duration(seconds: lap.durationSeconds)),
                style: AppText.number(21, color: timeColor),
              ),
              const SizedBox(height: 3),
              Text(
                formatPaceWithUnit(lap.paceSecondsPerKm),
                style: AppText.caption.copyWith(color: p.inkFaint),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
