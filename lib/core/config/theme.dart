import 'dart:ui' as ui;

import 'package:flutter/material.dart';

/// This was generated based on the css.
class AppTheme {
  const AppTheme._();

  // --- Colors ---
  // Extracted from the @theme block in styles.css
  static const Color cream = Color(0xFFF3F1E9);
  static const Color yellow = Color(0xFFF4DC92);
  static const Color mauve = Color(0xFF987AA5);
  static const Color slate = Color(0xFF262F37);
  static const Color deepGray = Color(0xFF514F4D);
  static const Color blue = Color(0xFF9BC0DD);
  static const Color blueTint = Color(0xFF55778F);
  static const Color pink = Color(0xFFD999AA);
  static const Color pinkTint = Color(0xFF8B5363);

  // Basic Colors
  static const Color white = Colors.white;
  static const Color black = Colors.black;
  static const Color transparent = Colors.transparent;
  static const Color grey = Colors.grey;

  // --- Font Families ---
  // Extracted from the @theme block in styles.css
  static const String fontFamilySans = 'Montserrat';
  static const String fontFamilySerif =
      'Erode'; // Note: Ensure 'Erode' font is added to pubspec.yaml

  // --- ThemeData ---
  static ThemeData get lightTheme => ThemeData(
    brightness: Brightness.light,
    primaryColor: mauve,
    scaffoldBackgroundColor: cream,
    fontFamily: fontFamilySans, // Default font family
    // --- Color Scheme ---
    colorScheme: ColorScheme(
      brightness: Brightness.light,
      primary: mauve,
      onPrimary: white, // Based on btn-primary text color
      secondary: yellow, // Using yellow as a secondary/accent color
      onSecondary: slate,
      error: pinkTint, // Using pinkTint as error color
      onError: white,
      surface: cream, // Surfaces like Cards, Dialogs
      onSurface: slate, // Text/icons on surfaces
      tertiary: blue, // Using blue as tertiary
      onTertiary: slate,
      primaryContainer: const Color(0xFFEBDDED), // Lighter shade of mauve
      onPrimaryContainer: const Color(0xFF2E1F36),
      secondaryContainer: const Color(0xFFFDF1B9), // Lighter shade of yellow
      onSecondaryContainer: const Color(0xFF413A2A),
      tertiaryContainer: const Color(0xFFE1EEF8), // Lighter shade of blue
      onTertiaryContainer: const Color(0xFF24333E),
      errorContainer: const Color(0xFFF3DEE3), // Lighter shade of pinkTint
      onErrorContainer: const Color(0xFF3A2127),
      surfaceContainerHighest: const Color(
        0xFFEBEAE3,
      ), // Slightly different surface color
      onSurfaceVariant: deepGray, // Text/icons on variant surfaces
      outline: deepGray,
      outlineVariant: const Color(0xFFCFCBC4), // Lighter outline
      shadow: black,
      scrim: black.withValues(alpha: 0.5),
      inverseSurface: slate,
      onInverseSurface: cream,
      inversePrimary: const Color(
        0xFFDDC5E6,
      ), // Mauve for dark theme use (approx)
      surfaceTint: mauve, // Color overlaid on surfaces to indicate elevation
    ),

    // --- Text Theme ---
    // Defined using fontFamilySans primarily, inspired by h1/h2/h3 utilities
    textTheme: const TextTheme(
      // Display styles (Large headlines)
      displayLarge: TextStyle(
        fontFamily: fontFamilySans,
        fontSize: 57,
        fontWeight: FontWeight.w600,
        color: slate,
      ), // Approx h1 md:text-6xl font-semibold
      displayMedium: TextStyle(
        fontFamily: fontFamilySans,
        fontSize: 45,
        fontWeight: FontWeight.w600,
        color: slate,
      ), // Approx h1 text-4xl font-semibold
      displaySmall: TextStyle(
        fontFamily: fontFamilySans,
        fontSize: 36,
        fontWeight: FontWeight.w600,
        color: slate,
      ),

      // Headline styles (Standard headlines)
      headlineLarge: TextStyle(
        fontFamily: fontFamilySans,
        fontSize: 32,
        fontWeight: FontWeight.w500,
        color: slate,
      ), // Approx h2 text-4xl font-medium
      headlineMedium: TextStyle(
        fontFamily: fontFamilySans,
        fontSize: 28,
        fontWeight: FontWeight.w500,
        color: slate,
      ), // Approx h3 text-2xl font-medium
      headlineSmall: TextStyle(
        fontFamily: fontFamilySans,
        fontSize: 24,
        fontWeight: FontWeight.w500,
        color: slate,
      ),

      // Title styles (Slightly smaller than headlines)
      titleLarge: TextStyle(
        fontFamily: fontFamilySans,
        fontSize: 22,
        fontWeight: FontWeight.w500,
        color: slate,
      ),
      titleMedium: TextStyle(
        fontFamily: fontFamilySans,
        fontSize: 16,
        fontWeight: FontWeight.w500,
        color: deepGray,
      ),
      titleSmall: TextStyle(
        fontFamily: fontFamilySans,
        fontSize: 14,
        fontWeight: FontWeight.w500,
        color: deepGray,
      ),

      // Body styles (Standard text)
      bodyLarge: TextStyle(
        fontFamily: fontFamilySans,
        fontSize: 16,
        fontWeight: FontWeight.normal,
        color: slate,
      ),
      bodyMedium: TextStyle(
        fontFamily: fontFamilySans,
        fontSize: 14,
        fontWeight: FontWeight.normal,
        color: deepGray,
      ), // Default Text() style
      bodySmall: TextStyle(
        fontFamily: fontFamilySans,
        fontSize: 12,
        fontWeight: FontWeight.normal,
        color: deepGray,
      ),

      // Label styles (Buttons, captions, input labels)
      labelLarge: TextStyle(
        fontFamily: fontFamilySans,
        fontSize: 14,
        fontWeight: FontWeight.w500,
        color: white,
      ), // For ElevatedButtons
      labelMedium: TextStyle(
        fontFamily: fontFamilySans,
        fontSize: 12,
        fontWeight: FontWeight.w500,
        color: deepGray,
      ), // Input labels
      labelSmall: TextStyle(
        fontFamily: fontFamilySans,
        fontSize: 11,
        fontWeight: FontWeight.w500,
        color: deepGray,
      ), // Captions
    ).apply(bodyColor: slate, displayColor: slate),

    // --- App Bar Theme ---
    appBarTheme: const AppBarTheme(
      backgroundColor: cream,
      foregroundColor: black,
      elevation: 2,
      titleTextStyle: TextStyle(
        fontFamily: fontFamilySans,
        fontSize: 20,
        fontWeight: FontWeight.w500,
        color: black,
      ),
      iconTheme: IconThemeData(color: black),
      actionsIconTheme: IconThemeData(color: black),
      surfaceTintColor: Colors.transparent,
    ),

    // --- Button Themes ---
    buttonTheme: const ButtonThemeData(
      buttonColor: mauve,
      textTheme: ButtonTextTheme.primary,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(8)),
      ),
    ),

    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        surfaceTintColor: Colors.transparent,
        backgroundColor: mauve,
        foregroundColor: white,
        textStyle: const TextStyle(
          fontFamily: fontFamilySans,
          fontWeight: FontWeight.w600,
          fontSize: 21,
          height: 1.2,
          letterSpacing: 0,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        padding: const EdgeInsetsDirectional.symmetric(horizontal: 16),
        elevation: 0,
        minimumSize: const Size(20, 56),
      ),
    ),

    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: blueTint,
        textStyle: const TextStyle(
          fontFamily: fontFamilySans,
          fontWeight: FontWeight.w500,
          decoration: TextDecoration.underline,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    ),

    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: mauve,
        side: const BorderSide(color: mauve),
        textStyle: const TextStyle(
          fontFamily: fontFamilySans,
          fontWeight: FontWeight.w600,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        padding: const EdgeInsetsDirectional.symmetric(
          horizontal: 16,
          vertical: 12,
        ),
        minimumSize: const Size(20, 48),
      ),
    ),

    // --- Input Decoration Theme ---
    // Based on input/textarea styles
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: const Color(0xFFD9D9D9),
      contentPadding: const EdgeInsetsDirectional.symmetric(
        horizontal: 16,
        vertical: 12,
      ),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(20),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(20),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(20),
        borderSide: BorderSide.none,
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(20),
        borderSide: const BorderSide(color: pinkTint, width: 1.5),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(20),
        borderSide: const BorderSide(color: pinkTint, width: 2),
      ),
      labelStyle: const TextStyle(
        fontFamily: fontFamilySans,
        fontSize: 14,
        fontWeight: FontWeight.w500,
        color: deepGray,
      ),
      hintStyle: TextStyle(
        fontFamily: fontFamilySans,
        fontSize: 14,
        fontWeight: FontWeight.normal,
        color: deepGray.withValues(alpha: 0.7),
      ),
      errorStyle: const TextStyle(
        fontFamily: fontFamilySans,
        fontSize: 12,
        fontWeight: FontWeight.normal,
        color: pinkTint,
      ),
    ),

    // --- Card Theme ---
    cardTheme: CardThemeData(
      color: white,
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      margin: const EdgeInsetsDirectional.symmetric(
        horizontal: 20,
        vertical: 20,
      ),
    ),

    // --- Dialog Theme ---
    dialogTheme: DialogThemeData(
      backgroundColor: const Color(0xFFF3F1E9),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
      titleTextStyle: const TextStyle(
        fontFamily: fontFamilySans,
        fontSize: 21,
        fontWeight: FontWeight.w600,
        color: slate,
      ),
      contentTextStyle: const TextStyle(
        fontFamily: fontFamilySans,
        fontSize: 16,
        fontWeight: FontWeight.normal,
        color: deepGray,
      ),
    ),

    // --- Divider Theme ---
    dividerTheme: DividerThemeData(
      color: deepGray.withValues(alpha: 0.3),
      thickness: 1,
      space: 1,
    ),

    // --- Chip Theme ---
    chipTheme: ChipThemeData(
      backgroundColor: cream.withValues(alpha: 0.8),
      disabledColor: grey.withValues(alpha: 0.5),
      selectedColor: mauve.withValues(alpha: 0.2),
      secondarySelectedColor: yellow.withValues(alpha: 0.3),
      padding: const EdgeInsetsDirectional.symmetric(
        horizontal: 12,
        vertical: 8,
      ),
      labelStyle: const TextStyle(
        fontFamily: fontFamilySans,
        color: deepGray,
        fontWeight: FontWeight.w500,
      ),
      secondaryLabelStyle: const TextStyle(
        fontFamily: fontFamilySans,
        color: slate,
        fontWeight: FontWeight.w500,
      ),
      brightness: Brightness.light,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      side: BorderSide.none,
    ),

    // --- Icon Theme ---
    iconTheme: const IconThemeData(color: deepGray, size: 24),
    primaryIconTheme: const IconThemeData(color: mauve),

    // --- Checkbox Theme ---
    checkboxTheme: CheckboxThemeData(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(100)),
      materialTapTargetSize: MaterialTapTargetSize.padded,
      side: const BorderSide(color: mauve, width: 1.5),
      visualDensity: VisualDensity.compact,
    ),

    // --- SnackBar Theme ---
    snackBarTheme: SnackBarThemeData(
      backgroundColor: cream,
      contentTextStyle: const TextStyle(
        fontFamily: fontFamilySans,
        fontSize: 16,
        fontWeight: FontWeight.w500,
        color: white,
      ),
      actionTextColor: mauve,
      behavior: SnackBarBehavior.floating,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(20)),
      ),
      insetPadding: const EdgeInsets.all(20),
      width:
          ui.PlatformDispatcher.instance.views.first.physicalSize.width.clamp(
            100,
            600,
          ) -
          40,
    ),

    /// --- Bottom Navigation Bar Theme ---
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      indicatorColor: Colors.transparent,
      labelTextStyle: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return const TextStyle(
            fontFamily: fontFamilySans,
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: mauve,
          );
        } else {
          return const TextStyle(
            fontFamily: fontFamilySans,
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: deepGray,
          );
        }
      }),
    ),

    useMaterial3: true,

    pageTransitionsTheme: const PageTransitionsTheme(
      builders: <TargetPlatform, PageTransitionsBuilder>{
        // Set the predictive back transitions for Android.
        TargetPlatform.android: PredictiveBackPageTransitionsBuilder(),
      },
    ),
  );
}
