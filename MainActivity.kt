package com.runcoachapp.run_coach_app

import android.Manifest
import android.content.pm.PackageManager
import android.os.Build
import android.view.WindowManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/**
 * Activity principale dell'app.
 *
 * Espone un unico canale nativo ("device") con due funzioni che richiedono
 * l'Activity e che altrimenti costringerebbero ad aggiungere pacchetti
 * esterni:
 *
 *  - setKeepScreenOn: tiene lo schermo acceso durante la registrazione;
 *  - requestNotificationPermission: da Android 13 la notifica della
 *    registrazione in background richiede il consenso dell'utente.
 */
class MainActivity : FlutterActivity() {

    private val deviceChannel = "com.runcoachapp.run_coach_app/device"
    private val notificationRequestCode = 4711

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, deviceChannel)
            .setMethodCallHandler { call, result ->
                when (call.method) {

                    "setKeepScreenOn" -> {
                        val enabled = call.argument<Boolean>("enabled") ?: false
                        runOnUiThread {
                            if (enabled) {
                                window.addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
                            } else {
                                window.clearFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
                            }
                        }
                        result.success(null)
                    }

                    "requestNotificationPermission" -> {
                        // Prima di Android 13 il permesso non esiste: e' gia'
                        // concesso per definizione.
                        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.TIRAMISU) {
                            result.success(true)
                        } else {
                            val granted = checkSelfPermission(
                                Manifest.permission.POST_NOTIFICATIONS
                            ) == PackageManager.PERMISSION_GRANTED

                            if (granted) {
                                result.success(true)
                            } else {
                                // La richiesta e' asincrona: si risponde subito
                                // "non ancora concesso". La registrazione parte
                                // comunque, la notifica comparira' al prossimo
                                // avvio se l'utente accetta.
                                requestPermissions(
                                    arrayOf(Manifest.permission.POST_NOTIFICATIONS),
                                    notificationRequestCode
                                )
                                result.success(false)
                            }
                        }
                    }

                    else -> result.notImplemented()
                }
            }
    }
}
