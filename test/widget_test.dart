import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:run_coach_app/app/theme.dart';
import 'package:run_coach_app/models/lap.dart';
import 'package:run_coach_app/models/workout_step.dart';
import 'package:run_coach_app/widgets/lap_table.dart';
import 'package:run_coach_app/widgets/metric_card.dart';
import 'package:run_coach_app/widgets/pace_indicator.dart';

/// I test dei widget usano componenti isolati: non avviano l'app completa,
/// che avrebbe bisogno di GPS e Text To Speech (non disponibili nei test).
Widget _wrap(Widget child) => MaterialApp(
      theme: AppTheme.light(),
      home: Scaffold(body: SingleChildScrollView(child: child)),
    );

void main() {
  testWidgets('MetricCard mostra etichetta, valore e unita',
      (WidgetTester tester) async {
    await tester.pumpWidget(_wrap(
      const MetricCard(label: 'Distanza', value: '8.54', unit: 'km'),
    ));

    expect(find.text('DISTANZA'), findsOneWidget);
    expect(find.text('8.54'), findsOneWidget);
    expect(find.text('km'), findsOneWidget);
  });

  testWidgets('LapTable elenca i giri con numero, tempo e passo',
      (WidgetTester tester) async {
    await tester.pumpWidget(_wrap(
      const LapTable(
        laps: <Lap>[
          Lap(
            number: 1,
            distanceMeters: 1000,
            durationSeconds: 323,
            totalTimeSeconds: 323,
          ),
          Lap(
            number: 2,
            distanceMeters: 1000,
            durationSeconds: 310,
            totalTimeSeconds: 633,
          ),
        ],
      ),
    ));

    // Senza allenamento le righe sono numerate.
    expect(find.text('GIRO 1'), findsOneWidget);
    expect(find.text('GIRO 2'), findsOneWidget);
    expect(find.text('05:23'), findsOneWidget);
    expect(find.text('05:10'), findsOneWidget);
    expect(find.text('5:23 /km'), findsOneWidget);
  });

  testWidgets('LapTable mostra la fase quando c\'e\' un allenamento',
      (WidgetTester tester) async {
    await tester.pumpWidget(_wrap(
      const LapTable(
        showStepColumn: true,
        laps: <Lap>[
          Lap(
            number: 1,
            distanceMeters: 400,
            durationSeconds: 96,
            totalTimeSeconds: 96,
            stepLabel: 'Ripetuta 1/10',
          ),
          Lap(
            number: 2,
            distanceMeters: 200,
            durationSeconds: 82,
            totalTimeSeconds: 178,
            stepLabel: 'Recupero 1/10',
          ),
        ],
      ),
    ));

    expect(find.text('RIPETUTA 1/10'), findsOneWidget);
    expect(find.text('RECUPERO 1/10'), findsOneWidget);
    expect(find.text('400 m'), findsOneWidget);
    expect(find.text('01:36'), findsOneWidget);
    // Il numero del giro lascia il posto alla fase.
    expect(find.text('GIRO 1'), findsNothing);
  });

  testWidgets('LapTable gestisce la lista vuota', (WidgetTester tester) async {
    await tester.pumpWidget(_wrap(const LapTable(laps: <Lap>[])));
    expect(find.text('Nessun parziale registrato.'), findsOneWidget);
  });

  testWidgets('PaceIndicator dice a parole come stai andando',
      (WidgetTester tester) async {
    await tester.pumpWidget(_wrap(
      const PaceIndicator(
        status: PaceStatus.tooSlow,
        currentPaceSecPerKm: 280,
        target: PaceTarget(fastestSecPerKm: 240, slowestSecPerKm: 250),
      ),
    ));

    expect(find.text('Stai rallentando'), findsOneWidget);
    expect(find.text('obiettivo 4:00-4:10 /km'), findsOneWidget);
  });

  testWidgets('PaceIndicator senza obiettivo mostra il passo attuale',
      (WidgetTester tester) async {
    await tester.pumpWidget(_wrap(
      const PaceIndicator(
        status: PaceStatus.unknown,
        currentPaceSecPerKm: 320,
      ),
    ));

    expect(find.text('Nessun passo obiettivo'), findsOneWidget);
    expect(find.text('5:20 /km'), findsOneWidget);
  });
}
