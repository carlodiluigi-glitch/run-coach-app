import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../app/routes.dart';
import '../app/tokens.dart';
import '../models/effort.dart';
import '../models/running_activity.dart';
import '../models/running_shoe.dart';
import '../models/workout.dart';
import '../models/workout_step.dart';
import '../providers/activity_provider.dart';
import '../providers/plan_provider.dart';
import '../providers/running_provider.dart';
import '../providers/shoe_provider.dart';
import '../services/permission_service.dart';
import '../services/workout_engine.dart';
import '../utils/formatters.dart';
import '../widgets/app_card.dart';
import '../widgets/effort_sheet.dart';
import '../widgets/lap_table.dart';
import '../widgets/metric_display.dart';
import '../widgets/pace_indicator.dart';
import '../widgets/run_control_buttons.dart';

/// Schermata di registrazione della corsa (libera o con allenamento).
///
/// Durante la corsa la schermata e' sempre nera, in qualunque tema: si legge
/// al sole, consuma meno e non acceca di notte.
class RunScreen extends StatefulWidget {
  const RunScreen({super.key, this.workout});

  /// Allenamento programmato da eseguire. `null` = corsa libera.
  final Workout? workout;

  @override
  State<RunScreen> createState() => _RunScreenState();
}

class _RunScreenState extends State<RunScreen> {
  bool _saving = false;

  /// Riferimento catturato all'avvio: serve nel dispose, dove non e' piu'
  /// sicuro leggere il provider dal context.
  late final RunningProvider _run;

  @override
  void initState() {
    super.initState();
    _run = context.read<RunningProvider>();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _run.prepare();
    });
  }

  @override
  void dispose() {
    // Se si esce senza aver avviato la corsa, si spegne il GPS di anteprima.
    _run.stopPreview();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final RunningProvider run = context.watch<RunningProvider>();
    final bool active = run.isActive;

    if (!active) {
      return PopScope(
        canPop: true,
        child: Scaffold(
          appBar: AppBar(title: Text(widget.workout?.name ?? 'Corsa libera')),
          body: SafeArea(child: _buildPreStart(context, run)),
        ),
      );
    }

    return PopScope(
      canPop: false,
      child: AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle.light,
        child: Scaffold(
          backgroundColor: AppPalette.run.background,
          body: SafeArea(child: _buildActive(context, run)),
        ),
      ),
    );
  }

  // ----------------------------------------------------------- prima dello
  Widget _buildPreStart(BuildContext context, RunningProvider run) {
    final AppPalette p = AppPalette.of(context);
    final GpsAvailability availability = run.gpsAvailability;
    final bool ready = availability.isReady;
    final Workout? workout = widget.workout;

    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.screenSide,
        8,
        AppSpacing.screenSide,
        32,
      ),
      children: <Widget>[
        AppCard(
          child: Row(
            children: <Widget>[
              Icon(
                ready ? Icons.gps_fixed_rounded : Icons.gps_off_rounded,
                size: 28,
                color: ready ? p.green : p.red,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      ready ? 'Stato GPS' : 'GPS non disponibile',
                      style: AppText.title.copyWith(
                        color: ready ? p.ink : p.red,
                        fontSize: 17,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      ready ? _gpsQualityLabel(run) : availability.message,
                      style: AppText.body.copyWith(color: p.inkSoft),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        if (!ready) ...<Widget>[
          const SizedBox(height: 12),
          if (availability == GpsAvailability.serviceDisabled)
            OutlinedButton.icon(
              onPressed: () async {
                await run.openLocationSettings();
                if (!mounted) return;
                await run.prepare();
              },
              icon: const Icon(Icons.settings),
              label: const Text('Attiva la localizzazione'),
            )
          else if (availability == GpsAvailability.deniedForever)
            OutlinedButton.icon(
              onPressed: () async {
                await run.openAppSettings();
                if (!mounted) return;
                await run.prepare(request: false);
              },
              icon: const Icon(Icons.app_settings_alt),
              label: const Text('Apri impostazioni app'),
            )
          else
            OutlinedButton.icon(
              onPressed: () => run.prepare(),
              icon: const Icon(Icons.lock_open),
              label: const Text('Concedi il permesso posizione'),
            ),
        ],
        if (run.gpsError != null) ...<Widget>[
          const SizedBox(height: 12),
          Text(
            run.gpsError!,
            style: AppText.caption.copyWith(color: p.red),
          ),
        ],

        if (workout != null) ...<Widget>[
          const SectionTitle('Allenamento'),
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(workout.name, style: AppText.title.copyWith(color: p.ink)),
                const SizedBox(height: 4),
                Text(
                  '${workout.totalSteps} fasi  ·  stima '
                  '${formatDistanceWithUnit(workout.estimatedMeters, decimals: 1)} '
                  'in ${formatDurationShort(workout.estimatedSeconds)}',
                  style: AppText.caption.copyWith(color: p.inkFaint),
                ),
                const SizedBox(height: 12),
                for (final ResolvedStep step in workout.expand().take(6))
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Row(
                      children: <Widget>[
                        Expanded(
                          child: Text(
                            step.label,
                            style: AppText.body.copyWith(color: p.inkSoft),
                          ),
                        ),
                        Text(
                          step.step.goalLabel,
                          style: AppText.row.copyWith(color: p.ink),
                        ),
                      ],
                    ),
                  ),
                if (workout.totalSteps > 6)
                  Text(
                    'e altre ${workout.totalSteps - 6} fasi',
                    style: AppText.caption.copyWith(color: p.inkFaint),
                  ),
              ],
            ),
          ),
        ],

        const SizedBox(height: 26),

        Center(
          child: SizedBox(
            width: 92,
            height: 92,
            child: FilledButton(
              onPressed: ready ? () => _start(context, run) : null,
              style: FilledButton.styleFrom(
                backgroundColor: p.green,
                foregroundColor: Colors.white,
                disabledBackgroundColor: p.separator,
                disabledForegroundColor: p.inkFaint,
                padding: EdgeInsets.zero,
                shape: const CircleBorder(),
                minimumSize: const Size(92, 92),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  const Icon(Icons.play_arrow_rounded, size: 36),
                  const SizedBox(height: 1),
                  Text('START', style: AppText.label),
                ],
              ),
            ),
          ),
        ),

        const SizedBox(height: 20),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Icon(
              run.backgroundTrackingRequested
                  ? Icons.phone_android
                  : Icons.screen_lock_portrait,
              size: 17,
              color: p.inkFaint,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                run.backgroundTrackingRequested
                    ? 'Puoi mettere il telefono in tasca e spegnere lo schermo: '
                        'la corsa continua a registrarsi e resta una notifica attiva.'
                    : 'Registrazione in background disattivata: tieni l\'app aperta '
                        'e lo schermo acceso, altrimenti la corsa si interrompe.',
                style: AppText.caption.copyWith(color: p.inkFaint),
              ),
            ),
          ],
        ),
      ],
    );
  }

  String _gpsQualityLabel(RunningProvider run) {
    switch (run.gpsQuality) {
      case 3:
        return 'Segnale ottimo (precisione ${run.accuracy?.round()} m).';
      case 2:
        return 'Segnale buono (precisione ${run.accuracy?.round()} m).';
      case 1:
        return 'Segnale debole (precisione ${run.accuracy?.round()} m). '
            'Attendi qualche secondo all\'aperto.';
      default:
        return 'In attesa del segnale GPS...';
    }
  }

  // ------------------------------------------------------ durante la corsa
  Widget _buildActive(BuildContext context, RunningProvider run) {
    final AppPalette p = AppPalette.run;
    final WorkoutEngine? engine = run.engine;
    final bool hasWorkout = engine != null && !engine.isEmpty;

    return Column(
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.fromLTRB(AppSpacing.screenSide, 10,
              AppSpacing.screenSide, 0),
          child: _TopBar(run: run),
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.screenSide,
              14,
              AppSpacing.screenSide,
              8,
            ),
            children: <Widget>[
              // La condizione va scritta per esteso qui dentro: e' cosi' che
              // Dart capisce che dentro il blocco `engine` non e' piu' nullo.
              if (engine != null && !engine.isEmpty) ...<Widget>[
                _StepProgress(run: run, engine: engine),
                const SizedBox(height: 22),
              ],

              // Il numero principale: il passo attuale, colorato secondo il
              // target quando l'allenamento ne ha uno.
              BigMetric(
                label: 'Passo attuale',
                value: formatPace(run.currentPaceSecPerKm),
                unit: '/km',
                size: 74,
                color: _paceColor(run, p),
                footnote: hasWorkout
                    ? PaceIndicator(
                        status: run.paceStatus,
                        currentPaceSecPerKm: run.currentPaceSecPerKm,
                        target: run.currentPaceTarget,
                      )
                    : null,
              ),

              const SizedBox(height: 24),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Expanded(
                    child: BigMetric(
                      label: 'Tempo',
                      value: formatDuration(run.elapsed),
                      size: 34,
                    ),
                  ),
                  Expanded(
                    child: BigMetric(
                      label: 'Distanza',
                      value: formatDistance(run.distanceMeters),
                      unit: 'km',
                      size: 34,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Expanded(
                    child: BigMetric(
                      label: hasWorkout ? 'Questa fase' : 'Giro in corso',
                      value: formatDuration(
                        Duration(seconds: run.currentLapSeconds),
                      ),
                      size: 24,
                    ),
                  ),
                  Expanded(
                    child: BigMetric(
                      label: 'Passo medio',
                      value: formatPace(run.averagePaceSecPerKm),
                      unit: '/km',
                      size: 24,
                    ),
                  ),
                ],
              ),

              // IL TELEFONO HA SOSPESO LA REGISTRAZIONE
              //
              // Diverso dal "segnale assente" qui sotto: li' e' un sottopasso,
              // qui e' Android che ha messo l'app a dormire. Va detto forte e
              // subito, perche' e' l'unico momento in cui si puo' rimediare -
              // a fine corsa restano solo i chilometri che mancano.
              if (run.isGpsStalled) ...<Widget>[
                const SizedBox(height: 18),
                Container(
                  padding: const EdgeInsets.fromLTRB(12, 11, 12, 11),
                  decoration: BoxDecoration(
                    color: p.red.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(AppRadius.small + 2),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Icon(Icons.warning_amber_rounded,
                          size: 18, color: p.red),
                      const SizedBox(width: 9),
                      Expanded(
                        child: Text(
                          'Il telefono ha smesso di mandare la posizione da '
                          '${run.stalledSeconds} secondi. Tieni l\'app aperta '
                          'e controlla il risparmio energetico: da qui in '
                          'avanti i chilometri non si contano.',
                          style: AppText.caption
                              .copyWith(color: p.red, height: 1.35),
                        ),
                      ),
                    ],
                  ),
                ),
              ] else if (!run.hasGpsFix) ...<Widget>[
                const SizedBox(height: 18),
                Row(
                  children: <Widget>[
                    Icon(Icons.gps_off_rounded, size: 17, color: p.orange),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Segnale GPS assente: la distanza non si aggiorna.',
                        style: AppText.caption.copyWith(color: p.orange),
                      ),
                    ),
                  ],
                ),
              ],

              if (run.laps.isNotEmpty) ...<Widget>[
                const SizedBox(height: 26),
                Text(
                  'PARZIALI',
                  style: AppText.label.copyWith(color: p.inkFaint),
                ),
                const SizedBox(height: 8),
                LapTable(
                  laps: run.laps.reversed.toList(),
                  showStepColumn: run.hasWorkout,
                  dark: true,
                ),
              ],
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: RunControlButtons(
            isRunning: run.isRunning,
            isPaused: run.isPaused,
            onPause: run.pause,
            onResume: run.resume,
            onStop: _saving ? () {} : () => _confirmStop(context, run),
            onLap: run.manualLap,
            onSkipStep: run.hasWorkout ? run.skipStep : null,
          ),
        ),
      ],
    );
  }

  /// Il passo si colora solo quando c'e' un obiettivo da rispettare: nella
  /// corsa libera resta bianco, perche' non esiste un "giusto".
  Color _paceColor(RunningProvider run, AppPalette p) {
    switch (run.paceStatus) {
      case PaceStatus.onTarget:
        return p.green;
      case PaceStatus.tooFast:
      case PaceStatus.tooSlow:
        return p.orange;
      case PaceStatus.unknown:
        return p.ink;
    }
  }

  // ------------------------------------------------------------- azioni
  Future<void> _start(BuildContext context, RunningProvider run) async {
    final bool ok = await run.start(workout: widget.workout);
    if (!mounted) return;
    if (!ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(run.gpsAvailability.message)),
      );
    }
  }

  Future<void> _confirmStop(BuildContext context, RunningProvider run) async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext ctx) => AlertDialog(
        title: const Text('Terminare la corsa?'),
        content: const Text(
            'La registrazione verra chiusa e potrai salvare l\'attivita.'),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Annulla'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Termina'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    await _finishAndSave(context, run);
  }

  Future<void> _finishAndSave(BuildContext context, RunningProvider run) async {
    setState(() => _saving = true);

    final RunningActivity? activity = await run.finish();
    if (!mounted || activity == null) {
      if (mounted) setState(() => _saving = false);
      return;
    }

    // Attivita' troppo corta: si propone di scartarla.
    if (activity.distanceMeters < 50 && activity.durationSeconds < 30) {
      final bool? keep = await showDialog<bool>(
        context: context,
        builder: (BuildContext ctx) => AlertDialog(
          title: const Text('Attivita molto breve'),
          content: const Text(
              'Hai registrato pochissimi dati. Vuoi salvarla comunque?'),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Scarta'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('Salva'),
            ),
          ],
        ),
      );
      if (keep != true) {
        await run.reset();
        if (!mounted) return;
        Navigator.of(context).pop();
        return;
      }
    }

    if (!mounted) return;
    final String? shoeId = await _askShoe(context);

    // La fatica percepita si chiede subito dopo, finche' la sensazione e'
    // fresca: chiederla il giorno dopo darebbe un numero inventato.
    if (!mounted) return;
    final SessionFeedback? feedback = await askSessionFeedback(context);

    if (!mounted) return;
    final ActivityProvider activities = context.read<ActivityProvider>();
    final RunningActivity toSave = activity.copyWith(
      shoeId: shoeId,
      feedback: feedback,
      plannedSessionKey: _plannedSessionKey(context),
    );
    final bool saved = await activities.add(toSave);

    await run.reset();
    if (!mounted) return;

    setState(() => _saving = false);

    if (!saved) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(activities.errorMessage ??
              'Salvataggio non riuscito: controlla lo spazio disponibile.'),
        ),
      );
    }

    Navigator.of(context).pushReplacementNamed(
      AppRoutes.activityDetail,
      arguments: toSave.id,
    );
  }

  /// A quale seduta del piano corrisponde la corsa appena finita.
  ///
  /// Si usa la data invece di un identificatore perche' il piano viene
  /// ricalcolato a ogni avvio: gli id interni cambiano, la data no. Serve al
  /// motore per confrontare quello che era previsto con quello che e' stato
  /// davvero corso.
  String? _plannedSessionKey(BuildContext context) {
    final PlanProvider plans = context.read<PlanProvider>();
    if (!plans.hasPlan) return null;
    final DateTime today = DateTime.now();
    if (plans.sessionsOn(today).isEmpty) return null;
    final String month = today.month.toString().padLeft(2, '0');
    final String day = today.day.toString().padLeft(2, '0');
    return '${today.year}-$month-$day';
  }

  /// Chiede quali scarpe sono state usate.
  Future<String?> _askShoe(BuildContext context) async {
    final ShoeProvider shoes = context.read<ShoeProvider>();
    final List<RunningShoe> available = shoes.activeShoes;

    if (available.isEmpty) {
      await showDialog<void>(
        context: context,
        builder: (BuildContext ctx) => AlertDialog(
          title: const Text('Nessuna scarpa'),
          content: const Text(
              'Non hai ancora inserito nessuna scarpa. Puoi aggiungerla dalla sezione Scarpe e assegnarla in seguito.'),
          actions: <Widget>[
            FilledButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Ho capito'),
            ),
          ],
        ),
      );
      return null;
    }

    return showDialog<String>(
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
                onTap: () => Navigator.of(ctx).pop(shoe.id),
              );
            },
          ),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Nessuna'),
          ),
        ],
      ),
    );
  }
}

/// Riga in cima alla schermata di corsa: fase in corso a sinistra, stato del
/// segnale a destra.
class _TopBar extends StatelessWidget {
  const _TopBar({required this.run});

  final RunningProvider run;

  @override
  Widget build(BuildContext context) {
    final AppPalette p = AppPalette.run;
    final ResolvedStep? step = run.currentStep;
    final bool paused = run.isPaused;

    final String pillText;
    final Color dotColor;
    if (paused) {
      pillText = 'In pausa';
      dotColor = p.orange;
    } else if (step != null) {
      pillText = step.label;
      dotColor = p.accent;
    } else {
      pillText = 'Corsa libera';
      dotColor = p.green;
    }

    return Row(
      children: <Widget>[
        Flexible(
          child: StatusPill(
            text: pillText,
            dotColor: dotColor,
            background: p.surfaceElevated,
            textColor: p.ink,
          ),
        ),
        const Spacer(),
        Icon(
          run.hasGpsFix ? Icons.gps_fixed_rounded : Icons.gps_off_rounded,
          size: 15,
          color: run.hasGpsFix ? p.green : p.orange,
        ),
        const SizedBox(width: 6),
        Text(
          _signalLabel(run),
          style: AppText.label.copyWith(
            color: run.hasGpsFix ? p.green : p.orange,
          ),
        ),
      ],
    );
  }

  String _signalLabel(RunningProvider run) {
    switch (run.gpsQuality) {
      case 3:
        return 'GPS OTTIMO';
      case 2:
        return 'GPS BUONO';
      case 1:
        return 'GPS DEBOLE';
      default:
        return 'GPS ASSENTE';
    }
  }
}

/// Avanzamento della fase corrente: barra sottile, obiettivo a sinistra,
/// quanto manca a destra.
class _StepProgress extends StatelessWidget {
  const _StepProgress({required this.run, required this.engine});

  final RunningProvider run;
  final WorkoutEngine engine;

  @override
  Widget build(BuildContext context) {
    final AppPalette p = AppPalette.run;
    final ResolvedStep? step = engine.currentStep;

    if (step == null || engine.isFinished) {
      return Row(
        children: <Widget>[
          Icon(Icons.check_circle_rounded, size: 20, color: p.green),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              'Allenamento completato. Metti in pausa per terminare.',
              style: AppText.body.copyWith(color: p.green),
            ),
          ),
        ],
      );
    }

    final double? metersLeft = engine.remainingMeters;
    final int? secondsLeft = engine.remainingSeconds;
    final ResolvedStep? next = engine.nextStep;

    final String remaining = metersLeft != null
        ? 'restano ${metersLeft.round()} m'
        : 'restano ${formatDuration(Duration(seconds: secondsLeft ?? 0))}';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        ThinProgressBar(
          value: engine.stepProgress,
          color: p.accent,
          trackColor: p.surfaceElevated,
        ),
        const SizedBox(height: 9),
        Row(
          children: <Widget>[
            Expanded(
              child: Text(
                step.step.goalLabel,
                style: AppText.label.copyWith(color: p.inkFaint),
              ),
            ),
            Text(
              remaining.toUpperCase(),
              style: AppText.label.copyWith(color: p.ink),
            ),
          ],
        ),
        if (next != null) ...<Widget>[
          const SizedBox(height: 5),
          Text(
            'poi ${next.label.toLowerCase()} · ${next.step.goalLabel}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppText.caption.copyWith(color: p.inkFaint),
          ),
        ],
      ],
    );
  }
}
