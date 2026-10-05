import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

import '../models/athlete_profile.dart';
import '../models/daily_checkin.dart';
import '../models/run_snapshot.dart';
import '../models/running_activity.dart';
import '../models/running_shoe.dart';
import '../models/training_plan.dart';
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
  static const String planFileName = 'plan.json';
  static const String profileFileName = 'profile.json';
  static const String checkInsFileName = 'checkins.json';
  static const String runInProgressFileName = 'corsa_in_corso.json';

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

  // -------------------------------------------------------------------- piano
  /// Del piano si salvano solo i parametri: le sedute vengono ricalcolate.
  /// Restituisce `null` se non c'e' nessun piano attivo.
  Future<PlanConfig?> loadPlanConfig() async {
    final String? raw = await _readRaw(planFileName);
    if (raw == null) return null;
    try {
      final Object? decoded = jsonDecode(raw);
      if (decoded is Map) {
        return PlanConfig.fromJson(decoded.cast<String, dynamic>());
      }
    } catch (error) {
      lastError = 'Piano non leggibile: $error';
    }
    return null;
  }

  Future<bool> savePlanConfig(PlanConfig config) =>
      _writeRaw(planFileName, jsonEncode(config.toJson()));

  // ------------------------------------------------------------------ atleta
  /// Profilo dell'atleta: eta', anni di corsa e personali dichiarati.
  ///
  /// Sta in un file suo e non dentro le impostazioni perche' e' un dato di
  /// allenamento, non una preferenza: il motore di forma lo legge a ogni
  /// calcolo, e i personali dichiarati pesano piu' di qualunque corsa
  /// registrata.
  Future<AthleteProfile> loadAthleteProfile() async {
    final String? raw = await _readRaw(profileFileName);
    if (raw == null) return const AthleteProfile();
    try {
      final Object? decoded = jsonDecode(raw);
      if (decoded is Map) {
        return AthleteProfile.fromJson(decoded.cast<String, dynamic>());
      }
    } catch (error) {
      lastError = 'Profilo non leggibile: $error';
    }
    return const AthleteProfile();
  }

  Future<bool> saveAthleteProfile(AthleteProfile profile) =>
      _writeRaw(profileFileName, jsonEncode(profile.toJson()));

  // ----------------------------------------------------------- check-in
  /// I check-in del mattino, uno per giorno.
  ///
  /// Si tengono solo gli ultimi [checkInsToKeep] giorni: oltre non servono a
  /// nessun conto, e un file che cresce per sempre su un telefono e' un
  /// problema che arriva sempre, solo piu' tardi.
  static const int checkInsToKeep = 120;

  Future<List<DailyCheckIn>> loadCheckIns() async {
    final String? raw = await _readRaw(checkInsFileName);
    if (raw == null) return <DailyCheckIn>[];
    try {
      final Object? decoded = jsonDecode(raw);
      if (decoded is List) {
        return decoded
            .whereType<Map<dynamic, dynamic>>()
            .map((Map<dynamic, dynamic> e) =>
                DailyCheckIn.fromJson(e.cast<String, dynamic>()))
            .toList();
      }
    } catch (error) {
      lastError = 'Check-in non leggibili: $error';
    }
    return <DailyCheckIn>[];
  }

  Future<bool> saveCheckIns(List<DailyCheckIn> checkIns) {
    final List<DailyCheckIn> ordinati = List<DailyCheckIn>.from(checkIns)
      ..sort((DailyCheckIn a, DailyCheckIn b) => b.date.compareTo(a.date));
    final List<DailyCheckIn> tenuti = ordinati.length > checkInsToKeep
        ? ordinati.sublist(0, checkInsToKeep)
        : ordinati;
    return _writeRaw(
      checkInsFileName,
      jsonEncode(tenuti.map((DailyCheckIn c) => c.toJson()).toList()),
    );
  }

  // ------------------------------------------------- corsa in corso
  /// Scrive su disco la corsa che si sta registrando.
  ///
  /// Viene chiamata ogni pochi secondi mentre si corre. E' l'unica scrittura
  /// dell'app che deve essere veloce e frequente, quindi il file resta uno
  /// solo e viene riscritto intero: un file che cresce a pezzi si corrompe
  /// se il processo muore a meta', ed e' proprio quando muore che questo
  /// file serve.
  Future<bool> saveRunSnapshot(RunSnapshot snapshot) =>
      _writeRaw(runInProgressFileName, jsonEncode(snapshot.toJson()));

  /// Rilegge la corsa interrotta, se c'e'.
  Future<RunSnapshot?> loadRunSnapshot() async {
    final String? raw = await _readRaw(runInProgressFileName);
    if (raw == null) return null;
    try {
      final Object? decoded = jsonDecode(raw);
      if (decoded is Map) {
        return RunSnapshot.fromJson(decoded.cast<String, dynamic>());
      }
    } catch (error) {
      // Un file mezzo scritto e' esattamente il caso per cui esiste questa
      // funzione: si butta via senza far rumore, non c'e' niente da
      // recuperare e non e' colpa dell'utente.
      lastError = 'Corsa interrotta non leggibile: $error';
    }
    return null;
  }

  /// Toglie la corsa in corso: si chiama quando e' stata salvata o buttata.
  Future<bool> clearRunSnapshot() async {
    try {
      final File file = await _file(runInProgressFileName);
      if (await file.exists()) await file.delete();
      return true;
    } catch (error) {
      lastError = 'Non riesco a togliere la corsa interrotta: $error';
      return false;
    }
  }

  /// Cancella il piano attivo.
  Future<bool> deletePlanConfig() async {
    try {
      final File file = await _file(planFileName);
      if (await file.exists()) {
        await file.delete();
      }
      lastError = null;
      return true;
    } catch (error) {
      lastError = 'Eliminazione del piano non riuscita: $error';
      return false;
    }
  }

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


  // ======================================================= copia di sicurezza
  /// I file che compongono l'archivio.
  ///
  /// `corsa_in_corso.json` NON c'e' di proposito: e' la corsa che si sta
  /// registrando adesso, non fa parte dell'archivio, e ripristinarla su un
  /// altro telefono farebbe comparire una corsa a meta' che non si e' mai
  /// fatta.
  static const List<String> backupFiles = <String>[
    settingsFileName,
    shoesFileName,
    workoutsFileName,
    activitiesFileName,
    planFileName,
    profileFileName,
    checkInsFileName,
  ];

  /// Marcatore in testa al file: serve a riconoscerlo e a rifiutare tutto il
  /// resto prima di toccare qualcosa.
  static const String backupMarker = 'falcata-backup';
  static const int backupFormat = 1;

  /// Tutto l'archivio in un file solo.
  ///
  /// PERCHE' UN FILE E NON UNA SINCRONIZZAZIONE
  /// ------------------------------------------
  /// Perche' una sincronizzazione vuole un account, un server e un costo
  /// mensile, e Falcata non ha nessuna delle tre cose. Un file lo metti dove
  /// vuoi tu - email a te stesso, chiavetta, Drive - e resta leggibile anche
  /// se un giorno l'app non esiste piu': dentro c'e' JSON, non un formato
  /// chiuso. L'archivio e' tuo davvero solo se puoi portartelo via.
  Future<String?> exportBackup({String appVersion = ''}) async {
    try {
      final Map<String, dynamic> contenuto = <String, dynamic>{};
      for (final String nome in backupFiles) {
        final String? raw = await _readRaw(nome);
        if (raw != null) contenuto[nome] = raw;
      }
      if (contenuto.isEmpty) {
        lastError = 'Non c\'e\' ancora niente da salvare.';
        return null;
      }
      lastError = null;
      return const JsonEncoder.withIndent('  ').convert(<String, dynamic>{
        'tipo': backupMarker,
        'formato': backupFormat,
        'app': appVersion,
        'creato': DateTime.now().toIso8601String(),
        'file': contenuto,
      });
    } catch (error) {
      lastError = 'Copia non riuscita: $error';
      return null;
    }
  }

  /// Rimette l'archivio da una copia.
  ///
  /// LA REGOLA CHE NON SI ROMPE
  /// --------------------------
  /// **Prima si controlla tutto, poi si scrive.** Un file rotto scritto sopra
  /// un archivio buono lo distrugge, e il ripristino e' proprio il momento in
  /// cui l'utente non ha una seconda copia. Quindi: si verifica il marcatore,
  /// si verifica che ogni pezzo sia JSON valido, e solo se e' passato tutto si
  /// tocca il disco.
  ///
  /// I nomi sconosciuti vengono ignorati invece di far fallire il ripristino:
  /// una copia fatta da una versione futura deve poter restituire almeno
  /// quello che questa versione sa leggere.
  Future<BackupReport> importBackup(String raw) async {
    final Object? decodificato;
    try {
      decodificato = jsonDecode(raw);
    } catch (_) {
      return const BackupReport.failed('Questo file non e\' leggibile.');
    }

    if (decodificato is! Map) {
      return const BackupReport.failed('Questo non e\' un file di Falcata.');
    }
    if (decodificato['tipo'] != backupMarker) {
      return const BackupReport.failed(
        'Questo non e\' una copia di Falcata. Non ho toccato niente.',
      );
    }

    final Object? file = decodificato['file'];
    if (file is! Map) {
      return const BackupReport.failed('La copia e\' vuota o danneggiata.');
    }

    // --- primo giro: si controlla, senza scrivere niente ---
    final Map<String, String> daScrivere = <String, String>{};
    for (final String nome in backupFiles) {
      final Object? contenuto = file[nome];
      if (contenuto == null) continue;
      if (contenuto is! String) {
        return BackupReport.failed('Il pezzo "$nome" e\' danneggiato.');
      }
      try {
        jsonDecode(contenuto);
      } catch (_) {
        return BackupReport.failed('Il pezzo "$nome" non e\' leggibile.');
      }
      daScrivere[nome] = contenuto;
    }

    if (daScrivere.isEmpty) {
      return const BackupReport.failed(
        'Nella copia non c\'e\' niente che questa versione sappia leggere.',
      );
    }

    // --- secondo giro: adesso si scrive ---
    final List<String> fatti = <String>[];
    for (final MapEntry<String, String> e in daScrivere.entries) {
      if (await _writeRaw(e.key, e.value)) {
        fatti.add(e.key);
      } else {
        return BackupReport.failed(
          'Scrittura di "${e.key}" non riuscita: $lastError',
        );
      }
    }

    // La corsa in corso non appartiene all'archivio ripristinato.
    await clearRunSnapshot();

    return BackupReport.ok(
      fatti,
      createdAt: DateTime.tryParse(decodificato['creato'] as String? ?? ''),
    );
  }
}

/// Esito di un ripristino.
class BackupReport {
  const BackupReport.ok(this.restored, {this.createdAt}) : error = null;
  const BackupReport.failed(this.error)
      : restored = const <String>[],
        createdAt = null;

  /// I file rimessi a posto.
  final List<String> restored;

  /// Quando era stata fatta la copia.
  final DateTime? createdAt;

  /// Perche' non si e' potuto fare. `null` se e' andata.
  final String? error;

  bool get isOk => error == null;

  /// Che cosa e' tornato, in italiano.
  String get summary {
    final String? problema = error;
    if (problema != null) return problema;
    const Map<String, String> nomi = <String, String>{
      StorageService.activitiesFileName: 'le corse',
      StorageService.settingsFileName: 'le impostazioni',
      StorageService.shoesFileName: 'le scarpe',
      StorageService.workoutsFileName: 'gli allenamenti',
      StorageService.planFileName: 'il piano',
      StorageService.profileFileName: 'il profilo',
      StorageService.checkInsFileName: 'i check-in',
    };
    final List<String> pezzi = <String>[
      for (final String f in restored)
        if (nomi[f] != null) nomi[f]!,
    ];
    if (pezzi.isEmpty) return 'Ripristino completato.';
    if (pezzi.length == 1) return 'Ho rimesso ${pezzi.first}.';
    final String ultimo = pezzi.removeLast();
    return 'Ho rimesso ${pezzi.join(', ')} e $ultimo.';
  }
}
