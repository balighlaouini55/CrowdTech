// Système de design CrowdTech « Night » : thème sombre premium inspiré des
// applications financières modernes. Tout le style de l'application vient
// d'ici : couleurs, couleurs par module, espacements, rayons, ombres,
// typographie et thème Material.

import 'package:flutter/cupertino.dart' show CupertinoPageTransitionsBuilder;
import 'package:flutter/material.dart';

/// Palette sombre. Les noms restent ceux de l'ancienne palette pour que
/// tous les écrans en profitent sans changement :
/// - `ink` = texte principal (clair), `muted` = texte secondaire ;
/// - `*Soft` = fond teinté discret derrière une couleur d'état.
class AppColors {
  AppColors._();

  // Fonds, du plus profond au plus élevé.
  static const background = Color(0xFF0A0E17);
  static const surface = Color(0xFF111725);
  static const surfaceRaised = Color(0xFF182033);
  static const surfaceHigh = Color(0xFF1F2940);

  // Lignes.
  static const border = Color(0xFF232D45);
  static const borderStrong = Color(0xFF33405E);

  // Texte.
  static const ink = Color(0xFFF1F4FA);
  static const muted = Color(0xFF8B95AD);
  static const subtle = Color(0xFF5E6884);

  // Accent iris et sa teinte.
  static const primary = Color(0xFF7C6CFF);
  static const primaryBright = Color(0xFFA197FF);
  static const primarySoft = Color(0xFF1E1C3F);

  // États.
  static const success = Color(0xFF2DD4A7);
  static const successSoft = Color(0xFF0E2A27);
  static const warning = Color(0xFFF5B544);
  static const warningSoft = Color(0xFF2D2513);
  static const danger = Color(0xFFF2637E);
  static const dangerSoft = Color(0xFF2E1520);
  static const info = Color(0xFF4BA3FF);
  static const infoSoft = Color(0xFF10233D);

  static const shadow = Color(0x66000000);
}

/// Espacements (multiples de 4).
class AppSpacing {
  AppSpacing._();
  static const xs = 4.0;
  static const sm = 8.0;
  static const md = 12.0;
  static const lg = 16.0;
  static const xl = 20.0;
  static const xxl = 24.0;
  static const xxxl = 32.0;
}

/// Rayons des coins.
class AppRadius {
  AppRadius._();
  static const sm = 10.0;
  static const md = 14.0;
  static const lg = 18.0;
  static const xl = 24.0;
  static const pill = 999.0;
}

/// Styles de texte communs (police Poppins). Les montants utilisent des
/// chiffres à chasse fixe pour rester alignés.
class AppText {
  AppText._();

  static const _tabular = [FontFeature.tabularFigures()];

  static const display = TextStyle(
    fontFamily: 'Poppins',
    fontSize: 30,
    height: 1.15,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.6,
    color: AppColors.ink,
    fontFeatures: _tabular,
  );
  static const title = TextStyle(
    fontFamily: 'Poppins',
    fontSize: 18,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.2,
    color: AppColors.ink,
  );
  static const subtitle = TextStyle(
    fontFamily: 'Poppins',
    fontSize: 15,
    fontWeight: FontWeight.w600,
    color: AppColors.ink,
  );
  static const body = TextStyle(
    fontFamily: 'Poppins',
    fontSize: 14,
    height: 1.45,
    color: AppColors.ink,
  );
  static const caption = TextStyle(
    fontFamily: 'Poppins',
    fontSize: 12,
    height: 1.35,
    color: AppColors.muted,
  );

  /// Petite étiquette en capitales (« PORTEFEUILLE »).
  static const overline = TextStyle(
    fontFamily: 'Poppins',
    fontSize: 11,
    fontWeight: FontWeight.w600,
    letterSpacing: 1.1,
    color: AppColors.muted,
  );

  /// Montant ou chiffre clé.
  static const figure = TextStyle(
    fontFamily: 'Poppins',
    fontSize: 20,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.3,
    color: AppColors.ink,
    fontFeatures: _tabular,
  );
}

/// Couleurs propres à chaque module : un dégradé lumineux utilisé avec
/// parcimonie (halo des en-têtes, icônes, barres de progression) et une
/// teinte sombre pour les fonds.
class ModulePalette {
  final Color start;
  final Color end;
  final Color soft;

  /// Ancienne mascotte du module, gardée pour les messages et les PDF.
  final String emoji;
  const ModulePalette(this.start, this.end, this.soft, [this.emoji = '✨']);

  LinearGradient get gradient => LinearGradient(
    colors: [start, end],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  /// Halo coloré très discret pour les fonds de cartes mises en avant.
  RadialGradient get glow => RadialGradient(
    center: const Alignment(0.9, -1.1),
    radius: 1.4,
    colors: [start.withValues(alpha: 0.30), start.withValues(alpha: 0)],
  );

  /// Fond d'un panneau mis en avant : surface sombre éclairée par un
  /// halo de la couleur du module dans le coin supérieur droit.
  RadialGradient get panel => RadialGradient(
    center: const Alignment(0.9, -1.1),
    radius: 1.5,
    colors: [
      Color.alphaBlend(start.withValues(alpha: 0.22), AppColors.surface),
      AppColors.surface,
    ],
  );

  static const home = ModulePalette(
    Color(0xFF7C6CFF),
    Color(0xFF2DD4A7),
    Color(0xFF16233A),
    '💼',
  );
  static const news = ModulePalette(
    Color(0xFF4B8DF8),
    Color(0xFF22D3EE),
    Color(0xFF0F2238),
    '📰',
  );
  static const funding = ModulePalette(
    Color(0xFF7C6CFF),
    Color(0xFFB57BFF),
    Color(0xFF1E1C3F),
    '🚀',
  );
  static const store = ModulePalette(
    Color(0xFFF59E0B),
    Color(0xFFF4727F),
    Color(0xFF2B1F12),
    '🛍️',
  );
  static const events = ModulePalette(
    Color(0xFF10B981),
    Color(0xFF3BC9DB),
    Color(0xFF0D2A24),
    '🎟️',
  );
  static const profile = ModulePalette(
    Color(0xFFA78BFA),
    Color(0xFFF472B6),
    Color(0xFF261A33),
    '🌸',
  );
}

/// Ombre portée des cartes (discrète sur fond sombre).
const softShadow = [
  BoxShadow(color: AppColors.shadow, blurRadius: 24, offset: Offset(0, 10)),
];

/// Décoration standard d'une carte : surface, bordure fine, ombre.
BoxDecoration cardDecoration({
  Color color = AppColors.surface,
  double radius = AppRadius.xl,
  Gradient? gradient,
  Color borderColor = AppColors.border,
}) => BoxDecoration(
  color: gradient == null ? color : null,
  gradient: gradient,
  borderRadius: BorderRadius.circular(radius),
  border: Border.all(color: borderColor),
  boxShadow: softShadow,
);

ThemeData buildAppTheme() {
  final scheme =
      ColorScheme.fromSeed(
        seedColor: AppColors.primary,
        brightness: Brightness.dark,
        primary: AppColors.primary,
        onPrimary: Colors.white,
        secondary: AppColors.success,
        surface: AppColors.surface,
        onSurface: AppColors.ink,
        error: AppColors.danger,
      ).copyWith(
        surfaceContainerLowest: AppColors.background,
        surfaceContainerLow: AppColors.surface,
        surfaceContainer: AppColors.surfaceRaised,
        surfaceContainerHigh: AppColors.surfaceHigh,
        surfaceContainerHighest: AppColors.surfaceHigh,
        onSurfaceVariant: AppColors.muted,
        outline: AppColors.borderStrong,
        outlineVariant: AppColors.border,
      );
  final radius = BorderRadius.circular(AppRadius.md);
  OutlineInputBorder inputBorder(Color color, [double width = 1]) =>
      OutlineInputBorder(
        borderRadius: radius,
        borderSide: BorderSide(color: color, width: width),
      );
  const font = 'Poppins';

  return ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    fontFamily: font,
    colorScheme: scheme,
    scaffoldBackgroundColor: AppColors.background,
    canvasColor: AppColors.background,
    splashFactory: InkSparkle.splashFactory,
    textTheme: ThemeData.dark().textTheme.apply(
      fontFamily: font,
      bodyColor: AppColors.ink,
      displayColor: AppColors.ink,
    ),
    // Transitions douces entre les pages, sur toutes les plateformes.
    pageTransitionsTheme: PageTransitionsTheme(
      builders: {
        TargetPlatform.android: const FadeForwardsPageTransitionsBuilder(),
        TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
        TargetPlatform.macOS: CupertinoPageTransitionsBuilder(),
        TargetPlatform.windows: const FadeForwardsPageTransitionsBuilder(),
        TargetPlatform.linux: const FadeForwardsPageTransitionsBuilder(),
      },
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.background,
      foregroundColor: AppColors.ink,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      titleTextStyle: TextStyle(
        fontFamily: font,
        color: AppColors.ink,
        fontSize: 20,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.3,
      ),
    ),
    cardTheme: CardThemeData(
      color: AppColors.surface,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      shadowColor: AppColors.shadow,
      margin: const EdgeInsets.only(bottom: AppSpacing.lg),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.xl),
        side: const BorderSide(color: AppColors.border),
      ),
    ),
    listTileTheme: ListTileThemeData(
      iconColor: AppColors.muted,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.lg),
      ),
      titleTextStyle: const TextStyle(
        fontFamily: font,
        color: AppColors.ink,
        fontSize: 15,
        fontWeight: FontWeight.w600,
      ),
      subtitleTextStyle: const TextStyle(
        fontFamily: font,
        color: AppColors.muted,
        fontSize: 13,
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.surfaceRaised,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      border: inputBorder(AppColors.border),
      enabledBorder: inputBorder(AppColors.border),
      focusedBorder: inputBorder(AppColors.primary, 1.6),
      errorBorder: inputBorder(AppColors.danger),
      focusedErrorBorder: inputBorder(AppColors.danger, 1.6),
      prefixIconColor: WidgetStateColor.resolveWith(
        (states) => states.contains(WidgetState.focused)
            ? AppColors.primaryBright
            : AppColors.muted,
      ),
      suffixIconColor: AppColors.muted,
      labelStyle: const TextStyle(fontFamily: font, color: AppColors.muted),
      floatingLabelStyle: WidgetStateTextStyle.resolveWith(
        (states) => TextStyle(
          fontFamily: font,
          color: states.contains(WidgetState.error)
              ? AppColors.danger
              : states.contains(WidgetState.focused)
              ? AppColors.primaryBright
              : AppColors.muted,
        ),
      ),
      hintStyle: const TextStyle(fontFamily: font, color: AppColors.subtle),
      helperStyle: const TextStyle(fontFamily: font, color: AppColors.muted),
      counterStyle: const TextStyle(fontFamily: font, color: AppColors.subtle),
      errorStyle: const TextStyle(
        fontFamily: font,
        color: AppColors.danger,
        fontWeight: FontWeight.w500,
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size(0, 52),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        disabledBackgroundColor: AppColors.surfaceHigh,
        disabledForegroundColor: AppColors.subtle,
        shape: RoundedRectangleBorder(borderRadius: radius),
        textStyle: const TextStyle(
          fontFamily: font,
          fontWeight: FontWeight.w600,
          fontSize: 15,
        ),
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        minimumSize: const Size(0, 52),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: radius),
        textStyle: const TextStyle(
          fontFamily: font,
          fontWeight: FontWeight.w600,
          fontSize: 15,
        ),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(0, 50),
        foregroundColor: AppColors.ink,
        backgroundColor: Colors.transparent,
        side: const BorderSide(color: AppColors.borderStrong),
        shape: RoundedRectangleBorder(borderRadius: radius),
        textStyle: const TextStyle(
          fontFamily: font,
          fontWeight: FontWeight.w600,
        ),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: AppColors.primaryBright,
        shape: RoundedRectangleBorder(borderRadius: radius),
        textStyle: const TextStyle(
          fontFamily: font,
          fontWeight: FontWeight.w600,
        ),
      ),
    ),
    iconButtonTheme: IconButtonThemeData(
      style: IconButton.styleFrom(
        foregroundColor: AppColors.ink,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
      ),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: AppColors.surfaceRaised,
      selectedColor: AppColors.primarySoft,
      disabledColor: AppColors.surface,
      showCheckmark: false,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      side: WidgetStateBorderSide.resolveWith(
        (states) => BorderSide(
          color: states.contains(WidgetState.selected)
              ? AppColors.primary
              : AppColors.border,
        ),
      ),
      labelStyle: const TextStyle(
        fontFamily: font,
        fontWeight: FontWeight.w500,
        fontSize: 13,
        color: AppColors.ink,
      ),
      iconTheme: const IconThemeData(color: AppColors.muted, size: 16),
    ),
    checkboxTheme: CheckboxThemeData(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
      side: const BorderSide(color: AppColors.borderStrong, width: 1.5),
      fillColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.selected)
            ? AppColors.primary
            : Colors.transparent,
      ),
    ),
    switchTheme: SwitchThemeData(
      trackColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.selected)
            ? AppColors.primary
            : AppColors.surfaceHigh,
      ),
      thumbColor: const WidgetStatePropertyAll(Colors.white),
      trackOutlineColor: const WidgetStatePropertyAll(Colors.transparent),
    ),
    segmentedButtonTheme: SegmentedButtonThemeData(
      style: SegmentedButton.styleFrom(
        backgroundColor: AppColors.surfaceRaised,
        selectedBackgroundColor: AppColors.primarySoft,
        selectedForegroundColor: AppColors.primaryBright,
        foregroundColor: AppColors.muted,
        side: const BorderSide(color: AppColors.border),
      ),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: AppColors.surface,
      surfaceTintColor: Colors.transparent,
      indicatorColor: AppColors.primarySoft,
      indicatorShape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      elevation: 0,
      iconTheme: WidgetStateProperty.resolveWith(
        (states) => IconThemeData(
          color: states.contains(WidgetState.selected)
              ? AppColors.primaryBright
              : AppColors.subtle,
        ),
      ),
      labelTextStyle: WidgetStateProperty.resolveWith(
        (states) => TextStyle(
          fontFamily: font,
          fontSize: 11,
          fontWeight: states.contains(WidgetState.selected)
              ? FontWeight.w600
              : FontWeight.w500,
          color: states.contains(WidgetState.selected)
              ? AppColors.ink
              : AppColors.subtle,
        ),
      ),
    ),
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: AppColors.primary,
      foregroundColor: Colors.white,
      elevation: 0,
      focusElevation: 0,
      hoverElevation: 0,
      highlightElevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.lg),
      ),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: AppColors.surfaceHigh,
      actionTextColor: AppColors.primaryBright,
      elevation: 0,
      insetPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      contentTextStyle: const TextStyle(
        fontFamily: font,
        color: AppColors.ink,
        fontWeight: FontWeight.w500,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.md),
        side: const BorderSide(color: AppColors.borderStrong),
      ),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: AppColors.surfaceRaised,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.xl),
        side: const BorderSide(color: AppColors.border),
      ),
      titleTextStyle: const TextStyle(
        fontFamily: font,
        color: AppColors.ink,
        fontSize: 18,
        fontWeight: FontWeight.w700,
      ),
      contentTextStyle: const TextStyle(
        fontFamily: font,
        color: AppColors.muted,
        fontSize: 14,
        height: 1.45,
      ),
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: AppColors.surfaceRaised,
      surfaceTintColor: Colors.transparent,
      showDragHandle: true,
      dragHandleColor: AppColors.borderStrong,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
      ),
    ),
    popupMenuTheme: PopupMenuThemeData(
      color: AppColors.surfaceRaised,
      surfaceTintColor: Colors.transparent,
      elevation: 8,
      shadowColor: AppColors.shadow,
      textStyle: const TextStyle(
        fontFamily: font,
        color: AppColors.ink,
        fontWeight: FontWeight.w500,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.lg),
        side: const BorderSide(color: AppColors.border),
      ),
    ),
    menuTheme: const MenuThemeData(
      style: MenuStyle(
        backgroundColor: WidgetStatePropertyAll(AppColors.surfaceRaised),
      ),
    ),
    dropdownMenuTheme: const DropdownMenuThemeData(
      menuStyle: MenuStyle(
        backgroundColor: WidgetStatePropertyAll(AppColors.surfaceRaised),
      ),
    ),
    datePickerTheme: DatePickerThemeData(
      backgroundColor: AppColors.surfaceRaised,
      headerBackgroundColor: AppColors.surfaceHigh,
      headerForegroundColor: AppColors.ink,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.xl),
      ),
    ),
    timePickerTheme: const TimePickerThemeData(
      backgroundColor: AppColors.surfaceRaised,
    ),
    tooltipTheme: TooltipThemeData(
      textStyle: const TextStyle(fontFamily: font, color: AppColors.ink),
      decoration: BoxDecoration(
        color: AppColors.surfaceHigh,
        borderRadius: BorderRadius.circular(AppRadius.sm),
        border: Border.all(color: AppColors.borderStrong),
      ),
    ),
    tabBarTheme: const TabBarThemeData(
      labelColor: AppColors.ink,
      unselectedLabelColor: AppColors.muted,
      indicatorColor: AppColors.primary,
      dividerColor: AppColors.border,
    ),
    dividerTheme: const DividerThemeData(color: AppColors.border, space: 1),
    progressIndicatorTheme: const ProgressIndicatorThemeData(
      color: AppColors.primary,
      linearTrackColor: AppColors.surfaceHigh,
      circularTrackColor: AppColors.surfaceHigh,
    ),
    badgeTheme: const BadgeThemeData(
      backgroundColor: AppColors.danger,
      textColor: Colors.white,
    ),
  );
}
