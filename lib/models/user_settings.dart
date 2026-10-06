import 'weekly_availability.dart';

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
WeeklyAvailability? _availabilityFromJson(dynamic raw) {
  if (raw is! Map<dynamic, dynamic>) return null;
  final WeeklyAvailability letta =
      WeeklyAvailability.fromJson(raw.cast<String, dynamic>());
  return letta.isEmpty ? null : letta;
}

/// Chiaro, scuro, o come il telefono.
///
/// PERCHE' UNA SCELTA DENTRO L'APP E NON SOLO QUELLA DI SISTEMA
/// ------------------------------------------------------------
/// Perche' sono due decisioni diverse. Il telefono e' chiaro tutto il giorno
/// per leggere i messaggi al sole; un'app che si guarda la sera, o che si
/// riapre dopo una corsa, puo' voler stare scura lo stesso. Legare le due cose
/// costringe a cambiare tutto il telefono per cambiare un'app.
enum ThemeChoice { sistema, chiaro, scuro }

extension ThemeChoiceLabel on ThemeChoice {
  String get label {
    switch (this) {
      case ThemeChoice.sistema:
        return 'Come il telefono';
      case ThemeChoice.chiaro:
        return 'Chiaro';
      case ThemeChoice.scuro:
        return 'Scuro';
    }
  }

  String get description {
    switch (this) {
      case ThemeChoice.sistema:
        return 'Segue l\'impostazione di Android.';
      case ThemeChoice.chiaro:
        return 'Sempre chiaro, anche di notte.';
      case ThemeChoice.scuro:
        return 'Sempre scuro. Su uno schermo OLED consuma anche meno.';
    }
  }

  String get storageKey => name;

  static ThemeChoice fromStorage(String? value) {
    for (final ThemeChoice t in ThemeChoice.values) {
      if (t.name == value) return t;
    }
    return ThemeChoice.sistema;
  }
}

/// Quanto deve dire la voce a ogni chilometro.
///
/// PERCHE' UNA SCELTA E NON UN INTERRUTTORE PER OGNI COSA
/// ------------------------------------------------------
/// Perche' cinque interruttori separati - dimmi il totale, dimmi il confronto,
/// dimmi la cadenza - costringono a decidere cinque volte una cosa sola: quanto
/// vuoi sentire parlare mentre corri. Tre livelli rispondono alla domanda vera,
/// e chi li prova capisce subito la differenza senza leggere niente.
enum SpokenDetail {
  /// Solo il chilometro e il suo passo. Il minimo per non guardare il telefono.
  essenziale,

  /// Aggiunge il confronto col chilometro prima e il totale: e' il livello che
  /// serve a correggere l'andatura mentre sei ancora in tempo.
  completo,

  /// Aggiunge la cadenza e, negli allenamenti, quanto manca alla fine.
  tutto,
}

extension SpokenDetailLabel on SpokenDetail {
  String get label {
    switch (this) {
      case SpokenDetail.essenziale:
        return 'Essenziale';
      case SpokenDetail.completo:
        return 'Completo';
      case SpokenDetail.tutto:
        return 'Tutto';
    }
  }

  String get description {
    switch (this) {
      case SpokenDetail.essenziale:
        return 'Il chilometro e il suo passo, e basta.';
      case SpokenDetail.completo:
        return 'Aggiunge quanto sei andato piu\' veloce o piu\' piano del '
            'chilometro prima, e il totale fin li\'.';
      case SpokenDetail.tutto:
        return 'Aggiunge la cadenza e, negli allenamenti, quanto manca.';
    }
  }

  String get storageKey => name;

  static SpokenDetail fromStorage(String? value) {
    for (final SpokenDetail d in SpokenDetail.values) {
      if (d.name == value) return d;
    }
    return SpokenDetail.completo;
  }
}

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
    this.backgroundTrackingEnabled = true,
    this.welcomeDone = false,
    this.mapEnabled = false,
    this.ttsVoice = '',
    this.ttsEngine = '',
    this.spokenDetail = SpokenDetail.completo,
    this.theme = ThemeChoice.sistema,
    this.weeklyAvailability,
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

  /// La voce scelta dall'utente, fra quelle installate sul telefono.
  ///
  /// PERCHE' SI SALVA IL NOME E NON LA VOCE
  /// --------------------------------------
  /// Perche' la voce non e' dell'app, e' del telefono: l'app puo' solo
  /// chiedere al sistema di usarne una fra quelle che ci sono. Se un giorno
  /// quella voce viene disinstallata, il nome qui dentro non corrisponde piu'
  /// a niente e si torna automaticamente alla scelta migliore disponibile -
  /// che e' meglio di restare muti.
  ///
  /// Vuoto = la sceglie l'app.
  final String ttsVoice;

  /// Il motore vocale scelto (su Android ce n'e' spesso piu' d'uno).
  /// Vuoto = quello predefinito del telefono.
  final String ttsEngine;

  /// Quanto deve dire il coach a ogni chilometro.
  final SpokenDetail spokenDetail;

  /// Chiaro, scuro, o come il telefono.
  final ThemeChoice theme;

  /// Continua a registrare con lo schermo spento e l'app in secondo piano.
  ///
  /// Quando e' attivo, durante la corsa compare una notifica permanente:
  /// e' il modo con cui Android garantisce che il processo non venga chiuso.
  final bool backgroundTrackingEnabled;

  /// `true` dopo che la schermata di benvenuto e' stata completata o saltata.
  ///
  /// Serve un campo suo invece di guardare se il nome e' vuoto: chi decide di
  /// non metterlo non deve ritrovarsi la domanda a ogni avvio.
  final bool welcomeDone;

  /// Mostra la mappa vera sotto al percorso delle corse.
  ///
  /// PERCHE' NASCE SPENTA
  /// --------------------
  /// Perche' e' l'unica funzione di Falcata che ha bisogno di internet e
  /// l'unica che costa qualcosa ogni mese: i riquadri di mappa li serve un
  /// fornitore, e si pagano a consumo. Il disegno del percorso - che per
  /// riconoscere il proprio giro basta e avanza - non costa niente e c'e'
  /// sempre.
  ///
  /// Spenta di default vuol dire che chi non la accende non manda nessuna
  /// richiesta a nessuno e non fa crescere nessun conto. Chi la vuole la
  /// accende, e i riquadri che scarica restano nel telefono: la stessa corsa
  /// riaperta non ne chiede piu' nemmeno uno.
  final bool mapEnabled;

  /// I giorni della settimana in cui puo' correre e quanti minuti ha su
  /// ognuno.
  ///
  /// PERCHE' STA QUI E NON NEL PIANO
  /// -------------------------------
  /// Prima viveva solo dentro il piano, e la schermata di creazione la
  /// rileggeva da li'. Ma la settimana di una persona non e' una proprieta'
  /// del piano: e' una proprieta' sua. Senza piano - o dopo averlo
  /// cancellato - i giorni sparivano e si tornava allo schema standard
  /// (lungo di domenica, qualita' martedi' e giovedi'), che e' esattamente
  /// quello che questa funzione esisteva per non fare.
  ///
  /// `null` = non l'ha ancora dichiarata.
  final WeeklyAvailability? weeklyAvailability;

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
    bool? backgroundTrackingEnabled,
    bool? welcomeDone,
    bool? mapEnabled,
    String? ttsVoice,
    String? ttsEngine,
    SpokenDetail? spokenDetail,
    ThemeChoice? theme,
    WeeklyAvailability? weeklyAvailability,
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
        backgroundTrackingEnabled:
            backgroundTrackingEnabled ?? this.backgroundTrackingEnabled,
        welcomeDone: welcomeDone ?? this.welcomeDone,
        mapEnabled: mapEnabled ?? this.mapEnabled,
        ttsVoice: ttsVoice ?? this.ttsVoice,
        ttsEngine: ttsEngine ?? this.ttsEngine,
        spokenDetail: spokenDetail ?? this.spokenDetail,
        theme: theme ?? this.theme,
        weeklyAvailability: weeklyAvailability ?? this.weeklyAvailability,
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
        'backgroundTrackingEnabled': backgroundTrackingEnabled,
        'welcomeDone': welcomeDone,
        'mapEnabled': mapEnabled,
        'ttsVoice': ttsVoice,
        'ttsEngine': ttsEngine,
        'spokenDetail': spokenDetail.name,
        'theme': theme.name,
        if (weeklyAvailability != null)
          'weeklyAvailability': weeklyAvailability!.toJson(),
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
        backgroundTrackingEnabled:
            json['backgroundTrackingEnabled'] as bool? ?? true,
        // Chi ha gia' l'app installata non deve rivedere il benvenuto: se il
        // nome c'e' gia', il giro e' considerato fatto.
        welcomeDone: json['welcomeDone'] as bool? ??
            ((json['userName'] as String? ?? '').trim().isNotEmpty),
        mapEnabled: json['mapEnabled'] as bool? ?? false,
        ttsVoice: json['ttsVoice'] as String? ?? '',
        ttsEngine: json['ttsEngine'] as String? ?? '',
        spokenDetail:
            SpokenDetailLabel.fromStorage(json['spokenDetail'] as String?),
        theme: ThemeChoiceLabel.fromStorage(json['theme'] as String?),
        weeklyAvailability: _availabilityFromJson(json['weeklyAvailability']),
      );
}
