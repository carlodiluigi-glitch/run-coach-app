# Falcata — scheda per il Play Store

Testi pronti da incollare nella Google Play Console. I limiti di caratteri sono
quelli veri di Google: se si supera, la console rifiuta.

Il tono segue una regola sola: **dire cosa fa, non quanto è bella.** Chi cerca
un'app di corsa ne ha già provate tre gratis. Non la convince un aggettivo, la
convince una frase che descrive un problema che ha davvero.

---

## Nome dell'app (30 caratteri)

```
Falcata — allenamento corsa
```

27 caratteri. "Allenamento" e "corsa" sono le due parole con cui la gente cerca,
e nel nome contano più che altrove.

---

## Descrizione breve (80 caratteri)

```
Il piano di allenamento si scrive sui giorni e sul tempo che hai davvero.
```

72 caratteri. È la frase che compare sotto l'icona nei risultati di ricerca,
quindi deve contenere la differenza, non il genere: "app per correre col GPS"
sarebbe sprecata, lo sono tutte.

---

## Descrizione completa (4000 caratteri)

```
Falcata è un allenatore di corsa che funziona con il telefono che hai già.
Niente orologio da comprare, niente abbonamento, niente account.

IL PIANO SI SCRIVE SULLA TUA SETTIMANA, NON SU UNA SETTIMANA TIPO

Quasi tutti i piani di allenamento sono scritti per chi ha il fine settimana
libero: qualità il martedì e il giovedì, lungo la domenica. Chi lavora nella
ristorazione, nella sanità o su turni ha la settimana esattamente al contrario.

In Falcata dici quanti minuti hai, giorno per giorno. Da lì il piano decide:
il lungo va dove hai più tempo, la qualità non cade mai il giorno prima del
lungo né due volte di fila, e nessuna seduta chiede più tempo di quello che
hai. Se questa settimana i turni cambiano, cambi i giorni di quella settimana
sola: le altre non si muovono.

I PASSI VENGONO DALLA TUA FORMA DI ADESSO

Falcata guarda le corse che hai registrato e ricava quanto vali oggi. Da quel
numero escono i passi di ogni seduta — lento, soglia, ripetute — e le
previsioni su 5 km, 10 km, mezza e maratona. Non percentuali inventate: il
metodo è quello di Daniels, lo stesso usato dagli allenatori.

E dice sempre su cosa si è basato: quali corse, quanto se ne fida, e quando
non ha abbastanza dati per dire niente lo dice invece di tirare a indovinare.

QUANTO TI STAI CARICANDO

Dieci chilometri lenti e dieci di ripetute sono la stessa riga sul diario e due
cose diverse nelle gambe. Falcata misura lo sforzo, non i chilometri: quanto ti
è costata una seduta, quanta fatica hai ancora addosso, quanto sei allenato, e
se stai caricando più in fretta di quanto il corpo si adatti.

La mattina ti chiede come hai dormito e come hai le gambe, e con quello ti dice
se oggi conviene tirare o restare piano. Un grafico degli ultimi mesi fa vedere
se stai costruendo o se ti stai consumando.

LA CORSA NON SI PERDE

La causa numero uno delle corse perse a metà non è il GPS: è Android che chiude
le app per risparmiare batteria. Falcata scrive la corsa su disco ogni quindici
secondi, quindi anche se il telefono la chiude non perdi niente. E se il
segnale sparisce per più di mezzo minuto te lo dice mentre corri, a voce, non a
fine corsa quando non si può più rimediare.

C'è anche una guida che spiega, marca per marca, dove sta l'impostazione da
cambiare: su Xiaomi, Huawei, Samsung e Oppo si chiama in modo diverso e sta in
un posto diverso.

COSA C'È DENTRO

• Registrazione GPS con schermo spento, giri automatici, coach vocale
• Allenamenti a intervalli guidati a voce, con il passo obiettivo
• Il percorso disegnato e il dislivello, senza mappe e senza connessione
• Record personali su ogni distanza, e le statistiche del mese
• Piano di allenamento con fasi, scarichi e gare in calendario
• Indice di forma, passi di allenamento, previsioni di gara
• Carico, fatica, condizione, prontezza del mattino
• Gestione delle scarpe e dei chilometri che hanno fatto
• Chilometri o miglia

GRATIS E A PAGAMENTO

Registrare le corse, gli allenamenti a intervalli, il coach vocale, i record,
le statistiche, il percorso e il dislivello sono gratis e restano gratis.

Il piano di allenamento, i passi calcolati sulla tua forma e il motore del
carico si sbloccano con un acquisto unico. Una volta sola, non un abbonamento.

I TUOI DATI RESTANO SUL TUO TELEFONO

Nessun account, nessun server, nessuna registrazione. Le corse stanno nella
memoria del telefono e non vengono mandate da nessuna parte. Falcata funziona
in aereo.
```

Circa 3.200 caratteri: sotto il limite, con spazio per aggiungere.

---

## Le immagini (screenshot)

Google ne vuole da 2 a 8, almeno 320 px di lato corto. Vanno fatte **in questo
ordine**, perché quasi nessuno scorre oltre la terza:

| # | Schermata | Cosa deve far capire in due secondi |
|---|---|---|
| 1 | Nuovo piano, con i giorni e i minuti | È qui che Falcata è diversa |
| 2 | Una settimana del piano | Il lungo non è di domenica, è dove c'è tempo |
| 3 | Forma, con il grafico degli ultimi mesi | Sa qualcosa che le app gratis non sanno |
| 4 | Corsa in corso | Fa anche il mestiere normale, e lo fa bene |
| 5 | Dettaglio corsa con percorso e dislivello | — |
| 6 | Prontezza del mattino | — |

Su ogni immagine va una riga di testo sopra, grande, che dica la cosa — chi
guarda legge quella, non l'interfaccia.

---

## Categoria e classificazione

- **Categoria**: Salute e fitness
- **Contenuti**: per tutti
- **Pubblicità**: nessuna (da dichiarare, è un punto a favore)
- **Acquisti in-app**: sì, uno solo, non ricorrente

---

## Dichiarazione sulla privacy (Data safety)

È la sezione in cui Google chiede cosa raccoglie l'app. Per Falcata la risposta
è la stessa ovunque, e va detta chiaramente perché è un argomento di vendita:

- Dati raccolti: **nessuno**
- Dati condivisi con terzi: **nessuno**
- Posizione: usata solo sul dispositivo, mai trasmessa
- Account: non richiesto

Serve comunque una pagina web con l'informativa privacy: Google la pretende
anche quando non si raccoglie niente. Una pagina sola, può stare su GitHub
Pages.

---

## Prima di pubblicare, da fare

1. **Account sviluppatore Google Play** — 25 dollari una volta sola.
2. **Chiave di firma permanente** — il progetto la prevede già
   (`key.properties`): va generata e **conservata**. Se si perde, l'app non è
   più aggiornabile e va ripubblicata da zero con un altro nome.
3. **Informativa privacy** su una pagina web raggiungibile.
4. **Verificare sul campo le istruzioni batteria** marca per marca: sono
   scritte a tavolino e non ancora viste su uno schermo vero.
5. **Prodotto in-app** configurato nella console, e poi collegato al posto di
   `LicenseState.developerUnlocked`.
