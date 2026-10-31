import 'package:flutter/material.dart';

enum AppThemeMode {
  darkStudio,
  classicBlue,
  cyberNeon,
  lightClean,
}

class ThemeProvider extends ChangeNotifier {
  AppThemeMode _currentTheme = AppThemeMode.darkStudio;

  AppThemeMode get currentTheme => _currentTheme;

  void setTheme(AppThemeMode theme) {
    _currentTheme = theme;
    notifyListeners();
  }

  ThemeData get themeData {
    switch (_currentTheme) {
      case AppThemeMode.darkStudio:
        return _buildDarkStudioTheme();
      case AppThemeMode.classicBlue:
        return _buildClassicBlueTheme();
      case AppThemeMode.cyberNeon:
        return _buildCyberNeonTheme();
      case AppThemeMode.lightClean:
        return _buildLightCleanTheme();
    }
  }

  ThemeData _buildDarkStudioTheme() {
    return ThemeData(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: const Color(0xFF0F172A), // Slate 900
      canvasColor: const Color(0xFF1E293B), // Slate 800
      cardColor: const Color(0xFF1E293B),
      primaryColor: const Color(0xFF6366F1), // Indigo
      colorScheme: const ColorScheme.dark(
        primary: Color(0xFF6366F1),
        secondary: Color(0xFFF59E0B),
        surface: Color(0xFF1E293B),
        error: Color(0xFFEF4444),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Color(0xFF0F172A),
        elevation: 0,
        centerTitle: false,
      ),
      fontFamily: 'Roboto',
    );
  }

  ThemeData _buildClassicBlueTheme() {
    return ThemeData(
      brightness: Brightness.light,
      scaffoldBackgroundColor: const Color(0xFFF1F5F9), // Slate 100
      canvasColor: const Color(0xFFFFFFFF),
      cardColor: const Color(0xFFFFFFFF),
      primaryColor: const Color(0xFF0284C7), // Sky 600
      colorScheme: const ColorScheme.light(
        primary: Color(0xFF0284C7),
        secondary: Color(0xFF0EA5E9),
        surface: Color(0xFFFFFFFF),
        error: Color(0xFFDC2626),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Color(0xFF0284C7),
        elevation: 1,
        foregroundColor: Colors.white,
      ),
      fontFamily: 'Roboto',
    );
  }

  ThemeData _buildCyberNeonTheme() {
    return ThemeData(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: const Color(0xFF05050D),
      canvasColor: const Color(0xFF0D0D1F),
      cardColor: const Color(0xFF14142B),
      primaryColor: const Color(0xFF06B6D4), // Cyan
      colorScheme: const ColorScheme.dark(
        primary: Color(0xFF06B6D4),
        secondary: Color(0xFFF43F5E), // Rose
        surface: Color(0xFF14142B),
        error: Color(0xFFFF0055),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Color(0xFF05050D),
        elevation: 0,
      ),
      fontFamily: 'Roboto',
    );
  }

  ThemeData _buildLightCleanTheme() {
    return ThemeData(
      brightness: Brightness.light,
      scaffoldBackgroundColor: const Color(0xFFF8FAFC),
      canvasColor: const Color(0xFFFFFFFF),
      cardColor: const Color(0xFFFFFFFF),
      primaryColor: const Color(0xFF4F46E5),
      colorScheme: const ColorScheme.light(
        primary: Color(0xFF4F46E5),
        secondary: Color(0xFF10B981),
        surface: Color(0xFFFFFFFF),
        error: Color(0xFFEF4444),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Color(0xFFFFFFFF),
        elevation: 0,
        foregroundColor: Color(0xFF0F172A),
      ),
      fontFamily: 'Roboto',
    );
  }
}
