import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../app/routes.dart';
import '../app/tokens.dart';
import '../models/training_plan.dart';
import '../providers/plan_provider.dart';
import '../utils/formatters.dart';
import '../widgets/app_card.dart';
import '../widgets/empty_state.dart';
import '../widgets/inset_list.dart';
import '../widgets/metric_display.dart';

/// Il piano di allenamento: settimana per settimana, seduta per seduta.
class PlanScreen extends StatefulWidget {
  const PlanScreen({super.key});

  @override
  State<PlanScreen> createState() => _PlanScreenState();
}

class _PlanScreenState extends State<PlanScreen> {
  /// Settimana mostrata. `null` = quella di oggi.
  int? _shownWeek;

  @override
  Widget build(BuildContext context) {
    final PlanProvider plans = context.watch<PlanProvider>();
    final AppPalette p = AppPalette.of(context);
    final TrainingPlan? plan = plans.plan;

    if (plan == null || plan.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('Piano')),
        body: EmptyState(
          icon: Icons.calendar_month_outlined,
          title: 'Nessun piano attivo',
          message: 'Un piano ti dice cosa fare ogni giorno, con i passi '
              'calcolati sulla tua forma di adesso.',
          actionLabel: 'Crea un piano',
          onAction: () => Navigator.of(context).pushNamed(AppRoutes.planSetup),
        ),
      );
    }

    final DateTime today = DateTime.now();
    final int currentNumber = plan.currentWeekNumber(today) ?? 1;
    final int shown = (_shownWeek ?? currentNumber)
        .clamp(1, plan.weeks.length);
    final PlanWeek week = plan.weeks[shown - 1];

    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 44,
        backgroundColor: p.background,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        actions: <Widget>[
          IconButton(
            tooltip: 'Aggiungi una gara',
            icon: Icon(Icons.flag_outlined, color: p.blue),
            onPressed: () => _addRace(context, plans),
          ),
          IconButton(
            tooltip: 'Elimina il piano',
            icon: Icon(Icons.delete_outline, color: p.red),
            onPressed: () => _confirmDelete(context, plans),
          ),
        ],
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
            Text(
              plan.config.goal.label,
              style: AppText.largeTitle.copyWith(color: p.ink),
            ),
            const SizedBox(height: 5),
            Text(
              'Settimana $currentNumber di ${plan.weeks.length}  ·  '
              '${plan.config.daysPerWeek} giorni a settimana',
              style: AppText.caption.copyWith(color: p.inkFaint),
            ),
            const SizedBox(height: 16),

            _WeekHeader(
              week: week,
              isCurrent: week.number == currentNumber,
              total: plan.weeks.length,
              onPrevious: shown > 1
                  ? () => setState(() => _shownWeek = shown - 1)
                  : null,
              onNext: shown < plan.weeks.length
                  ? () => setState(() => _shownWeek = shown + 1)
                  : null,
            ),

            const SizedBox(height: 14),
            for (final PlannedSession session in week.sessions)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _SessionCard(
                  session: session,
                  isToday: _sameDay(session.date, today),
                  onStart: session.hasWorkout
                      ? () => Navigator.of(context).pushNamed(
                            AppRoutes.run,
                            arguments: session.workout,
                          )
                      : () => Navigator.of(context).pushNamed(AppRoutes.run),
                ),
              ),

            if (plan.config.races.isNotEmpty) ...<Widget>[
              const SectionTitle('Gare in calendario'),
              InsetList(
                children: <Widget>[
                  for (final RaceEvent race in plan.config.races)
                    AppListRow(
                      title: race.name,
                      subtitle:
                          '${formatDistanceAuto(race.meters)}  ·  ${formatDateShort(race.date)}',
                      showChevron: false,
                      trailing: IconButton(
                        tooltip: 'Togli',
                        icon: Icon(Icons.close, size: 18, color: p.inkFaint),
                        onPressed: () => plans.removeRace(race.id),
                      ),
                    ),
                ],
              ),
            ],

            const SectionTitle('Tutto il piano'),
            InsetList(
              children: <Widget>[
                for (final PlanWeek w in plan.weeks)
                  AppListRow(
                    title: 'Settimana ${w.number}  ·  ${w.phase.label}',
                    subtitle: w.note ??
                        '${w.sessions.length} sedute, '
                            '${w.qualityCount} di qualita\'',
                    value: w.plannedKm.toStringAsFixed(0),
                    valueColor:
                        w.number == currentNumber ? p.accent : p.inkSoft,
                    onTap: () => setState(() => _shownWeek = w.number),
                  ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.only(left: 4, top: 8),
              child: Text(
                'I numeri a destra sono i chilometri della settimana. '
                'Totale del piano: ${plan.totalKm.toStringAsFixed(0)} km.',
                style: AppText.caption.copyWith(color: p.inkFaint),
              ),
            ),

            const SizedBox(height: 16),
            AppCard(
              padding: const EdgeInsets.fromLTRB(14, 13, 15, 14),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Icon(Icons.info_outline, size: 18, color: p.inkFaint),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Il piano e\' un\'ipotesi scritta il '
                      '${formatDateShort(plan.config.createdAt)}: va corretto '
                      'in corsa. Se una seduta ti trova stanco, spostala o '
                      'accorciala. Se salta fuori una gara, aggiungila con la '
                      'bandierina qui sopra: il piano alleggerisce prima e '
                      'recupera dopo.',
                      style: AppText.caption.copyWith(color: p.inkFaint),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  Future<void> _confirmDelete(
    BuildContext context,
    PlanProvider plans,
  ) async {
    final bool? ok = await showDialog<bool>(
      context: context,
      builder: (BuildContext ctx) => AlertDialog(
        title: const Text('Eliminare il piano?'),
        content: const Text(
            'Le corse che hai gia\' registrato restano: si cancella solo il '
            'programma.'),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Annulla'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Elimina'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await plans.clear();
  }

  Future<void> _addRace(BuildContext context, PlanProvider plans) async {
    final RaceEvent? race = await showDialog<RaceEvent>(
      context: context,
      builder: (BuildContext ctx) => const _AddRaceDialog(),
    );
    if (race == null) return;
    await plans.addRace(race);
    if (!mounted) return;
    setState(() => _shownWeek = null);
  }
}

/// Intestazione della settimana mostrata, con le frecce per scorrere.
class _WeekHeader extends StatelessWidget {
  const _WeekHeader({
    required this.week,
    required this.isCurrent,
    required this.total,
    required this.onPrevious,
    required this.onNext,
  });

  final PlanWeek week;
  final bool isCurrent;
  final int total;
  final VoidCallback? onPrevious;
  final VoidCallback? onNext;

  @override
  Widget build(BuildContext context) {
    final AppPalette p = AppPalette.of(context);

    return AppCard(
      padding: const EdgeInsets.fromLTRB(8, 12, 8, 14),
      child: Column(
        children: <Widget>[
          Row(
            children: <Widget>[
              IconButton(
                onPressed: onPrevious,
                icon: const Icon(Icons.chevron_left),
                color: p.inkSoft,
                disabledColor: p.separator,
              ),
              Expanded(
                child: Column(
                  children: <Widget>[
                    Text(
                      isCurrent
                          ? 'Questa settimana'
                          : 'Settimana ${week.number} di $total',
                      style: AppText.title.copyWith(color: p.ink, fontSize: 17),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${week.phase.label}  ·  '
                      '${week.plannedKm.toStringAsFixed(0)} km',
                      style: AppText.caption.copyWith(color: p.inkFaint),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: onNext,
                icon: const Icon(Icons.chevron_right),
                color: p.inkSoft,
                disabledColor: p.separator,
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Column(
              children: <Widget>[
                Text(
                  week.phase.description,
                  textAlign: TextAlign.center,
                  style: AppText.caption.copyWith(color: p.inkSoft),
                ),
                if (week.note != null) ...<Widget>[
                  const SizedBox(height: 8),
                  StatusPill(
                    text: week.note!,
                    dotColor: p.orange,
                    background: p.surfaceElevated,
                    textColor: p.inkSoft,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Una seduta del piano.
class _SessionCard extends StatelessWidget {
  const _SessionCard({
    required this.session,
    required this.isToday,
    required this.onStart,
  });

  final PlannedSession session;
  final bool isToday;
  final VoidCallback onStart;

  static const List<String> _weekdays = <String>[
    'LUN',
    'MAR',
    'MER',
    'GIO',
    'VEN',
    'SAB',
    'DOM',
  ];

  @override
  Widget build(BuildContext context) {
    final AppPalette p = AppPalette.of(context);

    Color accentFor(SessionKind kind) {
      switch (kind) {
        case SessionKind.race:
          return p.red;
        case SessionKind.long:
          return p.blue;
        case SessionKind.easy:
          return p.inkFaint;
        default:
          return p.accent;
      }
    }

    final Color tone = accentFor(session.kind);

    return AppCard(
      color: isToday ? p.surfaceElevated : null,
      padding: const EdgeInsets.fromLTRB(14, 13, 14, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Container(
                width: 44,
                padding: const EdgeInsets.symmetric(vertical: 4),
                decoration: BoxDecoration(
                  color: tone,
                  borderRadius: BorderRadius.circular(AppRadius.small),
                ),
                alignment: Alignment.center,
                child: Text(
                  _weekdays[(session.date.weekday - 1).clamp(0, 6)],
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.6,
                    color: Colors.white,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      session.title,
                      style: AppText.row.copyWith(
                        color: p.ink,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${session.kind.label}'
                      '${session.distanceMeters == null ? '' : '  ·  ${formatDistanceAuto(session.distanceMeters!)}'}',
                      style: AppText.caption.copyWith(color: p.inkFaint),
                    ),
                  ],
                ),
              ),
              if (isToday)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                  decoration: BoxDecoration(
                    color: p.accent,
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                  ),
                  child: Text(
                    'OGGI',
                    style: AppText.label.copyWith(color: p.onAccent),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            session.detail,
            style: AppText.caption.copyWith(color: p.inkSoft),
          ),
          if (session.kind != SessionKind.race) ...<Widget>[
            const SizedBox(height: 12),
            SizedBox(
              height: 44,
              child: OutlinedButton.icon(
                onPressed: onStart,
                icon: Icon(
                  session.hasWorkout
                      ? Icons.play_arrow_rounded
                      : Icons.directions_run_rounded,
                  size: 20,
                ),
                label: Text(
                  session.hasWorkout
                      ? 'Esegui questa seduta'
                      : 'Parti con una corsa libera',
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Finestra per aggiungere una gara al calendario.
class _AddRaceDialog extends StatefulWidget {
  const _AddRaceDialog();

  @override
  State<_AddRaceDialog> createState() => _AddRaceDialogState();
}

class _AddRaceDialogState extends State<_AddRaceDialog> {
  final TextEditingController _name = TextEditingController();
  double _meters = 10000;
  DateTime _date = DateTime.now().add(const Duration(days: 14));

  static const List<double> _distances = <double>[
    5000,
    10000,
    21097.5,
    42195,
  ];

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AppPalette p = AppPalette.of(context);

    return AlertDialog(
      title: const Text('Aggiungi una gara'),
      content: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            TextField(
              controller: _name,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'Nome della gara',
                hintText: 'es. Corrida di paese',
              ),
            ),
            const SizedBox(height: 18),
            Text('Distanza', style: AppText.label.copyWith(color: p.inkFaint)),
            const SizedBox(height: 6),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: <Widget>[
                for (final double meters in _distances)
                  ChoiceChip(
                    label: Text(formatDistanceAuto(meters)),
                    selected: _meters == meters,
                    onSelected: (_) => setState(() => _meters = meters),
                  ),
              ],
            ),
            const SizedBox(height: 18),
            Text('Data', style: AppText.label.copyWith(color: p.inkFaint)),
            const SizedBox(height: 6),
            OutlinedButton.icon(
              onPressed: _pickDate,
              icon: const Icon(Icons.calendar_today_outlined, size: 18),
              label: Text(formatDateShort(_date)),
            ),
          ],
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Annulla'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(
            RaceEvent(
              name: _name.text.trim().isEmpty
                  ? 'Gara ${formatDistanceAuto(_meters)}'
                  : _name.text.trim(),
              date: _date,
              meters: _meters,
            ),
          ),
          child: const Text('Aggiungi'),
        ),
      ],
    );
  }

  Future<void> _pickDate() async {
    final DateTime now = DateTime.now();
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: now.subtract(const Duration(days: 1)),
      lastDate: now.add(const Duration(days: 365)),
    );
    if (picked == null || !mounted) return;
    setState(() => _date = picked);
  }
}
