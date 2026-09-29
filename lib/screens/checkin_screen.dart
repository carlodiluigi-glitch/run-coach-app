import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../app/tokens.dart';
import '../models/daily_checkin.dart';
import '../providers/activity_provider.dart';
import '../widgets/app_card.dart';
import '../widgets/inset_list.dart';

/// Il check-in del mattino: tre domande e il dolore.
///
/// PERCHE' TRE DOMANDE E PERCHE' COSI'
/// -----------------------------------
/// Perche' un questionario si compila tutti i giorni solo se costa dieci
/// secondi. Cinque pallini per riga, niente testo da scrivere, niente scorrere:
/// tutto in una schermata.
///
/// Il dolore sta in fondo e separato dal resto, perche' non e' un punteggio:
/// e' un interruttore. Vedi ReadinessEngine.
class CheckInScreen extends StatefulWidget {
  const CheckInScreen({super.key});

  @override
  State<CheckInScreen> createState() => _CheckInScreenState();
}

class _CheckInScreenState extends State<CheckInScreen> {
  DailyCheckIn? _checkIn;
  bool _loaded = false;
  bool _saving = false;
  final TextEditingController _painNote = TextEditingController();

  @override
  void dispose() {
    _painNote.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AppPalette p = AppPalette.of(context);
    final ActivityProvider activities = context.watch<ActivityProvider>();

    if (!_loaded) {
      _loaded = true;
      final DailyCheckIn? esistente = activities.todayCheckIn;
      _checkIn = esistente ?? DailyCheckIn.neutral(DateTime.now());
      _painNote.text = esistente?.painNote ?? '';
    }

    final DailyCheckIn c = _checkIn!;

    return Scaffold(
      appBar: AppBar(title: const Text('Come stai oggi')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.screenSide,
            8,
            AppSpacing.screenSide,
            32,
          ),
          children: <Widget>[
            AppCard(
              child: Text(
                'Dieci secondi, ogni mattina. Serve al motore per decidere '
                'cosa farti fare oggi: gli stessi chilometri costano diverso '
                'a seconda di come sei messo, e il GPS questo non lo vede.',
                style: AppText.body.copyWith(color: p.inkSoft),
              ),
            ),

            const SectionTitle('Come hai dormito'),
            _ScaleRow(
              value: c.sleep,
              onChanged: (int v) =>
                  setState(() => _checkIn = c.copyWith(sleep: v)),
            ),

            const SectionTitle('Come sono le gambe'),
            _ScaleRow(
              value: c.legs,
              onChanged: (int v) =>
                  setState(() => _checkIn = c.copyWith(legs: v)),
            ),
            Padding(
              padding: const EdgeInsets.only(left: 4, top: 6),
              child: Text(
                'Questa pesa doppio: si corre bene anche dopo una notte '
                'storta, molto meno con le gambe piene.',
                style: AppText.caption.copyWith(color: p.inkFaint),
              ),
            ),

            const SectionTitle('Quanta voglia hai di correre'),
            _ScaleRow(
              value: c.motivation,
              onChanged: (int v) =>
                  setState(() => _checkIn = c.copyWith(motivation: v)),
            ),

            const SectionTitle('Dolori o fastidi'),
            InsetList(
              children: <Widget>[
                AppListRow(
                  title: 'Ho un dolore o un fastidio',
                  subtitle: 'Finche\' c\'e\', il motore non ti manda a fare '
                      'qualita\'. Nessun altro segnale lo puo\' compensare.',
                  showChevron: false,
                  trailing: Switch(
                    value: c.hasPain,
                    activeTrackColor: p.red,
                    onChanged: (bool v) =>
                        setState(() => _checkIn = c.copyWith(hasPain: v)),
                  ),
                ),
              ],
            ),
            if (c.hasPain) ...<Widget>[
              const SizedBox(height: 10),
              AppCard(
                child: TextField(
                  controller: _painNote,
                  decoration: const InputDecoration(
                    border: InputBorder.none,
                    hintText: 'Dove? (ginocchio, tendine, polpaccio...)',
                  ),
                  textCapitalization: TextCapitalization.sentences,
                ),
              ),
            ],

            const SizedBox(height: 24),
            SizedBox(
              height: 54,
              child: FilledButton(
                onPressed: _saving ? null : _salva,
                style: FilledButton.styleFrom(
                  backgroundColor: p.accent,
                  foregroundColor: p.onAccent,
                  disabledBackgroundColor: p.separator,
                ),
                child: const Text('Salva'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _salva() async {
    final DailyCheckIn? c = _checkIn;
    if (c == null) return;
    setState(() => _saving = true);

    final ActivityProvider activities = context.read<ActivityProvider>();
    final NavigatorState navigator = Navigator.of(context);

    await activities.saveCheckIn(c.copyWith(
      painNote: c.hasPain ? _painNote.text.trim() : null,
      clearPainNote: !c.hasPain,
    ));

    if (!mounted) return;
    navigator.pop();
  }
}

/// Cinque pallini con l'etichetta sotto. Un tocco, nessuna finestra.
class _ScaleRow extends StatelessWidget {
  const _ScaleRow({required this.value, required this.onChanged});

  final int value;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final AppPalette p = AppPalette.of(context);

    return AppCard(
      padding: const EdgeInsets.fromLTRB(10, 12, 10, 12),
      child: Column(
        children: <Widget>[
          Row(
            children: <Widget>[
              for (int i = DailyCheckIn.min; i <= DailyCheckIn.max; i++)
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 3),
                    child: Material(
                      color: i == value ? p.accent : p.surfaceElevated,
                      borderRadius:
                          BorderRadius.circular(AppRadius.small + 2),
                      clipBehavior: Clip.antiAlias,
                      child: InkWell(
                        onTap: () => onChanged(i),
                        child: SizedBox(
                          height: 46,
                          child: Center(
                            child: Text(
                              '$i',
                              style: AppText.number(
                                18,
                                color: i == value ? p.onAccent : p.inkSoft,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            DailyCheckIn.scaleLabel(value),
            style: AppText.body.copyWith(color: p.ink),
          ),
        ],
      ),
    );
  }
}
