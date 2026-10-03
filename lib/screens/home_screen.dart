import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../app/app.dart';
import '../app/routes.dart';
import '../app/tokens.dart';
import '../models/daily_checkin.dart';
import '../models/run_snapshot.dart';
import '../models/running_activity.dart';
import '../models/training_plan.dart';
import '../providers/activity_provider.dart';
import '../providers/plan_provider.dart';
import '../providers/settings_provider.dart';
import '../services/readiness_engine.dart';
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

            // ------------------------------- una corsa che non si e' persa
            const _RecoveryCard(),

            // ------------------------------------------------- prontezza
            const _ReadinessCard(),

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
/// "Ho trovato una corsa interrotta."
///
/// Compare quando l'app e' stata chiusa mentre si correva - risparmio
/// energetico, memoria finita, un crash - e sul disco e' rimasta la corsa
/// scritta fino a quel momento.
///
/// Non la salva da sola: mostra cosa ha trovato e lascia decidere. Salvare di
/// nascosto una corsa che magari era un avvio per sbaglio significherebbe
/// sporcare l'archivio, e l'archivio e' la base di ogni stima che l'app fa.
class _RecoveryCard extends StatelessWidget {
  const _RecoveryCard();

  @override
  Widget build(BuildContext context) {
    final AppPalette p = AppPalette.of(context);
    final ActivityProvider activities = context.watch<ActivityProvider>();
    final RunSnapshot? corsa = activities.pendingRecovery;
    if (corsa == null) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: AppCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Icon(Icons.restore, size: 20, color: p.orange),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Ho trovato una corsa interrotta',
                    style: AppText.title.copyWith(color: p.ink, fontSize: 17),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              '${formatDateShort(corsa.startTime)}  ·  '
              '${formatDistanceWithUnit(corsa.distanceMeters)}  ·  '
              '${formatDuration(Duration(seconds: corsa.elapsedSeconds))}',
              style: AppText.body.copyWith(color: p.ink),
            ),
            const SizedBox(height: 6),
            Text(
              'L\'app si e\' chiusa mentre registravi. Questo e\' quello che '
              'era stato misurato fino a quel momento: gli ultimi secondi '
              'prima della chiusura non ci sono.',
              style: AppText.caption.copyWith(color: p.inkSoft),
            ),
            const SizedBox(height: 14),
            Row(
              children: <Widget>[
                Expanded(
                  child: SizedBox(
                    height: 46,
                    child: FilledButton(
                      onPressed: () => activities.keepRecovered(),
                      style: FilledButton.styleFrom(
                        backgroundColor: p.accent,
                        foregroundColor: p.onAccent,
                      ),
                      child: const Text('Salvala'),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                SizedBox(
                  height: 46,
                  child: TextButton(
                    onPressed: () => activities.discardRecovered(),
                    child: Text(
                      'Butta',
                      style: TextStyle(color: p.inkFaint),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Quanto sei pronto oggi, e cosa vuol dire per la seduta in programma.
///
/// PERCHE' STA IN CIMA ALLA HOME
/// -----------------------------
/// Perche' e' la domanda che uno si fa aprendo l'app la mattina. E perche' se
/// il motore ha qualcosa da dire - "ieri hai tirato, oggi tieniti facile" -
/// deve dirlo prima che tu esca di casa, non dopo.
///
/// Il numero non compare mai da solo: sotto c'e' sempre il primo motivo per
/// cui e' quello che e'. Un punteggio che non si puo' contestare e' un
/// oracolo, e un oracolo non si corregge.
class _ReadinessCard extends StatelessWidget {
  const _ReadinessCard();

  @override
  Widget build(BuildContext context) {
    final AppPalette p = AppPalette.of(context);
    final ActivityProvider activities = context.watch<ActivityProvider>();

    // Senza zone non c'e' carico, e senza carico la prontezza sarebbe solo il
    // check-in: si mostra lo stesso, ma solo se il check-in c'e'.
    final bool haCarico = activities.trainingZones != null &&
        !activities.trainingLoad.isEmpty;
    final DailyCheckIn? oggi = activities.todayCheckIn;
    if (!haCarico && oggi == null) return const SizedBox.shrink();

    final Readiness r = activities.readiness;

    Color colore() {
      switch (r.band) {
        case ReadinessBand.ready:
          return p.green;
        case ReadinessBand.normal:
          return p.blue;
        case ReadinessBand.easy:
          return p.orange;
        case ReadinessBand.rest:
          return p.red;
      }
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: AppCard(
        onTap: () => Navigator.of(context).pushNamed(AppRoutes.checkIn),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: <Widget>[
                Text(
                  'PRONTEZZA',
                  style: AppText.label.copyWith(color: p.inkFaint),
                ),
                const Spacer(),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                  decoration: BoxDecoration(
                    color: colore().withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                  ),
                  child: Text(
                    r.band.label,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: colore(),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: <Widget>[
                Text(
                  '${r.score}',
                  style: AppText.number(40, color: colore()),
                ),
                const SizedBox(width: 6),
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Text(
                    'su 100  ·  fiducia ${r.confidenceLabel}',
                    style: AppText.caption.copyWith(color: p.inkFaint),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              r.reasons.first,
              style: AppText.body.copyWith(
                color: r.blockedByPain ? p.red : p.inkSoft,
              ),
            ),
            if (r.reasons.length > 1) ...<Widget>[
              const SizedBox(height: 4),
              Text(
                r.reasons[1],
                style: AppText.caption.copyWith(color: p.inkFaint),
              ),
            ],
            const SizedBox(height: 12),
            Row(
              children: <Widget>[
                Icon(
                  oggi == null ? Icons.add_circle_outline : Icons.edit_outlined,
                  size: 16,
                  color: p.accent,
                ),
                const SizedBox(width: 6),
                Text(
                  oggi == null
                      ? 'Fai il check-in di stamattina'
                      : 'Modifica il check-in di oggi',
                  style: AppText.caption.copyWith(
                    color: p.accent,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _WeekCard extends StatelessWidget {
  const _WeekCard({required this.stats});

  final RunningStats stats;

  @override
  Widget build(BuildContext context) {
    final AppPalette p = AppPalette.of(context);
    // IL CONFRONTO SI FA CON LE SETTIMANE VERE
    //
    // Prima si divideva per quattro il totale delle ultime quattro settimane,
    // anche quando in tre di quelle l'app non era installata. A un atleta da
    // 60 km a settimana diceva "sopra la tua media di 10,5 km": un confronto
    // con un numero che non e' mai esistito.
    //
    // E' lo stesso difetto del punto di partenza del piano, quindi si usa la
    // stessa identica regola - mediana delle settimane intere, niente
    // confronto sotto le tre - invece di riscriverla qui. Due strade che
    // calcolano la stessa cosa finiscono sempre per divergere.
    final double? riferimento = stats.suggestedWeeklyKm;
    final bool hasHistory = riferimento != null;
    final double ratio = hasHistory
        ? stats.weekKm / riferimento
        : (stats.weekKm > 0 ? 1.0 : 0.0);

    final String note;
    if (!hasHistory) {
      note = stats.weekKm > 0
          ? 'Ancora poche settimane per un confronto'
          : 'Nessuna corsa questa settimana';
    } else if (stats.weekKm >= riferimento) {
      note = 'Sopra le tue ${riferimento.toStringAsFixed(0)} km di solito';
    } else {
      note = 'Di solito fai ${riferimento.toStringAsFixed(0)} km a settimana';
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

  /// L'avviso da mostrare sulla seduta di oggi, se ce n'e' uno.
  ///
  /// Due sole regole, le piu' nette:
  ///
  ///  - **dolore dichiarato** -> la qualita' non si fa. Non e' un consiglio.
  ///  - **prontezza bassa** -> la qualita' si sposta di un giorno, che costa
  ///    quasi niente e cambia parecchio.
  ///
  /// Su una seduta facile non si dice niente: un lento si corre anche stanchi,
  /// ed e' anzi il modo giusto di passare una giornata storta.
  String? _avviso(BuildContext context) {
    if (!session.isQuality) return null;
    final Readiness r = context.watch<ActivityProvider>().readiness;

    if (r.blockedByPain) {
      return 'Hai dichiarato un dolore. Oggi era in programma una seduta di '
          'qualita\': falla diventare un lento, o riposa. Le ripetute su un '
          'fastidio fanno un danno che nessun allenamento ripaga.';
    }
    if (!r.band.allowsQuality) {
      return 'Prontezza ${r.score} su 100: ${r.reasons.first.toLowerCase()}. '
          'Se puoi, sposta questa seduta a domani e oggi corri facile: un '
          'giorno di ritardo non cambia niente, una qualita\' fatta male '
          'costa una settimana.';
    }
    return null;
  }

  bool _avvisoGrave(BuildContext context) =>
      context.watch<ActivityProvider>().readiness.blockedByPain;

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

          // LA REAZIONE DEL MOTORE
          //
          // Il programma e' stato scritto settimane fa. Se oggi non sei nelle
          // condizioni di farlo, dirlo QUI - sulla scheda della seduta, prima
          // che tu esca - e' l'unico momento in cui serve a qualcosa.
          //
          // Non cambia il piano e non toglie il pulsante: l'ultima parola e'
          // dell'atleta. Dice quello che sa e lascia decidere.
          if (_avviso(context) != null) ...<Widget>[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.fromLTRB(11, 10, 11, 10),
              decoration: BoxDecoration(
                color: _avvisoGrave(context)
                    ? p.red.withValues(alpha: 0.12)
                    : p.orange.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(AppRadius.small + 2),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Icon(
                    _avvisoGrave(context)
                        ? Icons.report_gmailerrorred_outlined
                        : Icons.info_outline,
                    size: 17,
                    color: _avvisoGrave(context) ? p.red : p.orange,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _avviso(context)!,
                      style: AppText.caption.copyWith(
                        color: _avvisoGrave(context) ? p.red : p.orange,
                        height: 1.35,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
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
