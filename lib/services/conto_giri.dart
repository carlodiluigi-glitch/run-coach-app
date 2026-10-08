/// Il punto a cui e' arrivato il giro in corso: metri e secondi gia' chiusi.
///
/// PERCHE' ESISTE UN FILE PER DUE NUMERI
/// -------------------------------------
/// Perche' quei due numeri erano due variabili sciolte dentro il motore della
/// corsa, e **sono stati persi**. In un rilascio, riscrivendo il pezzo che
/// chiude un giro per aggiungerci la cadenza, le due righe che spostavano il
/// riferimento sono sparite nel rimpasto. Il risultato, su una corsa vera:
///
///   Giro 1 - 1.00 km - 5:44
///   Giro 2 - 1.00 km - 5:44
///   Giro 3 - 1.00 km - 5:44   ... fino al decimo, tutti insieme, allo scoccare
///                                 del primo chilometro
///
/// Il motivo e' tutto qui: se il riferimento non si sposta, i metri del giro
/// restano sopra il chilometro per sempre, e il controllo del giro automatico
/// continua a chiuderne uno dopo l'altro finche' non sbatte contro il suo
/// limite di sicurezza. Tutti con lo stesso tempo, perche' nessun tempo e'
/// passato fra il primo e il decimo.
///
/// Due variabili sciolte non si possono provare. Una classe si', ed e' l'unico
/// motivo per cui esiste: la regola "chiudere un giro sposta SEMPRE il
/// riferimento" adesso e' scritta in un posto solo, e c'e' un test che la
/// tiene ferma.
class ContoGiri {
  /// Metri gia' assegnati ai giri chiusi.
  double _metriChiusi = 0.0;

  /// Secondi di tempo attivo gia' assegnati ai giri chiusi.
  int _secondiChiusi = 0;

  double get metriChiusi => _metriChiusi;
  int get secondiChiusi => _secondiChiusi;

  /// Metri percorsi nel giro in corso.
  double metriDelGiro(double metriTotali) {
    final double valore = metriTotali - _metriChiusi;
    return valore < 0 ? 0 : valore;
  }

  /// Secondi del giro in corso.
  int secondiDelGiro(int secondiTotali) {
    final int valore = secondiTotali - _secondiChiusi;
    return valore < 0 ? 0 : valore;
  }

  /// Chiude un giro e sposta il riferimento.
  ///
  /// Restituisce `true` se il riferimento si e' mosso davvero. Un `false` vuol
  /// dire che questo giro non ha consumato niente: chi chiude i giri in ciclo
  /// deve fermarsi, perche' il ciclo successivo troverebbe la stessa
  /// situazione e girerebbe a vuoto.
  bool chiudi({required double metri, required int secondiTotali}) {
    final double passoAvanti = metri > 0 ? metri : 0;
    final bool tempoAvanti = secondiTotali > _secondiChiusi;

    _metriChiusi += passoAvanti;
    if (tempoAvanti) _secondiChiusi = secondiTotali;

    return passoAvanti > 0;
  }

  void azzera() {
    _metriChiusi = 0.0;
    _secondiChiusi = 0;
  }
}
