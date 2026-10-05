import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:run_coach_app/services/storage_service.dart';

/// La copia di sicurezza, e soprattutto il ripristino.
///
/// DA DOVE NASCE QUESTO FILE
/// -------------------------
/// Falcata tiene tutto nel telefono e non manda niente a nessuno. E' la scelta
/// giusta, ma ha un prezzo che finora pagava l'utente senza saperlo: si cambia
/// telefono e sparisce tutto.
///
/// IL RISCHIO VERO NON E' SALVARE, E' RIMETTERE
/// --------------------------------------------
/// Salvare non puo' rompere niente: nel peggiore dei casi non si salva. Il
/// ripristino invece **scrive sopra l'archivio buono**, ed e' esattamente il
/// momento in cui l'utente non ha una seconda copia a cui tornare.
///
/// Quindi la regola e' una sola: **prima si controlla tutto, poi si scrive**.
/// Un file che non e' una copia di Falcata, o che e' danneggiato a meta', deve
/// essere rifiutato **senza aver toccato il disco**. Questi test provano che un
/// file sbagliato non arriva mai alla scrittura.
void main() {
  /// Il contenuto di una copia, come lo produce l'app.
  String copia({
    Map<String, String>? file,
    String tipo = StorageService.backupMarker,
    String creato = '2026-10-01T08:00:00.000',
  }) =>
      jsonEncode(<String, dynamic>{
        'tipo': tipo,
        'formato': StorageService.backupFormat,
        'app': '2.1.0',
        'creato': creato,
        'file': file ??
            <String, String>{
              StorageService.activitiesFileName: '[]',
              StorageService.settingsFileName: '{"userName":"Carlo"}',
            },
      });

  group('cosa va dentro una copia', () {
    test('la corsa in corso NON fa parte dell\'archivio', () {
      // Rimetterla su un altro telefono farebbe comparire una corsa a meta'
      // che non si e' mai fatta.
      expect(
        StorageService.backupFiles.contains(
          StorageService.runInProgressFileName,
        ),
        isFalse,
      );
    });

    test('tutto il resto c\'e\'', () {
      // Se un file nuovo venisse aggiunto allo storage e dimenticato qui, la
      // copia sarebbe incompleta senza che nessuno se ne accorga - e si
      // scoprirebbe il giorno del ripristino.
      for (final String atteso in <String>[
        StorageService.activitiesFileName,
        StorageService.settingsFileName,
        StorageService.shoesFileName,
        StorageService.workoutsFileName,
        StorageService.planFileName,
        StorageService.profileFileName,
        StorageService.checkInsFileName,
      ]) {
        expect(StorageService.backupFiles.contains(atteso), isTrue,
            reason: '$atteso manca dalla copia');
      }
    });
  });

  group('un file sbagliato non arriva mai alla scrittura', () {
    late StorageService storage;
    setUp(() => storage = StorageService());

    test('testo che non e\' nemmeno JSON', () async {
      final BackupReport r = await storage.importBackup('questo non e un file');
      expect(r.isOk, isFalse);
      expect(r.restored, isEmpty);
      expect(r.summary.toLowerCase().contains('leggibile'), isTrue);
    });

    test('JSON valido ma di un\'altra app', () async {
      final BackupReport r = await storage.importBackup(
        jsonEncode(<String, dynamic>{'tipo': 'altra-app', 'file': <String, String>{}}),
      );
      expect(r.isOk, isFalse);
      expect(r.restored, isEmpty);
      expect(r.summary.contains('Falcata'), isTrue);
    });

    test('una lista invece di una copia', () async {
      final BackupReport r = await storage.importBackup('[1, 2, 3]');
      expect(r.isOk, isFalse);
      expect(r.restored, isEmpty);
    });

    test('il marcatore giusto ma senza contenuto', () async {
      final BackupReport r = await storage.importBackup(
        jsonEncode(<String, dynamic>{'tipo': StorageService.backupMarker}),
      );
      expect(r.isOk, isFalse);
      expect(r.restored, isEmpty);
    });

    test('un pezzo danneggiato ferma TUTTO il ripristino', () async {
      // La parte che conta. Se si scrivessero i pezzi buoni e si saltassero i
      // rotti, l'archivio resterebbe meta' nuovo e meta' vecchio: incoerente,
      // e nessuno saprebbe quale meta'. Meglio non fare niente e dirlo.
      final BackupReport r = await storage.importBackup(copia(
        file: <String, String>{
          StorageService.activitiesFileName: '[]',
          StorageService.settingsFileName: '{non e json',
        },
      ));
      expect(r.isOk, isFalse);
      expect(r.restored, isEmpty,
          reason: 'non deve aver scritto niente');
      expect(r.summary.contains(StorageService.settingsFileName), isTrue,
          reason: 'deve dire QUALE pezzo e\' rotto');
    });

    test('un pezzo che non e\' nemmeno testo', () async {
      final BackupReport r = await storage.importBackup(
        jsonEncode(<String, dynamic>{
          'tipo': StorageService.backupMarker,
          'file': <String, dynamic>{
            StorageService.activitiesFileName: 42,
          },
        }),
      );
      expect(r.isOk, isFalse);
      expect(r.restored, isEmpty);
    });

    test('una copia di una versione futura, con solo nomi sconosciuti',
        () async {
      // Non deve far finta di aver ripristinato qualcosa.
      final BackupReport r = await storage.importBackup(copia(
        file: <String, String>{'cosa_futura.json': '{}'},
      ));
      expect(r.isOk, isFalse);
      expect(r.restored, isEmpty);
    });
  });

  group('quello che si legge dopo', () {
    test('un esito riuscito dice cosa e\' tornato, in italiano', () {
      const BackupReport r = BackupReport.ok(<String>[
        StorageService.activitiesFileName,
        StorageService.planFileName,
        StorageService.shoesFileName,
      ]);
      expect(r.isOk, isTrue);
      expect(r.summary, 'Ho rimesso le corse, il piano e le scarpe.');
    });

    test('una cosa sola si legge al singolare', () {
      const BackupReport r =
          BackupReport.ok(<String>[StorageService.activitiesFileName]);
      expect(r.summary, 'Ho rimesso le corse.');
    });

    test('un errore si legge come un errore, non come un codice', () {
      const BackupReport r = BackupReport.failed('Questo file non e\' leggibile.');
      expect(r.isOk, isFalse);
      expect(r.summary, 'Questo file non e\' leggibile.');
      expect(r.restored, isEmpty);
    });

    test('un nome sconosciuto non manda in pezzi il riassunto', () {
      const BackupReport r = BackupReport.ok(<String>['cosa_futura.json']);
      expect(r.isOk, isTrue);
      expect(r.summary.isNotEmpty, isTrue);
    });
  });

  group('la forma della copia', () {
    test('il marcatore c\'e\' ed e\' stabile', () {
      // Cambiarlo renderebbe illeggibili tutte le copie gia' fatte dalla
      // gente. Se un giorno il formato cambiera' davvero, si alza
      // backupFormat e si legge anche il vecchio - non si cambia questo.
      expect(StorageService.backupMarker, 'falcata-backup');
      expect(StorageService.backupFormat, 1);
    });

    test('una copia ben fatta ha tutto quello che serve a riconoscerla', () {
      final Map<String, dynamic> letta =
          jsonDecode(copia()) as Map<String, dynamic>;
      expect(letta['tipo'], StorageService.backupMarker);
      expect(letta['formato'], isNotNull);
      expect(letta['creato'], isNotNull);
      expect(letta['file'], isA<Map<String, dynamic>>());
    });
  });

  group('andata e ritorno, su disco vero', () {
    late Directory tempDir;
    late StorageService storage;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('falcata_backup_test');
      storage = StorageService(overrideDirectory: tempDir);
    });

    tearDown(() async {
      if (await tempDir.exists()) await tempDir.delete(recursive: true);
    });

    test('quello che salvi e\' quello che ritrovi', () async {
      // Il giro completo: si scrive un archivio, se ne fa la copia, si
      // cancella tutto, si rimette. Deve tornare identico.
      final File corse = File('${tempDir.path}/${StorageService.activitiesFileName}');
      await corse.writeAsString('[{"id":"a1","name":"Corsa di prova"}]');
      final File impostazioni =
          File('${tempDir.path}/${StorageService.settingsFileName}');
      await impostazioni.writeAsString('{"userName":"Carlo","units":"metric"}');

      final String? copia = await storage.exportBackup(appVersion: '2.1.0');
      expect(copia, isNotNull);

      // Il disastro: tutto cancellato.
      await corse.delete();
      await impostazioni.delete();
      expect(await corse.exists(), isFalse);

      final BackupReport r = await storage.importBackup(copia!);
      expect(r.isOk, isTrue, reason: r.summary);
      expect(await corse.exists(), isTrue);
      expect(await corse.readAsString(),
          '[{"id":"a1","name":"Corsa di prova"}]');
      expect(await impostazioni.readAsString(),
          '{"userName":"Carlo","units":"metric"}');
    });

    test('un archivio vuoto non produce una copia vuota', () async {
      // Salvare "niente" e poi rimetterlo cancellerebbe l'archivio di
      // destinazione: meglio dire che non c'e' niente da salvare.
      final String? copia = await storage.exportBackup();
      expect(copia, isNull);
      expect(storage.lastError, isNotNull);
    });

    test('un file rotto non tocca quello che c\'e\' gia\'', () async {
      // La garanzia piu' importante di tutte, provata sul disco vero.
      final File corse =
          File('${tempDir.path}/${StorageService.activitiesFileName}');
      await corse.writeAsString('[{"id":"vero"}]');

      final BackupReport r = await storage.importBackup(jsonEncode(
        <String, dynamic>{
          'tipo': StorageService.backupMarker,
          'file': <String, String>{
            StorageService.activitiesFileName: '[{"id":"nuovo"}]',
            StorageService.settingsFileName: 'rotto{',
          },
        },
      ));

      expect(r.isOk, isFalse);
      expect(await corse.readAsString(), '[{"id":"vero"}]',
          reason: 'l\'archivio di prima doveva restare intatto');
    });
  });
}
