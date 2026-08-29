import 'package:flutter/material.dart';

import 'routes.dart';
import 'theme.dart';

/// Widget radice dell'applicazione.
class RunCoachApp extends StatelessWidget {
  const RunCoachApp({super.key});

  static const String appName = 'Run Coach';

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: appName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: ThemeMode.system,
      initialRoute: AppRoutes.home,
      onGenerateRoute: AppRoutes.onGenerateRoute,
    );
  }
}
