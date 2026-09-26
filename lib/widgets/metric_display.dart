import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../app/tokens.dart';

/// Metrica senza riquadro: etichetta piccola e numero grande.
///
/// Serve dove il riquadro darebbe fastidio invece che aiutare: sulla
/// schermata di corsa, dove i bordi rubano spazio ai numeri.
class BigMetric extends StatelessWidget {
  const BigMetric({
    super.key,
    required this.label,
    required this.value,
    required this.size,
    this.unit,
    this.color,
    this.labelColor,
    this.footnote,
  });

  final String label;
  final String value;
  final String? unit;

  /// Dimensione del numero in pixel logici.
  final double size;

  final Color? color;
  final Color? labelColor;

  /// Riga sotto il numero (es. "sei in ritmo").
  final Widget? footnote;

  @override
  Widget build(BuildContext context) {
    final AppPalette p = AppPalette.run;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Text(
          label.toUpperCase(),
          style: AppText.label.copyWith(color: labelColor ?? p.inkFaint),
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
                style: AppText.number(size, color: color ?? p.ink),
              ),
              if (unit != null) ...<Widget>[
                const SizedBox(width: 5),
                Text(
                  unit!,
                  style: TextStyle(
                    fontSize: (size * 0.26).clamp(12, 20),
                    fontWeight: FontWeight.w600,
                    color: p.inkFaint,
                  ),
                ),
              ],
            ],
          ),
        ),
        if (footnote != null) ...<Widget>[
          const SizedBox(height: 8),
          footnote!,
        ],
      ],
    );
  }
}

/// Barra di avanzamento sottile e arrotondata.
class ThinProgressBar extends StatelessWidget {
  const ThinProgressBar({
    super.key,
    required this.value,
    required this.color,
    required this.trackColor,
    this.height = 5,
  });

  /// Da 0 a 1. Valori fuori scala vengono riportati dentro.
  final double value;
  final Color color;
  final Color trackColor;
  final double height;

  @override
  Widget build(BuildContext context) {
    final double v = value.isNaN ? 0.0 : value.clamp(0.0, 1.0);
    return ClipRRect(
      borderRadius: BorderRadius.circular(height),
      child: SizedBox(
        height: height,
        child: LinearProgressIndicator(
          value: v,
          minHeight: height,
          backgroundColor: trackColor,
          valueColor: AlwaysStoppedAnimation<Color>(color),
        ),
      ),
    );
  }
}

/// Anello di avanzamento, con il contenuto al centro.
class ProgressRing extends StatelessWidget {
  const ProgressRing({
    super.key,
    required this.value,
    required this.color,
    required this.trackColor,
    this.size = 66,
    this.thickness = 9,
    this.child,
  });

  /// Da 0 a 1.
  final double value;
  final Color color;
  final Color trackColor;
  final double size;
  final double thickness;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    final double v = value.isNaN ? 0.0 : value.clamp(0.0, 1.0);
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _RingPainter(
          value: v,
          color: color,
          trackColor: trackColor,
          thickness: thickness,
        ),
        child: child == null ? null : Center(child: child),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter({
    required this.value,
    required this.color,
    required this.trackColor,
    required this.thickness,
  });

  final double value;
  final Color color;
  final Color trackColor;
  final double thickness;

  @override
  void paint(Canvas canvas, Size size) {
    final Offset center = Offset(size.width / 2, size.height / 2);
    final double radius = (math.min(size.width, size.height) - thickness) / 2;
    if (radius <= 0) return;

    final Paint track = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = thickness
      ..strokeCap = StrokeCap.round
      ..color = trackColor;

    final Paint arc = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = thickness
      ..strokeCap = StrokeCap.round
      ..color = color;

    canvas.drawCircle(center, radius, track);

    if (value > 0) {
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        -math.pi / 2,
        2 * math.pi * value,
        false,
        arc,
      );
    }
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.value != value ||
      old.color != color ||
      old.trackColor != trackColor ||
      old.thickness != thickness;
}

/// Pillola con un pallino colorato davanti al testo.
class StatusPill extends StatelessWidget {
  const StatusPill({
    super.key,
    required this.text,
    required this.dotColor,
    required this.background,
    required this.textColor,
  });

  final String text;
  final Color dotColor;
  final Color background;
  final Color textColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(9, 6, 13, 6),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: dotColor, shape: BoxShape.circle),
          ),
          const SizedBox(width: 8),
          Text(
            text,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              letterSpacing: -0.2,
              color: textColor,
            ),
          ),
        ],
      ),
    );
  }
}
