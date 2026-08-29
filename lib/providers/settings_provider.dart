import 'package:flutter/foundation.dart';

import '../models/user_settings.dart';
import '../services/audio_coach_service.dart';
import '../services/storage_service.dart';

/// Stato delle impostazioni utente, persistite su file.
class SettingsProvider extends ChangeNotifier {
  SettingsProvider({
    required StorageService storage,
    required AudioCoachService coach,
  })  : _storage = storage,
        _coach = coach;

  final StorageService _storage;
  final AudioCoachService _coach;

  UserSettings _settings = const UserSettings();
  bool _loaded = false;
  String? _errorMessage;

  UserSettings get settings => _settings;
  bool get isLoaded => _loaded;
  String? get errorMessage => _errorMessage;

  Future<void> load() async {
    _settings = await _storage.loadSettings();
    _loaded = true;
    _errorMessage = _storage.lastError;
    await _coach.applySettings(_settings);
    notifyListeners();
  }

  Future<void> update(UserSettings next) async {
    _settings = next;
    notifyListeners();
    final bool ok = await _storage.saveSettings(next);
    _errorMessage = ok ? null : _storage.lastError;
    await _coach.applySettings(next);
    if (!ok) notifyListeners();
  }

  Future<void> setUserName(String name) =>
      update(_settings.copyWith(userName: name));

  Future<void> setAudioCoachEnabled(bool enabled) =>
      update(_settings.copyWith(audioCoachEnabled: enabled));

  Future<void> setCoachVolume(double volume) =>
      update(_settings.copyWith(coachVolume: volume));

  Future<void> setSpeechRate(double rate) =>
      update(_settings.copyWith(speechRate: rate));

  Future<void> setCoachPersonality(CoachPersonality personality) =>
      update(_settings.copyWith(coachPersonality: personality));

  Future<void> setAutoLapEnabled(bool enabled) =>
      update(_settings.copyWith(autoLapEnabled: enabled));

  Future<void> setAutoLapDistance(double meters) =>
      update(_settings.copyWith(autoLapDistanceMeters: meters));

  Future<void> setPaceAlertsEnabled(bool enabled) =>
      update(_settings.copyWith(paceAlertsEnabled: enabled));

  Future<void> setPaceAlertCooldown(int seconds) =>
      update(_settings.copyWith(paceAlertCooldownSeconds: seconds));

  Future<void> setKeepScreenOn(bool enabled) =>
      update(_settings.copyWith(keepScreenOn: enabled));

  Future<void> setUnits(UnitSystem units) =>
      update(_settings.copyWith(units: units));

  /// Prova la voce del coach con la personalita' attualmente selezionata.
  Future<void> testVoice() async {
    await _coach.applySettings(_settings);
    await _coach.speak(_coach.phrases.start());
  }
}
