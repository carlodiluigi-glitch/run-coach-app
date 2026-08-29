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

  testWidgets('LapTable elenca i lap', (WidgetTester tester) async {
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

    expect(find.text('LAP'), findsOneWidget);
    expect(find.text('5:23'), findsOneWidget);
    expect(find.text('5:10'), findsOneWidget);
  });

  testWidgets('LapTable gestisce la lista vuota', (WidgetTester tester) async {
    await tester.pumpWidget(_wrap(const LapTable(laps: <Lap>[])));
    expect(find.text('Nessun lap registrato.'), findsOneWidget);
  });

  testWidgets('PaceIndicator mostra simbolo e stato',
      (WidgetTester tester) async {
    await tester.pumpWidget(_wrap(
      const PaceIndicator(
        status: PaceStatus.tooSlow,
        currentPaceSecPerKm: 280,
        target: PaceTarget(fastestSecPerKm: 240, slowestSecPerKm: 250),
      ),
    ));

    expect(find.text('↓'), findsOneWidget);
    expect(find.text('TROPPO LENTO'), findsOneWidget);
    expect(find.text('Target 4:00-4:10 /km'), findsOneWidget);
    expect(find.text('Attuale 4:40 /km'), findsOneWidget);
  });
}
