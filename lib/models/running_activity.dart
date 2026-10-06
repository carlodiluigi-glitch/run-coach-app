import 'effort.dart';
import 'health_data.dart';
import 'lap.dart';
import '../utils/formatters.dart';
import '../utils/id_generator.dart';

/// Tipo di attivita' registrata.
enum ActivityType { free, workout }

/// Cosa era davvero questa uscita, secondo chi l'ha corsa.
///
/// PERCHE' SERVE DICHIARARLO
/// -------------------------
/// Il motore di forma pesa una prestazione in base a quanto e' affidabile, e
/// un tratto veloce dentro una corsa qualsiasi vale 0,45: giusto, perche' non
/// si sa se l'atleta stava spingendo o se era una discesa.
///
/// Il problema e' che senza questo campo una gara CORSA CON L'APP valeva 0,45
/// mentre la stessa gara DIGITATA A MANO nel profilo valeva 1,00. Cioe' il
/// dato misurato dal GPS contava meno di quello battuto sulla tastiera, che
/// e' esattamente al contrario di come dovrebbe essere.
enum EffortKind { race, timeTrial }

extension EffortKindInfo on EffortKind {
  String get label => this == EffortKind.race ? 'Gara' : 'Test';

  String get description => this == EffortKind.race
      ? 'Una gara vera: vale il massimo per la stima della forma.'
      : 'Una prova tirata a fondo da solo: vale quasi quanto una gara.';

  String get storageKey => name;

  static EffortKind? fromStorage(String? value) {
    for (final EffortKind k in EffortKind.values) {
      if (k.name == value) return k;
    }
    return null;
  }
}

extension ActivityTypeLabel on ActivityType {
  String get label => this == ActivityType.free ? 'Corsa libera' : 'Allenamento';

  static ActivityType fromStorage(String? value) =>
      value == 'workout' ? ActivityType.workout : ActivityType.free;
}

/// Punto del tracciato GPS accettato dal filtro.
class RoutePoint {
  const RoutePoint({
    required this.latitude,
    required this.longitude,
    required this.elapsedSeconds,
    this.altitude,
    this.speed,
    this.steps,
  });

  final double latitude;
  final double longitude;

  /// Secondi di tempo attivo dall'inizio dell'attivita'.
  final int elapsedSeconds;

  final double? altitude;

  /// Velocita' in metri al secondo misurata dal chip GPS, se l'ha riportata.
  ///
  /// PERCHE' VIENE SALVATA
  /// ---------------------
  /// Perche' e' il dato buono. Il chip la ricava dallo spostamento di frequenza
  /// del segnale dei satelliti - l'effetto Doppler - e non dalle posizioni:
  /// resta precisa a qualche decimo di metro al secondo anche quando la
  /// posizione balla di dieci metri.
  ///
  /// La distanza della corsa gia' la usa. Ma anche DOPO, a corsa finita,
  /// l'app rilegge il tracciato per capire che seduta e' stata e quanto e'
  /// costata - e per farlo misurava il passo dalle posizioni, cioe' con lo
  /// stesso difetto, un passo piu' in la': qualche secondo al chilometro, ma
  /// sempre nella stessa direzione. Salvandola qui, quei conti leggono la
  /// misura buona invece di rifare l'errore.
  ///
  /// `null` sui tracciati registrati prima, e sui telefoni che non la
  /// riportano: in quel caso si torna alle posizioni.
  final double? speed;

  /// Passi contati dall'inizio della corsa fino a questo punto.
  ///
  /// PERCHE' CUMULATIVI E NON "I PASSI DI QUESTO TRATTO"
  /// ---------------------------------------------------
  /// Perche' un totale che cresce non si puo' sbagliare a rileggere: la cadenza
  /// fra due punti qualsiasi e' la differenza divisa per il tempo, e funziona
  /// anche raggruppando dieci punti in uno - che e' esattamente quello che fa
  /// il grafico per starci nello schermo. Se qui ci fosse "i passi di questo
  /// tratto", unire dei tratti vorrebbe dire sommarli, e un punto perso li
  /// perderebbe per sempre.
  ///
  /// Un totale, invece, si ricuce da solo: se manca un punto in mezzo, la
  /// differenza fra quello prima e quello dopo e' ancora giusta.
  ///
  /// `null` sulle corse registrate prima della cadenza, sui telefoni senza
  /// sensore di passo, e quando il permesso e' stato negato.
  final int? steps;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'lat': latitude,
        'lon': longitude,
        't': elapsedSeconds,
        'alt': altitude,
        if (speed != null) 'v': speed,
        if (steps != null) 'p': steps,
      };

  factory RoutePoint.fromJson(Map<String, dynamic> json) => RoutePoint(
        latitude: (json['lat'] as num?)?.toDouble() ?? 0.0,
        longitude: (json['lon'] as num?)?.toDouble() ?? 0.0,
        elapsedSeconds: (json['t'] as num?)?.toInt() ?? 0,
        altitude: (json['alt'] as num?)?.toDouble(),
        speed: (json['v'] as num?)?.toDouble(),
        steps: (json['p'] as num?)?.toInt(),
      );
}

/// Una attivita' di corsa salvata nello storico.
class RunningActivity {
  RunningActivity({
    String? id,
    required this.startTime,
    required this.name,
    required this.type,
    required this.durationSeconds,
    required this.distanceMeters,
    List<Lap>? laps,
    List<RoutePoint>? route,
    this.shoeId,
    this.workoutId,
    this.note,
    this.feedback,
    this.plannedSessionKey,
    this.declared,
    // --- Campi predisposti per il futuro (mai inventati) ---
    this.dynamics,
    this.heartRateAverage,
    this.heartRateMax,
    List<HeartRateSample>? heartRateSamples,
    this.hrv,
    this.sleep,
  })  : id = id ?? IdGenerator.newId('act'),
        laps = laps ?? <Lap>[],
        route = route ?? <RoutePoint>[],
        heartRateSamples = heartRateSamples ?? <HeartRateSample>[];

  final String id;
  final DateTime startTime;
  final String name;
  final ActivityType type;

  /// Tempo attivo in secondi (le pause NON sono conteggiate).
  final int durationSeconds;

  final double distanceMeters;
  final List<Lap> laps;
  final List<RoutePoint> route;

  /// Id della scarpa usata (vedi `RunningShoe`).
  final String? shoeId;

  /// Id dell'allenamento programmato eseguito, se presente.
  final String? workoutId;

  final String? note;

  /// Come e' andata secondo chi l'ha corsa: fatica percepita, gambe, dolori.
  ///
  /// E' l'unico dato che il telefono non puo' misurare da solo, ed e' anche
  /// il piu' informativo: dice quanto e' costata la seduta, non solo cosa e'
  /// stato fatto.
  final SessionFeedback? feedback;

  /// A quale seduta del piano corrisponde questa attivita'.
  ///
  /// E' la data della seduta in formato `aaaa-mm-gg`, non un identificatore:
  /// il piano viene ricalcolato a ogni avvio, quindi gli id interni cambiano
  /// mentre la data no. Serve a confrontare previsto ed effettivo.
  final String? plannedSessionKey;

  /// Gara o test, se l'atleta l'ha dichiarato. `null` = uscita normale.
  ///
  /// Non si deduce da solo e non si indovina: lo dice l'atleta dal dettaglio
  /// dell'attivita'. Vedi [EffortKind].
  final EffortKind? declared;

  // ---- Predisposizione funzioni future -------------------------------------
  /// Cadenza, lunghezza passo, oscillazione verticale. `null` se non misurate.
  final RunningDynamics? dynamics;

  final int? heartRateAverage;
  final int? heartRateMax;
  final List<HeartRateSample> heartRateSamples;
  final HrvData? hrv;
  final SleepData? sleep;

  /// Passo medio in secondi per chilometro (`null` se non calcolabile).
  double? get averagePaceSecondsPerKm =>
      paceFromDistanceAndTime(distanceMeters, durationSeconds);

  double get distanceKm => distanceMeters / 1000.0;

  Duration get duration => Duration(seconds: durationSeconds);

  /// `true` se l'atleta ha dichiarato dolore su questa seduta.
  bool get reportedPain => feedback?.hasPain ?? false;

  /// Fatica percepita, se dichiarata.
  int? get rpe => feedback?.rpe;

  /// `true` se l'atleta ha dichiarato che era una gara o un test.
  bool get isDeclaredEffort => declared != null;

  RunningActivity copyWith({
    String? name,
    String? shoeId,
    bool clearShoe = false,
    String? note,
    SessionFeedback? feedback,
    String? plannedSessionKey,
    EffortKind? declared,
    bool clearDeclared = false,
  }) =>
      RunningActivity(
        id: id,
        startTime: startTime,
        name: name ?? this.name,
        type: type,
        durationSeconds: durationSeconds,
        distanceMeters: distanceMeters,
        laps: laps,
        route: route,
        shoeId: clearShoe ? null : (shoeId ?? this.shoeId),
        workoutId: workoutId,
        note: note ?? this.note,
        feedback: feedback ?? this.feedback,
        plannedSessionKey: plannedSessionKey ?? this.plannedSessionKey,
        declared: clearDeclared ? null : (declared ?? this.declared),
        dynamics: dynamics,
        heartRateAverage: heartRateAverage,
        heartRateMax: heartRateMax,
        heartRateSamples: heartRateSamples,
        hrv: hrv,
        sleep: sleep,
      );

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'startTime': startTime.toIso8601String(),
        'name': name,
        'type': type.name,
        'durationSeconds': durationSeconds,
        'distanceMeters': distanceMeters,
        'laps': laps.map((Lap l) => l.toJson()).toList(),
        'route': route.map((RoutePoint p) => p.toJson()).toList(),
        'shoeId': shoeId,
        'workoutId': workoutId,
        'note': note,
        'feedback': feedback?.toJson(),
        'plannedSessionKey': plannedSessionKey,
        'declared': declared?.storageKey,
        'dynamics': dynamics?.toJson(),
        'heartRateAverage': heartRateAverage,
        'heartRateMax': heartRateMax,
        'heartRateSamples':
            heartRateSamples.map((HeartRateSample s) => s.toJson()).toList(),
        'hrv': hrv?.toJson(),
        'sleep': sleep?.toJson(),
      };

  factory RunningActivity.fromJson(Map<String, dynamic> json) {
    final List<dynamic> rawLaps = (json['laps'] as List<dynamic>?) ?? <dynamic>[];
    final List<dynamic> rawRoute =
        (json['route'] as List<dynamic>?) ?? <dynamic>[];
    final List<dynamic> rawHr =
        (json['heartRateSamples'] as List<dynamic>?) ?? <dynamic>[];
    final Map<String, dynamic>? rawFeedback =
        (json['feedback'] as Map?)?.cast<String, dynamic>();
    final Map<String, dynamic>? rawDynamics =
        (json['dynamics'] as Map?)?.cast<String, dynamic>();
    final Map<String, dynamic>? rawHrv =
        (json['hrv'] as Map?)?.cast<String, dynamic>();
    final Map<String, dynamic>? rawSleep =
        (json['sleep'] as Map?)?.cast<String, dynamic>();

    return RunningActivity(
      id: json['id'] as String?,
      startTime: DateTime.tryParse(json['startTime'] as String? ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
      name: json['name'] as String? ?? 'Corsa',
      type: ActivityTypeLabel.fromStorage(json['type'] as String?),
      durationSeconds: (json['durationSeconds'] as num?)?.toInt() ?? 0,
      distanceMeters: (json['distanceMeters'] as num?)?.toDouble() ?? 0.0,
      laps: rawLaps
          .map((dynamic e) => Lap.fromJson((e as Map).cast<String, dynamic>()))
          .toList(),
      route: rawRoute
          .map((dynamic e) =>
              RoutePoint.fromJson((e as Map).cast<String, dynamic>()))
          .toList(),
      shoeId: json['shoeId'] as String?,
      workoutId: json['workoutId'] as String?,
      note: json['note'] as String?,
      feedback:
          rawFeedback == null ? null : SessionFeedback.fromJson(rawFeedback),
      plannedSessionKey: json['plannedSessionKey'] as String?,
      declared: EffortKindInfo.fromStorage(json['declared'] as String?),
      dynamics:
          rawDynamics == null ? null : RunningDynamics.fromJson(rawDynamics),
      heartRateAverage: (json['heartRateAverage'] as num?)?.toInt(),
      heartRateMax: (json['heartRateMax'] as num?)?.toInt(),
      heartRateSamples: rawHr
          .map((dynamic e) =>
              HeartRateSample.fromJson((e as Map).cast<String, dynamic>()))
          .toList(),
      hrv: rawHrv == null ? null : HrvData.fromJson(rawHrv),
      sleep: rawSleep == null ? null : SleepData.fromJson(rawSleep),
    );
  }
}
