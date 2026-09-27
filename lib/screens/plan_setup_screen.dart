import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../app/tokens.dart';
import '../models/training_plan.dart';
import '../providers/activity_provider.dart';
import '../models/estimate.dart';
import '../providers/plan_provider.dart';
import '../services/run_index_engine.dart';
import '../services/stats_service.dart';
import '../widgets/app_card.dart';
import '../widgets/inset_list.dart';

/// Impostazione di un nuovo piano: obiettivo, durata, giorni, punto di
/// partenza.
class PlanSetupScreen extends StatefulWidget {
  const PlanSetupScreen({super.key});

  @override
  State<PlanSetupScreen> createState() => _PlanSetupScreenState();
}

class _PlanSetupScreenState extends State<PlanSetupScreen> {
  RaceGoal _goal = RaceGoal.tenK;
  int _weeks = RaceGoal.tenK.defaultWeeks;
  int _days = 4;
  double _startKm = 25;
  bool _startKmTouched = false;
  bool _saving = false;

  @override
  Widget build(BuildContext context) {
    final AppPalette p = AppPalette.of(context);
    final ActivityProvider activities = context.watch<ActivityProvider>();
    final RunningStats stats = activities.stats;

    // Il punto di partenza si propone dai chilometri che stai giá facendo:
    // costruire un piano dal nulla e' il modo migliore per abbandonarlo.
    if (!_startKmTouched) {
      final double recent = stats.lastFourWeeksKm / 4.0;
      final double suggested = recent > 5 ? recent : stats.weekKm;
      if (suggested > 5) _startKm = double.parse(suggested.toStringAsFixed(0));
    }

    // I passi del piano devono venire dallo STESSO indice che si vede nella
    // schermata Forma.
    //
    // Prima questa schermata usava una stima vecchia, ricavata solo dai
    // record misurati col GPS: non sapeva niente dei personali dichiarati a
    // mano ne' delle gare. Risultato: la Forma diceva 45,4 e il piano veniva
    // costruito su 36, cioe' con i ritmi di un altro atleta. Due numeri per
    // la stessa cosa nella stessa app, e quello sbagliato era proprio quello
    // che decideva gli allenamenti.
    final RunIndexResult forma = activities.runIndex;
    final Estimate<double>? indice = forma.index;
    final bool ready = indice != null;

    return Scaffold(
      appBar: AppBar(title: const Text('Nuovo piano')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.screenSide,
            8,
            AppSpacing.screenSide,
            32,
          ),
          children: <Widget>[
            if (!ready) ...<Widget>[
              AppCard(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Icon(Icons.warning_amber_rounded, size: 22, color: p.orange),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        forma.explanation,
                        style: AppText.body.copyWith(color: p.inkSoft),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
            ],

            const SectionTitle('Obiettivo'),
            InsetList(
              children: <Widget>[
                for (final RaceGoal goal in RaceGoal.values)
                  AppListRow(
                    title: goal.label,
                    subtitle: goal == RaceGoal.fitness
                        ? 'Senza gara: volume e qualita\' senza scarico finale'
                        : 'Consigliate ${goal.defaultWeeks} settimane',
                    showChevron: false,
                    trailing: Icon(
                      _goal == goal
                          ? Icons.radio_button_checked
                          : Icons.radio_button_unchecked,
                      size: 22,
                      color: _goal == goal ? p.accent : p.separator,
                    ),
                    onTap: () => setState(() {
                      _goal = goal;
                      _weeks = goal.defaultWeeks;
                    }),
                  ),
              ],
            ),

            const SectionTitle('Durata'),
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      Expanded(
                        child: Text(
                          '$_weeks settimane',
                          style: AppText.title.copyWith(color: p.ink),
                        ),
                      ),
                      Text(
                        'min ${_goal.minWeeks}',
                        style: AppText.caption.copyWith(color: p.inkFaint),
                      ),
                    ],
                  ),
                  Slider(
                    value: _weeks
                        .clamp(_goal.minWeeks, _goal.maxWeeks)
                        .toDouble(),
                    min: _goal.minWeeks.toDouble(),
                    max: _goal.maxWeeks.toDouble(),
                    divisions: _goal.maxWeeks - _goal.minWeeks,
                    label: '$_weeks',
                    activeColor: p.accent,
                    onChanged: (double value) =>
                        setState(() => _weeks = value.round()),
                  ),
                ],
              ),
            ),

            const SectionTitle('Giorni di corsa a settimana'),
            AppCard(
              child: Row(
                children: <Widget>[
                  for (final int days in <int>[3, 4, 5, 6])
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 3),
                        child: _DayChip(
                          days: days,
                          selected: _days == days,
                          onTap: () => setState(() => _days = days),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(left: 4, top: 8),
              child: Text(
                'Qualita\' il martedi\' e il giovedi\', lungo la domenica. '
                'Il resto sono corse lente.',
                style: AppText.caption.copyWith(color: p.inkFaint),
              ),
            ),

            const SectionTitle('Da quanti km parti'),
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    '${_startKm.toStringAsFixed(0)} km a settimana',
                    style: AppText.title.copyWith(color: p.ink),
                  ),
                  Slider(
                    value: _startKm.clamp(10.0, 80.0),
                    min: 10,
                    max: 80,
                    divisions: 70,
                    label: '${_startKm.toStringAsFixed(0)} km',
                    activeColor: p.accent,
                    onChanged: (double value) => setState(() {
                      _startKmTouched = true;
                      _startKm = value.roundToDouble();
                    }),
                  ),
                  Text(
                    'Il piano cresce da qui, al massimo del 55% fino al picco. '
                    'Metti quello che fai davvero adesso, non quello che '
                    'vorresti fare.',
                    style: AppText.caption.copyWith(color: p.inkFaint),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),
            SizedBox(
              height: 54,
              child: FilledButton(
                onPressed: (ready && !_saving)
                    ? () => _create(indice!.value)
                    : null,
                style: FilledButton.styleFrom(
                  backgroundColor: p.accent,
                  foregroundColor: p.onAccent,
                  disabledBackgroundColor: p.separator,
                  disabledForegroundColor: p.inkFaint,
                ),
                child: const Text('Crea il piano'),
              ),
            ),
            if (ready) ...<Widget>[
              const SizedBox(height: 10),
              Text(
                'Le sedute useranno i passi del tuo indice di forma '
                '${indice!.value.toStringAsFixed(1)} (fiducia '
                '${indice.confidenceLabel}). Se migliori, potrai rifare il '
                'piano con i passi aggiornati.',
                style: AppText.caption.copyWith(color: p.inkFaint),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _create(double vdot) async {
    setState(() => _saving = true);

    final PlanProvider plans = context.read<PlanProvider>();
    final DateTime start = StatsService.startOfWeek(DateTime.now());

    final PlanConfig config = PlanConfig(
      goal: _goal,
      startDate: start,
      weeks: _weeks,
      daysPerWeek: _days,
      startWeeklyKm: _startKm,
      vdot: vdot,
    );

    final bool ok = await plans.create(config);
    if (!mounted) return;
    setState(() => _saving = false);

    if (!ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(plans.errorMessage ?? 'Creazione non riuscita.'),
        ),
      );
      return;
    }
    Navigator.of(context).pop();
  }
}

class _DayChip extends StatelessWidget {
  const _DayChip({
    required this.days,
    required this.selected,
    required this.onTap,
  });

  final int days;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final AppPalette p = AppPalette.of(context);
    return Material(
      color: selected ? p.accent : p.surfaceElevated,
      borderRadius: BorderRadius.circular(AppRadius.small + 2),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: SizedBox(
          height: 52,
          child: Center(
            child: Text(
              '$days',
              style: AppText.number(
                20,
                color: selected ? p.onAccent : p.ink,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
