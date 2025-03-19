import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Defines the app's themes (light and dark) and related styling utilities
class AppTheme {
  // Prevent instantiation
  AppTheme._();

  // Color palette - Primary colors
  static const Color _primaryLight = Color(0xFF3C64B1); // Totem blue
  static const Color _primaryDark = Color(
    0xFF4F7CE0,
  ); // Lighter blue for dark mode

  // Color palette - Secondary colors
  static const Color _secondaryLight = Color(0xFF6E8AD8);
  static const Color _secondaryDark = Color(0xFF8AA5F0);

  // Color palette - Background colors
  static const Color _backgroundLight = Color(0xFFF8F9FA);
  static const Color _backgroundDark = Color(0xFF121212);

  // Color palette - Surface colors
  static const Color _surfaceLight = Colors.white;
  static const Color _surfaceDark = Color(0xFF1E1E1E);

  // Text colors
  static const Color _textPrimaryLight = Color(0xFF212121);
  static const Color _textSecondaryLight = Color(0xFF757575);
  static const Color _textPrimaryDark = Color(0xFFEAEAEA);
  static const Color _textSecondaryDark = Color(0xFFB0B0B0);

  // Error colors
  static const Color _errorLight = Color(0xFFD32F2F);
  static const Color _errorDark = Color(0xFFEF5350);

  // Success colors
  static const Color _successLight = Color(0xFF388E3C);
  static const Color _successDark = Color(0xFF4CAF50);

  // Font families
  static const String _fontFamily = 'Inter';

  // Input decoration theme
  static InputDecorationTheme _inputDecorationTheme({required bool isDark}) {
    return InputDecorationTheme(
      filled: true,
      fillColor: isDark ? Colors.black12 : Colors.grey[50],
      contentPadding: const EdgeInsets.all(16),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(
          color: isDark ? Colors.grey[700]! : Colors.grey[300]!,
          width: 1.0,
        ),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(
          color: isDark ? Colors.grey[700]! : Colors.grey[300]!,
          width: 1.0,
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(
          color: isDark ? _primaryDark : _primaryLight,
          width: 2.0,
        ),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(
          color: isDark ? _errorDark : _errorLight,
          width: 1.0,
        ),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(
          color: isDark ? _errorDark : _errorLight,
          width: 2.0,
        ),
      ),
      errorStyle: TextStyle(
        color: isDark ? _errorDark : _errorLight,
        fontSize: 12,
      ),
      labelStyle: TextStyle(
        color: isDark ? Colors.grey[400] : Colors.grey[700],
        fontWeight: FontWeight.w500,
      ),
      hintStyle: TextStyle(
        color: isDark ? Colors.grey[500] : Colors.grey[400],
        fontWeight: FontWeight.w400,
      ),
    );
  }

  // Elevated button theme
  static ElevatedButtonThemeData _elevatedButtonTheme({required bool isDark}) {
    return ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        foregroundColor: Colors.white,
        backgroundColor: isDark ? _primaryDark : _primaryLight,
        elevation: 0,
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        textStyle: const TextStyle(
          fontFamily: _fontFamily,
          fontWeight: FontWeight.w600,
          fontSize: 16,
        ),
      ),
    );
  }

  // Text button theme
  static TextButtonThemeData _textButtonTheme({required bool isDark}) {
    return TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: isDark ? _primaryDark : _primaryLight,
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        textStyle: const TextStyle(
          fontFamily: _fontFamily,
          fontWeight: FontWeight.w600,
          fontSize: 14,
        ),
      ),
    );
  }

  // Card theme
  static CardTheme _cardTheme({required bool isDark}) {
    return CardTheme(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: isDark ? Colors.grey[800]! : Colors.grey[200]!,
          width: 1,
        ),
      ),
      color: isDark ? _surfaceDark : _surfaceLight,
      clipBehavior: Clip.antiAlias,
      margin: const EdgeInsets.all(8),
    );
  }

  // App bar theme
  static AppBarTheme _appBarTheme({required bool isDark}) {
    return AppBarTheme(
      elevation: 0,
      centerTitle: false,
      backgroundColor: isDark ? _backgroundDark : _backgroundLight,
      foregroundColor: isDark ? _textPrimaryDark : _textPrimaryLight,
      iconTheme: IconThemeData(
        color: isDark ? _textPrimaryDark : _textPrimaryLight,
      ),
      systemOverlayStyle:
          isDark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
      titleTextStyle: TextStyle(
        fontFamily: _fontFamily,
        fontWeight: FontWeight.w600,
        fontSize: 20,
        color: isDark ? _textPrimaryDark : _textPrimaryLight,
      ),
    );
  }

  // Light theme
  static final ThemeData lightTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    primaryColor: _primaryLight,
    colorScheme: const ColorScheme.light(
      primary: _primaryLight,
      secondary: _secondaryLight,
      surface: _surfaceLight,
      error: _errorLight,
      onPrimary: Colors.white,
      onSecondary: Colors.white,
      onSurface: _textPrimaryLight,
      onError: Colors.white,
    ),
    scaffoldBackgroundColor: _backgroundLight,
    fontFamily: _fontFamily,
    appBarTheme: _appBarTheme(isDark: false),
    cardTheme: _cardTheme(isDark: false),
    inputDecorationTheme: _inputDecorationTheme(isDark: false),
    elevatedButtonTheme: _elevatedButtonTheme(isDark: false),
    textButtonTheme: _textButtonTheme(isDark: false),
    textTheme: const TextTheme(
      displayLarge: TextStyle(color: _textPrimaryLight),
      displayMedium: TextStyle(color: _textPrimaryLight),
      displaySmall: TextStyle(color: _textPrimaryLight),
      headlineLarge: TextStyle(color: _textPrimaryLight),
      headlineMedium: TextStyle(color: _textPrimaryLight),
      headlineSmall: TextStyle(color: _textPrimaryLight),
      titleLarge: TextStyle(color: _textPrimaryLight),
      titleMedium: TextStyle(color: _textPrimaryLight),
      titleSmall: TextStyle(color: _textPrimaryLight),
      bodyLarge: TextStyle(color: _textPrimaryLight),
      bodyMedium: TextStyle(color: _textPrimaryLight),
      bodySmall: TextStyle(color: _textSecondaryLight),
      labelLarge: TextStyle(color: _textPrimaryLight),
      labelMedium: TextStyle(color: _textSecondaryLight),
      labelSmall: TextStyle(color: _textSecondaryLight),
    ),
    dividerTheme: DividerThemeData(color: Colors.grey[200], thickness: 1),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: _surfaceLight,
      contentTextStyle: const TextStyle(color: _textPrimaryLight),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    ),
  );

  // Dark theme
  static final ThemeData darkTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    primaryColor: _primaryDark,
    colorScheme: const ColorScheme.dark(
      primary: _primaryDark,
      secondary: _secondaryDark,
      surface: _surfaceDark,
      error: _errorDark,
      onPrimary: Colors.black,
      onSecondary: Colors.black,
      onSurface: _textPrimaryDark,
      onError: Colors.black,
    ),
    scaffoldBackgroundColor: _backgroundDark,
    fontFamily: _fontFamily,
    appBarTheme: _appBarTheme(isDark: true),
    cardTheme: _cardTheme(isDark: true),
    inputDecorationTheme: _inputDecorationTheme(isDark: true),
    elevatedButtonTheme: _elevatedButtonTheme(isDark: true),
    textButtonTheme: _textButtonTheme(isDark: true),
    textTheme: const TextTheme(
      displayLarge: TextStyle(color: _textPrimaryDark),
      displayMedium: TextStyle(color: _textPrimaryDark),
      displaySmall: TextStyle(color: _textPrimaryDark),
      headlineLarge: TextStyle(color: _textPrimaryDark),
      headlineMedium: TextStyle(color: _textPrimaryDark),
      headlineSmall: TextStyle(color: _textPrimaryDark),
      titleLarge: TextStyle(color: _textPrimaryDark),
      titleMedium: TextStyle(color: _textPrimaryDark),
      titleSmall: TextStyle(color: _textPrimaryDark),
      bodyLarge: TextStyle(color: _textPrimaryDark),
      bodyMedium: TextStyle(color: _textPrimaryDark),
      bodySmall: TextStyle(color: _textSecondaryDark),
      labelLarge: TextStyle(color: _textPrimaryDark),
      labelMedium: TextStyle(color: _textSecondaryDark),
      labelSmall: TextStyle(color: _textSecondaryDark),
    ),
    dividerTheme: DividerThemeData(color: Colors.grey[800], thickness: 1),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: _surfaceDark,
      contentTextStyle: const TextStyle(color: _textPrimaryDark),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    ),
  );

  // Helper methods for consistent colors
  static Color successColor(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark
        ? _successDark
        : _successLight;
  }

  static Color errorColor(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark
        ? _errorDark
        : _errorLight;
  }
}
