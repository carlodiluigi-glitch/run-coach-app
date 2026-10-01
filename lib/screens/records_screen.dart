import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../app/routes.dart';
import '../app/tokens.dart';
import '../providers/activity_provider.dart';
import '../services/records_service.dart';
import '../utils/formatters.dart';
import '../widgets/app_card.dart';
import '../widgets/empty_state.dart';
import '../widgets/inset_list.dart';
import '../widgets/metric_card.dart';

/// Record personali: miglior tempo su ogni distanza classica, corsa piu'
/// lunga, settimana migliore.
class RecordsScreen extends StatelessWidget {
  const RecordsScreen({super.key});

  /// Sigla breve per il riquadro a sinistra della riga.
  ///
  /// "Mezza maratona" non ci sta in un quadrato di trenta pixel, quindi per
  /// le distanze lunghe si usano i chilometri arrotondati.
  static String _shortKey(String key) {
    switch (key) {
      case 'half':
        return '21K';
      case 'marathon':
        return '42K';
      default:
        return key.toUpperCase();
    }
  }

  @override
  Widget build(BuildContext context) {
    final ActivityProvider provider = context.watch<ActivityProvider>();
    final PersonalRecords records = provider.records;
    final AppPalette p = AppPalette.of(context);

    if (records.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('Record')),
        body: const EmptyState(
          icon: Icons.emoji_events_outlined,
          title: 'Nessun record ancora',
          message: 'I record si calcolano dalle corse registrate. '
              'Dopo la prima uscita compariranno qui.',
        ),
      );
    }

    final DateTime now = DateTime.now();

    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 44,
        backgroundColor: p.background,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
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
            Text('Record', style: AppText.largeTitle.copyWith(color: p.ink)),
            const SizedBox(height: 16),

            if (records.byDistance.isEmpty)
              AppCard(
                child: Row(
                  children: <Widget>[
                    Icon(Icons.info_outline, size: 20, color: p.inkFaint),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        records.activitiesWithGps == 0
                            ? 'Nessuna corsa ha ancora un tracciato GPS utilizzabile.'
                            : 'Nessuna corsa ha ancora raggiunto una distanza da record. '
                                'Il primo traguardo e\' il chilometro.',
                        style: AppText.body.copyWith(color: p.inkSoft),
                      ),
                    ),
                  ],
                ),
              )
            else
              InsetList(
                separatorIndent: 58,
                children: <Widget>[
                  for (final DistanceRecord record in records.byDistance)
                    _RecordRow(
                      record: record,
                      now: now,
                      declaredSeconds:
                          provider.declaredBestSeconds(record.distance.meters),
                    ),
                ],
              ),

            const SectionTitle('Altri primati'),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Expanded(
                  child: MetricCard(
                    label: 'Corsa piu lunga',
                    value: records.longestRun == null
                        ? kEmptyValue
                        : formatDistance(
                            records.longestRun!.distanceMeters,
                            decimals: 1,
                          ),
                    unit: records.longestRun == null ? null : 'km',
                    secondary: records.longestRun == null
                        ? null
                        : formatDateShort(records.longestRun!.startTime),
                    valueFontSize: 28,
                    onTap: records.longestRun == null
                        ? null
                        : () => Navigator.of(context).pushNamed(
                              AppRoutes.activityDetail,
                              arguments: records.longestRun!.id,
                            ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: MetricCard(
                    label: 'Settimana migliore',
                    value: records.bestWeekKm <= 0
                        ? kEmptyValue
                        : records.bestWeekKm.toStringAsFixed(1),
                    unit: records.bestWeekKm <= 0 ? null : 'km',
                    secondary: records.bestWeekStart == null
                        ? null
                        : 'dal ${formatDateShort(records.bestWeekStart!)}',
                    valueFontSize: 28,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 14),
            AppCard(
              padding: const EdgeInsets.fromLTRB(14, 13, 15, 14),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Icon(Icons.info_outline, size: 18, color: p.inkFaint),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Il record non e\' la corsa piu\' veloce su quella distanza, '
                      'ma il tratto piu\' veloce dentro una corsa qualsiasi: se '
                      'durante un lungo hai spinto per 5 km, quel tratto conta.',
                      style: AppText.caption.copyWith(color: p.inkFaint),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 14),
            Text(
              '${records.totalActivities} attivita registrate, '
              '${records.activitiesWithGps} con tracciato GPS.',
              style: AppText.caption.copyWith(color: p.inkFaint),
            ),
          ],
        ),
      ),
    );
  }
}

/// Una riga della lista dei record.
///
/// [declaredSeconds] e' il personale che l'atleta ha dichiarato a mano per
/// quella distanza. Quando e' piu' veloce di quello registrato, la riga smette
/// di chiamarsi "record": mostra il tempo dichiarato come primato e quello
/// misurato come il migliore **registrato con l'app**.
///
/// Prima non lo guardava nessuno, e la schermata dichiarava record un 10 km in
/// 54:44 a un atleta che nel profilo aveva scritto 44:00 - lo stesso numero su
/// cui il motore di forma costruisce l'indice.
class _RecordRow extends StatelessWidget {
  const _RecordRow({
    required this.record,
    required this.now,
    this.declaredSeconds,
  });

  final DistanceRecord record;
  final DateTime now;
  final int? declaredSeconds;

  @override
  Widget build(BuildContext context) {
    final AppPalette p = AppPalette.of(context);

    final int? dichiarato = declaredSeconds;
    final bool superato = dichiarato != null && dichiarato < record.seconds;

    // Un record fatto nelle ultime due settimane si colora: cosi' si vede
    // quale primato e' "caldo" senza leggere tutte le date. Un tempo gia'
    // battuto da un personale dichiarato non si colora mai.
    final bool recent =
        !superato && now.difference(record.date).inDays <= 14;
    final Color badgeColor = recent ? p.accent : (p.isDark ? p.surfaceElevated : Colors.black);

    return AppListRow(
      leading: Container(
        width: 30,
        height: 30,
        decoration: BoxDecoration(
          color: badgeColor,
          borderRadius: BorderRadius.circular(AppRadius.small),
        ),
        alignment: Alignment.center,
        child: Text(
          RecordsScreen._shortKey(record.distance.key),
          style: const TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.2,
            color: Colors.white,
          ),
        ),
      ),
      title: record.distance.label,
      subtitle: superato
          ? 'Dichiarato da te. Con l\'app: '
              '${formatDuration(Duration(seconds: record.seconds))} il '
              '${formatRelativeDay(record.date, now: now)}'
          : '${formatPaceWithUnit(record.paceSecPerKm)}  ·  '
              '${formatRelativeDay(record.date, now: now)}',
      value: formatDuration(
        Duration(seconds: superato ? dichiarato : record.seconds),
      ),
      valueColor: recent ? p.accent : p.ink,
      onTap: () => Navigator.of(context)
          .pushNamed(AppRoutes.activityDetail, arguments: record.activityId),
    );
  }
}
