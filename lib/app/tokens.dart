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
  // TEMA "NOTTE" (versione 2.11).
  //
  // Scelto fra tre proposte disegnate sulla stessa schermata vera (la soglia
  // 2 x 1,6 km): fondo quasi nero, un solo colore acceso - giallo lime - per
  // quello che conta (i tratti di lavoro, il pulsante principale), numeri
  // grandi in un carattere stretto da tabellone sportivo. Il chiaro resta per
  // chi lo sceglie, con lo stesso disegno: il lime su fondo bianco non si
  // legge, li' l'accento diventa un verde oliva scuro della stessa famiglia.
  static const AppPalette light = AppPalette(
    background: Color(0xFFF4F4F1),
    surface: Color(0xFFFFFFFF),
    surfaceElevated: Color(0xFFECECE8),
    ink: Color(0xFF0E0F11),
    inkSoft: Color(0xFF4A4F55),
    inkFaint: Color(0xFF6E7379),
    separator: Color(0xFFE1E2DD),
    accent: Color(0xFF557300),
    onAccent: Color(0xFFFFFFFF),
    green: Color(0xFF1F7A37),
    orange: Color(0xFFB04E00),
    blue: Color(0xFF1F4FD1),
    red: Color(0xFFC62828),
    isDark: false,
  );

  static const AppPalette dark = AppPalette(
    background: Color(0xFF0E0F11),
    surface: Color(0xFF17191C),
    surfaceElevated: Color(0xFF22252A),
    ink: Color(0xFFF2F3F5),
    inkSoft: Color(0xFFB9BEC4),
    inkFaint: Color(0xFF8B9096),
    separator: Color(0xFF26292E),
    accent: Color(0xFFD4FF3A),
    // Sul lime il bianco non si legge: il testo sopra l'accento e' scuro.
    onAccent: Color(0xFF0E0F11),
    green: Color(0xFF3DDC84),
    orange: Color(0xFFFFB020),
    blue: Color(0xFF8EA8FF),
    red: Color(0xFFFF6B5E),
    isDark: true,
  );

  static const AppPalette run = dark;

  /// La palette giusta per il tema attualmente in uso.
  /// Il colore del testo o dell'icona da mettere SOPRA [sfondo].
  ///
  /// Prima era sempre bianco, e andava bene finche' i colori pieni erano
  /// rossi e blu scuri. Con il lime e i verdi chiari del tema Notte il bianco
  /// sparisce: qui si sceglie fra quasi-nero e bianco guardando quanto e'
  /// chiaro lo sfondo.
  Color on(Color sfondo) => sfondo.computeLuminance() > 0.4
      ? const Color(0xFF0E0F11)
      : const Color(0xFFFFFFFF);

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

  /// Il carattere dei numeri grandi: stretto, da tabellone sportivo. Le
  /// cifre stanno in meno spazio, quindi si possono fare piu' grandi.
  static const String numberFamily = 'BarlowCondensed';

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
    // Barlow Condensed ha due pesi nel pacchetto, 500 e 600: chi chiede
    // grassetto (700 e oltre) riceve il 600, chi chiede meno riceve il 500.
    final FontWeight w = weight ?? FontWeight.w600;
    return TextStyle(
      fontFamily: numberFamily,
      // Un carattere stretto a parita' di corpo sembra piu' piccolo: un
      // po' piu' grande riporta i numeri alla presenza di prima.
      fontSize: size * 1.08,
      fontWeight: w.index >= FontWeight.w600.index
          ? FontWeight.w600
          : FontWeight.w500,
      letterSpacing: -size * 0.01,
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
