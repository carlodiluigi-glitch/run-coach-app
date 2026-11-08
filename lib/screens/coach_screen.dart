import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../app/routes.dart';
import '../app/tokens.dart';
import '../providers/activity_provider.dart';
import '../providers/daily_steps_provider.dart';
import '../providers/plan_provider.dart';
import '../services/coach_export.dart';
import '../widgets/app_card.dart';

/// "Parla col coach": prepara il testo da incollare in una chat con un'AI.
///
/// Primo pezzo del giro. Il secondo - incollare in Falcata la settimana che
/// l'AI propone - arriva nel rilascio dopo, quando il metodo sara' provato
/// con corse vere. Vedi [CoachExport].
class CoachScreen extends StatefulWidget {
  const CoachScreen({super.key});

  @override
  State<CoachScreen> createState() => _CoachScreenState();
}

class _CoachScreenState extends State<CoachScreen> {
  bool _mostraTesto = false;

  String _testo(BuildContext context) {
    final ActivityProvider a = context.read<ActivityProvider>();
    final PlanProvider plans = context.read<PlanProvider>();
    return const CoachExport().build(
      now: DateTime.now(),
      activities: a.activities,
      checkIns: a.checkIns,
      profile: a.athleteProfile,
      fitnessIndex: a.runIndex.index?.value,
      zones: a.trainingZones,
      load: a.trainingLoad,
      plan: plans.plan,
      dailySteps: context.read<DailyStepsProvider>().stepsByDay,
    );
  }

  Future<void> _copia(BuildContext context, String testo) async {
    await Clipboard.setData(ClipboardData(text: testo));
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Copiato. Ora incollalo nella chat con l\'AI.'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final AppPalette p = AppPalette.of(context);
    // Si ricostruisce se arrivano corse o cambia il piano mentre si guarda.
    context.watch<ActivityProvider>();
    context.watch<PlanProvider>();
    final String testo = _testo(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Parla col coach')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.screenSide,
            12,
            AppSpacing.screenSide,
            32,
          ),
          children: <Widget>[
            Text(
              'Discuti la settimana con un\'AI',
              style: AppText.title.copyWith(color: p.ink, fontSize: 20),
            ),
            const SizedBox(height: 8),
            Text(
              'Falcata prepara un testo con le tue ultime due settimane: le '
              'sedute con le fasi separate dai recuperi, i tuoi commenti, '
              'come stavi al mattino, il piano e i giorni che hai. In fondo '
              'ci sono le istruzioni per l\'AI.',
              style: AppText.body.copyWith(color: p.inkSoft),
            ),
            const SizedBox(height: 20),
            SizedBox(
              height: 52,
              child: FilledButton.icon(
                onPressed: () => _copia(context, testo),
                style: FilledButton.styleFrom(
                  backgroundColor: p.accent,
                  foregroundColor: p.onAccent,
                ),
                icon: const Icon(Icons.copy_rounded, size: 19),
                label: const Text('Copia per il coach'),
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              height: 52,
              child: OutlinedButton.icon(
                onPressed: () =>
                    Navigator.of(context).pushNamed(AppRoutes.coachImport),
                icon: const Icon(Icons.content_paste_rounded, size: 19),
                label: const Text('Incolla la risposta del coach'),
              ),
            ),
            const SizedBox(height: 20),
            const SectionTitle('Come si usa'),
            AppCard(
              child: Text(
                '1. Premi "Copia per il coach".\n'
                '2. Apri la chat dell\'AI che usi e incolla.\n'
                '3. Racconta come sono andate le sedute: l\'AI ti fa qualche '
                'domanda e ti propone la settimana dopo.\n'
                '4. Quando siete d\'accordo, l\'AI scrive un blocco che '
                'comincia con ${CoachExport.inizioBlocco}. Copia la sua '
                'risposta e premi "Incolla la risposta del coach".\n'
                '5. Falcata controlla la settimana, te la mostra accanto a '
                'quella del piano e la applica solo se confermi.',
                style: AppText.body.copyWith(color: p.ink),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(left: 4, top: 8),
              child: Text(
                'Falcata non manda niente a nessuno: il testo esce solo se lo '
                'incolli tu. Contiene le tue corse e i tuoi commenti, quindi '
                'incollalo solo dove ti fidi.',
                style: AppText.caption.copyWith(color: p.inkFaint),
              ),
            ),
            const SizedBox(height: 20),
            TextButton(
              onPressed: () => setState(() => _mostraTesto = !_mostraTesto),
              child: Text(_mostraTesto
                  ? 'Nascondi il testo'
                  : 'Guarda il testo (${testo.length} caratteri)'),
            ),
            if (_mostraTesto)
              AppCard(
                child: SelectableText(
                  testo,
                  style: AppText.caption.copyWith(
                    color: p.ink,
                    fontFamily: 'monospace',
                    height: 1.35,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
