import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../app/app.dart';
import '../app/routes.dart';
import '../app/tokens.dart';
import '../models/user_settings.dart';
import '../providers/settings_provider.dart';
import '../widgets/app_card.dart';

/// Schermata di benvenuto, mostrata una volta sola al primo avvio.
///
/// Chiede due cose sole: il nome e l'unita' di misura. Ogni domanda in piu'
/// e' una persona in meno che arriva alla fine, quindi il resto sta in
/// Impostazioni.
///
/// L'unita' merita di stare qui e non la' in fondo perche' e' la prima cosa
/// che si nota: vedere le distanze nell'unita' sbagliata fa sembrare l'app
/// rotta prima ancora di aver corso. Cambiarla dopo non rovina niente - i
/// dati restano in metri - ma e' meglio non doverla cercare.
class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key});

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen> {
  final TextEditingController _controller = TextEditingController();
  UnitSystem _units = UnitSystem.metric;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    // Se il nome c'era gia' (aggiornamento da una versione precedente) lo si
    // propone invece di far riscrivere tutto.
    final SettingsProvider settings = context.read<SettingsProvider>();
    _controller.text = settings.settings.userName;
    _units = settings.settings.units;
    _controller.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _finish({required bool useName}) async {
    if (_saving) return;
    setState(() => _saving = true);

    final SettingsProvider settings = context.read<SettingsProvider>();
    await settings.completeWelcome(
      name: useName ? _controller.text : '',
      units: _units,
    );

    if (!mounted) return;
    Navigator.of(context).pushReplacementNamed(AppRoutes.home);
  }

  @override
  Widget build(BuildContext context) {
    final AppPalette p = AppPalette.of(context);
    final String name = _controller.text.trim();
    final bool hasName = name.isNotEmpty;

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.screenSide,
            24,
            AppSpacing.screenSide,
            20,
          ),
          // Il contenuto scorre e i pulsanti restano in fondo: con la
          // tastiera aperta su un telefono piccolo, altrimenti, non ci sta.
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            RunCoachApp.appName.toUpperCase(),
                            style: AppText.label.copyWith(color: p.accent),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            hasName ? 'Ciao $name.' : 'Come ti chiami?',
                            style: AppText.largeTitle.copyWith(color: p.ink),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            'Serve solo per salutarti quando apri l\'app. '
                            'Resta sul telefono e non va da nessuna parte.',
                            style: AppText.body.copyWith(color: p.inkSoft),
                          ),
                          const SizedBox(height: 28),

                          TextField(
                            controller: _controller,
                            autofocus: true,
                            textCapitalization: TextCapitalization.words,
                            textInputAction: TextInputAction.done,
                            onSubmitted: (_) => _finish(useName: true),
                            style: TextStyle(
                              fontSize: 26,
                              fontWeight: FontWeight.w700,
                              letterSpacing: -1,
                              color: p.ink,
                            ),
                            decoration: InputDecoration(
                              hintText: 'Il tuo nome',
                              hintStyle: TextStyle(
                                fontSize: 26,
                                fontWeight: FontWeight.w700,
                                letterSpacing: -1,
                                color: p.separator,
                              ),
                              filled: true,
                              fillColor: p.surface,
                              contentPadding:
                                  const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(AppRadius.card),
                                borderSide: BorderSide.none,
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(AppRadius.card),
                                borderSide: BorderSide.none,
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(AppRadius.card),
                                borderSide: BorderSide(color: p.accent, width: 2),
                              ),
                            ),
                          ),

                          const SizedBox(height: 34),
                          const SectionTitle('In che unita\' misuri'),
                          Row(
                            children: <Widget>[
                              Expanded(
                                child: _UnitChoice(
                                  title: 'Chilometri',
                                  subtitle: 'km, min/km',
                                  selected: _units == UnitSystem.metric,
                                  onTap: () => setState(
                                      () => _units = UnitSystem.metric),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _UnitChoice(
                                  title: 'Miglia',
                                  subtitle: 'mi, min/mi',
                                  selected: _units == UnitSystem.imperial,
                                  onTap: () => setState(
                                      () => _units = UnitSystem.imperial),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Puoi cambiarla quando vuoi dalle impostazioni: '
                            'le corse salvate non cambiano, cambia solo come '
                            'te le scrivo.',
                            style: AppText.caption.copyWith(color: p.inkFaint),
                          ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 16),

              SizedBox(
                height: 54,
                child: FilledButton(
                  onPressed:
                      (hasName && !_saving) ? () => _finish(useName: true) : null,
                  style: FilledButton.styleFrom(
                    backgroundColor: p.accent,
                    foregroundColor: p.onAccent,
                    disabledBackgroundColor: p.separator,
                    disabledForegroundColor: p.inkFaint,
                  ),
                  child: const Text('Iniziamo'),
                ),
              ),
              const SizedBox(height: 4),
              Center(
                child: TextButton(
                  onPressed: _saving ? null : () => _finish(useName: false),
                  child: Text(
                    'Preferisco non dirlo',
                    style: TextStyle(color: p.inkFaint),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Una delle due scelte di unita'.
class _UnitChoice extends StatelessWidget {
  const _UnitChoice({
    required this.title,
    required this.subtitle,
    required this.selected,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final AppPalette p = AppPalette.of(context);
    return AppCard(
      onTap: onTap,
      color: selected ? p.accent : p.surface,
      padding: const EdgeInsets.fromLTRB(14, 13, 14, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            title,
            style: AppText.title.copyWith(
              fontSize: 17,
              color: selected ? p.onAccent : p.ink,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            style: AppText.caption.copyWith(
              color: selected ? p.onAccent : p.inkFaint,
            ),
          ),
        ],
      ),
    );
  }
}
