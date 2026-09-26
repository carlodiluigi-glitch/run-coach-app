import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../app/app.dart';
import '../app/routes.dart';
import '../app/tokens.dart';
import '../providers/settings_provider.dart';

/// Schermata di apertura: il nome dell'app e il saluto, poi si entra.
///
/// Non e' solo decorazione. I dati locali (impostazioni, attivita', scarpe)
/// vengono letti da file all'avvio: questa schermata copre quel momento, che
/// altrimenti si vedrebbe come uno sfarfallio bianco.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  /// Quanto resta visibile. Abbastanza per leggere il saluto, non tanto da
  /// diventare un'attesa.
  static const Duration duration = Duration(milliseconds: 1600);

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  bool _visible = false;
  Timer? _timer;

  /// Evita che un doppio tocco (o un tocco proprio mentre scade il tempo)
  /// faccia cambiare schermata due volte.
  bool _leaving = false;

  @override
  void initState() {
    super.initState();
    // La comparsa parte al primo fotogramma utile, cosi' l'animazione si
    // vede davvero invece di essere gia' finita quando lo schermo si accende.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      setState(() => _visible = true);
    });
    _timer = Timer(SplashScreen.duration, _goOn);
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _goOn() {
    if (!mounted || _leaving) return;
    _leaving = true;
    _timer?.cancel();
    final SettingsProvider settings = context.read<SettingsProvider>();
    Navigator.of(context).pushReplacementNamed(
      settings.settings.welcomeDone ? AppRoutes.home : AppRoutes.welcome,
    );
  }

  @override
  Widget build(BuildContext context) {
    final AppPalette p = AppPalette.run;
    final SettingsProvider settings = context.watch<SettingsProvider>();
    final bool hasName = settings.settings.hasUserName;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: p.background,
        body: GestureDetector(
          // Toccando si salta l'attesa: chi apre l'app per partire non deve
          // aspettare un'animazione.
          behavior: HitTestBehavior.opaque,
          onTap: _goOn,
          child: SafeArea(
            child: AnimatedOpacity(
              opacity: _visible ? 1 : 0,
              duration: const Duration(milliseconds: 500),
              curve: Curves.easeOut,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 24, 24, 20),
                child: Column(
                  children: <Widget>[
                    Expanded(
                      child: Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: <Widget>[
                            // Il segno dell'app, lo stesso dell'icona: tre
                            // falcate che si allungano.
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: <Widget>[
                                _Stride(width: 30, color: p.accent),
                                const SizedBox(height: 9),
                                _Stride(width: 48, color: p.accent),
                                const SizedBox(height: 9),
                                _Stride(width: 68, color: p.accent),
                              ],
                            ),
                            const SizedBox(height: 26),
                            Text(
                              RunCoachApp.appName.toUpperCase(),
                              style: TextStyle(
                                fontSize: 42,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 7,
                                color: p.ink,
                              ),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              hasName
                                  ? settings.settings.greeting
                                  : 'Allenati meglio',
                              style: TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w500,
                                letterSpacing: -0.2,
                                color: p.inkFaint,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    Text(
                      RunCoachApp.credit,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        letterSpacing: 0.3,
                        color: p.inkFaint,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Stride extends StatelessWidget {
  const _Stride({required this.width, required this.color});

  final double width;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: 4,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(2),
      ),
    );
  }
}
