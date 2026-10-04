import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../app/routes.dart';
import '../app/tokens.dart';
import '../models/estimate.dart';
import '../providers/activity_provider.dart';
import '../services/fitness_service.dart';
import '../services/pace_zone_engine.dart';
import '../services/run_index_engine.dart';
import '../services/training_load_engine.dart';
import '../utils/formatters.dart';
import '../widgets/app_card.dart';
import '../widgets/inset_list.dart';
import '../widgets/load_chart.dart';

/// Forma attuale: indice, zone di allenamento, previsioni di gara.
class FitnessScreen extends StatelessWidget {
  const FitnessScreen({super.key});

  static const FitnessService _fitness = FitnessService();

  @override
  Widget build(BuildContext context) {
    final ActivityProvider activities = context.watch<ActivityProvider>();
    final AppPalette p = AppPalette.of(context);

    final RunIndexResult result = activities.runIndex;
    final TrainingZones? zones = activities.trainingZones;
    final Estimate<double>? index = result.index;

    if (index == null || zones == null) {
      return _shell(
        context,
        children: <Widget>[
        AppCard(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Icon(Icons.timeline, size: 22, color: p.inkFaint),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      'Stima non disponibile',
                      style: AppText.title
                          .copyWith(color: p.ink, fontSize: 17),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      result.explanation,
                      style: AppText.body.copyWith(color: p.inkSoft),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        const _MethodCard(),
        ],
      );
    }

    return _shell(
      context,
      children: <Widget>[
        _IndexCard(result: result, index: index),

        const SectionTitle('Zone di allenamento'),
        InsetList(
          children: <Widget>[
            for (final ZonePace zone in zones.all)
              AppListRow(
                title: zone.label,
                subtitle: zone.purpose,
                showChevron: false,
                trailing: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Text(
                      '${formatPace(zone.range.low)} - '
                      '${formatPace(zone.range.high)}',
                      style: AppText.number(15, color: p.ink),
                    ),
                    Text(
                      '/km',
                      style:
                          AppText.caption.copyWith(color: p.inkFaint),
                    ),
                  ],
                ),
              ),
          ],
        ),
        Padding(
          padding: const EdgeInsets.only(left: 4, top: 8),
          child: Text(
            index.isStrong
                ? 'Le fasce sono strette perche\' ci sono abbastanza dati.'
                : 'Le fasce sono larghe di proposito: con pochi dati '
                    'una stima precisa sarebbe finta. Si stringono da '
                    'sole man mano che corri.',
            style: AppText.caption.copyWith(color: p.inkFaint),
          ),
        ),

        const SectionTitle('Previsioni di gara'),
        InsetList(
          children: <Widget>[
            for (final RacePrediction prediction in _fitness.predictions(
              index.value,
              result.samples.isEmpty
                  ? 5000
                  : result.samples.first.sample.meters,
            ))
              AppListRow(
                title: prediction.distance.label,
                subtitle:
                    '${formatPaceWithUnit(prediction.paceSecPerKm)}  ·  '
                    'fra ${formatDuration(Duration(seconds: prediction.bestCaseSeconds))} '
                    'e ${formatDuration(Duration(seconds: prediction.worstCaseSeconds))}',
                value: formatDuration(
                  Duration(seconds: prediction.seconds),
                ),
                showChevron: false,
              ),
          ],
        ),

        if (!activities.trainingLoad.isEmpty) ...<Widget>[
          const SectionTitle('Carico e freschezza'),
          _LoadCard(load: activities.trainingLoad),
        ],

        // IL NUMERO DI OGGI NON BASTA.
        //
        // "Condizione 48" dopo essere stato a 30 e "condizione 48" dopo essere
        // stato a 65 sono la stessa riga e due situazioni opposte. Il grafico
        // e' l'unico modo di far vedere quale delle due.
        //
        // Il grafico finisce esattamente sul numero scritto sopra, perche' e'
        // lo stesso conto: l'ultimo punto della serie E' lo stato di oggi.
        if (LoadChart.canDraw(activities.loadSeries())) ...<Widget>[
          const SectionTitle('Gli ultimi mesi'),
          AppCard(
            padding: const EdgeInsets.fromLTRB(12, 14, 12, 12),
            child: LoadChart(points: activities.loadSeries()),
          ),
          Padding(
            padding: const EdgeInsets.only(left: 4, top: 8),
            child: Text(
              'La linea spessa sale piano e scende piano: e\' quanto sei '
              'allenato. La sottile sale subito dopo una seduta dura e scende '
              'in pochi giorni: e\' la fatica. Quando la sottile sta sopra '
              'per settimane, stai portando piu\' carico di quanto il corpo '
              'riesca a trasformare in allenamento.',
              style: AppText.caption.copyWith(color: p.inkFaint),
            ),
          ),
        ],

        if (result.samples.isNotEmpty) ...<Widget>[
          const SectionTitle('Su cosa e\' basato'),
          _EvidenceList(samples: result.samples),
        ],

        if (result.profileBias != null) ...<Widget>[
          const SectionTitle('Che tipo di corridore sei'),
          _BiasCard(bias: result.profileBias!),
        ],

        const SizedBox(height: 14),
        const _MethodCard(),

        const SizedBox(height: 14),
        SizedBox(
          height: 54,
          child: FilledButton.icon(
            onPressed: () =>
                Navigator.of(context).pushNamed(AppRoutes.plan),
            style: FilledButton.styleFrom(
              backgroundColor: p.accent,
              foregroundColor: p.onAccent,
            ),
            icon: const Icon(Icons.calendar_month_rounded),
            label: const Text('Costruisci un piano con questi ritmi'),
          ),
        ),
      ],
    );
  }

  /// Struttura comune della schermata: barra, titolo, lista.
  Widget _shell(BuildContext context, {required List<Widget> children}) {
    final AppPalette p = AppPalette.of(context);
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
            Text('Forma', style: AppText.largeTitle.copyWith(color: p.ink)),
            const SizedBox(height: 16),
            ...children,

            // Sempre in fondo, anche quando la stima non c'e': se l'indice
            // e' piu' basso di quello che l'atleta sa di valere, questa e'
            // la strada per dirlo al motore.
            const SizedBox(height: 18),
            InsetList(
              children: <Widget>[
                AppListRow(
                  title: 'Profilo e personali',
                  subtitle: 'L\'indice non ti rende giustizia? Dichiara le '
                      'tue gare: pesano piu\' di qualsiasi corsa registrata.',
                  onTap: () =>
                      Navigator.of(context).pushNamed(AppRoutes.profile),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _IndexCard extends StatelessWidget {
  const _IndexCard({required this.result, required this.index});

  final RunIndexResult result;
  final Estimate<double> index;

  @override
  Widget build(BuildContext context) {
    final AppPalette p = AppPalette.of(context);

    Color confidenceColor() {
      if (index.isStrong) return p.green;
      if (index.isWeak) return p.orange;
      return p.blue;
    }

    return AppCard(
      padding: const EdgeInsets.fromLTRB(16, 15, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            'INDICE DI FORMA',
            style: AppText.label.copyWith(color: p.inkFaint),
          ),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: <Widget>[
              Text(
                index.value.toStringAsFixed(1),
                style: AppText.number(46, color: p.accent),
              ),
              const SizedBox(width: 10),
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                  decoration: BoxDecoration(
                    color: confidenceColor().withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                  ),
                  child: Text(
                    'fiducia ${index.confidenceLabel}',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: confidenceColor(),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            result.explanation,
            style: AppText.caption.copyWith(color: p.inkSoft),
          ),
        ],
      ),
    );
  }
}

/// Quanto stai caricando e quanto sei fresco.
///
/// PERCHE' STA QUI
/// ---------------
/// L'indice di forma dice quanto vai forte. Questi due numeri dicono quanto ti
/// sta costando arrivarci, ed e' l'altra meta' della stessa domanda: si puo'
/// essere in forma e cotti nello stesso momento, ed e' il momento in cui ci si
/// fa male.
///
/// Come per l'indice, nessun numero compare senza una riga che lo spiega.
class _LoadCard extends StatelessWidget {
  const _LoadCard({required this.load});

  final TrainingLoadState load;

  @override
  Widget build(BuildContext context) {
    final AppPalette p = AppPalette.of(context);
    final double? rapporto = load.loadRatio;

    Color tono() {
      if (!load.isReliable || rapporto == null) return p.inkFaint;
      if (rapporto >= 1.35) return p.red;
      if (rapporto >= 1.15) return p.orange;
      if (rapporto <= 0.75) return p.blue;
      return p.green;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text('FATICA',
                            style: AppText.label.copyWith(color: p.inkFaint)),
                        const SizedBox(height: 4),
                        Text(load.fatigue.toStringAsFixed(0),
                            style: AppText.number(30, color: p.ink)),
                        Text('ultimi 7 giorni',
                            style:
                                AppText.caption.copyWith(color: p.inkFaint)),
                      ],
                    ),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text('CONDIZIONE',
                            style: AppText.label.copyWith(color: p.inkFaint)),
                        const SizedBox(height: 4),
                        Text(load.fitness.toStringAsFixed(0),
                            style: AppText.number(30, color: p.ink)),
                        Text('ultimi 28 giorni',
                            style:
                                AppText.caption.copyWith(color: p.inkFaint)),
                      ],
                    ),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text('FRESCHEZZA',
                            style: AppText.label.copyWith(color: p.inkFaint)),
                        const SizedBox(height: 4),
                        Text(
                          load.freshness >= 0
                              ? '+${load.freshness.toStringAsFixed(0)}'
                              : load.freshness.toStringAsFixed(0),
                          style: AppText.number(30, color: tono()),
                        ),
                        Text('la differenza',
                            style:
                                AppText.caption.copyWith(color: p.inkFaint)),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Text(load.headline, style: AppText.body.copyWith(color: p.ink)),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(left: 4, top: 8),
          child: Text(
            'Il carico di ogni seduta si misura in sforzo, non in chilometri: '
            '100 punti sono un\'ora a ritmo soglia. La fatica e\' la media '
            'degli ultimi sette giorni, la condizione quella degli ultimi '
            'ventotto. Positiva vuol dire riposato rispetto al tuo solito, '
            'negativa vuol dire che stai portando piu\' carico del normale - '
            'che e\' giusto in carico e sbagliato prima di una gara.',
            style: AppText.caption.copyWith(color: p.inkFaint),
          ),
        ),
      ],
    );
  }
}

/// L'elenco delle prestazioni su cui l'indice e' costruito.
///
/// PERCHE' ESISTE QUESTA SEZIONE
/// -----------------------------
/// Un numero senza le sue prove e' un oracolo, e un oracolo non si puo'
/// correggere. Se l'indice dice 45,4 e l'atleta pensa di valere 47, l'unica
/// domanda utile e' "su cosa ti stai basando?". Qui c'e' la risposta, riga per
/// riga: la prestazione, quando, quanto pesa, e che indice suggerirebbe da
/// sola.
///
/// Toccando una riga si apre la corsa da cui viene, quando ce n'e' una: i
/// personali dichiarati a mano non hanno una corsa dietro.
class _EvidenceList extends StatelessWidget {
  const _EvidenceList({required this.samples});

  final List<WeightedSample> samples;

  /// Quante righe mostrare. Oltre la decima si entra nella coda di
  /// prestazioni che pesano quasi zero: allungare la lista non informa, fa
  /// solo scorrere.
  static const int maxRighe = 10;

  String _quando(int ageDays) {
    if (ageDays <= 0) return 'oggi';
    if (ageDays == 1) return 'ieri';
    if (ageDays < 14) return '$ageDays giorni fa';
    if (ageDays < 60) return '${(ageDays / 7).round()} settimane fa';
    return '${(ageDays / 30).round()} mesi fa';
  }

  @override
  Widget build(BuildContext context) {
    final AppPalette p = AppPalette.of(context);
    final List<WeightedSample> mostrate =
        samples.length > maxRighe ? samples.sublist(0, maxRighe) : samples;

    final int nascoste = samples.length - mostrate.length;
    final String coda = nascoste == 0
        ? ''
        : 'Ci sono anche $nascoste prove piu\' leggere, non elencate. ';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        InsetList(
          children: <Widget>[
            for (final WeightedSample s in mostrate)
              AppListRow(
                title: s.sample.label ??
                    formatDistanceWithUnit(s.sample.meters),
                subtitle: '${formatDuration(Duration(seconds: s.sample.seconds))}'
                    '  ·  ${s.sample.source.label}  ·  '
                    '${_quando(s.ageDays)}',
                onTap: s.sample.activityId == null
                    ? null
                    : () => Navigator.of(context).pushNamed(
                          AppRoutes.activityDetail,
                          arguments: s.sample.activityId,
                        ),
                showChevron: s.sample.activityId != null,
                trailing: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Text(
                      s.rawIndex.toStringAsFixed(1),
                      style: AppText.number(16, color: p.ink),
                    ),
                    const SizedBox(height: 5),
                    _WeightBar(weight: s.weight),
                  ],
                ),
              ),
          ],
        ),
        Padding(
          padding: const EdgeInsets.only(left: 4, top: 8),
          child: Text(
            'Il numero e\' l\'indice che quella prova, da sola, '
            'suggerirebbe. La barra sotto e\' quanto pesa: scende con il '
            'tempo e con l\'incertezza di come e\' stata misurata. $coda'
            'L\'indice non e\' la media di questi numeri: e\' dove sono '
            'arrivate, una conferma alla volta.',
            style: AppText.caption.copyWith(color: p.inkFaint),
          ),
        ),
      ],
    );
  }
}

/// Barretta che mostra il peso di una prestazione, da 0 a 1.
class _WeightBar extends StatelessWidget {
  const _WeightBar({required this.weight});

  final double weight;

  static const double fullWidth = 46;

  @override
  Widget build(BuildContext context) {
    final AppPalette p = AppPalette.of(context);
    final double fraction = weight.clamp(0.0, 1.0);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        SizedBox(
          width: fullWidth,
          height: 4,
          child: Stack(
            children: <Widget>[
              Container(
                decoration: BoxDecoration(
                  color: p.separator,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              FractionallySizedBox(
                widthFactor: fraction < 0.04 ? 0.04 : fraction,
                child: Container(
                  decoration: BoxDecoration(
                    color: p.accent,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 3),
        Text(
          'peso ${(fraction * 100).round()}%',
          style: AppText.caption.copyWith(color: p.inkFaint, fontSize: 11),
        ),
      ],
    );
  }
}

class _BiasCard extends StatelessWidget {
  const _BiasCard({required this.bias});

  final Estimate<double> bias;

  @override
  Widget build(BuildContext context) {
    final AppPalette p = AppPalette.of(context);

    // La posizione sulla barra: -6 punti = velocista puro, +6 = fondista.
    final double position = ((bias.value + 6) / 12).clamp(0.0, 1.0);

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            bias.note ?? '',
            style: AppText.body.copyWith(color: p.ink),
          ),
          const SizedBox(height: 14),
          LayoutBuilder(
            builder: (BuildContext context, BoxConstraints constraints) {
              final double width = constraints.maxWidth;
              return SizedBox(
                height: 26,
                child: Stack(
                  children: <Widget>[
                    Positioned(
                      left: 0,
                      right: 0,
                      top: 10,
                      child: Container(
                        height: 5,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(3),
                          gradient: LinearGradient(
                            colors: <Color>[p.blue, p.separator, p.accent],
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      left: (width - 14) * position,
                      top: 4,
                      child: Container(
                        width: 14,
                        height: 18,
                        decoration: BoxDecoration(
                          color: p.ink,
                          borderRadius: BorderRadius.circular(7),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
          const SizedBox(height: 6),
          Row(
            children: <Widget>[
              Text('Velocista',
                  style: AppText.caption.copyWith(color: p.inkFaint)),
              const Spacer(),
              Text('Fondista',
                  style: AppText.caption.copyWith(color: p.inkFaint)),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'Fiducia ${bias.confidenceLabel}. Serve molta piu\' evidenza per '
            'dire che tipo sei che per stimare il tuo ritmo: finche\' non ci '
            'sono prove su distanze diverse, questa riga vale poco.',
            style: AppText.caption.copyWith(color: p.inkFaint),
          ),
        ],
      ),
    );
  }
}

class _MethodCard extends StatelessWidget {
  const _MethodCard();

  @override
  Widget build(BuildContext context) {
    final AppPalette p = AppPalette.of(context);

    return AppCard(
      padding: const EdgeInsets.fromLTRB(14, 13, 15, 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(Icons.info_outline, size: 18, color: p.inkFaint),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'L\'indice nasce dalle tue prestazioni, pesate per quanto sono '
              'affidabili: una gara conta piu\' di un tratto veloce dentro una '
              'corsa normale, e una corsa che hai dichiarato facile non conta '
              'quasi niente. Nessuna singola giornata puo\' spostarlo di molto: '
              'serve conferma. E non scende perche\' hai corso piano, ma solo '
              'se passano settimane senza prove.',
              style: AppText.caption.copyWith(color: p.inkFaint),
            ),
          ),
        ],
      ),
    );
  }
}
