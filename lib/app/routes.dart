import 'package:flutter/material.dart';

import '../models/workout.dart';
import '../screens/activity_detail_screen.dart';
import '../screens/activity_history_screen.dart';
import '../screens/fitness_screen.dart';
import '../screens/home_screen.dart';
import '../screens/plan_screen.dart';
import '../screens/plan_setup_screen.dart';
import '../screens/records_screen.dart';
import '../screens/run_screen.dart';
import '../screens/settings_screen.dart';
import '../screens/shoes_screen.dart';
import '../screens/splash_screen.dart';
import '../screens/stats_screen.dart';
import '../screens/welcome_screen.dart';
import '../screens/workout_builder_screen.dart';
import '../screens/workout_library_screen.dart';

/// Nomi delle rotte dell'app, in un unico posto.
class AppRoutes {
  AppRoutes._();

  /// Schermata di apertura: e' la prima cosa che parte.
  static const String splash = '/';

  /// Benvenuto del primo avvio (chiede il nome). Mostrato una volta sola.
  static const String welcome = '/welcome';

  static const String home = '/home';
  static const String run = '/run';
  static const String workoutLibrary = '/workouts';
  static const String workoutBuilder = '/workout-builder';
  static const String history = '/history';
  static const String activityDetail = '/activity';
  static const String shoes = '/shoes';
  static const String stats = '/stats';
  static const String records = '/records';
  static const String settings = '/settings';

  /// Forma attuale: indice, passi, previsioni.
  static const String fitness = '/fitness';

  /// Piano di allenamento attivo.
  static const String plan = '/plan';

  /// Creazione di un nuovo piano.
  static const String planSetup = '/plan-setup';

  /// Generatore delle rotte con gestione degli argomenti.
  static Route<dynamic> onGenerateRoute(RouteSettings routeSettings) {
    switch (routeSettings.name) {
      case splash:
        return MaterialPageRoute<void>(
          builder: (_) => const SplashScreen(),
          settings: routeSettings,
        );

      case welcome:
        return MaterialPageRoute<void>(
          builder: (_) => const WelcomeScreen(),
          settings: routeSettings,
        );

      case home:
        return MaterialPageRoute<void>(
          builder: (_) => const HomeScreen(),
          settings: routeSettings,
        );

      case run:
        final Object? args = routeSettings.arguments;
        return MaterialPageRoute<void>(
          builder: (_) => RunScreen(workout: args is Workout ? args : null),
          settings: routeSettings,
        );

      case workoutLibrary:
        return MaterialPageRoute<void>(
          builder: (_) => const WorkoutLibraryScreen(),
          settings: routeSettings,
        );

      case workoutBuilder:
        final Object? args = routeSettings.arguments;
        return MaterialPageRoute<void>(
          builder: (_) =>
              WorkoutBuilderScreen(existing: args is Workout ? args : null),
          settings: routeSettings,
        );

      case history:
        return MaterialPageRoute<void>(
          builder: (_) => const ActivityHistoryScreen(),
          settings: routeSettings,
        );

      case activityDetail:
        final Object? args = routeSettings.arguments;
        return MaterialPageRoute<void>(
          builder: (_) =>
              ActivityDetailScreen(activityId: args is String ? args : ''),
          settings: routeSettings,
        );

      case shoes:
        return MaterialPageRoute<void>(
          builder: (_) => const ShoesScreen(),
          settings: routeSettings,
        );

      case stats:
        return MaterialPageRoute<void>(
          builder: (_) => const StatsScreen(),
          settings: routeSettings,
        );

      case records:
        return MaterialPageRoute<void>(
          builder: (_) => const RecordsScreen(),
          settings: routeSettings,
        );

      case settings:
        return MaterialPageRoute<void>(
          builder: (_) => const SettingsScreen(),
          settings: routeSettings,
        );

      case fitness:
        return MaterialPageRoute<void>(
          builder: (_) => const FitnessScreen(),
          settings: routeSettings,
        );

      case plan:
        return MaterialPageRoute<void>(
          builder: (_) => const PlanScreen(),
          settings: routeSettings,
        );

      case planSetup:
        return MaterialPageRoute<void>(
          builder: (_) => const PlanSetupScreen(),
          settings: routeSettings,
        );

      default:
        return MaterialPageRoute<void>(
          builder: (_) => Scaffold(
            appBar: AppBar(title: const Text('Pagina non trovata')),
            body: Center(
              child: Text('Rotta sconosciuta: ${routeSettings.name}'),
            ),
          ),
          settings: routeSettings,
        );
    }
  }
}
