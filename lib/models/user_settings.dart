/// Sistema di unita' di misura. Per ora solo metrico, ma l'enum e' gia'
/// predisposto per l'aggiunta di quello imperiale.
enum UnitSystem { metric, imperial }

/// Personalita' del coach vocale.
enum CoachPersonality { normal, motivational, sergeant }

extension UnitSystemLabel on UnitSystem {
  String get label => this == UnitSystem.metric ? 'Metrico (km)' : 'Imperiale (mi)';

  static UnitSystem fromStorage(String? value) =>
      value == 'imperial' ? UnitSystem.imperial : UnitSystem.metric;
}

extension CoachPersonalityLabel on CoachPersonality {
  String get label {
    switch (this) {
      case CoachPersonality.normal:
        return 'Normale';
      case CoachPersonality.motivational:
        return 'Motivazionale';
      case CoachPersonality.sergeant:
        return 'Sergente';
    }
  }

  String get description {
    switch (this) {
      case CoachPersonality.normal:
        return 'Indicazioni essenziali e neutre.';
      case CoachPersonality.motivational:
        return 'Incoraggiamenti e rinforzo positivo.';
      case CoachPersonality.sergeant:
        return 'Tono duro e ironico, sempre rispettoso.';
    }
  }

  static CoachPersonality fromStorage(String? value) {
    for (final CoachPersonality p in CoachPersonality.values) {
      if (p.name == value) return p;
    }
    return CoachPersonality.normal;
  }
}

/// Impostazioni dell'utente, salvate localmente.
class UserSettings {
  const UserSettings({
    this.userName = '',
    this.units = UnitSystem.metric,
    this.audioCoachEnabled = true,
    this.coachVolume = 1.0,
    this.coachPersonality = CoachPersonality.normal,
    this.autoLapEnabled = true,
    this.autoLapDistanceMeters = 1000.0,
    this.paceAlertsEnabled = true,
    this.paceAlertCooldownSeconds = 20,
    this.keepScreenOn = true,
    this.speechRate = 0.5,
  });

  /// Nome mostrato nella Home ("Ciao <nome>"). Vuoto = saluto generico.
  final String userName;

  final UnitSystem units;
  final bool audioCoachEnabled;

  /// Volume del coach, 0.0 - 1.0.
  final double coachVolume;

  final CoachPersonality coachPersonality;

  final bool autoLapEnabled;

  /// Distanza del lap automatico in metri (default 1000 = 1 km).
  final double autoLapDistanceMeters;

  final bool paceAlertsEnabled;

  /// Intervallo minimo fra due avvisi di ritmo, in secondi.
  final int paceAlertCooldownSeconds;

  /// Mantiene lo schermo acceso durante la corsa.
  final bool keepScreenOn;

  /// Velocita' di lettura del TTS (0.0 - 1.0 su Android).
  final double speechRate;

  bool get hasUserName => userName.trim().isNotEmpty;

  String get greeting => hasUserName ? 'Ciao ${userName.trim()}' : 'Ciao!';

  UserSettings copyWith({
    String? userName,
    UnitSystem? units,
    bool? audioCoachEnabled,
    double? coachVolume,
    CoachPersonality? coachPersonality,
    bool? autoLapEnabled,
    double? autoLapDistanceMeters,
    bool? paceAlertsEnabled,
    int? paceAlertCooldownSeconds,
    bool? keepScreenOn,
    double? speechRate,
  }) =>
      UserSettings(
        userName: userName ?? this.userName,
        units: units ?? this.units,
        audioCoachEnabled: audioCoachEnabled ?? this.audioCoachEnabled,
        coachVolume: coachVolume ?? this.coachVolume,
        coachPersonality: coachPersonality ?? this.coachPersonality,
        autoLapEnabled: autoLapEnabled ?? this.autoLapEnabled,
        autoLapDistanceMeters:
            autoLapDistanceMeters ?? this.autoLapDistanceMeters,
        paceAlertsEnabled: paceAlertsEnabled ?? this.paceAlertsEnabled,
        paceAlertCooldownSeconds:
            paceAlertCooldownSeconds ?? this.paceAlertCooldownSeconds,
        keepScreenOn: keepScreenOn ?? this.keepScreenOn,
        speechRate: speechRate ?? this.speechRate,
      );

  Map<String, dynamic> toJson() => <String, dynamic>{
        'userName': userName,
        'units': units.name,
        'audioCoachEnabled': audioCoachEnabled,
        'coachVolume': coachVolume,
        'coachPersonality': coachPersonality.name,
        'autoLapEnabled': autoLapEnabled,
        'autoLapDistanceMeters': autoLapDistanceMeters,
        'paceAlertsEnabled': paceAlertsEnabled,
        'paceAlertCooldownSeconds': paceAlertCooldownSeconds,
        'keepScreenOn': keepScreenOn,
        'speechRate': speechRate,
      };

  factory UserSettings.fromJson(Map<String, dynamic> json) => UserSettings(
        userName: json['userName'] as String? ?? '',
        units: UnitSystemLabel.fromStorage(json['units'] as String?),
        audioCoachEnabled: json['audioCoachEnabled'] as bool? ?? true,
        coachVolume: (json['coachVolume'] as num?)?.toDouble() ?? 1.0,
        coachPersonality: CoachPersonalityLabel.fromStorage(
            json['coachPersonality'] as String?),
        autoLapEnabled: json['autoLapEnabled'] as bool? ?? true,
        autoLapDistanceMeters:
            (json['autoLapDistanceMeters'] as num?)?.toDouble() ?? 1000.0,
        paceAlertsEnabled: json['paceAlertsEnabled'] as bool? ?? true,
        paceAlertCooldownSeconds:
            (json['paceAlertCooldownSeconds'] as num?)?.toInt() ?? 20,
        keepScreenOn: json['keepScreenOn'] as bool? ?? true,
        speechRate: (json['speechRate'] as num?)?.toDouble() ?? 0.5,
      );
}
