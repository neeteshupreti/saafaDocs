import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'palette.dart';

/// Spacing scale (8 / 16 / 24 dp grid).
class Gap {
  static const s = 8.0, m = 16.0, l = 24.0;
}

class AppTheme {
  static ThemeData light() => _build(Brightness.light);
  static ThemeData dark() => _build(Brightness.dark);

  static ThemeData _build(Brightness b) {
    final dark = b == Brightness.dark;
    final bg = dark ? Palette.bgDark : Palette.bgLight;
    final surface = dark ? Palette.surfaceDark : Palette.surfaceLight;
    final text = dark ? Palette.textDark : Palette.textLight;
    final muted = dark ? Palette.mutedDark : Palette.mutedLight;
    final border = dark ? const Color(0xFF262A33) : const Color(0xFFE5E7EB);

    final scheme = ColorScheme(
      brightness: b,
      primary: Palette.primary,
      onPrimary: Colors.white,
      secondary: Palette.secondary,
      onSecondary: Colors.white,
      error: dark ? const Color(0xFFF87171) : const Color(0xFFB91C1C),
      onError: dark ? Palette.bgDark : Colors.white,
      surface: surface,
      onSurface: text,
      outline: border,
      onSurfaceVariant: muted,
    );

    final base = ThemeData(brightness: b, useMaterial3: true, colorScheme: scheme);
    final tt = GoogleFonts.interTextTheme(base.textTheme).apply(bodyColor: text, displayColor: text);
    final textTheme = tt.copyWith(
      titleLarge: tt.titleLarge?.copyWith(fontWeight: FontWeight.w700),
      titleMedium: tt.titleMedium?.copyWith(fontWeight: FontWeight.w600),
      labelLarge: tt.labelLarge?.copyWith(fontWeight: FontWeight.w500),
      bodyMedium: tt.bodyMedium?.copyWith(fontWeight: FontWeight.w400),
      bodySmall: tt.bodySmall?.copyWith(color: muted),
    );

    const shape = RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(12)));
    return base.copyWith(
      scaffoldBackgroundColor: bg,
      textTheme: textTheme,
      dividerColor: border,
      appBarTheme: AppBarTheme(
        backgroundColor: bg,
        foregroundColor: text,
        elevation: 0,
        scrolledUnderElevation: 0,
        titleTextStyle: textTheme.titleLarge,
      ),
      cardTheme: CardThemeData(
        color: surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: border),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(minimumSize: const Size(48, 48), shape: shape,
            textStyle: textTheme.labelLarge),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(minimumSize: const Size(48, 48), shape: shape,
            foregroundColor: text, side: BorderSide(color: border)),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(minimumSize: const Size(48, 48), shape: shape,
            foregroundColor: text),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: Palette.primary,
        foregroundColor: Colors.white,
        elevation: 2,
        extendedTextStyle: TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: surface,
        selectedColor: Palette.primary,
        side: BorderSide(color: border),
        labelStyle: textTheme.labelLarge,
        secondaryLabelStyle: textTheme.labelLarge?.copyWith(color: Colors.white),
        checkmarkColor: Colors.white,
        showCheckmark: false,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surface,
        hintStyle: TextStyle(color: muted),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: border)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: border)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Palette.primary, width: 2)),
      ),
      sliderTheme: const SliderThemeData(activeTrackColor: Palette.primary, thumbColor: Palette.primary),
      switchTheme: SwitchThemeData(
        trackColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? Palette.primary : border),
        thumbColor: const WidgetStatePropertyAll(Colors.white),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: Palette.primary, linearTrackColor: border, linearMinHeight: 4),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: surface, surfaceTintColor: Colors.transparent,
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24)))),
      dialogTheme: DialogThemeData(backgroundColor: surface, surfaceTintColor: Colors.transparent, shape: shape),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: text,
        contentTextStyle: textTheme.bodyMedium?.copyWith(color: bg),
        actionTextColor: dark ? Palette.primary : const Color(0xFF93B4FF),
        shape: shape,
      ),
    );
  }
}
