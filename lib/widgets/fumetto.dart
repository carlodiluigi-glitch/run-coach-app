import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../app/tokens.dart';
import '../providers/settings_provider.dart';
import 'omino.dart';

/// Un fumetto di spiegazione: compare una volta sola su una schermata, la
/// prima volta che ci si arriva, e indica la cosa di cui parla.
///
/// PERCHE' UNA VOLTA SOLA
/// ----------------------
/// Perche' un consiglio che torna a ogni apertura smette di essere letto
/// alla seconda e comincia a dare fastidio alla terza. Chi lo vuole rivedere
/// lo ritrova in Impostazioni, "Rivedi la guida".
class Fumetto {
  const Fumetto({
    required this.chiave,
    required this.titolo,
    required this.testo,
    this.posa = OminoPose.pensa,
    this.ominoADestra = false,
  });

  /// Il nome con cui si ricorda che e' gia' stato letto. Non va cambiato:
  /// cambiarlo lo fa ricomparire a chi l'aveva gia' chiuso.
  final String chiave;
  final String titolo;
  final String testo;
  final OminoPose posa;
  final bool ominoADestra;
}

/// I fumetti dell'app, tutti in un posto.
class Fumetti {
  Fumetti._();

  static const Fumetto forma = Fumetto(
    chiave: 'forma',
    titolo: 'Questo e\' il tuo indice di forma.',
    testo: 'Lo calcolo dalle gare, dai test e dalle ripetute: le corse lente '
        'non lo abbassano. Da qui vengono i ritmi del tuo piano.',
    posa: OminoPose.pensa,
  );

  static const Fumetto piano = Fumetto(
    chiave: 'piano',
    titolo: 'Vuoi discutere la settimana?',
    testo: 'Da quest\'icona porti le tue ultime corse in una chat con un\'AI. '
        'Ne parlate, e la settimana che ti propone la puoi rimettere qui.',
    posa: OminoPose.indica,
    ominoADestra: true,
  );

  static const Fumetto coach = Fumetto(
    chiave: 'coach',
    titolo: 'Il giro col coach, in due tocchi.',
    testo: 'Il primo copia le tue settimane: incollale in ChatGPT o nell\'AI '
        'che usi e raccontale com\'e\' andata. Alla fine l\'AI ti scrive la '
        'settimana nuova: la incolli col secondo, e io la controllo prima di '
        'metterla nel piano.',
    posa: OminoPose.saluta,
    ominoADestra: true,
  );
}

/// Mostra [fumetto] sopra la schermata, se non e' gia' stato letto.
///
/// [bersaglio] e' la cosa da indicare: viene lasciata accesa e cerchiata,
/// il resto si scurisce. Senza bersaglio si scurisce tutto.
Future<void> mostraFumettoSeNuovo(
  BuildContext context,
  Fumetto fumetto, {
  GlobalKey? bersaglio,
}) async {
  final SettingsProvider settings = context.read<SettingsProvider>();
  if (settings.settings.tipSeen(fumetto.chiave)) return;
  if (_FumettoAperto.si) return;

  Rect? area;
  final BuildContext? ctx = bersaglio?.currentContext;
  final RenderObject? oggetto = ctx?.findRenderObject();
  if (oggetto is RenderBox && oggetto.hasSize && oggetto.attached) {
    area = oggetto.localToGlobal(Offset.zero) & oggetto.size;
  }

  _FumettoAperto.si = true;
  try {
    await showGeneralDialog<void>(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.transparent,
      barrierLabel: fumetto.titolo,
      transitionDuration: const Duration(milliseconds: 220),
      pageBuilder: (BuildContext _, Animation<double> __, Animation<double> ___) =>
          _VistaFumetto(fumetto: fumetto, area: area),
      transitionBuilder: (BuildContext _, Animation<double> a,
              Animation<double> __, Widget child) =>
          FadeTransition(opacity: a, child: child),
    );
  } finally {
    _FumettoAperto.si = false;
  }
  // Letto anche se chiuso col tasto indietro: chi lo chiude l'ha visto.
  await settings.markTipSeen(fumetto.chiave);
}

class _FumettoAperto {
  static bool si = false;
}

/// Mette [fumetto] su una schermata: lo mostra appena la schermata ha finito
/// di entrare, se non e' gia' stato letto.
///
/// [builder] riceve la chiave da mettere sulla cosa da indicare (con un
/// `KeyedSubtree`). Con [attivo] a `false` non mostra niente: serve quando la
/// cosa da indicare non c'e' ancora (per esempio l'indice di forma prima
/// della prima corsa utile).
class FumettoAllApertura extends StatefulWidget {
  const FumettoAllApertura({
    super.key,
    required this.fumetto,
    required this.builder,
    this.attivo = true,
  });

  final Fumetto fumetto;
  final Widget Function(BuildContext context, GlobalKey bersaglio) builder;
  final bool attivo;

  @override
  State<FumettoAllApertura> createState() => _FumettoAllAperturaState();
}

class _FumettoAllAperturaState extends State<FumettoAllApertura> {
  final GlobalKey _bersaglio = GlobalKey();
  bool _provato = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _forse());
  }

  @override
  void didUpdateWidget(FumettoAllApertura old) {
    super.didUpdateWidget(old);
    if (widget.attivo && !old.attivo) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _forse());
    }
  }

  Future<void> _forse() async {
    if (!mounted || _provato || !widget.attivo) return;
    if (context.read<SettingsProvider>().settings.tipSeen(widget.fumetto.chiave)) {
      return;
    }
    _provato = true;

    // Si aspetta che la schermata abbia finito di scorrere dentro:
    // misurata a meta' animazione, la cosa da indicare starebbe altrove.
    final Animation<double>? entrata = ModalRoute.of(context)?.animation;
    if (entrata != null && entrata.status != AnimationStatus.completed) {
      final Completer<void> fatto = Completer<void>();
      void ascolta(AnimationStatus s) {
        if (s == AnimationStatus.completed && !fatto.isCompleted) {
          fatto.complete();
        }
      }

      entrata.addStatusListener(ascolta);
      await fatto.future.timeout(
        const Duration(seconds: 2),
        onTimeout: () {},
      );
      entrata.removeStatusListener(ascolta);
    }
    await Future<void>.delayed(const Duration(milliseconds: 250));
    if (!mounted) return;
    final ModalRoute<dynamic>? rotta = ModalRoute.of(context);
    if (rotta != null && !rotta.isCurrent) {
      // Si e' gia' andati altrove: lo si mostra la prossima volta.
      _provato = false;
      return;
    }
    await mostraFumettoSeNuovo(context, widget.fumetto, bersaglio: _bersaglio);
  }

  @override
  Widget build(BuildContext context) => widget.builder(context, _bersaglio);
}

/// Il fumetto vero e proprio, sempre nei colori della notte: sopra un velo
/// scuro si legge bene sia col tema chiaro che con lo scuro.
class _VistaFumetto extends StatelessWidget {
  const _VistaFumetto({required this.fumetto, required this.area});

  final Fumetto fumetto;
  final Rect? area;

  static const Color _velo = Color(0x9E050608);
  static const Color _carta = Color(0xFFF2F3F5);
  static const Color _testoForte = Color(0xFF0E0F11);
  static const Color _testoMorbido = Color(0xFF33373D);

  @override
  Widget build(BuildContext context) {
    const AppPalette notte = AppPalette.dark;
    final MediaQueryData mq = MediaQuery.of(context);
    final Rect? cerchio = area?.inflate(6);
    final double raggio =
        cerchio == null ? 0 : (cerchio.shortestSide / 2).clamp(0, 18).toDouble();

    // Il fumetto va dalla parte opposta alla cosa indicata.
    final bool inAlto =
        cerchio != null && cerchio.center.dy > mq.size.height * 0.55;

    final Widget omino = SizedBox(
      height: 112,
      child: Align(
        alignment: fumetto.ominoADestra
            ? (inAlto ? Alignment.bottomRight : Alignment.topRight)
            : (inAlto ? Alignment.bottomLeft : Alignment.topLeft),
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: 8,
            vertical: inAlto ? 0 : 8,
          ),
          child: Omino(
            pose: fumetto.posa,
            size: 104,
            bodyColor: notte.ink,
            accentColor: notte.accent,
          ),
        ),
      ),
    );

    final Widget nuvola = Stack(
      clipBehavior: Clip.none,
      children: <Widget>[
        // La punta del fumetto, verso l'omino.
        Positioned(
          left: fumetto.ominoADestra ? null : 34,
          right: fumetto.ominoADestra ? 54 : null,
          top: inAlto ? -10 : null,
          bottom: inAlto ? null : -10,
          child: Transform.rotate(
            angle: 0.785398,
            child: Container(width: 20, height: 20, color: _carta),
          ),
        ),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 14),
          decoration: BoxDecoration(
            color: _carta,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Text(
                fumetto.titolo,
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                  height: 1.3,
                  color: _testoForte,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                fumetto.testo,
                style: const TextStyle(
                  fontSize: 15,
                  height: 1.45,
                  color: _testoMorbido,
                ),
              ),
              const SizedBox(height: 10),
              Align(
                alignment: Alignment.centerRight,
                child: SizedBox(
                  height: 44,
                  child: FilledButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: FilledButton.styleFrom(
                      backgroundColor: _testoForte,
                      foregroundColor: notte.accent,
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      textStyle: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    child: const Text('Capito'),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );

    return Material(
      type: MaterialType.transparency,
      child: Stack(
        children: <Widget>[
          Positioned.fill(
            child: CustomPaint(
              painter: _VeloPainter(
                colore: _velo,
                buco: cerchio == null
                    ? null
                    : RRect.fromRectAndRadius(cerchio, Radius.circular(raggio)),
              ),
            ),
          ),
          if (cerchio != null)
            Positioned.fromRect(
              rect: cerchio,
              child: IgnorePointer(
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(raggio),
                    border: Border.all(color: notte.accent, width: 2),
                  ),
                ),
              ),
            ),
          Positioned(
            left: 16,
            right: 16,
            top: inAlto ? mq.padding.top + 12 : null,
            bottom: inAlto ? null : mq.padding.bottom + 20,
            child: ConstrainedBox(
              constraints: BoxConstraints(maxHeight: mq.size.height * 0.75),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: inAlto
                      ? <Widget>[omino, nuvola]
                      : <Widget>[nuvola, omino],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Il velo scuro con il buco sopra la cosa indicata.
class _VeloPainter extends CustomPainter {
  const _VeloPainter({required this.colore, required this.buco});

  final Color colore;
  final RRect? buco;

  @override
  void paint(Canvas canvas, Size size) {
    final Path velo = Path()..addRect(Offset.zero & size);
    if (buco != null) {
      velo
        ..addRRect(buco!)
        ..fillType = PathFillType.evenOdd;
    }
    canvas.drawPath(velo, Paint()..color = colore);
  }

  @override
  bool shouldRepaint(_VeloPainter old) => old.buco != buco || old.colore != colore;
}
