import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../app/tokens.dart';
import '../models/user_settings.dart';
import '../providers/settings_provider.dart';
import '../services/audio_coach_service.dart';
import '../services/native_bridge.dart';
import '../widgets/app_card.dart';
import '../widgets/inset_list.dart';

/// "La voce": quale usa, quali ci sono, e come averne una migliore.
///
/// PERCHE' ESISTE UNA SCHERMATA INTERA
/// -----------------------------------
/// Perche' la voce **non e' dell'app, e' del telefono**, e questa e' la cosa
/// che nessuno si aspetta. L'app puo' chiedere al sistema di parlare, e puo'
/// scegliere fra le voci installate - non puo' fabbricarne una. Se su un
/// telefono c'e' solo la voce di base, quella meccanica, l'unica cosa onesta
/// e' dirlo e spiegare in due passaggi come scaricarne una buona.
///
/// E' lo stesso ragionamento della schermata sul risparmio energetico: un
/// difetto che sembra dell'app e invece sta nel telefono si risolve
/// spiegandolo bene una volta, non nascondendolo.
class VoiceScreen extends StatefulWidget {
  const VoiceScreen({super.key});

  @override
  State<VoiceScreen> createState() => _VoiceScreenState();
}

class _VoiceScreenState extends State<VoiceScreen> {
  final NativeBridge _native = NativeBridge();

  List<CoachVoice> _voci = const <CoachVoice>[];
  bool _caricate = false;

  @override
  void initState() {
    super.initState();
    _carica();
  }

  Future<void> _carica() async {
    final List<CoachVoice> voci =
        await context.read<SettingsProvider>().availableVoices();
    if (!mounted) return;
    setState(() {
      _voci = voci;
      _caricate = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    final AppPalette p = AppPalette.of(context);
    final SettingsProvider provider = context.watch<SettingsProvider>();
    final UserSettings settings = provider.settings;

    return Scaffold(
      appBar: AppBar(title: const Text('La voce')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.screenSide,
            12,
            AppSpacing.screenSide,
            32,
          ),
          children: <Widget>[
            Text(
              'La voce non e\' dell\'app',
              style: AppText.title.copyWith(color: p.ink, fontSize: 20),
            ),
            const SizedBox(height: 8),
            Text(
              'E\' del telefono. Falcata puo\' solo chiedergli di parlare e '
              'scegliere fra le voci che ci sono gia\'. Quasi tutti i telefoni '
              'ne hanno piu\' d\'una: una di base, piccola, che e\' quella che '
              'suona meccanica, e altre migliori da scaricare.',
              style: AppText.body.copyWith(color: p.inkSoft),
            ),
            const SizedBox(height: 20),

            // ----------------------------------------- quanto deve dire
            const SectionTitle('Quanto deve dire'),
            AppCard(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: Column(
                children: <Widget>[
                  for (final SpokenDetail d in SpokenDetail.values)
                    RadioListTile<SpokenDetail>(
                      value: d,
                      groupValue: settings.spokenDetail,
                      onChanged: (SpokenDetail? scelto) {
                        if (scelto != null) provider.setSpokenDetail(scelto);
                      },
                      title: Text(d.label),
                      subtitle: Text(d.description),
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(left: 4, top: 8),
              child: Text(
                'Esempio con "Completo": «Giro tre, un chilometro in cinque e '
                'dieci. Due secondi piu\' veloce. Totale tre chilometri in '
                'quindici minuti.»',
                style: AppText.caption.copyWith(color: p.inkFaint),
              ),
            ),

            const SizedBox(height: 20),

            // ----------------------------------------------- quale voce
            const SectionTitle('Quale voce'),
            if (!_caricate)
              const Padding(
                padding: EdgeInsets.all(16),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_voci.isEmpty)
              AppCard(
                child: Text(
                  'Non sono riuscito a leggere l\'elenco delle voci di questo '
                  'telefono. Il coach parla lo stesso, con la voce '
                  'predefinita: da qui non si puo\' cambiarla, ma la trovi '
                  'nelle impostazioni Android sotto "Sintesi vocale".',
                  style: AppText.body.copyWith(color: p.inkSoft),
                ),
              )
            else
              InsetList(
                children: <Widget>[
                  _VoceRow(
                    titolo: 'Scegli tu (consigliato)',
                    sottotitolo:
                        'Falcata prende la migliore fra quelle installate, e '
                        'si aggiorna da sola se ne installi una nuova.',
                    scelta: settings.ttsVoice.isEmpty,
                    onTap: () => provider.setVoice(''),
                    onProva: null,
                  ),
                  for (int i = 0; i < _voci.length; i++)
                    _VoceRow(
                      titolo: _voci[i].readableName(i + 1),
                      sottotitolo: _voci[i].needsNetwork
                          ? 'Suona meglio, ma ha bisogno della rete: dove non '
                              'c\'e\' campo resta muta.'
                          : 'Funziona anche senza rete.',
                      scelta: settings.ttsVoice == _voci[i].name,
                      onTap: () => provider.setVoice(_voci[i].name),
                      onProva: () => provider.previewVoice(_voci[i]),
                    ),
                ],
              ),

            const SizedBox(height: 20),

            // -------------------------------- come averne una migliore
            const SectionTitle('Se nessuna ti convince'),
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    'Le voci italiane piu\' naturali su Android sono quelle di '
                    'Google, e si scaricano gratis. Due passaggi:',
                    style: AppText.body.copyWith(color: p.inkSoft),
                  ),
                  const SizedBox(height: 10),
                  _Passo(
                    numero: '1',
                    testo: 'Nelle impostazioni del telefono cerca "Sintesi '
                        'vocale" (a volte sta sotto Accessibilita\', a volte '
                        'sotto Sistema o Gestione generale).',
                  ),
                  _Passo(
                    numero: '2',
                    testo: 'Scegli "Sintesi vocale di Google" come motore, poi '
                        'apri le sue impostazioni e scarica la voce italiana. '
                        'Se ce ne sono piu\' d\'una, prendile tutte e qui le '
                        'provi.',
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: () async {
                      await _native.openAppSettings();
                    },
                    icon: const Icon(Icons.open_in_new),
                    label: const Text('Apri le impostazioni'),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Il pulsante apre la pagina di Falcata: da li\' si torna '
                    'indietro alle impostazioni del telefono. Android non '
                    'lascia aprire direttamente la pagina della sintesi '
                    'vocale.',
                    style: AppText.caption.copyWith(color: p.inkFaint),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Dopo aver scaricato una voce nuova, torna qui: compare '
              'nell\'elenco.',
              style: AppText.caption.copyWith(color: p.inkFaint),
            ),
            const SizedBox(height: 8),
            Center(
              child: TextButton.icon(
                onPressed: () {
                  setState(() => _caricate = false);
                  _carica();
                },
                icon: const Icon(Icons.refresh),
                label: const Text('Rileggi l\'elenco'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Una voce nell'elenco: si sceglie toccandola, si prova col pulsante.
class _VoceRow extends StatelessWidget {
  const _VoceRow({
    required this.titolo,
    required this.sottotitolo,
    required this.scelta,
    required this.onTap,
    required this.onProva,
  });

  final String titolo;
  final String sottotitolo;
  final bool scelta;
  final VoidCallback onTap;
  final VoidCallback? onProva;

  @override
  Widget build(BuildContext context) {
    final AppPalette p = AppPalette.of(context);
    return ListTile(
      onTap: onTap,
      leading: Icon(
        scelta ? Icons.radio_button_checked : Icons.radio_button_unchecked,
        color: scelta ? p.accent : p.inkFaint,
      ),
      title: Text(titolo),
      subtitle: Text(sottotitolo),
      trailing: onProva == null
          ? null
          : IconButton(
              tooltip: 'Prova',
              icon: Icon(Icons.volume_up, color: p.blue),
              onPressed: onProva,
            ),
    );
  }
}

class _Passo extends StatelessWidget {
  const _Passo({required this.numero, required this.testo});

  final String numero;
  final String testo;

  @override
  Widget build(BuildContext context) {
    final AppPalette p = AppPalette.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Container(
            width: 22,
            height: 22,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: p.accent.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Text(
              numero,
              style: AppText.number(12, color: p.accent),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(testo, style: AppText.body.copyWith(color: p.inkSoft)),
          ),
        ],
      ),
    );
  }
}
