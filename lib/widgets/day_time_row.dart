import 'package:flutter/material.dart';

import '../app/tokens.dart';
import '../models/weekly_availability.dart';

/// Una riga: il giorno e quanto tempo hai.
///
/// Niente slider e niente finestre: il meno sempre a sinistra, il piu' sempre
/// a destra, il valore in mezzo. La settimana si imposta in pochi tocchi
/// stando in piedi, che e' come verra' usata davvero.
///
/// PERCHE' STA IN UN FILE A PARTE
/// ------------------------------
/// Perche' la settimana si dichiara in due posti: quando si crea il piano, e
/// quando una singola settimana fa eccezione per i turni. Due righe disegnate
/// due volte diventano due righe che si comportano in modo diverso - un passo
/// da 15 minuti qui e da 10 la', un minimo diverso - e l'atleta non capisce
/// perche'. Una sola riga, usata da entrambe.
class DayTimeRow extends StatelessWidget {
  const DayTimeRow({
    super.key,
    required this.weekday,
    required this.minutes,
    required this.isLong,
    required this.isQuality,
    required this.onChanged,
  });

  final int weekday;
  final int minutes;

  /// `true` se e' qui che cade il lungo.
  final bool isLong;

  /// `true` se e' uno dei giorni di qualita'.
  final bool isQuality;

  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final AppPalette p = AppPalette.of(context);
    final bool runs = minutes >= WeeklyAvailability.minUsefulMinutes;

    String? ruolo;
    if (isLong) {
      ruolo = 'lungo';
    } else if (isQuality) {
      ruolo = 'qualita\'';
    }

    return SizedBox(
      height: 46,
      child: Row(
        children: <Widget>[
          SizedBox(
            width: 92,
            child: Text(
              WeeklyAvailability.dayName(weekday),
              style: AppText.body.copyWith(
                color: runs ? p.ink : p.inkFaint,
                fontWeight: runs ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
          ),
          if (ruolo != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
              decoration: BoxDecoration(
                color: p.accent.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(AppRadius.pill),
              ),
              child: Text(
                ruolo,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: p.accent,
                ),
              ),
            ),
          const Spacer(),
          IconButton(
            visualDensity: VisualDensity.compact,
            onPressed: minutes <= 0
                ? null
                : () => onChanged(minutes - WeeklyAvailability.stepMinutes),
            icon: Icon(Icons.remove_circle_outline,
                size: 22, color: minutes <= 0 ? p.separator : p.inkSoft),
          ),
          SizedBox(
            width: 62,
            child: Text(
              WeeklyAvailability.formatMinutes(runs ? minutes : 0),
              textAlign: TextAlign.center,
              style: AppText.number(
                15,
                color: runs ? p.ink : p.inkFaint,
              ),
            ),
          ),
          IconButton(
            visualDensity: VisualDensity.compact,
            onPressed: minutes >= WeeklyAvailability.maxMinutes
                ? null
                : () => onChanged(minutes < WeeklyAvailability.minMinutes
                    ? WeeklyAvailability.minMinutes + 25
                    : minutes + WeeklyAvailability.stepMinutes),
            icon: Icon(Icons.add_circle_outline,
                size: 22,
                color: minutes >= WeeklyAvailability.maxMinutes
                    ? p.separator
                    : p.accent),
          ),
        ],
      ),
    );
  }
}
