/// Colori, misure e stili di testo dell'app: un unico posto da cui passano
/// tutte le schermate.
///
/// PERCHE' NON USARE SOLO IL ColorScheme DI MATERIAL
/// -------------------------------------------------
/// Material genera la palette da un colore "seme": comoda, ma i valori che
/// tira fuori non sono quelli che vogliamo. Qui i colori sono scelti a mano,
/// sulla falsariga dei colori di sistema di iOS, perche' devono restare
/// esattamente questi. Il ColorScheme di Material viene comunque riempito con
/// gli stessi valori (vedi `theme.dart`), cosi' i widget standard - dialoghi,
/// campi di testo, interruttori - restano coerenti.
library;

import 'package:flutter/material.dart';

/// La palette di una singola modalita' (chiara o scura).
class AppPalette {
  const AppPalette({
    required this.background,
    required this.surface,
    required this.surfaceElevated,
    required this.ink,
    required this.inkSoft,
    required this.inkFaint,
    required this.separator,
    required this.accent,
    required this.green,
    required this.orange,
    required this.blue,
    required this.red,
    required this.onAccent,
    required this.isDark,
  });

  /// Sfondo della schermata (grigio chiarissimo, come le impostazioni iOS).
  final Color background;

  /// Sfondo delle schede appoggiate sul [background].
  final Color surface;

  /// Sfondo di un elemento appoggiato sopra una scheda (pillole, pulsanti).
  final Color surfaceElevated;

  /// Testo principale.
  final Color ink;

  /// Testo secondario, ancora leggibile.
  final Color inkSoft;

  /// Etichette e didascalie.
  final Color inkFaint;

  /// Linea di separazione dentro le liste.
  final Color separator;

  /// Colore di identita' dell'app: record, ripetute, evidenziazioni.
  final Color accent;

  /// Testo o icona sopra [accent].
  final Color onAccent;

  /// Verde: sei in ritmo, tutto a posto.
  final Color green;

  /// Arancio: attenzione, sei fuori target, in pausa.
  final Color orange;

  /// Blu: azioni e collegamenti.
  final Color blue;

  /// Rosso: errori e azioni distruttive.
  final Color red;

  final bool isDark;

  /// Palette per il tema chiaro.
  ///
  /// PERCHE' NON E' PIU' BIANCA
  /// --------------------------
  /// La prima versione era quella delle impostazioni iOS: sfondo grigio
  /// chiarissimo (F2F2F7) e schede bianche piene. Su un telefono Android, con
  /// la luminosita' alta, il risultato e' una schermata che e' quasi tutta
  /// bianca - le schede e lo sfondo distano cinque punti di grigio su
  /// duecentocinquanta, cioe' non si distinguono, e quello che si vede e' un
  /// foglio acceso.
  ///
  /// Qui lo sfondo scende di piu' e prende un filo di calore (il grigio
  /// perfettamente neutro, accanto a un accento rosso, legge freddo), e le
  /// schede smettono di essere bianco puro. Lo stacco fra scheda e sfondo
  /// **cresce** - adesso si vede che sono schede - ma la quantita' di bianco
  /// cala. Sono due cose diverse che prima andavano insieme per sbaglio.
  static const AppPalette light = AppPalette(
    background: Color(0xFFE8E4E1),
    surface: Color(0xFFFBFAF9),
    surfaceElevated: Color(0xFFF1EEEC),
    ink: Color(0xFF1A1718),
    inkSoft: Color(0xFF5B5558),
    inkFaint: Color(0xFF8A8286),
    separator: Color(0xFFD6D0CD),
    accent: Color(0xFFE02047),
    onAccent: Color(0xFFFFFFFF),
    green: Color(0xFF1F7A37),
    orange: Color(0xFFB04E00),
    blue: Color(0xFF0066D6),
    red: Color(0xFFD32F26),
    isDark: false,
  );

  /// Palette per il tema scuro.
  static const AppPalette dark = AppPalette(
    background: Color(0xFF000000),
    surface: Color(0xFF1C1C1E),
    surfaceElevated: Color(0xFF2C2C2E),
    ink: Color(0xFFFFFFFF),
    inkSoft: Color(0xFFAEAEB2),
    inkFaint: Color(0xFF8E8E93),
    separator: Color(0xFF38383A),
    accent: Color(0xFFFF375F),
    onAccent: Color(0xFFFFFFFF),
    green: Color(0xFF30D158),
    orange: Color(0xFFFF9F0A),
    blue: Color(0xFF0A84FF),
    red: Color(0xFFFF453A),
    isDark: true,
  );

  /// Palette della schermata di corsa: sempre scura, in qualunque tema.
  ///
  /// Non e' una scelta estetica ma pratica: nero pieno sugli schermi OLED
  /// consuma molto meno, e il bianco su nero si legge al sole meglio di
  /// qualunque altra combinazione.
  static const AppPalette run = dark;

  /// La palette giusta per il tema attualmente in uso.
  static AppPalette of(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark ? dark : light;
}

/// Stili di testo dell'app.
///
/// Il carattere e' Inter (vedi `assets/fonts/`), scelto perche' e' il piu'
/// vicino disponibile liberamente al San Francisco di Apple.
class AppText {
  AppText._();

  static const String fontFamily = 'Inter';

  /// Cifre a larghezza fissa: senza questo i numeri "ballano" mentre corri,
  /// perche' l'1 e' piu' stretto del 7.
  static const List<FontFeature> tabular = <FontFeature>[
    FontFeature.tabularFigures(),
  ];

  /// Titolo grande in cima alla schermata.
  static const TextStyle largeTitle = TextStyle(
    fontSize: 32,
    fontWeight: FontWeight.w800,
    letterSpacing: -1.1,
    height: 1.1,
  );

  /// Titolo di una scheda o di un elemento importante.
  static const TextStyle title = TextStyle(
    fontSize: 19,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.4,
    height: 1.2,
  );

  /// Riga di una lista.
  static const TextStyle row = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w500,
    letterSpacing: -0.2,
  );

  /// Testo corrente.
  static const TextStyle body = TextStyle(
    fontSize: 15,
    fontWeight: FontWeight.w400,
    height: 1.35,
  );

  /// Didascalia sotto una riga.
  static const TextStyle caption = TextStyle(
    fontSize: 13,
    fontWeight: FontWeight.w400,
    height: 1.3,
  );

  /// Etichetta maiuscoletta sopra un numero.
  static const TextStyle label = TextStyle(
    fontSize: 11,
    fontWeight: FontWeight.w700,
    letterSpacing: 0.9,
  );

  /// Intestazione di un gruppo di righe.
  static const TextStyle groupHeader = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.6,
  );

  /// Stile per un numero, di qualunque dimensione.
  ///
  /// La spaziatura negativa cresce con la dimensione: e' quello che rende
  /// "compatti" i numeri grandi di iOS invece che sparpagliati.
  static TextStyle number(double size, {FontWeight? weight, Color? color}) {
    return TextStyle(
      fontSize: size,
      fontWeight: weight ?? FontWeight.w700,
      letterSpacing: -size * 0.045,
      height: 1.0,
      color: color,
      fontFeatures: tabular,
    );
  }
}

/// Raggi degli angoli arrotondati.
class AppRadius {
  AppRadius._();

  /// Schede e gruppi di righe.
  static const double card = 16;

  /// Pillole e piccoli riquadri.
  static const double pill = 999;

  /// Riquadri piccoli (icone quadrate).
  static const double small = 8;
}

/// Spaziature riutilizzabili in tutta l'app.
class AppSpacing {
  AppSpacing._();
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 16;
  static const double lg = 24;
  static const double xl = 32;

  /// Margine laterale standard delle schermate.
  static const double screenSide = 16;
}
