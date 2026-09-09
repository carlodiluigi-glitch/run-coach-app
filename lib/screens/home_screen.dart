import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../app/app.dart';
import '../app/routes.dart';
import '../models/run_checkpoint.dart';
import '../models/running_activity.dart';
import '../providers/activity_provider.dart';
import '../providers/running_provider.dart';
import '../providers/settings_provider.dart';
import '../services/stats_service.dart';
import '../utils/formatters.dart';
import '../widgets/app_card.dart';
import '../widgets/metric_card.dart';

/// Cosa fare di una corsa rimasta aperta.
enum _RecoveryChoice { resume, saveAndClose, discard }

/// Schermata iniziale: saluto, riepilogo e accessi rapidi.
///
/// All'avvio controlla se e' rimasta una corsa interrotta e, in quel caso,
/// chiede cosa farne prima di lasciar fare qualsiasi altra cosa.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  /// La domanda si fa una volta sola per avvio dell'app.
  bool _checkpointChecked = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkForInterruptedRun();
    });
  }

  Future<void> _checkForInterruptedRun() async {
    if (_checkpointChecked) return;
    _checkpointChecked = true;

    final RunningProvider run = context.read<RunningProvider>();
    final RunCheckpoint? checkpoint = await run.loadRecoverableCheckpoint();
    if (checkpoint == null || !mounted) return;

    // La domanda non e' chiudibile toccando fuori.
    //
    // PERCHE': se fosse ignorabile e poi si avviasse una corsa nuova, il
    // checkpoint verrebbe sovrascritto e la corsa interrotta sparirebbe senza
    // che nessuno se ne accorga. Meglio una domanda in faccia che una perdita
    // silenziosa.
    final _RecoveryChoice? choice = await showDialog<_RecoveryChoice>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext ctx) => _RecoveryDialog(checkpoint: checkpoint),
    );

    if (choice == null || !mounted) return;

    switch (choice) {
      case _RecoveryChoice.resume:
        await _resume(checkpoint);
        break;
      case _RecoveryChoice.saveAndClose:
        await _saveAndClose(checkpoint);
        break;
      case _RecoveryChoice.discard:
        await _discard(checkpoint);
        break;
    }
  }

  Future<void> _resume(RunCheckpoint checkpoint) async {
    final RunningProvider run = context.read<RunningProvider>();
    final NavigatorState navigator = Navigator.of(context);
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);

    final bool ok = await run.resumeFromCheckpoint(checkpoint);
    if (!mounted) return;

    if (!ok) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text(
            'Impossibile riprendere: controlla i permessi di posizione.',
          ),
        ),
      );
      return;
    }

    navigator.pushNamed(AppRoutes.run, arguments: checkpoint.workout);
  }

  Future<void> _saveAndClose(RunCheckpoint checkpoint) async {
    final RunningProvider run = context.read<RunningProvider>();
    final ActivityProvider activities = context.read<ActivityProvider>();
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);

    final RunningActivity activity = run.activityFromCheckpoint(checkpoint);
    final bool saved = await activities.add(activity);

    // Il checkpoint si elimina solo a salvataggio riuscito: se la scrittura
    // fallisce, la corsa resta recuperabile al prossimo avvio invece di
    // sparire per sempre.
    if (saved) {
      await run.discardCheckpoint();
    }
    if (!mounted) return;

    messenger.showSnackBar(
      SnackBar(
        content: Text(
          saved
              ? 'Corsa salvata nello storico.'
              : 'Salvataggio non riuscito: la corsa resta recuperabile.',
        ),
      ),
    );
  }

  Future<void> _discard(RunCheckpoint checkpoint) async {
    // Seconda conferma: e' l'unica scelta irreversibile delle tre.
    final bool confirmed = await showDialog<bool>(
          context: context,
          builder: (BuildContext ctx) => AlertDialog(
            title: const Text('Scartare la corsa?'),
            content: Text(
              'I ${formatDistanceKmWithUnit(checkpoint.distanceMeters)} '
              'registrati andranno persi e non si potranno recuperare.',
            ),
            actions: <Widget>[
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(false),
                child: const Text('Annulla'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(ctx).pop(true),
                child: const Text('Scarta'),
              ),
            ],
          ),
        ) ??
        false;

    if (!confirmed) {
      // Ci si ripensa: la domanda principale torna a comparire.
      if (mounted) {
        _checkpointChecked = false;
        await _checkForInterruptedRun();
      }
      return;
    }

    final RunningProvider run = context.read<RunningProvider>();
    await run.discardCheckpoint();
  }

  @override
  Widget build(BuildContext context) {
    final SettingsProvider settings = context.watch<SettingsProvider>();
    final ActivityProvider activities = context.watch<ActivityProvider>();
    final RunningStats stats = activities.stats;
    final ColorScheme scheme = Theme.of(context).colorScheme;

    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
          children: <Widget>[
            // ------------------------------------------------ intestazione
            Row(
              children: <Widget>[
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        RunCoachApp.appName,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.4,
                          color: scheme.primary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        settings.settings.greeting,
                        style: const TextStyle(
                          fontSize: 30,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () =>
                      Navigator.of(context).pushNamed(AppRoutes.settings),
                  icon: const Icon(Icons.settings_outlined, size: 28),
                  tooltip: 'Impostazioni',
                ),
              ],
            ),
            const SizedBox(height: 20),

            // -------------------------------------------------- riepilogo
            Row(
              children: <Widget>[
                Expanded(
                  child: MetricCard(
                    label: 'Km settimana',
                    value: stats.weekKm.toStringAsFixed(1),
                    unit: 'km',
                    valueFontSize: 30,
                    emphasized: true,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: MetricCard(
                    label: 'Allenamenti',
                    value: '${stats.weekActivities}',
                    secondary: 'questa settimana',
                    valueFontSize: 30,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: <Widget>[
                Expanded(
                  child: MetricCard(
                    label: 'Passo medio recente',
                    value: formatPace(stats.averagePaceSecPerKm),
                    unit: '/km',
                    secondary: 'ultime 4 settimane',
                    valueFontSize: 30,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: MetricCard(
                    label: 'Totale',
                    value: stats.totalKm.toStringAsFixed(0),
                    unit: 'km',
                    secondary: '${stats.totalActivities} attivita',
                    valueFontSize: 30,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 20),

            // --------------------------------------------- ultima attivita
            const SectionTitle('Ultima attivita'),
            _LastActivityCard(activity: stats.lastActivity),

            const SizedBox(height: 24),

            // ---------------------------------------------------- pulsanti
            SizedBox(
              height: 80,
              child: FilledButton.icon(
                onPressed: () => Navigator.of(context).pushNamed(AppRoutes.run),
                icon: const Icon(Icons.directions_run, size: 34),
                label: const Text(
                  'CORSA LIBERA',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
                ),
              ),
            ),
            const SizedBox(height: 12),
            _HomeButton(
              icon: Icons.list_alt,
              label: 'ALLENAMENTI',
              onTap: () =>
                  Navigator.of(context).pushNamed(AppRoutes.workoutLibrary),
            ),
            const SizedBox(height: 10),
            _HomeButton(
              icon: Icons.history,
              label: 'STORICO',
              onTap: () => Navigator.of(context).pushNamed(AppRoutes.history),
            ),
            const SizedBox(height: 10),
            _HomeButton(
              icon: Icons.insights,
              label: 'STATISTICHE',
              onTap: () => Navigator.of(context).pushNamed(AppRoutes.stats),
            ),
            const SizedBox(height: 10),
            _HomeButton(
              icon: Icons.hiking,
              label: 'SCARPE',
              onTap: () => Navigator.of(context).pushNamed(AppRoutes.shoes),
            ),
            const SizedBox(height: 10),
            _HomeButton(
              icon: Icons.settings_outlined,
              label: 'IMPOSTAZIONI',
              onTap: () => Navigator.of(context).pushNamed(AppRoutes.settings),
            ),
          ],
        ),
      ),
    );
  }
}

/// La domanda all'avvio: cosa fare della corsa rimasta aperta.
class _RecoveryDialog extends StatelessWidget {
  const _RecoveryDialog({required this.checkpoint});

  final RunCheckpoint checkpoint;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final String name = checkpoint.workout?.name ?? 'Corsa libera';

    return AlertDialog(
      title: const Text('Corsa interrotta'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            'L\'app si e chiusa mentre stavi registrando.',
            style: TextStyle(color: scheme.onSurfaceVariant),
          ),
          const SizedBox(height: 14),
          Text(
            name,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 2),
          Text(
            formatRelativeDay(checkpoint.startTime),
            style: TextStyle(fontSize: 13, color: scheme.onSurfaceVariant),
          ),
          const SizedBox(height: 12),
          Row(
            children: <Widget>[
              _Stat(
                label: 'Distanza',
                value: formatDistanceKmWithUnit(checkpoint.distanceMeters),
              ),
              _Stat(
                label: 'Tempo',
                value: formatDuration(
                  Duration(seconds: checkpoint.elapsedSeconds),
                ),
              ),
              _Stat(label: 'Lap', value: '${checkpoint.laps.length}'),
            ],
          ),
        ],
      ),
      actionsOverflowDirection: VerticalDirection.down,
      actions: <Widget>[
        TextButton(
          onPressed: () =>
              Navigator.of(context).pop(_RecoveryChoice.discard),
          child: const Text('Scarta'),
        ),
        TextButton(
          onPressed: () =>
              Navigator.of(context).pop(_RecoveryChoice.saveAndClose),
          child: const Text('Chiudi e salva'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(_RecoveryChoice.resume),
          child: const Text('Riprendi'),
        ),
      ],
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            label,
            style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}

class _HomeButton extends StatelessWidget {
  const _HomeButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 62,
      child: OutlinedButton.icon(
        onPressed: onTap,
        icon: Icon(icon, size: 26),
        label: Align(
          alignment: Alignment.centerLeft,
          child: Text(label,
              style:
                  const TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
        ),
      ),
    );
  }
}

class _LastActivityCard extends StatelessWidget {
  const _LastActivityCard({this.activity});

  final RunningActivity? activity;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final RunningActivity? last = activity;

    if (last == null) {
      return AppCard(
        child: Row(
          children: <Widget>[
            Icon(Icons.flag_outlined, color: scheme.onSurfaceVariant),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Nessuna attivita registrata. Premi CORSA LIBERA per iniziare.',
                style: TextStyle(color: scheme.onSurfaceVariant),
              ),
            ),
          ],
        ),
      );
    }

    return AppCard(
      onTap: () => Navigator.of(context)
          .pushNamed(AppRoutes.activityDetail, arguments: last.id),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  last.name,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Text(
                formatRelativeDay(last.startTime),
                style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 13),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: <Widget>[
              _MiniMetric(
                label: 'Distanza',
                value: formatDistanceKmWithUnit(last.distanceMeters),
              ),
              _MiniMetric(
                label: 'Tempo',
                value: formatDuration(last.duration),
              ),
              _MiniMetric(
                label: 'Passo',
                value: formatPaceWithUnit(last.averagePaceSecondsPerKm),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MiniMetric extends StatelessWidget {
  const _MiniMetric({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            label,
            style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}
