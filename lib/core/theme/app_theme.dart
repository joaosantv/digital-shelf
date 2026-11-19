import 'package:flutter/material.dart';

/// Paleta e configuração visual do tema escuro do Digital Shelf.
class AppTheme {
  AppTheme._();

  /// Cor de fundo principal em grafite profundo.
  static const Color graphiteBackground = Color(0xFF121318);

  /// Superfície elevada para cards e painéis.
  static const Color graphiteSurface = Color(0xFF1C1E26);

  /// Superfície secundária para campos de entrada e contêineres.
  static const Color graphiteSurfaceHigh = Color(0xFF252834);

  /// Roxo escuro para contêineres de destaque secundário.
  static const Color deepPurpleContainer = Color(0xFF2A1B4E);

  /// Roxo vibrante para elementos secundários e chips.
  static const Color accentPurple = Color(0xFF9C6BFF);

  /// Dourado/âmbar como cor primária de marca.
  static const Color amberGold = Color(0xFFFFB300);

  /// Dourado claro para textos e realces sobre superfícies escuras.
  static const Color amberLight = Color(0xFFFFD54F);

  /// Cor de erro com alto contraste sobre fundo escuro.
  static const Color errorRed = Color(0xFFFF6B6B);

  /// Cor indicativa de estado online ou sucesso.
  static const Color successGreen = Color(0xFF4ADE80);

  /// Tema escuro Material 3 aplicado em toda a aplicação.
  static ThemeData get darkTheme {
    const colorScheme = ColorScheme(
      brightness: Brightness.dark,
      primary: amberGold,
      onPrimary: Color(0xFF1A1400),
      primaryContainer: Color(0xFF473300),
      onPrimaryContainer: amberLight,
      secondary: accentPurple,
      onSecondary: Color(0xFF14082E),
      secondaryContainer: deepPurpleContainer,
      onSecondaryContainer: Color(0xFFE5DAFF),
      tertiary: amberLight,
      onTertiary: Color(0xFF1A1400),
      error: errorRed,
      onError: Color(0xFF2B0000),
      surface: graphiteSurface,
      onSurface: Color(0xFFF2F3F7),
      onSurfaceVariant: Color(0xFFB3B7C7),
      outline: Color(0xFF3A3F52),
      outlineVariant: Color(0xFF2A2E3D),
      surfaceContainerHighest: graphiteSurfaceHigh,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: graphiteBackground,
      appBarTheme: const AppBarTheme(
        backgroundColor: graphiteBackground,
        foregroundColor: Color(0xFFF2F3F7),
        elevation: 0,
        centerTitle: false,
      ),
      cardTheme: CardThemeData(
        color: graphiteSurface,
        elevation: 2,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: Color(0xFF2B2F3E), width: 1),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: graphiteSurfaceHigh,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF3A3F52)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF3A3F52)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: amberGold, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: errorRed),
        ),
        labelStyle: const TextStyle(color: Color(0xFFB3B7C7)),
        hintStyle: const TextStyle(color: Color(0xFF7D8296)),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: amberGold,
          foregroundColor: const Color(0xFF1A1400),
          minimumSize: const Size(0, 48),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: const TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: amberGold,
          foregroundColor: const Color(0xFF1A1400),
          minimumSize: const Size(0, 48),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: const TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: amberLight,
          side: const BorderSide(color: Color(0xFF4A4E63)),
          minimumSize: const Size(0, 44),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: graphiteSurfaceHigh,
        selectedColor: deepPurpleContainer,
        labelStyle: const TextStyle(color: Color(0xFFF2F3F7)),
        secondaryLabelStyle: const TextStyle(
          color: amberLight,
          fontWeight: FontWeight.w600,
        ),
        side: const BorderSide(color: Color(0xFF3A3F52)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: graphiteSurface,
        indicatorColor: deepPurpleContainer,
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const TextStyle(
              color: amberLight,
              fontWeight: FontWeight.w600,
              fontSize: 12,
            );
          }
          return const TextStyle(color: Color(0xFFB3B7C7), fontSize: 12);
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const IconThemeData(color: amberGold);
          }
          return const IconThemeData(color: Color(0xFFB3B7C7));
        }),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: graphiteSurfaceHigh,
        contentTextStyle: const TextStyle(color: Color(0xFFF2F3F7)),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: Color(0xFF3A3F52)),
        ),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: amberGold,
        foregroundColor: Color(0xFF1A1400),
      ),
    );
  }
}
