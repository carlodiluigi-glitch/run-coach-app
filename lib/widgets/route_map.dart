import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../app/tokens.dart';
import '../models/running_activity.dart';
import '../services/map_tile_service.dart';
import 'route_shape.dart';

/// Il percorso sopra la mappa vera.
///
/// COME SI COMPORTA QUANDO LE COSE VANNO MALE
/// ------------------------------------------
/// Questa e' la parte che conta, perche' e' l'unico pezzo di Falcata che
/// dipende da internet. Le regole:
///
/// - **Si parte sempre dal disegno.** Il percorso senza mappa compare subito,
///   prima che sia arrivato un solo riquadro. Non esiste il momento in cui si
///   guarda un rettangolo vuoto.
/// - **Niente rete, nessun errore.** Se i riquadri non arrivano, resta il
///   disegno. Non c'e' nessun messaggio di errore, perche' non e' successo
///   niente di sbagliato: la corsa si vede lo stesso.
/// - **Quello che arriva si tiene.** I riquadri scaricati restano nel telefono
///   e la stessa corsa, riaperta, non ne chiede nemmeno uno.
///
/// L'ATTRIBUZIONE NON SI TOGLIE
/// ----------------------------
/// La scritta in basso a destra e' una condizione d'uso dei dati, non una
/// decorazione. Compare ogni volta che si vede un riquadro di mappa.
class RouteMap extends StatefulWidget {
  const RouteMap({
    super.key,
    required this.route,
    this.height = 220,
  });

  final List<RoutePoint> route;
  final double height;

  @override
  State<RouteMap> createState() => _RouteMapState();
}

class _RouteMapState extends State<RouteMap> {
  static const MapTileService _service = MapTileService();

  MapView? _view;
  final Map<String, ui.Image> _immagini = <String, ui.Image>{};
  Size? _ultimaMisura;
  bool _caricando = false;

  @override
  void dispose() {
    for (final ui.Image img in _immagini.values) {
      img.dispose();
    }
    super.dispose();
  }

  static String _chiave(MapTile t) => '${t.zoom}_${t.x}_${t.y}';

  Future<void> _carica(Size misura) async {
    if (_caricando || _ultimaMisura == misura) return;
    _caricando = true;
    _ultimaMisura = misura;

    final MapView? vista = _service.viewFor(
      widget.route,
      widthPx: misura.width,
      heightPx: misura.height,
    );
    if (vista == null) {
      _caricando = false;
      return;
    }
    if (mounted) setState(() => _view = vista);

    // Un riquadro alla volta: in parallelo si aprirebbero sedici connessioni
    // insieme, e i server di mappe le contano come abuso.
    for (final MapTile t in vista.tiles) {
      if (!mounted) return;
      final String k = _chiave(t);
      if (_immagini.containsKey(k)) continue;

      final File? file = await _service.tileFile(t);
      if (file == null || !mounted) continue;

      final ui.Image? img = await _decodifica(file);
      if (img == null) continue;
      if (!mounted) {
        img.dispose();
        return;
      }
      setState(() => _immagini[k] = img);
    }
    _caricando = false;
  }

  Future<ui.Image?> _decodifica(File file) async {
    try {
      final Uint8List bytes = await file.readAsBytes();
      final ui.Codec codec = await ui.instantiateImageCodec(bytes);
      final ui.FrameInfo frame = await codec.getNextFrame();
      return frame.image;
    } catch (_) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final AppPalette p = AppPalette.of(context);

    return SizedBox(
      height: widget.height,
      width: double.infinity,
      child: LayoutBuilder(
        builder: (BuildContext context, BoxConstraints vincoli) {
          final Size misura = Size(vincoli.maxWidth, widget.height);
          // Il caricamento parte dopo che il disegno e' stato costruito:
          // chiamare setState mentre si costruisce fa saltare Flutter.
          WidgetsBinding.instance.addPostFrameCallback((_) => _carica(misura));

          final MapView? vista = _view;
          final bool conMappa = vista != null && _immagini.isNotEmpty;

          return Stack(
            fit: StackFit.expand,
            children: <Widget>[
              if (vista != null)
                CustomPaint(
                  painter: _MapPainter(
                    view: vista,
                    tiles: _immagini,
                    chiave: _chiave,
                    route: widget.route,
                    lineColor: conMappa ? p.accent : p.accent,
                    startColor: p.green,
                    endColor: conMappa ? Colors.white : p.ink,
                    shadow: conMappa,
                  ),
                )
              else
                // Finche' non si sa nemmeno la vista, il disegno semplice.
                RouteShape(route: widget.route, height: widget.height),

              if (conMappa)
                Positioned(
                  right: 6,
                  bottom: 4,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.75),
                      borderRadius: BorderRadius.circular(3),
                    ),
                    child: Text(
                      MapTileService.attribution,
                      style: const TextStyle(
                        fontSize: 9,
                        color: Color(0xFF333333),
                      ),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _MapPainter extends CustomPainter {
  _MapPainter({
    required this.view,
    required this.tiles,
    required this.chiave,
    required this.route,
    required this.lineColor,
    required this.startColor,
    required this.endColor,
    required this.shadow,
  });

  final MapView view;
  final Map<String, ui.Image> tiles;
  final String Function(MapTile) chiave;
  final List<RoutePoint> route;
  final Color lineColor;
  final Color startColor;
  final Color endColor;

  /// Con la mappa sotto, la traccia ha bisogno di un bordo chiaro per
  /// staccarsi: una linea colorata sopra una fotografia di strade si perde.
  final bool shadow;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.clipRect(Offset.zero & size);

    // ------------------------------------------------------------ i riquadri
    final Paint pennello = Paint()..filterQuality = FilterQuality.medium;
    for (final MapTile t in view.tiles) {
      final ui.Image? img = tiles[chiave(t)];
      if (img == null) continue;
      canvas.drawImageRect(
        img,
        Rect.fromLTWH(0, 0, img.width.toDouble(), img.height.toDouble()),
        Rect.fromLTWH(
          t.offsetX,
          t.offsetY,
          MapTileService.tileSize.toDouble(),
          MapTileService.tileSize.toDouble(),
        ),
        pennello,
      );
    }

    // -------------------------------------------------------------- traccia
    if (route.length >= 2) {
      final Path path = Path();
      for (int i = 0; i < route.length; i++) {
        final double x = view.screenX(route[i].longitude);
        final double y = view.screenY(route[i].latitude);
        if (i == 0) {
          path.moveTo(x, y);
        } else {
          path.lineTo(x, y);
        }
      }

      if (shadow) {
        canvas.drawPath(
          path,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 6.5
            ..strokeCap = StrokeCap.round
            ..strokeJoin = StrokeJoin.round
            ..color = Colors.white.withValues(alpha: 0.85),
        );
      }
      canvas.drawPath(
        path,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3.4
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round
          ..color = lineColor,
      );

      final Offset partenza = Offset(
        view.screenX(route.first.longitude),
        view.screenY(route.first.latitude),
      );
      final Offset arrivo = Offset(
        view.screenX(route.last.longitude),
        view.screenY(route.last.latitude),
      );
      canvas.drawCircle(
        arrivo,
        6,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3
          ..color = endColor,
      );
      canvas.drawCircle(partenza, 6, Paint()..color = startColor);
      canvas.drawCircle(
        partenza,
        6,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5
          ..color = Colors.white.withValues(alpha: 0.9),
      );
    }

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _MapPainter old) =>
      old.tiles.length != tiles.length ||
      old.view != view ||
      old.route != route;
}
