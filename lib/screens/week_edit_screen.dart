import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../app/tokens.dart';
import '../models/training_plan.dart';
import '../models/weekly_availability.dart';
import '../providers/plan_provider.dart';
import '../services/plan_service.dart';
import '../utils/formatters.dart';
import '../widgets/app_card.dart';
import '../widgets/day_time_row.dart';

/// Cambia i giorni e i tempi di UNA settimana sola.
///
/// DA DOVE NASCE QUESTA SCHERMATA
/// ------------------------------
/// La settimana si dichiara una volta, quando si crea il piano, e va bene per
/// generarlo. Ma chi lavora su turni non ha una settimana: ha dodici settimane
/// diverse. Il mercoledi' esce il turno della settimana dopo, e il lungo che il
/// piano ha messo di mercoledi' cade nel giorno del doppio turno.
///
/// Quello che succede a quel punto non e' "l'atleta si adatta": e' che quella
/// settimana viene saltata, e dopo due settimane saltate il piano non si guarda
/// piu'. Il piano non si abbandona perche' e' troppo duro, si abbandona perche'
/// ha smesso di somigliare alla vita di chi lo segue.
///
/// COSA CAMBIA E COSA NO
/// ---------------------
/// Cambiano i giorni e i minuti di questa settimana, e quindi dove cadono le
/// sedute e quanto ci sta. NON cambiano: la fase, il volume previsto dalla
/// progressione, e soprattutto le altre settimane. Un turno diverso e' un
/// eccezione, non un trasloco.
class WeekEditScreen extends StatefulWidget {
  const WeekEditScreen({super.key, required this.weekNumber});

  /// Numero della settimana, da 1.
  final int weekNumber;

  @override
  State<WeekEditScreen> createState() => _WeekEditScreenState();
}

class _WeekEditScreenState extends State<WeekEditScreen> {
  static const PlanService _service = PlanService();

  WeeklyAvailability? _edited;
  bool _saving = false;

  /// La settimana su cui stiamo lavorando. Parte da quella in vigore per
  /// questa settimana (la sua eccezione, se ce l'ha, altrimenti la normale).
  WeeklyAvailability _availabilityFrom(PlanProvider plans) =>
      _edited ?? plans.availabilityForWeek(widget.weekNumber);

  @override
  Widget build(BuildContext context) {
    final PlanProvider plans = context.watch<PlanProvider>();
    final AppPalette p = AppPalette.of(context);
    final TrainingPlan? plan = plans.plan;
    final PlanConfig? config = plans.config;

    if (plan == null || config == null || widget.weekNumber > plan.weeks.length) {
      return Scaffold(
        appBar: AppBar(title: const Text('Settimana')),
        body: const Center(child: Text('Questa settimana non c\'e\' piu\'.')),
      );
    }

    final PlanWeek week = plan.weeks[widget.weekNumber - 1];
    final WeeklyAvailability availability = _availabilityFrom(plans);
    final WeeklyAvailability normale = config.effectiveAvailability;
    final bool changed = availability != normale;
    final bool wasChanged = config.isWeekChanged(widget.weekNumber);
    final bool enoughDays = availability.dayCount >= 3;

    // L'anteprima usa lo STESSO conto del generatore: se dicesse due qualita'
    // e poi il piano ne mettesse una, l'anteprima sarebbe peggio di niente.
    final int qualityWanted = _service.qualityWantedFor(
      phase: week.phase,
      dayCount: availability.dayCount,
      isDownWeek: _service.isDownWeek(widget.weekNumber - 1, week.phase),
    );
    final WeekSchedule schedule = _service.scheduleFor(
      availability,
      qualityWanted: qualityWanted,
    );

    return Scaffold(
      appBar: AppBar(title: Text('Settimana ${week.number}')),
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
                    'Dal ${formatDateShort(week.startDate)} '
                    'al ${formatDateShort(week.endDate)}',
                    style: AppText.title.copyWith(color: p.ink, fontSize: 17),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '${week.phase.label}  ·  '
                    '${week.targetKm.toStringAsFixed(0)} km previsti',
                    style: AppText.caption.copyWith(color: p.inkFaint),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Se questa settimana hai turni diversi, cambia qui i '
                    'giorni e i tempi. Vale solo per questa settimana: le '
                    'altre non si muovono, e la fase e il volume restano '
                    'quelli della progressione.',
                    style: AppText.body.copyWith(color: p.inkSoft),
                  ),
                ],
              ),
            ),

            const SectionTitle('Questa settimana'),
            AppCard(
              padding: const EdgeInsets.fromLTRB(14, 6, 10, 6),
              child: Column(
                children: <Widget>[
                  for (int day = 1; day <= 7; day++)
                    DayTimeRow(
                      weekday: day,
                      minutes: availability.minutesOn(day),
                      isLong:
                          schedule.longDay == day && availability.runsOn(day),
                      isQuality: schedule.qualityDays.contains(day),
                      onChanged: (int minutes) => setState(() {
                        _edited = availability.withDay(day, minutes);
                      }),
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(left: 4, top: 8),
              child: Text(
                _explanation(
                  schedule: schedule,
                  enoughDays: enoughDays,
                  qualityWanted: qualityWanted,
                ),
                style: AppText.caption.copyWith(color: p.inkFaint),
              ),
            ),

            if (changed) ...<Widget>[
              const SectionTitle('Rispetto alla settimana normale'),
              AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    for (final String riga in _differences(normale, availability))
                      Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Text(
                          riga,
                          style: AppText.body.copyWith(color: p.inkSoft),
                        ),
                      ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 18),
            SizedBox(
              height: 52,
              child: FilledButton(
                onPressed: _saving || !enoughDays || !changed
                    ? null
                    : () => _save(plans, availability),
                style: FilledButton.styleFrom(
                  backgroundColor: p.accent,
                  foregroundColor: p.onAccent,
                ),
                child: Text(
                  _saving ? 'Ricalcolo...' : 'Applica a questa settimana',
                ),
              ),
            ),
            if (!enoughDays)
              Padding(
                padding: const EdgeInsets.only(left: 4, top: 8),
                child: Text(
                  'Servono almeno tre giorni di corsa. Se questa settimana ne '
                  'hai due, e\' una settimana di riposo: non c\'e\' niente da '
                  'ricalcolare.',
                  style: AppText.caption.copyWith(color: p.orange),
                ),
              ),

            if (wasChanged) ...<Widget>[
              const SizedBox(height: 12),
              SizedBox(
                height: 50,
                child: OutlinedButton.icon(
                  onPressed: _saving ? null : () => _reset(plans),
                  icon: const Icon(Icons.undo, size: 18),
                  label: const Text('Rimetti come le altre settimane'),
                ),
              ),
            ],

            const SizedBox(height: 20),
            AppCard(
              child: Text(
                'Cambiare una settimana non riscrive il piano: il piano viene '
                'ricalcolato ogni volta dai parametri, e questa settimana '
                'diventa uno di quei parametri. Per questo si puo\' tornare '
                'indietro in qualunque momento senza perdere niente.',
                style: AppText.caption.copyWith(color: p.inkFaint),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Dove cadranno le sedute con i giorni scelti, in una riga.
  String _explanation({
    required WeekSchedule schedule,
    required bool enoughDays,
    required int qualityWanted,
  }) {
    if (!enoughDays) {
      return 'Metti il tempo che hai, giorno per giorno. Il tempo e\' quello '
          'per correre, non il tempo libero.';
    }

    final String lungo = WeeklyAvailability.dayName(schedule.longDay);
    if (schedule.qualityDays.isEmpty) {
      return 'Il lungo cade $lungo, dove hai piu\' tempo. '
          '${qualityWanted == 0 ? 'Questa settimana non c\'e\' qualita\'.' : 'Non c\'e\' spazio per la qualita\' con questi giorni.'}';
    }

    final String qualita =
        schedule.qualityDays.map(WeeklyAvailability.dayName).join(' e ');
    return 'Il lungo cade $lungo, dove hai piu\' tempo. La qualita\' va '
        '$qualita: mai attaccata fra loro, mai il giorno prima del lungo.';
  }

  /// Cosa cambia rispetto alla settimana normale, giorno per giorno.
  ///
  /// Serve perche' dopo dieci tocchi del piu' e del meno non si ricorda piu'
  /// cosa si e' cambiato, e si rischia di applicare una settimana sbagliata.
  List<String> _differences(
    WeeklyAvailability normale,
    WeeklyAvailability ora,
  ) {
    final List<String> out = <String>[];
    for (int d = 1; d <= 7; d++) {
      final int prima = normale.minutesOn(d);
      final int adesso = ora.minutesOn(d);
      if (prima == adesso) continue;
      final String nome = WeeklyAvailability.dayName(d);
      if (prima < WeeklyAvailability.minUsefulMinutes) {
        out.add('$nome: si aggiunge '
            '${WeeklyAvailability.formatMinutes(adesso)}');
      } else if (adesso < WeeklyAvailability.minUsefulMinutes) {
        out.add('$nome: riposo invece di '
            '${WeeklyAvailability.formatMinutes(prima)}');
      } else {
        out.add('$nome: ${WeeklyAvailability.formatMinutes(adesso)} '
            'invece di ${WeeklyAvailability.formatMinutes(prima)}');
      }
    }
    if (out.isEmpty) out.add('Niente: e\' identica alla settimana normale.');
    return out;
  }

  Future<void> _save(
    PlanProvider plans,
    WeeklyAvailability availability,
  ) async {
    setState(() => _saving = true);
    final bool ok = await plans.setWeekAvailability(
      widget.weekNumber,
      availability,
    );
    if (!mounted) return;
    setState(() => _saving = false);
    if (!ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(plans.errorMessage ?? 'Non salvata.'),
        ),
      );
      return;
    }
    Navigator.of(context).pop();
  }

  Future<void> _reset(PlanProvider plans) async {
    setState(() => _saving = true);
    await plans.resetWeek(widget.weekNumber);
    if (!mounted) return;
    setState(() {
      _edited = null;
      _saving = false;
    });
    Navigator.of(context).pop();
  }
}
