import 'package:flutter/material.dart';

import '../app/tokens.dart';

/// Scheda bianca ad angoli arrotondati: il mattone di quasi tutte le
/// schermate.
///
/// E' volutamente povera di decorazioni. Niente bordi, niente ombre: si
/// distingue dallo sfondo solo perche' e' piu' chiara (o piu' scura, nel tema
/// notturno). Bordi e ombre su ogni blocco appiattiscono la gerarchia e fanno
/// sembrare tutto ugualmente importante.
class AppCard extends StatelessWidget {
  const AppCard({
    super.key,
    required this.child,
    this.onTap,
    this.padding = const EdgeInsets.all(16),
    this.color,
    this.borderRadius = AppRadius.card,
  });

  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry padding;
  final Color? color;
  final double borderRadius;

  @override
  Widget build(BuildContext context) {
    final AppPalette p = AppPalette.of(context);
    final BorderRadius radius = BorderRadius.circular(borderRadius);

    return Material(
      color: color ?? p.surface,
      borderRadius: radius,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        borderRadius: radius,
        child: Padding(padding: padding, child: child),
      ),
    );
  }
}

/// Intestazione di un gruppo di righe, come nelle impostazioni di iOS:
/// piccola, grigia, a filo con il bordo sinistro della scheda sottostante.
class SectionTitle extends StatelessWidget {
  const SectionTitle(this.text, {super.key, this.trailing});

  final String text;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final AppPalette p = AppPalette.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 20, 4, 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: <Widget>[
          Expanded(
            child: Text(
              text.toUpperCase(),
              style: AppText.groupHeader.copyWith(color: p.inkFaint),
            ),
          ),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}

/// Riquadro colorato con l'icona, come quelli a sinistra delle voci nelle
/// impostazioni di iOS.
class IconSquare extends StatelessWidget {
  const IconSquare({
    super.key,
    required this.icon,
    required this.color,
    this.size = 30,
  });

  final IconData icon;
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(AppRadius.small),
      ),
      alignment: Alignment.center,
      child: Icon(icon, size: size * 0.6, color: Colors.white),
    );
  }
}
