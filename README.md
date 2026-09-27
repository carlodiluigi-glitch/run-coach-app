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
│   │   ├── plan_provider.dart       # piano attivo
│   │   └── running_provider.dart    # timer, distanza, lap, coach
│   ├── screens/
│   │   ├── splash_screen.dart       # apertura: nome app e saluto
│   │   ├── fitness_screen.dart      # forma, passi, previsioni
│   │   ├── plan_screen.dart         # il piano attivo
│   │   ├── plan_setup_screen.dart   # creazione del piano
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

Schema settimanale fisso, perche' un piano si segue solo se e' prevedibile:
qualita' il martedi' e il giovedi', lungo la domenica, il resto lento.

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
| Raccolta fatica percepita | domanda a fine corsa | fatto |
| `TrainingLoadEngine` | carico per intensita', non per chilometri | da fare |
| `FatigueEngine` / `ReadinessEngine` | fatica residua, prontezza 0-100 | da fare |
| `WorkoutDecisionEngine` | sceglie la seduta di oggi | da fare |
| `RiskEngine` | filtro di sicurezza prima di confermare | da fare |
| `AdaptationEngine` | impara dalla risposta individuale | da fare |

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

### Il dolore non e' un segnale come gli altri

Nel motore del rischio il dolore dichiarato **chiude la porta** alla
qualita': nessun punteggio lo puo' compensare. Un algoritmo che manda a fare
ripetute su un ginocchio che tira fa un danno che nessun guadagno di forma
ripaga.

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
