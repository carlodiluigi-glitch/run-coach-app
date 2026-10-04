import 'package:flutter/material.dart';

import '../app/tokens.dart';
import '../models/license.dart';
import '../widgets/app_card.dart';

/// Cosa c'e' dentro Falcata completa, e quanto costa.
///
/// COME E' SCRITTA, E PERCHE'
/// --------------------------
/// Le schermate di acquisto sono quasi sempre scritte per mettere fretta:
/// "offerta", "solo oggi", un timer che scende. Funzionano una volta e poi
/// bruciano la fiducia, e un'app che si compra una volta sola vive di
/// passaparola - cioe' esattamente di fiducia.
///
/// Quindi qui si dice la verita' in ordine: cosa resta gratis per sempre, cosa
/// si paga, quanto, e che si paga una volta. Nessuna scadenza, nessun prezzo
/// barrato, nessun abbonamento nascosto in fondo.
class UnlockScreen extends StatelessWidget {
  const UnlockScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final AppPalette p = AppPalette.of(context);

    final List<Feature> gratis =
        Feature.values.where((Feature f) => f.isFree).toList();
    final List<Feature> complete =
        Feature.values.where((Feature f) => !f.isFree).toList();

    return Scaffold(
      appBar: AppBar(title: const Text('Falcata completa')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.screenSide,
            8,
            AppSpacing.screenSide,
            32,
          ),
          children: <Widget>[
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    'Un allenatore, non un contachilometri',
                    style: AppText.title.copyWith(color: p.ink),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Tutto quello che fa una normale app di corsa, in Falcata '
                    'e\' gratis e resta gratis. Si paga solo la parte che le '
                    'altre non hanno: il piano che si scrive sui giorni che hai '
                    'davvero, i passi calcolati sulla tua forma di adesso, e il '
                    'conto di quanto ti stai caricando.\n\n'
                    'Una volta sola. Nessun abbonamento.',
                    style: AppText.body.copyWith(color: p.inkSoft),
                  ),
                ],
              ),
            ),

            const SectionTitle('Gratis, per sempre'),
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  for (final Feature f in gratis)
                    _Riga(feature: f, inclusa: true),
                ],
              ),
            ),

            const SectionTitle('Con Falcata completa'),
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  for (final Feature f in complete)
                    _Riga(feature: f, inclusa: false),
                ],
              ),
            ),

            const SizedBox(height: 20),
            if (LicenseState.developerUnlocked)
              AppCard(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Icon(Icons.info_outline, size: 18, color: p.blue),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Falcata non e\' ancora sul Play Store, quindi per ora '
                        'hai tutto aperto. Quando ci sara\', questa schermata '
                        'avra\' il pulsante per comprare: '
                        '${LicenseState.priceLabel}, una volta sola.',
                        style: AppText.body.copyWith(color: p.inkSoft),
                      ),
                    ),
                  ],
                ),
              )
            else ...<Widget>[
              SizedBox(
                height: 54,
                child: FilledButton(
                  onPressed: null,
                  style: FilledButton.styleFrom(
                    backgroundColor: p.accent,
                    foregroundColor: p.onAccent,
                  ),
                  child: Text(
                    'Sblocca tutto - ${LicenseState.priceLabel}',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(left: 4, top: 10),
                child: Text(
                  'Pagamento una volta sola, gestito dal Play Store. Niente '
                  'rinnovi, niente scadenze. Se cambi telefono lo riprendi '
                  'con lo stesso account Google, senza ripagare.',
                  style: AppText.caption.copyWith(color: p.inkFaint),
                ),
              ),
            ],

            const SizedBox(height: 22),
            AppCard(
              child: Text(
                'Le corse che hai registrato restano tue in ogni caso. Non '
                'esiste nessuna condizione in cui Falcata smette di farti '
                'vedere il tuo archivio: sono allenamenti che hai fatto tu, '
                'non contenuti in prestito.',
                style: AppText.caption.copyWith(color: p.inkFaint),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Riga extends StatelessWidget {
  const _Riga({required this.feature, required this.inclusa});

  final Feature feature;
  final bool inclusa;

  @override
  Widget build(BuildContext context) {
    final AppPalette p = AppPalette.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(
            inclusa ? Icons.check_circle : Icons.lock_open_rounded,
            size: 18,
            color: inclusa ? p.green : p.accent,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  feature.title,
                  style: AppText.body.copyWith(
                    color: p.ink,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  feature.summary,
                  style: AppText.caption.copyWith(color: p.inkSoft),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
