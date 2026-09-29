import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../app/tokens.dart';
import '../models/training_plan.dart';
import '../models/weekly_availability.dart';
import '../providers/activity_provider.dart';
import '../models/estimate.dart';
import '../providers/plan_provider.dart';
import '../services/plan_service.dart';
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
  static const PlanService _planService = PlanService();

  RaceGoal _goal = RaceGoal.tenK;
  int _weeks = RaceGoal.tenK.defaultWeeks;
  double _startKm = 25;
  bool _startKmTouched = false;
  bool _saving = false;

  /// I giorni e i tempi disponibili.
  ///
  /// Si parte da quelli del piano precedente, se c'e': la settimana di chi
  /// corre cambia raramente, e ridichiararla ogni volta sarebbe una tassa.
  WeeklyAvailability? _availabilityOrNull;

  WeeklyAvailability get _availability =>
      _availabilityOrNull ?? WeeklyAvailability.suggested();

  set _availability(WeeklyAvailability next) => _availabilityOrNull = next;

  bool _availabilityLoaded = false;

  @override
  Widget build(BuildContext context) {
    final AppPalette p = AppPalette.of(context);
    final ActivityProvider activities = context.watch<ActivityProvider>();
    final RunningStats stats = activities.stats;

    if (!_availabilityLoaded) {
      _availabilityLoaded = true;
      final WeeklyAvailability? previous =
          context.read<PlanProvider>().plan?.config.availability;
      if (previous != null && !previous.isEmpty) {
        _availabilityOrNull = previous;
      }
    }

    // Il calendario si vede mentre lo si costruisce: due sedute di qualita' e'
    // il caso piu' carico, quindi mostra dove finirebbero nel peggiore dei
    // casi. Ricalcolato a ogni tocco, cosi' si capisce subito l'effetto di
    // aggiungere o togliere un giorno.
    final WeekSchedule schedule =
        _planService.scheduleFor(_availability, qualityWanted: 2);

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

    // Sotto i tre giorni non c'e' un piano da costruire: non basta a mettere
    // insieme un lungo, una qualita' e un lento.
    final bool enoughDays = _availability.dayCount >= 3;
    final bool ready = indice != null && enoughDays;

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

            const SectionTitle('Quando puoi correre'),
            AppCard(
              padding: const EdgeInsets.fromLTRB(14, 6, 10, 6),
              child: Column(
                children: <Widget>[
                  for (int day = 1; day <= 7; day++)
                    _DayTimeRow(
                      weekday: day,
                      minutes: _availability.minutesOn(day),
                      isLong: schedule.longDay == day &&
                          _availability.runsOn(day),
                      isQuality: schedule.qualityDays.contains(day),
                      onChanged: (int minutes) => setState(() {
                        _availability = _availability.withDay(day, minutes);
                      }),
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(left: 4, top: 8),
              child: Text(
                _scheduleExplanation(schedule),
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
            if (!enoughDays) ...<Widget>[
              const SizedBox(height: 10),
              Text(
                'Servono almeno tre giorni con del tempo sopra. Con due non '
                'si tiene insieme un piano: il lungo e la qualita\' '
                'finirebbero attaccati.',
                style: AppText.caption.copyWith(color: p.orange),
              ),
            ],
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

  /// Spiega, in una riga, dove cadranno le sedute con i giorni scelti.
  ///
  /// Serve perche' la regola non e' ovvia: il lungo non va la domenica per
  /// tradizione, va dove c'e' piu' tempo. Vedendolo cambiare mentre si tocca
  /// il piu' e il meno, la regola si capisce senza spiegarla.
  String _scheduleExplanation(WeekSchedule schedule) {
    if (schedule.runDays.length < 3) {
      return 'Metti il tempo che hai, giorno per giorno. Il tempo e\' quello '
          'per correre, non il tempo libero.';
    }

    final String lungo = WeeklyAvailability.dayName(schedule.longDay);
    final String qualita = schedule.qualityDays.isEmpty
        ? 'nessun giorno'
        : schedule.qualityDays
            .map(WeeklyAvailability.dayName)
            .join(' e ');

    return 'Il lungo cade $lungo, dove hai piu\' tempo. La qualita\' va '
        '$qualita: mai attaccata fra loro, mai il giorno prima del lungo. '
        'Gli altri giorni sono lenti, lunghi in proporzione al tempo che hai.';
  }

  Future<void> _create(double vdot) async {
    setState(() => _saving = true);

    final PlanProvider plans = context.read<PlanProvider>();
    final DateTime start = StatsService.startOfWeek(DateTime.now());

    final PlanConfig config = PlanConfig(
      goal: _goal,
      startDate: start,
      weeks: _weeks,
      daysPerWeek: _availability.dayCount,
      availability: _availability,
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

/// Una riga: il giorno e quanto tempo hai.
///
/// Niente slider e niente finestre: il meno sempre a sinistra, il piu' sempre
/// a destra, il valore in mezzo. La settimana si imposta in pochi tocchi
/// stando in piedi, che e' come verra' usata davvero.
class _DayTimeRow extends StatelessWidget {
  const _DayTimeRow({
    required this.weekday,
    required this.minutes,
    required this.isLong,
    required this.isQuality,
    required this.onChanged,
  });

  final int weekday;
  final int minutes;
  final bool isLong;
  final bool isQuality;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final AppPalette p = AppPalette.of(context);
    final bool runs = minutes >= WeeklyAvailability.minUsefulMinutes;

    String? ruolo;
    if (isLong) {
      ruolo = 'lungo';
    } else if (isQuality) {
      ruolo = 'qualita\'';
    }

    return SizedBox(
      height: 46,
      child: Row(
        children: <Widget>[
          SizedBox(
            width: 92,
            child: Text(
              WeeklyAvailability.dayName(weekday),
              style: AppText.body.copyWith(
                color: runs ? p.ink : p.inkFaint,
                fontWeight: runs ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
          ),
          if (ruolo != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
              decoration: BoxDecoration(
                color: p.accent.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(AppRadius.pill),
              ),
              child: Text(
                ruolo,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: p.accent,
                ),
              ),
            ),
          const Spacer(),
          IconButton(
            visualDensity: VisualDensity.compact,
            onPressed: minutes <= 0
                ? null
                : () => onChanged(
                    minutes - WeeklyAvailability.stepMinutes),
            icon: Icon(Icons.remove_circle_outline,
                size: 22, color: minutes <= 0 ? p.separator : p.inkSoft),
          ),
          SizedBox(
            width: 62,
            child: Text(
              WeeklyAvailability.formatMinutes(runs ? minutes : 0),
              textAlign: TextAlign.center,
              style: AppText.number(
                15,
                color: runs ? p.ink : p.inkFaint,
              ),
            ),
          ),
          IconButton(
            visualDensity: VisualDensity.compact,
            onPressed: minutes >= WeeklyAvailability.maxMinutes
                ? null
                : () => onChanged(minutes < WeeklyAvailability.minMinutes
                    ? WeeklyAvailability.minMinutes + 25
                    : minutes + WeeklyAvailability.stepMinutes),
            icon: Icon(Icons.add_circle_outline,
                size: 22,
                color: minutes >= WeeklyAvailability.maxMinutes
                    ? p.separator
                    : p.accent),
          ),
        ],
      ),
    );
  }
}
