import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../app/routes.dart';
import '../app/tokens.dart';
import '../models/athlete_profile.dart';
import '../models/user_settings.dart';
import '../providers/activity_provider.dart';
import '../providers/settings_provider.dart';
import '../utils/tempo_digitato.dart';
import '../widgets/omino.dart';

/// La guida del primo avvio: cinque vignette con l'omino.
///
/// Prende il posto del vecchio benvenuto (nome e unita'), che ora e'
/// l'ultima vignetta insieme a peso e a un tempo recente.
///
/// COSA DICE E COSA NO
/// -------------------
/// Quattro cose sole: come si registra una corsa, cosa vogliono dire le due
/// linee di forma e fatica, come nasce il piano, e chi sei. Il resto lo
/// spiegano i fumetti sulle schermate, quando ci si arriva: una guida che
/// spiega tutto subito non la legge nessuno.
///
/// Si salta in ogni momento. Chi salta tiene quello che aveva (nome e unita'
/// di prima, se aggiorna da una versione vecchia).
class GuideScreen extends StatefulWidget {
  const GuideScreen({super.key, this.fromSettings = false});

  /// `true` se aperta da "Rivedi la guida": alla fine si torna indietro
  /// invece di andare alla Home.
  final bool fromSettings;

  @override
  State<GuideScreen> createState() => _GuideScreenState();
}

/// Le distanze proposte per il tempo recente.
class _Distanza {
  const _Distanza(this.etichetta, this.metri);
  final String etichetta;
  final double metri;
}

const List<_Distanza> _distanze = <_Distanza>[
  _Distanza('5 km', 5000),
  _Distanza('10 km', 10000),
  _Distanza('21 km', 21097.5),
];

class _GuideScreenState extends State<GuideScreen> {
  static const int _pagine = 5;

  final PageController _controller = PageController();
  final TextEditingController _nome = TextEditingController();
  final TextEditingController _peso = TextEditingController();
  final TextEditingController _tempo = TextEditingController();

  int _pagina = 0;
  int _distanza = 1;
  bool _eraGara = false;
  UnitSystem _units = UnitSystem.metric;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    // Chi aggiorna da una versione vecchia ritrova quello che aveva gia'
    // scritto: la guida non gli fa ripetere niente.
    final UserSettings s = context.read<SettingsProvider>().settings;
    _nome.text = s.userName;
    _units = s.units;
    final double? peso =
        context.read<ActivityProvider>().athleteProfile.weightKg;
    if (peso != null) {
      _peso.text = peso == peso.roundToDouble()
          ? peso.toStringAsFixed(0)
          : peso.toStringAsFixed(1).replaceAll('.', ',');
    }
    for (final TextEditingController c in <TextEditingController>[
      _nome,
      _peso,
      _tempo,
    ]) {
      c.addListener(() => setState(() {}));
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _nome.dispose();
    _peso.dispose();
    _tempo.dispose();
    super.dispose();
  }

  bool get _ultima => _pagina == _pagine - 1;

  /// Il problema del peso scritto, o `null` (anche se vuoto: e' facoltativo).
  String? get _problemaPeso {
    if (_peso.text.trim().isEmpty) return null;
    return chiliDaTesto(_peso.text) == null
        ? 'Scrivi i chili, per esempio 72 o 72,5.'
        : null;
  }

  /// Il problema del tempo scritto, o `null` (anche se vuoto).
  String? get _problemaTempo {
    if (_tempo.text.trim().isEmpty) return null;
    return problemaTempo(
      _distanze[_distanza].metri,
      secondiDaTesto(_tempo.text),
    );
  }

  void _avanti() {
    FocusScope.of(context).unfocus();
    _controller.nextPage(
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeOutCubic,
    );
  }

  void _indietro() {
    FocusScope.of(context).unfocus();
    _controller.previousPage(
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeOutCubic,
    );
  }

  /// Chiude la guida. Con [salva] tiene anche quello scritto nell'ultima
  /// vignetta; senza ("Salta", "Lo faccio dopo") tiene solo quello che
  /// c'era gia'.
  Future<void> _fine({required bool salva}) async {
    if (_saving) return;
    setState(() => _saving = true);

    final SettingsProvider settings = context.read<SettingsProvider>();
    final ActivityProvider activities = context.read<ActivityProvider>();

    if (salva) {
      final AthleteProfile prima = activities.athleteProfile;
      AthleteProfile dopo = prima;

      final double? peso = chiliDaTesto(_peso.text);
      if (peso != null && peso != prima.weightKg) {
        dopo = dopo.copyWith(weightKg: peso);
      }

      final _Distanza d = _distanze[_distanza];
      final int? secondi = secondiDaTesto(_tempo.text);
      if (_tempo.text.trim().isNotEmpty &&
          problemaTempo(d.metri, secondi) == null) {
        final DateTime adesso = DateTime.now();
        dopo = dopo.copyWith(personalBests: <PersonalBest>[
          ...dopo.personalBests,
          PersonalBest(
            meters: d.metri,
            seconds: secondi!,
            date: DateTime(adesso.year, adesso.month, adesso.day),
            wasRace: _eraGara,
          ),
        ]);
      }

      if (!identical(dopo, prima)) {
        await activities.updateAthleteProfile(dopo);
      }
    }

    await settings.completeGuide(
      name: salva ? _nome.text : settings.settings.userName,
      units: salva ? _units : settings.settings.units,
    );

    if (!mounted) return;
    if (widget.fromSettings) {
      Navigator.of(context).pop();
    } else {
      Navigator.of(context).pushReplacementNamed(AppRoutes.home);
    }
  }

  @override
  Widget build(BuildContext context) {
    final AppPalette p = AppPalette.of(context);
    final bool datiValidi = _problemaPeso == null && _problemaTempo == null;

    return PopScope(
      canPop: _pagina == 0,
      onPopInvokedWithResult: (bool didPop, Object? _) {
        if (!didPop) _indietro();
      },
      child: Scaffold(
        backgroundColor: p.background,
        body: SafeArea(
          child: Column(
            children: <Widget>[
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 12, 0),
                child: SizedBox(
                  height: 48,
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: _saving ? null : () => _fine(salva: false),
                      child: Text(
                        'Salta',
                        style: AppText.row.copyWith(
                          fontSize: 15,
                          color: p.inkFaint,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              Expanded(
                child: PageView(
                  controller: _controller,
                  onPageChanged: (int i) => setState(() => _pagina = i),
                  children: <Widget>[
                    _PaginaBenvenuto(p: p),
                    _PaginaCorsa(p: p),
                    _PaginaForma(p: p),
                    _PaginaPiano(p: p),
                    _paginaProfilo(p),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 12, 24, 16),
                child: Column(
                  children: <Widget>[
                    _Puntini(pagina: _pagina, totale: _pagine, p: p),
                    const SizedBox(height: 18),
                    SizedBox(
                      width: double.infinity,
                      height: 54,
                      child: FilledButton(
                        onPressed: _saving || (_ultima && !datiValidi)
                            ? null
                            : () {
                                if (_ultima) {
                                  _fine(salva: true);
                                } else {
                                  _avanti();
                                }
                              },
                        style: FilledButton.styleFrom(
                          backgroundColor: p.accent,
                          foregroundColor: p.onAccent,
                          disabledBackgroundColor: p.separator,
                          disabledForegroundColor: p.inkFaint,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          textStyle: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        child: Text(
                          _pagina == 0
                              ? 'Cominciamo'
                              : (_ultima ? 'Fatto, andiamo' : 'Avanti'),
                        ),
                      ),
                    ),
                    // Lo spazio c'e' sempre, cosi' il pulsante non salta su
                    // e giu' arrivando all'ultima vignetta.
                    SizedBox(
                      height: 44,
                      child: _ultima
                          ? TextButton(
                              onPressed:
                                  _saving ? null : () => _fine(salva: false),
                              child: Text(
                                'Lo faccio dopo',
                                style: TextStyle(color: p.inkFaint),
                              ),
                            )
                          : null,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _paginaProfilo(AppPalette p) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: <Widget>[
              const Omino(pose: OminoPose.indica, size: 92),
              const SizedBox(width: 8),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text('Dimmi di te', style: _titolo(p).copyWith(fontSize: 28)),
                      const SizedBox(height: 6),
                      Text(
                        'Tutto facoltativo, e resta sul telefono.',
                        style: AppText.caption
                            .copyWith(fontSize: 14, color: p.inkSoft),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 22),

          _Etichetta('Come ti chiami', p: p),
          _Campo(
            controller: _nome,
            hint: 'Il tuo nome',
            p: p,
            capitalization: TextCapitalization.words,
          ),
          _Nota('La voce ti chiama per nome alla partenza.', p: p),
          const SizedBox(height: 16),

          _Etichetta('Peso', p: p),
          _Campo(
            controller: _peso,
            hint: 'kg',
            p: p,
            keyboard: const TextInputType.numberWithOptions(decimal: true),
          ),
          _Nota(_problemaPeso ?? 'Serve solo alle calorie.',
              p: p, errore: _problemaPeso != null),
          const SizedBox(height: 16),

          _Etichetta('Un tuo tempo recente', p: p),
          Row(
            children: <Widget>[
              for (int i = 0; i < _distanze.length; i++) ...<Widget>[
                _Scelta(
                  testo: _distanze[i].etichetta,
                  scelta: _distanza == i,
                  p: p,
                  onTap: () => setState(() => _distanza = i),
                ),
                const SizedBox(width: 6),
              ],
              const SizedBox(width: 2),
              Expanded(
                child: _Campo(
                  controller: _tempo,
                  hint: _distanza == 2 ? 'h:mm:ss' : 'mm:ss',
                  p: p,
                  numero: true,
                  keyboard: TextInputType.datetime,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: <Widget>[
              _Scelta(
                testo: 'In allenamento',
                scelta: !_eraGara,
                p: p,
                piccola: true,
                onTap: () => setState(() => _eraGara = false),
              ),
              const SizedBox(width: 6),
              _Scelta(
                testo: 'In gara',
                scelta: _eraGara,
                p: p,
                piccola: true,
                onTap: () => setState(() => _eraGara = true),
              ),
            ],
          ),
          _Nota(
            _problemaTempo ??
                'Da qui calcolo subito i tuoi ritmi. Se non lo sai, li '
                    'scopro dalle prime corse.',
            p: p,
            errore: _problemaTempo != null,
          ),
          const SizedBox(height: 16),

          _Etichetta('Misuri in', p: p),
          Row(
            children: <Widget>[
              _Scelta(
                testo: 'Chilometri',
                scelta: _units == UnitSystem.metric,
                p: p,
                onTap: () => setState(() => _units = UnitSystem.metric),
              ),
              const SizedBox(width: 6),
              _Scelta(
                testo: 'Miglia',
                scelta: _units == UnitSystem.imperial,
                p: p,
                onTap: () => setState(() => _units = UnitSystem.imperial),
              ),
            ],
          ),
          _Nota('Si cambia quando vuoi dalle impostazioni.', p: p),
        ],
      ),
    );
  }
}

TextStyle _titolo(AppPalette p) => TextStyle(
      fontSize: 30,
      fontWeight: FontWeight.w600,
      letterSpacing: -0.6,
      height: 1.15,
      color: p.ink,
    );

/// L'impaginazione comune alle prime quattro vignette: disegno in alto,
/// titolo e testo sotto, tutto centrato. Scorre se lo schermo e' basso.
class _Vignetta extends StatelessWidget {
  const _Vignetta({
    required this.disegno,
    required this.titolo,
    required this.testo,
    required this.p,
    this.extra,
  });

  final Widget disegno;
  final String titolo;
  final String testo;
  final Widget? extra;
  final AppPalette p;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints c) {
        return SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: c.maxHeight),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                disegno,
                const SizedBox(height: 24),
                Text(titolo, textAlign: TextAlign.center, style: _titolo(p)),
                const SizedBox(height: 12),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 330),
                  child: Text(
                    testo,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 16,
                      height: 1.5,
                      color: p.inkSoft,
                    ),
                  ),
                ),
                if (extra != null) ...<Widget>[
                  const SizedBox(height: 18),
                  extra!,
                ],
                const SizedBox(height: 8),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _PaginaBenvenuto extends StatelessWidget {
  const _PaginaBenvenuto({required this.p});
  final AppPalette p;

  @override
  Widget build(BuildContext context) {
    return _Vignetta(
      p: p,
      disegno: const Omino(pose: OminoPose.saluta, size: 190),
      titolo: 'Ciao, benvenuto in Falcata',
      testo: 'Sono qui per farti vedere come funziona. Quattro cose, un '
          'minuto. Puoi saltare quando vuoi.',
    );
  }
}

class _PaginaCorsa extends StatelessWidget {
  const _PaginaCorsa({required this.p});
  final AppPalette p;

  @override
  Widget build(BuildContext context) {
    return _Vignetta(
      p: p,
      disegno: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          const Omino(pose: OminoPose.indica, size: 150),
          const SizedBox(width: 4),
          Container(
            width: 104,
            height: 104,
            alignment: Alignment.center,
            decoration: BoxDecoration(color: p.accent, shape: BoxShape.circle),
            child: Text(
              'VIA',
              style: AppText.number(32, color: p.onAccent)
                  .copyWith(letterSpacing: 1),
            ),
          ),
        ],
      ),
      titolo: 'Premi Via e corri',
      testo: 'Basta il telefono in tasca. Distanza, passo e giri li registro '
          'io, e a ogni chilometro la voce ti dice come stai andando.',
      extra: Container(
        constraints: const BoxConstraints(maxWidth: 330),
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        decoration: BoxDecoration(
          color: p.surface,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Icon(Icons.battery_alert_outlined, size: 20, color: p.accent),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Se il telefono risparmia batteria puo\' fermare il GPS a '
                'meta\' corsa. In Impostazioni, alla voce "Corse che si '
                'interrompono", ti dico come evitarlo.',
                style: AppText.caption.copyWith(color: p.inkSoft),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PaginaForma extends StatelessWidget {
  const _PaginaForma({required this.p});
  final AppPalette p;

  @override
  Widget build(BuildContext context) {
    return _Vignetta(
      p: p,
      disegno: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 330),
        child: SizedBox(
        width: double.infinity,
        height: 214,
        child: Stack(
          clipBehavior: Clip.none,
          children: <Widget>[
            Positioned(
              left: 0,
              right: 0,
              top: 34,
              bottom: 0,
              child: Container(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
                decoration: BoxDecoration(
                  color: p.surface,
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Expanded(
                      child: CustomPaint(
                        size: Size.infinite,
                        painter: _FormaFaticaPainter(
                          condizione: p.accent,
                          fatica: p.orange,
                          griglia: p.separator,
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: <Widget>[
                        _Legenda('Condizione', p.accent, 5, p),
                        const SizedBox(width: 18),
                        _Legenda('Fatica', p.orange, 2, p),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const Positioned(
              right: -8,
              top: -36,
              child: Omino(pose: OminoPose.pensa, size: 104),
            ),
          ],
        ),
        ),
      ),
      titolo: 'Forma e fatica',
      testo: 'La linea spessa e\' quanto sei allenato: sale piano. Quella '
          'sottile e\' la fatica: sale dopo una seduta dura e scende in pochi '
          'giorni.',
      extra: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 330),
        child: Text(
          'Se la sottile resta sopra per settimane, stai caricando piu\' di '
          'quanto il corpo riesca a smaltire.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 15, height: 1.5, color: p.ink),
        ),
      ),
    );
  }
}

class _Legenda extends StatelessWidget {
  const _Legenda(this.testo, this.colore, this.spessore, this.p);
  final String testo;
  final Color colore;
  final double spessore;
  final AppPalette p;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Container(
          width: 18,
          height: spessore,
          decoration: BoxDecoration(
            color: colore,
            borderRadius: BorderRadius.circular(3),
          ),
        ),
        const SizedBox(width: 6),
        Text(testo, style: AppText.caption.copyWith(color: p.inkSoft)),
      ],
    );
  }
}

/// Il grafico finto della vignetta: la condizione che sale piano e la
/// fatica che va su e giu'. Stesse forme del bozzetto, su 310x120.
class _FormaFaticaPainter extends CustomPainter {
  const _FormaFaticaPainter({
    required this.condizione,
    required this.fatica,
    required this.griglia,
  });

  final Color condizione;
  final Color fatica;
  final Color griglia;

  static const List<Offset> _fatica = <Offset>[
    Offset(0, 92), Offset(20, 86), Offset(35, 70), Offset(50, 80),
    Offset(68, 52), Offset(84, 66), Offset(100, 44), Offset(116, 60),
    Offset(134, 40), Offset(150, 54), Offset(170, 26), Offset(186, 34),
    Offset(204, 22), Offset(222, 44), Offset(240, 30), Offset(258, 52),
    Offset(276, 66), Offset(294, 78), Offset(310, 88),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final double sx = size.width / 310;
    final double sy = size.height / 120;
    Offset s(double x, double y) => Offset(x * sx, y * sy);

    final Paint linea = Paint()
      ..color = griglia
      ..strokeWidth = 1;
    canvas.drawLine(s(0, 60), s(310, 60), linea);
    canvas.drawLine(s(0, 100), s(310, 100), linea);

    final Path f = Path()..moveTo(_fatica.first.dx * sx, _fatica.first.dy * sy);
    for (final Offset o in _fatica.skip(1)) {
      f.lineTo(o.dx * sx, o.dy * sy);
    }
    canvas.drawPath(
      f,
      Paint()
        ..color = fatica
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );

    final Offset a = s(0, 108);
    final Offset c1 = s(60, 100), c2 = s(100, 84), b = s(150, 72);
    final Offset c3 = s(200, 60), c4 = s(240, 54), e = s(310, 58);
    final Path c = Path()
      ..moveTo(a.dx, a.dy)
      ..cubicTo(c1.dx, c1.dy, c2.dx, c2.dy, b.dx, b.dy)
      ..cubicTo(c3.dx, c3.dy, c4.dx, c4.dy, e.dx, e.dy);
    canvas.drawPath(
      c,
      Paint()
        ..color = condizione
        ..style = PaintingStyle.stroke
        ..strokeWidth = 6
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(_FormaFaticaPainter old) =>
      old.condizione != condizione || old.fatica != fatica;
}

class _PaginaPiano extends StatelessWidget {
  const _PaginaPiano({required this.p});
  final AppPalette p;

  @override
  Widget build(BuildContext context) {
    const List<String> giorni = <String>[
      'LUN', 'MAR', 'MER', 'GIO', 'VEN', 'SAB', 'DOM',
    ];
    // (valore grande, sotto, tipo) - tipo: 0 vuoto, 1 turno, 2 facile,
    // 3 qualita'.
    const List<(String, String, int)> celle = <(String, String, int)>[
      ('', 'turno', 1),
      ('40\'', 'lento', 2),
      ('', '', 0),
      ('5×1k', 'ripetute', 3),
      ('', 'turno', 1),
      ('35\'', 'lento', 2),
      ('16k', 'lungo', 2),
    ];

    return _Vignetta(
      p: p,
      disegno: Column(
        children: <Widget>[
          const Omino(pose: OminoPose.corre, size: 140),
          const SizedBox(height: 18),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 342),
            child: Row(
              children: <Widget>[
                for (int i = 0; i < 7; i++) ...<Widget>[
                  if (i > 0) const SizedBox(width: 6),
                  Expanded(child: _Giorno(giorni[i], celle[i], p)),
                ],
              ],
            ),
          ),
        ],
      ),
      titolo: 'Un piano che segue i tuoi turni',
      testo: 'Dimmi in che giorni puoi correre e quanto tempo hai. Il lungo '
          'va dove hai piu\' tempo, la qualita\' mai attaccata a un\'altra. '
          'E la mattina ti dico se oggi e\' giornata da spingere o da '
          'tenere facile.',
    );
  }
}

class _Giorno extends StatelessWidget {
  const _Giorno(this.nome, this.cella, this.p);
  final String nome;
  final (String, String, int) cella;
  final AppPalette p;

  @override
  Widget build(BuildContext context) {
    final (String grande, String sotto, int tipo) = cella;
    final bool qualita = tipo == 3;
    final Color fondo = qualita
        ? p.accent
        : (tipo == 2 ? p.surfaceElevated : p.surface);
    final Color testo = qualita ? p.onAccent : p.inkSoft;
    return Column(
      children: <Widget>[
        Text(
          nome,
          style: AppText.label.copyWith(color: p.inkFaint, letterSpacing: 0.3),
        ),
        const SizedBox(height: 6),
        Container(
          height: 64,
          decoration: BoxDecoration(
            color: fondo,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              if (grande.isNotEmpty)
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 2),
                    child: Text(
                      grande,
                      style: AppText.number(17,
                          color: qualita ? p.onAccent : p.ink),
                    ),
                  ),
                ),
              if (sotto.isNotEmpty)
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 2),
                    child: Text(
                      sotto,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight:
                            qualita ? FontWeight.w600 : FontWeight.w400,
                        color: tipo == 1 ? p.inkFaint : testo,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _Puntini extends StatelessWidget {
  const _Puntini({required this.pagina, required this.totale, required this.p});
  final int pagina;
  final int totale;
  final AppPalette p;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Pagina ${pagina + 1} di $totale',
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          for (int i = 0; i < totale; i++)
            AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              margin: const EdgeInsets.symmetric(horizontal: 3),
              width: i == pagina ? 22 : 6,
              height: 6,
              decoration: BoxDecoration(
                color: i == pagina
                    ? p.accent
                    : p.inkFaint.withValues(alpha: 0.35),
                borderRadius: BorderRadius.circular(3),
              ),
            ),
        ],
      ),
    );
  }
}

class _Etichetta extends StatelessWidget {
  const _Etichetta(this.testo, {required this.p});
  final String testo;
  final AppPalette p;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(
          testo,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: p.inkSoft,
          ),
        ),
      );
}

class _Nota extends StatelessWidget {
  const _Nota(this.testo, {required this.p, this.errore = false});
  final String testo;
  final AppPalette p;
  final bool errore;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: 6),
        child: Text(
          testo,
          style: TextStyle(
            fontSize: 12,
            height: 1.4,
            color: errore ? p.red : p.inkFaint,
          ),
        ),
      );
}

class _Campo extends StatelessWidget {
  const _Campo({
    required this.controller,
    required this.hint,
    required this.p,
    this.keyboard,
    this.capitalization = TextCapitalization.none,
    this.numero = false,
  });

  final TextEditingController controller;
  final String hint;
  final AppPalette p;
  final TextInputType? keyboard;
  final TextCapitalization capitalization;
  final bool numero;

  @override
  Widget build(BuildContext context) {
    final TextStyle stile = numero
        ? AppText.number(21, color: p.ink)
        : TextStyle(fontSize: 16, color: p.ink);
    final OutlineInputBorder bordo = OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: BorderSide.none,
    );
    return TextField(
      controller: controller,
      keyboardType: keyboard,
      textCapitalization: capitalization,
      textInputAction: TextInputAction.done,
      style: stile,
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: stile.copyWith(color: p.inkFaint),
        filled: true,
        fillColor: p.surface,
        isDense: true,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 15),
        border: bordo,
        enabledBorder: bordo,
        focusedBorder: bordo.copyWith(
          borderSide: BorderSide(color: p.accent, width: 2),
        ),
      ),
    );
  }
}

/// Una pillola da toccare (distanza, unita', gara o allenamento).
class _Scelta extends StatelessWidget {
  const _Scelta({
    required this.testo,
    required this.scelta,
    required this.p,
    required this.onTap,
    this.piccola = false,
  });

  final String testo;
  final bool scelta;
  final AppPalette p;
  final VoidCallback onTap;
  final bool piccola;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: scelta,
      child: Material(
        color: scelta ? p.accent : p.surfaceElevated,
        borderRadius: BorderRadius.circular(piccola ? 10 : 14),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(piccola ? 10 : 14),
          child: Container(
            height: piccola ? 36 : 50,
            padding: EdgeInsets.symmetric(horizontal: piccola ? 12 : 13),
            alignment: Alignment.center,
            child: Text(
              testo,
              style: TextStyle(
                fontSize: piccola ? 13 : 15,
                fontWeight: scelta ? FontWeight.w600 : FontWeight.w400,
                color: scelta ? p.onAccent : p.inkSoft,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
