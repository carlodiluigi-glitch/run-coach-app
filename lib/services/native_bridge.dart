import 'dart:typed_data';

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

  /// L'app e' esclusa dal risparmio energetico di Android?
  ///
  /// PERCHE' CONTA PIU' DEL GPS
  /// -------------------------
  /// La causa numero uno delle corse perse a meta' non e' il segnale: e'
  /// Android che addormenta il processo per risparmiare batteria. Una corsa
  /// di un'ora e mezza diventa una di venti minuti, e non c'e' niente da
  /// recuperare.
  ///
  /// In caso di dubbio risponde `true`: meglio non disturbare l'utente con
  /// un avviso che potrebbe non servire.
  Future<bool> isIgnoringBatteryOptimizations() async {
    try {
      final bool? ok = await _channel
          .invokeMethod<bool>('isIgnoringBatteryOptimizations');
      return ok ?? true;
    } catch (error) {
      debugPrint('NativeBridge: risparmio energetico non leggibile ($error)');
      return true;
    }
  }

  /// Apre la finestra di sistema che chiede l'esenzione.
  ///
  /// Chiede: la decisione resta all'utente e la finestra la disegna Android.
  /// Restituisce `false` se quella schermata non esiste su questo telefono -
  /// certi produttori la tolgono - e allora si ripiega su [openAppSettings].
  Future<bool> requestIgnoreBatteryOptimizations() async {
    try {
      final bool? ok = await _channel
          .invokeMethod<bool>('requestIgnoreBatteryOptimizations');
      return ok ?? false;
    } catch (error) {
      debugPrint('NativeBridge: richiesta esenzione non disponibile ($error)');
      return false;
    }
  }

  /// Apre la pagina di sistema dell'app.
  ///
  /// Serve per i telefoni con un gestore energetico proprio (Xiaomi, Huawei,
  /// Oppo), dove l'esenzione standard non basta e l'impostazione che conta si
  /// chiama "avvio automatico" e sta in un posto diverso per ogni marca.
  Future<bool> openAppSettings() async {
    try {
      final bool? ok = await _channel.invokeMethod<bool>('openAppSettings');
      return ok ?? false;
    } catch (error) {
      debugPrint('NativeBridge: impostazioni app non apribili ($error)');
      return false;
    }
  }

  /// La marca del telefono, in minuscolo. Vuota se non si sa.
  ///
  /// Serve solo per dire all'utente dove cercare: l'impostazione che spegne
  /// le app cambia nome e posto per ogni produttore.
  Future<String> manufacturer() async {
    try {
      final String? name =
          await _channel.invokeMethod<String>('deviceManufacturer');
      return (name ?? '').toLowerCase().trim();
    } catch (error) {
      return '';
    }
  }

  /// Condivide l'immagine di una corsa (e un testo di accompagnamento).
  ///
  /// L'immagine finisce nella galleria, cartella Falcata, e poi si apre il
  /// pannello di condivisione di Android: da li' l'utente sceglie dove
  /// mandarla. Se l'immagine non si puo' scrivere - Android precedente al 10,
  /// galleria piena, permessi negati - parte lo stesso la condivisione del
  /// solo testo, perche' un pulsante che non fa niente e' peggio di un
  /// pulsante che fa meno.
  ///
  /// Restituisce `false` solo se non e' partito proprio niente.
  Future<bool> shareRunImage({required Uint8List png, String text = ''}) async {
    try {
      final bool? ok = await _channel.invokeMethod<bool>(
        'shareRunImage',
        <String, dynamic>{'png': png, 'text': text},
      );
      return ok ?? false;
    } catch (error) {
      debugPrint('NativeBridge: condivisione non disponibile ($error)');
      return false;
    }
  }

  /// Chiede dove salvare un file di testo e lo scrive li'.
  ///
  /// Si apre il selettore di Android: decide l'utente dove va a finire -
  /// telefono, chiavetta, Drive, quello che ha. Cosi' l'app non ha bisogno di
  /// nessun permesso sulla memoria, e la copia non resta in un posto scelto da
  /// noi che l'utente non trovera' mai.
  ///
  /// `false` se ha annullato o se non si e' potuto scrivere.
  Future<bool> saveTextFile({
    required String name,
    required String content,
  }) async {
    try {
      final bool? ok = await _channel.invokeMethod<bool>(
        'saveTextFile',
        <String, dynamic>{'name': name, 'content': content},
      );
      return ok ?? false;
    } catch (error) {
      debugPrint('NativeBridge: salvataggio file non disponibile ($error)');
      return false;
    }
  }

  /// Chiede quale file aprire e ne restituisce il testo.
  ///
  /// `null` se ha annullato o se il file non si e' potuto leggere.
  Future<String?> openTextFile() async {
    try {
      return await _channel.invokeMethod<String>('openTextFile');
    } catch (error) {
      debugPrint('NativeBridge: apertura file non disponibile ($error)');
      return null;
    }
  }

  // ------------------------------------------------------- la cadenza
  //
  // PERCHE' I PASSI LI CONTA IL TELEFONO E NON L'APP
  // ------------------------------------------------
  // Perche' il conteggio dei passi e' l'unica misura in cui un telefono batte
  // il GPS: la fanno gli accelerometri dentro al telefono, e il chip dei
  // sensori la tiene anche mentre Android dorme. Non dipende dai satelliti,
  // dai palazzi, dagli alberi.
  //
  // Rifarlo in Dart vorrebbe dire leggere l'accelerometro a 50 volte al
  // secondo per un'ora, filtrare, cercare i picchi - cioe' tenere sveglia la
  // CPU per riprodurre peggio una cosa che il telefono fa gia' in hardware,
  // consumando niente.

  /// Chiede il permesso per leggere il sensore dei passi (da Android 10).
  ///
  /// Risponde `false` se non e' ancora concesso: la richiesta vera e' una
  /// finestra di sistema e la risposta arriva dopo. Non si aspetta - la corsa
  /// parte comunque e la cadenza, al massimo, comincia dalla prossima.
  Future<bool> requestStepPermission() async {
    try {
      final bool? ok =
          await _channel.invokeMethod<bool>('requestStepPermission');
      return ok ?? false;
    } catch (error) {
      debugPrint('NativeBridge: permesso passi non disponibile ($error)');
      return false;
    }
  }

  /// Comincia a contare i passi da adesso.
  ///
  /// `false` se non si puo': permesso negato, o telefono senza sensore di
  /// passo. In quel caso la corsa va avanti senza cadenza.
  Future<bool> startStepCounter() async {
    try {
      final bool? ok = await _channel.invokeMethod<bool>('startStepCounter');
      return ok ?? false;
    } catch (error) {
      debugPrint('NativeBridge: contapassi non disponibile ($error)');
      return false;
    }
  }

  /// Quanti passi dall'avvio del conteggio. `null` se non si sta contando.
  ///
  /// `null` e zero sono due cose diverse e non vanno confuse: zero vuol dire
  /// "fermo", `null` vuol dire "non lo so". E' lo stesso errore che aveva
  /// azzerato corse intere quando la velocita' zero del GPS veniva letta come
  /// "sta fermo" invece di "il chip non l'ha riportata".
  Future<int?> stepCount() async {
    try {
      final int? passi = await _channel.invokeMethod<int>('stepCount');
      if (passi == null || passi < 0) return null;
      return passi;
    } catch (error) {
      return null;
    }
  }

  /// Smette di contare (e stacca l'ascoltatore del sensore: un ascoltatore
  /// lasciato aperto consuma batteria a corsa finita).
  Future<void> stopStepCounter() async {
    try {
      await _channel.invokeMethod<void>('stopStepCounter');
    } catch (error) {
      debugPrint('NativeBridge: contapassi non fermabile ($error)');
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
