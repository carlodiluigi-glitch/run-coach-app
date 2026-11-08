import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../app/tokens.dart';
import '../models/coach_week.dart';
import '../models/running_activity.dart';
import '../models/training_plan.dart';
import '../providers/activity_provider.dart';
import '../providers/plan_provider.dart';
import '../services/coach_export.dart';
import '../services/coach_import.dart';
import '../utils/giorni.dart';
import '../widgets/app_card.dart';
import '../widgets/inset_list.dart';

/// "Incolla dal coach": il secondo pezzo del giro.
///
/// Si incolla la risposta dell'AI (anche tutta: il blocco si trova da solo),
/// Falcata la legge e la controlla, mostra la settimana nuova accanto a
/// quella del piano, e la applica solo dopo la conferma. Vedi [CoachImport].
class CoachImportScreen extends StatefulWidget {
  const CoachImportScreen({super.key});

  @override
  State<CoachImportScreen> createState() => _CoachImportScreenState();
}

class _CoachImportScreenState extends State<CoachImportScreen> {
  final TextEditingController _testo = TextEditingController();
  CoachImportResult? _risultato;
  List<CoachCheck> _controlli = <CoachCheck>[];
  bool _avvisiLetti = false;
  bool _salvando = false;

  @override
  void dispose() {
    _testo.dispose();
    super.dispose();
  }

  Future<void> _incolla() async {
    final ClipboardData? dati = await Clipboard.getData(Clipboard.kTextPlain);
    final String? t = dati?.text;
    if (t == null || t.trim().isEmpty) {
      _avviso('Negli appunti non c\'e\' testo. Copia la risposta dell\'AI.');
      return;
    }
    _testo.text = t;
    _controlla();
  }

  void _controlla() {
    final ActivityProvider attivita = context.read<ActivityProvider>();
    final PlanProvider piani = context.read<PlanProvider>();
    const CoachImport imp = CoachImport();
    final CoachImportResult r = imp.parse(_testo.text, now: DateTime.now());
    setState(() {
      _risultato = r;
      _avvisiLetti = false;
      _controlli = r.week == null
          ? <CoachCheck>[]
          : imp.check(
              week: r.week!,
              activities: attivita.activities,
              plan: piani.plan,
              zones: attivita.trainingZones,
            );
    });
  }

  /// Un messaggio pronto da incollare all'AI per farle correggere il blocco.
  String _perAi() {
    final CoachImportResult? r = _risultato;
    final List<String> righe = <String>[
      'Falcata non accetta il blocco, per questi motivi:',
      for (final String e in r?.errors ?? <String>[]) '- $e',
      for (final CoachCheck c in _controlli)
        if (c.blocking) '- ${c.message}',
      '',
      'Riscrivi il blocco ${CoachExport.inizioBlocco} corretto, nello '
          'stesso formato.',
    ];
    return righe.join('\n');
  }

  Future<void> _conferma() async {
    final CoachWeek? w = _risultato?.week;
    if (w == null) return;
    setState(() => _salvando = true);
    final PlanProvider piani = context.read<PlanProvider>();
    final ActivityProvider attivita = context.read<ActivityProvider>();

    final bool ok = await piani.applyCoachWeek(w);
    int riepiloghi = 0;
    for (final CoachSummary s in _risultato!.summaries) {
      final RunningActivity? a = attivita.byId(s.activityId);
      if (a == null) continue;
      await attivita.update(a.copyWith(coachSummary: s.asText));
      riepiloghi++;
    }
    if (!mounted) return;
    setState(() => _salvando = false);
    if (!ok) {
      _avviso('Salvataggio non riuscito. Riprova.');
      return;
    }
    _avviso(riepiloghi == 0
        ? 'Settimana applicata al piano.'
        : 'Settimana applicata. Salvati $riepiloghi riepiloghi delle corse.');
    Navigator.of(context).pop();
  }

  void _avviso(String testo) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(testo)));
  }

  @override
  Widget build(BuildContext context) {
    final AppPalette p = AppPalette.of(context);
    final PlanProvider piani = context.watch<PlanProvider>();
    final CoachImportResult? r = _risultato;
    final CoachWeek? w = r?.week;
    final bool bloccato = _controlli.any((CoachCheck c) => c.blocking);
    final bool avvisi = _controlli.any((CoachCheck c) => !c.blocking);

    // Una settimana del coach gia' attiva, da poter togliere.
    final DateTime oggi = soloGiorno(DateTime.now());
    final CoachWeek? attiva = piani.coachWeeks
        .cast<CoachWeek?>()
        .firstWhere((CoachWeek? c) => !c!.to.isBefore(oggi),
            orElse: () => null);

    return Scaffold(
      appBar: AppBar(title: const Text('Incolla dal coach')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
              AppSpacing.screenSide, 12, AppSpacing.screenSide, 32),
          children: <Widget>[
            if (!piani.hasPlan)
              AppCard(
                child: Text(
                  'Serve un piano attivo: la settimana del coach si appoggia '
                  'sopra le sedute del piano. Crea prima un piano.',
                  style: AppText.body.copyWith(color: p.inkSoft),
                ),
              )
            else ...<Widget>[
              if (attiva != null) ...<Widget>[
                AppCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        'La settimana dal ${_data(attiva.from)} e\' '
                        'concordata col coach.',
                        style: AppText.row.copyWith(color: p.ink),
                      ),
                      const SizedBox(height: 6),
                      TextButton(
                        onPressed: () async {
                          await piani.removeCoachWeek(attiva.from);
                          if (!mounted) return;
                          _avviso('Tornata la settimana del piano.');
                        },
                        child: const Text('Torna alla settimana del piano'),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],
              Text(
                'Copia la risposta dell\'AI - anche tutta, il blocco lo trovo '
                'io - e incollala qui.',
                style: AppText.body.copyWith(color: p.inkSoft),
              ),
              const SizedBox(height: 12),
              SizedBox(
                height: 52,
                child: FilledButton.icon(
                  onPressed: _incolla,
                  style: FilledButton.styleFrom(
                    backgroundColor: p.accent,
                    foregroundColor: p.onAccent,
                  ),
                  icon: const Icon(Icons.content_paste_rounded, size: 19),
                  label: const Text('Incolla e controlla'),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _testo,
                minLines: 3,
                maxLines: 6,
                style: AppText.caption.copyWith(
                    color: p.ink, fontFamily: 'monospace'),
                decoration: InputDecoration(
                  hintText: 'Oppure incolla qui a mano...',
                  filled: true,
                  fillColor: p.surface,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppRadius.small),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: _controlla,
                  child: const Text('Controlla'),
                ),
              ),

              // ------------------------------------------------- errori
              if (r != null && !r.isOk) ...<Widget>[
                const SectionTitle('Da correggere'),
                AppCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      for (final String e in r.errors)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 6),
                          child: Text('• $e',
                              style: AppText.body.copyWith(color: p.red)),
                        ),
                    ],
                  ),
                ),
                _copiaPerAi(p),
              ],

              // ---------------------------------------- settimana letta
              if (w != null) ...<Widget>[
                const SectionTitle('La proposta'),
                AppCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        '${w.decisionLabel} · dal ${_data(w.from)} '
                        'al ${_data(w.to)}',
                        style: AppText.title.copyWith(color: p.ink),
                      ),
                      if (w.reason.isNotEmpty) ...<Widget>[
                        const SizedBox(height: 6),
                        Text(w.reason,
                            style: AppText.body.copyWith(color: p.inkSoft)),
                      ],
                    ],
                  ),
                ),
                const SectionTitle('Giorno per giorno'),
                InsetList(
                  children: <Widget>[
                    for (int g = 0; g < 7; g++)
                      _giorno(context, p, piani, w, piuGiorni(w.from, g)),
                  ],
                ),
                if (_controlli.isNotEmpty) ...<Widget>[
                  const SectionTitle('Controlli di Falcata'),
                  AppCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        for (final CoachCheck c in _controlli)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: <Widget>[
                                Icon(
                                  c.blocking
                                      ? Icons.block_rounded
                                      : Icons.info_outline_rounded,
                                  size: 18,
                                  color: c.blocking ? p.red : p.orange,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(c.message,
                                      style: AppText.body
                                          .copyWith(color: p.ink)),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
                if (r!.summaries.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 10, left: 4),
                    child: Text(
                      'Con la settimana arrivano ${r.summaries.length} '
                      'riepiloghi delle corse: li trovi nelle note di ogni '
                      'corsa, marcati come scritti dal coach.',
                      style: AppText.caption.copyWith(color: p.inkFaint),
                    ),
                  ),
                const SizedBox(height: 16),
                if (bloccato) ...<Widget>[
                  Text(
                    'Prima di confermare vanno corretti i punti in rosso: '
                    'chiedi all\'AI di spostare le sedute.',
                    style: AppText.body.copyWith(color: p.red),
                  ),
                  _copiaPerAi(p),
                ] else ...<Widget>[
                  if (avvisi)
                    CheckboxListTile(
                      value: _avvisiLetti,
                      onChanged: (bool? v) =>
                          setState(() => _avvisiLetti = v ?? false),
                      contentPadding: EdgeInsets.zero,
                      controlAffinity: ListTileControlAffinity.leading,
                      title: Text('Ho letto gli avvisi e la voglio lo stesso',
                          style: AppText.row.copyWith(color: p.ink)),
                    ),
                  SizedBox(
                    height: 52,
                    child: FilledButton(
                      onPressed: _salvando || (avvisi && !_avvisiLetti)
                          ? null
                          : _conferma,
                      style: FilledButton.styleFrom(
                        backgroundColor: p.accent,
                        foregroundColor: p.onAccent,
                        disabledBackgroundColor: p.separator,
                        disabledForegroundColor: p.inkFaint,
                      ),
                      child: const Text('Conferma la settimana'),
                    ),
                  ),
                ],
              ],
            ],
          ],
        ),
      ),
    );
  }

  Widget _copiaPerAi(AppPalette p) => Align(
        alignment: Alignment.centerLeft,
        child: TextButton.icon(
          onPressed: () async {
            await Clipboard.setData(ClipboardData(text: _perAi()));
            if (!mounted) return;
            _avviso('Copiato: incollalo nella chat con l\'AI.');
          },
          icon: const Icon(Icons.copy_rounded, size: 18),
          label: const Text('Copia la richiesta di correzione per l\'AI'),
        ),
      );

  Widget _giorno(BuildContext context, AppPalette p, PlanProvider piani,
      CoachWeek w, DateTime giorno) {
    final List<PlannedSession> nuove = w.sessions
        .where((PlannedSession s) => giorniFra(s.date, giorno) == 0)
        .toList();
    final List<PlannedSession> prima = piani.baseSessionsOn(giorno);
    final String primaTesto = prima.isEmpty
        ? 'riposo'
        : prima.map((PlannedSession s) => s.title).join(', ');

    return AppListRow(
      title: '${_nome(giorno)} ${giorno.day}/${giorno.month}: '
          '${nuove.isEmpty ? 'riposo' : nuove.map((PlannedSession s) => '${s.kind.label} - ${s.title}').join(', ')}',
      subtitle: <String>[
        for (final PlannedSession s in nuove) s.detail,
        'Nel piano: $primaTesto',
      ].join('\n'),
      showChevron: false,
    );
  }

  static const List<String> _nomi = <String>[
    'Lun',
    'Mar',
    'Mer',
    'Gio',
    'Ven',
    'Sab',
    'Dom',
  ];

  static String _nome(DateTime d) => _nomi[d.weekday - 1];

  static String _data(DateTime d) => '${d.day}/${d.month}';
}
