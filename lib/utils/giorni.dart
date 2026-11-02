/// I giorni di calendario, contati senza sbagliare al cambio dell'ora.
///
/// PERCHE' ESISTE QUESTO FILE
/// --------------------------
/// Domenica 25 ottobre 2026 e' durata 25 ore. Tutto il codice che faceva
/// "mezzanotte + 24 ore" per passare al giorno dopo, da quel momento si e'
/// trovato alle 23:00 del giorno prima. E nessun test se n'era accorto, perche'
/// i test girano su un server con l'ora di Greenwich, che l'ora legale non ce
/// l'ha.
///
/// Le conseguenze, viste sul telefono:
///
///  - il grafico di fatica e condizione cercava il carico di "25 ottobre ore
///    23" invece che di "26 ottobre": non lo trovava, e da lunedi' in poi
///    tutte le corse risultavano zero. La fatica scendeva in una settimana da
///    48 km;
///  - le barre del volume erano spostate di una settimana: la settimana
///    scorsa vuota, i suoi 57 km sotto la settimana prima;
///  - "questa settimana sei 25% sotto la media", con una media fatta su tre
///    settimane invece che su quattro.
///
/// La regola, da qui in avanti: **i giorni si contano con il calendario, mai
/// con le ore**. `DateTime(anno, mese, giorno + 1)` e' il giorno dopo anche
/// quando quel giorno dura 23 o 25 ore; `data.add(Duration(days: 1))` no.
library;

/// Mezzanotte del giorno di [data], nell'ora locale.
DateTime soloGiorno(DateTime data) =>
    DateTime(data.year, data.month, data.day);

/// Il giorno che sta [giorni] giorni dopo [data] (prima, se negativo), a
/// mezzanotte. Al posto di `data.add(Duration(days: n))`.
DateTime piuGiorni(DateTime data, int giorni) =>
    DateTime(data.year, data.month, data.day + giorni);

/// Quanti giorni di calendario da [da] ad [a]: 1 se [a] e' il giorno dopo,
/// qualunque ora sia. Negativo se [a] viene prima.
///
/// Il conto si fa in UTC, dove ogni giorno ha 24 ore esatte: cosi' il cambio
/// dell'ora non puo' togliere o aggiungere niente.
int giorniFra(DateTime da, DateTime a) =>
    DateTime.utc(a.year, a.month, a.day)
        .difference(DateTime.utc(da.year, da.month, da.day))
        .inDays;
