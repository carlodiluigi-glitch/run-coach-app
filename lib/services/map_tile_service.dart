import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

import '../models/running_activity.dart';

/// La mappa sotto al percorso: quali riquadri servono, e come non ripagarli.
///
/// PERCHE' UN SERVIZIO SCRITTO A MANO E NON UN PACCHETTO
/// -----------------------------------------------------
/// I pacchetti per le mappe sanno fare lo scorrimento e lo zoom con le dita, e
/// per farlo scaricano riquadri in continuazione: ogni trascinamento costa. A
/// Falcata serve l'opposto - **una figura ferma** che inquadra la corsa e
/// basta. Ferma vuol dire un numero di riquadri deciso in partenza, lo stesso
/// per sempre, che si possono scaricare una volta e tenere.
///
/// La differenza non e' di stile, e' di conto: con lo zoom libero la spesa
/// dipende da quanto l'utente gioca con la mappa, e non e' prevedibile. Qui
/// una corsa costa [maxTiles] riquadri la prima volta che la si guarda, e zero
/// tutte le volte dopo. E' l'unico modo in cui una mappa sta dentro un'app che
/// si compra una volta sola.
///
/// IL FORNITORE STA IN UN POSTO SOLO
/// ---------------------------------
/// [tileUrlTemplate] e' l'unica riga da cambiare per passare a un fornitore a
/// pagamento, o per spegnere la mappa del tutto. Non va copiata altrove.
///
/// **PRIMA DI PUBBLICARE SUL PLAY STORE QUESTA RIGA VA CAMBIATA.** I riquadri
/// di OpenStreetMap sono gratuiti e vanno benissimo per un'app usata da chi la
/// scrive, ma la loro politica d'uso non permette di distribuirla su un
/// negozio appoggiandosi ai loro server: e' una fondazione che paga quella
/// banda con le donazioni. Per pubblicare serve un fornitore con un contratto
/// (Thunderforest, MapTiler e simili): cambia l'indirizzo e si aggiunge la
/// chiave, il resto del codice non si tocca.
///
/// L'attribuzione invece non e' facoltativa in nessun caso, ed e' per questo
/// che [attribution] sta qui accanto all'indirizzo e non in una schermata
/// dimenticabile.
class MapTileService {
  const MapTileService();

  /// L'unico posto dove e' scritto da dove arrivano i riquadri.
  static const String tileUrlTemplate =
      'https://tile.openstreetmap.org/{z}/{x}/{y}.png';

  /// Da mostrare sotto la mappa. Obbligatoria.
  static const String attribution = '© OpenStreetMap';

  /// Chi siamo, per il server che ci serve i riquadri.
  ///
  /// Non e' un vezzo: OpenStreetMap blocca le richieste senza un nome
  /// riconoscibile, perche' e' l'unico modo che ha per distinguere un'app da
  /// uno che gli sta svuotando il database.
  static const String userAgent = 'Falcata/1.9 (app di corsa, uso personale)';

  /// Quanti riquadri al massimo per una corsa.
  ///
  /// ATTENZIONE: QUESTO NUMERO NON DIPENDE DALLO ZOOM
  /// ------------------------------------------------
  /// Sembra che abbassare lo zoom debba ridurre i riquadri, e non e' cosi': a
  /// qualunque zoom, per coprire una tela larga 360 pixel ne servono sempre
  /// due o tre. Il numero di riquadri dipende dalla **grandezza del riquadro
  /// sullo schermo**, non da quanto si e' larghi con la vista.
  ///
  /// La prima versione di questo codice usava il tetto come condizione per
  /// scendere di zoom: su una tela grande nessuno zoom passava il controllo, e
  /// la mappa semplicemente non compariva mai. Il tetto e' un **controllo di
  /// sicurezza sul costo**, non una leva di regolazione: se scatta, vuol dire
  /// che la mappa e' stata messa in uno spazio troppo grande, e si ripiega sul
  /// disegno del percorso senza mappa.
  ///
  /// Ventiquattro (una griglia 6x4) copre comodamente una scheda a tutta
  /// larghezza su qualunque telefono.
  static const int maxTiles = 24;

  /// Lato di un riquadro, in pixel. E' lo standard di tutti i fornitori.
  static const int tileSize = 256;

  static const int minZoom = 3;
  static const int maxZoom = 17;

  /// Quanto tempo vale un riquadro salvato.
  ///
  /// Le strade cambiano piano. Un anno e' abbondante, e nel frattempo la
  /// stessa corsa riaperta cento volte non costa niente.
  static const Duration cacheLife = Duration(days: 365);

  // ----------------------------------------------------- proiezione
  /// Longitudine -> coordinata orizzontale del mondo, in frazione di giro.
  ///
  /// Zero al meridiano -180, uno al +180.
  static double worldX(double longitude) => (longitude + 180.0) / 360.0;

  /// Latitudine -> coordinata verticale del mondo, in frazione.
  ///
  /// E' la proiezione di Mercatore, quella che usano tutte le mappe del web:
  /// i meridiani restano verticali e paralleli, e il prezzo e' che le zone
  /// vicine ai poli vengono ingrandite. Su un percorso di dieci chilometri la
  /// deformazione non si vede.
  static double worldY(double latitude) {
    final double lat = latitude.clamp(-85.05112878, 85.05112878);
    final double rad = lat * math.pi / 180.0;
    final double sin = math.sin(rad);
    return 0.5 - math.log((1 + sin) / (1 - sin)) / (4 * math.pi);
  }

  /// La vista giusta per un percorso dentro un riquadro di date dimensioni.
  ///
  /// Sceglie lo zoom piu' stretto in cui la corsa ci sta tutta, poi scende
  /// finche' i riquadri non sono al massimo [maxTiles].
  MapView? viewFor(
    List<RoutePoint> route, {
    required double widthPx,
    required double heightPx,
  }) {
    if (route.length < 2 || widthPx <= 0 || heightPx <= 0) return null;

    double minX = 1, maxX = 0, minY = 1, maxY = 0;
    for (final RoutePoint p in route) {
      final double x = worldX(p.longitude);
      final double y = worldY(p.latitude);
      if (x < minX) minX = x;
      if (x > maxX) maxX = x;
      if (y < minY) minY = y;
      if (y > maxY) maxY = y;
    }

    // Un margine attorno alla traccia: un percorso che tocca i bordi sembra
    // tagliato anche quando non lo e'.
    const double margine = 0.08;
    double spanX = (maxX - minX) * (1 + margine * 2);
    double spanY = (maxY - minY) * (1 + margine * 2);

    // Un percorso avanti e indietro sulla stessa strada ha uno dei due lati a
    // zero: senza un minimo, la scala andrebbe all'infinito.
    const double minimo = 1e-7;
    if (spanX < minimo) spanX = minimo;
    if (spanY < minimo) spanY = minimo;

    final double centroX = (minX + maxX) / 2;
    final double centroY = (minY + maxY) / 2;

    for (int zoom = maxZoom; zoom >= minZoom; zoom--) {
      final double mondoPx = tileSize * math.pow(2, zoom).toDouble();
      if (spanX * mondoPx > widthPx || spanY * mondoPx > heightPx) {
        continue; // a questo zoom la corsa non ci sta
      }

      final double originX = centroX * mondoPx - widthPx / 2;
      final double originY = centroY * mondoPx - heightPx / 2;

      final int primoX = (originX / tileSize).floor();
      final int primoY = (originY / tileSize).floor();
      final int ultimoX = ((originX + widthPx) / tileSize).ceil() - 1;
      final int ultimoY = ((originY + heightPx) / tileSize).ceil() - 1;

      // Il tetto si controlla UNA volta, al primo zoom che va bene, e non fa
      // proseguire il ciclo: scendere di zoom non cambia quanti riquadri
      // servono (vedi [maxTiles]). Se scatta, niente mappa - e la schermata
      // mostra il disegno del percorso, che non costa niente.
      final int quanti = (ultimoX - primoX + 1) * (ultimoY - primoY + 1);
      if (quanti > maxTiles) return null;

      final int lato = 1 << zoom;
      final List<MapTile> riquadri = <MapTile>[];
      for (int ty = primoY; ty <= ultimoY; ty++) {
        for (int tx = primoX; tx <= ultimoX; tx++) {
          // Fuori dai poli non c'e' mappa; attorno al mondo invece si gira.
          if (ty < 0 || ty >= lato) continue;
          riquadri.add(MapTile(
            zoom: zoom,
            x: tx % lato < 0 ? tx % lato + lato : tx % lato,
            y: ty,
            offsetX: tx * tileSize - originX,
            offsetY: ty * tileSize - originY,
          ));
        }
      }
      if (riquadri.isEmpty) continue;

      return MapView(
        zoom: zoom,
        worldPixels: mondoPx,
        originX: originX,
        originY: originY,
        tiles: riquadri,
      );
    }
    return null;
  }

  // ----------------------------------------------------------- memoria
  /// Il file di un riquadro, scaricandolo solo se non c'e' gia'.
  ///
  /// `null` se non si e' potuto avere: niente rete, server che non risponde,
  /// disco pieno. In quel caso la mappa mostra quello che ha e il percorso si
  /// vede lo stesso - una mappa a pezzi e' meglio di una schermata di errore,
  /// e il disegno del giro non dipende da internet.
  Future<File?> tileFile(MapTile tile) async {
    try {
      final Directory cartella = await _cacheDir();
      final File file = File(
        '${cartella.path}/${tile.zoom}_${tile.x}_${tile.y}.png',
      );

      if (await file.exists()) {
        final DateTime quando = await file.lastModified();
        if (DateTime.now().difference(quando) < cacheLife) return file;
      }

      final Uint8List? dati = await _download(tile);
      if (dati == null || dati.isEmpty) {
        // Scaduto ma non riscaricabile: meglio il vecchio che niente.
        return await file.exists() ? file : null;
      }

      await file.writeAsBytes(dati, flush: true);
      return file;
    } catch (error) {
      debugPrint('MapTileService: riquadro non disponibile ($error)');
      return null;
    }
  }

  Future<Uint8List?> _download(MapTile tile) async {
    final String url = tileUrlTemplate
        .replaceAll('{z}', '${tile.zoom}')
        .replaceAll('{x}', '${tile.x}')
        .replaceAll('{y}', '${tile.y}');

    final HttpClient client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 8)
      ..userAgent = userAgent;
    try {
      final HttpClientRequest richiesta = await client.getUrl(Uri.parse(url));
      final HttpClientResponse risposta =
          await richiesta.close().timeout(const Duration(seconds: 12));
      if (risposta.statusCode != 200) return null;
      final List<int> bytes =
          await consolidateHttpClientResponseBytes(risposta);
      return Uint8List.fromList(bytes);
    } catch (error) {
      debugPrint('MapTileService: scaricamento fallito ($error)');
      return null;
    } finally {
      client.close(force: true);
    }
  }

  static Directory? _cached;

  Future<Directory> _cacheDir() async {
    final Directory? gia = _cached;
    if (gia != null) return gia;
    final Directory base = await getApplicationDocumentsDirectory();
    final Directory cartella = Directory('${base.path}/mappe');
    if (!await cartella.exists()) await cartella.create(recursive: true);
    return _cached = cartella;
  }

  /// Quanto spazio occupano i riquadri tenuti, in byte.
  Future<int> cacheBytes() async {
    try {
      final Directory cartella = await _cacheDir();
      int totale = 0;
      await for (final FileSystemEntity e in cartella.list()) {
        if (e is File) totale += await e.length();
      }
      return totale;
    } catch (_) {
      return 0;
    }
  }

  /// Butta via i riquadri salvati.
  Future<void> clearCache() async {
    try {
      final Directory cartella = await _cacheDir();
      await for (final FileSystemEntity e in cartella.list()) {
        if (e is File) await e.delete();
      }
    } catch (error) {
      debugPrint('MapTileService: pulizia non riuscita ($error)');
    }
  }
}

/// Un riquadro di mappa, e dove va messo sullo schermo.
class MapTile {
  const MapTile({
    required this.zoom,
    required this.x,
    required this.y,
    required this.offsetX,
    required this.offsetY,
  });

  final int zoom;
  final int x;
  final int y;

  /// Posizione dell'angolo in alto a sinistra, in pixel dello schermo.
  final double offsetX;
  final double offsetY;
}

/// La vista scelta per una corsa: zoom, riquadri e come passare da
/// latitudine e longitudine ai pixel.
class MapView {
  const MapView({
    required this.zoom,
    required this.worldPixels,
    required this.originX,
    required this.originY,
    required this.tiles,
  });

  final int zoom;

  /// Larghezza del mondo intero a questo zoom, in pixel.
  final double worldPixels;

  /// Pixel del mondo corrispondenti all'angolo in alto a sinistra dello
  /// schermo.
  final double originX;
  final double originY;

  final List<MapTile> tiles;

  /// Quanti riquadri costa questa corsa, la prima volta.
  int get tileCount => tiles.length;

  double screenX(double longitude) =>
      MapTileService.worldX(longitude) * worldPixels - originX;

  double screenY(double latitude) =>
      MapTileService.worldY(latitude) * worldPixels - originY;
}
