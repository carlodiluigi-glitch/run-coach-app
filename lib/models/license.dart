/// Cosa e' gratis e cosa si paga una volta sola.
///
/// LA DECISIONE, PRIMA DEL CODICE
/// ------------------------------
/// Falcata si vende a chi corre con il telefono e non ha l'orologio da
/// cinquecento euro. Quella persona ha gia' tre app gratuite installate e non
/// ha nessun motivo di pagarne una - a meno che non veda, prima di pagare, che
/// questa fa una cosa che le altre non fanno.
///
/// Quindi la divisione non e' "poco gratis per costringerti a pagare". E'
/// l'opposto: **tutto quello che fanno le altre app e' gratis per sempre**, e
/// si paga solo quello che le altre non hanno. Chi scarica Falcata e la usa
/// come app di corsa normale non incontra mai un muro: registra, vede i
/// parziali, i record, lo storico, le statistiche, il percorso. Se poi vuole
/// essere allenato - il piano che si scrive da solo, i passi calcolati sulla
/// sua forma, il carico, la prontezza del mattino - quello e' il prodotto, e si
/// paga una volta.
///
/// PERCHE' UNA VOLTA SOLA E NON UN ABBONAMENTO
/// -------------------------------------------
/// Perche' l'abbonamento e' il motivo per cui la gente non compra. Chi corre
/// tre volte a settimana e paga gia' la palestra non aggiunge un'altra rata
/// mensile per un'app; venti euro una volta sola li spende senza pensarci,
/// perche' e' meno di un paio di calze tecniche e non torna il mese dopo.
///
/// REGOLA CHE NON SI ROMPE
/// -----------------------
/// **Niente di gia' registrato si blocca mai.** Le corse sono dell'atleta, non
/// dell'app: se un giorno il blocco scattasse sullo storico, quello non sarebbe
/// un modello di vendita, sarebbe un ostaggio.
enum Feature {
  /// Registrare, vedere, archiviare. Il mestiere di base.
  recording,

  /// Allenamenti a intervalli e coach vocale.
  workouts,

  /// Il percorso disegnato e il dislivello.
  route,

  /// Record personali e statistiche.
  records,

  /// Il piano di allenamento che si scrive da solo.
  plan,

  /// Indice di forma, passi di allenamento, previsioni di gara.
  fitness,

  /// Carico, fatica, condizione, prontezza del mattino.
  adaptive,
}

extension FeatureInfo on Feature {
  /// `true` se si usa senza pagare, per sempre.
  bool get isFree {
    switch (this) {
      case Feature.recording:
      case Feature.workouts:
      case Feature.route:
      case Feature.records:
        return true;
      case Feature.plan:
      case Feature.fitness:
      case Feature.adaptive:
        return false;
    }
  }

  String get title {
    switch (this) {
      case Feature.recording:
        return 'Registrare le corse';
      case Feature.workouts:
        return 'Allenamenti e coach vocale';
      case Feature.route:
        return 'Percorso e dislivello';
      case Feature.records:
        return 'Record e statistiche';
      case Feature.plan:
        return 'Il piano di allenamento';
      case Feature.fitness:
        return 'Forma, passi e previsioni';
      case Feature.adaptive:
        return 'Carico, fatica e prontezza';
    }
  }

  /// Una riga che dice cosa ci fai, non cosa e'.
  String get summary {
    switch (this) {
      case Feature.recording:
        return 'GPS, giri, storico, anche a schermo spento.';
      case Feature.workouts:
        return 'Ripetute guidate a voce, con il passo obiettivo.';
      case Feature.route:
        return 'Il giro che hai fatto e quanto hai salito.';
      case Feature.records:
        return 'I tuoi migliori su ogni distanza, e i numeri del mese.';
      case Feature.plan:
        return 'Settimane scritte sui giorni e sul tempo che hai davvero, '
            'con i passi calcolati sulla tua forma.';
      case Feature.fitness:
        return 'Quanto vali adesso, a che passo allenarti, che tempo faresti '
            'in gara.';
      case Feature.adaptive:
        return 'Quanto ti e\' costata una seduta, quanta ne hai nelle gambe, '
            'e se oggi conviene tirare.';
    }
  }
}

/// Lo stato della licenza sul telefono.
///
/// PERCHE' NON C'E' ANCORA L'ACQUISTO VERO
/// ---------------------------------------
/// Il pagamento passa per il Play Store, e il Play Store vuole un account da
/// sviluppatore, l'app pubblicata e un prodotto configurato nella sua console.
/// Niente di tutto questo esiste ancora.
///
/// Quello che esiste da adesso e' la **struttura**: l'app sa cosa e' gratis,
/// sa cosa e' bloccato, e lo dice all'utente nel posto giusto. Quando ci sara'
/// l'account, l'unica cosa da cambiare e' da dove arriva [isUnlocked] - una
/// riga - invece di dover rimettere mano a tutte le schermate.
///
/// E finche' l'app non e' sul negozio, [developerUnlocked] tiene tutto aperto:
/// sarebbe assurdo che l'autore non potesse usare la propria app.
class LicenseState {
  const LicenseState({
    required this.isUnlocked,
    this.purchasedAt,
  });

  /// Lo stato di chi non ha (ancora) comprato.
  static const LicenseState locked = LicenseState(isUnlocked: false);

  /// `true` quando questa copia e' destinata al Play Store.
  ///
  /// Non e' una riga che si cambia a mano: arriva da fuori, al momento della
  /// compilazione, e la mette **il workflow** nel passo che costruisce il
  /// pacchetto per il negozio:
  ///
  ///   flutter build appbundle --release --dart-define=FALCATA_NEGOZIO=true
  ///
  /// L'APK che ci si installa da soli quel passaggio non lo fa, quindi resta
  /// aperto.
  static const bool forTheStore =
      bool.fromEnvironment('FALCATA_NEGOZIO');

  /// Finche' Falcata non e' sul Play Store, tutto e' aperto.
  ///
  /// PERCHE' NON E' PIU' UN `true` SCRITTO A MANO
  /// --------------------------------------------
  /// Perche' era l'errore piu' costoso che questo progetto potesse fare, e
  /// dipendeva solo dal ricordarsene.
  ///
  /// Il conto, per esteso: si paga l'account sviluppatore, si aspettano i
  /// quattordici giorni dei dodici tester, si pubblica - e con questa riga
  /// accesa l'app esce **con tutto sbloccato per chiunque**. Piano, forma,
  /// carico, regalati. Nessun avviso, nessun errore, nessun test rosso: dal
  /// di fuori sembra tutto a posto, e ci si accorge dell'errore dagli incassi
  /// a zero.
  ///
  /// Adesso dipende da [forTheStore], che non sta nel codice ma nel workflow:
  /// il pacchetto per il negozio e quello che ti installi tu li costruiscono
  /// due passi diversi, quindi non c'e' niente da ricordarsi. Sbagliare
  /// richiederebbe di togliere di proposito la riga dal workflow, che e' una
  /// cosa che non si fa per distrazione.
  ///
  /// Resta vero per l'APK che ci si installa da soli, ed e' giusto: sarebbe
  /// assurdo che l'autore non potesse usare la propria app.
  static const bool developerUnlocked = !forTheStore;

  final bool isUnlocked;
  final DateTime? purchasedAt;

  /// Prezzo, una volta sola. Il valore vero arrivera' dal negozio, perche'
  /// cambia da paese a paese: questo serve per scriverlo nella schermata.
  static const String priceLabel = '19,90 €';

  bool allows(Feature feature) =>
      feature.isFree || isUnlocked || developerUnlocked;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'isUnlocked': isUnlocked,
        if (purchasedAt != null) 'purchasedAt': purchasedAt!.toIso8601String(),
      };

  factory LicenseState.fromJson(Map<String, dynamic> json) => LicenseState(
        isUnlocked: json['isUnlocked'] as bool? ?? false,
        purchasedAt:
            DateTime.tryParse(json['purchasedAt'] as String? ?? ''),
      );
}
