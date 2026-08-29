import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'app/app.dart';
import 'providers/activity_provider.dart';
import 'providers/running_provider.dart';
import 'providers/settings_provider.dart';
import 'providers/shoe_provider.dart';
import 'providers/workout_provider.dart';
import 'services/audio_coach_service.dart';
import 'services/gps_service.dart';
import 'services/permission_service.dart';
import 'services/screen_service.dart';
import 'services/storage_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Preferenza portrait: durante la corsa l'orientamento fisso evita
  // rotazioni accidentali.
  await SystemChrome.setPreferredOrientations(<DeviceOrientation>[
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // --- Servizi (istanza unica per tutta l'app) ---
  final StorageService storage = StorageService();
  final AudioCoachService coach = AudioCoachService();
  final GpsService gps = GpsService();
  final PermissionService permissions = PermissionService();
  final ScreenService screen = ScreenService();

  // --- Provider ---
  final SettingsProvider settingsProvider =
      SettingsProvider(storage: storage, coach: coach);
  final ShoeProvider shoeProvider = ShoeProvider(storage: storage);
  final WorkoutProvider workoutProvider = WorkoutProvider(storage: storage);
  final ActivityProvider activityProvider =
      ActivityProvider(storage: storage, shoeProvider: shoeProvider);
  final RunningProvider runningProvider = RunningProvider(
    gpsService: gps,
    permissionService: permissions,
    coach: coach,
    screenService: screen,
  );

  // Caricamento dei dati locali prima di mostrare la Home.
  await settingsProvider.load();
  await shoeProvider.load();
  await workoutProvider.load();
  await activityProvider.load();
  runningProvider.applySettings(settingsProvider.settings);

  // Le impostazioni cambiate a runtime vengono propagate alla corsa.
  settingsProvider.addListener(() {
    runningProvider.applySettings(settingsProvider.settings);
  });

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<SettingsProvider>.value(value: settingsProvider),
        ChangeNotifierProvider<ShoeProvider>.value(value: shoeProvider),
        ChangeNotifierProvider<WorkoutProvider>.value(value: workoutProvider),
        ChangeNotifierProvider<ActivityProvider>.value(value: activityProvider),
        ChangeNotifierProvider<RunningProvider>.value(value: runningProvider),
      ],
      child: const RunCoachApp(),
    ),
  );
}
