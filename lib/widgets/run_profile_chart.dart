import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../app/tokens.dart';
import '../services/run_profile.dart';
import '../utils/formatters.dart';

/// Il passo, la cadenza e la quota lungo la corsa.
///
/// PERCHE' RIQUADRI IMPILATI E NON LINEE SOVRAPPOSTE
/// -------------------------------------------------
/// Perche' passo, cadenza e quota si misurano in cose diverse - minuti al
/// chilometro, passi al minuto, metri - e mettere piu' scale verticali sullo
/// stesso disegno e' il modo piu' comune di mentire con un grafico: scegliendo
/// le scale si puo' far sembrare che due linee salgano insieme, o che si
/// incrocino, o che una anticipi l'altra. Sono tutte illusioni della scala, non
/// cose vere.
///
/// Riquadri impilati che condividono solo l'asse orizzontale dicono la stessa
/// cosa senza poterla falsare: la posizione lungo il percorso e' confrontabile
/// perche' e' la stessa, i valori restano ognuno nel suo.
///
/// PERCHE' IL PASSO E' CAPOVOLTO
/// -----------------------------
/// Sul passo il numero piccolo e' il risultato migliore - 4:00 e' piu' veloce
/// di 6:00. Disegnato dritto, il grafico scenderebbe quando si va forte, e
/// l'occhio legge "verso il basso" come "va peggio". L'asse e' rovesciato: in
/// alto si corre forte.
///
/// La cadenza NON e' capovolta: sulla cadenza il numero grande e' piu' alto e
/// basta, come la quota.
///
/// LE INTERRUZIONI SONO VERE
/// -------------------------
/// Dove il dato non si puo' dire - una sosta, un buco di segnale, il sensore
/// dei passi che non ha risposto - la linea si interrompe. Non scende a zero e
/// non viene ricucita: un ponte disegnato sopra un buco e' un dato inventato, e
/// sarebbe pure quello piu' bello da guardare.
class RunProfileChart extends StatefulWidget {
  const RunProfileChart({
    super.key,
    required this.profile,
    this.height = 240,
  });

  final List<ProfileSample> profile;

  /// L'altezza del disegno con due riquadri. Con tre - passo, cadenza e quota -
  /// il widget se ne prende un po' di piu' da solo: schiacciare il passo per
  /// far stare la cadenza vorrebbe dire rovinare il grafico principale per
  /// aggiungerne uno secondario.
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
    final bool conCadenza = RunProfile.hasCadence(dati);

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

    final double altezza =
        widget.height + (conQuota && conCadenza ? 54 : 0);

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
                    ? (RunProfile.mostlyFromSpeed(dati)
                        ? 'PASSO'
                        : 'PASSO · DALLE POSIZIONI')
                    : '${formatDistance(scelto.meters, decimals: 2)} km',
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
                    : _letturaPunto(scelto),
                style: AppText.number(13, color: p.ink),
              ),
            ],
          ),
        ),
        const SizedBox(height: 6),
        SizedBox(
          height: altezza,
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
                conCadenza: conCadenza,
                piuVeloce: piuVeloce,
                piuLento: piuLento,
                toccato: _toccato,
                linea: p.accent,
                cadenza: p.blue,
                quota: p.inkFaint,
                griglia: p.separator,
                sfondo: p.surface,
                etichetta: p.inkFaint,
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

  /// Cosa si legge quando il dito sta su un punto.
  String _letturaPunto(ProfileSample s) {
    if (s.paceSecondsPerKm == null) return 'fermo';
    final StringBuffer b = StringBuffer('${formatPace(s.paceSecondsPerKm)} /km');
    final double? cad = s.cadenceStepsPerMinute;
    if (cad != null) b.write('  ·  ${cad.round()} ppm');
    final double? quota = s.altitude;
    if (quota != null) b.write('  ·  ${quota.round()} m');
    return b.toString();
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
    required this.conCadenza,
    required this.piuVeloce,
    required this.piuLento,
    required this.toccato,
    required this.linea,
    required this.cadenza,
    required this.quota,
    required this.griglia,
    required this.sfondo,
    required this.etichetta,
  });

  final List<ProfileSample> dati;
  final bool conQuota;
  final bool conCadenza;
  final double piuVeloce;
  final double piuLento;
  final int? toccato;
  final Color linea;
  final Color cadenza;
  final Color quota;
  final Color griglia;
  final Color sfondo;
  final Color etichetta;

  /// Lo stacco fra due riquadri. Dieci pixel bastano a dire "sono due cose
  /// diverse" senza sprecare spazio.
  static const double stacco = 10;

  /// La banda minima della cadenza, in passi al minuto.
  ///
  /// PERCHE' UN MINIMO
  /// -----------------
  /// Perche' una cadenza che sta fra 166 e 171 per un'ora e' una cadenza
  /// ottima e costante, e stirata per riempire il riquadro sembrerebbe un
  /// disastro di irregolarita'. Venticinque passi al minuto e' lo scarto oltre
  /// il quale un cambio di cadenza significa davvero qualcosa: sotto, il
  /// profilo resta giustamente piatto.
  static const double bandaMinimaCadenza = 25.0;

  /// La banda minima della quota, in metri. Stesso motivo: un dislivello di
  /// cinque metri non va disegnato come una montagna.
  static const double bandaMinimaQuota = 20.0;

  @override
  void paint(Canvas canvas, Size size) {
    if (dati.length < 2 || size.width <= 0 || size.height <= 0) return;

    // ------------------------------------------- come si divide l'altezza
    //
    // Il passo si prende la parte grossa: e' il grafico, gli altri due lo
    // spiegano. Quanto esattamente dipende da quanti riquadri ci sono, e il
    // conto sta qui in un posto solo invece che sparso nel disegno.
    final int quanti = 1 + (conCadenza ? 1 : 0) + (conQuota ? 1 : 0);
    final double disponibile = size.height - stacco * (quanti - 1);
    if (disponibile <= 0) return;

    final double pesoPasso = quanti == 1
        ? 1.0
        : quanti == 2
            ? 0.68
            : 0.54;
    final double altezzaPasso = disponibile * pesoPasso;
    final double altezzaAltri =
        quanti == 1 ? 0 : (disponibile - altezzaPasso) / (quanti - 1);

    double cima = 0;
    final double cimaPasso = cima;
    cima += altezzaPasso + stacco;
    final double cimaCadenza = conCadenza ? cima : -1;
    if (conCadenza) cima += altezzaAltri + stacco;
    final double cimaQuota = conQuota ? cima : -1;

    double x(int i) => size.width * i / (dati.length - 1);

    // ------------------------------------------------------------- il passo
    //
    // Asse capovolto: il passo piu' veloce sta in alto. Con un margine sopra e
    // sotto, cosi' il minimo e il massimo non finiscono incollati al bordo.
    final double banda = math.max(1.0, piuLento - piuVeloce);
    const double aria = 0.12;
    double yPasso(double passo) {
      final double q = (passo - piuVeloce) / banda; // 0 = veloce, 1 = lento
      return cimaPasso + (aria + q * (1 - 2 * aria)) * altezzaPasso;
    }

    // Due righe di riferimento, senza numeri: danno il senso dell'altezza
    // senza trasformare il grafico in una tabella.
    final Paint rigo = Paint()
      ..color = griglia.withValues(alpha: 0.45)
      ..strokeWidth = 1;
    for (final double f in <double>[0.33, 0.66]) {
      final double yy = cimaPasso + f * altezzaPasso;
      canvas.drawLine(Offset(0, yy), Offset(size.width, yy), rigo);
    }

    _disegnaLinea(
      canvas: canvas,
      x: x,
      valore: (ProfileSample s) => s.paceSecondsPerKm,
      y: yPasso,
      colore: linea,
      spessore: 2,
    );

    // ----------------------------------------------------------- la cadenza
    if (conCadenza) {
      final List<double> valori = <double>[
        for (final ProfileSample s in dati)
          if (s.cadenceStepsPerMinute != null) s.cadenceStepsPerMinute!,
      ];
      if (valori.length >= 2) {
        final double minC = valori.reduce(math.min);
        final double maxC = valori.reduce(math.max);
        final double bandaC = math.max(bandaMinimaCadenza, maxC - minC);
        final double centroC = (minC + maxC) / 2;
        double yCad(double v) {
          final double rel = ((v - (centroC - bandaC / 2)) / bandaC)
              .clamp(0.0, 1.0);
          return cimaCadenza + altezzaAltri - rel * altezzaAltri;
        }

        _disegnaLinea(
          canvas: canvas,
          x: x,
          valore: (ProfileSample s) => s.cadenceStepsPerMinute,
          y: yCad,
          colore: cadenza,
          spessore: 1.6,
        );
        _scritta(canvas, 'CADENZA', 0, cimaCadenza - 1);
      }
    }

    // --------------------------------------------------------- l'altimetria
    if (conQuota) {
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
        final double bandaQ = math.max(bandaMinimaQuota, maxQ - minQ);
        final double centro = (minQ + maxQ) / 2;
        double yQuota(double q) {
          final double rel =
              ((q - (centro - bandaQ / 2)) / bandaQ).clamp(0.0, 1.0);
          return cimaQuota + altezzaAltri - rel * altezzaAltri;
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
            ..lineTo(ultimoX, cimaQuota + altezzaAltri)
            ..lineTo(primoX, cimaQuota + altezzaAltri)
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
          _scritta(canvas, 'QUOTA', 0, cimaQuota - 1);
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

  /// Una spezzata che si interrompe dove il valore non si sa.
  ///
  /// PERCHE' UNA FUNZIONE SOLA PER TUTTE LE LINEE
  /// -------------------------------------------
  /// Perche' "la linea si interrompe sui buchi" e' una regola del grafico, non
  /// un dettaglio di una linea: scritta tre volte, prima o poi una delle tre
  /// ricuce il buco - e sarebbe il disegno piu' bello e il dato piu' falso.
  void _disegnaLinea({
    required Canvas canvas,
    required double Function(int) x,
    required double? Function(ProfileSample) valore,
    required double Function(double) y,
    required Color colore,
    required double spessore,
  }) {
    final Paint tratto = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = spessore
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..color = colore;

    Path? corrente;
    for (int i = 0; i < dati.length; i++) {
      final double? v = valore(dati[i]);
      if (v == null) {
        if (corrente != null) {
          canvas.drawPath(corrente, tratto);
          corrente = null;
        }
        continue;
      }
      final Offset punto = Offset(x(i), y(v));
      if (corrente == null) {
        corrente = Path()..moveTo(punto.dx, punto.dy);
      } else {
        corrente.lineTo(punto.dx, punto.dy);
      }
    }
    if (corrente != null) canvas.drawPath(corrente, tratto);
  }

  /// L'etichetta di un riquadro.
  ///
  /// Serve perche' con tre riquadri impilati non si capisce da solo quale sia
  /// quale: una linea che sale puo' essere la cadenza o la salita, e sono due
  /// letture opposte della stessa corsa.
  void _scritta(Canvas canvas, String testo, double x, double y) {
    final TextPainter tp = TextPainter(
      text: TextSpan(
        text: testo,
        style: TextStyle(
          fontSize: 8,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.9,
          color: etichetta.withValues(alpha: 0.75),
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, Offset(x, y - tp.height));
  }

  @override
  bool shouldRepaint(covariant _ProfilePainter old) =>
      old.toccato != toccato ||
      old.dati != dati ||
      old.linea != linea ||
      old.conQuota != conQuota ||
      old.conCadenza != conCadenza;
}
