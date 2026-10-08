# La chiave di caricamento del Play Store

## Cos'e', e perche' non e' "la" chiave dell'app

Sul Play Store ci sono **due** chiavi, e confonderle e' il modo piu' comune di
mettersi nei guai.

| | chi la tiene | se si perde |
|---|---|---|
| **Chiave dell'app** (app signing key) | **Google**, con Play App Signing | niente, la tiene Google |
| **Chiave di caricamento** (upload key) | tu | Google te la resetta |

Questa e' la **seconda**. Serve solo a dire a Google "sono io che sto
caricando". Ed e' il motivo per cui si puo' generare senza drammi: se un giorno
finisce nelle mani sbagliate o va persa, si chiede a Google di sostituirla e
l'app resta tua.

## Quella che gia' c'e' nel repository non va toccata

In `android/app/runcoach-release.jks` c'e' un'altra chiave, con la password in
chiaro dentro `android/key.properties`. **Deve restare li' com'e'**: e' quella
che firma l'APK che si installa a mano. Cambiarla farebbe rifiutare ad Android
ogni aggiornamento sopra l'installazione esistente, e si perderebbero tutte le
corse registrate.

Quindi, da adesso, la stessa build produce due pacchetti firmati in modo
diverso:

- `app-release.apk` - chiave vecchia, si installa sopra quella che hai;
- `app-release.aab` - chiave di caricamento, va in Play Console.

## I due secret da mettere su GitHub

Si mettono una volta sola, in **Settings -> Secrets and variables -> Actions ->
New repository secret**.

| Nome del secret | Contenuto |
|---|---|
| `FALCATA_UPLOAD_KEYSTORE_BASE64` | tutto il testo del file `falcata-upload-base64.txt` |
| `FALCATA_UPLOAD_PASSWORD` | la password della chiave |

I secret non si rileggono: GitHub li mostra solo come pallini. Se si perdono si
rifanno, ma la password va conservata **anche altrove**.

## Dove tenere il file della chiave

Il file `falcata-upload.jks` non va nel repository. Va conservato in almeno due
posti che non siano lo stesso computer - per esempio una chiavetta e un servizio
cloud - insieme alla password.

Non e' drammatico come perdere la chiave dell'app (quella la tiene Google), ma
perderla significa comunque una pratica di reset prima di poter pubblicare un
aggiornamento.

## Come si verifica che abbia funzionato

Dopo aver messo i due secret, al primo `AGGIORNA.bat` la build fa un passo in
piu': **"Pacchetto per il Play Store"**. In fondo alla pagina della build
compare un file scaricabile chiamato `Falcata-PlayStore-aab`: quello e' il
pacchetto da caricare in Play Console.

Senza i secret quel passo si salta da solo e la build resta identica a prima.
