import 'package:flutter/cupertino.dart' show CupertinoPageTransitionsBuilder;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'app_tokens.dart';

/// Thème global construit à partir de la couleur d'accent choisie par
/// l'utilisateur. Boutons, champs, dialogues, feuilles, interrupteurs… sont
/// stylés ici une seule fois : les écrans n'ont rien à redéfinir.
abstract final class AppTheme {
  static const fontFamily = 'Inter';

  static Color onColor(Color color) =>
      ThemeData.estimateBrightnessForColor(color) == Brightness.dark ? Colors.white : Colors.black;

  static ThemeData dark(Color accent) {
    final onAccent = onColor(accent);

    final colorScheme = ColorScheme.fromSeed(seedColor: accent, brightness: Brightness.dark).copyWith(
      primary: accent,
      onPrimary: onAccent,
      primaryContainer: accent.withValues(alpha: 0.18),
      onPrimaryContainer: AppColors.textPrimary,
      secondary: accent,
      onSecondary: onAccent,
      secondaryContainer: accent.withValues(alpha: 0.18),
      onSecondaryContainer: AppColors.textPrimary,
      surface: AppColors.surface,
      onSurface: AppColors.textPrimary,
      onSurfaceVariant: AppColors.textSecondary,
      surfaceContainerLowest: AppColors.background,
      surfaceContainerLow: AppColors.surface,
      surfaceContainer: AppColors.surface,
      surfaceContainerHigh: AppColors.surfaceHigh,
      surfaceContainerHighest: AppColors.surfaceHighest,
      outline: AppColors.borderStrong,
      outlineVariant: AppColors.border,
      error: AppColors.danger,
    );

    final base = ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: colorScheme,
      fontFamily: fontFamily,
    );

    TextStyle? t(TextStyle? s, {double? size, FontWeight? weight, double? spacing, Color? color, double? height}) =>
        s?.copyWith(
          fontFamily: fontFamily,
          fontSize: size,
          fontWeight: weight,
          letterSpacing: spacing,
          color: color,
          height: height,
        );

    final b = base.textTheme;
    final textTheme = TextTheme(
      displayLarge: t(b.displayLarge, size: 64, weight: FontWeight.w800, spacing: -2.5, color: AppColors.textPrimary, height: 1),
      displayMedium: t(b.displayMedium, size: 48, weight: FontWeight.w800, spacing: -2, color: AppColors.textPrimary, height: 1),
      displaySmall: t(b.displaySmall, size: 36, weight: FontWeight.w800, spacing: -1.4, color: AppColors.textPrimary, height: 1.05),
      headlineLarge: t(b.headlineLarge, size: 32, weight: FontWeight.w800, spacing: -1.2, color: AppColors.textPrimary),
      headlineMedium: t(b.headlineMedium, size: 28, weight: FontWeight.w800, spacing: -1, color: AppColors.textPrimary),
      headlineSmall: t(b.headlineSmall, size: 22, weight: FontWeight.w700, spacing: -0.6, color: AppColors.textPrimary),
      titleLarge: t(b.titleLarge, size: 19, weight: FontWeight.w700, spacing: -0.4, color: AppColors.textPrimary),
      titleMedium: t(b.titleMedium, size: 16, weight: FontWeight.w600, spacing: -0.2, color: AppColors.textPrimary),
      titleSmall: t(b.titleSmall, size: 14, weight: FontWeight.w600, spacing: -0.1, color: AppColors.textPrimary),
      bodyLarge: t(b.bodyLarge, size: 16, weight: FontWeight.w400, spacing: -0.1, color: AppColors.textPrimary, height: 1.4),
      bodyMedium: t(b.bodyMedium, size: 14, weight: FontWeight.w400, spacing: -0.05, color: AppColors.textSecondary, height: 1.4),
      bodySmall: t(b.bodySmall, size: 12.5, weight: FontWeight.w400, spacing: 0, color: AppColors.textSecondary, height: 1.35),
      labelLarge: t(b.labelLarge, size: 15, weight: FontWeight.w600, spacing: -0.1, color: AppColors.textPrimary),
      labelMedium: t(b.labelMedium, size: 12.5, weight: FontWeight.w600, spacing: 0, color: AppColors.textSecondary),
      labelSmall: t(b.labelSmall, size: 11, weight: FontWeight.w700, spacing: 0.9, color: AppColors.textTertiary),
    );

    final roundedMd = RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md));
    const buttonPadding = EdgeInsets.symmetric(horizontal: 20, vertical: 15);
    final buttonText = textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700);

    OutlineInputBorder inputBorder(Color color, [double width = 1]) => OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: BorderSide(color: color, width: width),
        );

    return base.copyWith(
      scaffoldBackgroundColor: AppColors.background,
      canvasColor: AppColors.background,
      textTheme: textTheme,
      primaryTextTheme: textTheme,
      splashFactory: InkSparkle.splashFactory,
      highlightColor: Colors.transparent,
      hoverColor: Colors.white.withValues(alpha: 0.04),
      dividerTheme: const DividerThemeData(color: AppColors.border, thickness: 1, space: 1),
      iconTheme: const IconThemeData(color: AppColors.textSecondary, size: 22),
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.background,
        surfaceTintColor: Colors.transparent,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: textTheme.titleLarge,
        systemOverlayStyle: const SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.light,
          statusBarBrightness: Brightness.dark,
          systemNavigationBarColor: Colors.black,
          systemNavigationBarIconBrightness: Brightness.light,
        ),
      ),
      cardTheme: CardThemeData(
        color: AppColors.surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
          side: const BorderSide(color: AppColors.border),
        ),
      ),
      listTileTheme: ListTileThemeData(
        iconColor: AppColors.textSecondary,
        contentPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
        minVerticalPadding: AppSpacing.md,
        titleTextStyle: textTheme.titleMedium?.copyWith(fontSize: 15.5),
        subtitleTextStyle: textTheme.bodySmall,
        leadingAndTrailingTextStyle: textTheme.bodyMedium,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(padding: buttonPadding, shape: roundedMd, textStyle: buttonText),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          elevation: 0,
          backgroundColor: accent,
          foregroundColor: onAccent,
          padding: buttonPadding,
          shape: roundedMd,
          textStyle: buttonText,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.textPrimary,
          side: const BorderSide(color: AppColors.borderStrong),
          padding: buttonPadding,
          shape: roundedMd,
          textStyle: buttonText,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: accent,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          shape: roundedMd,
          textStyle: buttonText,
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(foregroundColor: AppColors.textSecondary),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: accent,
        foregroundColor: onAccent,
        elevation: 0,
        focusElevation: 0,
        hoverElevation: 0,
        highlightElevation: 0,
        extendedTextStyle: buttonText,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.lg)),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white.withValues(alpha: 0.05),
        hintStyle: textTheme.bodyLarge?.copyWith(color: AppColors.textTertiary),
        labelStyle: textTheme.bodyLarge?.copyWith(color: AppColors.textSecondary),
        floatingLabelStyle: textTheme.bodyMedium?.copyWith(color: accent, fontWeight: FontWeight.w600),
        helperStyle: textTheme.bodySmall?.copyWith(color: AppColors.textTertiary),
        prefixIconColor: AppColors.textTertiary,
        suffixIconColor: AppColors.textTertiary,
        contentPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.lg),
        border: inputBorder(Colors.transparent),
        enabledBorder: inputBorder(AppColors.border),
        focusedBorder: inputBorder(accent, 1.5),
        errorBorder: inputBorder(AppColors.danger),
        focusedErrorBorder: inputBorder(AppColors.danger, 1.5),
      ),
      textSelectionTheme: TextSelectionThemeData(
        cursorColor: accent,
        selectionColor: accent.withValues(alpha: 0.35),
        selectionHandleColor: accent,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: AppColors.surfaceHigh,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.xl),
          side: const BorderSide(color: AppColors.border),
        ),
        titleTextStyle: textTheme.titleLarge,
        contentTextStyle: textTheme.bodyMedium,
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: AppColors.surfaceHigh,
        surfaceTintColor: Colors.transparent,
        modalBackgroundColor: AppColors.surfaceHigh,
        showDragHandle: true,
        dragHandleColor: AppColors.borderStrong,
        dragHandleSize: Size(36, 4),
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColors.surfaceHighest,
        contentTextStyle: textTheme.titleSmall,
        actionTextColor: accent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
        elevation: 0,
        insetPadding: const EdgeInsets.fromLTRB(AppSpacing.lg, 0, AppSpacing.lg, 96),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: Colors.white.withValues(alpha: 0.05),
        selectedColor: accent.withValues(alpha: 0.2),
        side: const BorderSide(color: AppColors.border),
        labelStyle: textTheme.labelMedium?.copyWith(color: AppColors.textPrimary),
        secondaryLabelStyle: textTheme.labelMedium?.copyWith(color: AppColors.textPrimary),
        checkmarkColor: accent,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: AppSpacing.xs),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.pill)),
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: SegmentedButton.styleFrom(
          selectedBackgroundColor: accent.withValues(alpha: 0.2),
          selectedForegroundColor: AppColors.textPrimary,
          foregroundColor: AppColors.textSecondary,
          side: const BorderSide(color: AppColors.border),
          textStyle: textTheme.labelMedium,
        ),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? onAccent : AppColors.textSecondary,
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? accent : AppColors.surfaceHighest,
        ),
        trackOutlineColor: const WidgetStatePropertyAll(Colors.transparent),
      ),
      sliderTheme: SliderThemeData(
        activeTrackColor: accent,
        inactiveTrackColor: Colors.white.withValues(alpha: 0.1),
        thumbColor: Colors.white,
        overlayColor: accent.withValues(alpha: 0.15),
        trackHeight: 4,
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: accent,
        linearTrackColor: Colors.white.withValues(alpha: 0.08),
        circularTrackColor: Colors.transparent,
      ),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: AppColors.surfaceHighest,
          borderRadius: BorderRadius.circular(AppRadius.xs),
        ),
        textStyle: textTheme.labelMedium?.copyWith(color: AppColors.textPrimary),
      ),
      datePickerTheme: DatePickerThemeData(
        backgroundColor: AppColors.surfaceHigh,
        surfaceTintColor: Colors.transparent,
        headerBackgroundColor: AppColors.surfaceHigh,
        headerForegroundColor: AppColors.textPrimary,
        todayForegroundColor: WidgetStatePropertyAll(accent),
        todayBorder: BorderSide(color: accent, width: 1.5),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.xl)),
        cancelButtonStyle: TextButton.styleFrom(foregroundColor: AppColors.textSecondary),
        confirmButtonStyle: TextButton.styleFrom(foregroundColor: accent),
      ),
      timePickerTheme: TimePickerThemeData(
        backgroundColor: AppColors.surfaceHigh,
        dialBackgroundColor: AppColors.surface,
        dialHandColor: accent,
        hourMinuteColor: AppColors.surface,
        hourMinuteTextColor: AppColors.textPrimary,
        entryModeIconColor: AppColors.textSecondary,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.xl)),
        cancelButtonStyle: TextButton.styleFrom(foregroundColor: AppColors.textSecondary),
        confirmButtonStyle: TextButton.styleFrom(foregroundColor: accent),
      ),
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: FadeForwardsPageTransitionsBuilder(),
          TargetPlatform.windows: FadeForwardsPageTransitionsBuilder(),
          TargetPlatform.linux: FadeForwardsPageTransitionsBuilder(),
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
          TargetPlatform.macOS: CupertinoPageTransitionsBuilder(),
        },
      ),
    );
  }
}
