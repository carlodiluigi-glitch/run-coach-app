import 'package:flutter_test/flutter_test.dart';
import 'package:run_coach_app/services/stats_service.dart';

/// Da quanti chilometri parte il piano.
///
/// DA DOVE NASCE QUESTO FILE
/// -------------------------
/// L'app, appena installata, proponeva **9 km a settimana** a un atleta che ne
/// corre 60. Non perche' il conto fosse sbagliato: perche' divideva per quattro
/// settimane quando le corse registrate erano di tre giorni.
///
/// E non era un numero sbagliato qualsiasi. Da quel numero dipendono il volume
/// di tutto il piano, la fase da cui parte (sotto i 45 km propone Costruzione)
/// e quante ripetizioni entrano in una seduta. Un errore all'ingresso che
/// diventa un piano intero sbagliato.
void main() {
  RunningStats conSettimane(List<double> weeklyKm) => RunningStats(
        weekKm: weeklyKm.isEmpty ? 0 : weeklyKm.last,
        weekActivities: 0,
        lastFourWeeksKm: 0,
        lastFourWeeksActivities: 0,
        totalKm: 0,
        totalActivities: 0,
        averagePaceSecPerKm: null,
        longestRunMeters: 0,
        weeklyKm: weeklyKm,
      );

  group('con poche settimane l\'app non indovina', () {
    test('appena installata non propone niente', () {
      // Otto settimane, ma corse solo in quella in corso.
      final RunningStats stats = conSettimane(
        <double>[0, 0, 0, 0, 0, 0, 0, 9],
      );
      expect(stats.suggestedWeeklyKm, isNull,
          reason: 'con tre giorni di archivio non si propone un numero');
    });

    test('due settimane intere non bastano', () {
      final RunningStats stats = conSettimane(
        <double>[0, 0, 0, 0, 0, 55, 60, 12],
      );
      expect(stats.suggestedWeeklyKm, isNull);
    });

    test('tre settimane intere bastano', () {
      final RunningStats stats = conSettimane(
        <double>[0, 0, 0, 0, 58, 55, 60, 12],
      );
      expect(stats.suggestedWeeklyKm, 58);
    });
  });

  group('quando le settimane ci sono', () {
    test('la settimana in corso non conta', () {
      // L'ultima e' incompleta: se contasse, abbasserebbe la proposta.
      final RunningStats stats = conSettimane(
        <double>[60, 62, 58, 61, 59, 60, 62, 8],
      );
      final double? proposta = stats.suggestedWeeklyKm;
      expect(proposta, isNotNull);
      expect(proposta! >= 58, isTrue, reason: 'proposta $proposta');
    });

    test('una settimana saltata non abbassa tutto il piano', () {
      // Influenza in mezzo: la media direbbe 51, la mediana dice 60.
      final RunningStats stats = conSettimane(
        <double>[60, 62, 0, 61, 59, 60, 62, 20],
      );
      expect(stats.suggestedWeeklyKm, 60.5);
    });

    test('chi corre poco davvero riceve un numero basso', () {
      // Qui il numero basso e' vero, non un artefatto: si propone.
      final RunningStats stats = conSettimane(
        <double>[0, 0, 18, 20, 19, 21, 20, 6],
      );
      expect(stats.suggestedWeeklyKm, 20);
    });

    test('settimane quasi vuote non contano come settimane', () {
      // Una corsetta da 2 km non e' una settimana di allenamento.
      final RunningStats stats = conSettimane(
        <double>[2, 1, 2, 3, 60, 58, 62, 10],
      );
      expect(stats.suggestedWeeklyKm, 60);
    });

    test('archivio vuoto: niente proposta', () {
      expect(conSettimane(<double>[]).suggestedWeeklyKm, isNull);
      expect(conSettimane(<double>[0, 0, 0, 0, 0, 0, 0, 0]).suggestedWeeklyKm,
          isNull);
    });
  });
}
