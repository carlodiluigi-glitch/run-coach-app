import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:provider/provider.dart';

import '../app/tokens.dart';
import '../models/running_activity.dart';
import '../providers/activity_provider.dart';
import '../services/elevation_service.dart';
import '../services/native_bridge.dart';
import '../widgets/app_card.dart';
import '../widgets/share_card.dart';

/// Guarda l'immagine della corsa, poi mandala.
///
/// PERCHE' SI VEDE PRIMA
/// ---------------------
/// Perche' quello che esce da qui finisce in una chat di gruppo, e non si manda
/// alla cieca una cosa che parla di te. Vedere l'immagine prima serve anche a
/// un'altra cosa: a controllare che il percorso disegnato non dica piu' di
/// quanto si vuole dire.
///
/// COME SI TRASFORMA IN IMMAGINE
/// -----------------------------
/// La scheda e' avvolta in un RepaintBoundary, cioe' un pezzo di schermo che
/// Flutter sa ridisegnare per conto suo. Da quello si ottiene l'immagine vera,
/// a tripla risoluzione, e quella e' la figura che parte - identica a quella
/// che si sta guardando, perche' e' proprio quella.
class ShareScreen extends StatefulWidget {
  const ShareScreen({super.key, required this.activityId});

  final String activityId;

  @override
  State<ShareScreen> createState() => _ShareScreenState();
}

class _ShareScreenState extends State<ShareScreen> {
  final GlobalKey _cardKey = GlobalKey();
  final NativeBridge _native = NativeBridge();

  bool _working = false;

  /// Quanto piu' grande dello schermo viene generata l'immagine.
  ///
  /// Tre volte: su un telefono moderno la scheda da 360 punti diventa 1080
  /// pixel di larghezza, che e' la misura che le chat non sgranano.
  static const double pixelRatio = 3.0;

  @override
  Widget build(BuildContext context) {
    final ActivityProvider provider = context.watch<ActivityProvider>();
    final RunningActivity? activity = provider.byId(widget.activityId);
    final AppPalette p = AppPalette.of(context);

    if (activity == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Condividi')),
        body: const Center(child: Text('Questa corsa non c\'e\' piu\'.')),
      );
    }

    final ElevationSummary dislivello =
        const ElevationService().of(activity.route);

    return Scaffold(
      appBar: AppBar(title: const Text('Condividi la corsa')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.screenSide,
            12,
            AppSpacing.screenSide,
            32,
          ),
          children: <Widget>[
            Center(
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(AppRadius.card),
                  border: Border.all(color: p.separator),
                ),
                clipBehavior: Clip.antiAlias,
                child: RepaintBoundary(
                  key: _cardKey,
                  child: ShareCard(
                    activity: activity,
                    elevation: dislivello,
                  ),
                ),
              ),
            ),

            const SizedBox(height: 20),
            SizedBox(
              height: 52,
              child: FilledButton.icon(
                onPressed: _working ? null : () => _share(activity),
                style: FilledButton.styleFrom(
                  backgroundColor: p.accent,
                  foregroundColor: p.onAccent,
                ),
                icon: const Icon(Icons.ios_share, size: 19),
                label: Text(_working ? 'Preparo...' : 'Condividi'),
              ),
            ),

            const SizedBox(height: 16),
            AppCard(
              child: Text(
                'L\'immagine viene salvata nella galleria, cartella Falcata, '
                'e poi Android ti chiede dove mandarla.\n\n'
                'Il disegno del percorso e\' in scala relativa: si vede la '
                'forma del giro, non il posto in cui l\'hai fatto. Nessuna '
                'coordinata e nessuna mappa escono da qui.',
                style: AppText.caption.copyWith(color: p.inkFaint),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _share(RunningActivity activity) async {
    setState(() => _working = true);
    final Uint8List? png = await _capture();
    if (!mounted) return;

    final bool ok = await _native.shareRunImage(
      png: png ?? Uint8List(0),
      text: ShareCard.textFor(activity),
    );
    if (!mounted) return;
    setState(() => _working = false);

    if (!ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Questo telefono non ha niente con cui condividere.'),
        ),
      );
    }
  }

  /// La scheda, diventata immagine. `null` se la cattura non riesce: in quel
  /// caso parte la condivisione del solo testo.
  Future<Uint8List?> _capture() async {
    try {
      final RenderObject? object =
          _cardKey.currentContext?.findRenderObject();
      if (object is! RenderRepaintBoundary) return null;
      final ui.Image image = await object.toImage(pixelRatio: pixelRatio);
      final ByteData? data =
          await image.toByteData(format: ui.ImageByteFormat.png);
      image.dispose();
      return data?.buffer.asUint8List();
    } catch (error) {
      debugPrint('ShareScreen: immagine non generata ($error)');
      return null;
    }
  }
}
