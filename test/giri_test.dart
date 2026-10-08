import 'package:flutter_test/flutter_test.dart';
import 'package:run_coach_app/services/conto_giri.dart';

/// Il conto dei giri.
///
/// DA DOVE NASCE QUESTO FILE
/// -------------------------
/// Da una corsa vera, rovinata. Il dettaglio diceva:
///
///   Giro 1 - 1.00 km - 5:44
///   Giro 2 - 1.00 km - 5:44
///   ... fino al decimo, identici al secondo
///
/// e la voce, allo scoccare del primo chilometro, aveva annunciato giro due,
/// tre, quattro uno dietro l'altro senza che fosse passato un metro.
///
/// La causa: riscrivendo il pezzo che chiude un giro per aggiungerci la
/// cadenza, le due righe che spostavano il riferimento del giro erano sparite.
/// Non un errore di logica - due righe cadute in un rimpasto, il tipo di
/// guasto che nessun controllo automatico vede, perche' il codice rimasto e'
/// perfettamente valido.
///
/// La difesa non e' "stare piu' attenti": e' che adesso quelle due cifre sono
/// una classe con un contratto, e il contratto ha un test.
void main() {
  group('il riferimento si sposta', () {
    test('chiudere un giro consuma i metri', () {
      final ContoGiri giri = ContoGiri();

      // Mille metri fatti, nessun giro chiuso: il giro in corso vale mille.
      expect(giri.metriDelGiro(1000), 1000);

      giri.chiudi(metri: 1000, secondiTotali: 344);

      // Ecco il punto: adesso il giro in corso deve valere ZERO, non mille.
      expect(giri.metriDelGiro(1000), 0);
      expect(giri.secondiDelGiro(344), 0);
    });

    test('il secondo giro riparte da dove e\' finito il primo', () {
      final ContoGiri giri = ContoGiri();
      giri.chiudi(metri: 1000, secondiTotali: 344);

      expect(giri.metriDelGiro(1600), 600);
      expect(giri.secondiDelGiro(500), 156);

      giri.chiudi(metri: 1000, secondiTotali: 700);
      expect(giri.metriDelGiro(2000), 0);
      expect(giri.secondiDelGiro(700), 0);
    });

    test('chiudere dice se ha davvero consumato qualcosa', () {
      final ContoGiri giri = ContoGiri();
      expect(giri.chiudi(metri: 1000, secondiTotali: 300), isTrue);
      // Un giro da zero metri non consuma niente: chi cicla deve saperlo e
      // fermarsi, se no gira a vuoto.
      expect(giri.chiudi(metri: 0, secondiTotali: 300), isFalse);
    });

    test('azzerare riporta tutto all\'inizio', () {
      final ContoGiri giri = ContoGiri();
      giri.chiudi(metri: 1000, secondiTotali: 344);
      giri.azzera();
      expect(giri.metriDelGiro(1000), 1000);
      expect(giri.secondiDelGiro(344), 344);
    });

    test('non esistono giri di lunghezza negativa', () {
      // Puo' succedere rileggendo uno stato incoerente: deve uscire zero, non
      // un numero negativo che poi diventa un passo assurdo.
      final ContoGiri giri = ContoGiri();
      giri.chiudi(metri: 1000, secondiTotali: 344);
      expect(giri.metriDelGiro(500), 0);
      expect(giri.secondiDelGiro(100), 0);
    });
  });

  group('la corsa che aveva prodotto dieci giri uguali', () {
    /// Riproduce il ciclo del giro automatico come sta nel motore della corsa:
    /// a ogni colpo di orologio, finche' il giro in corso supera il
    /// chilometro, se ne chiude uno. Restituisce **l'istante** in cui ogni
    /// giro si e' chiuso.
    List<int> quandoSiChiudono({
      required double metriAlSecondo,
      required int secondi,
      double passoGiro = 1000,
    }) {
      final ContoGiri giri = ContoGiri();
      final List<int> istanti = <int>[];

      for (int t = 1; t <= secondi; t++) {
        final double metri = metriAlSecondo * t;
        int sicurezza = 0;
        while (giri.metriDelGiro(metri) >= passoGiro && sicurezza < 10) {
          sicurezza++;
          final double prima = giri.metriChiusi;
          istanti.add(t);
          giri.chiudi(metri: passoGiro, secondiTotali: t);
          if (giri.metriChiusi <= prima) break;
        }
      }
      return istanti;
    }

    test('i dieci giri si chiudono in dieci momenti diversi', () {
      // 2,907 m/s = 5:44 al chilometro, il passo di quella corsa.
      final List<int> istanti =
          quandoSiChiudono(metriAlSecondo: 2.907, secondi: 3600);

      expect(istanti.length, 10);

      // QUESTA E' LA PROVA.
      //
      // Col difetto, i dieci giri si chiudevano tutti nello stesso istante -
      // allo scoccare del primo chilometro - ed e' per quello che uscivano
      // dieci tempi identici. Qui ogni chiusura deve cadere dopo la
      // precedente, a circa un chilometro di distanza.
      for (int i = 1; i < istanti.length; i++) {
        expect(istanti[i], greaterThan(istanti[i - 1]),
            reason: 'il giro ${i + 1} si chiude insieme al precedente: '
                'il riferimento non si sta spostando');
        expect(istanti[i] - istanti[i - 1], closeTo(344, 2));
      }
    });

    test('un passo che cambia fra un giro e l\'altro si vede', () {
      final ContoGiri giri = ContoGiri();
      final List<int> tempi = <int>[];

      // Primo chilometro a 5:00, secondo a 6:00.
      tempi.add(giri.secondiDelGiro(300));
      giri.chiudi(metri: 1000, secondiTotali: 300);
      tempi.add(giri.secondiDelGiro(660));
      giri.chiudi(metri: 1000, secondiTotali: 660);

      expect(tempi, <int>[300, 360]);
    });

    test('un salto di distanza chiude piu\' giri, ma non all\'infinito', () {
      // Il caso per cui il ciclo esiste: un buco di segnale lungo che
      // all'improvviso aggiunge tre chilometri.
      final ContoGiri giri = ContoGiri();
      int chiusi = 0;
      int sicurezza = 0;
      const double metri = 3200;
      while (giri.metriDelGiro(metri) >= 1000 && sicurezza < 10) {
        sicurezza++;
        final double prima = giri.metriChiusi;
        giri.chiudi(metri: 1000, secondiTotali: 1100);
        if (giri.metriChiusi <= prima) break;
        chiusi++;
      }
      expect(chiusi, 3);
      expect(giri.metriDelGiro(metri), closeTo(200, 0.001));
    });
  });
}
