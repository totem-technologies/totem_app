import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Defines the app's themes (light and dark) and related styling utilities
class AppTheme {
  const AppTheme._();

  // Primary palette colors from image
  static const Color _creme = Color(0xFFF3F1E9);
  static const Color _yellow = Color(0xFFF4D092);
  static const Color _mauve = Color(0xFF987AA5);
  static const Color _slate = Color(0xFF262F37);

  // Secondary palette colors from image
  static const Color _deepGray = Color(0xFF514F4D);
  static const Color _blue = Color(0xFF95C0DD);
  static const Color _blueTint = Color(0xFF55778F);
  // static const Color _pink = Color(0xFFD99BAA);
  // static const Color _pinkTint = Color(0xFF8B5363);

  static const Color _primaryLight = _mauve;
  static const Color _primaryDark = _blueTint;

  static const Color _secondaryLight = _yellow;
  static const Color _secondaryDark = _blue;

  static const Color _backgroundLight = _creme;
  static const Color _backgroundDark = _slate;

  static const Color _surfaceLight = Colors.white;
  static const Color _surfaceDark = _deepGray;

  static const Color _textPrimaryLight = _slate;
  static const Color _textSecondaryLight = _deepGray;
  static const Color _textPrimaryDark = _creme;
  static const Color _textSecondaryDark = _blue;

  static const Color _errorLight = Color(0xFFD32F2F);
  static const Color _errorDark = Color(0xFFEF5350);

  static const Color _successLight = Color(0xFF388E3C);
  static const Color _successDark = Color(0xFF4CAF50);

  static const Color _onPrimaryLight = _creme; // Text on Mauve
  static const Color _onPrimaryDark = _creme; // Text on Blue Tint
  static const Color _onSecondaryLight = _slate; // Text on Yellow
  static const Color _onSecondaryDark = _slate; // Text on Blue
  static const Color _onBackgroundLight = _slate; // Text on Creme
  static const Color _onBackgroundDark = _creme; // Text on Slate
  static const Color _onSurfaceLight = _slate; // Text on White
  static const Color _onSurfaceDark = _creme; // Text on Deep Gray
  static const Color _onErrorLight = Colors.white; // Text on Error Red
  static const Color _onErrorDark = Colors.black; // Text on Error Light Red

  static const String _fontFamily = 'Inter';

  static InputDecorationTheme _inputDecorationTheme({required bool isDark}) {
    final Color primary = isDark ? _primaryDark : _primaryLight;
    final Color onSurface = isDark ? _onSurfaceDark : _onSurfaceLight;
    final Color outlineColor = isDark ? Colors.grey[700]! : Colors.grey[300]!;
    final Color errorColor = isDark ? _errorDark : _errorLight;
    final Color fillColor =
        isDark
            ? Colors.black12
            : Colors
                .grey[50]!; // Maybe adjust fillColor based on new palette? Using grey for now.
    final Color hintColor =
        isDark
            ? Colors.grey[500]!
            : Colors.grey[400]!; // Maybe adjust hintColor based on new palette?

    return InputDecorationTheme(
      filled: true,
      fillColor: fillColor,
      contentPadding: const EdgeInsets.all(16),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: outlineColor, width: 1.0),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: outlineColor, width: 1.0),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(
          color: primary, // Use theme primary
          width: 2.0,
        ),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: errorColor, width: 1.0),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: errorColor, width: 2.0),
      ),
      errorStyle: TextStyle(color: errorColor, fontSize: 12),
      labelStyle: TextStyle(
        // Use secondary text color for labels? Or a dimmed primary?
        color: isDark ? _textSecondaryDark : _textSecondaryLight,
        fontWeight: FontWeight.w500,
      ),
      hintStyle: TextStyle(
        color: hintColor, // Keep hint distinct, maybe map later
        fontWeight: FontWeight.w400,
      ),
    );
  }

  // Elevated button theme - Updated for new colors
  static ElevatedButtonThemeData _elevatedButtonTheme({required bool isDark}) {
    final Color backgroundColor = isDark ? _primaryDark : _primaryLight;
    final Color foregroundColor = isDark ? _onPrimaryDark : _onPrimaryLight;

    return ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        foregroundColor: foregroundColor, // Text color ON the button
        backgroundColor: backgroundColor, // Button background color
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

  // Text button theme - Updated for new colors
  static TextButtonThemeData _textButtonTheme({required bool isDark}) {
    final Color foregroundColor = isDark ? _primaryDark : _primaryLight;

    return TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: foregroundColor, // Use primary color for text
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

  // Card theme - Updated for new colors
  static CardTheme _cardTheme({required bool isDark}) {
    final Color cardColor = isDark ? _surfaceDark : _surfaceLight;
    // Use a subtle border color, maybe a slightly darker/lighter shade of the background/surface
    final Color borderColor =
        isDark
            ? Colors.grey[800]!
            : Colors.grey[200]!; // Keep original subtle border for now

    return CardTheme(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: borderColor, width: 1),
      ),
      color: cardColor, // Use surface color for cards
      clipBehavior: Clip.antiAlias,
      margin: const EdgeInsets.all(8),
    );
  }

  // App bar theme - Updated for new colors
  static AppBarTheme _appBarTheme({required bool isDark}) {
    final Color backgroundColor = isDark ? _backgroundDark : Colors.white;
    final Color foregroundColor =
        isDark ? _onBackgroundDark : _onBackgroundLight;

    return AppBarTheme(
      elevation: 0,
      centerTitle: false,
      backgroundColor: backgroundColor,
      foregroundColor: foregroundColor,
      iconTheme: IconThemeData(color: foregroundColor),
      systemOverlayStyle:
          isDark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
      surfaceTintColor: Colors.transparent,
      titleTextStyle: TextStyle(
        fontFamily: _fontFamily,
        fontWeight: FontWeight.w600,
        fontSize: 20,
        color: foregroundColor,
      ),
    );
  }

  static final ThemeData lightTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    primaryColor: _primaryLight,
    colorScheme: const ColorScheme.light(
      primary: _primaryLight,
      secondary: _secondaryLight,
      surface: _surfaceLight,
      error: _errorLight,
      onPrimary: _onPrimaryLight,
      onSecondary: _onSecondaryLight,
      onSurface: _onSurfaceLight,
      onError: _onErrorLight,
    ),
    scaffoldBackgroundColor: _backgroundLight,
    fontFamily: _fontFamily,
    appBarTheme: _appBarTheme(isDark: false),
    cardTheme: _cardTheme(isDark: false),
    inputDecorationTheme: _inputDecorationTheme(isDark: false),
    elevatedButtonTheme: _elevatedButtonTheme(isDark: false),
    textButtonTheme: _textButtonTheme(isDark: false),
    textTheme: TextTheme(
      displayLarge: const TextStyle().copyWith(color: _textPrimaryLight),
      displayMedium: const TextStyle().copyWith(color: _textPrimaryLight),
      displaySmall: const TextStyle().copyWith(color: _textPrimaryLight),
      headlineLarge: const TextStyle().copyWith(color: _textPrimaryLight),
      headlineMedium: const TextStyle().copyWith(color: _textPrimaryLight),
      headlineSmall: const TextStyle().copyWith(color: _textPrimaryLight),
      titleLarge: const TextStyle().copyWith(color: _textPrimaryLight),
      titleMedium: const TextStyle().copyWith(color: _textPrimaryLight),
      titleSmall: const TextStyle().copyWith(color: _textPrimaryLight),
      bodyLarge: const TextStyle().copyWith(color: _textPrimaryLight),
      bodyMedium: const TextStyle().copyWith(color: _textPrimaryLight),
      bodySmall: const TextStyle().copyWith(color: _textSecondaryLight),
      labelLarge: const TextStyle().copyWith(color: _textPrimaryLight),
      labelMedium: const TextStyle().copyWith(color: _textSecondaryLight),
      labelSmall: const TextStyle().copyWith(color: _textSecondaryLight),
    ).apply(fontFamily: _fontFamily),
    dividerTheme: DividerThemeData(color: Colors.grey[300], thickness: 1),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: _surfaceLight,
      contentTextStyle: const TextStyle(color: _onSurfaceLight),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    ),
    buttonTheme: ButtonThemeData(
      buttonColor: _primaryLight,
      textTheme: ButtonTextTheme.primary,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    ),
  );

  // Dark theme - Updated with new ColorScheme
  static final ThemeData darkTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    primaryColor: _primaryDark,
    colorScheme: const ColorScheme.dark(
      primary: _primaryDark,
      secondary: _secondaryDark,
      surface: _surfaceDark,
      error: _errorDark,
      onPrimary: _onPrimaryDark,
      onSecondary: _onSecondaryDark,
      onSurface: _onSurfaceDark, // Primary text on surface
      onError: _onErrorDark,
    ),
    scaffoldBackgroundColor: _backgroundDark,
    fontFamily: _fontFamily,
    appBarTheme: _appBarTheme(isDark: true),
    cardTheme: _cardTheme(isDark: true),
    inputDecorationTheme: _inputDecorationTheme(isDark: true),
    elevatedButtonTheme: _elevatedButtonTheme(isDark: true),
    textButtonTheme: _textButtonTheme(isDark: true),
    textTheme: TextTheme(
      // Define text styles using the new text colors
      displayLarge: const TextStyle().copyWith(color: _textPrimaryDark),
      displayMedium: const TextStyle().copyWith(color: _textPrimaryDark),
      displaySmall: const TextStyle().copyWith(color: _textPrimaryDark),
      headlineLarge: const TextStyle().copyWith(color: _textPrimaryDark),
      headlineMedium: const TextStyle().copyWith(color: _textPrimaryDark),
      headlineSmall: const TextStyle().copyWith(color: _textPrimaryDark),
      titleLarge: const TextStyle().copyWith(color: _textPrimaryDark),
      titleMedium: const TextStyle().copyWith(color: _textPrimaryDark),
      titleSmall: const TextStyle().copyWith(color: _textPrimaryDark),
      bodyLarge: const TextStyle().copyWith(color: _textPrimaryDark),
      bodyMedium: const TextStyle().copyWith(color: _textPrimaryDark),
      bodySmall: const TextStyle().copyWith(color: _textSecondaryDark),
      labelLarge: const TextStyle().copyWith(color: _textPrimaryDark),
      labelMedium: const TextStyle().copyWith(color: _textSecondaryDark),
      labelSmall: const TextStyle().copyWith(color: _textSecondaryDark),
    ).apply(fontFamily: _fontFamily),
    dividerTheme: DividerThemeData(color: Colors.grey[700], thickness: 1),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: _surfaceDark,
      contentTextStyle: const TextStyle(color: _onSurfaceDark),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    ),
    buttonTheme: ButtonThemeData(
      buttonColor: _primaryDark,
      textTheme: ButtonTextTheme.primary,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    ),
  );

  // Helper methods for consistent colors (Still useful)
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
