import 'package:flutter/material.dart';

import '../app/tokens.dart';

/// Gruppo di righe dentro un'unica scheda arrotondata, con le linee di
/// separazione fra una riga e l'altra.
///
/// E' la struttura delle liste di iOS: le righe non hanno ognuna la propria
/// scheda, stanno tutte dentro la stessa. Cosi' si legge un blocco solo
/// invece di tanti riquadri staccati.
class InsetList extends StatelessWidget {
  const InsetList({
    super.key,
    required this.children,

    /// Rientro della linea di separazione dal bordo sinistro. Con l'icona
    /// quadrata va allineata al testo, non al bordo della scheda.
    this.separatorIndent = 16,
    this.color,
  });

  final List<Widget> children;
  final double separatorIndent;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final AppPalette p = AppPalette.of(context);

    final List<Widget> rows = <Widget>[];
    for (int i = 0; i < children.length; i++) {
      if (i > 0) {
        rows.add(Padding(
          padding: EdgeInsets.only(left: separatorIndent),
          child: Container(height: 0.5, color: p.separator),
        ));
      }
      rows.add(children[i]);
    }

    return Material(
      color: color ?? p.surface,
      borderRadius: BorderRadius.circular(AppRadius.card),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: rows,
      ),
    );
  }
}

/// Una riga di [InsetList]: icona facoltativa, titolo, sottotitolo, valore a
/// destra e freccia se si puo' toccare.
class AppListRow extends StatelessWidget {
  const AppListRow({
    super.key,
    required this.title,
    this.subtitle,
    this.leading,
    this.trailing,
    this.value,
    this.valueColor,
    this.onTap,
    this.showChevron = true,
  });

  final String title;
  final String? subtitle;

  /// Di solito un [IconSquare].
  final Widget? leading;

  /// Widget libero a destra, al posto di [value].
  final Widget? trailing;

  /// Testo a destra, in evidenza.
  final String? value;
  final Color? valueColor;

  final VoidCallback? onTap;
  final bool showChevron;

  @override
  Widget build(BuildContext context) {
    final AppPalette p = AppPalette.of(context);
    final bool tappable = onTap != null;

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 14, 12),
        child: Row(
          children: <Widget>[
            if (leading != null) ...<Widget>[
              leading!,
              const SizedBox(width: 12),
            ],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Text(title, style: AppText.row.copyWith(color: p.ink)),
                  if (subtitle != null) ...<Widget>[
                    const SizedBox(height: 2),
                    Text(
                      subtitle!,
                      style: AppText.caption.copyWith(color: p.inkFaint),
                    ),
                  ],
                ],
              ),
            ),
            if (value != null) ...<Widget>[
              const SizedBox(width: 12),
              Text(
                value!,
                style: AppText.number(19, color: valueColor ?? p.ink),
              ),
            ],
            if (trailing != null) ...<Widget>[
              const SizedBox(width: 12),
              trailing!,
            ],
            if (tappable && showChevron) ...<Widget>[
              const SizedBox(width: 6),
              Icon(Icons.chevron_right, size: 20, color: p.separator),
            ],
          ],
        ),
      ),
    );
  }
}
