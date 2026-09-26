import 'package:flutter/material.dart';

import '../app/tokens.dart';
import 'app_card.dart';

/// Riquadro con una metrica: etichetta piccola in alto, numero grande sotto.
///
/// Il numero e' l'unica cosa che deve saltare all'occhio, quindi l'etichetta
/// resta piccola e grigia e l'unita' di misura non compete con la cifra.
class MetricCard extends StatelessWidget {
  const MetricCard({
    super.key,
    required this.label,
    required this.value,
    this.unit,
    this.secondary,
    this.valueFontSize = 28,
    this.onTap,
    this.emphasized = false,
    this.valueColor,
  });

  final String label;
  final String value;
  final String? unit;
  final String? secondary;
  final double valueFontSize;
  final VoidCallback? onTap;

  /// Se `true` il numero prende il colore di identita' dell'app.
  ///
  /// L'evidenza si fa colorando il numero, non riempiendo di colore tutto il
  /// riquadro: cosi' si possono mettere piu' riquadri accanto senza che la
  /// schermata diventi un mosaico.
  final bool emphasized;

  /// Colore del numero, se serve forzarlo (es. verde quando sei in ritmo).
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    final AppPalette p = AppPalette.of(context);
    final Color numberColor = valueColor ?? (emphasized ? p.accent : p.ink);

    return AppCard(
      onTap: onTap,
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Text(
            label.toUpperCase(),
            style: AppText.label.copyWith(color: p.inkFaint),
          ),
          const SizedBox(height: 8),
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
                  style: AppText.number(valueFontSize, color: numberColor),
                ),
                if (unit != null) ...<Widget>[
                  const SizedBox(width: 4),
                  Text(
                    unit!,
                    style: TextStyle(
                      fontSize: (valueFontSize * 0.42).clamp(11, 17),
                      fontWeight: FontWeight.w600,
                      color: p.inkFaint,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (secondary != null) ...<Widget>[
            const SizedBox(height: 5),
            Text(
              secondary!,
              style: AppText.caption.copyWith(color: p.inkFaint),
            ),
          ],
        ],
      ),
    );
  }
}

/// Riga etichetta / valore, per i blocchi di informazioni.
class MetricRow extends StatelessWidget {
  const MetricRow({super.key, required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final AppPalette p = AppPalette.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Expanded(
            child: Text(label, style: AppText.row.copyWith(color: p.inkSoft)),
          ),
          const SizedBox(width: 12),
          Text(
            value,
            textAlign: TextAlign.right,
            style: AppText.row.copyWith(
              color: p.ink,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
