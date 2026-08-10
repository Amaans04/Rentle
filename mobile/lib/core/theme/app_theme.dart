import 'package:flutter/material.dart';

/// "Blue Vivid + Cool Grey" from the color-palette skill — chosen because it
/// extends the brand blue already in use (Organization.primaryColor default
/// #2563EB, and the old seed color here) rather than replacing it with an
/// unrelated hue. Raw palette values live here as the one source of truth;
/// everything else should read colors from Theme.of(context), never these
/// constants directly.
abstract class _Palette {
  // Primary: Blue (Vivid)
  static const blue900 = Color(0xFF002159);
  static const blue600 = Color(0xFF0552B5);
  static const blue100 = Color(0xFFBAE3FF);
  static const blue50 = Color(0xFFE6F6FF);

  // Neutrals: Cool Grey
  static const grey900 = Color(0xFF1F2933);
  static const grey700 = Color(0xFF3E4C59);
  static const grey600 = Color(0xFF52606D);
  static const grey500 = Color(0xFF616E7C);
  static const grey300 = Color(0xFF9AA5B1);
  static const grey200 = Color(0xFFCBD2D9);
  static const grey100 = Color(0xFFE4E7EB);
  static const grey50 = Color(0xFFF5F7FA);

  // Supporting: Red (Vivid) — error/destructive
  static const red900 = Color(0xFF610316);
  static const red600 = Color(0xFFCF1124);
  static const red100 = Color(0xFFFFBDBD);

  // Supporting: Teal (standard) — success
  static const teal900 = Color(0xFF014D40);
  static const teal600 = Color(0xFF199473);
  static const teal500 = Color(0xFF27AB83);
  static const teal100 = Color(0xFFC6F7E2);

  // Supporting: Yellow (standard) — warning/pending
  static const yellow900 = Color(0xFF513C06);
  static const yellow700 = Color(0xFFA27C1A);
  static const yellow100 = Color(0xFFFCEFC7);
}

/// Status colors Material's ColorScheme has no built-in role for (it only
/// has `error`) — a proper ThemeExtension so every status chip/badge across
/// tenancy/complaint/invoice/bed screens reads from one place instead of
/// each file picking its own `Colors.orange`/`Colors.green`.
@immutable
class AppSemanticColors extends ThemeExtension<AppSemanticColors> {
  const AppSemanticColors({
    required this.success,
    required this.onSuccess,
    required this.successContainer,
    required this.onSuccessContainer,
    required this.warning,
    required this.onWarning,
    required this.warningContainer,
    required this.onWarningContainer,
  });

  final Color success;
  final Color onSuccess;
  final Color successContainer;
  final Color onSuccessContainer;
  final Color warning;
  final Color onWarning;
  final Color warningContainer;
  final Color onWarningContainer;

  static const light = AppSemanticColors(
    success: _Palette.teal600,
    onSuccess: Colors.white,
    successContainer: _Palette.teal100,
    onSuccessContainer: _Palette.teal900,
    warning: _Palette.yellow700,
    onWarning: Colors.white,
    warningContainer: _Palette.yellow100,
    onWarningContainer: _Palette.yellow900,
  );

  @override
  AppSemanticColors copyWith({
    Color? success,
    Color? onSuccess,
    Color? successContainer,
    Color? onSuccessContainer,
    Color? warning,
    Color? onWarning,
    Color? warningContainer,
    Color? onWarningContainer,
  }) {
    return AppSemanticColors(
      success: success ?? this.success,
      onSuccess: onSuccess ?? this.onSuccess,
      successContainer: successContainer ?? this.successContainer,
      onSuccessContainer: onSuccessContainer ?? this.onSuccessContainer,
      warning: warning ?? this.warning,
      onWarning: onWarning ?? this.onWarning,
      warningContainer: warningContainer ?? this.warningContainer,
      onWarningContainer: onWarningContainer ?? this.onWarningContainer,
    );
  }

  @override
  AppSemanticColors lerp(ThemeExtension<AppSemanticColors>? other, double t) {
    if (other is! AppSemanticColors) return this;
    return AppSemanticColors(
      success: Color.lerp(success, other.success, t)!,
      onSuccess: Color.lerp(onSuccess, other.onSuccess, t)!,
      successContainer: Color.lerp(successContainer, other.successContainer, t)!,
      onSuccessContainer: Color.lerp(onSuccessContainer, other.onSuccessContainer, t)!,
      warning: Color.lerp(warning, other.warning, t)!,
      onWarning: Color.lerp(onWarning, other.onWarning, t)!,
      warningContainer: Color.lerp(warningContainer, other.warningContainer, t)!,
      onWarningContainer: Color.lerp(onWarningContainer, other.onWarningContainer, t)!,
    );
  }
}

/// Convenience accessor so call sites read `context.semanticColors.success`
/// instead of the more verbose `Theme.of(context).extension<...>()!`.
extension SemanticColorsX on BuildContext {
  AppSemanticColors get semanticColors => Theme.of(this).extension<AppSemanticColors>()!;
}

ThemeData buildAppTheme() {
  const colorScheme = ColorScheme(
    brightness: Brightness.light,
    primary: _Palette.blue600,
    onPrimary: Colors.white,
    primaryContainer: _Palette.blue100,
    onPrimaryContainer: _Palette.blue900,
    secondary: _Palette.grey600,
    onSecondary: Colors.white,
    secondaryContainer: _Palette.grey100,
    onSecondaryContainer: _Palette.grey900,
    tertiary: _Palette.teal500,
    onTertiary: Colors.white,
    tertiaryContainer: _Palette.teal100,
    onTertiaryContainer: _Palette.teal900,
    error: _Palette.red600,
    onError: Colors.white,
    errorContainer: _Palette.red100,
    onErrorContainer: _Palette.red900,
    surface: Colors.white,
    onSurface: _Palette.grey900,
    surfaceContainerLowest: Colors.white,
    surfaceContainerLow: _Palette.blue50,
    surfaceContainer: _Palette.grey50,
    surfaceContainerHigh: _Palette.grey100,
    surfaceContainerHighest: _Palette.grey200,
    onSurfaceVariant: _Palette.grey600,
    outline: _Palette.grey300,
    outlineVariant: _Palette.grey200,
  );

  final textTheme = Typography.blackMountainView.apply(bodyColor: _Palette.grey900, displayColor: _Palette.grey900);

  return ThemeData(
    useMaterial3: true,
    colorScheme: colorScheme,
    scaffoldBackgroundColor: Colors.white,
    textTheme: textTheme,
    extensions: const [AppSemanticColors.light],
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.white,
      foregroundColor: _Palette.grey900,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 1,
      titleTextStyle: TextStyle(fontSize: 20, fontWeight: FontWeight.w600, color: _Palette.grey900),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: _Palette.blue600,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: _Palette.blue600,
        side: const BorderSide(color: _Palette.grey300),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(foregroundColor: _Palette.blue600, textStyle: const TextStyle(fontWeight: FontWeight.w600)),
    ),
    cardTheme: CardThemeData(
      elevation: 0,
      color: Colors.white,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: const BorderSide(color: _Palette.grey200)),
      margin: EdgeInsets.zero,
    ),
    chipTheme: ChipThemeData(
      backgroundColor: _Palette.grey100,
      labelStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: _Palette.grey700),
      side: BorderSide.none,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: _Palette.grey50,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: _Palette.grey200)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: _Palette.blue600, width: 1.5)),
      errorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: _Palette.red600)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
    ),
    dividerTheme: const DividerThemeData(color: _Palette.grey200, thickness: 1, space: 1),
    listTileTheme: const ListTileThemeData(iconColor: _Palette.grey600),
    tabBarTheme: const TabBarThemeData(
      labelColor: _Palette.blue600,
      unselectedLabelColor: _Palette.grey500,
      indicatorColor: _Palette.blue600,
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: _Palette.grey900,
      contentTextStyle: const TextStyle(color: Colors.white),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ),
    progressIndicatorTheme: const ProgressIndicatorThemeData(color: _Palette.blue600),
  );
}
