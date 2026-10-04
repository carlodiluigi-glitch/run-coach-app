import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../app/routes.dart';
import '../app/tokens.dart';
import '../models/effort.dart';
import '../models/running_activity.dart';
import '../models/running_shoe.dart';
import '../providers/activity_provider.dart';
import '../providers/shoe_provider.dart';
import '../services/elevation_service.dart';
import '../services/pace_zone_engine.dart';
import '../services/records_service.dart';
import '../services/session_classifier.dart';
import '../utils/formatters.dart';
import '../widgets/app_card.dart';
import '../widgets/empty_state.dart';
import '../widgets/inset_list.dart';
import '../widgets/lap_table.dart';
import '../widgets/metric_card.dart';
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

    // Cosa e' stata davvero questa seduta, guardando i passi corsi e non il
    // nome che aveva sul programma.
    final ElevationSummary dislivello =
        const ElevationService().of(activity.route);

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
                  child: MetricCard(
                    label: isWorkout ? 'Parziali' : 'Giri',
                    value: '${activity.laps.length}',
                    valueFontSize: 28,
                  ),
                ),
              ],
            ),

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
                AppListRow(
                  title: 'Punti GPS registrati',
                  value: '${activity.route.length}',
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
class _RecordsHeld extends StatelessWidget {
  const _RecordsHeld({required this.records});

  final List<DistanceRecord> records;

  @override
  Widget build(BuildContext context) {
    final AppPalette p = AppPalette.of(context);

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadius.card),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[p.accent, const Color(0xFFFF6B4A)],
        ),
      ),
      padding: const EdgeInsets.fromLTRB(15, 14, 15, 15),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              const Icon(Icons.emoji_events_rounded,
                  size: 22, color: Colors.white),
              const SizedBox(width: 10),
              Text(
                records.length == 1
                    ? 'Record personale'
                    : 'Record personali',
                style: AppText.title.copyWith(
                  color: Colors.white,
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
                      style: AppText.row.copyWith(color: Colors.white),
                    ),
                  ),
                  Text(
                    formatDuration(Duration(seconds: record.seconds)),
                    style: AppText.number(19, color: Colors.white),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
