package com.runcoachapp.run_coach_app

import android.Manifest
import android.content.ContentValues
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.os.Environment
import android.os.PowerManager
import android.provider.MediaStore
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
 *    Oppo), dove l'esenzione standard non basta;
 *  - shareRunImage: condivide l'immagine di una corsa;
 *  - saveTextFile / openTextFile: la copia di sicurezza dell'archivio, salvata
 *    e riletta dove decide l'utente.
 */
class MainActivity : FlutterActivity() {

    private val deviceChannel = "com.runcoachapp.run_coach_app/device"
    private val notificationRequestCode = 4711

    // La copia di sicurezza passa dal selettore di file di Android (SAF):
    // l'utente sceglie dove scrivere e cosa rileggere, e l'app non ha bisogno
    // di nessun permesso sulla memoria. La risposta arriva piu' tardi, in
    // onActivityResult, quindi la richiesta Flutter va tenuta da parte.
    private val saveFileCode = 4713
    private val openFileCode = 4714
    private var pendingResult: MethodChannel.Result? = null
    private var pendingContent: String? = null

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

                    // Condivide l'immagine di una corsa.
                    //
                    // PERCHE' NON UN FileProvider, CHE SAREBBE LA VIA SOLITA
                    // ------------------------------------------------------
                    // Il FileProvider sta in androidx, cioe' in una libreria
                    // che va dichiarata fra le dipendenze. Aggiungere una
                    // dipendenza per condividere un'immagine significa un
                    // pezzo in piu' che puo' rompere la compilazione a ogni
                    // aggiornamento di Flutter, su un'app che per scelta ne ha
                    // cinque in tutto.
                    //
                    // MediaStore e' nel sistema, non in una libreria. Da
                    // Android 10 ci si puo' scrivere senza nessun permesso, e
                    // restituisce proprio il tipo di indirizzo che serve per
                    // condividere. In piu' l'immagine resta nella galleria,
                    // nella cartella Falcata: chi la vuole rimandare domani la
                    // ritrova senza riaprire l'app.
                    "shareRunImage" -> {
                        val png = call.argument<ByteArray>("png")
                        val text = call.argument<String>("text") ?: ""
                        result.success(shareRunImage(png, text))
                    }

                    // Chiede dove salvare la copia e la scrive li'.
                    "saveTextFile" -> {
                        if (pendingResult != null) {
                            result.success(false)
                        } else {
                            val nome = call.argument<String>("name") ?: "falcata.json"
                            pendingContent = call.argument<String>("content") ?: ""
                            pendingResult = result
                            try {
                                val intent = Intent(Intent.ACTION_CREATE_DOCUMENT).apply {
                                    addCategory(Intent.CATEGORY_OPENABLE)
                                    type = "application/json"
                                    putExtra(Intent.EXTRA_TITLE, nome)
                                }
                                startActivityForResult(intent, saveFileCode)
                            } catch (error: Exception) {
                                pendingResult = null
                                pendingContent = null
                                result.success(false)
                            }
                        }
                    }

                    // Chiede quale copia rileggere e ne restituisce il testo.
                    "openTextFile" -> {
                        if (pendingResult != null) {
                            result.success(null)
                        } else {
                            pendingResult = result
                            try {
                                val intent = Intent(Intent.ACTION_OPEN_DOCUMENT).apply {
                                    addCategory(Intent.CATEGORY_OPENABLE)
                                    // Non si filtra per application/json: tanti
                                    // gestori di file e servizi cloud
                                    // restituiscono i .json come tipo generico,
                                    // e filtrando l'utente non vedrebbe la
                                    // propria copia.
                                    type = "*/*"
                                }
                                startActivityForResult(intent, openFileCode)
                            } catch (error: Exception) {
                                pendingResult = null
                                result.success(null)
                            }
                        }
                    }

                    else -> result.notImplemented()
                }
            }
    }

    /**
     * La risposta del selettore di file.
     *
     * Vale per tutte e due le direzioni: salvataggio e rilettura. La richiesta
     * Flutter rimasta in sospeso viene chiusa qui, **sempre** - anche quando
     * l'utente annulla o qualcosa va storto. Una richiesta lasciata aperta
     * bloccherebbe per sempre il pulsante nell'app, e non si capirebbe perche'.
     */
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode != saveFileCode && requestCode != openFileCode) return

        val risposta = pendingResult
        val contenuto = pendingContent
        pendingResult = null
        pendingContent = null
        if (risposta == null) return

        val annullato = resultCode != RESULT_OK || data?.data == null
        if (annullato) {
            risposta.success(if (requestCode == saveFileCode) false else null)
            return
        }

        val uri = data!!.data!!
        try {
            if (requestCode == saveFileCode) {
                contentResolver.openOutputStream(uri)?.use { out ->
                    out.write((contenuto ?: "").toByteArray(Charsets.UTF_8))
                }
                risposta.success(true)
            } else {
                val testo = contentResolver.openInputStream(uri)?.use { input ->
                    input.readBytes().toString(Charsets.UTF_8)
                }
                risposta.success(testo)
            }
        } catch (error: Exception) {
            risposta.success(if (requestCode == saveFileCode) false else null)
        }
    }

    /**
     * Scrive l'immagine nella galleria e apre il pannello di condivisione.
     *
     * Se qualcosa non va - Android troppo vecchio, galleria non scrivibile,
     * immagine assente - non fallisce: ripiega sul testo. Una condivisione
     * senza figura e' meno bella; una condivisione che non parte e' un
     * pulsante rotto.
     */
    private fun shareRunImage(png: ByteArray?, text: String): Boolean {
        if (png == null || png.isEmpty()) return shareText(text)

        // Prima di Android 10 scrivere nella galleria vorrebbe il permesso di
        // accesso alla memoria: un permesso invasivo, che gli store guardano
        // storto, chiesto per una funzione accessoria. Non vale lo scambio.
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.Q) return shareText(text)

        return try {
            val valori = ContentValues().apply {
                put(
                    MediaStore.Images.Media.DISPLAY_NAME,
                    "Falcata-" + System.currentTimeMillis() + ".png"
                )
                put(MediaStore.Images.Media.MIME_TYPE, "image/png")
                put(
                    MediaStore.Images.Media.RELATIVE_PATH,
                    Environment.DIRECTORY_PICTURES + "/Falcata"
                )
            }

            val uri = contentResolver.insert(
                MediaStore.Images.Media.EXTERNAL_CONTENT_URI,
                valori
            ) ?: return shareText(text)

            val scritto = contentResolver.openOutputStream(uri)?.use { out ->
                out.write(png)
                true
            } ?: false
            if (!scritto) return shareText(text)

            val intent = Intent(Intent.ACTION_SEND).apply {
                type = "image/png"
                putExtra(Intent.EXTRA_STREAM, uri)
                if (text.isNotEmpty()) putExtra(Intent.EXTRA_TEXT, text)
                addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
            }
            startActivity(Intent.createChooser(intent, "Condividi la corsa"))
            true
        } catch (error: Exception) {
            shareText(text)
        }
    }

    /** Condivisione di solo testo: funziona ovunque e non chiede niente. */
    private fun shareText(text: String): Boolean {
        if (text.isEmpty()) return false
        return try {
            val intent = Intent(Intent.ACTION_SEND).apply {
                type = "text/plain"
                putExtra(Intent.EXTRA_TEXT, text)
            }
            startActivity(Intent.createChooser(intent, "Condividi la corsa"))
            true
        } catch (error: Exception) {
            false
        }
    }
}
