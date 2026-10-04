import 'package:flutter/material.dart';

import '../app/tokens.dart';
import '../models/running_activity.dart';
import '../services/elevation_service.dart';
import '../utils/formatters.dart';
import 'route_shape.dart';

/// L'immagine della corsa, quella che finisce su WhatsApp.
///
/// PERCHE' UN'APP DI CORSA HA BISOGNO DI QUESTO
/// --------------------------------------------
/// Perche' e' il modo in cui le app di corsa si fanno conoscere senza
/// pubblicita'. Ogni corsa condivisa e' una persona che la vede e chiede "con
/// cosa l'hai fatta". Per un'app che si compra una volta sola e non ha un
/// budget di marketing, quel passaparola non e' un di piu': e' il canale.
///
/// COSA CI VA DENTRO, E COSA NO
/// ----------------------------
/// Ci va quello che si guarda in due secondi scorrendo una chat: distanza,
/// tempo, passo, la forma del giro. Non ci vanno i dettagli che interessano
/// solo a chi ha corso - i parziali, il carico, l'indice di forma - perche'
/// riempirebbero l'immagine di numeri che chi la riceve non legge, e la cosa
/// che rende riconoscibile un'immagine condivisa e' che sia vuota.
///
/// NON CI VA NEMMENO DOVE ABITI. Il disegno del percorso e' in scala relativa,
/// senza coordinate e senza mappa: si vede la forma del giro, non il posto.
/// Chi condivide una corsa non sta scegliendo di pubblicare il proprio
/// indirizzo, e l'app non deve fargliene prendere la decisione per sbaglio.
class ShareCard extends StatelessWidget {
  const ShareCard({
    super.key,
    required this.activity,
    required this.elevation,
  });

  final RunningActivity activity;
  final ElevationSummary elevation;

  /// Il testo che accompagna l'immagine.
  static String textFor(RunningActivity activity) {
    final String km = formatDistance(activity.distanceMeters, decimals: 2);
    final String tempo = formatDuration(activity.duration);
    final String passo = formatPace(activity.averagePaceSecondsPerKm);
    return '$km km in $tempo a $passo/km. Registrata con Falcata.';
  }

  @override
  Widget build(BuildContext context) {
    final AppPalette p = AppPalette.of(context);
    final bool conPercorso = RouteShape.canDraw(activity.route);

    // Misura fissa: l'immagine deve venire uguale su ogni telefono, quindi non
    // dipende dalla larghezza dello schermo. 1080 x 1350 e' il formato che
    // Instagram e WhatsApp non tagliano.
    return Container(
      width: 360,
      height: 450,
      color: p.background,
      padding: const EdgeInsets.fromLTRB(26, 24, 26, 22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Container(
                width: 9,
                height: 9,
                decoration: BoxDecoration(
                  color: p.accent,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'FALCATA',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 2.2,
                  color: p.inkSoft,
                ),
              ),
              const Spacer(),
              Text(
                formatDateShort(activity.startTime),
                style: AppText.caption.copyWith(color: p.inkFaint),
              ),
            ],
          ),

          const SizedBox(height: 18),
          Text(
            formatDistance(activity.distanceMeters),
            style: AppText.number(64, color: p.ink).copyWith(height: 1.0),
          ),
          Text(
            'chilometri',
            style: AppText.caption.copyWith(color: p.inkFaint),
          ),

          const SizedBox(height: 16),
          Row(
            children: <Widget>[
              _Voce(
                etichetta: 'Tempo',
                valore: formatDuration(activity.duration),
              ),
              const SizedBox(width: 26),
              _Voce(
                etichetta: 'Passo',
                valore: formatPace(activity.averagePaceSecondsPerKm),
                unita: '/km',
              ),
              if (elevation.isKnown && !elevation.isFlat) ...<Widget>[
                const SizedBox(width: 26),
                _Voce(
                  etichetta: 'Dislivello',
                  valore: '${elevation.gainMeters.round()}',
                  unita: 'm',
                ),
              ],
            ],
          ),

          const SizedBox(height: 10),
          Expanded(
            child: conPercorso
                ? RouteShape(
                    route: activity.route,
                    height: double.infinity,
                    strokeWidth: 3.2,
                  )
                : Center(
                    child: Text(
                      activity.name,
                      textAlign: TextAlign.center,
                      style: AppText.title.copyWith(color: p.inkFaint),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

class _Voce extends StatelessWidget {
  const _Voce({
    required this.etichetta,
    required this.valore,
    this.unita,
  });

  final String etichetta;
  final String valore;
  final String? unita;

  @override
  Widget build(BuildContext context) {
    final AppPalette p = AppPalette.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Text(
          etichetta.toUpperCase(),
          style: TextStyle(
            fontSize: 9.5,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.1,
            color: p.inkFaint,
          ),
        ),
        const SizedBox(height: 3),
        Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text(valore, style: AppText.number(22, color: p.ink)),
            if (unita != null) ...<Widget>[
              const SizedBox(width: 2),
              Text(
                unita!,
                style: AppText.caption.copyWith(color: p.inkFaint),
              ),
            ],
          ],
        ),
      ],
    );
  }
}
