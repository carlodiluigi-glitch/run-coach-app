import 'dart:math' as math;

import '../models/running_activity.dart';
import 'gps_filter.dart';

/// Legge un file GPX e ne ricava corse da mettere nell'archivio.
///
/// PERCHE' E' LA FUNZIONE CHE DECIDE SE L'APP RESTA INSTALLATA
/// -----------------------------------------------------------
/// Chi scarica Falcata corre gia' da anni, e quegli anni stanno su Strava o su
/// un orologio. Al primo avvio l'app guarda un archivio vuoto e dice la verita':
/// non ho abbastanza per stimare la tua forma, non posso proporti un volume di
/// partenza, non posso scriverti un piano. E' onesto, ed e' anche il momento in
/// cui l'app viene disinstallata.
///
/// E' lo stesso difetto dei "9 km a settimana" proposti a chi ne corre 60 -
/// quello pero' capitava a un utente solo, questo capita a **tutti**, al primo
/// minuto.
///
/// PERCHE' NON UN LETTORE XML VERO
/// -------------------------------
/// Un GPX e' XML, e la cosa corretta sarebbe un lettore XML completo: cioe' una
/// dipendenza in piu' su un progetto che per scelta ne ha cinque, e ogni
/// dipendenza e' un pezzo che puo' rompersi al prossimo aggiornamento di
/// Flutter (e' gia' successo con il plugin Gradle).
///
/// Questo **non e' un lettore XML**: e' un estrattore di punti traccia, e fa una
/// cosa sola. Il modo in cui puo' fallire e' "questo file non si importa", che
/// si vede subito e non rovina niente - non "si importa storto", che sarebbe
/// grave. Prima di scrivere qualcosa nell'archivio si controlla tutto.
///
/// COSA SA LEGGERE
/// ---------------
/// I punti traccia (`trkpt`) con latitudine, longitudine, quota e orario, anche
/// quando il file usa un prefisso di spazio dei nomi (`<gpx:trkpt>`), ha gli
/// attributi in ordine inverso, o spezza la corsa in piu' segmenti. Ogni
/// `<trk>` diventa una corsa: un file con tre tracce porta dentro tre corse.
class GpxImport {
  const GpxImport._();

  /// Massimo numero di corse prese da un file solo.
  ///
  /// Un'esportazione di Strava puo' contenere migliaia di tracce: costruirle
  /// tutte in memoria in una volta farebbe chiudere l'app sui telefoni piu'
  /// modesti, che sono esattamente quelli dei clienti di Falcata. Oltre questo
  /// numero si prendono le prime e si dice quante sono rimaste fuori.
  static const int maxPerFile = 500;

  /// Meno di cosi' non e' una corsa: e' un file di prova o una traccia rotta.
  static const int minimumPoints = 20;
  static const double minimumMeters = 300;
  static const int minimumSeconds = 120;

  /// Legge il contenuto di un file GPX.
  static GpxResult parse(String xml) {
    if (!xml.contains('<trkpt') && !xml.contains(':trkpt')) {
      return const GpxResult.failed(
        'Questo non sembra un file GPX: non contiene nessuna traccia.',
      );
    }

    final List<RunningActivity> corse = <RunningActivity>[];
    int scartate = 0;

    final List<String> tracce = _blocchi(xml, 'trk');
    final int tetto = math.min(tracce.length, maxPerFile);
    final int oltreIlTetto = tracce.length - tetto;

    for (final String traccia in tracce.take(tetto)) {
      final List<_Punto> punti = _puntiDi(traccia);
      if (punti.length < minimumPoints) {
        scartate++;
        continue;
      }

      final RunningActivity? corsa = _corsaDa(punti, _nomeDi(traccia));
      if (corsa == null) {
        scartate++;
        continue;
      }
      corse.add(corsa);
    }

    if (corse.isEmpty) {
      return GpxResult.failed(
        scartate == 0
            ? 'Nel file non ho trovato nessuna traccia con dei punti.'
            : 'Le tracce trovate sono troppo corte per essere corse.',
      );
    }
    return GpxResult.ok(
      corse,
      skipped: scartate,
      overLimit: oltreIlTetto,
    );
  }

  // ---------------------------------------------------------------- lettura
  /// I blocchi `<tag ...> ... </tag>`, prefisso di spazio dei nomi compreso.
  static List<String> _blocchi(String xml, String tag) {
    final RegExp apre = RegExp('<(?:[A-Za-z0-9_.-]+:)?$tag(?:\\s[^>]*)?>');
    final RegExp chiude = RegExp('</(?:[A-Za-z0-9_.-]+:)?$tag\\s*>');

    final List<String> out = <String>[];
    int da = 0;
    while (true) {
      final Match? inizio = apre.firstMatch(xml.substring(da));
      if (inizio == null) break;
      final int apreA = da + inizio.end;
      final Match? fine = chiude.firstMatch(xml.substring(apreA));
      if (fine == null) break;
      out.add(xml.substring(apreA, apreA + fine.start));
      da = apreA + fine.end;
    }
    return out;
  }

  static final RegExp _trkpt =
      RegExp(r'<(?:[A-Za-z0-9_.-]+:)?trkpt\s([^>]*?)/?>', dotAll: true);
  static final RegExp _lat = RegExp(r'''lat\s*=\s*["']([^"']+)["']''');
  static final RegExp _lon = RegExp(r'''lon\s*=\s*["']([^"']+)["']''');

  /// I punti di una traccia, in ordine.
  ///
  /// Si cerca il tag di apertura e poi si guarda il testo che segue fino al
  /// punto successivo: quota e orario stanno li' dentro. E' piu' semplice che
  /// isolare la chiusura, e funziona anche con i punti auto-chiusi
  /// (`<trkpt ... />`), che quota e orario non ce l'hanno proprio.
  static List<_Punto> _puntiDi(String traccia) {
    final List<Match> aperture = _trkpt.allMatches(traccia).toList();
    final List<_Punto> out = <_Punto>[];

    for (int i = 0; i < aperture.length; i++) {
      final Match m = aperture[i];
      final String attributi = m.group(1) ?? '';
      final double? lat = double.tryParse(_lat.firstMatch(attributi)?.group(1) ?? '');
      final double? lon = double.tryParse(_lon.firstMatch(attributi)?.group(1) ?? '');
      if (lat == null || lon == null) continue;
      if (lat.abs() > 90 || lon.abs() > 180) continue;

      final int fine =
          i + 1 < aperture.length ? aperture[i + 1].start : traccia.length;
      final String corpo = traccia.substring(m.end, fine);

      out.add(_Punto(
        lat: lat,
        lon: lon,
        quota: double.tryParse(_contenuto(corpo, 'ele') ?? ''),
        quando: DateTime.tryParse(_contenuto(corpo, 'time') ?? '')?.toLocal(),
      ));
    }
    return out;
  }

  static String? _contenuto(String xml, String tag) {
    final Match? m = RegExp(
      '<(?:[A-Za-z0-9_.-]+:)?$tag(?:\\s[^>]*)?>(.*?)</(?:[A-Za-z0-9_.-]+:)?$tag\\s*>',
      dotAll: true,
    ).firstMatch(xml);
    return m?.group(1)?.trim();
  }

  static String _nomeDi(String traccia) {
    final String? nome = _contenuto(traccia, 'name');
    if (nome == null || nome.isEmpty) return 'Corsa importata';
    // Un nome puo' arrivare dentro CDATA.
    return nome
        .replaceAll('<![CDATA[', '')
        .replaceAll(']]>', '')
        .trim();
  }

  // -------------------------------------------------------------- la corsa
  /// Da una lista di punti a una corsa vera.
  ///
  /// La distanza NON si somma punto per punto: si passa dal filtro che usa
  /// l'app durante la corsa, con la velocita' assente - cioe' la strada del
  /// ripiego, posizioni mediate e soglia proporzionale all'incertezza. E' lo
  /// stesso conto, quindi una corsa importata e una registrata si possono
  /// confrontare. Sommare le differenze qui darebbe una distanza piu' lunga
  /// delle corse registrate con l'app, e l'indice di forma ne uscirebbe storto.
  static RunningActivity? _corsaDa(List<_Punto> punti, String nome) {
    final List<_Punto> conOrario =
        punti.where((_Punto p) => p.quando != null).toList();
    if (conOrario.length < minimumPoints) return null;

    conOrario.sort((_Punto a, _Punto b) => a.quando!.compareTo(b.quando!));
    final DateTime inizio = conOrario.first.quando!;
    final DateTime fine = conOrario.last.quando!;
    final int durata = fine.difference(inizio).inSeconds;
    if (durata < minimumSeconds) return null;

    final GpsFilter filtro = GpsFilter(maxAccuracyMeters: 1000);
    final List<RoutePoint> traccia = <RoutePoint>[];
    for (final _Punto p in conOrario) {
      final int secondi = p.quando!.difference(inizio).inSeconds;
      filtro.process(
        latitude: p.lat,
        longitude: p.lon,
        // Un GPX non dice quanto era preciso il segnale: si assume un valore
        // normale, cosi' la soglia del ripiego resta quella di una corsa
        // registrata bene.
        accuracy: 6,
        timestamp: p.quando!,
      );
      traccia.add(RoutePoint(
        latitude: p.lat,
        longitude: p.lon,
        elapsedSeconds: secondi,
        altitude: p.quota,
      ));
    }

    final double metri = filtro.totalMeters;
    if (metri < minimumMeters) return null;

    // Un passo impossibile vuol dire che il file non e' una corsa a piedi
    // (una pedalata, un viaggio in macchina registrato per sbaglio).
    final double passo = durata / (metri / 1000.0);
    if (passo < 120 || passo > 1800) return null;

    return RunningActivity(
      startTime: inizio,
      name: nome,
      type: ActivityType.free,
      durationSeconds: durata,
      distanceMeters: metri,
      route: traccia,
      note: 'Importata da GPX',
    );
  }

  /// Le corse del file che non sono gia' nell'archivio.
  ///
  /// Si riconosce il doppione dall'ora di partenza: due corse che cominciano
  /// entro pochi minuti l'una dall'altra sono la stessa corsa importata due
  /// volte. Reimportare lo stesso file e' la cosa piu' probabile che succeda -
  /// non si sa mai se e' andata - e un archivio con tutto in doppio falsa ogni
  /// stima dell'app.
  static List<RunningActivity> nuoveFra(
    List<RunningActivity> candidate,
    List<RunningActivity> archivio, {
    Duration tolleranza = const Duration(minutes: 5),
  }) =>
      <RunningActivity>[
        for (final RunningActivity c in candidate)
          if (!archivio.any((RunningActivity a) =>
              a.startTime.difference(c.startTime).abs() < tolleranza))
            c,
      ];
}

class _Punto {
  const _Punto({
    required this.lat,
    required this.lon,
    this.quota,
    this.quando,
  });
  final double lat;
  final double lon;
  final double? quota;
  final DateTime? quando;
}

/// Esito della lettura di un file GPX.
class GpxResult {
  const GpxResult.ok(
    this.activities, {
    this.skipped = 0,
    this.overLimit = 0,
  }) : error = null;

  const GpxResult.failed(this.error)
      : activities = const <RunningActivity>[],
        skipped = 0,
        overLimit = 0;

  final List<RunningActivity> activities;

  /// Tracce trovate ma scartate perche' troppo corte o senza orari.
  final int skipped;

  /// Tracce lasciate fuori perche' il file ne conteneva piu' del tetto.
  final int overLimit;

  final String? error;

  bool get isOk => error == null;

  double get totalMeters {
    double totale = 0;
    for (final RunningActivity a in activities) {
      totale += a.distanceMeters;
    }
    return totale;
  }

  /// Cosa e' stato trovato, in italiano.
  String get summary {
    final String? problema = error;
    if (problema != null) return problema;
    final int n = activities.length;
    final String corse = n == 1 ? '1 corsa' : '$n corse';
    final String km = (totalMeters / 1000).toStringAsFixed(1);
    final String troppe = overLimit == 0
        ? ''
        : ' Il file ne conteneva altre $overLimit: reimportalo per prenderle.';

    if (skipped == 0) return 'Trovate $corse, $km km in tutto.$troppe';

    final String quante = skipped == 1
        ? 'Una traccia e\' stata scartata'
        : '$skipped tracce sono state scartate';
    return 'Trovate $corse, $km km in tutto. '
        '$quante perche\' troppo corta o senza orari.$troppe';
  }
}

/// Il passo medio di una corsa, in secondi al chilometro. Per i test.
double? passoMedio(RunningActivity a) {
  if (a.distanceMeters <= 0) return null;
  return a.durationSeconds / (a.distanceMeters / 1000.0);
}

