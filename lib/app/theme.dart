import 'package:flutter/material.dart';

import 'tokens.dart';

/// Tema dell'app.
///
/// I colori veri stanno in `tokens.dart`: qui vengono solo travasati dentro il
/// ColorScheme di Material, cosi' anche i widget standard (dialoghi, campi di
/// testo, interruttori, SnackBar) usano la stessa palette senza doverli
/// personalizzare uno per uno.
///
/// NOTA per chi mette mano al file: qui si impostano solo parti di tema
/// stabili fra le versioni di Flutter. Le classi `CardTheme`, `AppBarTheme` e
/// simili sono state rinominate piu' volte, quindi non le usiamo: l'aspetto
/// delle schede e' definito dai nostri widget in `lib/widgets/`.
class AppTheme {
  AppTheme._();

  static ThemeData light() => _build(AppPalette.light);
  static ThemeData dark() => _build(AppPalette.dark);

  static ThemeData _build(AppPalette p) {
    final ColorScheme scheme = ColorScheme.fromSeed(
      seedColor: p.accent,
      brightness: p.isDark ? Brightness.dark : Brightness.light,
    ).copyWith(
      primary: p.accent,
      onPrimary: p.onAccent,
      secondary: p.blue,
      onSecondary: Colors.white,
      error: p.red,
      onError: Colors.white,
      surface: p.surface,
      onSurface: p.ink,
      onSurfaceVariant: p.inkSoft,
      surfaceContainerHighest: p.surfaceElevated,
      outlineVariant: p.separator,
    );

    return ThemeData(
      colorScheme: scheme,
      fontFamily: AppText.fontFamily,
      scaffoldBackgroundColor: p.background,
      dividerColor: p.separator,
      splashFactory: InkSparkle.splashFactory,

      // I pulsanti restano generosi: vanno colpiti anche correndo.
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size.fromHeight(54),
          textStyle: const TextStyle(
            fontFamily: AppText.fontFamily,
            fontSize: 17,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.2,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.card),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size.fromHeight(52),
          foregroundColor: p.blue,
          side: BorderSide(color: p.separator),
          textStyle: const TextStyle(
            fontFamily: AppText.fontFamily,
            fontSize: 16,
            fontWeight: FontWeight.w600,
            letterSpacing: -0.2,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.card),
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: p.blue,
          minimumSize: const Size(64, 46),
          textStyle: const TextStyle(
            fontFamily: AppText.fontFamily,
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}
