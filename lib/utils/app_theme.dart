import 'package:flutter/material.dart';
import '../init.dart';

const _fontFamilyFallback = [
  'Microsoft YaHei',
  'PingFang SC',
  'Noto Sans SC',
  'Segoe UI',
  'SF Pro',
  'Roboto',
];

const TextTheme _lightTextTheme = TextTheme(
  displayLarge: TextStyle(color: PremiumColors.lightText),
  displayMedium: TextStyle(color: PremiumColors.lightText),
  displaySmall: TextStyle(color: PremiumColors.lightText),
  headlineLarge: TextStyle(color: PremiumColors.lightText),
  headlineMedium: TextStyle(color: PremiumColors.lightText),
  headlineSmall: TextStyle(color: PremiumColors.lightText),
  titleLarge: TextStyle(
    color: PremiumColors.lightText,
    fontWeight: FontWeight.w600,
  ),
  titleMedium: TextStyle(
    color: PremiumColors.lightText,
    fontWeight: FontWeight.w500,
  ),
  titleSmall: TextStyle(
    color: PremiumColors.lightText,
    fontWeight: FontWeight.w500,
  ),
  bodyLarge: TextStyle(color: PremiumColors.lightText),
  bodyMedium: TextStyle(color: PremiumColors.lightText),
  bodySmall: TextStyle(color: PremiumColors.lightSecondaryText, fontSize: 12),
  labelLarge: TextStyle(color: PremiumColors.lightText),
  labelMedium: TextStyle(color: PremiumColors.lightText),
  labelSmall: TextStyle(color: PremiumColors.lightSecondaryText, fontSize: 12),
);

const TextTheme _darkTextTheme = TextTheme(
  displayLarge: TextStyle(color: PremiumColors.darkText),
  displayMedium: TextStyle(color: PremiumColors.darkText),
  displaySmall: TextStyle(color: PremiumColors.darkText),
  headlineLarge: TextStyle(color: PremiumColors.darkText),
  headlineMedium: TextStyle(color: PremiumColors.darkText),
  headlineSmall: TextStyle(color: PremiumColors.darkText),
  titleLarge: TextStyle(
    color: PremiumColors.darkText,
    fontWeight: FontWeight.w600,
  ),
  titleMedium: TextStyle(
    color: PremiumColors.darkText,
    fontWeight: FontWeight.w500,
  ),
  titleSmall: TextStyle(
    color: PremiumColors.darkText,
    fontWeight: FontWeight.w500,
  ),
  bodyLarge: TextStyle(color: PremiumColors.darkText),
  bodyMedium: TextStyle(color: PremiumColors.darkText),
  bodySmall: TextStyle(color: PremiumColors.darkSecondaryText, fontSize: 12),
  labelLarge: TextStyle(color: PremiumColors.darkText),
  labelMedium: TextStyle(color: PremiumColors.darkText),
  labelSmall: TextStyle(color: PremiumColors.darkSecondaryText, fontSize: 12),
);

class PremiumColors {
  // Vibrant Ocean Blue Theme
  static const Color primary = Color(0xFF0F62FE);
  static const Color primaryAccent = Color(0xFF4589FF);
  static const Color primaryDark = Color(0xFF00B0FF);
  static const Color primaryContainerLight = Color(0xFFD6E4FF);
  static const Color primaryContainerDark = Color(0xFF002D6D);

  // Background & Surfaces (matching OpenCode Electron shell)
  static const Color lightBackground = Color(0xFFF4F6F9);
  static const Color lightSurface = Color(0xFFFFFFFF);
  static const Color lightSidebar = Color(0xFFEBEFF5);
  static const Color lightRail = Color(0xFFEBEFF5);
  static const Color lightPanel = Color(0xFFFFFFFF);
  static const Color lightInputBg = Color(0xFFDDE1E6);
  static const Color lightChipBg = Color(0xFFE8ECF0);
  static const Color lightSurfaceHighest = Color(0xFFE8ECF0);
  static const Color darkBackground = Color(0xFF12131A);
  static const Color darkSurface = Color(0xFF1C1D26);
  static const Color darkSidebar = Color(0xFF16171E);
  static const Color darkRail = Color(0xFF16171E);
  static const Color darkPanel = Color(0xFF1C1D26);
  static const Color darkInputBg = Color(0xFF14151C);
  static const Color darkChipBg = Color(0xFF2A2B36);
  static const Color darkSurfaceHighest = Color(0xFF2A2B36);

  // Typography
  static const Color lightText = Color(0xFF161616);
  static const Color lightSecondaryText = Color(0xFF525252);
  static const Color darkText = Color(0xFFF4F4F4);
  static const Color darkSecondaryText = Color(0xFFA8A8A8);

  // Dividers & Accents
  static const Color lightDivider = Color(0xFFDDE1E6);
  static const Color darkDivider = Color(0xFF2E313D);
  static const Color success = Color(0xFF24A148);
  static const Color warning = Color(0xFFF1C21B);
  static const Color error = Color(0xFFDA1E28);
  static const Color errorContainerLight = Color(0xFFFCE8E6);
  static const Color errorContainerDark = Color(0xFF2D1619);
  static const Color onErrorContainerLight = Color(0xFF3C181A);
  static const Color onErrorContainerDark = Color(0xFFF1F3F5);
  static const Color errorOutlineLight = Color(0xFFF8B4B0);
  static const Color errorOutlineDark = Color(0xFF5C1E24);

  // Diff / terminal accents
  static const Color diffAddBgLight = Color(0x254CAF50);
  static const Color diffAddBgDark = Color(0x302E7D32);
  static const Color diffRemoveBgLight = Color(0x25F44336);
  static const Color diffRemoveBgDark = Color(0x35C62828);
  static const Color diffFgLight = Color(0xFF333333);
  static const Color diffFgDark = Color(0xFFDCDCDC);
  static const Color bashAccentLight = Color(0xFF2E7D32);
  static const Color bashAccentDark = Color(0xFF69F0AE);

  // Avatar colors
  static const List<Color> avatarColors = [
    Color(0xFF3F51B5),
    Color(0xFFE91E63),
    Color(0xFF9C27B0),
    Color(0xFF009688),
    Color(0xFF673AB7),
    Color(0xFF2196F3),
    Color(0xFFFF5722),
  ];

  /// Helper: pick surface/bg for current brightness
  static Color background(Brightness b) =>
      b == Brightness.dark ? darkBackground : lightBackground;
  static Color surface(Brightness b) =>
      b == Brightness.dark ? darkSurface : lightSurface;
  static Color sidebar(Brightness b) =>
      b == Brightness.dark ? darkSidebar : lightSidebar;
  static Color rail(Brightness b) =>
      b == Brightness.dark ? darkRail : lightRail;
  static Color panel(Brightness b) =>
      b == Brightness.dark ? darkPanel : lightPanel;
  static Color inputBg(Brightness b) =>
      b == Brightness.dark ? darkInputBg : lightInputBg;
  static Color chipBg(Brightness b) =>
      b == Brightness.dark ? darkChipBg : lightChipBg;
  static Color divider(Brightness b) =>
      b == Brightness.dark ? darkDivider : lightDivider;
  static Color text(Brightness b) =>
      b == Brightness.dark ? darkText : lightText;
  static Color secondaryText(Brightness b) =>
      b == Brightness.dark ? darkSecondaryText : lightSecondaryText;
  static Color avatarColor(String initials) {
    if (initials.isEmpty) return avatarColors[0];
    return avatarColors[initials.codeUnitAt(0) % avatarColors.length];
  }
}

/// App-specific colors that don't fit cleanly into [ColorScheme].
@immutable
class AppThemeColors extends ThemeExtension<AppThemeColors> {
  final Color inputBg;
  final Color chipBg;
  final Color toolCardBg;
  final Color success;
  final Color warning;
  final Color diffAddBg;
  final Color diffRemoveBg;
  final Color diffFg;
  final Color bashAccent;
  final Color errorSoftBg;
  final Color errorOutline;

  const AppThemeColors({
    required this.inputBg,
    required this.chipBg,
    required this.toolCardBg,
    required this.success,
    required this.warning,
    required this.diffAddBg,
    required this.diffRemoveBg,
    required this.diffFg,
    required this.bashAccent,
    required this.errorSoftBg,
    required this.errorOutline,
  });

  static const light = AppThemeColors(
    inputBg: PremiumColors.lightInputBg,
    chipBg: PremiumColors.lightChipBg,
    toolCardBg: PremiumColors.lightSurface,
    success: PremiumColors.success,
    warning: PremiumColors.warning,
    diffAddBg: PremiumColors.diffAddBgLight,
    diffRemoveBg: PremiumColors.diffRemoveBgLight,
    diffFg: PremiumColors.diffFgLight,
    bashAccent: PremiumColors.bashAccentLight,
    errorSoftBg: Color(0x14DA1E28),
    errorOutline: PremiumColors.errorOutlineLight,
  );

  static const dark = AppThemeColors(
    inputBg: PremiumColors.darkInputBg,
    chipBg: PremiumColors.darkChipBg,
    toolCardBg: PremiumColors.darkSurface,
    success: PremiumColors.success,
    warning: PremiumColors.warning,
    diffAddBg: PremiumColors.diffAddBgDark,
    diffRemoveBg: PremiumColors.diffRemoveBgDark,
    diffFg: PremiumColors.diffFgDark,
    bashAccent: PremiumColors.bashAccentDark,
    errorSoftBg: Color(0x14DA1E28),
    errorOutline: PremiumColors.errorOutlineDark,
  );

  @override
  AppThemeColors copyWith({
    Color? inputBg,
    Color? chipBg,
    Color? toolCardBg,
    Color? success,
    Color? warning,
    Color? diffAddBg,
    Color? diffRemoveBg,
    Color? diffFg,
    Color? bashAccent,
    Color? errorSoftBg,
    Color? errorOutline,
  }) {
    return AppThemeColors(
      inputBg: inputBg ?? this.inputBg,
      chipBg: chipBg ?? this.chipBg,
      toolCardBg: toolCardBg ?? this.toolCardBg,
      success: success ?? this.success,
      warning: warning ?? this.warning,
      diffAddBg: diffAddBg ?? this.diffAddBg,
      diffRemoveBg: diffRemoveBg ?? this.diffRemoveBg,
      diffFg: diffFg ?? this.diffFg,
      bashAccent: bashAccent ?? this.bashAccent,
      errorSoftBg: errorSoftBg ?? this.errorSoftBg,
      errorOutline: errorOutline ?? this.errorOutline,
    );
  }

  @override
  AppThemeColors lerp(ThemeExtension<AppThemeColors>? other, double t) {
    if (other is! AppThemeColors) return this;
    return AppThemeColors(
      inputBg: Color.lerp(inputBg, other.inputBg, t)!,
      chipBg: Color.lerp(chipBg, other.chipBg, t)!,
      toolCardBg: Color.lerp(toolCardBg, other.toolCardBg, t)!,
      success: Color.lerp(success, other.success, t)!,
      warning: Color.lerp(warning, other.warning, t)!,
      diffAddBg: Color.lerp(diffAddBg, other.diffAddBg, t)!,
      diffRemoveBg: Color.lerp(diffRemoveBg, other.diffRemoveBg, t)!,
      diffFg: Color.lerp(diffFg, other.diffFg, t)!,
      bashAccent: Color.lerp(bashAccent, other.bashAccent, t)!,
      errorSoftBg: Color.lerp(errorSoftBg, other.errorSoftBg, t)!,
      errorOutline: Color.lerp(errorOutline, other.errorOutline, t)!,
    );
  }
}

extension AppThemeX on BuildContext {
  AppThemeColors get appColors =>
      Theme.of(this).extension<AppThemeColors>() ?? AppThemeColors.dark;
}

ThemeData light = ThemeData.light().copyWith(
  primaryColor: PremiumColors.primary,
  scaffoldBackgroundColor: PremiumColors.lightBackground,
  textTheme: _lightTextTheme.apply(fontFamilyFallback: _fontFamilyFallback),
  colorScheme: const ColorScheme.light(
    primary: PremiumColors.primary,
    onPrimary: Colors.white,
    primaryContainer: PremiumColors.primaryContainerLight,
    onPrimaryContainer: PremiumColors.lightText,
    secondary: PremiumColors.primaryAccent,
    onSecondary: Colors.white,
    secondaryContainer: PremiumColors.primaryContainerLight,
    onSecondaryContainer: PremiumColors.lightText,
    surface: PremiumColors.lightSurface,
    onSurface: PremiumColors.lightText,
    onSurfaceVariant: PremiumColors.lightSecondaryText,
    surfaceContainerHighest: PremiumColors.lightSurfaceHighest,
    error: PremiumColors.error,
    onError: Colors.white,
    errorContainer: PremiumColors.errorContainerLight,
    onErrorContainer: PremiumColors.onErrorContainerLight,
    outline: PremiumColors.lightDivider,
    outlineVariant: PremiumColors.lightDivider,
  ),
  iconTheme: IconThemeData(
    size: Global.iconSize,
    color: PremiumColors.lightText,
  ),
  brightness: Brightness.light,
  appBarTheme: const AppBarTheme(
    backgroundColor: PremiumColors.lightSurface,
    foregroundColor: PremiumColors.lightText,
    elevation: 0,
    scrolledUnderElevation: 0.5,
    surfaceTintColor: Colors.transparent,
  ),
  cardTheme: CardThemeData(
    color: PremiumColors.lightSurface,
    elevation: 0,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(8),
      side: const BorderSide(color: PremiumColors.lightDivider),
    ),
  ),
  elevatedButtonTheme: ElevatedButtonThemeData(
    style: ElevatedButton.styleFrom(
      backgroundColor: PremiumColors.primary,
      foregroundColor: Colors.white,
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
    ),
  ),
  dividerTheme: const DividerThemeData(
    color: PremiumColors.lightDivider,
    thickness: 0.5,
  ),
  extensions: const <ThemeExtension<dynamic>>[AppThemeColors.light],
);

ThemeData dark = ThemeData.dark().copyWith(
  primaryColor: PremiumColors.primary,
  scaffoldBackgroundColor: PremiumColors.darkBackground,
  textTheme: _darkTextTheme.apply(fontFamilyFallback: _fontFamilyFallback),
  colorScheme: const ColorScheme.dark(
    primary: PremiumColors.primary,
    onPrimary: Colors.white,
    primaryContainer: PremiumColors.primaryContainerDark,
    onPrimaryContainer: PremiumColors.darkText,
    secondary: PremiumColors.primaryAccent,
    onSecondary: Colors.white,
    secondaryContainer: PremiumColors.primaryContainerDark,
    onSecondaryContainer: PremiumColors.darkText,
    surface: PremiumColors.darkSurface,
    onSurface: PremiumColors.darkText,
    onSurfaceVariant: PremiumColors.darkSecondaryText,
    surfaceContainerHighest: PremiumColors.darkSurfaceHighest,
    error: PremiumColors.error,
    onError: Colors.white,
    errorContainer: PremiumColors.errorContainerDark,
    onErrorContainer: PremiumColors.onErrorContainerDark,
    outline: PremiumColors.darkDivider,
    outlineVariant: PremiumColors.darkDivider,
  ),
  iconTheme: IconThemeData(
    size: Global.iconSize,
    color: PremiumColors.darkText,
  ),
  brightness: Brightness.dark,
  appBarTheme: const AppBarTheme(
    backgroundColor: PremiumColors.darkSurface,
    foregroundColor: PremiumColors.darkText,
    elevation: 0,
    scrolledUnderElevation: 0.5,
    surfaceTintColor: Colors.transparent,
  ),
  cardTheme: CardThemeData(
    color: PremiumColors.darkSurface,
    elevation: 0,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(8),
      side: const BorderSide(color: PremiumColors.darkDivider),
    ),
  ),
  elevatedButtonTheme: ElevatedButtonThemeData(
    style: ElevatedButton.styleFrom(
      backgroundColor: PremiumColors.primary,
      foregroundColor: Colors.white,
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
    ),
  ),
  dividerTheme: const DividerThemeData(
    color: PremiumColors.darkDivider,
    thickness: 0.5,
  ),
  extensions: const <ThemeExtension<dynamic>>[AppThemeColors.dark],
);
