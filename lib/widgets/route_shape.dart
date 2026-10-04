import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../app/tokens.dart';
import '../models/running_activity.dart';

/// Il disegno del giro che hai fatto.
///
/// PERCHE' NON UNA MAPPA VERA
/// --------------------------
/// Una mappa con le strade ha bisogno di un servizio esterno che fornisca le
/// piastrelle, di una chiave, di una connessione mentre la guardi, e di solito
/// di pagare oltre un certo numero di visualizzazioni. Tre cose che Falcata non
/// ha e una che non vuole.
///
/// E il valore, per chi ha appena finito di correre, sta quasi tutto nella
/// **forma**: riconoscere il proprio giro, vedere dove si e' girato, accorgersi
/// che il GPS ha fatto un salto. Quello lo da' la traccia da sola, senza rete,
/// senza chiavi e senza mandare da nessuna parte il posto in cui abiti.
///
/// COSA MOSTRA
/// -----------
/// La traccia in scala, con partenza (cerchio pieno) e arrivo (cerchio vuoto).
/// Se partenza e arrivo coincidono - il giro chiuso, il caso piu' comune - si
/// vede subito perche' i due cerchi si sovrappongono.
///
/// LA PROIEZIONE
/// -------------
/// I gradi di longitudine valgono meno di quelli di latitudine, e sempre meno
/// man mano che si sale verso i poli: alle nostre latitudini un grado di
/// longitudine e' circa i tre quarti di uno di latitudine. Senza quella
/// correzione un giro quadrato verrebbe disegnato rettangolare, e chi lo guarda
/// non riconoscerebbe il suo percorso. Si corregge moltiplicando per il coseno
/// della latitudine - la proiezione equirettangolare, che su pochi chilometri
/// e' esatta quanto basta.
class RouteShape extends StatelessWidget {
  const RouteShape({
    super.key,
    required this.route,
    this.height = 190,
    this.strokeWidth = 3.0,
    this.color,
    this.showEnds = true,
  });

  final List<RoutePoint> route;
  final double height;
  final double strokeWidth;
  final Color? color;

  /// Partenza e arrivo. Si tolgono quando il disegno e' piccolo (anteprima).
  final bool showEnds;

  /// Sotto questo numero di punti non c'e' una forma da disegnare.
  static const int minimumPoints = 10;

  static bool canDraw(List<RoutePoint> route) => route.length >= minimumPoints;

  @override
  Widget build(BuildContext context) {
    final AppPalette p = AppPalette.of(context);
    return SizedBox(
      height: height,
      width: double.infinity,
      child: CustomPaint(
        painter: _RoutePainter(
          route: route,
          color: color ?? p.accent,
          startColor: p.green,
          endColor: p.ink,
          strokeWidth: strokeWidth,
          showEnds: showEnds,
        ),
      ),
    );
  }
}

class _RoutePainter extends CustomPainter {
  _RoutePainter({
    required this.route,
    required this.color,
    required this.startColor,
    required this.endColor,
    required this.strokeWidth,
    required this.showEnds,
  });

  final List<RoutePoint> route;
  final Color color;
  final Color startColor;
  final Color endColor;
  final double strokeWidth;
  final bool showEnds;

  @override
  void paint(Canvas canvas, Size size) {
    if (route.length < 2 || size.width <= 0 || size.height <= 0) return;

    // --------------------------------------------------- proiezione in piano
    double latMedia = 0;
    for (final RoutePoint p in route) {
      latMedia += p.latitude;
    }
    latMedia /= route.length;
    final double kLon = math.cos(latMedia * math.pi / 180.0).abs();

    final List<Offset> piani = <Offset>[
      for (final RoutePoint p in route)
        Offset(p.longitude * kLon, -p.latitude),
    ];

    // ------------------------------------------------------- scala e centro
    double minX = piani.first.dx;
    double maxX = piani.first.dx;
    double minY = piani.first.dy;
    double maxY = piani.first.dy;
    for (final Offset o in piani) {
      if (o.dx < minX) minX = o.dx;
      if (o.dx > maxX) maxX = o.dx;
      if (o.dy < minY) minY = o.dy;
      if (o.dy > maxY) maxY = o.dy;
    }

    final double bordo = strokeWidth * 2 + 6;
    final double larghezzaUtile = size.width - bordo * 2;
    final double altezzaUtile = size.height - bordo * 2;
    if (larghezzaUtile <= 0 || altezzaUtile <= 0) return;

    final double spanX = maxX - minX;
    final double spanY = maxY - minY;

    // Un percorso quasi rettilineo ha uno dei due lati a zero: si usa solo
    // l'altro, altrimenti la divisione manda la scala all'infinito e non si
    // disegna niente.
    double scala;
    if (spanX <= 0 && spanY <= 0) {
      return; // tutti i punti nello stesso posto: non e' un percorso
    } else if (spanX <= 0) {
      scala = altezzaUtile / spanY;
    } else if (spanY <= 0) {
      scala = larghezzaUtile / spanX;
    } else {
      // La stessa scala sui due assi: un giro non deve uscire schiacciato.
      scala = math.min(larghezzaUtile / spanX, altezzaUtile / spanY);
    }
    if (!scala.isFinite || scala <= 0) return;

    final double offsetX =
        bordo + (larghezzaUtile - spanX * scala) / 2 - minX * scala;
    final double offsetY =
        bordo + (altezzaUtile - spanY * scala) / 2 - minY * scala;

    Offset schermo(Offset piano) => Offset(
          piano.dx * scala + offsetX,
          piano.dy * scala + offsetY,
        );

    // ------------------------------------------------------------ la traccia
    final Path path = Path()..moveTo(
        schermo(piani.first).dx, schermo(piani.first).dy);
    for (int i = 1; i < piani.length; i++) {
      final Offset o = schermo(piani[i]);
      path.lineTo(o.dx, o.dy);
    }

    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..color = color,
    );

    if (!showEnds) return;

    // Partenza piena, arrivo vuoto: su un giro chiuso i due cerchi finiscono
    // uno sopra l'altro, e si vede che e' un anello.
    final Offset partenza = schermo(piani.first);
    final Offset arrivo = schermo(piani.last);
    final double raggio = strokeWidth * 1.9;

    // L'arrivo e' un anello: disegnato come cerchio vuoto con il contorno, non
    // come cerchio pieno trasparente sopra uno pieno - il trasparente non
    // cancella niente, lascia solo quello che c'era sotto.
    canvas.drawCircle(
      arrivo,
      raggio,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth * 0.8
        ..color = endColor.withValues(alpha: 0.9),
    );
    canvas.drawCircle(
      partenza,
      raggio,
      Paint()..color = startColor,
    );
  }

  @override
  bool shouldRepaint(covariant _RoutePainter old) =>
      old.route != route ||
      old.color != color ||
      old.strokeWidth != strokeWidth ||
      old.showEnds != showEnds;
}
