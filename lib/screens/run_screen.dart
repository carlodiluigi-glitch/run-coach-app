import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../app/routes.dart';
import '../models/running_activity.dart';
import '../models/running_shoe.dart';
import '../models/workout.dart';
import '../models/workout_step.dart';
import '../providers/activity_provider.dart';
import '../providers/running_provider.dart';
import '../providers/shoe_provider.dart';
import '../services/permission_service.dart';
import '../services/workout_engine.dart';
import '../utils/formatters.dart';
import '../widgets/app_card.dart';
import '../widgets/lap_table.dart';
import '../widgets/metric_card.dart';
import '../widgets/pace_indicator.dart';
import '../widgets/run_control_buttons.dart';

/// Schermata di registrazione della corsa (libera o con allenamento).
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

    return PopScope(
      canPop: !active,
      child: Scaffold(
        appBar: AppBar(
          title: Text(widget.workout?.name ?? 'Corsa libera'),
          automaticallyImplyLeading: !active,
        ),
        body: SafeArea(
          child: active ? _buildActive(context, run) : _buildPreStart(context, run),
        ),
      ),
    );
  }

  // ----------------------------------------------------------- prima dello
  Widget _buildPreStart(BuildContext context, RunningProvider run) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final GpsAvailability availability = run.gpsAvailability;
    final bool ready = availability.isReady;
    final Workout? workout = widget.workout;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      children: <Widget>[
        AppCard(
          color: ready ? scheme.surfaceContainerHighest : scheme.errorContainer,
          child: Row(
            children: <Widget>[
              Icon(
                ready ? Icons.gps_fixed : Icons.gps_off,
                size: 32,
                color: ready ? scheme.primary : scheme.onErrorContainer,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      ready ? 'Stato GPS' : 'GPS non disponibile',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: ready ? null : scheme.onErrorContainer,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      ready
                          ? _gpsQualityLabel(run)
                          : availability.message,
                      style: TextStyle(
                        fontSize: 14,
                        color: ready
                            ? scheme.onSurfaceVariant
                            : scheme.onErrorContainer,
                      ),
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
            style: TextStyle(color: scheme.error, fontSize: 13),
          ),
        ],

        const SizedBox(height: 20),

        if (workout != null) ...<Widget>[
          const SectionTitle('Allenamento'),
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  workout.name,
                  style: const TextStyle(
                      fontSize: 18, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 6),
                Text(
                  '${workout.totalSteps} fasi - stima ${formatDistanceKmWithUnit(workout.estimatedMeters, decimals: 1)} / ${formatDurationShort(workout.estimatedSeconds)}',
                  style: TextStyle(color: scheme.onSurfaceVariant),
                ),
                const SizedBox(height: 10),
                for (final ResolvedStep step in workout.expand().take(6))
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Text(
                      '- ${step.label}: ${step.step.goalLabel}',
                      style: const TextStyle(fontSize: 14),
                    ),
                  ),
                if (workout.totalSteps > 6)
                  Text(
                    '... e altre ${workout.totalSteps - 6} fasi',
                    style: TextStyle(color: scheme.onSurfaceVariant),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 20),
        ],

        SizedBox(
          height: 96,
          child: FilledButton.icon(
            onPressed: ready ? () => _start(context, run) : null,
            icon: const Icon(Icons.play_arrow, size: 40),
            label: const Text(
              'START',
              style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Text(
          'Tieni lo schermo acceso durante la registrazione: in questa versione '
          'il tracciamento in background non e\' attivo.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 13, color: scheme.onSurfaceVariant),
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
        return 'Segnale debole (precisione ${run.accuracy?.round()} m). Attendi qualche secondo all\'aperto.';
      default:
        return 'In attesa del segnale GPS...';
    }
  }

  // ------------------------------------------------------ durante la corsa
  Widget _buildActive(BuildContext context, RunningProvider run) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final WorkoutEngine? engine = run.engine;

    return Column(
      children: <Widget>[
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            children: <Widget>[
              if (run.isPaused)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: AppCard(
                    color: scheme.tertiaryContainer,
                    child: Row(
                      children: <Widget>[
                        Icon(Icons.pause_circle_outline,
                            color: scheme.onTertiaryContainer),
                        const SizedBox(width: 10),
                        Text(
                          'IN PAUSA - il tempo non viene conteggiato',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            color: scheme.onTertiaryContainer,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

              // Metriche principali, molto grandi.
              MetricCard(
                label: 'Tempo',
                value: formatDuration(run.elapsed),
                valueFontSize: 56,
                emphasized: true,
              ),
              const SizedBox(height: 12),
              Row(
                children: <Widget>[
                  Expanded(
                    child: MetricCard(
                      label: 'Distanza',
                      value: formatDistanceKm(run.distanceMeters),
                      unit: 'km',
                      valueFontSize: 40,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: MetricCard(
                      label: 'Passo attuale',
                      value: formatPace(run.currentPaceSecPerKm),
                      unit: '/km',
                      valueFontSize: 40,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: <Widget>[
                  Expanded(
                    child: MetricCard(
                      label: 'Passo medio',
                      value: formatPace(run.averagePaceSecPerKm),
                      unit: '/km',
                      valueFontSize: 28,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: MetricCard(
                      label: 'Velocita',
                      value: formatSpeedKmh(run.currentSpeedMps),
                      valueFontSize: 28,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 16),

              // Fase di allenamento in corso.
              if (engine != null && !engine.isEmpty) ...<Widget>[
                _WorkoutStepPanel(run: run, engine: engine),
                const SizedBox(height: 12),
                PaceIndicator(
                  status: run.paceStatus,
                  currentPaceSecPerKm: run.currentPaceSecPerKm,
                  target: run.currentPaceTarget,
                ),
                const SizedBox(height: 16),
              ],

              // Lap.
              const SectionTitle('Giri'),
              AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        Expanded(
                          child: _InlineInfo(
                            label: 'Lap',
                            value: '${run.lapCount}',
                          ),
                        ),
                        Expanded(
                          child: _InlineInfo(
                            label: 'Lap corrente',
                            value: formatDistanceAuto(run.currentLapDistance),
                          ),
                        ),
                        Expanded(
                          child: _InlineInfo(
                            label: 'Ultimo lap',
                            value: run.lastLap == null
                                ? kEmptyPace
                                : formatPace(run.lastLap!.paceSecondsPerKm),
                          ),
                        ),
                      ],
                    ),
                    if (run.laps.isNotEmpty) ...<Widget>[
                      const SizedBox(height: 8),
                      LapTable(laps: run.laps, showStepColumn: run.hasWorkout),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 8),
              if (!run.hasGpsFix)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    'Segnale GPS assente: la distanza non viene aggiornata.',
                    style: TextStyle(color: scheme.error, fontSize: 13),
                  ),
                ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
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

    if (!mounted) return;
    final ActivityProvider activities = context.read<ActivityProvider>();
    final RunningActivity toSave =
        shoeId == null ? activity : activity.copyWith(shoeId: shoeId);
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

  /// Chiede quali scarpe sono state usate.
  Future<String?> _askShoe(BuildContext context) async {
    final ShoeProvider shoes = context.read<ShoeProvider>();
    final List<RunningShoe> available = shoes.activeShoes;

    if (available.isEmpty) {
      // Nessuna scarpa disponibile: si informa l'utente senza bloccarlo.
      await showDialog<void>(
        context: context,
        builder: (BuildContext ctx) => AlertDialog(
          title: const Text('Nessuna scarpa'),
          content: const Text(
              'Non hai ancora inserito nessuna scarpa. Puoi aggiungerla dalla sezione SCARPE e assegnarla in seguito.'),
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
                leading: const Icon(Icons.hiking),
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

/// Pannello con la fase corrente dell'allenamento programmato.
class _WorkoutStepPanel extends StatelessWidget {
  const _WorkoutStepPanel({required this.run, required this.engine});

  final RunningProvider run;
  final WorkoutEngine engine;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final ResolvedStep? step = engine.currentStep;

    if (step == null || engine.isFinished) {
      return AppCard(
        color: scheme.primaryContainer,
        child: Row(
          children: <Widget>[
            Icon(Icons.check_circle, color: scheme.onPrimaryContainer, size: 30),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Allenamento completato. Puoi terminare la registrazione.',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: scheme.onPrimaryContainer,
                ),
              ),
            ),
          ],
        ),
      );
    }

    final double? metersLeft = engine.remainingMeters;
    final int? secondsLeft = engine.remainingSeconds;
    final ResolvedStep? next = engine.nextStep;

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  step.step.type.label.toUpperCase(),
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.0,
                    color: scheme.primary,
                  ),
                ),
              ),
              if (step.isRepeated)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: scheme.primary,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${step.repetitionIndex} / ${step.repetitionTotal}',
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 16,
                      color: scheme.onPrimary,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Obiettivo ${step.step.goalLabel}',
            style: TextStyle(fontSize: 15, color: scheme.onSurfaceVariant),
          ),
          const SizedBox(height: 10),
          Text(
            metersLeft != null
                ? '${metersLeft.round()} m rimanenti'
                : '${formatDuration(Duration(seconds: secondsLeft ?? 0))} rimanenti',
            style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: engine.stepProgress,
              minHeight: 10,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            next == null
                ? 'Ultima fase dell\'allenamento'
                : 'Prossima: ${next.label} - ${next.step.goalLabel}',
            style: TextStyle(fontSize: 14, color: scheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}

class _InlineInfo extends StatelessWidget {
  const _InlineInfo({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(label,
            style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant)),
        const SizedBox(height: 2),
        Text(value,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
      ],
    );
  }
}
