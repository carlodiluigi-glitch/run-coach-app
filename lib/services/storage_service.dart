import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

import '../models/running_activity.dart';
import '../models/running_shoe.dart';
import '../models/user_settings.dart';
import '../models/workout.dart';

/// Storage locale su file JSON.
///
/// SCELTA TECNICA
/// --------------
/// Niente database e niente generazione di codice: i dati dell'app sono pochi
/// e strutturati, quindi quattro file JSON nella cartella documenti dell'app
/// sono la soluzione piu' semplice e piu' difficile da rompere. I dati
/// restano sul telefono e sopravvivono alla chiusura dell'app.
///
/// Ogni scrittura e' "atomica": si scrive prima un file temporaneo e poi lo si
/// rinomina, cosi' un'interruzione non lascia un JSON a meta'.
class StorageService {
  StorageService({Directory? overrideDirectory})
      : _overrideDirectory = overrideDirectory;

  static const String settingsFileName = 'settings.json';
  static const String shoesFileName = 'shoes.json';
  static const String workoutsFileName = 'workouts.json';
  static const String activitiesFileName = 'activities.json';

  final Directory? _overrideDirectory;
  Directory? _directory;

  /// Ultimo errore di storage (mostrato in UI se serve).
  String? lastError;

  Future<Directory> _dir() async {
    final Directory? cached = _directory;
    if (cached != null) return cached;

    final Directory base =
        _overrideDirectory ?? await getApplicationDocumentsDirectory();
    final Directory dir = Directory('${base.path}/run_coach');
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    _directory = dir;
    return dir;
  }

  Future<File> _file(String name) async {
    final Directory dir = await _dir();
    return File('${dir.path}/$name');
  }

  Future<String?> _readRaw(String name) async {
    try {
      final File file = await _file(name);
      if (!await file.exists()) return null;
      final String content = await file.readAsString();
      return content.trim().isEmpty ? null : content;
    } catch (error) {
      lastError = 'Lettura di $name non riuscita: $error';
      return null;
    }
  }

  Future<bool> _writeRaw(String name, String content) async {
    try {
      final File target = await _file(name);
      final File temp = File('${target.path}.tmp');
      await temp.writeAsString(content, flush: true);
      if (await target.exists()) {
        await target.delete();
      }
      await temp.rename(target.path);
      lastError = null;
      return true;
    } catch (error) {
      lastError = 'Salvataggio di $name non riuscito: $error';
      return false;
    }
  }

  // ---------------------------------------------------------------- settings
  Future<UserSettings> loadSettings() async {
    final String? raw = await _readRaw(settingsFileName);
    if (raw == null) return const UserSettings();
    try {
      final Object? decoded = jsonDecode(raw);
      if (decoded is Map) {
        return UserSettings.fromJson(decoded.cast<String, dynamic>());
      }
    } catch (error) {
      lastError = 'Impostazioni non leggibili: $error';
    }
    return const UserSettings();
  }

  Future<bool> saveSettings(UserSettings settings) =>
      _writeRaw(settingsFileName, jsonEncode(settings.toJson()));

  // ------------------------------------------------------------------- shoes
  Future<List<RunningShoe>> loadShoes() async {
    final List<Map<String, dynamic>> raw = await _readList(shoesFileName);
    final List<RunningShoe> shoes = <RunningShoe>[];
    for (final Map<String, dynamic> item in raw) {
      try {
        shoes.add(RunningShoe.fromJson(item));
      } catch (_) {
        // Elemento corrotto: viene ignorato invece di far fallire tutto.
      }
    }
    return shoes;
  }

  Future<bool> saveShoes(List<RunningShoe> shoes) => _writeRaw(
        shoesFileName,
        jsonEncode(shoes.map((RunningShoe s) => s.toJson()).toList()),
      );

  // ---------------------------------------------------------------- workouts
  Future<List<Workout>> loadWorkouts() async {
    final List<Map<String, dynamic>> raw = await _readList(workoutsFileName);
    final List<Workout> workouts = <Workout>[];
    for (final Map<String, dynamic> item in raw) {
      try {
        workouts.add(Workout.fromJson(item));
      } catch (_) {
        // Elemento corrotto: ignorato.
      }
    }
    return workouts;
  }

  Future<bool> saveWorkouts(List<Workout> workouts) => _writeRaw(
        workoutsFileName,
        jsonEncode(workouts.map((Workout w) => w.toJson()).toList()),
      );

  // -------------------------------------------------------------- activities
  Future<List<RunningActivity>> loadActivities() async {
    final List<Map<String, dynamic>> raw = await _readList(activitiesFileName);
    final List<RunningActivity> activities = <RunningActivity>[];
    for (final Map<String, dynamic> item in raw) {
      try {
        activities.add(RunningActivity.fromJson(item));
      } catch (_) {
        // Elemento corrotto: ignorato.
      }
    }
    activities.sort((RunningActivity a, RunningActivity b) =>
        b.startTime.compareTo(a.startTime));
    return activities;
  }

  Future<bool> saveActivities(List<RunningActivity> activities) => _writeRaw(
        activitiesFileName,
        jsonEncode(
            activities.map((RunningActivity a) => a.toJson()).toList()),
      );

  // ------------------------------------------------------------------ helper
  Future<List<Map<String, dynamic>>> _readList(String name) async {
    final String? raw = await _readRaw(name);
    if (raw == null) return <Map<String, dynamic>>[];
    try {
      final Object? decoded = jsonDecode(raw);
      if (decoded is List) {
        return decoded
            .whereType<Map<dynamic, dynamic>>()
            .map((Map<dynamic, dynamic> e) => e.cast<String, dynamic>())
            .toList();
      }
    } catch (error) {
      lastError = 'File $name non leggibile: $error';
    }
    return <Map<String, dynamic>>[];
  }
}
