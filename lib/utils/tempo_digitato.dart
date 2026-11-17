/// Lettura di un tempo scritto a mano, come "44:30" o "1:42:05".
///
/// Serve alla guida, dove il tempo si scrive in un campo solo invece che in
/// tre caselle ore/minuti/secondi: e' come lo si dice a voce ("ho fatto i 10
/// in 44 e 30") e si scrive piu' in fretta.
///
/// Accetta:
/// - "mm:ss" (44:30), anche con piu' di 59 minuti (95:10 = 1:35:10);
/// - "h:mm:ss" (1:42:05);
/// - il punto o la virgola al posto dei due punti (44.30, 44,30), perche' sul
///   tastierino numerico i due punti spesso non ci sono;
/// - un numero solo, letto come minuti interi (45 = 45:00).
///
/// Rifiuta (restituisce `null`) tutto il resto, compresi secondi oltre 59:
/// "44:75" e' quasi certamente un errore di battitura, e un tempo sbagliato
/// fa sbagliare tutti i ritmi del piano.
int? secondiDaTesto(String testo) {
  final String pulito = testo.trim().replaceAll(RegExp(r'[.,]'), ':');
  if (pulito.isEmpty) return null;
  final List<String> parti = pulito.split(':');
  if (parti.length > 3) return null;
  final List<int> numeri = <int>[];
  for (final String parte in parti) {
    if (parte.isEmpty || !RegExp(r'^\d+$').hasMatch(parte)) return null;
    numeri.add(int.parse(parte));
  }
  switch (numeri.length) {
    case 1:
      return numeri[0] > 0 ? numeri[0] * 60 : null;
    case 2:
      if (numeri[1] > 59) return null;
      final int totale = numeri[0] * 60 + numeri[1];
      return totale > 0 ? totale : null;
    default:
      if (numeri[1] > 59 || numeri[2] > 59) return null;
      final int totale = numeri[0] * 3600 + numeri[1] * 60 + numeri[2];
      return totale > 0 ? totale : null;
  }
}

/// Il problema di un tempo su una distanza, o `null` se e' credibile.
///
/// Stessi limiti della scheda dei personali nel profilo: piu' veloce di
/// 2:10 al km non lo corre nessuno, piu' lento di 20:00 al km e' camminare.
String? problemaTempo(double metri, int? secondi) {
  if (secondi == null || secondi <= 0) {
    return 'Scrivilo come minuti:secondi, per esempio 44:30.';
  }
  final double passo = secondi / (metri / 1000.0);
  if (passo < 130) {
    return 'Troppo veloce per essere vero: ricontrolla minuti e secondi.';
  }
  if (passo > 1200) {
    return 'Troppo lento: sicuro che sia quella la distanza?';
  }
  return null;
}

/// Un peso scritto a mano, in chili. Accetta la virgola ("72,5").
///
/// `null` se vuoto o fuori dai limiti che usano le calorie (30-250 kg).
double? chiliDaTesto(String testo) {
  final String pulito = testo.trim().replaceAll(',', '.');
  if (pulito.isEmpty) return null;
  final double? valore = double.tryParse(pulito);
  if (valore == null || valore < 30 || valore > 250) return null;
  return valore;
}
