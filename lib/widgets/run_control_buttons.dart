import 'package:flutter/material.dart';

import '../app/tokens.dart';

/// Comandi della corsa: pulsanti tondi, grandi, premibili senza guardare.
///
/// PERCHE' "TERMINA" COMPARE SOLO IN PAUSA
/// ---------------------------------------
/// Mentre corri i pulsanti sono Giro, Pausa e (se stai facendo un
/// allenamento) Salta fase. Termina non c'e': un tocco sbagliato in tasca o
/// con le mani sudate chiuderebbe la registrazione. Per terminare si mette
/// prima in pausa; a quel punto il tempo e' gia' fermo e non si perde niente.
class RunControlButtons extends StatelessWidget {
  const RunControlButtons({
    super.key,
    required this.isRunning,
    required this.isPaused,
    required this.onPause,
    required this.onResume,
    required this.onStop,
    this.onLap,
    this.onSkipStep,
  });

  final bool isRunning;
  final bool isPaused;
  final VoidCallback onPause;
  final VoidCallback onResume;
  final VoidCallback onStop;
  final VoidCallback? onLap;
  final VoidCallback? onSkipStep;

  @override
  Widget build(BuildContext context) {
    final AppPalette p = AppPalette.run;

    if (isPaused) {
      return Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          _RoundButton(
            label: 'Termina',
            icon: Icons.stop_rounded,
            background: p.red,
            foreground: Colors.white,
            diameter: 62,
            onTap: onStop,
          ),
          const SizedBox(width: 26),
          _RoundButton(
            label: 'Riprendi',
            icon: Icons.play_arrow_rounded,
            background: p.green,
            foreground: Colors.black,
            diameter: 78,
            onTap: onResume,
          ),
        ],
      );
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: <Widget>[
        if (onLap != null)
          _RoundButton(
            label: 'Giro',
            icon: Icons.flag_rounded,
            background: p.surfaceElevated,
            foreground: p.ink,
            diameter: 62,
            onTap: isRunning ? onLap! : null,
          ),
        if (onLap != null) const SizedBox(width: 22),
        _RoundButton(
          label: 'Pausa',
          icon: Icons.pause_rounded,
          background: p.orange,
          foreground: Colors.black,
          diameter: 78,
          onTap: isRunning ? onPause : null,
        ),
        if (onSkipStep != null) const SizedBox(width: 22),
        if (onSkipStep != null)
          _RoundButton(
            label: 'Salta',
            icon: Icons.skip_next_rounded,
            background: p.surfaceElevated,
            foreground: p.ink,
            diameter: 62,
            onTap: isRunning ? onSkipStep! : null,
          ),
      ],
    );
  }
}

class _RoundButton extends StatelessWidget {
  const _RoundButton({
    required this.label,
    required this.icon,
    required this.background,
    required this.foreground,
    required this.diameter,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final Color background;
  final Color foreground;
  final double diameter;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final bool enabled = onTap != null;

    return Semantics(
      button: true,
      label: label,
      child: Opacity(
        opacity: enabled ? 1 : 0.4,
        child: Material(
          color: background,
          shape: const CircleBorder(),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            customBorder: const CircleBorder(),
            child: SizedBox(
              width: diameter,
              height: diameter,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  Icon(icon, size: diameter * 0.36, color: foreground),
                  const SizedBox(height: 1),
                  Text(
                    label.toUpperCase(),
                    style: TextStyle(
                      fontSize: 9.5,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.6,
                      color: foreground,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
