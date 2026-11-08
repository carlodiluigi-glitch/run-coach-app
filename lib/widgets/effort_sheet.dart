import 'package:flutter/material.dart';

import '../app/tokens.dart';
import '../models/effort.dart';

/// Chiede com'e' andata la seduta.
///
/// PERCHE' E' FATTA COSI'
/// ----------------------
/// Questa domanda arriva quando uno ha appena finito di correre, e' sudato e
/// vuole solo togliersi le scarpe. Se costa piu' di cinque secondi non viene
/// risposta, e un dato che nessuno inserisce non serve a niente.
///
/// Quindi: un tocco basta (il numero), tutto il resto e' facoltativo, e si
/// puo' saltare senza sensi di colpa. Meglio nessun dato che un dato finto.
///
/// Dalla 2.11 si possono lasciare anche due righe di note e il tempo che
/// faceva. Anche da sole, senza il numero: "gambe a posto, mi ha fermato
/// il caldo" e' gia' un'informazione, e il coach la riceve intera.
Future<EndOfRunAnswers?> askSessionFeedback(BuildContext context) {
  return showModalBottomSheet<EndOfRunAnswers>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (BuildContext ctx) => const _EffortSheet(),
  );
}

/// Le risposte a fine corsa. Ogni parte puo' mancare.
class EndOfRunAnswers {
  const EndOfRunAnswers({this.feedback, this.note, this.temperature});

  /// Fatica, gambe, dolore: c'e' solo se e' stato scelto il numero.
  final SessionFeedback? feedback;

  /// Le note libere, gia' ripulite. `null` se vuote.
  final String? note;

  final FeltTemperature? temperature;
}

class _EffortSheet extends StatefulWidget {
  const _EffortSheet();

  @override
  State<_EffortSheet> createState() => _EffortSheetState();
}

class _EffortSheetState extends State<_EffortSheet> {
  int? _rpe;
  LegsFeel? _legs;
  bool _pain = false;
  FeltTemperature? _temp;
  final TextEditingController _note = TextEditingController();

  @override
  void initState() {
    super.initState();
    // Il pulsante Salva si accende anche scrivendo solo una nota.
    _note.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  String? get _notaPulita {
    final String t = _note.text.trim();
    return t.isEmpty ? null : t;
  }

  bool get _qualcosaDaSalvare =>
      _rpe != null || _notaPulita != null || _temp != null;

  @override
  Widget build(BuildContext context) {
    final AppPalette p = AppPalette.of(context);
    final int? rpe = _rpe;

    return Container(
      decoration: BoxDecoration(
        color: p.background,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.fromLTRB(
        AppSpacing.screenSide,
        10,
        AppSpacing.screenSide,
        MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 18),
                decoration: BoxDecoration(
                  color: p.separator,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Text(
              'Quanto ti e\' costata?',
              style: AppText.largeTitle.copyWith(color: p.ink, fontSize: 26),
            ),
            const SizedBox(height: 6),
            Text(
              'Serve a capire se stai migliorando o se sei solo stanco. '
              'Due corse allo stesso passo possono costare molto diverso.',
              style: AppText.caption.copyWith(color: p.inkFaint),
            ),
            const SizedBox(height: 18),

            // La scala 1-10.
            Row(
              children: <Widget>[
                for (int value = 1; value <= 10; value++)
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 2),
                      child: _EffortButton(
                        value: value,
                        selected: rpe == value,
                        onTap: () => setState(() => _rpe = value),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 10),

            // Cosa vuol dire il numero scelto.
            AnimatedSize(
              duration: const Duration(milliseconds: 150),
              alignment: Alignment.topLeft,
              child: rpe == null
                  ? Text(
                      'Tocca un numero: 1 e\' una passeggiata, 10 e\' il limite.',
                      style: AppText.body.copyWith(color: p.inkFaint),
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          PerceivedEffort.label(rpe),
                          style: AppText.title.copyWith(color: p.accent),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          PerceivedEffort.description(rpe),
                          style: AppText.body.copyWith(color: p.inkSoft),
                        ),
                      ],
                    ),
            ),

            const SizedBox(height: 22),
            Text('GAMBE', style: AppText.label.copyWith(color: p.inkFaint)),
            const SizedBox(height: 8),
            Row(
              children: <Widget>[
                for (final LegsFeel feel in LegsFeel.values)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(feel.label),
                      selected: _legs == feel,
                      onSelected: (bool on) =>
                          setState(() => _legs = on ? feel : null),
                    ),
                  ),
              ],
            ),

            const SizedBox(height: 14),
            // Il dolore non e' un dettaglio fra gli altri: se c'e', il motore
            // chiude la porta alla qualita' nei giorni seguenti.
            SwitchListTile.adaptive(
              value: _pain,
              onChanged: (bool value) => setState(() => _pain = value),
              contentPadding: EdgeInsets.zero,
              title: Text(
                'Ho sentito un dolore',
                style: AppText.row.copyWith(color: p.ink),
              ),
              subtitle: Text(
                'Non un normale affaticamento: un punto preciso che fa male.',
                style: AppText.caption.copyWith(color: p.inkFaint),
              ),
            ),

            const SizedBox(height: 14),
            Text('IL TEMPO', style: AppText.label.copyWith(color: p.inkFaint)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: <Widget>[
                for (final FeltTemperature t in FeltTemperature.values)
                  ChoiceChip(
                    label: Text(t.label),
                    selected: _temp == t,
                    onSelected: (bool on) =>
                        setState(() => _temp = on ? t : null),
                  ),
              ],
            ),

            const SizedBox(height: 18),
            Text('NOTE', style: AppText.label.copyWith(color: p.inkFaint)),
            const SizedBox(height: 8),
            TextField(
              controller: _note,
              minLines: 2,
              maxLines: 5,
              maxLength: 600,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(
                hintText: 'Facoltative. Com\'e\' andata, cosa ti ha '
                    'limitato, cosa avresti potuto fare in piu\'...',
                hintStyle: AppText.body.copyWith(color: p.inkFaint),
                filled: true,
                fillColor: p.surface,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppRadius.small),
                  borderSide: BorderSide.none,
                ),
              ),
              style: AppText.body.copyWith(color: p.ink),
            ),

            const SizedBox(height: 10),
            SizedBox(
              height: 54,
              child: FilledButton(
                onPressed: !_qualcosaDaSalvare
                    ? null
                    : () => Navigator.of(context).pop(
                          EndOfRunAnswers(
                            feedback: rpe == null
                                ? null
                                : SessionFeedback(
                                    rpe: rpe,
                                    legs: _legs,
                                    hasPain: _pain,
                                  ),
                            note: _notaPulita,
                            temperature: _temp,
                          ),
                        ),
                style: FilledButton.styleFrom(
                  backgroundColor: p.accent,
                  foregroundColor: p.onAccent,
                  disabledBackgroundColor: p.separator,
                  disabledForegroundColor: p.inkFaint,
                ),
                child: const Text('Salva'),
              ),
            ),
            Center(
              child: TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text(
                  'Salta',
                  style: TextStyle(color: p.inkFaint),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EffortButton extends StatelessWidget {
  const _EffortButton({
    required this.value,
    required this.selected,
    required this.onTap,
  });

  final int value;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final AppPalette p = AppPalette.of(context);

    // Il colore accompagna lo sforzo: verde in basso, arancio in mezzo,
    // rosso in alto. Aiuta a scegliere senza leggere.
    Color tone() {
      if (value <= 3) return p.green;
      if (value <= 6) return p.blue;
      if (value <= 8) return p.orange;
      return p.red;
    }

    return Material(
      color: selected ? tone() : p.surface,
      borderRadius: BorderRadius.circular(AppRadius.small),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: SizedBox(
          height: 52,
          child: Center(
            child: Text(
              '$value',
              style: AppText.number(
                17,
                color: selected ? p.on(tone()) : p.inkSoft,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
