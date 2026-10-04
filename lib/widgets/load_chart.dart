import 'package:flutter/material.dart';

import '../app/tokens.dart';
import '../services/training_load_engine.dart';

/// Condizione e fatica negli ultimi mesi, una linea ciascuna.
///
/// PERCHE' UN GRAFICO E NON DUE NUMERI
/// -----------------------------------
/// "Condizione 48, fatica 52" non dice niente da solo. Quello che conta e' la
/// direzione: 48 dopo essere stato a 30 vuol dire che stai costruendo, 48 dopo
/// essere stato a 65 vuol dire che ti stai perdendo - e il numero di oggi e'
/// identico nei due casi.
///
/// E' anche la cosa che le app gratuite non fanno: ti dicono quanti chilometri
/// hai fatto, non se quei chilometri ti stanno allenando o consumando.
///
/// COME SI LEGGE, IN UNA RIGA
/// --------------------------
/// La linea spessa e' la **condizione**: sale piano, scende piano, e' quanto
/// sei allenato. La linea sottile e' la **fatica**: sale subito dopo una seduta
/// dura e scende in pochi giorni. Quando la sottile sta sopra la spessa stai
/// portando piu' carico del tuo solito - va bene per qualche settimana, non per
/// sempre.
class LoadChart extends StatelessWidget {
  const LoadChart({
    super.key,
    required this.points,
    this.height = 160,
  });

  final List<TrainingLoadPoint> points;
  final double height;

  /// Sotto questi giorni non c'e' un andamento da mostrare: ci sarebbero due
  /// linee che partono da zero e salgono, che e' solo il grafico di un'app
  /// appena installata.
  static const int minimumDays = 14;

  static bool canDraw(List<TrainingLoadPoint> points) =>
      points.length >= minimumDays;

  @override
  Widget build(BuildContext context) {
    final AppPalette p = AppPalette.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        SizedBox(
          height: height,
          width: double.infinity,
          child: CustomPaint(
            painter: _LoadPainter(
              points: points,
              fitnessColor: p.accent,
              fatigueColor: p.orange,
              gridColor: p.separator,
            ),
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: <Widget>[
            _Legenda(color: p.accent, label: 'Condizione', spessa: true),
            const SizedBox(width: 16),
            _Legenda(color: p.orange, label: 'Fatica', spessa: false),
            const Spacer(),
            Text(
              '${points.length} giorni',
              style: AppText.caption.copyWith(color: p.inkFaint),
            ),
          ],
        ),
      ],
    );
  }
}

class _Legenda extends StatelessWidget {
  const _Legenda({
    required this.color,
    required this.label,
    required this.spessa,
  });

  final Color color;
  final String label;
  final bool spessa;

  @override
  Widget build(BuildContext context) {
    final AppPalette p = AppPalette.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Container(
          width: 16,
          height: spessa ? 3 : 2,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 6),
        Text(label, style: AppText.caption.copyWith(color: p.inkSoft)),
      ],
    );
  }
}

class _LoadPainter extends CustomPainter {
  _LoadPainter({
    required this.points,
    required this.fitnessColor,
    required this.fatigueColor,
    required this.gridColor,
  });

  final List<TrainingLoadPoint> points;
  final Color fitnessColor;
  final Color fatigueColor;
  final Color gridColor;

  @override
  void paint(Canvas canvas, Size size) {
    if (points.length < 2 || size.width <= 0 || size.height <= 0) return;

    // La scala parte sempre da zero. Un grafico che parte dal minimo fa
    // sembrare enorme una variazione piccola: qui le variazioni piccole sono
    // la norma, e farle sembrare drammatiche sarebbe mentire con il disegno.
    double massimo = 0;
    for (final TrainingLoadPoint p in points) {
      if (p.fitness > massimo) massimo = p.fitness;
      if (p.fatigue > massimo) massimo = p.fatigue;
    }
    if (massimo <= 0) return;
    massimo *= 1.12; // un po' d'aria sopra la linea piu' alta

    const double bordo = 6;
    final double larghezza = size.width - bordo * 2;
    final double altezza = size.height - bordo * 2;
    if (larghezza <= 0 || altezza <= 0) return;

    double x(int i) => bordo + larghezza * i / (points.length - 1);
    double y(double valore) =>
        bordo + altezza - altezza * (valore / massimo).clamp(0.0, 1.0);

    // Due righe di riferimento, senza numeri: servono a dare il senso
    // dell'altezza, non a leggere un valore.
    final Paint griglia = Paint()
      ..color = gridColor.withValues(alpha: 0.5)
      ..strokeWidth = 1;
    for (final double quota in <double>[0.33, 0.66]) {
      final double yy = bordo + altezza - altezza * quota;
      canvas.drawLine(Offset(bordo, yy), Offset(size.width - bordo, yy), griglia);
    }

    Path linea(double Function(TrainingLoadPoint) valore) {
      final Path path = Path()..moveTo(x(0), y(valore(points.first)));
      for (int i = 1; i < points.length; i++) {
        path.lineTo(x(i), y(valore(points[i])));
      }
      return path;
    }

    // La condizione si disegna prima e con un velo sotto: e' la linea che si
    // guarda, la fatica e' il commento.
    final Path condizione = linea((TrainingLoadPoint p) => p.fitness);
    final Path area = Path.from(condizione)
      ..lineTo(x(points.length - 1), bordo + altezza)
      ..lineTo(x(0), bordo + altezza)
      ..close();
    canvas.drawPath(
      area,
      Paint()..color = fitnessColor.withValues(alpha: 0.10),
    );

    canvas.drawPath(
      linea((TrainingLoadPoint p) => p.fatigue),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.6
        ..strokeJoin = StrokeJoin.round
        ..color = fatigueColor,
    );
    canvas.drawPath(
      condizione,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.6
        ..strokeJoin = StrokeJoin.round
        ..color = fitnessColor,
    );

    // Il punto di oggi, cosi' si capisce dove finisce la storia.
    canvas.drawCircle(
      Offset(x(points.length - 1), y(points.last.fitness)),
      3.5,
      Paint()..color = fitnessColor,
    );
  }

  @override
  bool shouldRepaint(covariant _LoadPainter old) =>
      old.points != points ||
      old.fitnessColor != fitnessColor ||
      old.fatigueColor != fatigueColor;
}
