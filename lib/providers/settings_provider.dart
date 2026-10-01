import 'package:flutter/foundation.dart';

import '../models/user_settings.dart';
import '../models/weekly_availability.dart';
import '../services/audio_coach_service.dart';
import '../services/storage_service.dart';
import '../utils/units.dart';

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
    activeUnits = _settings.units;
    _loaded = true;
    _errorMessage = _storage.lastError;
    await _coach.applySettings(_settings);
    notifyListeners();
  }

  Future<void> update(UserSettings next) async {
    _settings = next;
    // Chi formatta i numeri legge da qui: va aggiornata prima di ridisegnare,
    // altrimenti lo schermo si ricostruisce con l'unita' vecchia.
    activeUnits = next.units;
    notifyListeners();
    final bool ok = await _storage.saveSettings(next);
    _errorMessage = ok ? null : _storage.lastError;
    await _coach.applySettings(next);
    if (!ok) notifyListeners();
  }

  Future<void> setUserName(String name) =>
      update(_settings.copyWith(userName: name));

  /// Chiude la schermata di benvenuto, salvando il nome inserito.
  ///
  /// Nome e "benvenuto fatto" vengono scritti insieme: due salvataggi di fila
  /// potrebbero lasciare il file a meta' se l'app viene chiusa nel mezzo.
  Future<void> completeWelcome({
    String name = '',
    UnitSystem units = UnitSystem.metric,
  }) =>
      update(_settings.copyWith(
        userName: name.trim(),
        units: units,
        welcomeDone: true,
      ));

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

  Future<void> setBackgroundTracking(bool enabled) =>
      update(_settings.copyWith(backgroundTrackingEnabled: enabled));

  Future<void> setUnits(UnitSystem units) =>
      update(_settings.copyWith(units: units));

  /// Ricorda i giorni e i minuti in cui puo' correre.
  ///
  /// Si salva alla creazione di un piano, ma vive qui e non nel piano: la
  /// settimana e' una proprieta' dell'atleta, non dell'allenamento. Cosi'
  /// resta anche dopo aver cancellato un piano.
  Future<void> setWeeklyAvailability(WeeklyAvailability availability) =>
      update(_settings.copyWith(weeklyAvailability: availability));

  /// Prova la voce del coach con la personalita' attualmente selezionata.
  Future<void> testVoice() async {
    await _coach.applySettings(_settings);
    await _coach.speak(_coach.phrases.start());
  }
}
