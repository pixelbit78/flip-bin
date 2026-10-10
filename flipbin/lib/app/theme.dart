import 'package:flutter/material.dart';

/// FlipBin dark theme definition.
class FlipBinTheme {
  FlipBinTheme._();

  /// BUG-05/06: minimum tap target for every control. Web on desktop defaults
  /// to compact density + shrink-wrapped targets (32–40 px); pin both so no
  /// screen can render a tappable smaller than 44×44.
  static const double minTap = 44;
  static const Size _minSize = Size(minTap, minTap);
  static const ButtonStyle _minTapStyle = ButtonStyle(
    minimumSize: WidgetStatePropertyAll(_minSize),
    tapTargetSize: MaterialTapTargetSize.padded,
  );

  static ThemeData get dark {
    const primaryBlue = Color(0xFF2196F3);
    const surfaceColor = Color(0xFF1A1D23);
    const cardColor = Color(0xFF252830);

    const colorScheme = ColorScheme.dark(
      primary: primaryBlue,
      surface: surfaceColor,
      onSurface: Colors.white,
      onPrimary: Colors.white,
    );

    return ThemeData(
      visualDensity: VisualDensity.standard,
      materialTapTargetSize: MaterialTapTargetSize.padded,
      iconButtonTheme: const IconButtonThemeData(style: _minTapStyle),
      textButtonTheme: const TextButtonThemeData(style: _minTapStyle),
      outlinedButtonTheme: const OutlinedButtonThemeData(style: _minTapStyle),
      filledButtonTheme: const FilledButtonThemeData(style: _minTapStyle),
      segmentedButtonTheme: const SegmentedButtonThemeData(style: _minTapStyle),
      fontFamily: 'Roboto', // bundled (SPEC §12.8)
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: surfaceColor,
      cardColor: cardColor,
      cardTheme: CardThemeData(
        color: cardColor,
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        enabledBorder: const OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(8)),
          borderSide: BorderSide(color: Colors.white24),
        ),
        focusedBorder: const OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(8)),
          borderSide: BorderSide(color: primaryBlue),
        ),
        filled: true,
        fillColor: cardColor,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: surfaceColor,
        elevation: 0,
        centerTitle: true,
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: cardColor,
        selectedItemColor: primaryBlue,
        unselectedItemColor: Colors.white54,
        type: BottomNavigationBarType.fixed,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryBlue,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          minimumSize: _minSize,
          tapTargetSize: MaterialTapTargetSize.padded,
        ),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: primaryBlue,
        foregroundColor: Colors.white,
      ),
      chipTheme: ChipThemeData(
        backgroundColor: cardColor,
        selectedColor: primaryBlue.withValues(alpha: 0.3),
        labelStyle: const TextStyle(color: Colors.white),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
    );
  }
}
