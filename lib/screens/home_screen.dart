import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../app/app.dart';
import '../app/routes.dart';
import '../models/running_activity.dart';
import '../providers/activity_provider.dart';
import '../providers/settings_provider.dart';
import '../services/stats_service.dart';
import '../utils/formatters.dart';
import '../widgets/app_card.dart';
import '../widgets/metric_card.dart';

/// Schermata iniziale: saluto, riepilogo e accessi rapidi.
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

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
