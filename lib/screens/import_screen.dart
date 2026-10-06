import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../app/tokens.dart';
import '../models/running_activity.dart';
import '../providers/activity_provider.dart';
import '../services/gpx_import.dart';
import '../services/native_bridge.dart';
import '../utils/formatters.dart';
import '../widgets/app_card.dart';

/// Portare dentro le corse che hai gia' fatto.
///
/// PERCHE' ESISTE
/// --------------
/// Chi scarica Falcata corre gia' da anni, e quegli anni stanno da un'altra
/// parte. Al primo avvio l'app guarda un archivio vuoto e dice la verita': non
/// ho abbastanza per stimare la tua forma, non posso proporti un volume di
/// partenza, non posso scriverti un piano.
///
/// E' onesto, ed e' anche il momento in cui l'app viene disinstallata.
///
/// COME E' FATTA LA PROCEDURA
/// --------------------------
/// Si sceglie il file, si vede **cosa e' stato trovato**, e solo dopo si
/// conferma. Niente entra nell'archivio prima che l'utente abbia letto quante
/// corse sono e quanti chilometri: l'archivio e' la base di ogni stima che
/// l'app fa, e riempirlo alla cieca e' il modo piu' veloce di rovinarlo.
class ImportScreen extends StatefulWidget {
  const ImportScreen({super.key});

  @override
  State<ImportScreen> createState() => _ImportScreenState();
}

class _ImportScreenState extends State<ImportScreen> {
  final NativeBridge _native = NativeBridge();

  bool _lavorando = false;
  GpxResult? _letto;
  List<RunningActivity> _nuove = const <RunningActivity>[];
  String? _esito;
  bool _esitoBuono = true;

  @override
  Widget build(BuildContext context) {
    final AppPalette p = AppPalette.of(context);
    final ActivityProvider attivita = context.watch<ActivityProvider>();
    final GpxResult? letto = _letto;

    return Scaffold(
      appBar: AppBar(title: const Text('Importa le tue corse')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.screenSide,
            8,
            AppSpacing.screenSide,
            32,
          ),
          children: <Widget>[
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    'Se corri gia\' da prima',
                    style: AppText.title.copyWith(color: p.ink),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Falcata ricava la tua forma, i ritmi di allenamento e il '
                    'volume di partenza del piano dalle corse che ha in '
                    'archivio. Appena installata non ne ha nessuna, e per '
                    'qualche settimana non puo\' dirti granche\'.\n\n'
                    'Se hai le tue corse in file GPX - Strava, Garmin, Polar e '
                    'quasi tutti li esportano cosi\' - portale dentro e l\'app '
                    'parte sapendo chi sei.',
                    style: AppText.body.copyWith(color: p.inkSoft),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 18),
            SizedBox(
              height: 52,
              child: FilledButton.icon(
                onPressed: _lavorando ? null : _scegli,
                style: FilledButton.styleFrom(
                  backgroundColor: p.accent,
                  foregroundColor: p.onAccent,
                ),
                icon: const Icon(Icons.file_open_outlined, size: 19),
                label: Text(_lavorando ? 'Leggo...' : 'Scegli un file GPX'),
              ),
            ),

            // ------------------------------------------- cosa ho trovato
            if (letto != null && letto.isOk) ...<Widget>[
              const SectionTitle('Cosa ho trovato'),
              AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      letto.summary,
                      style: AppText.body.copyWith(color: p.ink),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      _nuove.isEmpty
                          ? 'Sono gia\' tutte nel tuo archivio: non c\'e\' '
                              'niente da aggiungere.'
                          : _nuove.length == letto.activities.length
                              ? 'Nessuna di queste e\' gia\' in archivio.'
                              : '${_nuove.length} non ce le hai ancora, le '
                                  'altre erano gia\' dentro.',
                      style: AppText.caption.copyWith(color: p.inkFaint),
                    ),
                    if (_nuove.isNotEmpty) ...<Widget>[
                      const SizedBox(height: 14),
                      for (final RunningActivity a in _nuove.take(5))
                        Padding(
                          padding: const EdgeInsets.only(bottom: 6),
                          child: Row(
                            children: <Widget>[
                              Expanded(
                                child: Text(
                                  formatDateShort(a.startTime),
                                  style: AppText.caption
                                      .copyWith(color: p.inkSoft),
                                ),
                              ),
                              Text(
                                '${formatDistance(a.distanceMeters)} km  ·  '
                                '${formatDuration(a.duration)}',
                                style: AppText.number(13, color: p.ink),
                              ),
                            ],
                          ),
                        ),
                      if (_nuove.length > 5)
                        Text(
                          '... e altre ${_nuove.length - 5}',
                          style: AppText.caption.copyWith(color: p.inkFaint),
                        ),
                      const SizedBox(height: 14),
                      SizedBox(
                        height: 50,
                        child: FilledButton(
                          onPressed: _lavorando ? null : _conferma,
                          style: FilledButton.styleFrom(
                            backgroundColor: p.green,
                            foregroundColor: Colors.white,
                          ),
                          child: Text(
                            _nuove.length == 1
                                ? 'Aggiungi questa corsa'
                                : 'Aggiungi ${_nuove.length} corse',
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],

            if (_esito != null) ...<Widget>[
              const SizedBox(height: 18),
              AppCard(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Icon(
                      _esitoBuono ? Icons.check_circle : Icons.error_outline,
                      size: 19,
                      color: _esitoBuono ? p.green : p.orange,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        _esito!,
                        style: AppText.body.copyWith(color: p.ink),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 22),
            AppCard(
              child: Text(
                'La distanza delle corse importate viene ricalcolata con lo '
                'stesso metodo che Falcata usa durante una corsa, non copiata '
                'dal file: cosi\' una corsa importata e una registrata si '
                'possono confrontare. Le tracce in bicicletta o in macchina '
                'vengono riconosciute dal passo e lasciate fuori.\n\n'
                'Hai ${attivita.activities.length} '
                '${attivita.activities.length == 1 ? 'corsa' : 'corse'} in '
                'archivio adesso.',
                style: AppText.caption.copyWith(color: p.inkFaint),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _scegli() async {
    setState(() {
      _lavorando = true;
      _esito = null;
      _letto = null;
      _nuove = const <RunningActivity>[];
    });

    final String? testo = await _native.openTextFile();
    if (!mounted) return;
    if (testo == null) {
      setState(() {
        _lavorando = false;
        _esito = 'Nessun file scelto.';
        _esitoBuono = false;
      });
      return;
    }

    final GpxResult r = GpxImport.parse(testo);
    if (!mounted) return;

    if (!r.isOk) {
      setState(() {
        _lavorando = false;
        _esito = r.summary;
        _esitoBuono = false;
      });
      return;
    }

    final List<RunningActivity> nuove = GpxImport.nuoveFra(
      r.activities,
      context.read<ActivityProvider>().activities,
    );

    setState(() {
      _lavorando = false;
      _letto = r;
      _nuove = nuove;
    });
  }

  Future<void> _conferma() async {
    setState(() => _lavorando = true);
    final ActivityProvider provider = context.read<ActivityProvider>();

    int fatte = 0;
    for (final RunningActivity a in _nuove) {
      if (await provider.add(a)) fatte++;
      if (!mounted) return;
    }

    setState(() {
      _lavorando = false;
      _letto = null;
      _nuove = const <RunningActivity>[];
      _esitoBuono = fatte > 0;
      _esito = fatte == 0
          ? 'Non sono riuscito ad aggiungerle.'
          : fatte == 1
              ? 'Aggiunta 1 corsa. L\'indice di forma si aggiorna da solo.'
              : 'Aggiunte $fatte corse. L\'indice di forma e i ritmi si '
                  'aggiornano da soli.';
    });
  }
}
