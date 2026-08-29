import 'package:flutter/material.dart';

/// Tema Material 3 dell'app.
///
/// Obiettivi: alta leggibilita' durante la corsa (numeri grandi, contrasto
/// alto) e pulsanti generosi, facili da colpire anche in movimento.
///
/// NOTA: qui vengono impostate solo le parti di tema stabili fra le versioni
/// di Flutter (ColorScheme e stili dei pulsanti). Material 3 e' attivo per
/// impostazione predefinita. Lo stile delle card e' definito dal widget
/// riutilizzabile `AppCard`, cosi' il progetto non dipende dalle classi di
/// tema che Flutter ha rinominato nel tempo.
class AppTheme {
  AppTheme._();

  /// Colore di partenza per la palette Material 3.
  static const Color seedColor = Color(0xFF00696D);

  static ThemeData light() => _build(Brightness.light);
  static ThemeData dark() => _build(Brightness.dark);

  static ThemeData _build(Brightness brightness) {
    final ColorScheme scheme = ColorScheme.fromSeed(
      seedColor: seedColor,
      brightness: brightness,
    );

    return ThemeData(
      colorScheme: scheme,
      scaffoldBackgroundColor: scheme.surface,
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size.fromHeight(60),
          textStyle: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.5,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size.fromHeight(56),
          textStyle: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          minimumSize: const Size(64, 48),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }
}

/// Spaziature riutilizzabili in tutta l'app.
class AppSpacing {
  AppSpacing._();
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 16;
  static const double lg = 24;
  static const double xl = 32;
}
