import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:run_coach_app/models/running_activity.dart';
import 'package:run_coach_app/services/map_tile_service.dart';

/// La mappa: la proiezione, e quanto costa.
///
/// DA DOVE NASCE QUESTO FILE
/// -------------------------
/// La mappa e' l'unica parte di Falcata che costa soldi ogni mese: i riquadri
/// li serve un fornitore e si pagano a consumo. Due cose vanno quindi
/// garantite dal codice, non dalla buona volonta':
///
/// 1. **La proiezione e' quella giusta.** Se il calcolo che trasforma
///    latitudine e longitudine in riquadri sbaglia, si scaricano - e si pagano
///    - pezzi di mappa di un altro posto, e il percorso cade nel vuoto.
/// 2. **Il numero di riquadri per corsa e' limitato e prevedibile.** Senza un
///    tetto, una corsa lunga o uno zoom sbagliato possono chiederne centinaia.
///
/// C'e' anche un difetto gia' trovato e corretto che questo file tiene fermo:
/// il tetto ai riquadri era usato come condizione per scendere di zoom, ma il
/// numero di riquadri NON dipende dallo zoom - dipende da quanto e' grande il
/// riquadro sullo schermo. Su una tela grande nessuno zoom passava il
/// controllo, e la mappa non compariva mai.
void main() {
  const MapTileService service = MapTileService();

  /// La formula ufficiale di OpenStreetMap, scritta in modo diverso da quella
  /// del servizio. Se le due coincidono, la proiezione e' giusta davvero e non
  /// solo coerente con se stessa.
  List<int> riquadroUfficiale(double lat, double lon, int zoom) {
    final double n = math.pow(2, zoom).toDouble();
    final double rad = lat * math.pi / 180.0;
    final double x = (lon + 180.0) / 360.0 * n;
    final double y =
        (1 - math.log(math.tan(rad) + 1 / math.cos(rad)) / math.pi) / 2 * n;
    return <int>[x.floor(), y.floor()];
  }

  /// Un anello di circa [km] chilometri attorno a un punto.
  List<RoutePoint> giro(double lat, double lon, double km,
      {int punti = 900}) {
    final double raggioKm = km / (2 * math.pi);
    final double dLat = raggioKm / 111.0;
    final double dLon = raggioKm / (111.0 * math.cos(lat * math.pi / 180.0));
    return <RoutePoint>[
      for (int i = 0; i < punti; i++)
        RoutePoint(
          latitude: lat + dLat * math.sin(2 * math.pi * i / punti),
          longitude: lon + dLon * math.cos(2 * math.pi * i / punti),
          elapsedSeconds: i * 2,
        ),
    ];
  }

  group('la proiezione e\' quella del resto del mondo', () {
    test('coincide con la formula ufficiale, in quattro continenti', () {
      const List<List<double>> posti = <List<double>>[
        <double>[41.9028, 12.4964], // Roma
        <double>[45.4642, 9.1900], // Milano
        <double>[51.5074, -0.1278], // Londra
        <double>[-33.8688, 151.2093], // Sydney
        <double>[40.7128, -74.0060], // New York
        <double>[0.0, 0.0], // equatore e meridiano zero
      ];

      for (final List<double> posto in posti) {
        for (final int zoom in <int>[8, 12, 14, 17]) {
          final double n = math.pow(2, zoom).toDouble();
          final List<int> mio = <int>[
            (MapTileService.worldX(posto[1]) * n).floor(),
            (MapTileService.worldY(posto[0]) * n).floor(),
          ];
          expect(mio, riquadroUfficiale(posto[0], posto[1], zoom),
              reason: 'lat ${posto[0]}, lon ${posto[1]}, zoom $zoom');
        }
      }
    });

    test('gli estremi stanno dove devono', () {
      expect(MapTileService.worldX(-180), closeTo(0.0, 1e-9));
      expect(MapTileService.worldX(180), closeTo(1.0, 1e-9));
      expect(MapTileService.worldX(0), closeTo(0.5, 1e-9));
      // Mercatore taglia i poli: l'equatore sta a meta'.
      expect(MapTileService.worldY(0), closeTo(0.5, 1e-9));
      expect(MapTileService.worldY(85.05112878), closeTo(0.0, 1e-6));
      expect(MapTileService.worldY(-85.05112878), closeTo(1.0, 1e-6));
    });

    test('oltre il polo non si va in pezzi', () {
      // Non ci si corre, ma un punto GPS sbagliato puo' arrivarci.
      expect(MapTileService.worldY(90).isFinite, isTrue);
      expect(MapTileService.worldY(-90).isFinite, isTrue);
      expect(MapTileService.worldY(90) >= 0, isTrue);
      expect(MapTileService.worldY(-90) <= 1, isTrue);
    });
  });

  group('quanto costa una corsa', () {
    test('una corsa normale sta in pochi riquadri', () {
      for (final double km in <double>[1, 2, 5, 10, 21, 42]) {
        final MapView? vista = service.viewFor(
          giro(45.46, 9.19, km),
          widthPx: 360,
          heightPx: 220,
        );
        expect(vista, isNotNull, reason: 'corsa da $km km');
        expect(vista!.tileCount <= MapTileService.maxTiles, isTrue,
            reason: 'corsa da $km km: ${vista.tileCount} riquadri');
        expect(vista.tileCount <= 9, isTrue,
            reason: 'corsa da $km km: ${vista.tileCount} riquadri, su una '
                'scheda normale non dovrebbero mai essere tanti');
      }
    });

    test('il tetto non viene mai superato, qualunque sia la corsa', () {
      // La garanzia che tiene il conto sotto controllo.
      for (final double km in <double>[0.3, 1, 10, 50, 150, 400]) {
        for (final List<double> dove in <List<double>>[
          <double>[45.46, 9.19],
          <double>[64.1, -21.9], // Reykjavik: Mercatore deforma parecchio
          <double>[-1.3, 36.8], // Nairobi, quasi equatore
        ]) {
          final MapView? vista = service.viewFor(
            giro(dove[0], dove[1], km),
            widthPx: 400,
            heightPx: 260,
          );
          if (vista == null) continue; // niente mappa e' un esito lecito
          expect(vista.tileCount <= MapTileService.maxTiles, isTrue,
              reason: '$km km a ${dove[0]},${dove[1]}: '
                  '${vista.tileCount} riquadri');
        }
      }
    });

    test('una tela grande non fa sparire la mappa', () {
      // IL difetto gia' trovato: il tetto usato come condizione per scendere
      // di zoom faceva fallire ogni zoom, e la mappa non compariva mai.
      final MapView? vista = service.viewFor(
        giro(45.46, 9.19, 10),
        widthPx: 1080,
        heightPx: 900,
      );
      expect(vista, isNotNull,
          reason: 'su una tela grande la mappa deve esserci lo stesso');
      expect(vista!.tileCount <= MapTileService.maxTiles, isTrue);
    });

    test('piu\' lunga e\' la corsa, piu\' larga la vista', () {
      final MapView? corta =
          service.viewFor(giro(45.46, 9.19, 2), widthPx: 360, heightPx: 220);
      final MapView? lunga =
          service.viewFor(giro(45.46, 9.19, 40), widthPx: 360, heightPx: 220);
      expect(corta!.zoom > lunga!.zoom, isTrue,
          reason: 'zoom corta ${corta.zoom}, lunga ${lunga.zoom}');
    });
  });

  group('il percorso cade dove deve', () {
    test('la traccia sta dentro al riquadro disegnato', () {
      // Se la proiezione della vista non corrispondesse a quella dei
      // riquadri, si vedrebbe una mappa giusta con sopra un percorso spostato.
      const double w = 360;
      const double h = 220;
      final List<RoutePoint> percorso = giro(45.46, 9.19, 8);
      final MapView vista =
          service.viewFor(percorso, widthPx: w, heightPx: h)!;

      for (final RoutePoint p in percorso) {
        final double x = vista.screenX(p.longitude);
        final double y = vista.screenY(p.latitude);
        expect(x >= 0 && x <= w, isTrue, reason: 'x $x fuori da 0..$w');
        expect(y >= 0 && y <= h, isTrue, reason: 'y $y fuori da 0..$h');
      }
    });

    test('il percorso e\' centrato, con un margine su tutti i lati', () {
      const double w = 360;
      const double h = 220;
      final List<RoutePoint> percorso = giro(45.46, 9.19, 8);
      final MapView vista =
          service.viewFor(percorso, widthPx: w, heightPx: h)!;

      double minX = w, maxX = 0, minY = h, maxY = 0;
      for (final RoutePoint p in percorso) {
        final double x = vista.screenX(p.longitude);
        final double y = vista.screenY(p.latitude);
        minX = math.min(minX, x);
        maxX = math.max(maxX, x);
        minY = math.min(minY, y);
        maxY = math.max(maxY, y);
      }

      expect(minX > 2 && minY > 2, isTrue,
          reason: 'la traccia tocca il bordo: minX $minX, minY $minY');
      expect(maxX < w - 2 && maxY < h - 2, isTrue,
          reason: 'la traccia tocca il bordo: maxX $maxX, maxY $maxY');

      // Centrata: lo spazio a sinistra somiglia a quello a destra.
      expect((minX - (w - maxX)).abs() < 2, isTrue,
          reason: 'sinistra $minX, destra ${w - maxX}');
      expect((minY - (h - maxY)).abs() < 2, isTrue,
          reason: 'sopra $minY, sotto ${h - maxY}');
    });

    test('un andata e ritorno sulla stessa strada non manda la scala a zero',
        () {
      // Un percorso rettilineo ha uno dei due lati largo zero: senza un
      // minimo, la divisione darebbe infinito e non si disegnerebbe niente.
      final List<RoutePoint> dritto = <RoutePoint>[
        for (int i = 0; i < 400; i++)
          RoutePoint(
            latitude: 45.46 + 0.00004 * i,
            longitude: 9.19,
            elapsedSeconds: i * 2,
          ),
      ];
      final MapView? vista =
          service.viewFor(dritto, widthPx: 360, heightPx: 220);
      expect(vista, isNotNull);
      expect(vista!.worldPixels.isFinite, isTrue);
      expect(vista.tileCount <= MapTileService.maxTiles, isTrue);
      for (final RoutePoint p in dritto) {
        expect(vista.screenX(p.longitude).isFinite, isTrue);
        expect(vista.screenY(p.latitude).isFinite, isTrue);
      }
    });

    test('un punto solo non e\' un percorso', () {
      expect(service.viewFor(const <RoutePoint>[], widthPx: 360, heightPx: 220),
          isNull);
      expect(
        service.viewFor(
          <RoutePoint>[
            const RoutePoint(latitude: 45.0, longitude: 9.0, elapsedSeconds: 0)
          ],
          widthPx: 360,
          heightPx: 220,
        ),
        isNull,
      );
    });

    test('senza spazio non si disegna', () {
      expect(
        service.viewFor(giro(45.46, 9.19, 5), widthPx: 0, heightPx: 220),
        isNull,
      );
    });
  });

  group('il fornitore sta in un posto solo', () {
    test('l\'indirizzo ha i tre segnaposto', () {
      // Se ne manca uno, si scaricherebbe sempre lo stesso riquadro.
      expect(MapTileService.tileUrlTemplate.contains('{z}'), isTrue);
      expect(MapTileService.tileUrlTemplate.contains('{x}'), isTrue);
      expect(MapTileService.tileUrlTemplate.contains('{y}'), isTrue);
    });

    test('c\'e\' un\'attribuzione, e non e\' vuota', () {
      // Non e' una decorazione: e' una condizione d'uso dei dati.
      expect(MapTileService.attribution.trim().isNotEmpty, isTrue);
    });

    test('ci presentiamo con un nome', () {
      // I server di mappe bloccano chi non si identifica.
      expect(MapTileService.userAgent.toLowerCase().contains('falcata'),
          isTrue);
    });
  });
}
