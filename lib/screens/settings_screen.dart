import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/user_settings.dart';
import '../providers/settings_provider.dart';
import '../widgets/app_card.dart';

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
            const SectionTitle('Unita di misura'),
            AppCard(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: _OptionTile(
                selected: settings.units == UnitSystem.metric,
                title: 'Metrico (km)',
                subtitle: 'Unica unita disponibile in questa versione.',
                onTap: () => provider.setUnits(UnitSystem.metric),
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
            const SectionTitle('Schermo'),
            AppCard(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: SwitchListTile(
                value: settings.keepScreenOn,
                onChanged: provider.setKeepScreenOn,
                title: const Text('Mantieni lo schermo acceso'),
                subtitle: const Text(
                    'Attivo solo durante la registrazione della corsa'),
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
              child: Text(
                'Run Coach - versione 1.0.0',
                style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 13),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
