import 'package:flutter/material.dart';

import '../app/tokens.dart';
import '../services/native_bridge.dart';
import '../utils/battery_advice.dart';
import '../widgets/app_card.dart';
import '../widgets/inset_list.dart';

/// "Perche' il telefono ferma l'app mentre corri", e cosa farci.
///
/// PERCHE' ESISTE UNA SCHERMATA INTERA
/// -----------------------------------
/// Perche' e' il difetto che perde piu' utenti di qualunque altro, e non e'
/// un difetto dell'app: e' Android che addormenta i processi per risparmiare
/// batteria. L'app non lo puo' impedire da sola - puo' solo chiedere
/// l'esenzione, e su parecchi telefoni nemmeno quella basta.
///
/// Quindi l'unica strada e' spiegarlo bene una volta, con le parole giuste
/// per QUELLA marca di telefono, e lasciare all'utente due pulsanti.
class BatteryScreen extends StatefulWidget {
  const BatteryScreen({super.key});

  @override
  State<BatteryScreen> createState() => _BatteryScreenState();
}

class _BatteryScreenState extends State<BatteryScreen> {
  final NativeBridge _native = NativeBridge();

  bool _loading = true;
  bool _exempt = true;
  String _manufacturer = '';

  @override
  void initState() {
    super.initState();
    _check();
  }

  Future<void> _check() async {
    final bool exempt = await _native.isIgnoringBatteryOptimizations();
    final String marca = await _native.manufacturer();
    if (!mounted) return;
    setState(() {
      _exempt = exempt;
      _manufacturer = marca;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final AppPalette p = AppPalette.of(context);
    final bool extra = BatteryAdvice.needsExtraSteps(_manufacturer);
    final String nome = BatteryAdvice.displayName(_manufacturer);

    return Scaffold(
      appBar: AppBar(title: const Text('Corse che si interrompono')),
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
                    'Se una corsa si ferma a meta\'',
                    style: AppText.title.copyWith(color: p.ink),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Quasi mai e\' colpa del GPS. E\' Android che chiude le '
                    'app per risparmiare batteria: lo schermo si spegne, il '
                    'telefono sta in tasca, e dopo qualche minuto la '
                    'registrazione muore. Sei chilometri diventano tre, e non '
                    'c\'e\' niente da recuperare.\n\n'
                    'Falcata ora scrive la corsa su disco ogni quindici '
                    'secondi, quindi anche nel caso peggiore non perdi tutto. '
                    'Ma la cosa giusta e\' impedire che succeda.',
                    style: AppText.body.copyWith(color: p.inkSoft),
                  ),
                ],
              ),
            ),

            const SectionTitle('Stato'),
            InsetList(
              children: <Widget>[
                AppListRow(
                  title: 'Esclusa dal risparmio energetico',
                  subtitle: _loading
                      ? 'Controllo in corso...'
                      : (_exempt
                          ? 'A posto: Android non dovrebbe chiudere l\'app '
                              'mentre registri.'
                          : 'Non ancora. E\' la prima cosa da sistemare.'),
                  showChevron: false,
                  value: _loading ? '' : (_exempt ? 'Si\'' : 'No'),
                  valueColor: _loading ? null : (_exempt ? p.green : p.orange),
                ),
              ],
            ),

            if (!_loading && !_exempt) ...<Widget>[
              const SizedBox(height: 14),
              SizedBox(
                height: 52,
                child: FilledButton.icon(
                  onPressed: () async {
                    final bool aperta =
                        await _native.requestIgnoreBatteryOptimizations();
                    if (!aperta) await _native.openAppSettings();
                    await Future<void>.delayed(const Duration(seconds: 1));
                    await _check();
                  },
                  style: FilledButton.styleFrom(
                    backgroundColor: p.accent,
                    foregroundColor: p.onAccent,
                  ),
                  icon: const Icon(Icons.battery_saver_outlined),
                  label: const Text('Chiedi l\'esenzione'),
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(left: 4, top: 8),
                child: Text(
                  'Si apre una finestra di Android. La decisione resta tua: '
                  'l\'app puo\' solo chiedere.',
                  style: AppText.caption.copyWith(color: p.inkFaint),
                ),
              ),
            ],

            if (extra) ...<Widget>[
              SectionTitle(
                  nome.isEmpty ? 'Sul tuo telefono' : 'Sul tuo $nome'),
              AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Icon(Icons.priority_high_rounded,
                            size: 18, color: p.orange),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Su questo telefono l\'esenzione standard non '
                            'basta: il produttore ha un gestore suo, piu\' '
                            'aggressivo.',
                            style: AppText.body.copyWith(color: p.ink),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      BatteryAdvice.stepsFor(_manufacturer),
                      style: AppText.body.copyWith(
                        color: p.inkSoft,
                        height: 1.45,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                height: 50,
                child: OutlinedButton.icon(
                  onPressed: () => _native.openAppSettings(),
                  icon: const Icon(Icons.open_in_new, size: 18),
                  label: const Text('Apri le impostazioni di Falcata'),
                ),
              ),
            ],

            const SectionTitle('Mentre corri'),
            AppCard(
              child: Text(
                'Se durante una corsa il telefono smette di mandare la '
                'posizione per piu\' di mezzo minuto, Falcata te lo dice '
                'subito: compare un avviso rosso e il coach lo annuncia a '
                'voce. Non e\' un dettaglio - detto a fine corsa non serve a '
                'niente, detto mentre succede si puo\' ancora rimediare.',
                style: AppText.body.copyWith(color: p.inkSoft),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
