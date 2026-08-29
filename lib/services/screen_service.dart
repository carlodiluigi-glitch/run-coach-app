import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Tiene lo schermo acceso durante la corsa.
///
/// Implementato con un `MethodChannel` verso il codice Kotlin dell'app
/// (`MainActivity.kt`): non serve nessun pacchetto aggiuntivo. Se il canale
/// non risponde (es. durante i test) l'app continua normalmente.
class ScreenService {
  static const MethodChannel _channel =
      MethodChannel('com.runcoachapp.run_coach_app/screen');

  Future<void> setKeepScreenOn(bool enabled) async {
    try {
      await _channel.invokeMethod<void>('setKeepScreenOn', <String, dynamic>{
        'enabled': enabled,
      });
    } catch (error) {
      debugPrint('ScreenService: canale non disponibile ($error)');
    }
  }
}
