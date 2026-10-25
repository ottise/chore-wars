import 'package:flutter/material.dart';

class AppTheme {
  static const fontFamily = 'BeVietnamPro';
  static const screenInset = 20.0;
  static const groupGap = 24.0;
  static const itemGap = 12.0;
  static const controlRadius = 12.0;
  static const cardRadius = 16.0;
  static const Color purple = Color(0xFF6845D6);
  static const Color yellow = Color(0xFFFFDDB8);
  static const Color green = Color(0xFF386A43);
  static const Color orange = Color(0xFF825100);
  static const Color red = Color(0xFFBA1A1A);
  static const Color ink = Color(0xFF27232F);
  static const Color muted = Color(0xFF6D6775);
  static const Color canvas = Color(0xFFF8F6F2);

  static const primaryContainer = Color(0xFF6845D6);
  static const onPrimary = Color(0xFFFFFFFF);
  static const lavender = Color(0xFFF0EBFA);
  static const onLavender = Color(0xFF6845D6);
  static const secondary = Color(0xFF6D6775);
  static const secondaryContainer = Color(0xFFF0EBFA);
  static const onAmber = Color(0xFF653E00);
  static const amberContainer = Color(0xFFFFDDB8);
  static const errorContainer = Color(0xFFFFDAD6);
  static const surfaceLowest = Color(0xFFFFFFFF);
  static const surfaceLow = Color(0xFFF5F3F0);
  static const surfaceContainer = Color(0xFFEFEEEB);
  static const surfaceHigh = Color(0xFFEAE8E5);
  static const surfaceHighest = Color(0xFFE4E2DF);
  static const outline = Color(0xFF6D6775);
  static const outlineVariant = Color(0xFFE7E2EA);
  static const successContainer = Color(0xFFD9EADB);

  static const lightColors = ColorScheme(
    brightness: Brightness.light,
    surface: Color(0xFFF8F6F2),
    surfaceDim: Color(0xFFDBDAD7),
    surfaceBright: Color(0xFFF8F6F2),
    surfaceContainerLowest: Color(0xFFFFFFFF),
    surfaceContainerLow: Color(0xFFF5F3F0),
    surfaceContainer: Color(0xFFEFEEEB),
    surfaceContainerHigh: Color(0xFFEAE8E5),
    surfaceContainerHighest: Color(0xFFE4E2DF),
    onSurface: Color(0xFF27232F),
    onSurfaceVariant: Color(0xFF6D6775),
    inverseSurface: Color(0xFF30312F),
    onInverseSurface: Color(0xFFF2F0ED),
    outline: Color(0xFF6D6775),
    outlineVariant: Color(0xFFE7E2EA),
    surfaceTint: Color(0xFF6845D6),
    primary: Color(0xFF6845D6),
    onPrimary: Color(0xFFFFFFFF),
    primaryContainer: Color(0xFF6845D6),
    onPrimaryContainer: Color(0xFFFFFFFF),
    inversePrimary: Color(0xFFF0EBFA),
    secondary: Color(0xFF6D6775),
    onSecondary: Color(0xFFFFFFFF),
    secondaryContainer: Color(0xFFF0EBFA),
    onSecondaryContainer: Color(0xFF27232F),
    tertiary: Color(0xFF6845D6),
    onTertiary: Color(0xFFFFFFFF),
    tertiaryContainer: Color(0xFFF0EBFA),
    onTertiaryContainer: Color(0xFF6845D6),
    error: Color(0xFFBA1A1A),
    onError: Color(0xFFFFFFFF),
    errorContainer: Color(0xFFFFDAD6),
    onErrorContainer: Color(0xFF93000A),
    primaryFixed: Color(0xFFF0EBFA),
    primaryFixedDim: Color(0xFFF0EBFA),
    onPrimaryFixed: Color(0xFF6845D6),
    onPrimaryFixedVariant: Color(0xFF6845D6),
    secondaryFixed: Color(0xFFF0EBFA),
    secondaryFixedDim: Color(0xFFE7E2EA),
    onSecondaryFixed: Color(0xFF27232F),
    onSecondaryFixedVariant: Color(0xFF6D6775),
    tertiaryFixed: Color(0xFFF0EBFA),
    tertiaryFixedDim: Color(0xFFF0EBFA),
    onTertiaryFixed: Color(0xFF6845D6),
    onTertiaryFixedVariant: Color(0xFF6845D6),
  );

  static ThemeData get lightTheme => _build(lightColors);

  static ThemeData get darkTheme => _build(
    ColorScheme.fromSeed(
      seedColor: purple,
      brightness: Brightness.dark,
    ).copyWith(
      surface: const Color(0xFF1D1923),
      surfaceContainerLowest: const Color(0xFF25202C),
      surfaceContainerLow: const Color(0xFF292430),
      primaryContainer: const Color(0xFF6845D6),
      onPrimaryContainer: Colors.white,
    ),
  );

  static ThemeData _build(ColorScheme colors) {
    TextStyle style(double size, FontWeight weight, {bool secondary = false}) =>
        TextStyle(
          fontFamily: fontFamily,
          fontSize: size,
          fontWeight: weight,
          height: size >= 24 ? 1.25 : 1.45,
          color: secondary ? colors.onSurfaceVariant : colors.onSurface,
        );
    final text = TextTheme(
      displayLarge: style(32, FontWeight.w600),
      displayMedium: style(32, FontWeight.w600),
      displaySmall: style(32, FontWeight.w600),
      headlineLarge: style(24, FontWeight.w600),
      headlineMedium: style(24, FontWeight.w600),
      headlineSmall: style(24, FontWeight.w600),
      titleLarge: style(24, FontWeight.w600),
      titleMedium: style(16, FontWeight.w600),
      titleSmall: style(16, FontWeight.w600),
      bodyLarge: style(15, FontWeight.w400),
      bodyMedium: style(14, FontWeight.w400),
      bodySmall: style(12, FontWeight.w400, secondary: true),
      labelLarge: style(14, FontWeight.w500),
      labelMedium: style(13, FontWeight.w500),
      labelSmall: style(12, FontWeight.w400, secondary: true),
    );
    final radius = BorderRadius.circular(controlRadius);
    final shape = RoundedRectangleBorder(borderRadius: radius);
    final border = BorderSide(color: colors.outlineVariant);
    return ThemeData(
      useMaterial3: true,
      colorScheme: colors,
      fontFamily: fontFamily,
      textTheme: text,
      scaffoldBackgroundColor: colors.surface,
      appBarTheme: AppBarTheme(
        centerTitle: false,
        elevation: 0,
        scrolledUnderElevation: 0,
        toolbarHeight: 72,
        backgroundColor: colors.surface,
        foregroundColor: colors.onSurface,
        titleTextStyle: text.titleLarge,
      ),
      cardTheme: CardThemeData(
        color: colors.surfaceContainerLowest,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        margin: EdgeInsets.zero,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(cardRadius),
          side: border,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: colors.surfaceContainerLowest,
        labelStyle: text.bodySmall,
        hintStyle: text.bodyMedium?.copyWith(color: colors.onSurfaceVariant),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 14,
        ),
        border: OutlineInputBorder(borderRadius: radius, borderSide: border),
        enabledBorder: OutlineInputBorder(
          borderRadius: radius,
          borderSide: border,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: radius,
          borderSide: BorderSide(color: colors.primary, width: 1.5),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: colors.primary,
          foregroundColor: colors.onPrimary,
          minimumSize: const Size(48, 48),
          textStyle: text.labelLarge,
          shape: shape,
          elevation: 0,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          elevation: 0,
          backgroundColor: colors.primary,
          foregroundColor: colors.onPrimary,
          minimumSize: const Size(48, 48),
          textStyle: text.labelLarge,
          shape: shape,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(48, 48),
          textStyle: text.labelLarge,
          shape: shape,
          side: border,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          minimumSize: const Size(48, 48),
          textStyle: text.labelLarge,
          shape: shape,
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          minimumSize: const Size(44, 44),
          shape: shape,
          foregroundColor: colors.onSurfaceVariant,
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: colors.primary,
        foregroundColor: colors.onPrimary,
        elevation: 0,
        focusElevation: 0,
        hoverElevation: 0,
        highlightElevation: 0,
        shape: shape,
        extendedTextStyle: text.labelLarge,
      ),
      chipTheme: ChipThemeData(
        backgroundColor: colors.surfaceContainerLowest,
        selectedColor: colors.primaryFixed,
        labelStyle: text.labelMedium,
        side: border,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      ),
      listTileTheme: ListTileThemeData(
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        titleTextStyle: text.titleMedium,
        subtitleTextStyle: text.bodySmall,
        iconColor: colors.onSurfaceVariant,
      ),
      tabBarTheme: TabBarThemeData(
        labelColor: colors.primary,
        unselectedLabelColor: colors.onSurfaceVariant,
        labelStyle: text.labelLarge,
        unselectedLabelStyle: text.labelLarge,
        indicatorColor: colors.primary,
        dividerColor: Colors.transparent,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: colors.surfaceContainerLowest,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        indicatorColor: colors.primaryFixed,
        labelTextStyle: WidgetStatePropertyAll(text.labelSmall),
      ),
      dividerTheme: DividerThemeData(
        color: colors.outlineVariant,
        thickness: 1,
        space: 1,
      ),
      iconTheme: IconThemeData(color: colors.onSurfaceVariant, size: 22),
      dialogTheme: DialogThemeData(
        backgroundColor: colors.surfaceContainerLowest,
        surfaceTintColor: Colors.transparent,
        elevation: 8,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(cardRadius),
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: colors.surfaceContainerLowest,
        surfaceTintColor: Colors.transparent,
        elevation: 8,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(cardRadius),
        ),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: colors.surfaceContainerLowest,
        elevation: 6,
        textStyle: text.bodyMedium,
        shape: shape,
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: colors.inverseSurface,
        contentTextStyle: text.bodyMedium?.copyWith(
          color: colors.onInverseSurface,
        ),
      ),
    );
  }

  static const successColor = green;
  static const warningColor = orange;
  static const dangerColor = red;
}
