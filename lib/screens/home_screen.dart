import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../app/app.dart';
import '../app/routes.dart';
import '../app/tokens.dart';
import '../models/running_activity.dart';
import '../models/training_plan.dart';
import '../providers/activity_provider.dart';
import '../providers/plan_provider.dart';
import '../providers/settings_provider.dart';
import '../services/stats_service.dart';
import '../utils/formatters.dart';
import '../widgets/app_card.dart';
import '../widgets/inset_list.dart';
import '../widgets/metric_display.dart';

/// Schermata iniziale: a che punto sei questa settimana, come si parte, dove
/// si va.
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final SettingsProvider settings = context.watch<SettingsProvider>();
    final ActivityProvider activities = context.watch<ActivityProvider>();
    final PlanProvider plans = context.watch<PlanProvider>();
    final RunningStats stats = activities.stats;
    final AppPalette p = AppPalette.of(context);

    final List<PlannedSession> todaySessions = plans.sessionsOn(DateTime.now());
    final PlannedSession? today =
        todaySessions.isEmpty ? null : todaySessions.first;

    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.screenSide,
            8,
            AppSpacing.screenSide,
            32,
          ),
          children: <Widget>[
            // ------------------------------------------------ intestazione
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        RunCoachApp.appName.toUpperCase(),
                        style: AppText.label.copyWith(color: p.accent),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        settings.settings.greeting,
                        style: AppText.largeTitle.copyWith(color: p.ink),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () =>
                      Navigator.of(context).pushNamed(AppRoutes.settings),
                  icon: Icon(Icons.settings_outlined, size: 26, color: p.inkSoft),
                  tooltip: 'Impostazioni',
                ),
              ],
            ),
            const SizedBox(height: 14),

            // -------------------------------------------- questa settimana
            _WeekCard(stats: stats),

            if (today != null) ...<Widget>[
              const SectionTitle('Oggi in programma'),
              _TodayCard(session: today),
            ],

            const SizedBox(height: 14),

            // ------------------------------------------------- come partire
            Row(
              children: <Widget>[
                Expanded(
                  child: _StartTile(
                    background: p.isDark ? p.surfaceElevated : Colors.black,
                    foreground: Colors.white,
                    overline: 'Parti subito',
                    title: 'Corsa libera',
                    icon: Icons.directions_run_rounded,
                    onTap: () =>
                        Navigator.of(context).pushNamed(AppRoutes.run),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _StartTile(
                    background: p.accent,
                    foreground: p.onAccent,
                    overline: 'Programmato',
                    title: 'Allenamenti',
                    icon: Icons.repeat_rounded,
                    onTap: () => Navigator.of(context)
                        .pushNamed(AppRoutes.workoutLibrary),
                  ),
                ),
              ],
            ),

            // ------------------------------------------------ ultima uscita
            const SectionTitle('Ultima uscita'),
            _LastActivityCard(activity: stats.lastActivity),

            // -------------------------------------------------------- vai a
            const SectionTitle('Vai a'),
            InsetList(
              separatorIndent: 58,
              children: <Widget>[
                AppListRow(
                  leading: IconSquare(
                    icon: Icons.calendar_month_rounded,
                    color: p.accent,
                  ),
                  title: 'Piano di allenamento',
                  subtitle: plans.hasPlan
                      ? plans.config!.goal.label
                      : 'Nessun piano attivo',
                  onTap: () => Navigator.of(context).pushNamed(AppRoutes.plan),
                ),
                AppListRow(
                  leading: IconSquare(
                    icon: Icons.speed_rounded,
                    color: p.blue,
                  ),
                  title: 'Forma e previsioni',
                  subtitle: 'Passi di allenamento e tempi di gara',
                  onTap: () =>
                      Navigator.of(context).pushNamed(AppRoutes.fitness),
                ),
                AppListRow(
                  leading: IconSquare(
                    icon: Icons.person_rounded,
                    color: p.green,
                  ),
                  title: 'Profilo e personali',
                  subtitle: 'Cosa sai fare: serve al motore per non sbagliare',
                  onTap: () =>
                      Navigator.of(context).pushNamed(AppRoutes.profile),
                ),
                AppListRow(
                  leading: IconSquare(
                    icon: Icons.emoji_events_rounded,
                    color: p.orange,
                  ),
                  title: 'Record personali',
                  subtitle: 'Quelli misurati dall\'app durante le corse',
                  onTap: () =>
                      Navigator.of(context).pushNamed(AppRoutes.records),
                ),
                AppListRow(
                  leading: IconSquare(
                    icon: Icons.format_list_bulleted_rounded,
                    color: p.inkSoft,
                  ),
                  title: 'Storico',
                  subtitle: stats.totalActivities == 0
                      ? null
                      : '${stats.totalActivities} attivita registrate',
                  onTap: () =>
                      Navigator.of(context).pushNamed(AppRoutes.history),
                ),
                AppListRow(
                  leading: IconSquare(
                    icon: Icons.show_chart_rounded,
                    color: p.green,
                  ),
                  title: 'Statistiche',
                  onTap: () => Navigator.of(context).pushNamed(AppRoutes.stats),
                ),
                AppListRow(
                  leading: IconSquare(
                    icon: Icons.directions_walk_rounded,
                    color: p.blue,
                  ),
                  title: 'Scarpe',
                  onTap: () => Navigator.of(context).pushNamed(AppRoutes.shoes),
                ),
                AppListRow(
                  leading: IconSquare(
                    icon: Icons.settings_rounded,
                    color: p.inkFaint,
                  ),
                  title: 'Impostazioni',
                  onTap: () =>
                      Navigator.of(context).pushNamed(AppRoutes.settings),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Riepilogo della settimana in corso, confrontato con le quattro precedenti.
///
/// Il confronto con la media e' piu' utile di un totale secco: dice se stai
/// facendo piu' o meno del solito, che e' la domanda vera.
class _WeekCard extends StatelessWidget {
  const _WeekCard({required this.stats});

  final RunningStats stats;

  @override
  Widget build(BuildContext context) {
    final AppPalette p = AppPalette.of(context);
    final double averageKm = stats.lastFourWeeksKm / 4.0;
    final bool hasHistory = averageKm >= 0.5;
    final double ratio = hasHistory
        ? stats.weekKm / averageKm
        : (stats.weekKm > 0 ? 1.0 : 0.0);

    final String note;
    if (!hasHistory) {
      note = stats.weekKm > 0
          ? 'La tua prima settimana di dati'
          : 'Nessuna corsa questa settimana';
    } else if (stats.weekKm >= averageKm) {
      note = 'Sopra la tua media di ${averageKm.toStringAsFixed(1)} km';
    } else {
      note = 'Media delle ultime 4 settimane: '
          '${averageKm.toStringAsFixed(1)} km';
    }

    return AppCard(
      padding: const EdgeInsets.fromLTRB(16, 15, 16, 16),
      child: Row(
        children: <Widget>[
          ProgressRing(
            value: ratio,
            color: p.accent,
            trackColor: p.surfaceElevated,
            size: 64,
            thickness: 9,
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text(
                  'QUESTA SETTIMANA',
                  style: AppText.label.copyWith(color: p.inkFaint),
                ),
                const SizedBox(height: 7),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: <Widget>[
                    Text(
                      stats.weekKm.toStringAsFixed(1),
                      style: AppText.number(34, color: p.ink),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'km',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: p.inkFaint,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      stats.weekActivities == 1
                          ? '1 uscita'
                          : '${stats.weekActivities} uscite',
                      style: AppText.caption.copyWith(color: p.inkFaint),
                    ),
                  ],
                ),
                const SizedBox(height: 5),
                Text(
                  note,
                  style: AppText.caption.copyWith(color: p.inkFaint),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Uno dei due riquadri colorati per iniziare a correre.
class _StartTile extends StatelessWidget {
  const _StartTile({
    required this.background,
    required this.foreground,
    required this.overline,
    required this.title,
    required this.icon,
    required this.onTap,
  });

  final Color background;
  final Color foreground;
  final String overline;
  final String title;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: background,
      borderRadius: BorderRadius.circular(AppRadius.card),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 13, 14, 15),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Expanded(
                    child: Text(
                      overline.toUpperCase(),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppText.label.copyWith(
                        color: foreground.withValues(alpha: 0.75),
                      ),
                    ),
                  ),
                  Icon(icon, size: 19, color: foreground.withValues(alpha: 0.9)),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                title,
                style: AppText.title.copyWith(color: foreground),
              ),
            ],
          ),
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
    final AppPalette p = AppPalette.of(context);
    final RunningActivity? last = activity;

    if (last == null) {
      return AppCard(
        child: Row(
          children: <Widget>[
            Icon(Icons.flag_outlined, color: p.inkFaint),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Nessuna attivita registrata. Premi Corsa libera per iniziare.',
                style: AppText.body.copyWith(color: p.inkSoft),
              ),
            ),
          ],
        ),
      );
    }

    return AppCard(
      onTap: () => Navigator.of(context)
          .pushNamed(AppRoutes.activityDetail, arguments: last.id),
      padding: const EdgeInsets.fromLTRB(16, 14, 12, 15),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  last.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppText.title.copyWith(color: p.ink),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                formatRelativeDay(last.startTime),
                style: AppText.caption.copyWith(color: p.inkFaint),
              ),
              Icon(Icons.chevron_right, size: 20, color: p.separator),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: <Widget>[
              _MiniMetric(
                label: 'Distanza',
                value: formatDistanceWithUnit(last.distanceMeters),
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

/// La seduta prevista dal piano per oggi, con il pulsante per eseguirla.
class _TodayCard extends StatelessWidget {
  const _TodayCard({required this.session});

  final PlannedSession session;

  @override
  Widget build(BuildContext context) {
    final AppPalette p = AppPalette.of(context);
    final Color tone =
        session.kind == SessionKind.easy ? p.inkFaint : p.accent;

    return AppCard(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 15),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(color: tone, shape: BoxShape.circle),
              ),
              const SizedBox(width: 8),
              Text(
                session.kind.label.toUpperCase(),
                style: AppText.label.copyWith(color: tone),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(session.title, style: AppText.title.copyWith(color: p.ink)),
          const SizedBox(height: 6),
          Text(
            session.detail,
            style: AppText.caption.copyWith(color: p.inkSoft),
          ),
          if (session.kind != SessionKind.race) ...<Widget>[
            const SizedBox(height: 12),
            SizedBox(
              height: 46,
              child: FilledButton.icon(
                onPressed: () => Navigator.of(context).pushNamed(
                  AppRoutes.run,
                  arguments: session.workout,
                ),
                style: FilledButton.styleFrom(
                  backgroundColor: p.accent,
                  foregroundColor: p.onAccent,
                ),
                icon: const Icon(Icons.play_arrow_rounded),
                label: Text(session.hasWorkout ? 'Esegui' : 'Parti'),
              ),
            ),
          ],
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
    final AppPalette p = AppPalette.of(context);
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            label.toUpperCase(),
            style: AppText.label.copyWith(color: p.inkFaint),
          ),
          const SizedBox(height: 4),
          Text(value, style: AppText.number(17, color: p.ink)),
        ],
      ),
    );
  }
}
