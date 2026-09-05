import 'dart:async';

import 'package:geolocator/geolocator.dart';

/// Un campione GPS normalizzato, indipendente dal pacchetto usato.
///
/// Isolare qui il tipo del plugin permette di sostituire `geolocator` in
/// futuro (o di aggiungere il tracking in background) senza toccare il resto
/// dell'app.
class GpsSample {
  const GpsSample({
    required this.latitude,
    required this.longitude,
    required this.accuracy,
    required this.timestamp,
    this.altitude,
    this.speed,
    this.heading,
  });

  final double latitude;
  final double longitude;

  /// Raggio di incertezza orizzontale in metri (piu' basso = meglio).
  final double accuracy;

  final DateTime timestamp;
  final double? altitude;

  /// Velocita' riportata dal chip GPS in m/s (puo' essere 0 o poco affidabile).
  final double? speed;

  final double? heading;
}

/// Servizio GPS: espone un flusso continuo di [GpsSample].
///
/// NOTA SUL BACKGROUND: in questa prima versione la registrazione avviene con
/// l'app in primo piano e lo schermo acceso. L'architettura e' pronta per il
/// tracking in background (basta sostituire le `LocationSettings` con le
/// `AndroidSettings` che includono la notifica di foreground service) senza
/// modificare i provider o la UI.
class GpsService {
  StreamSubscription<Position>? _subscription;
  final StreamController<GpsSample> _controller =
      StreamController<GpsSample>.broadcast();
  final StreamController<Object> _errors = StreamController<Object>.broadcast();

  bool _running = false;

  bool get isRunning => _running;

  /// Flusso dei campioni GPS validi restituiti dal sistema.
  Stream<GpsSample> get samples => _controller.stream;

  /// Flusso degli errori del provider di posizione.
  Stream<Object> get errors => _errors.stream;

  /// Avvia l'ascolto della posizione.
  ///
  /// [distanceFilterMeters] a 0 significa "notificami ogni aggiornamento":
  /// il filtro sui punti lo applichiamo noi in `GpsFilter`, cosi' possiamo
  /// controllare accuratezza, salti e velocita' impossibili.
  Future<void> start({int distanceFilterMeters = 0}) async {
    if (_running) return;

    final LocationSettings settings = LocationSettings(
      accuracy: LocationAccuracy.best,
      distanceFilter: distanceFilterMeters,
    );

    try {
      _subscription = Geolocator.getPositionStream(
        locationSettings: settings,
      ).listen(
        (Position position) {
          if (_controller.isClosed) return;
          _controller.add(
            GpsSample(
              latitude: position.latitude,
              longitude: position.longitude,
              accuracy: position.accuracy,
              timestamp: position.timestamp,
              altitude: position.altitude,
              speed: position.speed,
              heading: position.heading,
            ),
          );
        },
        onError: (Object error, StackTrace stack) {
          if (!_errors.isClosed) _errors.add(error);
        },
        cancelOnError: false,
      );
      _running = true;
    } catch (error) {
      if (!_errors.isClosed) _errors.add(error);
      _running = false;
      rethrow;
    }
  }

  /// Interrompe l'ascolto della posizione.
  Future<void> stop() async {
    await _subscription?.cancel();
    _subscription = null;
    _running = false;
  }

  /// Rilascia le risorse. Dopo `dispose()` il servizio non e' piu' usabile.
  Future<void> dispose() async {
    await stop();
    await _controller.close();
    await _errors.close();
  }
}
