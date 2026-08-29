import 'package:flutter/material.dart';

import 'app_card.dart';

/// Card con una metrica: etichetta piccola in alto, valore grande sotto.
///
/// Usata sia nella Home (riepiloghi) sia nella schermata corsa (tempo,
/// distanza, passo) dove la leggibilita' e' la priorita' assoluta.
class MetricCard extends StatelessWidget {
  const MetricCard({
    super.key,
    required this.label,
    required this.value,
    this.unit,
    this.secondary,
    this.valueFontSize = 34,
    this.onTap,
    this.emphasized = false,
  });

  final String label;
  final String value;
  final String? unit;
  final String? secondary;
  final double valueFontSize;
  final VoidCallback? onTap;

  /// Se `true` usa i colori primari: serve per la metrica piu' importante.
  final bool emphasized;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final Color background =
        emphasized ? scheme.primaryContainer : scheme.surfaceContainerHighest;
    final Color foreground =
        emphasized ? scheme.onPrimaryContainer : scheme.onSurface;
    final Color muted =
        emphasized ? scheme.onPrimaryContainer : scheme.onSurfaceVariant;

    return AppCard(
      color: background,
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Text(
            label.toUpperCase(),
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.0,
              color: muted,
            ),
          ),
          const SizedBox(height: 6),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text(
                  value,
                  style: TextStyle(
                    fontSize: valueFontSize,
                    fontWeight: FontWeight.w700,
                    height: 1.0,
                    color: foreground,
                    fontFeatures: const <FontFeature>[
                      FontFeature.tabularFigures(),
                    ],
                  ),
                ),
                if (unit != null) ...<Widget>[
                  const SizedBox(width: 4),
                  Text(
                    unit!,
                    style: TextStyle(
                      fontSize: valueFontSize * 0.42,
                      fontWeight: FontWeight.w600,
                      color: muted,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (secondary != null) ...<Widget>[
            const SizedBox(height: 4),
            Text(
              secondary!,
              style: TextStyle(fontSize: 13, color: muted),
            ),
          ],
        ],
      ),
    );
  }
}

/// Riga compatta etichetta / valore, usata nei dettagli.
class MetricRow extends StatelessWidget {
  const MetricRow({super.key, required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Expanded(
            child: Text(
              label,
              style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 15),
            ),
          ),
          const SizedBox(width: 12),
          Text(
            value,
            textAlign: TextAlign.right,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}
