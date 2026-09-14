import 'dart:async';

import 'package:geolocator/geolocator.dart';
import 'package:geolocator_android/geolocator_android.dart';

/// Un campione GPS normalizzato, indipendente dal pacchetto usato.
///
/// Isolare qui il tipo del plugin permette di sostituire `geolocator` in
/// futuro senza toccare il resto dell'app.
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
/// REGISTRAZIONE IN BACKGROUND
/// ---------------------------
/// Con [background] attivo il servizio chiede ad Android un *foreground
/// service* di tipo "location": compare una notifica permanente e il sistema
/// si impegna a non uccidere il processo. Cosi' la corsa continua a
/// registrarsi con lo schermo spento e con il telefono in tasca.
///
/// Questa e' la strada corretta su Android: usando il foreground service NON
/// serve il permesso "Consenti sempre" (ACCESS_BACKGROUND_LOCATION), che
/// spaventa l'utente ed e' molto piu' difficile da giustificare sugli store.
///
/// Il wake lock tiene la CPU sveglia: senza, Android sospende il processo dopo
/// qualche minuto di schermo spento e si perderebbero i punti GPS.
class GpsService {
  StreamSubscription<Position>? _subscription;
  final StreamController<GpsSample> _controller =
      StreamController<GpsSample>.broadcast();
  final StreamController<Object> _errors = StreamController<Object>.broadcast();

  bool _running = false;
  bool _backgroundActive = false;

  bool get isRunning => _running;

  /// `true` se lo stream attivo sta usando il foreground service.
  bool get isBackgroundActive => _backgroundActive;

  /// Flusso dei campioni GPS restituiti dal sistema.
  Stream<GpsSample> get samples => _controller.stream;

  /// Flusso degli errori del provider di posizione.
  Stream<Object> get errors => _errors.stream;

  /// Avvia l'ascolto della posizione.
  ///
  /// [background] attiva la notifica permanente e il wake lock. Va usato solo
  /// durante la registrazione vera: per la semplice anteprima del segnale
  /// prima dello START si lascia `false`, cosi' non compare nessuna notifica.
  ///
  /// [distanceFilterMeters] a 0 significa "notificami ogni aggiornamento": il
  /// filtro sui punti lo applichiamo noi in `GpsFilter`, dove possiamo
  /// controllare accuratezza, salti e velocita' impossibili.
  Future<void> start({
    int distanceFilterMeters = 0,
    bool background = false,
    String notificationTitle = 'Run Coach',
    String notificationText = 'Registrazione della corsa in corso',
  }) async {
    if (_running) return;

    final LocationSettings settings = background
        ? AndroidSettings(
            accuracy: LocationAccuracy.best,
            distanceFilter: distanceFilterMeters,
            foregroundNotificationConfig: ForegroundNotificationConfig(
              notificationTitle: notificationTitle,
              notificationText: notificationText,
              enableWakeLock: true,
            ),
          )
        : LocationSettings(
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
        onError: (Object error, StackTrace stackTrace) {
          if (!_errors.isClosed) _errors.add(error);
        },
        cancelOnError: false,
      );
      _running = true;
      _backgroundActive = background;
    } catch (error) {
      if (!_errors.isClosed) _errors.add(error);
      _running = false;
      _backgroundActive = false;
      rethrow;
    }
  }

  /// Interrompe l'ascolto della posizione e, se attivo, il foreground service
  /// (la notifica permanente sparisce).
  Future<void> stop() async {
    await _subscription?.cancel();
    _subscription = null;
    _running = false;
    _backgroundActive = false;
  }

  /// Passa dall'anteprima alla registrazione in background (o viceversa)
  /// riavviando lo stream con le impostazioni giuste.
  Future<void> restart({
    required bool background,
    int distanceFilterMeters = 0,
    String notificationTitle = 'Run Coach',
    String notificationText = 'Registrazione della corsa in corso',
  }) async {
    await stop();
    await start(
      distanceFilterMeters: distanceFilterMeters,
      background: background,
      notificationTitle: notificationTitle,
      notificationText: notificationText,
    );
  }

  /// Rilascia le risorse. Dopo `dispose()` il servizio non e' piu' usabile.
  Future<void> dispose() async {
    await stop();
    await _controller.close();
    await _errors.close();
  }
}
