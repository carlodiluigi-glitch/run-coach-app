import 'package:flutter/material.dart';

import '../app/tokens.dart';
import '../models/effort.dart';

/// L'icona di una faccina.
IconData iconaFaccina(RunSatisfaction s) {
  switch (s) {
    case RunSatisfaction.benissimo:
      return Icons.sentiment_very_satisfied_rounded;
    case RunSatisfaction.bene:
      return Icons.sentiment_satisfied_rounded;
    case RunSatisfaction.cosiCosi:
      return Icons.sentiment_neutral_rounded;
    case RunSatisfaction.male:
      return Icons.sentiment_dissatisfied_rounded;
    case RunSatisfaction.malissimo:
      return Icons.sentiment_very_dissatisfied_rounded;
  }
}

/// Il colore di una faccina: dal verde del "benissimo" al rosso del
/// "malissimo", cosi' si sceglie senza leggere.
Color coloreFaccina(RunSatisfaction s, AppPalette p) {
  switch (s) {
    case RunSatisfaction.benissimo:
      return p.green;
    case RunSatisfaction.bene:
      return p.accent;
    case RunSatisfaction.cosiCosi:
      return p.blue;
    case RunSatisfaction.male:
      return p.orange;
    case RunSatisfaction.malissimo:
      return p.red;
  }
}

/// Le cinque faccine in fila, con il nome sotto. Un tocco sceglie, un
/// secondo tocco sulla stessa toglie la scelta.
class FaccineRow extends StatelessWidget {
  const FaccineRow({
    super.key,
    required this.selected,
    required this.onChanged,
  });

  final RunSatisfaction? selected;
  final ValueChanged<RunSatisfaction?> onChanged;

  @override
  Widget build(BuildContext context) {
    final AppPalette p = AppPalette.of(context);
    return Row(
      children: <Widget>[
        for (final RunSatisfaction s in RunSatisfaction.values)
          Expanded(
            child: _Faccina(
              valore: s,
              scelta: selected == s,
              p: p,
              onTap: () => onChanged(selected == s ? null : s),
            ),
          ),
      ],
    );
  }
}

class _Faccina extends StatelessWidget {
  const _Faccina({
    required this.valore,
    required this.scelta,
    required this.p,
    required this.onTap,
  });

  final RunSatisfaction valore;
  final bool scelta;
  final AppPalette p;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final Color colore = coloreFaccina(valore, p);
    return Semantics(
      button: true,
      selected: scelta,
      label: valore.label,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.small),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: scelta ? colore : p.surface,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  iconaFaccina(valore),
                  size: 32,
                  color: scelta ? p.on(colore) : colore,
                ),
              ),
              const SizedBox(height: 6),
              ExcludeSemantics(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                  valore.label,
                  maxLines: 1,
                  style: AppText.caption.copyWith(
                    fontSize: 11,
                    color: scelta ? p.ink : p.inkFaint,
                    fontWeight: scelta ? FontWeight.w600 : FontWeight.w400,
                  ),
                ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
