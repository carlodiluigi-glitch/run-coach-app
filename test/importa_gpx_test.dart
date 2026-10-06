import 'package:flutter_test/flutter_test.dart';
import 'package:run_coach_app/models/running_activity.dart';
import 'package:run_coach_app/services/gpx_import.dart';

/// Importare lo storico da un file GPX.
///
/// DA DOVE NASCE QUESTO FILE
/// -------------------------
/// Chi scarica Falcata corre gia' da anni, e quegli anni stanno su Strava o su
/// un orologio. Al primo avvio l'app guarda un archivio vuoto e dice la verita':
/// non ho abbastanza per stimare la tua forma. E' onesto, ed e' anche il momento
/// in cui l'app viene disinstallata.
///
/// Questo non e' un lettore XML completo: e' un estrattore di punti traccia. Il
/// modo in cui puo' fallire deve essere "questo file non si importa" - che si
/// vede subito e non rovina niente - e mai "si importa storto".
void main() {
  /// Un GPX costruito su misura: un punto ogni [secondi] secondi, spostandosi
  /// verso est di [metriAlPunto] metri.
  String gpx({
    int punti = 300,
    int secondi = 2,
    double metriAlPunto = 6.67, // 3,33 m/s = 5:00/km
    String nome = 'Corsa del mattino',
    String prefisso = '',
    bool conQuota = true,
    bool conOrario = true,
    bool lonPrima = false,
    int tracce = 1,
  }) {
    final String p = prefisso.isEmpty ? '' : '$prefisso:';
    final StringBuffer b = StringBuffer('<?xml version="1.0"?>\n<${p}gpx>\n');
    for (int t = 0; t < tracce; t++) {
      b.writeln('<${p}trk><${p}name>$nome ${t + 1}</${p}name><${p}trkseg>');
      final DateTime inizio = DateTime.utc(2026, 5, 10 + t, 7, 30);
      for (int i = 0; i < punti; i++) {
        final double lon = 9.0 + (i * metriAlPunto) / 78846.0; // metri -> gradi
        final String attributi = lonPrima
            ? 'lon="${lon.toStringAsFixed(7)}" lat="45.0000000"'
            : 'lat="45.0000000" lon="${lon.toStringAsFixed(7)}"';
        b.write('<${p}trkpt $attributi>');
        if (conQuota) b.write('<${p}ele>${120 + i * 0.02}</${p}ele>');
        if (conOrario) {
          b.write('<${p}time>'
              '${inizio.add(Duration(seconds: i * secondi)).toIso8601String()}'
              '</${p}time>');
        }
        b.writeln('</${p}trkpt>');
      }
      b.writeln('</${p}trkseg></${p}trk>');
    }
    b.writeln('</${p}gpx>');
    return b.toString();
  }

  group('un file normale si importa', () {
    test('una traccia diventa una corsa', () {
      final GpxResult r = GpxImport.parse(gpx());
      expect(r.isOk, isTrue, reason: r.summary);
      expect(r.activities.length, 1);

      final RunningActivity a = r.activities.first;
      // 300 punti x 6,67 m = circa 2 km, in 600 secondi.
      expect(a.distanceMeters > 1700 && a.distanceMeters < 2200, isTrue,
          reason: '${a.distanceMeters.toStringAsFixed(0)} m');
      expect(a.durationSeconds, 598);
      expect(a.name, 'Corsa del mattino 1');
      expect(a.route.length, 300);
    });

    test('il passo torna', () {
      final RunningActivity a = GpxImport.parse(gpx()).activities.first;
      final double? passo = passoMedio(a);
      expect(passo, isNotNull);
      expect(passo! > 270 && passo < 340, isTrue,
          reason: 'passo ${passo.toStringAsFixed(0)} s/km, atteso ~300');
    });

    test('la quota arriva nel tracciato', () {
      final RunningActivity a = GpxImport.parse(gpx()).activities.first;
      expect(a.route.first.altitude, isNotNull);
      expect(a.route.last.altitude! > a.route.first.altitude!, isTrue);
    });

    test('tre tracce fanno tre corse', () {
      final GpxResult r = GpxImport.parse(gpx(tracce: 3));
      expect(r.activities.length, 3);
      // Giorni diversi: non devono accavallarsi.
      final Set<int> giorni =
          r.activities.map((RunningActivity a) => a.startTime.day).toSet();
      expect(giorni.length, 3);
    });
  });

  group('i file che non sono tutti uguali', () {
    test('con il prefisso di spazio dei nomi', () {
      // <gpx:trkpt> invece di <trkpt>: lo scrivono parecchi orologi.
      final GpxResult r = GpxImport.parse(gpx(prefisso: 'gpx'));
      expect(r.isOk, isTrue, reason: r.summary);
      expect(r.activities.length, 1);
    });

    test('con gli attributi in ordine inverso', () {
      // lon prima di lat: l'ordine degli attributi in XML non ha significato,
      // e dare per scontato che lat venga prima e' il classico modo di
      // rompersi su meta' dei file del mondo.
      final GpxResult r = GpxImport.parse(gpx(lonPrima: true));
      expect(r.isOk, isTrue, reason: r.summary);
      expect(r.activities.first.distanceMeters > 1700, isTrue);
    });

    test('senza quota si importa lo stesso', () {
      final GpxResult r = GpxImport.parse(gpx(conQuota: false));
      expect(r.isOk, isTrue, reason: r.summary);
      expect(r.activities.first.route.first.altitude, isNull);
    });

    test('un nome dentro CDATA si legge pulito', () {
      final String conCdata = gpx()
          .replaceAll('<name>Corsa del mattino 1</name>',
              '<name><![CDATA[Lungo di domenica]]></name>');
      final GpxResult r = GpxImport.parse(conCdata);
      expect(r.activities.first.name, 'Lungo di domenica');
    });
  });

  group('quello che non deve entrare nell\'archivio', () {
    test('un file che non e\' un GPX', () {
      final GpxResult r = GpxImport.parse('{"questo": "e json"}');
      expect(r.isOk, isFalse);
      expect(r.activities, isEmpty);
      expect(r.summary.contains('GPX'), isTrue);
    });

    test('una traccia senza orari non e\' una corsa', () {
      // Senza orari non c'e' durata, quindi non c'e' passo: metterla
      // nell'archivio falserebbe ogni stima dell'app.
      final GpxResult r = GpxImport.parse(gpx(conOrario: false));
      expect(r.isOk, isFalse);
      expect(r.activities, isEmpty);
    });

    test('una traccia troppo corta viene scartata', () {
      final GpxResult r = GpxImport.parse(gpx(punti: 10));
      expect(r.isOk, isFalse);
      expect(r.activities, isEmpty);
    });

    test('un giro in bicicletta non entra come corsa', () {
      // 30 km/h: nessuno corre a quel passo, e il motore di forma lo
      // leggerebbe come una prestazione fuori scala.
      final GpxResult r = GpxImport.parse(gpx(metriAlPunto: 16.7));
      expect(r.activities, isEmpty,
          reason: 'un passo da bicicletta non deve entrare');
    });

    test('un viaggio in macchina nemmeno', () {
      final GpxResult r = GpxImport.parse(gpx(metriAlPunto: 50));
      expect(r.activities, isEmpty);
    });

    test('una traccia buona e una rotta: entra solo la buona', () {
      final String misto = gpx(tracce: 1) .replaceAll('</gpx>',
          '<trk><name>Rotta</name><trkseg>'
          '<trkpt lat="45.0" lon="9.0"></trkpt>'
          '</trkseg></trk></gpx>');
      final GpxResult r = GpxImport.parse(misto);
      expect(r.isOk, isTrue);
      expect(r.activities.length, 1);
      expect(r.skipped, 1);
      expect(r.summary.contains('scartat'), isTrue);
    });
  });

  group('reimportare lo stesso file non raddoppia niente', () {
    test('le corse gia\' presenti vengono riconosciute', () {
      // E' la cosa piu' probabile che succeda: non si sa mai se e' andata, e
      // si riprova. Un archivio con tutto in doppio falsa ogni stima.
      final List<RunningActivity> corse = GpxImport.parse(gpx(tracce: 3)).activities;

      expect(GpxImport.nuoveFra(corse, const <RunningActivity>[]).length, 3);
      expect(GpxImport.nuoveFra(corse, corse), isEmpty);
      expect(
        GpxImport.nuoveFra(corse, <RunningActivity>[corse.first]).length,
        2,
      );
    });

    test('qualche minuto di differenza e\' sempre la stessa corsa', () {
      final RunningActivity a = GpxImport.parse(gpx()).activities.first;
      final RunningActivity quasi = RunningActivity(
        startTime: a.startTime.add(const Duration(minutes: 2)),
        name: 'Stessa corsa',
        type: ActivityType.free,
        durationSeconds: a.durationSeconds,
        distanceMeters: a.distanceMeters,
      );
      expect(GpxImport.nuoveFra(<RunningActivity>[a], <RunningActivity>[quasi]),
          isEmpty);
    });

    test('un\'ora di differenza sono due corse diverse', () {
      final RunningActivity a = GpxImport.parse(gpx()).activities.first;
      final RunningActivity altra = RunningActivity(
        startTime: a.startTime.add(const Duration(hours: 1)),
        name: 'Doppia seduta',
        type: ActivityType.free,
        durationSeconds: a.durationSeconds,
        distanceMeters: a.distanceMeters,
      );
      expect(
        GpxImport.nuoveFra(<RunningActivity>[a], <RunningActivity>[altra]).length,
        1,
      );
    });
  });
}
