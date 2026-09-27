import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../app/tokens.dart';
import '../models/athlete_profile.dart';
import '../providers/activity_provider.dart';
import '../utils/formatters.dart';
import '../widgets/app_card.dart';
import '../widgets/inset_list.dart';

/// Chi sei e cosa hai gia' fatto.
///
/// PERCHE' QUESTA SCHERMATA E' IMPORTANTE
/// --------------------------------------
/// Il motore di forma sa solo quello che ha misurato. Se l'unica corsa in
/// archivio era tranquilla, l'indice dice che vai piano, perche' piano hai
/// corso: non ha modo di sapere che sei capace di molto di piu'.
///
/// Qui glielo si dice. Un personale fatto in gara e' l'evidenza piu' forte
/// che esista (affidabilita' 1,0 contro lo 0,45 di un tratto veloce dentro
/// una corsa normale), quindi sposta l'indice subito e in modo deciso.
///
/// Eta', anni di corsa e stop recenti NON toccano i ritmi: servono solo a
/// decidere quanto in fretta si puo' alzare il carico. E' scritto anche
/// nella schermata, perche' e' la domanda che si fanno tutti.
class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final ActivityProvider activities = context.watch<ActivityProvider>();
    final AthleteProfile profile = activities.athleteProfile;
    final AppPalette p = AppPalette.of(context);

    final List<PersonalBest> bests = List<PersonalBest>.from(
      profile.personalBests,
    )..sort((PersonalBest a, PersonalBest b) => a.meters.compareTo(b.meters));

    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 44,
        backgroundColor: p.background,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
      ),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.screenSide,
            0,
            AppSpacing.screenSide,
            32,
          ),
          children: <Widget>[
            Text('Profilo', style: AppText.largeTitle.copyWith(color: p.ink)),
            const SizedBox(height: 16),

            // ------------------------------------------------ i personali
            SectionTitle(
              'I tuoi personali',
              trailing: TextButton(
                onPressed: () => _addBest(context, activities, profile),
                child: const Text('Aggiungi'),
              ),
            ),
            if (bests.isEmpty)
              AppCard(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Icon(Icons.emoji_events_outlined,
                        size: 22, color: p.inkFaint),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Non ne hai ancora dichiarato nessuno. Finche\' non '
                        'lo fai, il motore puo\' andare solo da quello che '
                        'hai corso con l\'app.',
                        style: AppText.body.copyWith(color: p.inkSoft),
                      ),
                    ),
                  ],
                ),
              )
            else
              InsetList(
                children: <Widget>[
                  for (final PersonalBest best in bests)
                    AppListRow(
                      title: _distanceLabel(best.meters),
                      subtitle: _bestSubtitle(best),
                      value: formatDuration(Duration(seconds: best.seconds)),
                      valueColor: best.wasRace ? p.accent : p.ink,
                      onTap: () =>
                          _editBest(context, activities, profile, best),
                    ),
                ],
              ),
            const SizedBox(height: 10),
            _Note(
              icon: Icons.workspace_premium_outlined,
              text: 'Una prestazione fatta in gara vale il massimo: in gara '
                  'ci si spreme davvero. Un test o una prova in allenamento '
                  'vale un po\' meno, perche\' quasi nessuno arriva fino in '
                  'fondo da solo. Metti la data vera: una prestazione di un '
                  'anno fa pesa poco, ed e\' giusto cosi\'.',
            ),

            // --------------------------------------------------- chi sei
            const SectionTitle('Chi sei'),
            InsetList(
              children: <Widget>[
                AppListRow(
                  title: 'Anno di nascita',
                  value: profile.birthYear == null
                      ? 'Non detto'
                      : '${profile.birthYear}',
                  onTap: () => _pickNumber(
                    context,
                    title: 'Anno di nascita',
                    from: DateTime.now().year - 90,
                    to: DateTime.now().year - 8,
                    current: profile.birthYear,
                    label: (int v) => '$v',
                    onPicked: (int? v) => activities.updateAthleteProfile(
                      v == null
                          ? profile.copyWith(clearBirthYear: true)
                          : profile.copyWith(birthYear: v),
                    ),
                  ),
                ),
                AppListRow(
                  title: 'Da quanti anni corri',
                  value: profile.runningYears == null
                      ? 'Non detto'
                      : _years(profile.runningYears!),
                  onTap: () => _pickNumber(
                    context,
                    title: 'Da quanti anni corri',
                    from: 0,
                    to: 40,
                    current: profile.runningYears,
                    label: _years,
                    onPicked: (int? v) => activities.updateAthleteProfile(
                      v == null
                          ? profile.copyWith(clearRunningYears: true)
                          : profile.copyWith(runningYears: v),
                    ),
                  ),
                ),
                AppListRow(
                  title: 'Giorni a settimana',
                  subtitle: 'Quanti ne hai davvero, non quanti vorresti',
                  value: '${profile.availableDays}',
                  onTap: () => _pickNumber(
                    context,
                    title: 'Giorni a settimana',
                    from: 2,
                    to: 7,
                    current: profile.availableDays,
                    label: (int v) => '$v giorni',
                    allowNone: false,
                    onPicked: (int? v) => activities.updateAthleteProfile(
                      profile.copyWith(availableDays: v ?? 4),
                    ),
                  ),
                ),
                AppListRow(
                  title: 'Stop recente',
                  subtitle: 'Settimane ferme, se hai appena ripreso',
                  value: profile.inactiveSinceWeeks == null
                      ? 'Nessuno'
                      : '${profile.inactiveSinceWeeks} settimane',
                  onTap: () => _pickNumber(
                    context,
                    title: 'Settimane di stop',
                    from: 1,
                    to: 26,
                    current: profile.inactiveSinceWeeks,
                    label: (int v) => v == 1 ? '1 settimana' : '$v settimane',
                    noneLabel: 'Nessuno stop',
                    onPicked: (int? v) => activities.updateAthleteProfile(
                      v == null
                          ? profile.copyWith(clearInactive: true)
                          : profile.copyWith(inactiveSinceWeeks: v),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            _Note(
              icon: Icons.speed_outlined,
              text: 'Questi dati NON decidono i tuoi ritmi. I ritmi vengono '
                  'solo da quello che hai corso: due persone con la stessa '
                  'prestazione si allenano agli stessi passi, che pesino '
                  'cinquanta chili o novanta. Servono a un\'altra cosa, '
                  'quanto in fretta alzare il carico: a parita\' di '
                  'prestazione un cinquantenne che corre da un anno recupera '
                  'piu\' lentamente di un venticinquenne che corre da dieci.',
            ),
            if (profile.hasBasics) ...<Widget>[
              const SizedBox(height: 10),
              AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text('COME TI CARICO',
                        style: AppText.label.copyWith(color: p.inkFaint)),
                    const SizedBox(height: 8),
                    Text(
                      profile.loadToleranceExplanation,
                      style: AppText.body.copyWith(color: p.ink),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // --------------------------------------------------------------- personali
  Future<void> _addBest(
    BuildContext context,
    ActivityProvider activities,
    AthleteProfile profile,
  ) async {
    final _BestResult? result = await showModalBottomSheet<_BestResult>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext ctx) => const _BestSheet(),
    );
    final PersonalBest? created = result?.best;
    if (created == null) return;
    await activities.updateAthleteProfile(
      profile.copyWith(
        personalBests: <PersonalBest>[...profile.personalBests, created],
      ),
    );
  }

  Future<void> _editBest(
    BuildContext context,
    ActivityProvider activities,
    AthleteProfile profile,
    PersonalBest best,
  ) async {
    final _BestResult? result = await showModalBottomSheet<_BestResult>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext ctx) => _BestSheet(existing: best),
    );
    if (result == null) return;

    final List<PersonalBest> next = <PersonalBest>[];
    for (final PersonalBest item in profile.personalBests) {
      if (identical(item, best)) {
        final PersonalBest? replacement = result.best;
        if (replacement != null) next.add(replacement);
        continue;
      }
      next.add(item);
    }
    await activities.updateAthleteProfile(
      profile.copyWith(personalBests: next),
    );
  }

  static String _bestSubtitle(PersonalBest best) {
    final String kind = best.wasRace ? 'In gara' : 'In allenamento';
    final DateTime? date = best.date;
    if (date == null) return '$kind, data non indicata';
    return '$kind, ${formatDateShort(date)}';
  }

  static String _years(int value) => value == 1 ? '1 anno' : '$value anni';

  static String _distanceLabel(double meters) {
    for (final _Distance d in _Distance.all) {
      if ((d.meters - meters).abs() < 1) return d.label;
    }
    if (meters >= 1000) {
      final double km = meters / 1000.0;
      return km == km.roundToDouble()
          ? '${km.round()} km'
          : '${km.toStringAsFixed(1)} km';
    }
    return '${meters.round()} m';
  }

  // ----------------------------------------------------------- scelta numero
  Future<void> _pickNumber(
    BuildContext context, {
    required String title,
    required int from,
    required int to,
    required int? current,
    required String Function(int) label,
    required void Function(int?) onPicked,
    bool allowNone = true,
    String noneLabel = 'Non lo dico',
  }) async {
    final List<int> values = <int>[for (int v = from; v <= to; v++) v];
    final AppPalette p = AppPalette.of(context);

    final int? chosen = await showModalBottomSheet<int>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext ctx) => Container(
        decoration: BoxDecoration(
          color: p.background,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        height: MediaQuery.of(ctx).size.height * 0.6,
        child: Column(
          children: <Widget>[
            const SizedBox(height: 14),
            Text(title, style: AppText.title.copyWith(color: p.ink)),
            const SizedBox(height: 10),
            Expanded(
              child: ListView(
                children: <Widget>[
                  if (allowNone)
                    ListTile(
                      title: Text(noneLabel,
                          style: AppText.row.copyWith(color: p.inkSoft)),
                      trailing: current == null
                          ? Icon(Icons.check, color: p.accent)
                          : null,
                      onTap: () => Navigator.of(ctx).pop(_noneSentinel),
                    ),
                  for (final int value in values.reversed)
                    ListTile(
                      title: Text(label(value),
                          style: AppText.row.copyWith(color: p.ink)),
                      trailing: current == value
                          ? Icon(Icons.check, color: p.accent)
                          : null,
                      onTap: () => Navigator.of(ctx).pop(value),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );

    if (chosen == null) return;
    onPicked(chosen == _noneSentinel ? null : chosen);
  }

  /// Valore impossibile usato per distinguere "ha scelto Non lo dico" da
  /// "ha chiuso il foglio senza scegliere": entrambi tornerebbero `null`.
  static const int _noneSentinel = -99999;
}

/// Una distanza proponibile come personale.
class _Distance {
  const _Distance(this.label, this.meters);

  final String label;
  final double meters;

  static const List<_Distance> all = <_Distance>[
    _Distance('1500 m', 1500),
    _Distance('3000 m', 3000),
    _Distance('5 km', 5000),
    _Distance('10 km', 10000),
    _Distance('Mezza maratona', 21097.5),
    _Distance('Maratona', 42195),
  ];
}

/// Cosa torna indietro dal foglio.
///
/// Serve un involucro perche' ci sono TRE esiti, non due: salvato, eliminato
/// e chiuso senza fare niente. Senza involucro "eliminato" e "chiuso" sarebbero
/// tutti e due `null` e il personale non si potrebbe togliere.
class _BestResult {
  const _BestResult(this.best);

  /// `null` se l'atleta ha chiesto di eliminarlo.
  final PersonalBest? best;
}

/// Inserimento o modifica di un personale.
class _BestSheet extends StatefulWidget {
  const _BestSheet({this.existing});

  final PersonalBest? existing;

  @override
  State<_BestSheet> createState() => _BestSheetState();
}

class _BestSheetState extends State<_BestSheet> {
  late double _meters;
  late bool _wasRace;
  late DateTime _date;
  late final TextEditingController _hours;
  late final TextEditingController _minutes;
  late final TextEditingController _seconds;

  @override
  void initState() {
    super.initState();
    final PersonalBest? existing = widget.existing;
    _meters = existing?.meters ?? 10000;
    _wasRace = existing?.wasRace ?? true;
    _date = existing?.date ?? DateTime.now();

    final int total = existing?.seconds ?? 0;
    _hours = TextEditingController(
      text: total >= 3600 ? '${total ~/ 3600}' : '',
    );
    _minutes = TextEditingController(
      text: total > 0 ? '${(total % 3600) ~/ 60}' : '',
    );
    _seconds = TextEditingController(
      text: total > 0 ? '${total % 60}' : '',
    );
  }

  @override
  void dispose() {
    _hours.dispose();
    _minutes.dispose();
    _seconds.dispose();
    super.dispose();
  }

  int get _totalSeconds {
    final int h = int.tryParse(_hours.text.trim()) ?? 0;
    final int m = int.tryParse(_minutes.text.trim()) ?? 0;
    final int s = int.tryParse(_seconds.text.trim()) ?? 0;
    return h * 3600 + m * 60 + s;
  }

  /// Un tempo che darebbe un passo impossibile viene rifiutato prima di
  /// entrare nel motore: meglio nessun dato che un dato finto.
  String? get _problem {
    final int total = _totalSeconds;
    if (total <= 0) return 'Manca il tempo.';
    final double pace = total / (_meters / 1000.0);
    if (pace < 130) {
      return 'Troppo veloce per essere vero: ricontrolla minuti e secondi.';
    }
    if (pace > 1200) {
      return 'Troppo lento: sicuro che sia quella la distanza?';
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final AppPalette p = AppPalette.of(context);
    final String? problem = _problem;
    final bool editing = widget.existing != null;

    return Container(
      decoration: BoxDecoration(
        color: p.background,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.fromLTRB(
        AppSpacing.screenSide,
        10,
        AppSpacing.screenSide,
        MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 18),
                decoration: BoxDecoration(
                  color: p.separator,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Text(
              editing ? 'Modifica il personale' : 'Aggiungi un personale',
              style: AppText.largeTitle.copyWith(color: p.ink, fontSize: 26),
            ),
            const SizedBox(height: 16),

            Text('DISTANZA', style: AppText.label.copyWith(color: p.inkFaint)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: <Widget>[
                for (final _Distance d in _Distance.all)
                  ChoiceChip(
                    label: Text(d.label),
                    selected: (_meters - d.meters).abs() < 1,
                    onSelected: (bool on) {
                      if (!on) return;
                      setState(() => _meters = d.meters);
                    },
                  ),
              ],
            ),

            const SizedBox(height: 20),
            Text('TEMPO', style: AppText.label.copyWith(color: p.inkFaint)),
            const SizedBox(height: 8),
            Row(
              children: <Widget>[
                _TimeField(controller: _hours, hint: 'ore', onChanged: _redraw),
                const SizedBox(width: 10),
                _TimeField(
                    controller: _minutes, hint: 'min', onChanged: _redraw),
                const SizedBox(width: 10),
                _TimeField(
                    controller: _seconds, hint: 'sec', onChanged: _redraw),
              ],
            ),

            const SizedBox(height: 20),
            Text('QUANDO', style: AppText.label.copyWith(color: p.inkFaint)),
            const SizedBox(height: 8),
            InsetList(
              children: <Widget>[
                AppListRow(
                  title: 'Data',
                  value: formatDateShort(_date),
                  onTap: _pickDate,
                ),
                AppListRow(
                  title: 'Era una gara',
                  subtitle: _wasRace
                      ? 'Vale il massimo: in gara ci si spreme davvero'
                      : 'Test o prova in allenamento: vale un po\' meno',
                  showChevron: false,
                  trailing: Switch.adaptive(
                    value: _wasRace,
                    onChanged: (bool value) => setState(() => _wasRace = value),
                  ),
                ),
              ],
            ),

            if (problem != null) ...<Widget>[
              const SizedBox(height: 14),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Icon(Icons.error_outline, size: 18, color: p.orange),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      problem,
                      style: AppText.caption.copyWith(color: p.orange),
                    ),
                  ),
                ],
              ),
            ],

            const SizedBox(height: 18),
            SizedBox(
              height: 54,
              child: FilledButton(
                onPressed: problem != null ? null : _save,
                style: FilledButton.styleFrom(
                  backgroundColor: p.accent,
                  foregroundColor: p.onAccent,
                  disabledBackgroundColor: p.separator,
                  disabledForegroundColor: p.inkFaint,
                ),
                child: const Text('Salva'),
              ),
            ),
            if (editing)
              Center(
                child: TextButton(
                  onPressed: () =>
                      Navigator.of(context).pop(const _BestResult(null)),
                  child: Text('Elimina', style: TextStyle(color: p.red)),
                ),
              ),
          ],
        ),
      ),
    );
  }

  void _redraw() => setState(() {});

  Future<void> _pickDate() async {
    final DateTime now = DateTime.now();
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(now.year - 20),
      lastDate: now,
      helpText: 'Quando l\'hai fatto',
    );
    if (picked == null) return;
    setState(() => _date = picked);
  }

  void _save() {
    final PersonalBest best = PersonalBest(
      meters: _meters,
      seconds: _totalSeconds,
      date: _date,
      wasRace: _wasRace,
    );
    Navigator.of(context).pop(_BestResult(best));
  }
}

class _TimeField extends StatelessWidget {
  const _TimeField({
    required this.controller,
    required this.hint,
    required this.onChanged,
  });

  final TextEditingController controller;
  final String hint;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    final AppPalette p = AppPalette.of(context);
    return Expanded(
      child: TextField(
        controller: controller,
        keyboardType: TextInputType.number,
        inputFormatters: <TextInputFormatter>[
          FilteringTextInputFormatter.digitsOnly,
          LengthLimitingTextInputFormatter(2),
        ],
        textAlign: TextAlign.center,
        style: AppText.number(22, color: p.ink),
        onChanged: (String _) => onChanged(),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: AppText.body.copyWith(color: p.inkFaint),
          filled: true,
          fillColor: p.surface,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppRadius.small),
            borderSide: BorderSide.none,
          ),
        ),
      ),
    );
  }
}

/// Riquadro grigio di spiegazione, come quelli sotto i gruppi nelle
/// impostazioni di iOS.
class _Note extends StatelessWidget {
  const _Note({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final AppPalette p = AppPalette.of(context);
    return AppCard(
      padding: const EdgeInsets.fromLTRB(14, 13, 15, 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(icon, size: 18, color: p.inkFaint),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: AppText.caption.copyWith(color: p.inkFaint),
            ),
          ),
        ],
      ),
    );
  }
}
