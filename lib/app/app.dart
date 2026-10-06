import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';

import '../models/user_settings.dart';
import '../providers/settings_provider.dart';
import 'routes.dart';
import 'theme.dart';

/// Widget radice dell'applicazione.
class RunCoachApp extends StatelessWidget {
  const RunCoachApp({super.key});

  static const String appName = 'Falcata';

  /// Riga di paternita', mostrata all'avvio e nelle impostazioni.
  static const String credit = 'Sviluppato da Carlo Di Luigi';

  static const String version = '2.7.0';

  /// Da quale scelta dell'utente dipende il tema.
  ///
  /// Si legge con `watch` perche' cambiare questa impostazione deve ridipingere
  /// l'app intera subito: un tema che cambia solo alla riapertura sembra un
  /// interruttore rotto.
  static ThemeMode _modo(ThemeChoice scelta) {
    switch (scelta) {
      case ThemeChoice.sistema:
        return ThemeMode.system;
      case ThemeChoice.chiaro:
        return ThemeMode.light;
      case ThemeChoice.scuro:
        return ThemeMode.dark;
    }
  }

  @override
  Widget build(BuildContext context) {
    final ThemeChoice scelta =
        context.watch<SettingsProvider>().settings.theme;
    return MaterialApp(
      title: appName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: _modo(scelta),

      // L'app e' in italiano, ma i pezzi di interfaccia che arrivano da
      // Flutter (il calendario, i pulsanti Annulla/OK, i nomi dei mesi)
      // parlano inglese finche' non glielo si dice. Questi tre delegati
      // fanno parte dell'SDK: nessuna dipendenza esterna in piu'.
      locale: const Locale('it'),
      supportedLocales: const <Locale>[Locale('it'), Locale('en')],
      localizationsDelegates: const <LocalizationsDelegate<dynamic>>[
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],

      initialRoute: AppRoutes.splash,
      onGenerateRoute: AppRoutes.onGenerateRoute,
    );
  }
}
