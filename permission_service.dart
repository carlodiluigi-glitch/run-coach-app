import 'package:geolocator/geolocator.dart';

/// Stato di disponibilita' del GPS / dei permessi.
enum GpsAvailability {
  /// Tutto a posto: servizio attivo e permesso concesso.
  ready,

  /// Il servizio di localizzazione del telefono e' spento.
  serviceDisabled,

  /// Permesso negato (ma richiedibile di nuovo).
  denied,

  /// Permesso negato per sempre: serve andare nelle impostazioni di sistema.
  deniedForever,

  /// Errore inatteso.
  unknown,
}

extension GpsAvailabilityLabel on GpsAvailability {
  String get message {
    switch (this) {
      case GpsAvailability.ready:
        return 'GPS pronto';
      case GpsAvailability.serviceDisabled:
        return 'La localizzazione del telefono e\' disattivata. Attivala per registrare la corsa.';
      case GpsAvailability.denied:
        return 'Permesso posizione non concesso. Senza permesso non e\' possibile registrare la corsa.';
      case GpsAvailability.deniedForever:
        return 'Permesso posizione negato in modo permanente. Aprilo dalle impostazioni di sistema dell\'app.';
      case GpsAvailability.unknown:
        return 'Impossibile verificare lo stato del GPS.';
    }
  }

  bool get isReady => this == GpsAvailability.ready;
}

/// Gestione permessi e stato del servizio di localizzazione.
///
/// Usa solo `geolocator`: non serve un pacchetto aggiuntivo per i permessi
/// perche' l'unico permesso richiesto dall'MVP e' la posizione.
class PermissionService {
  /// Verifica lo stato senza chiedere nulla all'utente.
  Future<GpsAvailability> check() async {
    try {
      final bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return GpsAvailability.serviceDisabled;

      final LocationPermission permission = await Geolocator.checkPermission();
      return _map(permission);
    } catch (_) {
      return GpsAvailability.unknown;
    }
  }

  /// Verifica lo stato e, se necessario, chiede il permesso all'utente.
  Future<GpsAvailability> checkAndRequest() async {
    try {
      final bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return GpsAvailability.serviceDisabled;

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      return _map(permission);
    } catch (_) {
      return GpsAvailability.unknown;
    }
  }

  GpsAvailability _map(LocationPermission permission) {
    if (permission == LocationPermission.always ||
        permission == LocationPermission.whileInUse) {
      return GpsAvailability.ready;
    }
    if (permission == LocationPermission.denied) {
      return GpsAvailability.denied;
    }
    if (permission == LocationPermission.deniedForever) {
      return GpsAvailability.deniedForever;
    }
    return GpsAvailability.unknown;
  }

  /// Apre le impostazioni di localizzazione del telefono.
  Future<bool> openLocationSettings() async {
    try {
      return await Geolocator.openLocationSettings();
    } catch (_) {
      return false;
    }
  }

  /// Apre la scheda dell'app nelle impostazioni di sistema.
  Future<bool> openAppSettings() async {
    try {
      return await Geolocator.openAppSettings();
    } catch (_) {
      return false;
    }
  }
}
