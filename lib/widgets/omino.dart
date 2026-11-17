import 'package:flutter/material.dart';

import '../app/tokens.dart';

/// Le pose dell'omino della guida.
enum OminoPose { corre, indica, pensa, saluta }

/// L'omino di Falcata: un corridore disegnato a tratti, con fascia e scarpe
/// del colore dell'app.
///
/// PERCHE' DISEGNATO E NON UN'IMMAGINE
/// -----------------------------------
/// Perche' cosi' prende i colori del tema da solo (chiaro o scuro), resta
/// nitido a ogni grandezza e non aggiunge file all'app. Le pose sono le
/// stesse del bozzetto della guida, punto per punto, su un quadrato 120x120.
class Omino extends StatelessWidget {
  const Omino({
    super.key,
    this.pose = OminoPose.corre,
    this.size = 120,
    this.bodyColor,
    this.accentColor,
  });

  final OminoPose pose;
  final double size;

  /// Se mancano si usano l'inchiostro e l'accento del tema.
  final Color? bodyColor;
  final Color? accentColor;

  @override
  Widget build(BuildContext context) {
    final AppPalette p = AppPalette.of(context);
    return ExcludeSemantics(
      child: SizedBox.square(
        dimension: size,
        child: CustomPaint(
          painter: OminoPainter(
            pose: pose,
            body: bodyColor ?? p.ink,
            accent: accentColor ?? p.accent,
          ),
        ),
      ),
    );
  }
}

/// Un tratto: una spezzata di spessore fisso.
class _Tratto {
  const _Tratto(this.punti, this.spessore, {this.accento = false, this.opacita = 1});

  final List<Offset> punti;
  final double spessore;
  final bool accento;
  final double opacita;
}

/// Un cerchio pieno (la testa, i pensieri, il dito che indica).
class _Tondo {
  const _Tondo(this.centro, this.raggio, {this.accento = false});

  final Offset centro;
  final double raggio;
  final bool accento;
}

class _Posa {
  const _Posa(this.tratti, this.tondi);

  final List<_Tratto> tratti;
  final List<_Tondo> tondi;
}

const Map<OminoPose, _Posa> _pose = <OminoPose, _Posa>{
  OminoPose.corre: _Posa(
    <_Tratto>[
      _Tratto(<Offset>[Offset(63, 17), Offset(86, 14)], 4, accento: true),
      _Tratto(<Offset>[Offset(70, 34), Offset(58, 66)], 9),
      _Tratto(<Offset>[Offset(68, 40), Offset(84, 50), Offset(95, 40)], 7),
      _Tratto(<Offset>[Offset(66, 41), Offset(50, 46), Offset(40, 58)], 7),
      _Tratto(<Offset>[Offset(58, 66), Offset(76, 78), Offset(71, 99)], 8),
      _Tratto(<Offset>[Offset(58, 66), Offset(44, 84), Offset(27, 81)], 8),
      _Tratto(<Offset>[Offset(70, 100), Offset(82, 101)], 7, accento: true),
      _Tratto(<Offset>[Offset(26, 80), Offset(20, 89)], 7, accento: true),
      _Tratto(<Offset>[Offset(14, 40), Offset(28, 40)], 3, accento: true, opacita: 0.7),
      _Tratto(<Offset>[Offset(8, 52), Offset(24, 52)], 3, accento: true, opacita: 0.7),
      _Tratto(<Offset>[Offset(14, 64), Offset(26, 64)], 3, accento: true, opacita: 0.7),
    ],
    <_Tondo>[_Tondo(Offset(74, 20), 11)],
  ),
  OminoPose.indica: _Posa(
    <_Tratto>[
      _Tratto(<Offset>[Offset(37, 17), Offset(60, 14)], 4, accento: true),
      _Tratto(<Offset>[Offset(48, 33), Offset(48, 70)], 9),
      _Tratto(<Offset>[Offset(49, 42), Offset(76, 36), Offset(100, 26)], 7),
      _Tratto(<Offset>[Offset(47, 43), Offset(36, 58), Offset(38, 72)], 7),
      _Tratto(<Offset>[Offset(48, 70), Offset(40, 100)], 8),
      _Tratto(<Offset>[Offset(48, 70), Offset(58, 100)], 8),
      _Tratto(<Offset>[Offset(33, 101), Offset(42, 101)], 7, accento: true),
      _Tratto(<Offset>[Offset(58, 101), Offset(67, 101)], 7, accento: true),
    ],
    <_Tondo>[
      _Tondo(Offset(48, 20), 11),
      _Tondo(Offset(104, 24), 4, accento: true),
    ],
  ),
  OminoPose.pensa: _Posa(
    <_Tratto>[
      _Tratto(<Offset>[Offset(45, 21), Offset(68, 18)], 4, accento: true),
      _Tratto(<Offset>[Offset(56, 37), Offset(56, 74)], 9),
      _Tratto(<Offset>[Offset(57, 46), Offset(74, 58), Offset(66, 38)], 7),
      _Tratto(<Offset>[Offset(55, 47), Offset(44, 64), Offset(46, 76)], 7),
      _Tratto(<Offset>[Offset(56, 74), Offset(48, 104)], 8),
      _Tratto(<Offset>[Offset(56, 74), Offset(64, 104)], 8),
      _Tratto(<Offset>[Offset(41, 105), Offset(50, 105)], 7, accento: true),
      _Tratto(<Offset>[Offset(64, 105), Offset(73, 105)], 7, accento: true),
    ],
    <_Tondo>[
      _Tondo(Offset(56, 24), 11),
      _Tondo(Offset(80, 14), 3, accento: true),
      _Tondo(Offset(90, 8), 4, accento: true),
      _Tondo(Offset(102, 4), 5, accento: true),
    ],
  ),
  OminoPose.saluta: _Posa(
    <_Tratto>[
      _Tratto(<Offset>[Offset(45, 23), Offset(68, 20)], 4, accento: true),
      _Tratto(<Offset>[Offset(56, 39), Offset(56, 76)], 9),
      _Tratto(<Offset>[Offset(57, 47), Offset(76, 34), Offset(80, 14)], 7),
      _Tratto(<Offset>[Offset(88, 10), Offset(96, 6)], 3, accento: true),
      _Tratto(<Offset>[Offset(90, 20), Offset(99, 20)], 3, accento: true),
      _Tratto(<Offset>[Offset(86, 29), Offset(94, 33)], 3, accento: true),
      _Tratto(<Offset>[Offset(55, 48), Offset(42, 64), Offset(44, 78)], 7),
      _Tratto(<Offset>[Offset(56, 76), Offset(48, 106)], 8),
      _Tratto(<Offset>[Offset(56, 76), Offset(64, 106)], 8),
      _Tratto(<Offset>[Offset(41, 107), Offset(50, 107)], 7, accento: true),
      _Tratto(<Offset>[Offset(64, 107), Offset(73, 107)], 7, accento: true),
    ],
    <_Tondo>[_Tondo(Offset(56, 26), 11)],
  ),
};

class OminoPainter extends CustomPainter {
  const OminoPainter({
    required this.pose,
    required this.body,
    required this.accent,
  });

  final OminoPose pose;
  final Color body;
  final Color accent;

  @override
  void paint(Canvas canvas, Size size) {
    final _Posa posa = _pose[pose]!;
    final double scala = size.shortestSide / 120.0;
    canvas.save();
    canvas.translate(
      (size.width - 120 * scala) / 2,
      (size.height - 120 * scala) / 2,
    );
    canvas.scale(scala);

    for (final _Tratto t in posa.tratti) {
      final Color base = t.accento ? accent : body;
      final Paint paint = Paint()
        ..color = base.withValues(alpha: base.a * t.opacita)
        ..style = PaintingStyle.stroke
        ..strokeWidth = t.spessore
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..isAntiAlias = true;
      final Path path = Path()..moveTo(t.punti.first.dx, t.punti.first.dy);
      for (final Offset o in t.punti.skip(1)) {
        path.lineTo(o.dx, o.dy);
      }
      canvas.drawPath(path, paint);
    }
    for (final _Tondo c in posa.tondi) {
      canvas.drawCircle(
        c.centro,
        c.raggio,
        Paint()
          ..color = c.accento ? accent : body
          ..isAntiAlias = true,
      );
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(OminoPainter old) =>
      old.pose != pose || old.body != body || old.accent != accent;
}
