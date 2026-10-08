import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../app/app.dart';
import '../app/routes.dart';
import '../app/tokens.dart';
import '../models/user_settings.dart';
import '../providers/settings_provider.dart';
import '../widgets/app_card.dart';
import '../widgets/inset_list.dart';

/// Voce di scelta singola.
///
/// Sostituisce `RadioListTile` con un semplice `ListTile`: stesso
/// comportamento, ma senza dipendere da API di Flutter soggette a
/// deprecazione.
class _OptionTile extends StatelessWidget {
  const _OptionTile({
    required this.selected,
    required this.title,
    required this.onTap,
    this.subtitle,
    this.enabled = true,
  });

  final bool selected;
  final String title;
  final String? subtitle;
  final VoidCallback onTap;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return ListTile(
      enabled: enabled,
      onTap: enabled ? onTap : null,
      leading: Icon(
        selected ? Icons.radio_button_checked : Icons.radio_button_unchecked,
        color: enabled && selected ? scheme.primary : scheme.onSurfaceVariant,
      ),
      title: Text(title),
      subtitle: subtitle == null ? null : Text(subtitle!),
    );
  }
}

/// Impostazioni dell'app.
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late final TextEditingController _nameController;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(
      text: context.read<SettingsProvider>().settings.userName,
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final SettingsProvider provider = context.watch<SettingsProvider>();
    final UserSettings settings = provider.settings;
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final AppPalette p = AppPalette.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Impostazioni')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
          children: <Widget>[
            // ------------------------------------------------------ utente
            const SectionTitle('Utente'),
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  TextField(
                    controller: _nameController,
                    textCapitalization: TextCapitalization.words,
                    decoration: const InputDecoration(
                      labelText: 'Il tuo nome',
                      helperText: 'Verra mostrato nella schermata iniziale',
                      border: OutlineInputBorder(),
                    ),
                    onSubmitted: (String value) =>
                        provider.setUserName(value.trim()),
                  ),
                  const SizedBox(height: 12),
                  FilledButton.tonal(
                    onPressed: () async {
                      await provider.setUserName(_nameController.text.trim());
                      if (!context.mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Nome salvato.')),
                      );
                    },
                    child: const Text('SALVA NOME'),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),
            const SectionTitle('Aspetto'),
            AppCard(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: Column(
                children: <Widget>[
                  for (final ThemeChoice scelta in ThemeChoice.values)
                    _OptionTile(
                      selected: settings.theme == scelta,
                      title: scelta.label,
                      subtitle: scelta.description,
                      onTap: () => provider.setTheme(scelta),
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(left: 4, top: 8),
              child: Text(
                'La schermata di corsa resta nera in ogni caso: il bianco su '
                'nero e\' quello che si legge meglio al sole, e sugli schermi '
                'OLED il nero pieno non consuma batteria.',
                style: AppText.caption.copyWith(color: p.inkFaint),
              ),
            ),

            const SizedBox(height: 20),
            const SectionTitle('Unita di misura'),
            AppCard(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: Column(
                children: <Widget>[
                  _OptionTile(
                    selected: settings.units == UnitSystem.metric,
                    title: 'Chilometri',
                    subtitle: 'Distanze in km, passo in min/km.',
                    onTap: () => provider.setUnits(UnitSystem.metric),
                  ),
                  _OptionTile(
                    selected: settings.units == UnitSystem.imperial,
                    title: 'Miglia',
                    subtitle: 'Distanze in mi, passo in min/mi. Le ripetute '
                        'restano in metri: in pista sono metriche ovunque.',
                    onTap: () => provider.setUnits(UnitSystem.imperial),
                  ),
                ],
              ),
            ),
            const Padding(
              padding: EdgeInsets.fromLTRB(4, 8, 4, 0),
              child: Text(
                'Le corse gia\' salvate non vengono toccate: dentro l\'app '
                'resta tutto in metri, cambia solo come viene scritto.',
                style: TextStyle(fontSize: 12),
              ),
            ),

            const SizedBox(height: 20),
            const SectionTitle('Coach vocale'),
            AppCard(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: Column(
                children: <Widget>[
                  SwitchListTile(
                    value: settings.audioCoachEnabled,
                    onChanged: provider.setAudioCoachEnabled,
                    title: const Text('Audio coach'),
                    subtitle: const Text('Annunci vocali durante la corsa'),
                  ),
                  ListTile(
                    title: const Text('Volume'),
                    subtitle: Slider(
                      value: settings.coachVolume,
                      min: 0.1,
                      max: 1.0,
                      divisions: 9,
                      label: '${(settings.coachVolume * 100).round()}%',
                      onChanged: settings.audioCoachEnabled
                          ? provider.setCoachVolume
                          : null,
                    ),
                  ),
                  ListTile(
                    title: const Text('Velocita della voce'),
                    subtitle: Slider(
                      value: settings.speechRate,
                      min: 0.2,
                      max: 1.0,
                      divisions: 8,
                      label: settings.speechRate.toStringAsFixed(1),
                      onChanged: settings.audioCoachEnabled
                          ? provider.setSpeechRate
                          : null,
                    ),
                  ),
                  const Divider(),
                  for (final CoachPersonality personality
                      in CoachPersonality.values)
                    _OptionTile(
                      selected: settings.coachPersonality == personality,
                      enabled: settings.audioCoachEnabled,
                      title: personality.label,
                      subtitle: personality.description,
                      onTap: () => provider.setCoachPersonality(personality),
                    ),
                  Padding(
                    padding: const EdgeInsets.all(8),
                    child: OutlinedButton.icon(
                      onPressed: settings.audioCoachEnabled
                          ? provider.testVoice
                          : null,
                      icon: const Icon(Icons.volume_up),
                      label: const Text('Prova la voce'),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            InsetList(
              children: <Widget>[
                AppListRow(
                  title: 'La voce',
                  subtitle: 'Quale voce usa fra quelle del telefono, quanto '
                      'deve dire a ogni chilometro, e come averne una meno '
                      'robotica.',
                  onTap: () => Navigator.of(context).pushNamed(AppRoutes.voce),
                ),
              ],
            ),

            const SizedBox(height: 20),
            const SectionTitle('Lap'),
            AppCard(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: Column(
                children: <Widget>[
                  SwitchListTile(
                    value: settings.autoLapEnabled,
                    onChanged: provider.setAutoLapEnabled,
                    title: const Text('Lap automatico'),
                    subtitle: const Text(
                        'Chiude un giro automaticamente alla distanza scelta'),
                  ),
                  ListTile(
                    title: const Text('Distanza lap'),
                    subtitle: Text(
                        '${(settings.autoLapDistanceMeters / 1000).toStringAsFixed(1)} km'),
                    trailing: Wrap(
                      spacing: 6,
                      children: <Widget>[
                        for (final double meters in <double>[500, 1000, 2000])
                          ChoiceChip(
                            label: Text(meters >= 1000
                                ? '${(meters / 1000).toStringAsFixed(0)} km'
                                : '${meters.round()} m'),
                            selected:
                                settings.autoLapDistanceMeters == meters,
                            onSelected: settings.autoLapEnabled
                                ? (_) => provider.setAutoLapDistance(meters)
                                : null,
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),
            const SectionTitle('Avvisi di ritmo'),
            AppCard(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: Column(
                children: <Widget>[
                  SwitchListTile(
                    value: settings.paceAlertsEnabled,
                    onChanged: provider.setPaceAlertsEnabled,
                    title: const Text('Avvisi di ritmo'),
                    subtitle: const Text(
                        'Avvisa quando sei fuori dal passo target della fase'),
                  ),
                  ListTile(
                    title: const Text('Intervallo minimo fra due avvisi'),
                    subtitle: Slider(
                      value: settings.paceAlertCooldownSeconds.toDouble(),
                      min: 15,
                      max: 60,
                      divisions: 9,
                      label: '${settings.paceAlertCooldownSeconds} s',
                      onChanged: settings.paceAlertsEnabled
                          ? (double value) =>
                              provider.setPaceAlertCooldown(value.round())
                          : null,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),
            const SectionTitle('I tuoi dati'),
            InsetList(
              children: <Widget>[
                AppListRow(
                  title: 'Importa le tue corse',
                  subtitle: 'Se corri gia\' da prima: porta dentro lo storico '
                      'da file GPX e l\'app parte sapendo chi sei.',
                  onTap: () =>
                      Navigator.of(context).pushNamed(AppRoutes.importa),
                ),
                AppListRow(
                  title: 'Copia di sicurezza',
                  subtitle: 'Le corse stanno solo in questo telefono. Se lo '
                      'cambi o lo perdi, senza una copia spariscono.',
                  onTap: () =>
                      Navigator.of(context).pushNamed(AppRoutes.backup),
                ),
              ],
            ),

            // LA MAPPA E' PARCHEGGIATA, NON CANCELLATA.
            //
            // Il codice c'e' ancora (map_tile_service.dart, route_map.dart) ma
            // non lo raggiunge piu' nessuno, e il permesso internet non e' piu'
            // dichiarato. Il motivo non e' tecnico: i server di OpenStreetMap
            // vietano l'uso da parte di un'app distribuita, e qualunque altro
            // fornitore e' un costo che torna ogni mese contro un'app che si
            // paga una volta sola.
            //
            // Toglierla cambia anche una cosa che si vede: Falcata adesso non
            // parla con nessuno, e nel modulo di Google sui dati la risposta e'
            // "niente", senza spiegazioni. Si riaccende il giorno in cui ci
            // sara' un fornitore deciso.

            const SizedBox(height: 20),
            const SectionTitle('Falcata completa'),
            InsetList(
              children: <Widget>[
                AppListRow(
                  title: 'Cosa e\' gratis e cosa si paga',
                  subtitle: 'Registrare, allenamenti, record e percorso sono '
                      'gratis per sempre. Il piano, i passi e il carico si '
                      'pagano una volta sola.',
                  onTap: () =>
                      Navigator.of(context).pushNamed(AppRoutes.unlock),
                ),
              ],
            ),

            const SizedBox(height: 20),
            const SectionTitle('Registrazione'),
            InsetList(
              children: <Widget>[
                AppListRow(
                  title: 'Corse che si interrompono',
                  subtitle: 'Se una corsa si ferma a meta\', quasi mai e\' il '
                      'GPS: e\' il telefono che chiude l\'app per '
                      'risparmiare batteria. Qui c\'e\' come impedirlo.',
                  onTap: () =>
                      Navigator.of(context).pushNamed(AppRoutes.battery),
                ),
              ],
            ),
            const SizedBox(height: 10),
            AppCard(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: Column(
                children: <Widget>[
                  SwitchListTile(
                    value: settings.backgroundTrackingEnabled,
                    onChanged: provider.setBackgroundTracking,
                    title: const Text('Registra in background'),
                    subtitle: const Text(
                        'La corsa continua con lo schermo spento e il telefono in tasca. '
                        'Durante la registrazione compare una notifica permanente.'),
                  ),
                  SwitchListTile(
                    value: settings.keepScreenOn,
                    onChanged: provider.setKeepScreenOn,
                    title: const Text('Mantieni lo schermo acceso'),
                    subtitle: const Text(
                        'Attivo solo durante la registrazione della corsa'),
                  ),
                  if (!settings.backgroundTrackingEnabled)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Icon(Icons.warning_amber_outlined,
                              size: 18, color: scheme.error),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Con la registrazione in background disattivata, uscendo '
                              'dall\'app o spegnendo lo schermo la corsa si interrompe.',
                              style: TextStyle(fontSize: 13, color: scheme.error),
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),

            if (provider.errorMessage != null) ...<Widget>[
              const SizedBox(height: 20),
              AppCard(
                color: scheme.errorContainer,
                child: Text(
                  provider.errorMessage!,
                  style: TextStyle(color: scheme.onErrorContainer),
                ),
              ),
            ],

            const SizedBox(height: 24),
            Center(
              child: Column(
                children: <Widget>[
                  Text(
                    '${RunCoachApp.appName} - versione ${RunCoachApp.version}',
                    style:
                        TextStyle(color: scheme.onSurfaceVariant, fontSize: 13),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    RunCoachApp.credit,
                    style:
                        TextStyle(color: scheme.onSurfaceVariant, fontSize: 13),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
