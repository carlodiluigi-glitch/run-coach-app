# Falcata

App Android (Flutter) per la corsa su strada: registrazione GPS, allenamenti a
intervalli con esecuzione automatica delle fasi, coach vocale, parziali,
record personali, storico, gestione scarpe e statistiche.

> **Nota sul nome.** L'app si chiama Falcata, ma il nome tecnico del pacchetto
> Android e' rimasto `com.runcoachapp.run_coach_app`, e cosi' deve restare:
> per Android quel nome e' l'identita' dell'app. Cambiandolo, il telefono
> vedrebbe un'app diversa e l'aggiornamento non si installerebbe piu' sopra
> quella esistente, perdendo tutte le corse registrate. Vale lo stesso per il
> nome del progetto Flutter (`run_coach_app`) usato negli import.

Il progetto e' pensato per essere caricato su GitHub e compilato
automaticamente in APK tramite GitHub Actions, **senza configurare nessuna
chiave privata**.

---

## Indice

1. [Prerequisiti](#prerequisiti)
2. [Come eseguire l'app](#come-eseguire-lapp)
3. [Come creare l'APK in locale](#come-creare-lapk-in-locale)
4. [Come usare GitHub Actions](#come-usare-github-actions)
5. [Come scaricare l'APK](#come-scaricare-lapk)
6. [Struttura del progetto](#struttura-del-progetto)
7. [Permessi Android](#permessi-android)
8. [Funzioni implementate](#funzioni-implementate)
9. [Funzioni predisposte per il futuro](#funzioni-predisposte-per-il-futuro)
10. [Note tecniche](#note-tecniche)
11. [Risoluzione problemi](#risoluzione-problemi)

---

## Prerequisiti

Per compilare in locale servono:

- **Flutter stabile** (consigliato 3.24 o successivo) - <https://docs.flutter.dev/get-started/install>
- **Java 17** (JDK Temurin o equivalente)
- **Android SDK** con:
  - la Android SDK Platform richiesta dalla tua versione di Flutter
    (installata automaticamente da Android Studio)
  - Android SDK Build-Tools
  - Android SDK Platform-Tools
- Un telefono Android con **debug USB** attivo, oppure un emulatore

Per usare solo GitHub Actions **non serve installare niente**: basta un account
GitHub.

Verifica dell'ambiente locale:

```bash
flutter doctor -v
```

---

## Come eseguire l'app

```bash
flutter pub get
flutter run
```

Con il telefono collegato via USB, `flutter run` installa e avvia l'app.

Comandi utili:

```bash
flutter analyze     # analisi statica del codice
flutter test        # test unitari e widget
flutter devices     # elenco dispositivi collegati
```

---

## Come creare l'APK in locale

APK di debug (piu' veloce da generare):

```bash
flutter build apk --debug
```

APK release (piu' leggera e veloce all'uso):

```bash
flutter build apk --release
```

I file vengono creati in:

```
build/app/outputs/flutter-apk/app-debug.apk
build/app/outputs/flutter-apk/app-release.apk
```

> La build release e' firmata con la chiave fissa del progetto
> (`android/app/runcoach-release.jks`, referenziata da `android/key.properties`).
> Non serve configurare nulla: la chiave e' nel repository apposta, cosi'
> ogni APK e' firmata allo stesso modo e si installa **sopra** la precedente
> senza disinstallare e senza perdere i dati.
>
> Chiave e password NON sono quindi un segreto. Prima di pubblicare sul Play
> Store va generata una chiave nuova, tenuta fuori dal repository e passata
> alla CI come secret. **Conservane sempre una copia**: se si perde, l'app non
> e' piu' aggiornabile.

---

## Come usare GitHub Actions

1. Crea un repository su GitHub (anche privato).
2. Carica il contenuto di questa cartella nella **radice** del repository.
   Nella radice devono trovarsi: `pubspec.yaml`, `lib/`, `android/`,
   `.github/`, `README.md`, `.gitignore`.
3. Assicurati che il branch principale si chiami `main`.

Da riga di comando:

```bash
git init
git add .
git commit -m "Falcata - primo commit"
git branch -M main
git remote add origin https://github.com/TUO-UTENTE/run_coach_app.git
git push -u origin main
```

Il workflow si trova in `.github/workflows/android.yml` e parte:

- **automaticamente** ad ogni `push` sul branch `main`;
- **manualmente** da GitHub -> **Actions** -> **Android APK** -> **Run workflow**.

Cosa fa il workflow:

1. checkout del repository;
2. installa **Java 17**;
3. installa **Flutter** (canale stable);
4. esegue `flutter pub get`;
5. esegue `flutter analyze` (non bloccante);
6. esegue `flutter test` (non bloccante);
7. compila `app-release.apk` e `app-debug.apk`;
8. carica gli APK come artifact chiamato **`Falcata-APK`**.

Non e' richiesto nessun *secret*, nessuna password e nessuna API key.

---

## Come scaricare l'APK

1. Apri il repository su GitHub.
2. Vai su **Actions**.
3. Clicca sull'ultima esecuzione del workflow **Android APK**.
4. In fondo alla pagina, nella sezione **Artifacts**, clicca su
   **Falcata-APK**.
5. Scarichi uno zip contenente `app-release.apk` e `app-debug.apk`.
6. Copia l'APK sul telefono e installala (serve autorizzare
   "installazione da origini sconosciute").

---

## Struttura del progetto

```
run_coach_app/
├── .github/
│   └── workflows/
│       └── android.yml          # build automatica dell'APK
├── android/                     # progetto Android nativo
│   ├── app/
│   │   ├── build.gradle
│   │   └── src/main/
│   │       ├── AndroidManifest.xml
│   │       ├── kotlin/.../MainActivity.kt
│   │       └── res/             # icone, temi, splash
│   ├── build.gradle
│   ├── settings.gradle
│   ├── gradle.properties
│   ├── gradle/wrapper/
│   ├── gradlew
│   └── gradlew.bat
├── lib/
│   ├── main.dart                # avvio app e registrazione provider
│   ├── app/
│   │   ├── app.dart             # MaterialApp
│   │   ├── routes.dart          # rotte con argomenti
│   │   └── theme.dart           # tema Material 3
│   ├── models/
│   │   ├── lap.dart
│   │   ├── running_activity.dart
│   │   ├── running_shoe.dart
│   │   ├── user_settings.dart
│   │   ├── workout.dart
│   │   ├── workout_step.dart
│   │   └── health_data.dart     # HR / HRV / sonno (predisposizione)
│   ├── services/
│   │   ├── gps_service.dart         # stream posizione (geolocator)
│   │   ├── gps_filter.dart          # filtro punti GPS
│   │   ├── permission_service.dart  # permessi e stato GPS
│   │   ├── workout_engine.dart      # motore allenamenti
│   │   ├── audio_coach_service.dart # Text To Speech + cooldown avvisi
│   │   ├── coach_phrases.dart       # tutte le frasi del coach
│   │   ├── stats_service.dart       # statistiche e trend
│   │   ├── records_service.dart     # record personali per distanza
│   │   ├── storage_service.dart     # salvataggio locale JSON
│   │   └── native_bridge.dart       # schermo acceso + permesso notifiche
│   ├── providers/
│   │   ├── settings_provider.dart
│   │   ├── shoe_provider.dart
│   │   ├── workout_provider.dart
│   │   ├── activity_provider.dart
│   │   └── running_provider.dart    # timer, distanza, lap, coach
│   ├── screens/
│   │   ├── splash_screen.dart       # apertura: nome app e saluto
│   │   ├── welcome_screen.dart      # primo avvio: chiede il nome
│   │   ├── home_screen.dart
│   │   ├── run_screen.dart
│   │   ├── workout_library_screen.dart
│   │   ├── workout_builder_screen.dart
│   │   ├── activity_history_screen.dart
│   │   ├── activity_detail_screen.dart
│   │   ├── shoes_screen.dart
│   │   ├── records_screen.dart
│   │   ├── stats_screen.dart
│   │   └── settings_screen.dart
│   ├── widgets/
│   │   ├── app_card.dart
│   │   ├── inset_list.dart
│   │   ├── metric_card.dart
│   │   ├── metric_display.dart
│   │   ├── lap_table.dart
│   │   ├── pace_indicator.dart
│   │   ├── run_control_buttons.dart
│   │   ├── workout_step_widget.dart
│   │   └── empty_state.dart
│   └── utils/
│       ├── formatters.dart        # tempo, distanza, passo, date (schermo)
│       ├── speech_formatters.dart # numeri pronunciabili (voce)
│       └── id_generator.dart
├── test/                        # test unitari e widget
├── analysis_options.yaml
├── pubspec.yaml
├── .gitignore
└── README.md
```

Separazione delle responsabilita':

| Livello    | Cartella     | Cosa fa                                        |
|------------|--------------|------------------------------------------------|
| UI         | `screens/`, `widgets/` | Solo presentazione e input utente     |
| Stato      | `providers/` | Collega UI e servizi, notifica i cambiamenti    |
| Logica     | `services/`  | GPS, filtro, allenamenti, voce, storage, statistiche |
| Dati       | `models/`    | Strutture dati e serializzazione JSON           |

---

## Permessi Android

Dichiarati in `android/app/src/main/AndroidManifest.xml`:

| Permesso                       | Perche' serve                                       |
|--------------------------------|-----------------------------------------------------|
| `ACCESS_FINE_LOCATION`         | posizione GPS precisa: distanza e passo              |
| `ACCESS_COARSE_LOCATION`       | richiesto insieme al precedente da Android 12+       |
| `FOREGROUND_SERVICE`           | registrazione con l'app in secondo piano             |
| `FOREGROUND_SERVICE_LOCATION`  | tipo del servizio (obbligatorio da Android 14)       |
| `WAKE_LOCK`                    | tiene la CPU attiva a schermo spento                 |
| `POST_NOTIFICATIONS`           | notifica della registrazione (da Android 13)         |

**Non** e' richiesto `ACCESS_BACKGROUND_LOCATION` (il permesso "Consenti
sempre"). Usando un foreground service avviato mentre l'app e' in primo piano,
Android consente di continuare a leggere la posizione con il solo permesso
"mentre l'app e' in uso": e' l'approccio meno invasivo e il piu' facile da
giustificare sugli store.

Non sono richiesti permessi Bluetooth, fotocamera o archiviazione. I dati
restano nella cartella privata dell'app.

---

## Funzioni implementate

- Avvio app e Home con saluto personalizzato (nome modificabile).
- Riepilogo: km settimanali, numero allenamenti, passo medio recente,
  ultima attivita'.
- **Corsa libera** con schermata dedicata: stato GPS, richiesta permessi,
  pulsante START.
- **GPS reale** con `geolocator`: posizione, precisione, velocita'.
- **Filtro GPS**: scarta punti con accuratezza scarsa, micro-spostamenti da
  fermo, velocita' impossibili e salti di segnale.
- **Registrazione in background**: la corsa continua con lo schermo spento e
  il telefono in tasca, grazie a un foreground service con notifica
  permanente e wake lock. Disattivabile dalle impostazioni.
- **Timer affidabile**: start / pausa / ripresa / stop; il tempo in pausa non
  viene conteggiato.
- **Distanza** in km con 2 decimali, **passo** in min/km (attuale, medio, del
  lap), `--:--` quando i dati non bastano.
- **Apertura e benvenuto**: all'avvio compare il nome dell'app con il saluto
  (toccando si salta l'attesa); al primissimo avvio viene chiesto il nome, una
  volta sola. Chi non lo vuole dare preme "Preferisco non dirlo" e la domanda
  non torna piu'. Il nome resta modificabile da Impostazioni.
- **Lap automatici** ogni 1 km (distanza configurabile) e **lap manuale**.
- **Parziali per fase**: durante un allenamento programmato ogni fase chiude il
  proprio parziale (ripetuta, recupero, riscaldamento...), con l'etichetta
  della fase salvata nel lap. In questa modalita' il lap automatico a distanza
  resta sospeso, altrimenti i giri cadrebbero a cavallo fra una ripetuta e il
  recupero. Alla fine di ogni fase "di lavoro" il coach annuncia anche il
  tempo del parziale; i recuperi restano silenziosi per non accavallarsi con
  l'annuncio della fase successiva. Lo spezzone finale, quello che resta
  premendo Termina, viene salvato solo se supera 100 m o 30 secondi, e non
  prende il nome della fase: non e' una ripetuta, e' la coda della corsa.
- **Editor di allenamenti** con blocchi ripetuti (`10 x (400 m + 200 m)`).
- Step a **distanza** o a **tempo**, tipi: riscaldamento, corsa, ripetuta,
  recupero, defaticamento, generico.
- **Ritmo target** per fase (intervallo min/max in min/km).
- **WorkoutEngine**: avanzamento automatico delle fasi, step corrente e
  successivo, distanza/tempo residuo, ripetizione corrente e totale.
- **Coach vocale** (`flutter_tts`) in italiano con countdown, annunci di fase,
  lap e fine allenamento.
- **Numeri pronunciabili**: i valori passati alla voce vengono tradotti in
  parole (`5:23` diventa "cinque e ventitre al chilometro"), perche' la
  sintesi vocale legge male le cifre nude. Vedi
  `lib/utils/speech_formatters.dart`.
- **Tre personalita' del coach**: Normale, Motivazionale, Sergente. Tutte le
  frasi sono centralizzate in `lib/services/coach_phrases.dart`.
- **Avvisi di ritmo** con cooldown configurabile (15-60 s).
- **Indicatore ritmo** accessibile: simbolo + parola (`↓ troppo lento`,
  `✓ ritmo corretto`, `↑ troppo veloce`).
- **Storico attivita'** e **dettaglio** con tabella lap.
- **Record personali**: miglior tempo su 1 km, 3 km, 5 km, 10 km, mezza e
  maratona, calcolati col tratto piu' veloce dentro ogni corsa (finestra
  scorrevole sul tracciato, con interpolazione del punto di partenza); piu'
  corsa piu' lunga e settimana migliore. Il dettaglio di una corsa segnala i
  primati che quella corsa detiene.
- **Gestione scarpe**: marca, modello, data primo utilizzo, km iniziali, km
  accumulati, soglia consigliata, numero corse, ultimo utilizzo.
- A fine attivita' viene chiesto **quali scarpe hai usato** e i km vengono
  sommati automaticamente.
- **Statistiche**: km settimana, ultime 4 settimane, grafico 8 settimane,
  passo medio, corsa piu' lunga, trend di miglioramento.
- **Impostazioni** complete e persistenti.
- **Storage locale** su file JSON: i dati restano dopo la chiusura dell'app.
- Gestione degli errori: GPS spento, permesso negato, permesso negato in modo
  permanente, assenza di fix, errori di storage, liste vuote.

---

## Grafica

L'aspetto dell'app segue le convenzioni di iOS, adattate ad Android. Tutte le
scelte passano da un unico file, `lib/app/tokens.dart`: cambiando un colore
li' cambia ovunque.

**Nero mentre corri, chiaro quando ti riposi.** La schermata di corsa e'
sempre nera, in qualunque tema. Non e' una scelta estetica: il bianco su nero
e' la combinazione piu' leggibile al sole, e sugli schermi OLED il nero pieno
non consuma batteria. Tutte le altre schermate seguono il tema del telefono,
chiaro o scuro.

**Un numero grande per schermata.** Durante la corsa il numero piu' grande e'
il passo attuale, e prende il colore del passo obiettivo: verde se sei
dentro, arancio se sei fuori, bianco nella corsa libera (dove non esiste un
"giusto"). Gli altri valori sono deliberatamente piu' piccoli: se sono tutti
uguali, nessuno si legge.

**Colori.** Un solo colore di identita' (rosa) per record e fasi di lavoro;
verde, arancio e rosso solo per dire qualcosa di preciso (in ritmo, fuori
ritmo, azione distruttiva). Nel tema chiaro verde e arancio sono piu' scuri
della versione iOS: quelli originali, su fondo bianco, non hanno abbastanza
contrasto.

**Carattere.** Inter, incluso in `assets/fonts/` (vedi la nota in
`pubspec.yaml`). I numeri usano sempre le cifre a larghezza fissa, cosi'
mentre corri non "ballano" quando un 1 diventa un 7.

**Liste.** Le righe stanno tutte dentro un'unica scheda arrotondata, con i
separatori fra una e l'altra, come nelle impostazioni dell'iPhone. Non una
scheda per riga: sarebbe un mosaico.

**"Termina" compare solo in pausa.** Durante la corsa i comandi sono Giro,
Pausa e - negli allenamenti - Salta fase. Termina non c'e': un tocco
sbagliato in tasca chiuderebbe la registrazione. Per terminare si mette prima
in pausa, e a quel punto il tempo e' gia' fermo.

---

## Funzioni predisposte per il futuro

Il modello dati e' gia' pronto, ma **nessun valore viene inventato o stimato**:
i campi restano `null` finche' non ci sara' una sorgente reale.

- Frequenza cardiaca: `heartRateAverage`, `heartRateMax`, `heartRateSamples`.
- HRV: `rmssd`, `sdnn`, `restingHeartRate` (`HrvData`).
- Sonno: durata, sonno profondo, REM, veglia, punteggio (`SleepData`).
- Dinamiche di corsa: `cadenceSpm`, `strideLengthMeters`,
  `verticalOscillationCm`, `groundContactTimeMs` (`RunningDynamics`).
- Bluetooth: non implementato nell'MVP. L'architettura a servizi permette di
  aggiungere un `HeartRateService` che alimenta gli stessi campi, senza
  toccare UI o storage.
- Tracking GPS in background: **implementato**, vedi sopra.
- Ripresa dopo la chiusura forzata dell'app: se Android termina comunque il
  processo (batteria critica, chiusura manuale dal gestore attivita'), la
  corsa in corso non viene recuperata. Un salvataggio periodico dello stato
  parziale e' il passo successivo naturale.

---

## Note tecniche

**Pacchetti usati** (tutti mantenuti, nessuna generazione di codice):

| Pacchetto        | Uso                                    |
|------------------|----------------------------------------|
| `provider`       | gestione dello stato                   |
| `geolocator`     | posizione GPS                          |
| `flutter_tts`    | coach vocale (Text To Speech)          |
| `path_provider`  | cartella documenti per lo storage JSON |
| `geolocator_android` | foreground service per la registrazione in background |

**Configurazione Android**

| Elemento                | Valore                                    |
|-------------------------|-------------------------------------------|
| Android Gradle Plugin   | 8.9.1                                     |
| Gradle                  | 8.12                                      |
| Kotlin                  | 2.1.0                                     |
| Java                    | 17                                        |
| compileSdk              | `flutter.compileSdkVersion` (segue Flutter) |
| targetSdk               | `flutter.targetSdkVersion` (segue Flutter)  |
| minSdk                  | 23                                        |

`compileSdk` e `targetSdk` non sono fissati a un numero: seguono la versione di
Flutter installata, cosi' il progetto resta compilabile anche con release
future dell'SDK senza dover modificare i file Gradle.

**Perche' il filtro GPS**

Sommare tutti i punti restituiti dal ricevitore produce distanze gonfiate:
da fermo il GPS oscilla di qualche metro e ogni oscillazione verrebbe contata.
`lib/services/gps_filter.dart` applica cinque controlli commentati nel codice:
accuratezza, distanza minima, velocita' massima plausibile, salto di segnale e
intervallo minimo fra campioni.

**Tracking in background**

In questa prima versione la registrazione richiede l'app in primo piano con lo
schermo acceso (l'app tiene lo schermo attivo automaticamente, opzione
disattivabile nelle impostazioni).

---

## Risoluzione problemi

**"flutter.sdk not set in local.properties"**
Esegui `flutter pub get` dalla radice del progetto: il file `local.properties`
viene creato automaticamente da Flutter (ed e' escluso da Git perche'
contiene percorsi locali).

**La build Gradle fallisce per la versione di Java**
Assicurati di usare Java 17 (`java -version`). Con Android Studio:
*Settings -> Build Tools -> Gradle -> Gradle JDK -> 17*.

**Il coach non parla**
Verifica che sul telefono sia installato un motore di sintesi vocale con la
lingua italiana (*Impostazioni -> Sistema -> Lingue -> Sintesi vocale*) e che
l'audio coach sia attivo nelle impostazioni dell'app.

**La distanza non aumenta**
Serve un fix GPS valido: all'aperto, con cielo libero. La schermata di avvio
mostra la qualita' del segnale prima dello START. Il filtro scarta di proposito
i punti poco affidabili.

**La corsa si ferma quando spengo lo schermo**
Controlla che in *Impostazioni -> Registrazione* sia attivo "Registra in
background". Se lo e' gia', il colpevole e' quasi sempre il risparmio
energetico del telefono: vai in *Impostazioni Android -> App -> Falcata ->
Batteria* e scegli **Senza restrizioni**. Su Xiaomi, Huawei, Samsung e
OnePlus questa impostazione e' particolarmente aggressiva e va disattivata a
mano.

**Non vedo la notifica durante la corsa**
Serve il permesso notifiche (Android 13+). L'app lo chiede al primo START; se
e' stato negato, riattivalo da *Impostazioni Android -> App -> Falcata ->
Notifiche*. Senza notifica la registrazione funziona comunque, ma Android
potrebbe essere piu' aggressivo nel sospendere l'app.

**L'APK non si installa**
Sul telefono va autorizzata l'installazione da origini sconosciute per
l'app che stai usando per aprire il file (browser o gestore file).
