import 'package:flutter/material.dart';

class AppTheme {
  // Imperial Gold & Purple color palette
  static const Color primaryColor = Color(0xFF2D1B4E); // Royal Purple
  static const Color primaryLight = Color(0xFF4A3070); // Light Purple
  static const Color primaryDark = Color(0xFF1A0F2E); // Deep Purple
  
  // Gold colors
  static const Color accentColor = Color(0xFFD4AF37); // Imperial Gold
  static const Color accentLight = Color(0xFFF5D76E); // Light Gold
  static const Color accentDark = Color(0xFFB8960C); // Dark Gold
  
  // Background colors
  static const Color backgroundColor = Color(0xFF1A0F2E); // Deep Purple
  static const Color surfaceColor = Color(0xFF2D1B4E); // Royal Purple
  static const Color cardColor = Color(0xFFFFFBF0); // Warm White
  
  // Functional colors
  static const Color errorColor = Color(0xFFD32F2F);
  static const Color successColor = Color(0xFF2E7D32);
  
  // Text colors
  static const Color textPrimary = Color(0xFF1A1A1A);
  static const Color textSecondary = Color(0xFF5A5A5A);
  static const Color textLight = Color(0xFFFFFFFF);
  static const Color textGold = Color(0xFFD4AF37);
  
  // Additional colors
  static const Color lockedColor = Color(0xFF6B5B7A);
  static const Color unlockedColor = Color(0xFFD4AF37);

  // Imperial Gradients
  static const LinearGradient imperialGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [
      Color(0xFF1A0F2E),
      Color(0xFF2D1B4E),
      Color(0xFF1A0F2E),
      Color(0xFF0D0618),
    ],
    stops: [0.0, 0.4, 0.7, 1.0],
  );

  static const LinearGradient goldGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0xFFB8960C),
      Color(0xFFD4AF37),
      Color(0xFFF5D76E),
      Color(0xFFD4AF37),
    ],
    stops: [0.0, 0.3, 0.7, 1.0],
  );

  static const LinearGradient cardGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0xFFFFFBF0),
      Color(0xFFFFFFFF),
      Color(0xFFFFFBF0),
    ],
  );

  // Text Styles
  static const String fontFamily = 'Cairo';

  static const TextStyle headingLarge = TextStyle(
    fontSize: 32,
    color: textLight,
    fontWeight: FontWeight.bold,
    fontFamily: 'Cairo', // Titles in Amiri
  );

  static const TextStyle headingMedium = TextStyle(
    fontSize: 24,
    fontWeight: FontWeight.bold,
    color: textLight,
    fontFamily: 'Cairo',
  );

  static const TextStyle headingSmall = TextStyle(
    fontSize: 20,
    fontWeight: FontWeight.w600,
    color: textLight,
    fontFamily: 'Cairo',
  );

  static const TextStyle bodyLarge = TextStyle(
    fontSize: 18,
    fontWeight: FontWeight.normal,
    color: textLight,
  );

  static const TextStyle bodyMedium = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.normal,
    color: textLight,
  );

  static const TextStyle buttonText = TextStyle(
    fontSize: 18,
    fontWeight: FontWeight.bold,
    color: primaryDark,
  );

  // Box Decorations
  static BoxDecoration cardDecoration = BoxDecoration(
    gradient: cardGradient,
    borderRadius: BorderRadius.circular(20),
    border: Border.all(color: accentColor.withAlpha(80), width: 1.5),
    boxShadow: [
      BoxShadow(
        color: accentColor.withAlpha(40),
        blurRadius: 20,
        offset: const Offset(0, 8),
      ),
    ],
  );

  static BoxDecoration gradientCardDecoration = BoxDecoration(
    gradient: goldGradient,
    borderRadius: BorderRadius.circular(20),
    boxShadow: [
      BoxShadow(
        color: accentColor.withAlpha(100),
        blurRadius: 20,
        offset: const Offset(0, 8),
      ),
    ],
  );

  // ThemeData
  static ThemeData get lightTheme {
    return ThemeData(
      primaryColor: primaryColor,
      scaffoldBackgroundColor: backgroundColor,
      fontFamily: 'Cairo',
      colorScheme: ColorScheme.fromSeed(
        seedColor: primaryColor,
        primary: primaryColor,
        secondary: accentColor,
        surface: surfaceColor,
        error: errorColor,
        brightness: Brightness.dark,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        foregroundColor: textLight,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.bold,
          color: accentColor,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: accentColor,
          foregroundColor: primaryDark,
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          textStyle: buttonText,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: accentColor,
          side: BorderSide(color: accentColor.withAlpha(150), width: 2),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
      cardTheme: CardThemeData(
        color: cardColor,
        elevation: 8,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
      textTheme: const TextTheme(
        headlineLarge: headingLarge,
        headlineMedium: headingMedium,
        headlineSmall: headingSmall,
        bodyLarge: bodyLarge,
        bodyMedium: bodyMedium,
      ),
      iconTheme: const IconThemeData(
        color: accentColor,
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: accentColor,
      ),
    );
  }
}
