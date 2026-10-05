import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../app/tokens.dart';
import '../services/run_profile.dart';
import '../utils/formatters.dart';

/// Il passo e la quota lungo la corsa.
///
/// PERCHE' DUE RIQUADRI E NON DUE LINEE SOVRAPPOSTE
/// ------------------------------------------------
/// Perche' passo e quota si misurano in cose diverse - minuti al chilometro e
/// metri - e mettere due scale verticali sullo stesso disegno e' il modo piu'
/// comune di mentire con un grafico: scegliendo le due scale si puo' far
/// sembrare che le due linee salgano insieme, o che si incrocino, o che una
/// anticipi l'altra. Sono tutte illusioni della scala, non cose vere.
///
/// Due riquadri impilati che condividono solo l'asse orizzontale dicono la
/// stessa cosa senza poterla falsare: la posizione lungo il percorso e'
/// confrontabile perche' e' la stessa, i valori restano ognuno nel suo.
///
/// PERCHE' IL PASSO E' CAPOVOLTO
/// -----------------------------
/// Sul passo il numero piccolo e' il risultato migliore - 4:00 e' piu' veloce
/// di 6:00. Disegnato dritto, il grafico scenderebbe quando si va forte, e
/// l'occhio legge "verso il basso" come "va peggio". L'asse e' rovesciato: in
/// alto si corre forte.
///
/// LE INTERRUZIONI SONO VERE
/// -------------------------
/// Dove il passo non si puo' dire - una sosta, un buco di segnale - la linea
/// si interrompe. Non scende a zero e non viene ricucita: un ponte disegnato
/// sopra un buco e' un dato inventato, e sarebbe pure quello piu' bello da
/// guardare.
class RunProfileChart extends StatefulWidget {
  const RunProfileChart({
    super.key,
    required this.profile,
    this.height = 240,
  });

  final List<ProfileSample> profile;
  final double height;

  @override
  State<RunProfileChart> createState() => _RunProfileChartState();
}

class _RunProfileChartState extends State<RunProfileChart> {
  /// Il punto che si sta toccando. `null` quando non si tocca niente.
  int? _toccato;

  @override
  Widget build(BuildContext context) {
    final AppPalette p = AppPalette.of(context);
    final List<ProfileSample> dati = widget.profile;
    final bool conQuota = RunProfile.hasAltitude(dati);

    final List<double> passi = <double>[
      for (final ProfileSample s in dati)
        if (s.paceSecondsPerKm != null) s.paceSecondsPerKm!,
    ];
    if (passi.isEmpty) return const SizedBox.shrink();

    final double piuVeloce = passi.reduce(math.min);
    final double piuLento = passi.reduce(math.max);
    final double totale = dati.last.meters;

    final ProfileSample? scelto =
        _toccato == null ? null : dati[_toccato!.clamp(0, dati.length - 1)];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        // La riga di lettura: quando non si tocca niente mostra gli estremi,
        // quando si tocca mostra il punto. Occupa sempre la stessa altezza,
        // cosi' il grafico non salta mentre ci si muove sopra con il dito.
        SizedBox(
          height: 20,
          child: Row(
            children: <Widget>[
              Text(
                scelto == null
                    ? 'PASSO'
                    : formatDistance(scelto.meters, decimals: 2) + ' km',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.1,
                  color: p.inkFaint,
                ),
              ),
              const Spacer(),
              Text(
                scelto == null
                    ? '${formatPace(piuVeloce)} - ${formatPace(piuLento)} /km'
                    : scelto.paceSecondsPerKm == null
                        ? 'fermo'
                        : '${formatPace(scelto.paceSecondsPerKm)} /km'
                            '${scelto.altitude == null ? '' : '  ·  ${scelto.altitude!.round()} m'}',
                style: AppText.number(13, color: p.ink),
              ),
            ],
          ),
        ),
        const SizedBox(height: 6),
        SizedBox(
          height: widget.height,
          width: double.infinity,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapDown: (TapDownDetails d) =>
                _aggiorna(d.localPosition.dx, context),
            onHorizontalDragUpdate: (DragUpdateDetails d) =>
                _aggiorna(d.localPosition.dx, context),
            onHorizontalDragEnd: (_) => setState(() => _toccato = null),
            onTapUp: (_) => setState(() => _toccato = null),
            onTapCancel: () => setState(() => _toccato = null),
            child: CustomPaint(
              painter: _ProfilePainter(
                dati: dati,
                conQuota: conQuota,
                piuVeloce: piuVeloce,
                piuLento: piuLento,
                toccato: _toccato,
                linea: p.accent,
                quota: p.inkFaint,
                griglia: p.separator,
                sfondo: p.surface,
              ),
            ),
          ),
        ),
        const SizedBox(height: 4),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: <Widget>[
            Text('0', style: AppText.caption.copyWith(color: p.inkFaint)),
            Text('${formatDistance(totale, decimals: 1)} km',
                style: AppText.caption.copyWith(color: p.inkFaint)),
          ],
        ),
      ],
    );
  }

  void _aggiorna(double dx, BuildContext context) {
    final RenderObject? box = context.findRenderObject();
    if (box is! RenderBox) return;
    final double larghezza = box.size.width;
    if (larghezza <= 0 || widget.profile.length < 2) return;
    final int i = ((dx / larghezza) * (widget.profile.length - 1))
        .round()
        .clamp(0, widget.profile.length - 1);
    if (i != _toccato) setState(() => _toccato = i);
  }
}

class _ProfilePainter extends CustomPainter {
  _ProfilePainter({
    required this.dati,
    required this.conQuota,
    required this.piuVeloce,
    required this.piuLento,
    required this.toccato,
    required this.linea,
    required this.quota,
    required this.griglia,
    required this.sfondo,
  });

  final List<ProfileSample> dati;
  final bool conQuota;
  final double piuVeloce;
  final double piuLento;
  final int? toccato;
  final Color linea;
  final Color quota;
  final Color griglia;
  final Color sfondo;

  /// Quanto dell'altezza va al passo quando c'e' anche la quota.
  static const double quotaPassoConQuota = 0.68;

  /// Lo stacco fra i due riquadri. Due pixel bastano a dire "sono due cose
  /// diverse" senza sprecare spazio.
  static const double stacco = 10;

  @override
  void paint(Canvas canvas, Size size) {
    if (dati.length < 2 || size.width <= 0 || size.height <= 0) return;

    final double altezzaPasso = conQuota
        ? (size.height - stacco) * quotaPassoConQuota
        : size.height;
    final double altezzaQuota =
        conQuota ? size.height - stacco - altezzaPasso : 0;

    double x(int i) => size.width * i / (dati.length - 1);

    // ------------------------------------------------------------- il passo
    //
    // Asse capovolto: il passo piu' veloce sta in alto. Con un margine sopra e
    // sotto, cosi' il minimo e il massimo non finiscono incollati al bordo.
    final double banda = math.max(1.0, piuLento - piuVeloce);
    const double aria = 0.12;
    double yPasso(double passo) {
      final double q = (passo - piuVeloce) / banda; // 0 = veloce, 1 = lento
      return (aria + q * (1 - 2 * aria)) * altezzaPasso;
    }

    // Due righe di riferimento, senza numeri: danno il senso dell'altezza
    // senza trasformare il grafico in una tabella.
    final Paint rigo = Paint()
      ..color = griglia.withValues(alpha: 0.45)
      ..strokeWidth = 1;
    for (final double f in <double>[0.33, 0.66]) {
      final double yy = f * altezzaPasso;
      canvas.drawLine(Offset(0, yy), Offset(size.width, yy), rigo);
    }

    // La linea si interrompe dove il passo non si sa: un ponte sopra un buco
    // sarebbe un dato inventato.
    final Paint tratto = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..color = linea;

    Path? corrente;
    for (int i = 0; i < dati.length; i++) {
      final double? passo = dati[i].paceSecondsPerKm;
      if (passo == null) {
        if (corrente != null) {
          canvas.drawPath(corrente, tratto);
          corrente = null;
        }
        continue;
      }
      final Offset punto = Offset(x(i), yPasso(passo));
      if (corrente == null) {
        corrente = Path()..moveTo(punto.dx, punto.dy);
      } else {
        corrente.lineTo(punto.dx, punto.dy);
      }
    }
    if (corrente != null) canvas.drawPath(corrente, tratto);

    // --------------------------------------------------------- l'altimetria
    if (conQuota) {
      final double base = altezzaPasso + stacco;
      final List<double> quote = <double>[
        for (final ProfileSample s in dati)
          if (s.altitude != null) s.altitude!,
      ];
      if (quote.length >= 2) {
        final double minQ = quote.reduce(math.min);
        final double maxQ = quote.reduce(math.max);
        // Un dislivello piccolo non va stirato per riempire il riquadro:
        // sembrerebbe una montagna. Sotto i venti metri si tiene una scala
        // fissa, e il profilo resta giustamente piatto.
        final double bandaQ = math.max(20.0, maxQ - minQ);
        final double centro = (minQ + maxQ) / 2;
        double yQuota(double q) {
          final double rel = (q - (centro - bandaQ / 2)) / bandaQ;
          return base + altezzaQuota - rel.clamp(0.0, 1.0) * altezzaQuota;
        }

        final Path profilo = Path();
        bool iniziato = false;
        double primoX = 0;
        double ultimoX = 0;
        for (int i = 0; i < dati.length; i++) {
          final double? q = dati[i].altitude;
          if (q == null) continue;
          final double px = x(i);
          if (!iniziato) {
            profilo.moveTo(px, yQuota(q));
            primoX = px;
            iniziato = true;
          } else {
            profilo.lineTo(px, yQuota(q));
          }
          ultimoX = px;
        }
        if (iniziato) {
          final Path pieno = Path.from(profilo)
            ..lineTo(ultimoX, base + altezzaQuota)
            ..lineTo(primoX, base + altezzaQuota)
            ..close();
          canvas.drawPath(
            pieno,
            Paint()..color = quota.withValues(alpha: 0.22),
          );
          canvas.drawPath(
            profilo,
            Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = 1.4
              ..color = quota.withValues(alpha: 0.9),
          );
        }
      }
    }

    // ------------------------------------------------------- il dito sopra
    final int? i = toccato;
    if (i != null && i >= 0 && i < dati.length) {
      final double px = x(i);
      canvas.drawLine(
        Offset(px, 0),
        Offset(px, size.height),
        Paint()
          ..color = linea.withValues(alpha: 0.45)
          ..strokeWidth = 1,
      );
      final double? passo = dati[i].paceSecondsPerKm;
      if (passo != null) {
        final Offset punto = Offset(px, yPasso(passo));
        canvas.drawCircle(punto, 5, Paint()..color = sfondo);
        canvas.drawCircle(punto, 3.5, Paint()..color = linea);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _ProfilePainter old) =>
      old.toccato != toccato ||
      old.dati != dati ||
      old.linea != linea ||
      old.conQuota != conQuota;
}
