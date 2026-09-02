import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// App-wide Material 3 themes (light + dark) for all platforms.
class AppTheme {
  AppTheme._();

  // Deep navy-blue brand palette.
  static const _seed = Color(0xFF1D4ED8); // blue-700
  static const _navyDark = Color(0xFF0A1628);
  static const _navyCard = Color(0xFF112240);
  static const _navyElevated = Color(0xFF1A3055);
  static const _navySurfaceLow = Color(0xFF0D1E36);
  static const _iceLight = Color(0xFFF0F4FA);
  static const _iceCard = Color(0xFFFFFFFF);
  static const _iceSurfaceLow = Color(0xFFE8EEF8);
  static const _iceSurfaceHigh = Color(0xFFDCE6F5);

  static ThemeData get light => _build(Brightness.light);

  static ThemeData get dark => _build(Brightness.dark);

  static ThemeData _build(Brightness brightness) {
    final scheme = ColorScheme.fromSeed(
      seedColor: _seed,
      brightness: brightness,
    );

    final isDark = brightness == Brightness.dark;
    final surface = isDark ? _navyDark : _iceLight;
    final card = isDark ? _navyCard : _iceCard;

    final refined = scheme.copyWith(
      primary: isDark ? const Color(0xFF3B82F6) : const Color(0xFF1D4ED8),
      onPrimary: Colors.white,
      primaryContainer: isDark
          ? const Color(0xFF1E3A8A)
          : const Color(0xFFDBEAFE),
      onPrimaryContainer:
          isDark ? const Color(0xFFBFDBFE) : const Color(0xFF1E3A8A),
      secondary: isDark ? const Color(0xFF60A5FA) : const Color(0xFF2563EB),
      tertiary: isDark ? const Color(0xFF38BDF8) : const Color(0xFF0284C7),
      surface: surface,
      surfaceContainerLowest: surface,
      surfaceContainerLow: isDark ? _navySurfaceLow : _iceSurfaceLow,
      surfaceContainer: card,
      surfaceContainerHigh: isDark ? _navyElevated : _iceSurfaceHigh,
      outlineVariant: isDark
          ? const Color(0xFF2A4A73)
          : const Color(0xFFC5D4EA),
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: refined,
      scaffoldBackgroundColor: surface,
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: FadeUpwardsPageTransitionsBuilder(),
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
          TargetPlatform.linux: FadeUpwardsPageTransitionsBuilder(),
          TargetPlatform.macOS: CupertinoPageTransitionsBuilder(),
          TargetPlatform.windows: FadeUpwardsPageTransitionsBuilder(),
        },
      ),
      textTheme: _textTheme(refined, isDark),
      appBarTheme: AppBarTheme(
        centerTitle: false,
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: Colors.transparent,
        foregroundColor: refined.onSurface,
        systemOverlayStyle: isDark
            ? SystemUiOverlayStyle.light
            : SystemUiOverlayStyle.dark,
        titleTextStyle: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          letterSpacing: -0.3,
          color: refined.onSurface,
        ),
      ),
      cardTheme: CardThemeData(
        elevation: isDark ? 0 : 1,
        shadowColor: isDark
            ? Colors.transparent
            : const Color(0xFF1D4ED8).withValues(alpha: 0.08),
        color: card,
        surfaceTintColor: refined.primary.withValues(alpha: 0.05),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(
            color: refined.outlineVariant.withValues(
              alpha: isDark ? 0.45 : 0.55,
            ),
          ),
        ),
        margin: EdgeInsets.zero,
      ),
      navigationBarTheme: NavigationBarThemeData(
        elevation: 0,
        height: 72,
        backgroundColor: isDark ? _navySurfaceLow : _iceCard,
        indicatorColor: refined.primary.withValues(alpha: 0.16),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return TextStyle(
            fontSize: 12,
            fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
            letterSpacing: 0.1,
          );
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return IconThemeData(
            size: 24,
            color: selected ? refined.primary : refined.onSurfaceVariant,
          );
        }),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(48, 48),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(48, 48),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: isDark
            ? refined.surfaceContainerHigh.withValues(alpha: 0.5)
            : refined.surfaceContainerLow,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(
            color: refined.outlineVariant.withValues(alpha: 0.6),
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: refined.primary, width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
      ),
      listTileTheme: ListTileThemeData(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
      dividerTheme: DividerThemeData(
        color: refined.outlineVariant.withValues(alpha: 0.45),
        space: 1,
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: ButtonStyle(
          visualDensity: VisualDensity.comfortable,
          shape: WidgetStatePropertyAll(
            RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: card,
        surfaceTintColor: refined.primary.withValues(alpha: 0.05),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
      ),
    );
  }

  static TextTheme _textTheme(ColorScheme scheme, bool isDark) {
    final base = isDark ? Typography.whiteMountainView : Typography.blackMountainView;
    return base.copyWith(
      headlineSmall: base.headlineSmall?.copyWith(
        fontWeight: FontWeight.w700,
        letterSpacing: -0.5,
        color: scheme.onSurface,
      ),
      titleLarge: base.titleLarge?.copyWith(
        fontWeight: FontWeight.w700,
        letterSpacing: -0.4,
        color: scheme.onSurface,
      ),
      titleMedium: base.titleMedium?.copyWith(
        fontWeight: FontWeight.w600,
        letterSpacing: -0.2,
        color: scheme.onSurface,
      ),
      bodyMedium: base.bodyMedium?.copyWith(
        color: scheme.onSurfaceVariant,
        height: 1.45,
      ),
      labelLarge: base.labelLarge?.copyWith(
        fontWeight: FontWeight.w600,
        letterSpacing: 0.2,
      ),
    );
  }
}
