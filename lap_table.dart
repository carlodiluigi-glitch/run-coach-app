import 'package:flutter/material.dart';

import '../models/lap.dart';
import '../utils/formatters.dart';

/// Tabella dei lap: numero, distanza, tempo, passo.
class LapTable extends StatelessWidget {
  const LapTable({super.key, required this.laps, this.showStepColumn = false});

  final List<Lap> laps;

  /// Mostra anche la fase di allenamento in cui il lap e' stato chiuso.
  final bool showStepColumn;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;

    if (laps.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Text(
          'Nessun lap registrato.',
          style: TextStyle(color: scheme.onSurfaceVariant),
        ),
      );
    }

    final TextStyle headerStyle = TextStyle(
      fontSize: 12,
      fontWeight: FontWeight.w700,
      letterSpacing: 0.8,
      color: scheme.onSurfaceVariant,
    );
    const TextStyle cellStyle = TextStyle(
      fontSize: 15,
      fontFeatures: <FontFeature>[FontFeature.tabularFigures()],
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            children: <Widget>[
              SizedBox(width: 44, child: Text('LAP', style: headerStyle)),
              Expanded(child: Text('DISTANZA', style: headerStyle)),
              Expanded(child: Text('TEMPO', style: headerStyle)),
              Expanded(
                child: Text('PASSO', style: headerStyle, textAlign: TextAlign.right),
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: laps.length,
          separatorBuilder: (BuildContext context, int index) =>
              const Divider(height: 1),
          itemBuilder: (BuildContext context, int index) {
            final Lap lap = laps[index];
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      SizedBox(
                        width: 44,
                        child: Row(
                          children: <Widget>[
                            Text(
                              '${lap.number}',
                              style: cellStyle.copyWith(
                                  fontWeight: FontWeight.w700),
                            ),
                            if (lap.manual)
                              Padding(
                                padding: const EdgeInsets.only(left: 2),
                                child: Icon(
                                  Icons.touch_app_outlined,
                                  size: 14,
                                  color: scheme.onSurfaceVariant,
                                ),
                              ),
                          ],
                        ),
                      ),
                      Expanded(
                        child: Text(
                          formatDistanceAuto(lap.distanceMeters),
                          style: cellStyle,
                        ),
                      ),
                      Expanded(
                        child: Text(
                          formatDuration(Duration(seconds: lap.durationSeconds)),
                          style: cellStyle,
                        ),
                      ),
                      Expanded(
                        child: Text(
                          formatPace(lap.paceSecondsPerKm),
                          style: cellStyle.copyWith(fontWeight: FontWeight.w600),
                          textAlign: TextAlign.right,
                        ),
                      ),
                    ],
                  ),
                  if (showStepColumn && lap.stepLabel != null)
                    Padding(
                      padding: const EdgeInsets.only(left: 44, top: 2),
                      child: Text(
                        lap.stepLabel!,
                        style: TextStyle(
                          fontSize: 12,
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                ],
              ),
            );
          },
        ),
      ],
    );
  }
}
