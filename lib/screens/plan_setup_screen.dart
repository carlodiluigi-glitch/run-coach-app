import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../app/tokens.dart';
import '../models/training_plan.dart';
import '../models/weekly_availability.dart';
import '../providers/activity_provider.dart';
import '../models/estimate.dart';
import '../providers/plan_provider.dart';
import '../providers/settings_provider.dart';
import '../services/plan_service.dart';
import '../services/run_index_engine.dart';
import '../services/stats_service.dart';
import '../widgets/app_card.dart';
import '../widgets/day_time_row.dart';
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

  /// Da quale fase parte il piano. `null` = non l'ha ancora scelta, quindi
  /// vale la proposta dell'app.
  PlanPhase? _startPhaseChosen;
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

    // I giorni si cercano in tre posti, in quest'ordine:
    //
    //  1. le impostazioni, dove vengono salvati alla creazione di un piano:
    //     e' la settimana dell'atleta, e resta anche senza piano;
    //  2. il piano attivo, per chi ne ha uno creato prima che i giorni
    //     finissero nelle impostazioni;
    //  3. la proposta standard, per chi non li ha mai dichiarati.
    //
    // Si aspetta che entrambi siano stati letti da disco: al primo disegno
    // della schermata possono non esserlo ancora, e marcare "caricato" li'
    // vorrebbe dire perdere i giorni per sempre.
    final SettingsProvider settingsForLoad = context.watch<SettingsProvider>();
    final PlanProvider plansForLoad = context.watch<PlanProvider>();
    if (!_availabilityLoaded &&
        settingsForLoad.isLoaded &&
        plansForLoad.isLoaded) {
      _availabilityLoaded = true;
      final WeeklyAvailability? salvata =
          settingsForLoad.settings.weeklyAvailability ??
              plansForLoad.plan?.config.availability;
      if (salvata != null && !salvata.isEmpty) {
        _availabilityOrNull = salvata;
      }
    }

    // Il calendario si vede mentre lo si costruisce: due sedute di qualita' e'
    // il caso piu' carico, quindi mostra dove finirebbero nel peggiore dei
    // casi. Ricalcolato a ogni tocco, cosi' si capisce subito l'effetto di
    // aggiungere o togliere un giorno.
    final WeekSchedule schedule =
        _planService.scheduleFor(_availability, qualityWanted: 2);

    final PlanPhase suggerita = _suggestedStartPhase();
    final PlanPhase startPhase = _startPhaseChosen ?? suggerita;

    // Il punto di partenza si propone dai chilometri che stai gia' facendo:
    // costruire un piano dal nulla e' il modo migliore per abbandonarlo.
    // Ma si propone solo se l'archivio ne sa abbastanza: vedi
    // _propostaKmSettimanali.
    final double? propostaKm = stats.suggestedWeeklyKm;
    if (!_startKmTouched && propostaKm != null) {
      _startKm = double.parse(propostaKm.toStringAsFixed(0));
    }
    final bool archivioCorto = propostaKm == null;

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
                        ? 'Senza gara: niente fasi, cicli di quattro '
                            'settimane che crescono'
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
                    DayTimeRow(
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

            if (_goal != RaceGoal.fitness) ...<Widget>[
              const SectionTitle('Da dove parti'),
              InsetList(
                children: <Widget>[
                  for (final PlanPhase phase in PlanPhaseInfo.startable)
                    AppListRow(
                      title: phase.label,
                      subtitle: phase.startHint,
                      showChevron: false,
                      trailing: Icon(
                        startPhase == phase
                            ? Icons.radio_button_checked
                            : Icons.radio_button_unchecked,
                        size: 22,
                        color: startPhase == phase ? p.accent : p.separator,
                      ),
                      onTap: () =>
                          setState(() => _startPhaseChosen = phase),
                    ),
                ],
              ),
              Padding(
                padding: const EdgeInsets.only(left: 4, top: 8),
                child: Text(
                  _startPhaseNote(suggerita, startPhase),
                  style: AppText.caption.copyWith(color: p.inkFaint),
                ),
              ),
            ],

            if (_goal == RaceGoal.fitness) ...<Widget>[
              const SizedBox(height: 18),
              AppCard(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Icon(Icons.all_inclusive, size: 18, color: p.inkFaint),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Senza una gara non ci sono fasi: tutte le settimane '
                        'hanno la stessa struttura, due qualita\' che '
                        'ruotano e il lungo. Ogni quarta settimana si '
                        'scarica. Non e\' una versione ridotta del piano: e\' '
                        'che una fase serve ad arrivare in forma un giorno '
                        'preciso, e quel giorno qui non c\'e\'.',
                        style: AppText.caption.copyWith(color: p.inkFaint),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            const SectionTitle('Da quanti km parti'),
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    '${_startKm.clamp(10.0, 80.0).toStringAsFixed(0)} km '
                    'a settimana',
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
                    archivioCorto
                        ? 'Non ho abbastanza settimane registrate per '
                            'proporti un numero, quindi mettilo tu: quanti '
                            'km corri di solito in una settimana. Da questo '
                            'nascono il volume del piano e quanto lavoro '
                            'forte ci sta dentro, quindi vale la pena '
                            'pensarci un secondo.'
                        : 'Proposto dalle tue settimane registrate. Il piano '
                            'cresce da qui, al massimo del 55% fino al picco. '
                            'Metti quello che fai davvero adesso, non quello '
                            'che vorresti fare.',
                    style: AppText.caption.copyWith(
                      color: archivioCorto ? p.orange : p.inkFaint,
                    ),
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

  /// Quale fase proporre, guardando i chilometri dichiarati.
  ///
  /// E' una PROPOSTA, non una decisione: i chilometri dicono che la base c'e'
  /// stata, non che c'e' adesso. Chi rientra da uno stop ne faceva altrettanti
  /// prima. Per questo la riga resta toccabile.
  PlanPhase _suggestedStartPhase() {
    if (_startKm >= 45) return PlanPhase.build;
    return PlanPhase.base;
  }

  String _startPhaseNote(PlanPhase suggerita, PlanPhase scelta) {
    if (scelta == PlanPhase.base) {
      return 'La Costruzione serve a costruire il motore e la tolleranza al '
          'volume. Se quella base ce l\'hai gia\', e\' tempo tolto al lavoro '
          'che sposta i tempi.';
    }
    if (scelta == PlanPhase.build) {
      final String perche = suggerita == PlanPhase.build
          ? 'Con i chilometri che fai, la base ce l\'hai. '
          : '';
      return '${perche}Le settimane di Costruzione non si perdono: vanno a '
          'Sviluppo, cioe\' a soglia e ripetute.';
    }
    return 'Tutto sul passo della gara, con lo scarico finale. Ha senso solo '
        'se sei gia\' in forma: qui non si costruisce niente, si affila.';
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
    final SettingsProvider settings = context.read<SettingsProvider>();
    final DateTime start = StatsService.startOfWeek(DateTime.now());

    // La settimana dichiarata si ricorda anche se il piano venisse poi
    // cancellato: la prossima volta non va ridichiarata.
    await settings.setWeeklyAvailability(_availability);

    final PlanConfig config = PlanConfig(
      goal: _goal,
      startDate: start,
      weeks: _weeks,
      daysPerWeek: _availability.dayCount,
      availability: _availability,
      startPhase: _startPhaseChosen ?? _suggestedStartPhase(),
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
