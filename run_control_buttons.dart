import 'package:flutter/material.dart';

/// Pulsanti di controllo della corsa.
///
/// Sono volutamente molto grandi (altezza minima 68 px): devono essere
/// premibili senza guardare, mentre si corre.
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
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Row(
          children: <Widget>[
            Expanded(
              child: SizedBox(
                height: 72,
                child: isPaused
                    ? FilledButton.icon(
                        onPressed: onResume,
                        icon: const Icon(Icons.play_arrow, size: 30),
                        label: const Text('RIPRENDI'),
                      )
                    : FilledButton.tonalIcon(
                        onPressed: isRunning ? onPause : null,
                        icon: const Icon(Icons.pause, size: 30),
                        label: const Text('PAUSA'),
                      ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: SizedBox(
                height: 72,
                child: FilledButton.icon(
                  onPressed: onStop,
                  style: FilledButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.error,
                    foregroundColor: Theme.of(context).colorScheme.onError,
                  ),
                  icon: const Icon(Icons.stop, size: 30),
                  label: const Text('TERMINA'),
                ),
              ),
            ),
          ],
        ),
        if (onLap != null || onSkipStep != null) ...<Widget>[
          const SizedBox(height: 12),
          Row(
            children: <Widget>[
              if (onLap != null)
                Expanded(
                  child: SizedBox(
                    height: 60,
                    child: OutlinedButton.icon(
                      onPressed: isRunning ? onLap : null,
                      icon: const Icon(Icons.flag_outlined, size: 26),
                      label: const Text('LAP'),
                    ),
                  ),
                ),
              if (onLap != null && onSkipStep != null)
                const SizedBox(width: 12),
              if (onSkipStep != null)
                Expanded(
                  child: SizedBox(
                    height: 60,
                    child: OutlinedButton.icon(
                      onPressed: isRunning ? onSkipStep : null,
                      icon: const Icon(Icons.skip_next, size: 26),
                      label: const Text('FASE'),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ],
    );
  }
}
