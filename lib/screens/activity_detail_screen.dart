import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../app/routes.dart';
import '../app/tokens.dart';
import '../models/effort.dart';
import '../models/lap.dart';
import '../models/running_activity.dart';
import '../models/running_shoe.dart';
import '../models/workout_step.dart';
import '../providers/activity_provider.dart';
import '../providers/shoe_provider.dart';
import '../services/cadence.dart';
import '../services/calorie_estimate.dart';
import '../services/elevation_service.dart';
import '../services/pace_zone_engine.dart';
import '../services/run_profile.dart';
import '../services/records_service.dart';
import '../services/session_classifier.dart';
import '../utils/formatters.dart';
import '../widgets/app_card.dart';
import '../widgets/empty_state.dart';
import '../widgets/inset_list.dart';
import '../widgets/lap_table.dart';
import '../widgets/metric_card.dart';
import '../widgets/run_profile_chart.dart';
import '../widgets/route_shape.dart';

/// Dettaglio di una attivita' salvata.
class ActivityDetailScreen extends StatelessWidget {
  const ActivityDetailScreen({super.key, required this.activityId});

  final String activityId;

  @override
  Widget build(BuildContext context) {
    final ActivityProvider provider = context.watch<ActivityProvider>();
    final ShoeProvider shoes = context.watch<ShoeProvider>();

    final RunningActivity? activity = provider.byId(activityId);
    final AppPalette p = AppPalette.of(context);

    if (activity == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Attivita')),
        body: const EmptyState(
          icon: Icons.search_off,
          title: 'Attivita non trovata',
          message: 'Potrebbe essere stata eliminata.',
        ),
      );
    }

    final RunningShoe? shoe = shoes.byId(activity.shoeId);
    final List<DistanceRecord> held = provider.recordsHeldBy(activity.id);
    final double? carico = provider.loadOf(activity);
    final bool isWorkout = activity.type == ActivityType.workout;

    // Il passo dei soli tratti di lavoro. In una seduta a fasi e' il numero
    // che conta: il passo medio mescola ripetute e recuperi e non dice ne'
    // l'uno ne' l'altro. Nella soglia 2 x 1,6 km di prova: 6:05 di media,
    // 4:32 sul lavoro.
    double metriLavoro = 0;
    int secondiLavoro = 0;
    for (final Lap l in activity.laps) {
      if (l.stepKind != StepType.interval.storageKey) continue;
      metriLavoro += l.distanceMeters;
      secondiLavoro += l.durationSeconds;
    }
    final double? passoLavoro = (metriLavoro >= 200 && secondiLavoro > 0)
        ? secondiLavoro / (metriLavoro / 1000.0)
        : null;

    // Cosa e' stata davvero questa seduta, guardando i passi corsi e non il
    // nome che aveva sul programma.
    final ElevationSummary dislivello =
        const ElevationService().of(activity.route);
    final List<ProfileSample> profilo = RunProfile.of(activity.route);
    final double? cadenza = Cadence.average(activity.route);
    final int? passiTotali = Cadence.totalSteps(activity.route);

    // Le calorie: servono il peso e la salita. Sul tapis roulant la salita
    // non c'e' (non c'e' tracciato), e va bene cosi'.
    final double? peso = provider.athleteProfile.weightKg;
    final int? calorie = CalorieEstimate.kcal(
      weightKg: peso,
      meters: activity.distanceMeters,
      seconds: activity.durationSeconds,
      climbMeters: dislivello.isKnown ? dislivello.gainMeters : 0,
    );

    final TrainingZones? zones = provider.trainingZones;
    final SessionAnalysis? analysis = zones == null
        ? null
        : const SessionClassifier().analyse(activity, zones);

    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 44,
        backgroundColor: p.background,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        actions: <Widget>[
          IconButton(
            tooltip: 'Condividi',
            icon: Icon(Icons.ios_share, color: p.blue),
            onPressed: () => Navigator.of(context).pushNamed(
              AppRoutes.share,
              arguments: activity.id,
            ),
          ),
          IconButton(
            tooltip: 'Elimina',
            icon: Icon(Icons.delete_outline, color: p.red),
            onPressed: () => _confirmDelete(context, provider, activity),
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
              activity.name,
              style: AppText.largeTitle.copyWith(color: p.ink),
            ),
            const SizedBox(height: 5),
            Text(
              '${formatDateLong(activity.startTime)}, ore '
              '${formatTimeShort(activity.startTime)}',
              style: AppText.caption.copyWith(color: p.inkFaint),
            ),
            const SizedBox(height: 16),

            // ------------------------------------------------- numeri chiave
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Expanded(
                  child: MetricCard(
                    label: 'Distanza',
                    value: formatDistance(activity.distanceMeters),
                    unit: 'km',
                    valueFontSize: 28,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: MetricCard(
                    label: 'Durata',
                    value: formatDuration(activity.duration),
                    valueFontSize: 28,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Expanded(
                  child: MetricCard(
                    label: 'Passo medio',
                    value: formatPace(activity.averagePaceSecondsPerKm),
                    unit: '/km',
                    valueFontSize: 28,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: passoLavoro != null
                      ? MetricCard(
                          label: 'Solo lavoro',
                          value: formatPace(passoLavoro),
                          unit: '/km',
                          valueFontSize: 28,
                          valueColor: p.accent,
                        )
                      : MetricCard(
                          label: isWorkout ? 'Parziali' : 'Giri',
                          value: '${activity.laps.length}',
                          valueFontSize: 28,
                        ),
                ),
              ],
            ),

            // ------------------------------------------------- le calorie
            //
            // Senza peso non c'e' un numero da dare: il riquadro c'e' lo
            // stesso e porta al profilo, cosi' si capisce cosa manca invece
            // di non vedere niente.
            const SizedBox(height: 12),
            MetricCard(
              label: 'Calorie',
              value: calorie == null ? '--' : formatThousands(calorie),
              unit: calorie == null ? null : 'kcal',
              secondary: calorie == null
                  ? 'Inserisci il tuo peso nel profilo'
                  : 'Stima dal peso e dalla salita',
              valueFontSize: 28,
              onTap: calorie == null
                  ? () => Navigator.of(context).pushNamed(AppRoutes.profile)
                  : null,
            ),

            // ------------------------------------------------- la cadenza
            //
            // Quanti appoggi al minuto. Non dice se si andava forte - dice COME
            // si correva: due persone allo stesso passo, una a 155 e una a 175,
            // stanno facendo due cose diverse.
            //
            // Compare solo se c'e': i telefoni senza sensore di passo esistono,
            // il permesso si puo' negare, e le corse registrate prima di questa
            // versione non ce l'hanno. Un riquadro con "--" dentro sarebbe
            // peggio di nessun riquadro.
            if (cadenza != null) ...<Widget>[
              const SizedBox(height: 12),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Expanded(
                    child: MetricCard(
                      label: 'Cadenza',
                      value: '${cadenza.round()}',
                      unit: 'passi/min',
                      valueFontSize: 28,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: MetricCard(
                      label: 'Passi',
                      value: passiTotali == null
                          ? '--'
                          : formatThousands(passiTotali),
                      valueFontSize: 28,
                    ),
                  ),
                ],
              ),
              Padding(
                padding: const EdgeInsets.only(left: 4, top: 8),
                child: Text(
                  'I passi li conta il sensore del telefono, non il GPS: e\' '
                  'l\'unica misura qui dentro che i satelliti non possono '
                  'sbagliare. Ne conta qualcuno in meno del vero, e quanto in '
                  'meno dipende da dove tieni il telefono - in mano, in tasca, '
                  'in fascia. Quindi guarda come cambia fra le tue corse, non '
                  'il confronto con l\'orologio di un altro.',
                  style: AppText.caption.copyWith(color: p.inkFaint),
                ),
              ),
            ],

            // ------------------------------------- com'e' andata, metro per metro
            //
            // La tabella dei giri dice il passo di ogni chilometro, e va bene
            // per un lento regolare. Non serve per capire DENTRO un
            // chilometro: una ripetuta da 400 metri sparisce nella media del
            // suo chilometro, e un calo negli ultimi due minuti pure.
            if (RunProfile.canDraw(profilo)) ...<Widget>[
              const SectionTitle('Come e\' andata'),
              AppCard(
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
                child: RunProfileChart(profile: profilo),
              ),
              Padding(
                padding: const EdgeInsets.only(left: 4, top: 8),
                child: Text(
                  RunProfile.mostlyFromSpeed(profilo)
                      ? 'In alto si corre forte. Tieni il dito sul grafico per '
                          'leggere un punto preciso. Dove la linea si '
                          'interrompe il passo non si poteva dire: una sosta, '
                          'o un buco di segnale.'
                      : 'In alto si corre forte. Questa corsa e\' stata '
                          'registrata prima che Falcata ricavasse il passo '
                          'dalla velocita\' del chip, quindi qui viene dalle '
                          'posizioni: la linea e\' piu\' mossa di com\'eri '
                          'tu, e gran parte di quei picchi sono il GPS che '
                          'balla. Le corse nuove hanno la linea pulita.',
                  style: AppText.caption.copyWith(color: p.inkFaint),
                ),
              ),
            ],

            // ----------------------------------------- percorso e dislivello
            //
            // La traccia GPS veniva registrata e salvata da sempre, e non si
            // vedeva da nessuna parte. Riconoscere il proprio giro e' il primo
            // motivo per cui si riapre una corsa di tre mesi fa.
            if (RouteShape.canDraw(activity.route)) ...<Widget>[
              const SectionTitle('Il giro'),
              AppCard(
                padding: const EdgeInsets.fromLTRB(10, 12, 10, 10),
                child: Column(
                  children: <Widget>[
                    // Il disegno del giro, non una mappa vera: nessuna
                    // rete, nessun costo, e si riconosce il percorso lo
                    // stesso. Vedi la nota nelle impostazioni.
                    RouteShape(route: activity.route),
                    const SizedBox(height: 6),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: <Widget>[
                        Icon(Icons.circle, size: 9, color: p.green),
                        const SizedBox(width: 5),
                        Text('Partenza',
                            style:
                                AppText.caption.copyWith(color: p.inkFaint)),
                        const SizedBox(width: 14),
                        Icon(Icons.circle_outlined, size: 9, color: p.ink),
                        const SizedBox(width: 5),
                        Text('Arrivo',
                            style:
                                AppText.caption.copyWith(color: p.inkFaint)),
                      ],
                    ),
                  ],
                ),
              ),
            ],

            if (dislivello.isKnown) ...<Widget>[
              const SizedBox(height: 12),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Expanded(
                    child: MetricCard(
                      label: 'Salita',
                      value: dislivello.isFlat
                          ? '--'
                          : '${dislivello.gainMeters.round()}',
                      unit: dislivello.isFlat ? 'pianeggiante' : 'm',
                      valueFontSize: 28,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: MetricCard(
                      label: 'Discesa',
                      value: dislivello.isFlat
                          ? '--'
                          : '${dislivello.lossMeters.round()}',
                      unit: dislivello.isFlat ? '' : 'm',
                      valueFontSize: 28,
                    ),
                  ),
                ],
              ),
              Padding(
                padding: const EdgeInsets.only(left: 4, top: 8),
                child: Text(
                  'Il dislivello viene dal GPS, non da un barometro: e\' un '
                  'numero indicativo. Le oscillazioni sotto i tre metri sono '
                  'scartate, altrimenti un\'ora in pianura risulterebbe una '
                  'salita di seicento metri fatta solo di errore.',
                  style: AppText.caption.copyWith(color: p.inkFaint),
                ),
              ),
            ],

            // ------------------------------------------------------ record
            if (held.isNotEmpty) ...<Widget>[
              const SizedBox(height: 14),
              _RecordsHeld(records: held),
            ],

            // ---------------------------------------------------- parziali
            SectionTitle(isWorkout ? 'Parziali' : 'Giri'),
            LapTable(laps: activity.laps, showStepColumn: isWorkout),

            // ------------------------------------------------------- note
            //
            // Quello che i numeri non dicono: perche' e' andata cosi'. Si
            // scrive a fine corsa, ma si puo' aggiungere o correggere qui in
            // qualunque momento. Arriva intero nel testo per il coach.
            const SectionTitle('Note'),
            AppCard(
              onTap: () => _editNote(context, provider, activity),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        if (activity.temperature != null) ...<Widget>[
                          Text(
                            'Tempo: ${activity.temperature!.label.toLowerCase()}',
                            style: AppText.caption.copyWith(color: p.inkFaint),
                          ),
                          const SizedBox(height: 4),
                        ],
                        if (activity.coachSummary != null) ...<Widget>[
                          Text(
                            'Riepilogo del coach (AI)',
                            style: AppText.caption.copyWith(color: p.inkFaint),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            activity.coachSummary!,
                            style: AppText.body.copyWith(color: p.inkSoft),
                          ),
                          const SizedBox(height: 10),
                        ],
                        Text(
                          _haNote(activity)
                              ? _testoNote(activity)
                              : 'Tocca per scrivere com\'e\' andata e che '
                                  'tempo faceva.',
                          style: AppText.body.copyWith(
                            color: _haNote(activity) ? p.ink : p.inkFaint,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Icon(Icons.edit_outlined, size: 18, color: p.inkFaint),
                ],
              ),
            ),

            // ------------------------------------------------ informazioni
            const SectionTitle('Informazioni'),
            InsetList(
              children: <Widget>[
                AppListRow(
                  title: 'Tipo',
                  value: activity.type.label,
                  showChevron: false,
                ),
                AppListRow(
                  title: 'Scarpa',
                  subtitle: shoe == null ? 'Tocca per assegnarla' : null,
                  value: shoe?.displayName ?? 'Nessuna',
                  onTap: () => _changeShoe(context, provider, shoes, activity),
                ),
                if (analysis != null)
                  AppListRow(
                    title: 'Intensita\' reale',
                    subtitle: analysis.explanation,
                    value: analysis.intensity.label,
                    valueColor: analysis.intensity.countsAsQuality
                        ? p.accent
                        : p.ink,
                    showChevron: false,
                  ),
                AppListRow(
                  title: 'Era una gara o un test',
                  subtitle: activity.declared == null
                      ? 'Se lo era, dillo: pesa piu\' del doppio nella '
                          'stima della forma'
                      : activity.declared!.description,
                  value: activity.declared?.label ?? 'No',
                  valueColor:
                      activity.declared == null ? null : p.accent,
                  onTap: () => _changeDeclared(context, provider, activity),
                ),
                if (activity.feedback != null)
                  AppListRow(
                    title: 'Fatica percepita',
                    subtitle: activity.feedback!.rpeLabel,
                    value: '${activity.rpe}/10',
                    showChevron: false,
                  ),
                if (activity.feedback?.legs != null)
                  AppListRow(
                    title: 'Gambe',
                    value: activity.feedback!.legs!.label,
                    showChevron: false,
                  ),
                if (activity.reportedPain)
                  AppListRow(
                    title: 'Dolore segnalato',
                    subtitle: 'Il motore non propone qualita\' finche\' non '
                        'passa.',
                    value: 'si\'',
                    valueColor: p.red,
                    showChevron: false,
                  ),
                // IL CARICO
                //
                // Il motore lo calcola per decidere la prontezza, ma finche'
                // non si vede e' un numero che nessuno puo' contestare. Qui
                // sta accanto alla distanza e al tempo, che e' il suo posto:
                // sono tre modi di dire quanto e' costata la stessa corsa.
                if (carico != null)
                  AppListRow(
                    title: 'Carico',
                    subtitle: '100 punti = un\'ora a ritmo soglia. Conta '
                        'l\'intensita\', non i chilometri.',
                    value: carico.round().toString(),
                    showChevron: false,
                  ),
                // "Punti GPS: 0" su una corsa inserita a mano sembra un
                // guasto, non una scelta. Su quelle la riga sparisce e al suo
                // posto c'e' la spiegazione, piu' sotto.
                if (!activity.type.isManual)
                  AppListRow(
                    title: 'Punti GPS registrati',
                    value: '${activity.route.length}',
                    showChevron: false,
                  ),
                if (activity.type.isManual)
                  const AppListRow(
                    title: 'Inserita a mano',
                    subtitle: 'Durata e distanza le hai scritte tu, leggendole '
                        'dal display. Questi chilometri contano nel volume '
                        'della settimana, nel carico e sul consumo delle '
                        'scarpe. Non contano per l\'indice di forma, per i '
                        'passi del piano e per i record sulle distanze: la '
                        'distanza la dichiara il nastro, e un nastro tarato '
                        'male non si puo\' smascherare da qui.',
                    showChevron: false,
                  ),
                if (activity.heartRateAverage != null)
                  AppListRow(
                    title: 'FC media',
                    value: '${activity.heartRateAverage} bpm',
                    showChevron: false,
                  ),
                if (activity.dynamics?.cadenceSpm != null)
                  AppListRow(
                    title: 'Cadenza',
                    value: '${activity.dynamics!.cadenceSpm} passi/min',
                    showChevron: false,
                  ),
              ],
            ),

            const SizedBox(height: 14),
            AppCard(
              padding: const EdgeInsets.fromLTRB(14, 13, 15, 14),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Icon(Icons.favorite_border, size: 18, color: p.inkFaint),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Frequenza cardiaca, cadenza, oscillazione verticale, HRV e '
                      'sonno sono gia previsti nel modello dati: verranno mostrati '
                      'qui quando sara collegata una sorgente reale (fascia cardio '
                      'o orologio).',
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

  Future<void> _confirmDelete(
    BuildContext context,
    ActivityProvider provider,
    RunningActivity activity,
  ) async {
    final bool? ok = await showDialog<bool>(
      context: context,
      builder: (BuildContext ctx) => AlertDialog(
        title: const Text('Eliminare l\'attivita?'),
        content: const Text(
            'I chilometri verranno scalati anche dalla scarpa associata.'),
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
    await provider.remove(activity.id);
    if (!context.mounted) return;
    Navigator.of(context).pop();
  }

  /// Chiede se questa uscita era una gara, un test, o niente di speciale.
  ///
  /// E' una dichiarazione, non una deduzione: il motore non prova a
  /// indovinarlo dai dati. Una corsa tirata puo' essere una gara o solo una
  /// giornata buona, e la differenza la sa solo chi l'ha corsa.
  Future<void> _changeDeclared(
    BuildContext context,
    ActivityProvider provider,
    RunningActivity activity,
  ) async {
    final String? choice = await showDialog<String>(
      context: context,
      builder: (BuildContext ctx) => SimpleDialog(
        title: const Text('Cos\'era questa uscita?'),
        children: <Widget>[
          for (final EffortKind kind in EffortKind.values)
            SimpleDialogOption(
              onPressed: () => Navigator.of(ctx).pop(kind.storageKey),
              child: ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(kind.label),
                subtitle: Text(kind.description),
                trailing: activity.declared == kind
                    ? const Icon(Icons.check)
                    : null,
              ),
            ),
          SimpleDialogOption(
            onPressed: () => Navigator.of(ctx).pop('__none__'),
            child: ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Niente di speciale'),
              subtitle: const Text(
                  'Un\'uscita normale: conta come tutte le altre.'),
              trailing:
                  activity.declared == null ? const Icon(Icons.check) : null,
            ),
          ),
        ],
      ),
    );

    if (choice == null) return;
    if (choice == '__none__') {
      await provider.update(activity.copyWith(clearDeclared: true));
      return;
    }
    final EffortKind? kind = EffortKindInfo.fromStorage(choice);
    if (kind == null) return;
    await provider.update(activity.copyWith(declared: kind));
  }

  Future<void> _changeShoe(
    BuildContext context,
    ActivityProvider provider,
    ShoeProvider shoes,
    RunningActivity activity,
  ) async {
    final List<RunningShoe> available = shoes.activeShoes;
    if (available.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Nessuna scarpa disponibile: aggiungila da Scarpe.')),
      );
      return;
    }

    final String? selected = await showDialog<String>(
      context: context,
      builder: (BuildContext ctx) => AlertDialog(
        title: const Text('Quali scarpe hai usato?'),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: available.length,
            itemBuilder: (BuildContext c, int index) {
              final RunningShoe shoe = available[index];
              return ListTile(
                leading: const Icon(Icons.directions_walk_rounded),
                title: Text(shoe.displayName),
                subtitle: Text('${shoe.totalKm.toStringAsFixed(0)} km'),
                selected: shoe.id == activity.shoeId,
                onTap: () => Navigator.of(ctx).pop(shoe.id),
              );
            },
          ),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(ctx).pop('__none__'),
            child: const Text('Nessuna'),
          ),
        ],
      ),
    );

    if (selected == null) return;
    if (selected == '__none__') {
      await provider.update(activity.copyWith(clearShoe: true));
    } else {
      await provider.update(activity.copyWith(shoeId: selected));
    }
  }
}

/// Targhetta con le distanze per cui questa corsa detiene il record.
///
/// Non compare nulla se la corsa non detiene nessun primato: e' un premio,
/// non una sezione fissa.
bool _haNote(RunningActivity a) =>
    (a.note?.trim().isNotEmpty ?? false) ||
    (a.feedback?.note?.trim().isNotEmpty ?? false);

/// Le note della corsa. Quelle scritte a fine corsa stanno nell'attivita';
/// quelle delle corse inserite a mano, nella fatica dichiarata: si mostrano
/// tutte e due, senza perderne nessuna.
String _testoNote(RunningActivity a) => <String>[
      if (a.feedback?.note?.trim().isNotEmpty ?? false) a.feedback!.note!.trim(),
      if (a.note?.trim().isNotEmpty ?? false) a.note!.trim(),
    ].join('\n\n');

Future<void> _editNote(
  BuildContext context,
  ActivityProvider provider,
  RunningActivity activity,
) async {
  final TextEditingController testo =
      TextEditingController(text: activity.note ?? '');
  FeltTemperature? tempo = activity.temperature;
  final AppPalette p = AppPalette.of(context);

  final bool? salva = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: p.background,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (BuildContext ctx) => StatefulBuilder(
      builder: (BuildContext ctx, StateSetter setSheet) => Padding(
        padding: EdgeInsets.fromLTRB(
          AppSpacing.screenSide,
          20,
          AppSpacing.screenSide,
          MediaQuery.of(ctx).viewInsets.bottom + 20,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text('Note', style: AppText.title.copyWith(color: p.ink)),
            const SizedBox(height: 14),
            Text('IL TEMPO', style: AppText.label.copyWith(color: p.inkFaint)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: <Widget>[
                for (final FeltTemperature t in FeltTemperature.values)
                  ChoiceChip(
                    label: Text(t.label),
                    selected: tempo == t,
                    onSelected: (bool on) =>
                        setSheet(() => tempo = on ? t : null),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            TextField(
              controller: testo,
              autofocus: true,
              minLines: 3,
              maxLines: 8,
              maxLength: 600,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(
                hintText: 'Com\'e\' andata, cosa ti ha limitato...',
                filled: true,
                fillColor: p.surface,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppRadius.small),
                  borderSide: BorderSide.none,
                ),
              ),
              style: AppText.body.copyWith(color: p.ink),
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 50,
              width: double.infinity,
              child: FilledButton(
                onPressed: () => Navigator.of(ctx).pop(true),
                style: FilledButton.styleFrom(
                  backgroundColor: p.accent,
                  foregroundColor: p.onAccent,
                ),
                child: const Text('Salva'),
              ),
            ),
          ],
        ),
      ),
    ),
  );

  final String pulito = testo.text.trim();
  testo.dispose();
  if (salva != true) return;
  await provider.update(activity.copyWith(
    note: pulito.isEmpty ? null : pulito,
    clearNote: pulito.isEmpty,
    temperature: tempo,
    clearTemperature: tempo == null,
  ));
}

class _RecordsHeld extends StatelessWidget {
  const _RecordsHeld({required this.records});

  final List<DistanceRecord> records;

  @override
  Widget build(BuildContext context) {
    final AppPalette p = AppPalette.of(context);

    return Container(
      // Tinta unita: la sfumatura rosso-arancio era del tema di prima.
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadius.card),
        color: p.accent,
      ),
      padding: const EdgeInsets.fromLTRB(15, 14, 15, 15),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Icon(Icons.emoji_events_rounded,
                  size: 22, color: p.onAccent),
              const SizedBox(width: 10),
              Text(
                records.length == 1
                    ? 'Record personale'
                    : 'Record personali',
                style: AppText.title.copyWith(
                  color: p.onAccent,
                  fontSize: 17,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          for (final DistanceRecord record in records)
            Padding(
              padding: const EdgeInsets.only(top: 5),
              child: Row(
                children: <Widget>[
                  Expanded(
                    child: Text(
                      record.distance.label,
                      style: AppText.row.copyWith(color: p.onAccent),
                    ),
                  ),
                  Text(
                    formatDuration(Duration(seconds: record.seconds)),
                    style: AppText.number(19, color: p.onAccent),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
