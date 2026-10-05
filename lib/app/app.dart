import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'routes.dart';
import 'theme.dart';

/// Widget radice dell'applicazione.
class RunCoachApp extends StatelessWidget {
  const RunCoachApp({super.key});

  static const String appName = 'Falcata';

  /// Riga di paternita', mostrata all'avvio e nelle impostazioni.
  static const String credit = 'Sviluppato da Carlo Di Luigi';

  static const String version = '2.2.0';

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: appName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: ThemeMode.system,

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
