import 'package:flutter/material.dart';

class AppTheme {
  static const Color purple = Color(0xFF5F3ADD);
  static const Color yellow = Color(0xFFFFDDB8);
  static const Color green = Color(0xFF386A43);
  static const Color orange = Color(0xFF825100);
  static const Color red = Color(0xFFBA1A1A);
  static const Color ink = Color(0xFF1B1C1A);
  static const Color muted = Color(0xFF484555);
  static const Color canvas = Color(0xFFF7F3ED);

  static const primaryContainer = Color(0xFF7857F8);
  static const onPrimary = Color(0xFFFFFFFF);
  static const lavender = Color(0xFFE6DEFF);
  static const onLavender = Color(0xFF4918C8);
  static const secondary = Color(0xFF5F5C6E);
  static const secondaryContainer = Color(0xFFE2DDF3);
  static const onAmber = Color(0xFF653E00);
  static const amberContainer = Color(0xFFFFDDB8);
  static const errorContainer = Color(0xFFFFDAD6);
  static const surfaceLowest = Color(0xFFFFFFFF);
  static const surfaceLow = Color(0xFFF5F3F0);
  static const surfaceContainer = Color(0xFFEFEEEB);
  static const surfaceHigh = Color(0xFFEAE8E5);
  static const surfaceHighest = Color(0xFFE4E2DF);
  static const outline = Color(0xFF797587);
  static const outlineVariant = Color(0xFFC9C4D8);
  static const successContainer = Color(0xFFD9EADB);

  static const lightColors = ColorScheme(
    brightness: Brightness.light,
    surface: Color(0xFFF7F3ED),
    surfaceDim: Color(0xFFDBDAD7),
    surfaceBright: Color(0xFFF7F3ED),
    surfaceContainerLowest: Color(0xFFFFFFFF),
    surfaceContainerLow: Color(0xFFF5F3F0),
    surfaceContainer: Color(0xFFEFEEEB),
    surfaceContainerHigh: Color(0xFFEAE8E5),
    surfaceContainerHighest: Color(0xFFE4E2DF),
    onSurface: Color(0xFF1B1C1A),
    onSurfaceVariant: Color(0xFF484555),
    inverseSurface: Color(0xFF30312F),
    onInverseSurface: Color(0xFFF2F0ED),
    outline: Color(0xFF797587),
    outlineVariant: Color(0xFFC9C4D8),
    surfaceTint: Color(0xFF613DE0),
    primary: Color(0xFF5F3ADD),
    onPrimary: Color(0xFFFFFFFF),
    primaryContainer: Color(0xFF7857F8),
    onPrimaryContainer: Color(0xFFFFFBFF),
    inversePrimary: Color(0xFFCABEFF),
    secondary: Color(0xFF5F5C6E),
    onSecondary: Color(0xFFFFFFFF),
    secondaryContainer: Color(0xFFE2DDF3),
    onSecondaryContainer: Color(0xFF636073),
    tertiary: Color(0xFF825100),
    onTertiary: Color(0xFFFFFFFF),
    tertiaryContainer: Color(0xFFA36700),
    onTertiaryContainer: Color(0xFFFFFBFF),
    error: Color(0xFFBA1A1A),
    onError: Color(0xFFFFFFFF),
    errorContainer: Color(0xFFFFDAD6),
    onErrorContainer: Color(0xFF93000A),
    primaryFixed: Color(0xFFE6DEFF),
    primaryFixedDim: Color(0xFFCABEFF),
    onPrimaryFixed: Color(0xFF1C0062),
    onPrimaryFixedVariant: Color(0xFF4918C8),
    secondaryFixed: Color(0xFFE4E0F5),
    secondaryFixedDim: Color(0xFFC8C4D9),
    onSecondaryFixed: Color(0xFF1B1A29),
    onSecondaryFixedVariant: Color(0xFF474556),
    tertiaryFixed: Color(0xFFFFDDB8),
    tertiaryFixedDim: Color(0xFFFFB95F),
    onTertiaryFixed: Color(0xFF2A1700),
    onTertiaryFixedVariant: Color(0xFF653E00),
  );

  static ThemeData get lightTheme {
    const colorScheme = lightColors;
    return _modernize(
      ThemeData(
        colorScheme: colorScheme,
        scaffoldBackgroundColor: canvas,
        useMaterial3: true,
        textTheme: const TextTheme(
          displaySmall: TextStyle(
            fontSize: 36,
            fontWeight: FontWeight.w800,
            color: ink,
          ),
          headlineSmall: TextStyle(
            fontSize: 26,
            fontWeight: FontWeight.w800,
            color: ink,
          ),
          titleLarge: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: ink,
          ),
          titleMedium: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: ink,
          ),
          bodyLarge: TextStyle(fontSize: 16, height: 1.45, color: ink),
          bodyMedium: TextStyle(fontSize: 14, height: 1.45, color: muted),
        ),
        appBarTheme: const AppBarTheme(
          centerTitle: false,
          elevation: 0,
          scrolledUnderElevation: 0,
          backgroundColor: canvas,
          foregroundColor: ink,
        ),
        navigationBarTheme: NavigationBarThemeData(
          backgroundColor: surfaceLowest,
          indicatorColor: lavender,
          labelTextStyle: const WidgetStatePropertyAll(
            TextStyle(fontWeight: FontWeight.w700, color: ink),
          ),
        ),
        cardTheme: const CardThemeData(
          elevation: 0,
          margin: EdgeInsets.zero,
          color: surfaceLowest,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(16)),
          ),
        ),
      ),
    );
  }

  static ThemeData get darkTheme => _modernize(
    ThemeData(
      colorScheme:
          ColorScheme.fromSeed(
            seedColor: purple,
            brightness: Brightness.dark,
          ).copyWith(
            surface: const Color(0xFF141411),
            surfaceContainerLow: const Color(0xFF1C1C19),
            surfaceContainer: const Color(0xFF20211D),
            surfaceContainerHigh: const Color(0xFF2B2B27),
            surfaceContainerHighest: const Color(0xFF363632),
          ),
      useMaterial3: true,
      appBarTheme: const AppBarTheme(centerTitle: true),
    ),
  );

  static ThemeData _modernize(ThemeData theme) {
    final colors = theme.colorScheme;
    final radius = BorderRadius.circular(12);
    return theme.copyWith(
      visualDensity: VisualDensity.standard,
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: colors.primary,
        foregroundColor: colors.onPrimary,
      ),
      cardTheme: theme.cardTheme.copyWith(
        color: colors.surfaceContainerLowest,
        surfaceTintColor: Colors.transparent,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: BorderSide(color: colors.outlineVariant.withValues(alpha: .35)),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: colors.surfaceContainerLow,
        surfaceTintColor: Colors.transparent,
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: colors.surfaceContainerLow,
        surfaceTintColor: Colors.transparent,
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: colors.inverseSurface,
        contentTextStyle: TextStyle(color: colors.onInverseSurface),
      ),
      iconTheme: IconThemeData(color: colors.onSurfaceVariant),

      appBarTheme: theme.appBarTheme.copyWith(
        centerTitle: false,
        elevation: 0,
        scrolledUnderElevation: 0,
        titleTextStyle: TextStyle(
          color: colors.onSurface,
          fontSize: 20,
          fontWeight: FontWeight.w700,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: colors.surfaceContainerLowest,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
        border: OutlineInputBorder(
          borderRadius: radius,
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: radius,
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: radius,
          borderSide: BorderSide(color: colors.primary, width: 1.5),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(48, 48),
          shape: RoundedRectangleBorder(borderRadius: radius),
          elevation: 0,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(48, 48),
          shape: RoundedRectangleBorder(borderRadius: radius),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          minimumSize: const Size(48, 48),
          shape: RoundedRectangleBorder(borderRadius: radius),
        ),
      ),
      dividerTheme: DividerThemeData(
        color: colors.outlineVariant.withValues(alpha: .5),
        thickness: .7,
        space: 1,
      ),
      listTileTheme: ListTileThemeData(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        titleTextStyle: TextStyle(
          color: colors.onSurface,
          fontSize: 15,
          fontWeight: FontWeight.w600,
        ),
        subtitleTextStyle: TextStyle(
          color: colors.onSurfaceVariant,
          fontSize: 13,
          height: 1.5,
        ),
      ),
      tabBarTheme: TabBarThemeData(
        labelColor: colors.onSurface,
        unselectedLabelColor: colors.onSurfaceVariant,
        labelStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
        dividerColor: Colors.transparent,
        indicatorColor: colors.primary,
      ),
    );
  }

  static const successColor = green;
  static const warningColor = orange;
  static const dangerColor = red;
}
