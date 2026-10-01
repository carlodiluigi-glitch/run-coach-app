package com.runcoachapp.run_coach_app

import android.Manifest
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.os.PowerManager
import android.provider.Settings
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
 *    registrazione in background richiede il consenso dell'utente;
 *  - isIgnoringBatteryOptimizations / requestIgnoreBatteryOptimizations:
 *    il risparmio energetico di Android e' la causa numero uno delle corse
 *    perse a meta'. Non lo si puo' disattivare da codice - si puo' solo
 *    chiedere all'utente, e la finestra la apre il sistema;
 *  - openAppSettings: per i telefoni con un gestore proprio (Xiaomi, Huawei,
 *    Oppo), dove l'esenzione standard non basta.
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

                    // L'app e' gia' esclusa dal risparmio energetico?
                    "isIgnoringBatteryOptimizations" -> {
                        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.M) {
                            // Prima di Android 6 il meccanismo non esiste.
                            result.success(true)
                        } else {
                            val power =
                                getSystemService(POWER_SERVICE) as PowerManager
                            result.success(
                                power.isIgnoringBatteryOptimizations(packageName)
                            )
                        }
                    }

                    // Chiede l'esenzione. La decisione resta all'utente: si
                    // apre la finestra di sistema e basta.
                    "requestIgnoreBatteryOptimizations" -> {
                        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.M) {
                            result.success(true)
                        } else {
                            try {
                                val intent = Intent(
                                    Settings
                                        .ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS
                                )
                                intent.data = Uri.parse("package:$packageName")
                                startActivity(intent)
                                result.success(true)
                            } catch (error: Exception) {
                                // Alcuni produttori tolgono quella schermata:
                                // si ripiega sulle impostazioni dell'app.
                                result.success(false)
                            }
                        }
                    }

                    // Apre la pagina di sistema dell'app: e' da li' che si
                    // arriva alle impostazioni proprie di ogni marca.
                    "openAppSettings" -> {
                        try {
                            val intent = Intent(
                                Settings.ACTION_APPLICATION_DETAILS_SETTINGS,
                                Uri.parse("package:$packageName")
                            )
                            intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                            startActivity(intent)
                            result.success(true)
                        } catch (error: Exception) {
                            result.success(false)
                        }
                    }

                    // Che marca e' il telefono: serve per spiegare dove
                    // cercare l'impostazione, che cambia posto per ognuna.
                    "deviceManufacturer" -> {
                        result.success(Build.MANUFACTURER ?: "")
                    }

                    else -> result.notImplemented()
                }
            }
    }
}
