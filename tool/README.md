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
4. [Applicare un aggiornamento: AGGIORNA.bat](#applicare-un-aggiornamento-aggiornabat)
5. [Come usare GitHub Actions](#come-usare-github-actions)
6. [Come scaricare l'APK](#come-scaricare-lapk)
7. [Struttura del progetto](#struttura-del-progetto)
8. [Permessi Android](#permessi-android)
9. [Funzioni implementate](#funzioni-implementate)
10. [La cadenza](#la-cadenza)
11. [Funzioni predisposte per il futuro](#funzioni-predisposte-per-il-futuro)
12. [Note tecniche](#note-tecniche)
13. [Risoluzione problemi](#risoluzione-problemi)

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

## Applicare un aggiornamento: AGGIORNA.bat

Nella radice del progetto c'e' **`AGGIORNA.bat`**. Si scarica lo zip
dell'aggiornamento e si fa **doppio clic sul .bat**: trova lo zip piu' recente
nei Download (o sul Desktop, o nella cartella stessa), dice cosa sta per
scrivere, chiede conferma una volta, scrive i file, fa il commit con il
messaggio che viaggia dentro lo zip (`_messaggio.txt`) e lo manda su GitHub, che
compila l'APK da solo.

Perche' esiste: i passaggi a mano - estrai, copia, apri GitHub Desktop, inventa
il messaggio del commit, Commit, Push - sono sei occasioni di sbagliare per ogni
modifica, e una volta e' andata male davvero (una release estratta solo a meta',
con il risultato che una versione non e' mai stata installata e la successiva
conteneva due blocchi di modifiche). Un doppio clic non si estrae a meta'.

Cosa **non** fa, e sono garanzie controllate dal programma stesso:

- non tocca `.git`: la storia del progetto non viene riscritta;
- non cancella file: scrive solo quelli che sono nello zip;
- si rifiuta di partire se la cartella non e' Falcata, o non e' collegata a
  GitHub, o se lo zip non somiglia a un aggiornamento (in cima non c'e' ne'
  `lib`, ne' `test`, ne' `pubspec.yaml`);
- **si ferma se uno zip cambia il nome del progetto o l'identificativo
  Android.** E' l'unico errore da cui non si torna: Android riconosce un'app da
  quell'identificativo, e se cambia considera Falcata un'altra app - si installa
  accanto e tutte le corse registrate restano dentro la vecchia, senza modo di
  riprenderle. Non e' un bug da correggere dopo, e' un archivio perso. Il
  controllo non scattera' mai, ed e' il controllo giusto da avere;
- se non trova `git` sul computer (lo cerca anche dentro GitHub Desktop, che se
  lo porta dietro) non si inventa niente: lascia i file scritti e dice i tre
  passi da fare in GitHub Desktop, compreso il messaggio del commit da
  incollare.

Il motore sta in `strumenti/aggiorna.ps1` ed e' stato provato su tutti i casi
che contano: zip giusto, zip di un altro progetto, zip che rinomina il progetto,
risposta "no", computer senza git, cartella senza `.git`, cartella di un altro
progetto, niente da mandare.

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

### Dal telefono, in un tocco (Release)

Ogni build su `main` che finisce bene pubblica una **Release** con l'APK
dentro, come file singolo.

1. Dal telefono, apri il repository su GitHub.
2. Tocca **Releases** (oppure l'ultima versione indicata a destra).
3. Tocca il file `Falcata-<versione>-build<numero>.apk`.
4. Aprilo e installalo. La prima volta Android chiede il permesso di
   installare da questa origine: si concede una volta sola.

Niente PC, niente zip, niente Chrome che blocca il download: un `.apk` allegato
a una Release e' un file normale, mentre l'artifact di Actions e' uno zip che
Chrome tratta come sospetto.

Il nome della Release e' `b<numero build>`, il titolo riporta la versione, e le
note contengono il messaggio del commit: si capisce sempre quale versione si
sta installando.

### Dal PC (artifact di Actions)

Resta come alternativa, per esempio per prendere anche l'APK di debug.

1. Apri il repository su GitHub.
2. Vai su **Actions**.
3. Clicca sull'ultima esecuzione del workflow **Android APK**.
4. In fondo alla pagina, nella sezione **Artifacts**, clicca su
   **Falcata-APK**.
5. Scarichi uno zip contenente `app-release.apk` e `app-debug.apk`.
6. Copia l'APK sul telefono e installala (serve autorizzare
   "installazione da origini sconosciute").

La Release viene pubblicata usando `gh`, la riga di comando ufficiale di
GitHub, che e' gia' installata sui runner: nessuna action di terzi ha accesso
in scrittura al repository.

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
│   │   ├── license.dart             # cosa e' gratis e cosa si paga
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
│   │   ├── elevation_service.dart   # dislivello, al netto del rumore GPS
│   │   ├── gpx_import.dart          # porta dentro lo storico da file GPX
│   │   ├── map_tile_service.dart    # riquadri di mappa: vista, memoria, costo
│   │   ├── route_windows.dart       # tracciato -> finestre (una strada sola)
│   │   ├── run_profile.dart         # passo e quota lungo il percorso
│   │   ├── storage_service.dart     # salvataggio locale JSON
│   │   └── native_bridge.dart       # schermo acceso + permesso notifiche
│   ├── providers/
│   │   ├── settings_provider.dart
│   │   ├── shoe_provider.dart
│   │   ├── workout_provider.dart
│   │   ├── activity_provider.dart
│   │   ├── plan_provider.dart       # piano attivo
│   │   └── running_provider.dart    # timer, distanza, lap, coach
│   ├── screens/
│   │   ├── splash_screen.dart       # apertura: nome app e saluto
│   │   ├── fitness_screen.dart      # forma, passi, previsioni
│   │   ├── plan_screen.dart         # il piano attivo
│   │   ├── plan_setup_screen.dart   # creazione del piano
│   │   ├── week_edit_screen.dart    # i giorni di UNA settimana sola
│   │   ├── backup_screen.dart       # copia di sicurezza: salva e rimetti
│   │   ├── import_screen.dart       # importa le corse gia' fatte
│   │   ├── share_screen.dart        # l'immagine della corsa da mandare
│   │   ├── unlock_screen.dart       # cosa e' gratis, cosa si paga
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
│   │   ├── day_time_row.dart      # giorno + minuti: una riga, usata in due posti
│   │   ├── route_shape.dart       # il disegno del giro
│   │   ├── route_map.dart         # il giro sopra la mappa vera
│   │   ├── load_chart.dart        # condizione e fatica negli ultimi mesi
│   │   ├── run_profile_chart.dart # passo e altimetria di una corsa
│   │   ├── share_card.dart        # la scheda che diventa immagine
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
├── negozio/
│   └── scheda-play-store.md     # testi pronti per la pubblicazione
├── strumenti/
│   └── aggiorna.ps1             # applica uno zip e fa commit+push
├── AGGIORNA.bat                 # doppio clic: aggiorna tutto
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
| `INTERNET`                     | solo i riquadri di mappa, solo se la mappa e' accesa |
| `ACTIVITY_RECOGNITION`         | il sensore dei passi, per la cadenza (da Android 10) |

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
- **Forma e previsioni**: indice VDOT dai record, cinque passi di allenamento
  personali, tempi previsti su 5 km, 10 km, mezza e maratona con un margine
  che si allarga allontanandosi dalla distanza misurata.
- **Piano di allenamento**: obiettivo, durata e giorni a scelta; fasi, volumi
  con scarichi, sedute di qualita' che sono allenamenti eseguibili. Le gare
  impreviste si inseriscono e il piano alleggerisce prima e recupera dopo.
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
- **Cadenza**: passi al minuto, misurati dal sensore di passo del telefono (non
  dal GPS), con la media e i passi totali nella scheda della corsa e un riquadro
  nel grafico. Vedi [La cadenza](#la-cadenza).
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

## Il motore di allenamento

Due servizi, entrambi Dart puro e quindi testabili senza telefono:
`lib/services/fitness_service.dart` e `lib/services/plan_service.dart`.

### La forma: il VDOT

Il metodo e' quello di Jack Daniels. Da una singola prestazione si ricava un
indice (il VDOT), e da quell'indice tutte le prestazioni equivalenti: 5 km in
19:57 vale un VDOT 50, e un VDOT 50 vale 41:21 sui 10 km, 1:31:35 in mezza e
3:10:49 in maratona.

Le formule sono quelle di Daniels e Gilbert: una dice quanto ossigeno costa
correre a una certa velocita', l'altra quale percentuale del massimo si tiene
per una certa durata. Il VDOT e' il rapporto fra le due; la previsione e'
l'operazione inversa, risolta per bisezione.

`test/fitness_service_test.dart` verifica i numeri contro le tabelle
pubblicate: le previsioni cadono entro pochi secondi da quelle stampate nel
libro.

### I passi di allenamento

Non sono percentuali arbitrarie: ognuno e' il passo di una gara equivalente,
che e' anche il modo in cui si spiegano a parole.

| Passo | Cos'e' | VDOT 50 |
|---|---|---|
| Lento (E) | una frazione del costo di ossigeno che cambia col livello | 5:19 - 5:54 /km |
| Medio (M) | il passo della tua maratona | 4:31 /km |
| Soglia (T) | il passo che terresti per un'ora esatta | 4:13 /km |
| Ripetute (I) | il passo dei tuoi 3000 metri | 3:51 /km |
| Veloci (R) | il passo dei tuoi 1500 metri | 3:36 /km |

Il lento merita una nota. La prima versione usava due frazioni fisse (0,55 e
0,62) per tutti, e su un atleta da indice 36 sbagliava di quasi un minuto al
chilometro; su uno da indice 65 era giusto. Non era un arrotondamento, era il
modello sbagliato: **piu' uno e' allenato, piu' il suo lento e' una
percentuale bassa del proprio massimo**. Un principiante che corre piano sta
gia' al 72% del suo consumo, un atleta evoluto allo stesso sforzo percepito
sta al 62%. Ora la frazione e' una retta ricavata per regressione dai passi
lenti della tabella di riferimento fra indice 30 e 65: scarto medio 2,5
secondi al chilometro, massimo 5. Il test
[`fitness_service_test.dart`](test/fitness_service_test.dart) lo verifica a
ogni livello, non solo su quello comodo.

### Il piano

Quattro principi, tutti documentati in letteratura:

1. **Distribuzione polarizzata** (Seiler): circa l'80% del tempo piano e il
   20% forte, con poco in mezzo. Il "medio tutti i giorni" stanca come il
   forte senza darne i benefici.
2. **Passi dalla forma attuale** (Daniels): ogni fase di ogni seduta ha un
   passo obiettivo derivato dal VDOT.
3. **Progressione con scarichi**: il volume cresce al massimo del 55% dal
   punto di partenza fino al picco, e ogni quarta settimana scende del 25%.
   L'adattamento avviene nel recupero, non nel carico.
4. **Periodizzazione**: costruzione, sviluppo, specifico, scarico.

**I giorni e il tempo li dichiari tu.** Per ogni giorno della settimana dici
quanti minuti hai per correre; zero vuol dire riposo. Da li' il piano decide:

- il **lungo** va dove c'e' piu' tempo, non la domenica per tradizione (a pari
  tempo vince la domenica, poi il sabato);
- la **qualita'** non cade mai il giorno prima del lungo, e due sedute di
  qualita' non sono mai attaccate - la settimana e' circolare, quindi domenica
  e lunedi' contano come attaccati;
- fra i giorni che restano la qualita' va dove c'e' piu' tempo, ed e' martedi'
  e giovedi' solo come spareggio a pari tempo;
- i **lenti** sono lunghi in proporzione al tempo di quel giorno;
- nessuna seduta sfora il tempo dichiarato: il lungo viene accorciato, e la
  qualita' perde prima il contorno (riscaldamento e defaticamento, fino a un
  minimo di 10 e 5 minuti) e poi le ripetizioni, perche' fra "4 x 1000 con
  dieci minuti di riscaldamento" e "3 x 1000 con venti" la prima allena di
  piu';
- se il volume della settimana non ci sta nel tempo disponibile, il volume
  scende e la settimana lo dichiara nella sua nota. Un piano che chiede
  l'impossibile viene abbandonato entro la seconda settimana.

Perche' serviva: i piani sono scritti per una settimana da ufficio, dove il
fine settimana e' il momento libero. Chi lavora nella ristorazione ha la
settimana al contrario, e un lungo da 18 km non entra nell'ora e mezza del
sabato.

Sotto i tre giorni il piano non si costruisce: non basta a tenere separati un
lungo, una qualita' e un lento.

I giorni dichiarati si ricordano nelle **impostazioni**, non dentro il piano.
Prima vivevano solo nel piano, e bastava cancellarlo perche' la settimana
tornasse allo schema standard - lungo di domenica - che e' esattamente quello
che questa funzione esiste per non fare. La settimana di una persona non e' una
proprieta' del suo allenamento.

#### Una settimana puo' fare eccezione

La settimana dichiarata una volta sola e' una finzione comoda: va bene per
generare un piano, non per viverlo. Chi lavora su turni sa il mercoledi' com'e'
fatta la settimana dopo, non tre mesi prima. E quando il piano chiede il lungo
nel giorno del doppio turno non e' che l'atleta si adatta: e' che **quella
settimana viene saltata**, e dopo due settimane saltate il piano non si guarda
piu'. Un piano non si abbandona perche' e' troppo duro, si abbandona perche' ha
smesso di somigliare alla vita di chi lo segue.

Adesso ogni settimana ha un pulsante *"Cambia i giorni di questa settimana"*:
si rimettono i giorni e i minuti, si vede dove cadranno le sedute mentre si
tocca il piu' e il meno, e si applica. Quello che cambia e quello che no:

| Cambia | Non cambia |
|---|---|
| dove cadono le sedute di quella settimana | la fase |
| quanto ci sta (il tempo e' un tetto anche qui) | il volume della progressione |
| la nota della settimana, che lo dichiara | **le altre settimane** |

Il punto non negoziabile e' l'ultima riga. Se cambiare la settimana del 12
ottobre muovesse anche quelle dopo, l'atleta dovrebbe ricordarsi di rimetterla
a posto - e non lo fara', e tre mesi dopo il piano avra' il lungo nel giorno
sbagliato senza che nessuno sappia perche'. Un turno diverso e' un'eccezione,
non un trasloco. Si torna indietro quando si vuole, su una settimana o su
tutte, e il piano conta quante eccezioni ci sono: le eccezioni si accumulano
senza farsi notare.

**Non e' una seconda strada.** Il generatore e' lo stesso, legge solo una
settimana diversa in ingresso: `PlanConfig.availabilityForWeek(n)` restituisce
l'eccezione se c'e', altrimenti la settimana normale, e `_buildWeek` chiama
quella e non sa la differenza. Anche il conto di quante qualita' vuole una
settimana (`qualityWantedFor`) e' uno solo, condiviso fra il generatore e
l'anteprima della schermata: se fosse scritto due volte, prima o poi
l'anteprima direbbe due qualita' dove il piano ne mette una, e un'anteprima che
mente e' peggio di nessuna anteprima. Stessa regola gia' imparata tre volte in
questo progetto - vedi il punto di partenza qui sotto.

Sul disco non finisce il piano, finisce il parametro: `weekOverrides` e' una
mappa da numero di settimana a settimana dichiarata, e il piano viene
ricalcolato da quella. Per questo si torna indietro senza perdere niente, e per
questo un piano salvato prima di questa funzione si riapre identico a com'era.

### Importare le corse che hai gia' fatto

Chi scarica Falcata corre gia' da anni, e quegli anni stanno su Strava o su un
orologio. Al primo avvio l'app guarda un archivio vuoto e dice la verita': non ho
abbastanza per stimare la tua forma, non posso proporti un volume di partenza,
non posso scriverti un piano.

E' onesto, ed e' anche **il momento in cui l'app viene disinstallata**. E' lo
stesso difetto dei "9 km a settimana" proposti a chi ne corre 60 - quello pero'
capitava a un utente solo, questo capita a tutti, al primo minuto.

Adesso si importano i file GPX, che e' il formato con cui Strava, Garmin, Polar e
quasi chiunque altro esportano. Il selettore di file e' lo stesso della copia di
sicurezza: scritto una volta, usato due.

#### Non e' un lettore XML, ed e' una scelta

Un GPX e' XML, e la cosa corretta sarebbe un lettore XML completo: cioe' una
dipendenza in piu' su un progetto che per scelta ne ha cinque, e ogni dipendenza
e' un pezzo che puo' rompersi al prossimo aggiornamento di Flutter (e' gia'
successo con il plugin Gradle).

Quello che c'e' e' un **estrattore di punti traccia**, che fa una cosa sola. Il
modo in cui puo' fallire e' *"questo file non si importa"* - che si vede subito e
non rovina niente - mai *"si importa storto"*. Regge il prefisso di spazio dei
nomi (`<gpx:trkpt>`), gli attributi in ordine inverso (`lon` prima di `lat`, che
in XML e' legittimo e rompe meta' dei lettori scritti in fretta), i punti
auto-chiusi, il CDATA nei nomi e le tracce multiple.

#### La distanza si ricalcola, non si copia

Il file dice gia' una distanza, e sarebbe comodo prenderla. Non si fa: ogni app
la calcola a modo suo, e una corsa importata da Strava accanto a una registrata
da Falcata sarebbero due misure diverse messe nello stesso grafico.

I punti passano invece per **lo stesso filtro che l'app usa mentre corri**, sulla
strada del ripiego (posizioni mediate su nove campioni, soglia proporzionale
all'incertezza). Su una traccia di prova da 1994 metri veri ne misura 1962, con
un passo di 5:04 contro i 5:00 reali - e soprattutto li misura **come li
misurerebbe su una corsa fatta oggi**, che e' l'unica cosa che rende i due numeri
confrontabili.

#### Quello che resta fuori

- **Le pedalate e i viaggi in macchina.** Si riconoscono dal passo: sopra gli 8
  metri al secondo il filtro non somma niente, e una traccia a quella velocita'
  esce con zero metri e viene scartata. Un giro in bici nell'archivio
  sposterebbe l'indice di forma di parecchio, e nella direzione sbagliata.
- **Le tracce senza orari.** Senza durata non c'e' passo, e senza passo quella
  riga falserebbe ogni stima.
- **I doppioni.** Reimportare lo stesso file e' la cosa piu' probabile che
  succeda - non si sa mai se e' andata, e si riprova. Due corse che cominciano
  entro cinque minuti l'una dall'altra sono la stessa corsa.

E niente entra nell'archivio prima che l'utente abbia visto **quante corse sono e
quanti chilometri**: si sceglie il file, si legge cosa e' stato trovato, e solo
dopo si conferma.

### La Home: ordinata male, non brutta

*"Questa schermata e' poco accattivante"* - e il problema non era estetico.

Dall'alto c'erano: **"Ciao Carlo" grandissimo**, che era la cosa piu' grande
dello schermo e non diceva niente; la prontezza; **la settimana che diceva zero
tre volte** (un anello vuoto, "0.0 km - 0 uscite", e sotto "Nessuna corsa questa
settimana"); e poi, forse, cosa fare oggi.

Si apre un'app di allenamento per rispondere a una domanda sola: **cosa faccio
oggi**. Quella risposta stava al quarto posto - e **spariva del tutto** nei
giorni senza seduta in calendario.

Cosa e' cambiato:

**Il blocco "Oggi" e' la testata, e non puo' essere vuoto.** Ha quattro facce:
la seduta del giorno con il pulsante che fa partire proprio quella; "riposo", e
perche' conta; "non hai un piano", con il pulsante per farlo; o niente di tutto
cio', e si corre e basta. Il vuoto non e' una risposta: *"oggi riposo"* e *"non
hai un piano"* sono due risposte diverse, utili tutte e due, e nessuna si legge
da un'assenza.

**La prontezza entra come pillola accanto a "OGGI".** Il suo verdetto - pronto,
normale, solo facile, riposa - serve *mentre si guarda la seduta*, non dieci
centimetri piu' su: e' li' che decide se uscire. Il numero e i motivi restano
nella scheda piu' in basso, per chi li vuole.

**La settimana mostra un bersaglio, non uno zero.** Con un piano attivo: *"0.0
km di 42 previsti, restano 42"*, con l'anello che si riempie. Lo stesso numero,
e si legge al contrario: uno zero accanto a un bersaglio e' un invito, uno zero
da solo e' un rimprovero.

**Il saluto diventa una riga** accanto al nome dell'app, e lo spazio va a quello
che serve a decidere.

**Un accento solo per schermata.** "Allenamenti" era rosso e "Corsa libera"
nero: l'occhio cadeva sull'azione secondaria. Adesso il rosso sta su quella che
si usa davvero.

Un dettaglio che vale la regola generale: il colore della banda di prontezza
adesso lo calcola **una funzione sola**, usata sia dalla pillola in cima sia
dalla scheda in fondo. Due copie dello stesso switch finiscono per divergere, e
li' si sarebbe visto subito - lo stesso stato con due colori nella stessa
schermata.

### Come e' andata, metro per metro

La tabella dei giri dice il passo di ogni chilometro, e va benissimo per un lento
regolare. Non serve a niente per capire **dentro** un chilometro: una ripetuta da
400 metri sparisce nella media del suo chilometro, un calo negli ultimi due
minuti pure, e una salita che ti ha fatto perdere venti secondi sembra una
giornata storta.

Il dettaglio di una corsa mostra adesso il **passo lungo tutto il percorso**, con
la **cadenza** e il **profilo altimetrico** sotto. Messi uno sopra l'altro si
spiegano a vicenda: si vede il passo che cede esattamente dove la strada sale, e
si capisce che non era una giornata storta, era in pendenza; e si vede la cadenza
che crolla negli ultimi chilometri di un lungo, che e' la stanchezza vera (vedi
[La cadenza](#la-cadenza)).

I riquadri compaiono solo se c'e' qualcosa da metterci: una corsa senza cadenza
ne ha due, una senza quota nemmeno quello. Il passo si prende lo spazio che
resta, invece di essere schiacciato per lasciare posto a un riquadro vuoto.

#### Riquadri impilati, non linee sovrapposte

Passo, cadenza e quota si misurano in cose diverse - minuti al chilometro, passi
al minuto, metri - e mettere **piu' scale verticali sullo stesso disegno** e' il
modo piu' comune di mentire con un grafico: scegliendo le scale si puo' far
sembrare che le linee salgano insieme, che si incrocino, che una anticipi
l'altra. Sono illusioni della scala, non cose vere. Riquadri impilati che
condividono **solo l'asse orizzontale** dicono la stessa cosa senza poterla
falsare.

#### Tre scelte che sembrano dettagli

**Il passo e' capovolto.** Sul passo il numero piccolo e' il risultato migliore:
4:00 e' piu' veloce di 6:00. Disegnato dritto, il grafico scenderebbe quando si
va forte, e l'occhio legge "verso il basso" come "va peggio". In alto si corre
forte.

**Le interruzioni sono vere.** Dove il passo non si puo' dire - una sosta, un
buco di segnale - la linea si interrompe. Non scende a zero e non viene ricucita:
un ponte disegnato sopra un buco e' un dato inventato, e sarebbe pure quello piu'
bello da guardare.

**Un dislivello piccolo non viene stirato.** Sotto i venti metri il profilo
altimetrico tiene una scala fissa invece di riempire il riquadro: venti metri su
dieci chilometri sono una pianura, e disegnarli come una montagna sarebbe la
stessa bugia del dislivello gonfiato, fatta con il disegno invece che con i
numeri. Lo stesso vale per la cadenza, con venticinque passi al minuto come
banda minima: una cadenza che sta fra 166 e 171 per un'ora e' una cadenza
ottima, e stirata per riempire il riquadro sembrerebbe un disastro.

**La cadenza non e' capovolta.** Lo e' solo il passo, perche' solo sul passo il
numero piccolo e' il risultato migliore. Per questo i riquadri hanno
un'etichetta: con tre linee impilate, una che sale puo' essere la cadenza o la
salita, e sono due letture opposte della stessa corsa.

#### Niente conti nuovi

I numeri vengono da `RouteWindows`, da `ElevationService` e da `Cadence`, cioe'
**dagli stessi conti** che producono la distanza, il dislivello, la cadenza media
scritta sopra, l'intensita' della seduta e il carico. Per farlo, la pulizia della quota e' diventata un metodo pubblico
(`smoothedAltitudes`) che usano sia il grafico sia chi conta il dislivello: il
numero scritto sotto il disegno e' quello del disegno.

Un grafico che si calcolasse i suoi numeri per conto proprio prima o poi
mostrerebbe una corsa diversa da quella scritta sopra. E' l'errore che questo
progetto ha gia' fatto quattro volte.

### Il passo, non solo la distanza

La distanza adesso viene dalla velocita' del chip. Ma a corsa finita l'app
rilegge il tracciato per capire **che seduta e' stata** (soglia? ripetute?
lento?) e **quanto e' costata**, e per farlo misurava il passo dalle posizioni:
lo stesso difetto gia' corretto, un passo piu' in la'.

Misurato con un errore GPS realistico, su ripetute con passo vero 3:50/km sul
forte e 6:00/km sul recupero:

| errore GPS | dalle posizioni | dalla velocita' |
|---|---|---|
| 3 m | 3:49 / 5:44 | **3:52 / 5:54** |
| 5 m | 3:49 / 5:42 | **3:52 / 5:54** |
| 8 m | 3:47 / 5:38 | **3:52 / 5:54** |

Pochi secondi, ma sempre nella stessa direzione: il forte sembra piu' veloce e
il recupero pure, cioe' **la seduta sembra piu' dura di com'e' stata**. Nel
motore del carico quello scarto viene elevato al quadrato.

#### Una strada sola, finalmente

Lo stesso conto era scritto **due volte**: nel classificatore e nel motore del
carico. Due copie, scritte in momenti diversi, che prima o poi divergono - e' la
quarta volta in questo progetto (il piano che leggeva un indice diverso da
quello della schermata Forma, il trofeo che non sapeva dei personali dichiarati,
la media settimanale che non era quella del punto di partenza, il grafico che
poteva finire su un numero diverso da quello scritto sopra).

Adesso c'e' `RouteWindows`, e tutti e due chiamano quello. Correggerlo significa
correggerlo per tutti.

I tracciati vecchi non hanno la velocita' nei punti: per quelli si torna alle
posizioni, cioe' al comportamento di prima. Peggio, ma mai peggio di prima.

### La copia di sicurezza

Falcata tiene tutto nel telefono e non manda niente a nessuno. E' la scelta
giusta, ma aveva un prezzo che pagava l'utente senza saperlo: **si cambia
telefono e sparisce tutto**. Anni di corse, i record, il piano. Un archivio che
non si puo' portare via non e' tuo, e' in prestito dal telefono che hai adesso.

La copia e' **un file solo, in JSON leggibile**. Non un formato chiuso: se un
giorno Falcata non esiste piu', quel file si apre lo stesso e dentro ci sono le
corse. E lo si mette dove si vuole: l'app apre il selettore di Android e decide
l'utente, cosi' la copia non finisce in un posto scelto da noi che poi non si
trova. Nessun permesso sulla memoria, nessun account, nessun server.

#### Il rischio non e' salvare, e' rimettere

Salvare non puo' rompere niente: nel peggiore dei casi non si salva. Il
ripristino invece **scrive sopra l'archivio buono**, ed e' esattamente il
momento in cui l'utente non ha una seconda copia a cui tornare.

Quindi la regola e' una sola: **prima si controlla tutto, poi si scrive.** Si
verifica il marcatore, si verifica che ogni pezzo sia JSON valido, e solo se e'
passato tutto si tocca il disco. Un pezzo danneggiato ferma **tutto** il
ripristino: scrivere i pezzi buoni e saltare i rotti lascerebbe l'archivio meta'
nuovo e meta' vecchio, e nessuno saprebbe quale meta'.

Due dettagli che sembrano piccoli e non lo sono:

- **La conferma si chiede prima di aprire il selettore.** Dopo aver scelto il
  file l'utente ha gia' in testa che l'operazione e' partita, e una domanda a
  quel punto si risponde senza leggerla.
- **Dopo il ripristino i provider rileggono dal disco.** Senza, l'app
  continuerebbe a mostrare l'archivio di prima finche' non viene riaperta, e
  sembrerebbe che il ripristino non abbia funzionato.

La corsa che si sta registrando in quel momento non entra nella copia: non fa
ancora parte dell'archivio, e rimetterla su un altro telefono farebbe comparire
una corsa a meta' che non si e' mai fatta.

### La distanza: il difetto piu' grave che l'app abbia avuto

Una corsa vera, sua: 10,32 km in 51:40, passo 5:00. Carlo ha detto *"mi e'
sembrato troppo veloce, ho dubitato che fosse sbagliato"*. Aveva ragione a
dubitare, e il difetto era peggio di quanto sembrasse.

**La distanza e' l'ingresso di tutto.** Da li' escono il passo, l'indice di
forma, i record, il carico, i ritmi del piano. Nessun calcolo a valle puo'
rimediare a un numero sbagliato in ingresso: se la distanza e' gonfiata del 15%
l'app ti crede piu' veloce di quello che sei e ti allena a ritmi che non reggi.

#### Il metodo che sembra ovvio, e quanto sbagliava davvero

Falcata sommava la distanza fra un punto GPS e il successivo. Misurato su corse
simulate con un errore del GPS **realistico** - che deriva lentamente invece di
cambiare a ogni secondo:

| caso | metodo vecchio | metodo nuovo |
|---|---|---|
| corsa continua | da +2,5% a +3,1% | **0,0%** |
| ripetute | da -2,4% a -4,2% | **-0,2%** |
| con soste e semafori | da +5,0% a +8,3% | **+0,1%** |

Tre per cento su dieci chilometri sono trecento metri. Sembra poco, e la cosa
che lo rende grave non e' la grandezza: e' che **il segno cambia secondo il tipo
di seduta**. Le corse con soste venivano allungate, le ripetute accorciate.
Confrontare una seduta con l'altra - che e' esattamente quello che fa l'indice
di forma - voleva dire confrontare due misure storte in direzioni opposte.

#### Una lezione su come si misura, piu' importante della correzione

La prima versione di questa analisi concludeva che il metodo vecchio sbagliava
**fino al 69%**. Quel numero e' finito nel README, in tre file di codice e in
due file di test, scritto come se fosse una misura. **Era falso.**

L'errore stava nell'ipotesi, non nel conto: il rumore del GPS era stato
modellato come **indipendente a ogni secondo**. L'errore vero invece deriva
lentamente - multipath, geometria dei satelliti e ionosfera cambiano in minuti,
non in secondi - quindi due posizioni consecutive hanno quasi lo stesso errore,
e la differenza fra loro e' molto piu' pulita di quanto quel modello prevedesse.

A smontarlo non e' stato il codice: e' stato chi l'app la usa, con *"non mi
sembrava che sbagliasse cosi' tanto"*. Aveva ragione, e la verifica l'ha data
lui senza saperlo: la sua corsa segnava 10,32 km, e +2,7% su 10,05 fa
esattamente 10,32.

Una simulazione vale quanto la sua ipotesi piu' debole. Quando il risultato
contraddice l'esperienza di chi guarda i numeri veri, e' quasi sempre l'ipotesi
a essere sbagliata - e vale la pena scriverlo qui, perche' la tentazione di
fidarsi del proprio modello e' esattamente il modo in cui si costruiscono app
che misurano male con grande sicurezza.

#### Il dato giusto c'era gia', e veniva buttato

Il chip GPS non ricava la velocita' dalle posizioni: la misura dallo
**spostamento di frequenza** del segnale dei satelliti - l'effetto Doppler, lo
stesso per cui la sirena di un'ambulanza cambia tono quando passa. E' una misura
diretta e indipendente, precisa a qualche decimo di metro al secondo anche
quando la posizione balla di dieci metri.

Android la riporta in ogni campione. Falcata **la leggeva gia'** - per scriverla
sullo schermo durante la corsa - e poi la buttava via. Adesso la distanza e' il
tempo per quella velocita', sommato.

#### Due trappole, cadute e risalite

**Zero non vuol dire fermo.** Qualche telefono riporta velocita' esattamente
zero sempre. Trattare lo zero come "sei fermo" azzerava la corsa intera su quei
telefoni: cento per cento di errore. Lo zero manda al ripiego sulle posizioni,
che se si e' davvero fermi non somma niente comunque, perche' la posizione non
si muove.

**Due strade, due riferimenti, un totale.** La velocita' e il ripiego sommano
nello stesso totale ma tengono due riferimenti diversi. Lasciando fermo quello
del ripiego mentre si misura con la velocita', al primo campione senza velocita'
il ripiego misurava tutto lo spostamento dall'ultima volta che era stato usato -
cioe' tratti gia' contati. Sulla corsa simulata con i semafori la distanza
usciva **del 90% piu' lunga del vero**. Un riferimento che non avanza e' un
tratto contato due volte.

Entrambe trovate dalla simulazione, non dal ragionamento. E' il motivo per cui i
test di questo file non controllano dei dettagli: ricostruiscono corse di cui si
conosce la distanza vera e verificano che il numero ci somigli.

#### Il ripiego, per i telefoni senza Doppler

Si torna alle posizioni, ma **mediate** sugli ultimi nove campioni - lo stesso
trucco della quota - con una soglia proporzionale all'accuratezza dichiarata,
perche' sotto l'errore del GPS non si distingue un passo da un tremolio. Resta
entro l'1% su un percorso diritto e perde al massimo il 5% su un percorso pieno
di curve strette, dove la media taglia gli angoli. Nove campioni sono il
compromesso misurato: a ventuno la pulizia e' migliore ma un giro con una curva
ogni cento metri perde il 13%.

#### I buchi di segnale: il 10% che spariva in silenzio

Quando il telefono smette di mandare punti per piu' di dieci secondi, quello
che e' successo nel mezzo non lo sa nessuno: moltiplicare l'ultima velocita'
per il buco sarebbe inventare, e inventare al rialzo. Prima il tratto si
buttava via intero.

Il problema e' che su un telefono che manda un punto ogni cinque secondi basta
perderne uno per superare i dieci. Una corsa vera su un percorso misurato di
**12,74 km e' uscita 11,45**: il 10% perso senza che niente lo dicesse,
perche' l'avviso vocale del segnale perso scatta solo dopo trenta secondi.

Adesso una cosa si sa per certo: sei passato dal punto di prima a quello di
adesso, e **la linea dritta fra i due e' il minimo che hai percorso**. Su una
strada dritta e' quasi esatta, in curva e' un po' corta - non puo' mai
gonfiare. Sotto la soglia dell'errore GPS resta zero, perche' li' uno
spostamento e un tremolio non si distinguono: chi e' rimasto fermo durante il
buco non somma niente.

La causa a monte e' stata tolta lo stesso: ad Android adesso si chiede
esplicitamente **un punto al secondo** (`intervalDuration`), anche
nell'anteprima prima dello START, cosi' il GPS e' gia' a regime quando si
parte. Senza chiederlo, il pacchetto ne manda di solito uno ogni cinque.

#### La prova in auto

Verificare la misura della distanza aspettando una corsa e' lento. Tenendo
premuto sul riquadro dello stato GPS si accende la **prova in auto**: il tetto
di velocita' del filtro passa da 8 m/s (29 km/h) a 100 m/s, e si puo' misurare
un tragitto noto in macchina.

Due cose per leggerla bene:

- **non si salva.** Chiudendo l'app torna spenta da sola. Una modalita' di
  prova lasciata accesa per sbaglio falserebbe una corsa vera senza dirlo, ed e'
  anche il motivo per cui si accende con un gesto che non si fa per caso invece
  che con un interruttore nelle impostazioni;
- **prova il ripiego, non la strada principale.** Sopra i 29 km/h il filtro
  smette comunque di fidarsi della velocita' del chip e misura dalle posizioni.
  Un giro in macchina conferma quindi la misura dalle posizioni e la gestione
  delle fermate, non il conto Doppler che l'app usa mentre corri.

### La deriva della quota

Sulla stessa corsa l'app ha scritto **salita 21 m, discesa 35 m**. E' un giro
chiuso: si parte e si arriva nello stesso punto, quindi quello che sali lo
scendi, e l'algoritmo garantisce da solo che i due numeri non possano differire
piu' della soglia di 8 metri. Quattordici metri di scarto non erano il percorso.

Erano la quota di partenza e quella di arrivo, misurate nello stesso posto, che
non coincidevano piu'. L'errore del GPS sulla quota non e' solo rumore veloce:
ha una componente **lenta**. In cinquanta minuti i satelliti si spostano e la
stima scivola di una decina di metri, e per una media su novanta secondi una
deriva lenta e' indistinguibile da una salita molto dolce.

La correzione: quando si torna al punto di partenza, la quota finale **deve**
essere quella iniziale. Tutta la differenza che resta e' deriva per definizione,
e si toglie distribuendola lungo la corsa.

| caso | prima | dopo |
|---|---|---|
| giro piatto, deriva +15 m | salita 15, discesa 0 | **salita 0, discesa 0** |
| giro piatto, deriva -15 m | salita 0, discesa 8 | **salita 0, discesa 0** |
| giro su collina da 40 m, deriva +12 m | salita 40, discesa 24 | **salita 36, discesa 36** |

Su un percorso da un punto a un altro la correzione **non** scatta: li' la
differenza di quota e' vera, e toglierla cancellerebbe il dislivello di chi
finisce in cima a una salita.

### La mappa vera, e perche' nasce spenta

Il disegno del percorso non costa niente e funziona senza rete. Una mappa vera
no: i riquadri li serve un fornitore e si pagano a consumo. Il piu' economico
per un'app come questa da' 150.000 riquadri al mese gratis e poi 125 dollari al
mese - circa 700 utenti attivi, poi la bolletta. E' un **costo ricorrente in un
prodotto che si vende una volta sola**, cioe' esattamente la trappola che
l'acquisto unico esisteva per evitare.

Quindi la mappa c'e', ma fatta in modo che quel conto resti governabile.

**Niente pacchetto, niente scorrimento.** I pacchetti per le mappe sanno fare
zoom e trascinamento, e per farlo scaricano riquadri in continuazione: la spesa
dipende da quanto l'utente gioca con la mappa, e non e' prevedibile. A Falcata
serve l'opposto - una **figura ferma** che inquadra la corsa. Ferma vuol dire un
numero di riquadri deciso in partenza: da due a sei per una corsa normale, con
un tetto a 24 che non si puo' sfondare.

**I riquadri si tengono.** Scaricati una volta, restano nel telefono per un
anno. La stessa corsa riaperta cento volte costa un download, non cento. Nelle
impostazioni si vede quanto spazio occupano e si possono buttare - si
riscaricano quando servono.

**Nasce spenta.** Chi non l'accende non manda una richiesta a nessuno e non fa
crescere nessun conto. Ed e' l'unica funzione per cui l'app ha bisogno di
internet: il permesso nel manifest Android e' stato aggiunto adesso, per questa
e solo per questa.

#### Due difetti trovati scrivendola

Il primo e' nella proiezione, ed e' stato evitato perche' il test la confronta
con la formula ufficiale di OpenStreetMap scritta in modo diverso. Non basta che
il conto sia coerente con se stesso: se sbaglia, si scaricano - e si pagano -
pezzi di mappa di un altro posto, e il percorso cade nel vuoto.

Il secondo c'era davvero. Il tetto ai riquadri era usato come condizione per
scendere di zoom: *"se ne servono troppi, allarga la vista"*. Sembra ovvio ed e'
falso - **il numero di riquadri non dipende dallo zoom**, dipende da quanto e'
grande il riquadro sullo schermo. Per coprire una tela larga 360 pixel ne
servono due o tre a qualunque zoom. Su una tela grande nessuno zoom passava il
controllo e la mappa non compariva mai, in silenzio. Adesso il tetto e' un
controllo di sicurezza sul costo, non una leva di regolazione: se scatta, si
ripiega sul disegno del percorso.

#### Quando le cose vanno male

E' l'unico pezzo di Falcata che dipende da internet, quindi le regole sono
scritte:

- **si parte sempre dal disegno**, che compare subito, prima di qualunque
  riquadro: non esiste il momento in cui si guarda un rettangolo vuoto;
- **niente rete, nessun errore**: se i riquadri non arrivano resta il disegno, e
  non c'e' nessun messaggio, perche' non e' successo niente di sbagliato;
- **un riquadro alla volta**: sedici connessioni insieme i server delle mappe le
  contano come abuso.

#### Prima di pubblicare

`MapTileService.tileUrlTemplate` e' l'unico posto dove e' scritto da dove
arrivano i riquadri, e punta a OpenStreetMap. E' gratuito e perfetto per un'app
usata da chi la scrive, ma la loro politica d'uso non consente di appoggiarsi ai
loro server per un'app distribuita su un negozio: e' una fondazione che paga
quella banda con le donazioni. Per pubblicare serve un fornitore con un
contratto - cambia quella riga e si aggiunge la chiave, il resto non si tocca.

L'attribuzione invece non e' facoltativa in nessun caso, ed e' per questo che
sta nella stessa classe accanto all'indirizzo e non in una schermata
dimenticabile.

### Il percorso, e il dislivello che quasi tutti sbagliano

La traccia GPS veniva registrata e salvata da sempre, e non si vedeva da nessuna
parte. Adesso il dettaglio di una corsa mostra il **disegno del giro**, con
partenza e arrivo.

Non e' una mappa stradale: una mappa vuole un servizio esterno, una chiave, una
connessione mentre la guardi e di solito un conto da pagare oltre un certo
numero di visualizzazioni. Il valore, per chi ha appena finito di correre, sta
quasi tutto nella **forma**: riconoscere il proprio giro, vedere dove si e'
girato, accorgersi che il GPS ha fatto un salto. Quello lo da' la traccia da
sola, senza rete, senza chiavi e senza mandare in giro il posto in cui abiti.

Un dettaglio che non e' un dettaglio: i gradi di longitudine valgono meno di
quelli di latitudine, e sempre meno salendo verso i poli. Senza quella
correzione un giro quadrato verrebbe disegnato rettangolare, e chi lo guarda non
riconoscerebbe il suo percorso.

**Il dislivello e' la parte in cui si sbaglia.** Il GPS la quota la sa male:
sulla verticale un telefono sbaglia dai quattro ai dodici metri, e l'errore
cambia da un secondo all'altro anche stando fermi. Sommare le differenze punto
per punto - la cosa ovvia da fare - su un'ora in pianura da' **ottomila metri di
dislivello**, tutti fatti di rumore. Si riconosce perche' il numero cresce con la
durata della corsa invece che con le salite.

La soluzione e' in due passaggi: si smussa la quota su una finestra di tempo, e
si conta solo quello che supera una soglia, spostando ogni volta il punto di
riferimento.

E qui c'e' l'errore che e' stato commesso scrivendo questo codice, prima di
essere corretto. La prima versione smussava su una finestra di **punti** - cinque
punti, soglia tre metri - e dava **474 metri su un'ora in pianura**. Una finestra
contata in punti dura mezzo minuto se il telefono registra una volta al secondo
e due minuti e mezzo se registra ogni cinque: nel primo caso non pulisce
abbastanza, nel secondo spiana le salite vere. La finestra va misurata in
**secondi**, e `RoutePoint` il tempo ce l'ha.

I valori finali - finestra di 45 secondi, soglia di 8 metri - non sono scelti a
occhio: vengono da una simulazione su percorsi di cui si conosceva il dislivello
vero, al campionamento reale dell'app (un punto ogni due secondi).

| percorso vero | rumore 4 m | rumore 12 m | somma ingenua |
|---|---|---|---|
| pianura, 0 m | **0 m** | **2 m** | 8.100 m |
| salita 100 m e ritorno | 94 m | 96 m | 8.100 m |
| ondulato, 150 m | 113 m | 124 m | 8.000 m |
| salita continua, 300 m | 292 m | 295 m | 8.100 m |

La pianura resta pianura anche con il segnale peggiore, ed e' la cosa che conta
di piu': e' li' che le app sbagliano in modo vistoso. Le salite lunghe sono
esatte. Il percorso ondulato viene sottostimato di circa un quinto, ed e' il
prezzo dello smussamento - una stima prudente e' preferibile a un numero
gonfiato che non si distingue dal rumore.

Sotto i venti metri l'app scrive **"Pianeggiante"** invece del numero: dare a un
residuo di rumore l'aria di una misura sarebbe la stessa bugia in piccolo.

### Condividere una corsa

Un pulsante genera l'immagine della corsa - distanza, tempo, passo, dislivello,
il disegno del giro - e la manda dove si vuole. E' il modo in cui le app di
corsa si fanno conoscere senza pubblicita': ogni corsa condivisa e' qualcuno che
la vede e chiede con cosa e' stata fatta. Per un'app che si compra una volta
sola e non ha un budget di marketing, quel passaparola e' il canale.

Due scelte che vale la pena scrivere.

**Niente FileProvider.** La via solita per condividere un file su Android passa
da `androidx`, cioe' da una libreria da dichiarare fra le dipendenze - un pezzo
in piu' che puo' rompere la compilazione a ogni aggiornamento di Flutter, su
un'app che per scelta ne ha cinque in tutto. `MediaStore` sta nel sistema, non
in una libreria: da Android 10 ci si scrive senza nessun permesso e restituisce
proprio l'indirizzo che serve. In piu' l'immagine resta nella galleria, cartella
Falcata, e chi la vuole rimandare domani la ritrova senza riaprire l'app. Sotto
Android 10 si condivide il solo testo, perche' scrivere nella galleria vorrebbe
un permesso invasivo per una funzione accessoria.

**Il percorso non dice dove abiti.** Il disegno e' in scala relativa, senza
coordinate e senza mappa: si vede la forma del giro, non il posto. Chi condivide
una corsa non sta scegliendo di pubblicare il proprio indirizzo, e l'app non
deve fargli prendere quella decisione per sbaglio. L'immagine si vede prima di
mandarla, sempre.

### Il grafico degli ultimi mesi

Il motore del carico calcolava condizione e fatica giorno per giorno e ne
mostrava solo l'ultimo. Ma *"condizione 48"* dopo essere stato a 30 e
*"condizione 48"* dopo essere stato a 65 sono la stessa riga e due situazioni
opposte: nella prima stai costruendo, nella seconda ti stai perdendo.

Adesso la schermata Forma mostra le due linee degli ultimi mesi. La spessa sale
piano e scende piano - quanto sei allenato. La sottile sale subito dopo una
seduta dura e scende in pochi giorni - la fatica. Quando la sottile sta sopra
per settimane, stai portando piu' carico di quanto il corpo riesca a trasformare
in allenamento.

Il punto delicato: **il grafico finisce esattamente sul numero scritto sopra**,
perche' e' lo stesso conto. `stateFor` non calcola piu' niente per conto suo, e'
l'ultimo punto di `seriesFor`. Un grafico che finisse da un'altra parte
costringerebbe l'utente a scegliere a quale dei due credere - ed e' la stessa
lezione del punto di partenza e dei record, imparata qui per la quarta volta.

Un'attenzione che si vede solo nel codice: chiedere trenta giorni mostra trenta
giorni ma **calcola dal primo allenamento**. Le medie esponenziali hanno memoria:
ripartire da zero un mese fa direbbe che un mese fa eri fermo anche se correvi da
due anni.

### Cosa e' gratis e cosa si paga

La divisione non e' "poco gratis per costringerti a pagare". E' l'opposto:
**tutto quello che fanno le altre app e' gratis per sempre**, e si paga solo
quello che le altre non hanno.

| Gratis, per sempre | Falcata completa |
|---|---|
| Registrare le corse, anche a schermo spento | Il piano di allenamento |
| Allenamenti a intervalli e coach vocale | Forma, passi e previsioni |
| Percorso e dislivello | Carico, fatica e prontezza |
| Record personali e statistiche | |

Chi scarica Falcata e la usa come app di corsa normale non incontra mai un muro.
Chi vuole essere allenato paga **una volta sola**, perche' l'abbonamento e' il
motivo per cui la gente non compra: chi corre tre volte a settimana e paga gia'
la palestra non aggiunge un'altra rata mensile, mentre venti euro una volta li
spende senza pensarci.

Una regola che non si rompe: **niente di gia' registrato si blocca mai.** Le
corse sono dell'atleta, non dell'app. Se il blocco scattasse sullo storico non
sarebbe un modello di vendita, sarebbe un ostaggio.

Il pagamento vero passa dal Play Store e richiede un account da sviluppatore,
che non c'e' ancora. Quello che c'e' da adesso e' la **struttura**: l'app sa
cosa e' gratis, sa cosa e' bloccato, e lo dice nel posto giusto. Quando ci sara'
l'account, cambia da dove arriva `LicenseState.isUnlocked` - una riga - invece
di dover rimettere mano a tutte le schermate. I testi per il negozio stanno in
`negozio/scheda-play-store.md`.

#### Da quanti km si parte

Il punto di partenza del piano si proponeva dalla media delle ultime quattro
settimane. Divideva per quattro anche con l'app installata da tre giorni: a un
atleta da 60 km a settimana ne proponeva **9**. E non e' un numero sbagliato
qualsiasi - da li' dipendono il volume di tutto il piano, la fase di partenza
(sotto i 45 km propone Costruzione) e quante ripetizioni entrano in una seduta.

Adesso la proposta guarda solo le **settimane intere** con delle corse dentro
(la settimana in corso e' incompleta per definizione, quindi non conta) e ne
prende la **mediana**, non la media: una settimana saltata per l'influenza o
per un turno pesante non deve abbassare il punto di partenza di tutto il piano.

Sotto le tre settimane utili l'app **non propone niente** e lo dice. Un archivio
corto non e' un archivio che dice numeri bassi: e' un archivio che non dice
niente, e tirare a indovinare al ribasso e' peggio che chiedere.

Lo stesso conto compariva anche in Home - *"sopra la tua media di 10,5 km"* a
un atleta che ne fa 60 - e adesso usa **la stessa identica funzione**, non una
copia. Due strade che calcolano la stessa cosa finiscono sempre per divergere:
e' gia' successo con il piano che leggeva un indice diverso da quello della
schermata Forma, e con il trofeo che non sapeva dei personali dichiarati.

#### Da dove parte il piano lo decidi tu

La Costruzione serve a costruire il motore aerobico e la tolleranza al volume.
Prima la sua lunghezza era una percentuale fissa: su dieci settimane, quattro
di Costruzione, sempre, che tu partissi da 25 km a settimana o da 60. E la
Costruzione prevede fartlek e allunghi, cioe' lavori che **per scelta** non
devono stancare. Per chi la base ce l'ha gia', e' un mese tolto al lavoro che
sposta i tempi.

Adesso, quando c'e' una gara, si sceglie da dove partire:

- **Costruzione** - si rientra, si viene da uno stop, o si vogliono rifare le
  fondamenta;
- **Sviluppo** - si corre gia' con continuita': si entra subito su soglia e
  ripetute;
- **Specifico** - si e' gia' in forma e manca poco: tutto sul passo di gara.

L'app propone (sopra i 45 km a settimana propone Sviluppo) ma non decide: i
chilometri dicono che la base **c'e' stata**, non che c'e' adesso - chi rientra
da uno stop ne faceva altrettanti prima.

Le settimane della Costruzione saltata non si perdono: diventano settimane di
Sviluppo. Saltare la base non accorcia il piano, lo riempie meglio.

#### Senza gara non ci sono fasi

Una fase e' un modo di distribuire il lavoro **verso una data**. Senza quella
data, "Costruzione" e "Sviluppo" sono due etichette. Quindi il piano "Restare
in forma" non ha fasi: tutte le settimane hanno la stessa struttura, e cambia
quello che deve cambiare davvero.

- **Cicli di quattro settimane.** Tre di carico allo stesso volume, una di
  scarico al 75%. Il ciclo dopo riparte **sopra** il precedente: +5% a ciclo,
  cioe' circa tre chilometri ogni quattro settimane per chi ne fa sessanta.
  Sembra poco, ed e' il punto: il volume che cresce in fretta e' quello che
  porta agli infortuni, e qui non c'e' nessuna data che costringa ad avere
  fretta.
- **I lavori ruotano.** Ogni terza settimana cambiano forma, non intensita':
  frazioni di soglia piu' lunghe allo stesso passo (2000 invece di 1600) e
  richiami brevi al posto dei mille. Ripetere le stesse due sedute per mesi
  smette di allenare molto prima che smetta di stancare.
- **Dura fino a un anno**, e la proposta di partenza e' sei mesi.

#### Quanta qualita' ci sta in una settimana

Prima le ripetizioni crescevano con il numero della settimana e si fermavano a
un numero scelto da me: cinque frazioni di soglia, sei ripetute. Arbitrario in
tutti e due i sensi - troppo per chi fa trenta chilometri, poco per chi ne fa
ottanta, e comunque fermo dopo due mesi.

Adesso il lavoro forte e' una quota del volume settimanale, come in Daniels:

| Lavoro | Quota massima del volume settimanale |
|---|---|
| Soglia | 10% |
| Ripetute (ritmo 3000) | 8% |
| Veloci (ritmo 1500) | 5% |

Le quote valgono sui metri di **lavoro**, recuperi esclusi. Cosi' l'intensita'
cresce da sola quando cresce il volume, e si ferma dove lo dice la fisiologia
invece che dove l'avevo messa io. A 73 km a settimana diventano circa 4 x 1600
di soglia, 5 x 1000 di ripetute, 9 x 400 di veloci.

Sopra le quote c'e' comunque il tetto del tempo: se la seduta non ci sta nei
minuti dichiarati, perde prima il contorno e poi le ripetizioni.

#### I ritmi seguono l'indice, ma solo se glielo chiedi

L'indice viene congelato alla creazione del piano apposta: se i ritmi
cambiassero a ogni corsa non si capirebbe piu' se stai migliorando o se e'
cambiato il metro di misura. Su dieci settimane e' giusto. Su un piano che dura
mesi e' l'errore opposto: dopo tre mesi ti allena ai ritmi di quando l'hai
creato, e diventa la cosa che ti frena.

La via di mezzo: quando l'indice si sposta di **almeno un punto** e la stima
non e' debole, in cima al piano compare una scheda - "adesso vali 47, il piano
e' costruito su 45,4" - con un pulsante per aggiornare. Il calendario non
cambia: stessi giorni, stesse settimane, stessa progressione. Cambiano i passi
e il numero di ripetizioni.

Non succede da solo di proposito. Un piano i cui ritmi si spostano alle spalle
dell'atleta e' un piano di cui non ci si fida.

I piani creati prima di questa impostazione non cambiano: senza tempi
dichiarati si ricade nello schema di prima (qualita' martedi' e giovedi', lungo
domenica).

Ogni seduta di qualita' non e' una descrizione ma un **allenamento vero**, con
riscaldamento, ripetizioni, recuperi e passi obiettivo: dal piano si preme
START e il motore esegue le fasi.

### Le gare nel mezzo

Se salta fuori una gara non prevista si aggiunge al piano e le settimane
intorno vengono ammorbidite: niente qualita' nei giorni prima, lungo
accorciato, e solo corsa lenta nei giorni dopo. Quanti giorni dipende dalla
distanza (3 prima e 6 dopo per una 10 km, 5 e 11 per una mezza), secondo la
regola classica di un giorno di recupero per miglio di gara, addolcita e
limitata a dodici giorni.

Il resto del piano non viene rifatto: le settimane lontane dalla gara restano
identiche. C'e' un test apposta per questo.

### Cosa viene salvato

Del piano si salvano solo i **parametri** (obiettivo, date, giorni, forma di
partenza, gare): le sedute vengono ricalcolate a ogni avvio. Un file di poche
righe invece di un centinaio di allenamenti serializzati, e nessuna doppia
versione della verita' da tenere in sincronia.

Il VDOT viene congelato alla creazione del piano di proposito: se cambiasse a
ogni corsa, i passi delle sedute ballerebbero da un giorno all'altro e non si
capirebbe piu' se stai migliorando o se e' cambiato il metro.

### Quello che il piano non puo' sapere

Se hai dormito male, se il ginocchio tira, se al lavoro e' una settimana
pesante. Un piano scritto un mese prima e' un'ipotesi: va corretto in corsa.
La parte che chiede come stai, e sposta la seduta di conseguenza, non c'e'
ancora.

---

## ADAPTIVE RUNNING COACH ENGINE

Il motore adattivo che sostituisce il generatore di piani statico. Viene
costruito per moduli: ogni rilascio e' compilabile, testabile e usabile da
solo.

### Stato dei moduli

| Modulo | Cosa fa | Stato |
|---|---|---|
| `AthleteProfile` | eta', esperienza, stop recenti, personali | fatto |
| `RunIndexEngine` | indice di forma con smoothing e confidenza | fatto |
| `PaceZoneEngine` | nove zone di allenamento come fasce | fatto |
| `SessionClassifier` | cosa e' stata **davvero** una seduta | fatto |
| Giorni e tempo disponibile | il calendario segue il tempo che hai | fatto |
| Raccolta fatica percepita | domanda a fine corsa | fatto |
| Check-in del mattino | sonno, gambe, voglia, dolore | fatto |
| `TrainingLoadEngine` | carico per intensita', non per chilometri | fatto |
| `FatigueEngine` / `ReadinessEngine` | fatica residua, prontezza 0-100 | fatto |
| `WorkoutDecisionEngine` | sceglie la seduta di oggi | da fare |
| `RiskEngine` | filtro di sicurezza prima di confermare | da fare |
| `AdaptationEngine` | impara dalla risposta individuale | da fare |

### Su cosa e' basato l'indice: l'elenco delle prove

Nella schermata Forma, sotto le previsioni, c'e' l'elenco delle prestazioni su
cui l'indice e' costruito: per ognuna il tempo, da dove viene (gara, test,
allenamento, tratto dentro una corsa, dichiarata a mano), quanto tempo fa, che
indice suggerirebbe **da sola**, e una barretta con il suo peso.

Perche' esiste: un numero senza le sue prove e' un oracolo, e un oracolo non si
puo' correggere. Se l'indice dice 45,4 e l'atleta pensa di valere 47, l'unica
domanda utile e' "su cosa ti stai basando?".

Toccando una riga si apre la corsa da cui viene, quando ce n'e' una: i personali
dichiarati a mano non hanno una corsa dietro. L'indice non e' la media di quei
numeri: e' dove sono arrivati, una conferma alla volta.

### Il principio che governa tutto: mai inventare un dato

Ogni stima importante e' un [`Estimate`](lib/models/estimate.dart): porta con
se' **valore, confidenza, fonte e data**. Se un dato non c'e', il campo e'
`null` e chi lo usa deve gestirlo. Non esistono valori di comodo.

La confidenza non e' decorativa: **cambia il comportamento del motore**. Con
pochi dati le fasce di ritmo si allargano, invece di fingere una precisione
che non c'e'. Si stringono da sole man mano che arrivano prestazioni.

### Il profilo: dire al motore quello che l'archivio non dimostra

Il motore sa solo quello che ha misurato. Se l'unica corsa registrata era
tranquilla, l'indice dice che l'atleta va piano, perche' piano ha corso: non
ha modo di sapere che e' capace di molto di piu'. Non lo inventa, e fa bene.

La schermata **Profilo e personali**
([`profile_screen.dart`](lib/screens/profile_screen.dart)) e' la via d'uscita.
L'atleta dichiara le sue prestazioni migliori - distanza, tempo, data, e se
erano in gara o in allenamento - e quelle entrano nel calcolo con il peso che
meritano: **1,00 se in gara, 0,85 se in test**, contro lo 0,45 di un tratto
veloce dentro una corsa normale. L'indice si aggiorna subito, senza aspettare
la prossima uscita.

La data conta davvero: un personale di un anno fa pesa poco, e un personale
senza data viene trattato come vecchio di un anno. Meglio prudenti che
ottimisti.

Nella stessa schermata ci sono eta', anni di corsa, giorni disponibili e stop
recenti. Quelli **non toccano i ritmi** - due persone con la stessa
prestazione si allenano agli stessi passi - ma decidono quanto in fretta
alzare il carico. Il profilo vive in `profile.json`, accanto agli altri dati.

### RunIndexEngine: l'indice di forma

Ogni prestazione viene convertita nell'indice che, da sola, suggerirebbe. Poi
le prestazioni vengono pesate su quattro fattori:

1. **da dove viene** - una gara vale piu' di un tratto veloce dentro una corsa
   normale (affidabilita' 1,00 contro 0,45);
2. **quanto ti e' costata** - una corsa dichiarata a fatica 3 pesa un decimo
   di una a fatica 9: stavi passeggiando, non dice niente su quanto vai forte;
3. **quanto e' vecchia** - il peso si dimezza ogni sei settimane;
4. **quanto e' lunga** - sotto 1,5 km non conta, sopra 3 km conta pieno.

La fusione e' un **filtro sequenziale**, non una media. Tre regole lo
governano:

- **si sale piu' facilmente di quanto si scenda.** Una prestazione eccellente
  prova cosa sai fare; una scarsa puo' essere caldo, stanchezza, una brutta
  giornata;
- **quanto l'indice segue una prestazione, e di quanto puo' spostarsi al
  massimo, dipendono da DOVE VIENE quella prestazione** (vedi sotto);
- **quattro conferme di fila valgono piu' di una**: il passo aumenta quando
  piu' prestazioni consecutive indicano la stessa direzione.

#### Il freno non e' uguale per tutti (e qui c'era un errore)

| fonte | quanto segue | spostamento massimo |
|---|---|---|
| gara | 0,90 | 10 punti |
| test / prova a cronometro | 0,80 | 6 punti |
| personale inserito a mano | 0,75 | 6 punti |
| seduta di qualita' | 0,62 | 2 punti |
| tratto veloce dentro una corsa | 0,55 | 1,2 punti |

La prima versione usava **0,55 e 1,5 punti per tutto**. Quei numeri erano
tarati sul caso difficile - un tratto veloce dentro una corsa normale, dove
non si sa se l'atleta stava spingendo o se era una discesa - e applicarli
anche alle gare e' stato un errore grosso.

Si e' visto al primo uso serio: un atleta ha dichiarato il suo **10 km in
44:00**, che vale indice **46,5**, e il motore si e' spostato da 36,2 a
**37,7**. Un punto e mezzo, il massimo consentito. Gli avrebbe fatto correre
il lento **quasi un minuto al chilometro piu' piano del dovuto**.

Due regole sbagliate, tutte e due corrette:

1. il motore moltiplicava ogni prestazione per la fatica dichiarata, e una
   gara senza RPE prendeva 0,60 invece di 1,00 - veniva penalizzata perche'
   nessuno le aveva chiesto se stava spingendo. **In gara si spinge per
   definizione**: ora la fatica percepita pesa solo dove l'impegno e' davvero
   ignoto (tratti e sedute);
2. il tetto di 1,5 punti serve contro il rumore, e **una gara non e' rumore**:
   e' la misura. Un allenatore che ti vede correre 44:00 non risponde
   "aspettiamo conferme", risponde "allora i tuoi ritmi sono questi".

Con le regole corrette, lo stesso atleta arriva a **45,4**: appena sotto quello
che la gara dice, perche' il motore resta prudente, non ottimista.

Una corsa e' **una** prova, non cinque: i tratti da 1,5 / 3 / 5 / 10 km dentro
la stessa uscita sono lo stesso sforzo guardato con lenti diverse, e vengono
uniti in uno solo.

L'indice **non scende mai perche' hai corso piano**. Scende solo per il
passare del tempo senza prove: quello e' decadimento vero, mentre "oggi ero
lento quindi sono peggiorato" non lo e'.

E lo stesso principio vale per la **fiducia**: una corsa tranquilla non
contraddice una gara, quindi non la abbassa. Prima bastava un'uscita lenta in
archivio per far crollare la fiducia in un 10 km corso in gara - la
confidenza diceva il contrario di quello che il motore dichiara altrove.

#### Un limite noto

Il filtro parte dalla prestazione piu' vecchia e la prende per buona qualunque
sia il suo peso. Conseguenza: **una gara di sei mesi fa continua a reggere
l'indice** finche' si continua a correre piano, perche' il decadimento scatta
solo quando non arriva nessuna prova, non quando non ne arriva una
significativa. La fiducia in quel caso resta bassa e le fasce larghe, quindi
il motore lo dichiara - ma il numero resta piu' alto di quanto meriti. Va
sistemato insieme al motore del carico, dove la distinzione fra "ho corso" e
"ho corso forte" esiste gia'.

### SessionClassifier: cosa e' stata davvero la seduta

Il programma dice "8 km facili". L'atleta li corre venticinque secondi al km
piu' veloce perche' si sentiva bene. Sulla carta e' stata una corsa facile;
nelle gambe e' stata una seduta scorrevole, e programmare ripetute il giorno
dopo significa programmarle su un corpo che non ha recuperato.

Il tracciato viene diviso in finestre di venti secondi, ogni finestra viene
assegnata a una zona, e la seduta viene classificata su quanto tempo e' stato
passato dove. Il confronto fra previsto ed effettivo produce una nota che il
motore usera' per decidere il giorno dopo.

#### Il rumore del GPS non e' allenamento

Un lento vero (parziali 5:27, 5:00, 5:20, 5:20, 5:25, 5:20, 5:24, 5:10, 5:30,
5:18) veniva riassunto cosi': "7 minuti a soglia o piu' veloce: seduta
impegnativa". Falso, e con conseguenze: il motore ci avrebbe costruito sopra il
giorno dopo.

Il conto: una finestra di venti secondi copre circa cento metri. Fra 5:00 e
4:34 al chilometro, su cento metri, ci sono **sei metri** di differenza. Il GPS
sbaglia di piu' di sei metri. Quindi su una corsa regolare qualche finestra
cade per caso nella soglia, e sommandole veniva fuori un lavoro mai fatto.

La correzione: il tempo di qualita' si conta solo a **blocchi continui di
almeno un minuto**. Il rumore e' sparso (una finestra qui, una la', mai tre di
fila), il lavoro e' continuo (un mille a 4:18 sono tredici finestre attaccate).
Le finestre restano di venti secondi, perche' servono per vedere le ripetute:
cambia solo come si sommano. Lo stesso conteggio a blocchi vale per la quota di
tempo "sopra il lento", che era il secondo modo di sbagliare: senza nessun
tratto di soglia, la seduta diventava "impegnativa" perche' il 52% delle
finestre cadeva nella zona del medio.

Conseguenza accettata: un 8x200 non conta come qualita', perche' duecento metri
veloci durano quaranta secondi. E' corretto - le ripetute brevi servono alla
meccanica di corsa e non devono stancare - ma e' una scelta, non un caso.
Un 10x400 invece conta, perche' un 400 dura piu' di un minuto.

### La corsa non si perde

Il difetto piu' grave possibile per un'app che vive sul telefono non e' un
numero sbagliato: e' il dato che non c'e' piu'. Una stima imprecisa si
corregge, una corsa persa no.

Fino alla 1.6 una corsa viveva solo nella memoria del processo. Se Android
chiudeva l'app - risparmio energetico, memoria finita, il gestore aggressivo di
Xiaomi o Huawei, un crash - sparivano un'ora e mezza di lavoro. Tre difese, in
ordine di importanza.

**1. Si scrive su disco mentre si corre.** Ogni quindici secondi la corsa
viene salvata in un file. Nel caso peggiore si perdono quindici secondi, non
tutto. Alla riapertura, se il file c'e', la Home propone di salvare quello che
era stato misurato.

Non si riprende a correre, e non e' pigrizia: fra l'uccisione e il riavvio
possono essere passate ore, e il cronometro non saprebbe cosa farne. Meglio
salvare con sicurezza quello che era stato misurato che ricostruire per finta
quello che non c'era nessuno a misurare.

E non si salva da soli: l'app mostra cosa ha trovato e lascia decidere.
Archiviare di nascosto una corsa che magari era un avvio per sbaglio
sporcherebbe l'archivio, che e' la base di ogni stima. Sotto i due minuti o i
duecento metri il file viene buttato senza nemmeno disturbare.

**2. Se il telefono smette di mandare posizioni, lo dice subito.** Dopo mezzo
minuto senza un punto compare un avviso rosso e il coach lo annuncia a voce.
Trenta secondi e' la soglia: sotto e' un sottopasso, sopra e' Android che ha
messo l'app a dormire.

Detto a fine corsa non serve a niente - i chilometri mancano e basta. Detto
mentre succede si puo' ancora rimediare, e almeno si sa che quel numero non e'
da credere.

**3. Si chiede l'esenzione dal risparmio energetico.** C'e' una schermata che
lo spiega, sotto Impostazioni -> Registrazione, e che si adatta alla marca del
telefono: su Xiaomi, Huawei, Oppo e altri l'esenzione standard di Android non
basta, perche' hanno un gestore loro con un'impostazione "avvio automatico" che
sta in un posto diverso per ognuno.

Le istruzioni nominano la voce precisa da cercare. Un consiglio generico
("controlla le impostazioni della batteria") non lo segue nessuno; uno che dice
dove toccare si segue in trenta secondi. **I nomi delle voci vanno verificati
sul campo**: cambiano fra versioni della stessa interfaccia, e stanno tutti in
`lib/utils/battery_advice.dart` per essere corretti in un posto solo.

### Il carico: quanto e' costata una seduta

Dieci chilometri lenti e dieci di ripetute sono la stessa riga sul diario e due
cose diverse nelle gambe. Contare i chilometri fa sembrare uguale una settimana
da 60 km tutti lenti e una da 60 km con due sedute dure dentro: la prima si
regge per mesi, la seconda ti rompe.

Il carico si misura in **sforzo**. Per ogni finestra del tracciato si guarda
quanto si andava forte rispetto al proprio passo di soglia, e il tempo viene
pesato per il **quadrato** di quel rapporto. Il quadrato non e' un'invenzione:
e' la forma con cui il costo di una corsa cresce rispetto alla velocita', la
stessa usata dal TSS di Coggan - il metodo piu' collaudato per misurare il
carico senza cardiofrequenzimetro.

L'unita' e' tarata cosi': **100 punti = un'ora esatta a ritmo soglia**. Un'ora
di lento ne fa circa 70, mezz'ora di ripetute circa 57 - meno tempo, piu'
carico, che e' esattamente quello che i chilometri non sanno dire.

C'e' un tetto all'intensita' di una singola finestra (1,35 volte il passo di
soglia). Serve perche' il quadrato amplifica gli errori grandi: senza il tetto,
un salto del GPS trasformerebbe un lento in una seduta durissima.

### Fatica e condizione: sette giorni contro ventotto

Due medie esponenziali del carico giornaliero:

- **fatica**, costante di 7 giorni: quanto sei stanco adesso;
- **condizione**, costante di 28 giorni: quanto sei allenato.

La differenza e' la **freschezza**, il loro rapporto dice se il carico sta
salendo piu' in fretta di quanto il corpo si adatti (sopra 1,3) o se si sta
scaricando (sotto 0,8).

Sono i valori del modello di Banister, che usa 7 e 42: qui il lungo e'
accorciato a 28 perche' un'app usata da chi corre da poco deve rispondere in un
mese, non in sei settimane, altrimenti per tutto il primo periodo racconta solo
che sei fermo.

Si cammina giorno per giorno, riposi compresi: e' nei giorni di riposo che la
fatica scende, e una media fatta solo sui giorni in cui hai corso direbbe che
sei sempre stanco uguale.

**Con meno di quattro settimane di storico il motore lo dice**, invece di dare
numeri che non significano niente.

### Il check-in del mattino

Tre domande - sonno, gambe, voglia - su una scala da 1 a 5, piu' il dolore.
Dieci secondi. Un questionario lungo si compila due volte e poi si salta, e un
dato mediocre raccolto tutti i giorni vale infinitamente piu' di un dato
perfetto raccolto tre volte.

Le gambe pesano doppio: si corre bene anche dopo una notte storta, molto meno
con le gambe piene.

### La prontezza: 0-100, con i motivi

Quattro voci: la freschezza (45%), il check-in (40%), quanto e' passato
dall'ultima seduta dura (15%), e il dolore - che non e' una percentuale.

Il numero **non compare mai da solo**: sotto c'e' sempre il primo motivo per
cui e' quello che e'. Un punteggio che non si puo' contestare e' un oracolo, e
un oracolo non si corregge.

Due difetti trovati su questa parte, e vale la pena raccontarli perche' sono
lo stesso errore visto da due lati.

Il primo l'hanno trovato i test: il recupero vale 1 quando non hai fatto niente
di duro di recente, e da solo portava il punteggio a **100 su 100** per chi
aveva appena installato l'app. Massima prontezza perche' non si sapeva niente.
Corretto mettendo un 55 fisso quando mancano sia la freschezza sia il check-in.

Il secondo si e' visto solo usando l'app. La card in Home diceva **55,
"Normale"**, e sotto come motivo principale *"ieri hai fatto una seduta di
qualita'"* - che era vero, ma con il 55 fisso quel fatto non aveva spostato il
numero di un punto. Una causa che non era una causa, cioe' esattamente il
difetto che tutto il resto dell'app esiste per non avere. E la risposta giusta
il giorno dopo un 5x1000 non e' "normale": e' **solo facile**.

Adesso, senza carico e senza check-in, si parte da 55 e l'unica cosa che puo'
muoverlo e' una seduta dura recente, che puo' solo abbassarlo. Il giorno dopo
le ripetute vengono 40, fascia "solo facile". Sapere che ieri hai tirato e'
poco, ma non e' niente.

### Le due reazioni immediate

Sulla scheda della seduta di oggi, in Home, prima che tu esca di casa:

- **dolore dichiarato** -> la qualita' non si fa. Non e' un consiglio.
- **prontezza bassa** su una seduta di qualita' -> sposta a domani e oggi corri
  facile. Un giorno di ritardo non cambia niente, una qualita' fatta male costa
  una settimana.

Su una seduta facile non si dice niente: un lento si corre anche stanchi, ed e'
anzi il modo giusto di passare una giornata storta. E il pulsante per partire
resta sempre: l'app dice quello che sa, l'ultima parola e' dell'atleta.

### Il dolore non e' un segnale come gli altri

Nel motore del rischio il dolore dichiarato **chiude la porta** alla
qualita': nessun punteggio lo puo' compensare. Un algoritmo che manda a fare
ripetute su un ginocchio che tira fa un danno che nessun guadagno di forma
ripaga.

### Le ripetute contano

L'indice cerca tratti **continui** da 1500 metri in su. In una seduta a
intervalli ogni tratto abbastanza lungo si porta dentro i recuperi, quindi il
passo esce lento e viene buttato via; e una singola ripetuta da 1000 metri sta
sotto il minimo. Risultato: un **6x1000 a 4:18** - che e' una prova seria -
non contava niente. I parziali venivano salvati, mostrati in tabella, e poi
ignorati dal motore.

Non si puo' pero' prendere una ripetuta da 1000 in 4:18 e trattarla come una
gara sui 1000: con il recupero in mezzo si va piu' forte di quanto si andrebbe
di fila, e l'indice uscirebbe gonfiato.

La conversione usa una **definizione**, non una costante inventata: il ritmo
ripetute e', per definizione, il ritmo di gara sui 3000 metri. Quindi una
serie tenuta a ritmo costante, con almeno **1800 metri di lavoro vero**, dice
che quel passo e' il passo da 3000 dell'atleta, e viene riportata li'.

| serie | equivalente | indice |
|---|---|---|
| 6x1000 a 4:18 | 3000 in 12:54 | 44,1 |
| 4x1000 a 4:10 | 3000 in 12:30 | 45,7 |
| 8x800 a 4:05 | 3000 in 12:15 | 46,7 |
| 10x400 a 3:50 | — | scartata |

Le condizioni, tutte necessarie: almeno **due** ripetute (un episodio non fa
una serie), ognuna fra **due e sei minuti**, e uno scarto di passo fra la piu'
veloce e la piu' lenta **entro il 12%** - oltre, e' un progressivo e la media
non significa niente.

I due limiti di durata hanno ognuno la sua storia, e sono due errori trovati
prima di spedirli:

- **sotto i due minuti** le ripetute si corrono a ritmo velocita', non a ritmo
  3000. Un 10x400 riportato ai 3000 gonfiava l'indice di sei punti;
- **sopra i sei minuti** non sono piu' ripetute. E' venuto fuori da una
  domanda: *"2 per 15 minuti come ripetute possono andare?"*. No - e non
  perche' sia una brutta seduta, ma perche' quindici minuti a ritmo 3000 non
  esistono: quel ritmo si tiene per dodici minuti in tutto, in gara. Un 2x15
  e' lavoro di **soglia**, e la vecchia regola lo leggeva come ritmo 3000
  ricavandone indice 41 invece di 45: una seduta fatta bene **abbassava** la
  stima.

#### E le frazioni lunghe sono soglia

Per le frazioni oltre i sei minuti la conversione e' un'altra, e anche questa
e' una definizione e non un'invenzione: il **ritmo soglia** e' il ritmo che si
terrebbe per **un'ora esatta**. Quindi da mezz'ora di lavoro a quel ritmo si
ricava direttamente la distanza che l'atleta coprirebbe in un'ora.

| seduta | equivalente | indice |
|---|---|---|
| 2x15 min a 4:34 | 13.136 m in un'ora | 45,4 |
| 30 min di fila a 4:34 | 13.136 m in un'ora | 45,4 |
| 8 min a 4:34 | — | scartata (troppo poco) |

Servono almeno **venti minuti** di lavoro complessivo. Non serve che siano
frazionati: trenta minuti di fila a ritmo soglia sono la prova piu' pulita che
esista per quel ritmo.

Una seduta **mista** - ripetute corte piu' un blocco lungo - non viene
convertita: non e' ne' l'una ne' l'altra cosa, e indovinare sarebbe peggio che
tacere.

Pesa **0,65**, come seduta di allenamento: piu' di un tratto dentro una corsa
normale, meno di una gara.

Per riconoscere le ripetute senza dipendere dalla parola "Ripetuta", ogni
parziale porta con se' il **tipo** della fase in forma non traducibile
(`interval`, `recovery`, ...) accanto all'etichetta leggibile. Cercare la
stringa italiana si sarebbe rotto alla prima traduzione.

### Un record e' un record se batte quello che sai di aver fatto

Un'uscita da 13,5 km a 5:33 si e' presa il trofeo **"Record personale 10 km
54:44"** da un atleta che nel profilo ha dichiarato un 10 km in **44:00** - lo
stesso numero su cui il motore di forma costruisce tutto l'indice.

Due parti della stessa app che si contraddicono, e quella che si vede e' quella
sbagliata. Il calcolo dei record guardava solo lo storico registrato col GPS e
non sapeva niente dei personali dichiarati a mano.

Adesso il trofeo sull'attivita' non compare per una distanza su cui hai
dichiarato un tempo piu' veloce, e nella schermata Record quella riga mostra il
tempo dichiarato come primato, con sotto il migliore **registrato con l'app** -
che resta un'informazione utile, ma non e' il tuo record.

E' lo stesso difetto gia' incontrato con il piano che leggeva un indice diverso
da quello della schermata Forma: due strade che calcolano la stessa cosa
finiscono sempre per divergere. Dove si puo', deve esserci una strada sola.

### Gara o test, dichiarati sull'attivita'

C'era un'assurdita': una gara **corsa con l'app** valeva 0,45, mentre la
stessa gara **digitata a mano** nel profilo valeva 1,00. Il dato misurato dal
GPS contava meno di quello battuto sulla tastiera.

Adesso dal dettaglio di un'attivita' si puo' dichiarare che era una **gara**
(1,00) o un **test** (0,85). E' una dichiarazione, non una deduzione: una
corsa tirata puo' essere una gara o solo una giornata buona, e la differenza
la sa solo chi l'ha corsa. Per le uscite dichiarate entra nel conto anche la
**distanza intera**, non solo i tratti standard: una 12 km di gara altrimenti
andrebbe persa.

## Chilometri o miglia

L'interruttore esisteva nelle impostazioni fin dall'inizio e veniva pure
salvato, ma **non lo leggeva nessuno**: si poteva scegliere "Imperiale" e
l'app continuava tranquillamente a scrivere chilometri.

Ora funziona, e la scelta si fa al **primo avvio** insieme al nome - vedere le
distanze nell'unita' sbagliata fa sembrare l'app rotta prima ancora di aver
corso.

La regola che non si tocca: **dentro l'app tutto resta in metri e in secondi
al chilometro**. Il GPS misura in metri, lo storico e' salvato in metri, il
motore ragiona in metri. Le miglia esistono solo nell'ultimo centimetro,
quando un numero viene scritto sullo schermo o detto ad alta voce. E' il
motivo per cui si puo' cambiare unita' quando si vuole senza rovinare niente:
se l'unita' finisse dentro i file, il primo cambio trasformerebbe dieci
chilometri in dieci miglia e lo storico sarebbe da buttare.

Le distanze corte restano in **metri** in tutti e due i sistemi: in pista si
corrono i 400, non le 437 iarde, ed e' metrico anche negli Stati Uniti.

La conversione vive in [`lib/utils/units.dart`](lib/utils/units.dart). L'unita'
attiva e' una variabile di modulo e non un parametro passato a mano in tutti e
57 i punti che formattano numeri: 57 punti sono 57 occasioni di dimenticarsene,
e una dimenticanza non darebbe errore, darebbe solo un numero sbagliato - il
tipo di bug peggiore. Chi vuole essere esplicito, i test per primi, puo'
sempre passarla come parametro.

## La lingua, piu' avanti

Le frasi italiane scritte dentro il codice sono **oltre mille, in 54 file**.
Tradurle adesso vorrebbe dire scriverle due volte, perche' le frasi del motore
adattivo - quelle che spiegheranno *perche'* propone un allenamento - non
esistono ancora.

Quindi si traduce alla fine. Per evitare che quel giorno diventi una caccia al
tesoro, c'e' [`tool/estrai_frasi.py`](tool/estrai_frasi.py): produce l'elenco
completo con file, riga e testo, in un colpo solo. Non c'e' niente da tenere
aggiornato a mano.

La convenzione intanto e' una sola, e vale da subito: **mai costruire una
frase incollando pezzi**.

```dart
'Calcolato su ' + n + ' prestazioni'   // NO: altrove l'ordine cambia
'Calcolato su $n prestazioni'          // SI: e' una frase sola
```

### Valori empirici

Tutte le costanti tarabili sono raccolte in cima ai rispettivi motori e
marcate `VALORI EMPIRICI, TARABILI`, con accanto il ragionamento che le
giustifica. Sono volutamente prudenti: sbagliare per eccesso di cautela costa
qualche settimana, sbagliare per eccesso di entusiasmo costa un infortunio.

### Test

Gli scenari della specifica sono test veri:

| Scenario | Test |
|---|---|
| D - miglioramento costante | l'indice sale, e piu' di un picco isolato |
| E - singola prestazione eccezionale | il salto resta sotto 1,2 punti |
| F - facile corso troppo forte | riclassificato, e l'indice non si muove |
| L - nessun sensore | tutto il motore gira su passo, distanza e fatica |

---

## La cadenza

La cadenza e' quanti appoggi al minuto: piede destro, piede sinistro, due
passi. Un adulto che corre sta in genere fra i 150 e i 180.

**Non dice se si va forte.** Dice *come* si corre. Due persone allo stesso
passo, una a 155 e una a 175, stanno facendo due cose diverse: la prima fa
falcate piu' lunghe e sta piu' tempo in aria, la seconda appoggi piu' brevi e
piu' frequenti. Non c'e' un numero giusto - c'e' il tuo.

Quello che vale la pena guardare e' la **costanza**. La cadenza di una persona
e' abbastanza sua e cambia poco fra lento e medio; quando crolla negli ultimi
chilometri di un lungo, quello e' il segnale che l'appoggio si e' sfasciato per
la stanchezza. E si vede nel grafico **prima** che si veda nel passo, perche' il
passo lo si tiene a forza di volonta' e la cadenza no.

### Perche' i passi li conta il telefono

Perche' e' l'unica misura di questa app che il GPS non puo' sbagliare: il GPS
non la fa. I passi li contano gli accelerometri dentro al telefono, e li tiene
il chip dei sensori - non la CPU. Niente satelliti, niente palazzi, niente
alberi.

Due sensori Android fanno questo lavoro e la scelta fra i due non e' un
dettaglio:

| Sensore | Come funziona | Perche' |
|---|---|---|
| `TYPE_STEP_COUNTER` | totale cumulativo dall'accensione, tenuto dal chip | **si usa questo**: continua a contare anche mentre Android dorme, e quando l'evento arriva in ritardo il valore e' comunque giusto |
| `TYPE_STEP_DETECTOR` | un evento per ogni passo | ripiego, solo sui telefoni senza contatore: i passi fatti mentre il processo era sospeso li perde |

Rifare il conteggio in Dart vorrebbe dire leggere l'accelerometro cinquanta
volte al secondo per un'ora, filtrare, cercare i picchi - cioe' tenere sveglia
la CPU per riprodurre peggio una cosa che il telefono fa in hardware
consumando niente. Ed e' la stessa app che ha una schermata intera dedicata al
risparmio energetico.

### Perche' i passi sono salvati cumulativi

Nel tracciato ogni punto porta **quanti passi dall'inizio**
([`RoutePoint.steps`](lib/models/running_activity.dart)), non "quanti passi in
questo tratto". E' la scelta da cui dipende tutto il resto.

Un totale che cresce si ricuce da solo: la cadenza fra due punti qualsiasi e'
la differenza divisa per il tempo, e **se manca un punto in mezzo la differenza
fra quello prima e quello dopo e' ancora giusta**. Con "i passi di questo
tratto", invece, unire due tratti vorrebbe dire sommarli, e un punto perso li
perderebbe per sempre.

Questo conta davvero, perche' il grafico deve ridurre centocinquanta finestre a
settanta punti per starci nello schermo: unire e' la cosa che fa sempre, non un
caso limite.

L'unico posto dove un buco pesa e' quando cade **sul bordo** di una finestra:
li' la cadenza di quella finestra non si sa, e resta un buco nella linea. La
regola, in [`RunProfile`](lib/services/run_profile.dart), e' che un gruppo con un
buco dentro non ha cadenza: sommare solo le finestre buone darebbe "meno passi
nello stesso tempo", cioe' una cadenza crollata che non e' mai esistita - un
grafico piu' bello e un dato falso.

### Quanto ci si puo' fidare

Il contapassi di un telefono e' bravo ma non perfetto: tende a contarne
qualcuno **in meno**, e quanto in meno dipende da dove tieni il telefono - in
mano, in tasca, in fascia da braccio. Quindi 168 va letto come "fra 165 e 172",
e confrontato **con le tue altre corse**, non con il numero dell'orologio di un
altro. L'app lo scrive sotto il riquadro, invece di far finta che sia una misura
esatta.

I limiti del verosimile stanno in [`lib/services/cadence.dart`](lib/services/cadence.dart),
in un posto solo: sotto 100 passi al minuto non e' una corsa (e' una camminata,
o il sensore che ha perso dei pezzi), sopra 240 non e' un essere umano (e' il
telefono che sbatte in uno zaino e conta le buche). Fuori da quella forbice non
esce un numero sbagliato: non esce niente.

### Il permesso, e quando si chiede

Da Android 10 leggere il sensore dei passi richiede `ACTIVITY_RECOGNITION`.
Non da' accesso a nient'altro: non alla posizione, non alla salute, non allo
storico attivita' di Google.

Si chiede **aprendo la schermata corsa**, mentre si aspetta il segnale GPS - non
allo START. Una finestra di sistema che compare nell'istante in cui si schiaccia
START arriva sopra una corsa gia' partita: la si chiude di fretta, senza
leggerla, e spesso la si chiude col "no". Chi sta fermo ad aspettare i satelliti
invece ha il tempo di guardarla.

Se il permesso e' negato, o il telefono non ha il sensore, o la corsa e' stata
registrata prima della 2.5.0, non compare nessun riquadro vuoto e nessun "--":
semplicemente la cadenza non c'e', e tutto il resto funziona identico.

### Il sensore si stacca

Un ascoltatore di sensore lasciato aperto consuma batteria anche con l'app
chiusa. Viene staccato in tutti i modi in cui una corsa puo' finire - stop,
annullo, chiusura della schermata, `onDestroy` dell'Activity - perche' basta
una strada dimenticata per avere esattamente il difetto che questa app passa il
tempo a evitare.

---

## Funzioni predisposte per il futuro

Il modello dati e' gia' pronto, ma **nessun valore viene inventato o stimato**:
i campi restano `null` finche' non ci sara' una sorgente reale.

- Frequenza cardiaca: `heartRateAverage`, `heartRateMax`, `heartRateSamples`.
- HRV: `rmssd`, `sdnn`, `restingHeartRate` (`HrvData`).
- Sonno: durata, sonno profondo, REM, veglia, punteggio (`SleepData`).
- Dinamiche di corsa: `strideLengthMeters`, `verticalOscillationCm`,
  `groundContactTimeMs` (`RunningDynamics`). La **cadenza** non e' piu' fra
  queste: dalla 2.5.0 viene misurata davvero, vedi "La cadenza" sotto.
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
