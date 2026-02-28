import 'package:flutter/material.dart';
import 'package:translate_reader/features/reader/presentation/reader_home_page.dart';

class TranslateReaderApp extends StatefulWidget {
  const TranslateReaderApp({super.key});

  @override
  State<TranslateReaderApp> createState() => _TranslateReaderAppState();
}

class _TranslateReaderAppState extends State<TranslateReaderApp> {
  ThemeMode _themeMode = ThemeMode.light;

  void _handleThemeModeChanged(ThemeMode mode) {
    if (_themeMode == mode) {
      return;
    }

    setState(() {
      _themeMode = mode;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Читалка с переводом',
      debugShowCheckedModeBanner: false,
      themeMode: _themeMode,
      theme: _buildLightTheme(),
      darkTheme: _buildDarkTheme(),
      home: ReaderHomePage(
        themeMode: _themeMode,
        onThemeModeChanged: _handleThemeModeChanged,
      ),
    );
  }
}

ThemeData _buildLightTheme() {
  const ColorScheme colorScheme = ColorScheme(
    brightness: Brightness.light,
    primary: Color(0xFF3F6E6A),
    onPrimary: Color(0xFFF7F4EC),
    primaryContainer: Color(0xFFBFD8D0),
    onPrimaryContainer: Color(0xFF16302E),
    secondary: Color(0xFFBF7A54),
    onSecondary: Color(0xFFFDF7F1),
    secondaryContainer: Color(0xFFF1D5C4),
    onSecondaryContainer: Color(0xFF472513),
    tertiary: Color(0xFF7B8F5C),
    onTertiary: Color(0xFFF7FAF1),
    tertiaryContainer: Color(0xFFDCE8C8),
    onTertiaryContainer: Color(0xFF253117),
    error: Color(0xFFB3261E),
    onError: Colors.white,
    errorContainer: Color(0xFFF9DEDC),
    onErrorContainer: Color(0xFF410E0B),
    surface: Color(0xFFF6F1E8),
    onSurface: Color(0xFF1F2523),
    surfaceContainerHighest: Color(0xFFE4DDD2),
    onSurfaceVariant: Color(0xFF4B5754),
    outline: Color(0xFF7A8581),
    outlineVariant: Color(0xFFCACFC8),
    shadow: Color(0xFF000000),
    scrim: Color(0xFF000000),
    inverseSurface: Color(0xFF2D3331),
    onInverseSurface: Color(0xFFF1F0EB),
    inversePrimary: Color(0xFFA6CDC1),
    surfaceTint: Color(0xFF3F6E6A),
  );

  return ThemeData(
    useMaterial3: true,
    colorScheme: colorScheme,
    scaffoldBackgroundColor: colorScheme.surface,
    appBarTheme: AppBarTheme(
      centerTitle: false,
      elevation: 0,
      backgroundColor: colorScheme.surface,
      foregroundColor: colorScheme.onSurface,
      surfaceTintColor: Colors.transparent,
    ),
    cardTheme: CardThemeData(
      color: Colors.white.withValues(alpha: 0.72),
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        elevation: 0,
        minimumSize: const Size.fromHeight(56),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size.fromHeight(52),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      ),
    ),
    chipTheme: ChipThemeData(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      side: BorderSide.none,
      backgroundColor: colorScheme.surfaceContainerHighest,
      selectedColor: colorScheme.primaryContainer,
      labelStyle: TextStyle(color: colorScheme.onSurface),
    ),
  );
}

ThemeData _buildDarkTheme() {
  const ColorScheme colorScheme = ColorScheme(
    brightness: Brightness.dark,
    primary: Color(0xFF9BC7BE),
    onPrimary: Color(0xFF12312D),
    primaryContainer: Color(0xFF234843),
    onPrimaryContainer: Color(0xFFD2E9E2),
    secondary: Color(0xFFE2B694),
    onSecondary: Color(0xFF41210F),
    secondaryContainer: Color(0xFF5B3620),
    onSecondaryContainer: Color(0xFFF9DDC6),
    tertiary: Color(0xFFC4D7A4),
    onTertiary: Color(0xFF2A371B),
    tertiaryContainer: Color(0xFF414F2E),
    onTertiaryContainer: Color(0xFFE0EDCD),
    error: Color(0xFFF2B8B5),
    onError: Color(0xFF601410),
    errorContainer: Color(0xFF8C1D18),
    onErrorContainer: Color(0xFFF9DEDC),
    surface: Color(0xFF11181A),
    onSurface: Color(0xFFE8EFEA),
    surfaceContainerHighest: Color(0xFF33403E),
    onSurfaceVariant: Color(0xFFC1CBC7),
    outline: Color(0xFF8B9692),
    outlineVariant: Color(0xFF414C49),
    shadow: Color(0xFF000000),
    scrim: Color(0xFF000000),
    inverseSurface: Color(0xFFE8EFEA),
    onInverseSurface: Color(0xFF27302E),
    inversePrimary: Color(0xFF3F6E6A),
    surfaceTint: Color(0xFF9BC7BE),
  );

  return ThemeData(
    useMaterial3: true,
    colorScheme: colorScheme,
    scaffoldBackgroundColor: colorScheme.surface,
    appBarTheme: AppBarTheme(
      centerTitle: false,
      elevation: 0,
      backgroundColor: colorScheme.surface,
      foregroundColor: colorScheme.onSurface,
      surfaceTintColor: Colors.transparent,
    ),
    cardTheme: CardThemeData(
      color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.42),
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        elevation: 0,
        minimumSize: const Size.fromHeight(56),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size.fromHeight(52),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      ),
    ),
    chipTheme: ChipThemeData(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      side: BorderSide.none,
      backgroundColor: colorScheme.surfaceContainerHighest,
      selectedColor: colorScheme.primaryContainer,
      labelStyle: TextStyle(color: colorScheme.onSurface),
    ),
  );
}
