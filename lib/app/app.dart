import 'package:flutter/material.dart';

import 'routes.dart';
import 'theme.dart';

/// Widget radice dell'applicazione.
class RunCoachApp extends StatelessWidget {
  const RunCoachApp({super.key});

  static const String appName = 'Falcata';

  /// Riga di paternita', mostrata all'avvio e nelle impostazioni.
  static const String credit = 'Sviluppato da Carlo Di Luigi';

  static const String version = '1.1.0';

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: appName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: ThemeMode.system,
      initialRoute: AppRoutes.splash,
      onGenerateRoute: AppRoutes.onGenerateRoute,
    );
  }
}
