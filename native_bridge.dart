import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Ponte verso il codice nativo Android dell'app (`MainActivity.kt`).
///
/// Serve per le due cose che richiedono l'Activity e che altrimenti
/// costringerebbero ad aggiungere pacchetti esterni:
///
///  - tenere lo schermo acceso durante la corsa;
///  - chiedere il permesso per la notifica di registrazione (Android 13+).
///
/// Se il canale non risponde (ad esempio nei test) l'app prosegue senza
/// bloccarsi: sono entrambe funzioni accessorie.
class NativeBridge {
  static const MethodChannel _channel =
      MethodChannel('com.runcoachapp.run_coach_app/device');

  /// Impedisce allo schermo di spegnersi mentre si registra.
  Future<void> setKeepScreenOn(bool enabled) async {
    try {
      await _channel.invokeMethod<void>('setKeepScreenOn', <String, dynamic>{
        'enabled': enabled,
      });
    } catch (error) {
      debugPrint('NativeBridge: setKeepScreenOn non disponibile ($error)');
    }
  }

  /// Chiede il permesso di mostrare notifiche (necessario da Android 13).
  ///
  /// Se l'utente rifiuta, la registrazione in background funziona comunque:
  /// semplicemente non si vede la notifica con i dati della corsa.
  /// Restituisce `true` se il permesso risulta concesso.
  Future<bool> requestNotificationPermission() async {
    try {
      final bool? granted =
          await _channel.invokeMethod<bool>('requestNotificationPermission');
      return granted ?? false;
    } catch (error) {
      debugPrint('NativeBridge: permesso notifiche non disponibile ($error)');
      return false;
    }
  }
}
