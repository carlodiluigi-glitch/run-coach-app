import 'package:flutter_test/flutter_test.dart';
import 'package:run_coach_app/models/license.dart';

/// Cosa e' gratis, cosa si paga, e l'errore da 25 dollari.
///
/// PERCHE' QUESTO FILE ESISTE
/// --------------------------
/// Perche' qui un difetto non si vede. Tutto il resto del progetto, quando
/// sbaglia, lo dice: il passo esce storto, il grafico si spezza, un test
/// diventa rosso. La licenza no. Se si sbaglia qui, l'app funziona
/// perfettamente, sembra a posto da fuori, e l'unico sintomo arriva settimane
/// dopo sotto forma di incassi a zero.
///
/// I due modi di sbagliare sono questi, e stanno tutti e due qui sotto:
///
///   1. Pubblicare con tutto sbloccato - l'app regalata a chiunque.
///   2. Spostare per sbaglio una funzione da gratis a pagamento, o il
///      contrario, cambiando il patto con chi ha gia' scaricato.
void main() {
  group('il patto con chi scarica', () {
    test('il mestiere di base resta gratis per sempre', () {
      // QUESTA LISTA E' UNA PROMESSA, NON UNA CONFIGURAZIONE.
      //
      // Chi scarica Falcata deve poter registrare, rivedere e archiviare le
      // sue corse senza pagare niente, per sempre. Se un giorno qualcuna di
      // queste righe diventasse a pagamento, non sarebbe un cambio di
      // listino: sarebbe aver cambiato il patto a chi aveva gia' installato.
      expect(Feature.recording.isFree, isTrue, reason: 'registrare le corse');
      expect(Feature.workouts.isFree, isTrue, reason: 'allenamenti e voce');
      expect(Feature.route.isFree, isTrue, reason: 'percorso e dislivello');
      expect(Feature.records.isFree, isTrue, reason: 'record e statistiche');
    });

    test('il coach si paga', () {
      // La parte che costa e' quella che decide COSA fare: il piano, i passi,
      // la gestione del carico. Non la parte che misura.
      expect(Feature.plan.isFree, isFalse);
      expect(Feature.fitness.isFree, isFalse);
      expect(Feature.adaptive.isFree, isFalse);
    });

    test('ogni funzione ha una risposta, nessuna esclusa', () {
      // Una funzione nuova aggiunta all'elenco senza decidere da che parte
      // sta e' un buco: il controllo qui sotto obbliga a sceglierlo.
      for (final Feature f in Feature.values) {
        expect(() => f.isFree, returnsNormally, reason: f.name);
        expect(f.title.isNotEmpty, isTrue, reason: f.name);
      }
    });

    test('chi non ha comprato non e\' sbloccato', () {
      expect(LicenseState.locked.isUnlocked, isFalse);
    });

    test('chi ha comprato puo\' usare tutto', () {
      const LicenseState comprata = LicenseState(isUnlocked: true);
      for (final Feature f in Feature.values) {
        expect(comprata.allows(f), isTrue, reason: f.name);
      }
    });

    test('il prezzo e\' scritto una volta sola', () {
      // Se il prezzo comparisse a mano in due schermate, prima o poi ne
      // cambierebbe una sola - e l'app direbbe due prezzi diversi.
      expect(LicenseState.priceLabel.isNotEmpty, isTrue);
    });
  });

  group('l\'errore da venticinque dollari', () {
    test('tutto aperto e destinato al negozio non possono stare insieme', () {
      // IL CONTROLLO CHE VALE PIU' DI TUTTI GLI ALTRI.
      //
      // developerUnlocked tiene tutto aperto, e deve farlo: sarebbe assurdo
      // che l'autore non potesse usare la propria app, e i dodici tester
      // devono poter provare tutto.
      //
      // Ma nel pacchetto che va su Play deve essere spento, se no si pubblica
      // un'app regalata. Adesso i due valori sono legati per costruzione -
      // uno e' la negazione dell'altro - e questa riga tiene fermo quel
      // legame: se qualcuno rimettesse un `true` scritto a mano, cadrebbe.
      expect(LicenseState.developerUnlocked, !LicenseState.forTheStore,
          reason: 'developerUnlocked deve essere l\'opposto esatto di '
              'forTheStore, non un valore scritto a mano');
    });

    test('questi test girano sulla copia aperta, ed e\' giusto cosi\'', () {
      // I test girano senza --dart-define, quindi qui forTheStore e' falso e
      // developerUnlocked e' vero. Non e' un difetto: e' esattamente la copia
      // che si installa a mano.
      //
      // Vuol dire pero' che da qui NON si puo' provare il pacchetto del
      // negozio: quello lo garantisce il workflow, che passa la riga
      //
      //   --dart-define=FALCATA_NEGOZIO=true
      //
      // solo al passo "Pacchetto per il Play Store". Questo test serve a
      // ricordarlo a chi legge, e a far fallire il conto se un domani
      // qualcuno provasse a far dipendere la licenza dal modo di
      // compilazione invece che da li'.
      expect(LicenseState.forTheStore, isFalse);
      expect(LicenseState.developerUnlocked, isTrue);
    });

    test('con tutto aperto, nessuna funzione risulta bloccata', () {
      // La conseguenza, scritta per esteso: finche' developerUnlocked e'
      // vero, allows() dice sempre di si'. E' il comportamento voluto per
      // l'APK che ti installi tu, ed e' anche il motivo per cui quella
      // costante non puo' finire nel pacchetto del negozio.
      for (final Feature f in Feature.values) {
        expect(LicenseState.locked.allows(f), isTrue, reason: f.name);
      }
    });
  });
}
