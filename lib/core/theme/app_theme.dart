import 'package:flutter/cupertino.dart' show CupertinoPageTransitionsBuilder;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'glass.dart';

export 'glass.dart' show AppSurface, GlassBackdrop;

/// Every colour the theme varies. The monochrome pair is XPENC's Classic
/// palette value for value, so the two TRAKVRS apps read as siblings; only
/// the accent is FITNS's own.
///
/// The two rules a palette must obey (also XPENC's):
///  * [surfaceHigh] (cards) must be clearly distinct from [bg] (the page).
///  * [track] must read as a groove against [surfaceHigh], or an empty
///    progress bar is invisible.
@immutable
class Palette {
  const Palette({
    required this.brightness,
    required this.bg,
    required this.surface,
    required this.surfaceHigh,
    required this.track,
    required this.border,
    required this.text,
    required this.textMuted,
    required this.accent,
    required this.primary,
    required this.onPrimary,
  });

  final Brightness brightness;
  final Color bg;
  final Color surface;
  final Color surfaceHigh;
  final Color track;
  final Color border;
  final Color text;
  final Color textMuted;

  /// FITNS orange: progress rings, the active tab, a ticked-off set.
  final Color accent;

  /// Filled buttons. Monochrome — the text colour.
  final Color primary;
  final Color onPrimary;

  static const light = Palette(
    brightness: Brightness.light,
    bg: Color(0xFFF4F3F1),
    surface: Color(0xFFF4F3F1),
    surfaceHigh: Color(0xFFFFFFFF),
    track: Color(0xFFEDEBE8),
    border: Color(0xFFE3E0DC),
    text: Color(0xFF0A0A0B),
    textMuted: Color(0xFF6B6B70),
    accent: Color(0xFFEA580C),
    primary: Color(0xFF0A0A0B),
    onPrimary: Color(0xFFFFFFFF),
  );

  /// True black, AMOLED friendly.
  static const dark = Palette(
    brightness: Brightness.dark,
    bg: Color(0xFF000000),
    surface: Color(0xFF0E0E10),
    surfaceHigh: Color(0xFF17171A),
    track: Color(0xFF232328),
    border: Color(0xFF2F2F35),
    text: Color(0xFFF5F5F6),
    textMuted: Color(0xFF9A9AA0),
    accent: Color(0xFFFF7A2F),
    primary: Color(0xFFF5F5F6),
    onPrimary: Color(0xFF0A0A0B),
  );

  /// Glass on a dark background (Black, Ocean, Nebula): XPENC's Liquid
  /// Glass, iOS's dark label colours, FITNS orange. Cards and sheets take
  /// their colours from the backdrop's [GlassTone].
  static const glass = Palette(
    brightness: Brightness.dark,
    bg: Color(0xFF000000),
    surface: Color(0xFF000000),
    surfaceHigh: Color(0xFF1C1C1E),
    track: Color(0x3D787880),
    border: Color(0x33FFFFFF),
    text: Color(0xFFF5F5F7),
    textMuted: Color(0xFF9C9CA3),
    accent: Color(0xFFFF7A2F),
    primary: Color(0xFFF5F5F7),
    onPrimary: Color(0xFF0A0A0B),
  );

  /// Glass on a bright background (Aurora, White, Sunset): iOS's light
  /// label colours, FITNS orange.
  static const glassLight = Palette(
    brightness: Brightness.light,
    bg: Color(0xFFEFF2F8),
    surface: Color(0xFFEFF2F8),
    surfaceHigh: Color(0xFFFFFFFF),
    track: Color(0x1F787880),
    border: Color(0x243C3C43),
    text: Color(0xFF0A0A0F),
    textMuted: Color(0xFF65656D),
    accent: Color(0xFFEA580C),
    primary: Color(0xFF0A0A0F),
    onPrimary: Color(0xFFFFFFFF),
  );
}

/// One UI–inspired: large rounded cards, generous spacing, big titles.
/// Orange carries the main action on every screen; cards lift gently off
/// the page in light mode and get a hairline edge in dark.
class AppTheme {
  const AppTheme._();

  static const cardRadius = 24.0;
  static const controlRadius = 16.0;

  /// Inter, as in XPENC — a variable font, so one file covers every
  /// weight. Bundled in assets/fonts (SIL OFL, see Inter-OFL.txt).
  static const fontFamily = 'Inter';

  static ThemeData get light => of(Palette.light);
  static ThemeData get dark => of(Palette.dark);

  /// The Liquid Glass look, after XPENC's, over [backdrop] — light glass
  /// on a bright one, dark on a dark one.
  static ThemeData glass([GlassBackdrop backdrop = GlassBackdrop.fallback]) {
    final p = backdrop.isDark ? Palette.glass : Palette.glassLight;
    return _liquidGlass(of(p), p, backdrop);
  }

  static ThemeData of(Palette p) {
    final isDark = p.brightness == Brightness.dark;
    final scheme = ColorScheme(
      brightness: p.brightness,
      primary: p.primary,
      onPrimary: p.onPrimary,
      secondary: p.accent,
      onSecondary: Colors.white,
      error: const Color(0xFFDC2626),
      onError: Colors.white,
      surface: p.surface,
      onSurface: p.text,
      surfaceContainerHighest: p.track,
      surfaceContainerHigh: p.surfaceHigh,
      surfaceContainer: p.surfaceHigh,
      onSurfaceVariant: p.textMuted,
      outline: p.border,
      outlineVariant: p.border,
    );
    final base = ThemeData(
      useMaterial3: true,
      brightness: p.brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor: p.bg,
      splashFactory: InkSparkle.splashFactory,
      // XPENC's typeface, in every theme (bundled: the app is offline).
      fontFamily: AppTheme.fontFamily,
    );
    final text = base.textTheme.apply(bodyColor: p.text, displayColor: p.text);
    final controlShape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(controlRadius),
    );

    return base.copyWith(
      extensions: const [AppSurface.solid],
      textTheme: text.copyWith(
        displaySmall: text.displaySmall?.copyWith(
          fontWeight: FontWeight.w700,
          letterSpacing: -1,
        ),
        headlineLarge: text.headlineLarge?.copyWith(
          fontWeight: FontWeight.w700,
          letterSpacing: -0.8,
        ),
        headlineMedium: text.headlineMedium?.copyWith(
          fontWeight: FontWeight.w700,
          letterSpacing: -0.5,
        ),
        headlineSmall: text.headlineSmall?.copyWith(
          fontWeight: FontWeight.w700,
          letterSpacing: -0.3,
        ),
        titleLarge: text.titleLarge?.copyWith(
          fontWeight: FontWeight.w700,
          letterSpacing: -0.2,
        ),
        titleMedium: text.titleMedium?.copyWith(fontWeight: FontWeight.w600),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: p.bg,
        foregroundColor: p.text,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        systemOverlayStyle: isDark
            ? SystemUiOverlayStyle.light
            : SystemUiOverlayStyle.dark,
      ),
      cardTheme: CardThemeData(
        color: p.surfaceHigh,
        surfaceTintColor: Colors.transparent,
        elevation: isDark ? 0 : 2,
        shadowColor: Colors.black.withValues(alpha: 0.18),
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(cardRadius),
          side: isDark ? BorderSide(color: p.border) : BorderSide.none,
        ),
      ),
      dividerTheme: DividerThemeData(color: p.border, thickness: 1, space: 1),
      listTileTheme: ListTileThemeData(
        iconColor: p.textMuted,
        textColor: p.text,
        shape: controlShape,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: p.accent,
          foregroundColor: Colors.white,
          minimumSize: const Size(64, 52),
          shape: controlShape,
          textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(64, 52),
          shape: controlShape,
          foregroundColor: p.text,
          side: BorderSide(color: p.border),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: p.accent),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: p.accent,
        foregroundColor: Colors.white,
        elevation: 3,
        shape: controlShape,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: p.track,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: p.accent, width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 14,
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: p.surfaceHigh,
        selectedColor: p.accent.withValues(alpha: 0.18),
        checkmarkColor: p.accent,
        labelStyle: TextStyle(color: p.text, fontWeight: FontWeight.w500),
        side: BorderSide(color: p.border),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: p.surfaceHigh,
        surfaceTintColor: Colors.transparent,
        elevation: 8,
        shadowColor: Colors.black.withValues(alpha: 0.2),
        indicatorColor: p.accent.withValues(alpha: 0.2),
        indicatorShape: const StadiumBorder(),
        height: 70,
        iconTheme: WidgetStateProperty.resolveWith(
          (states) => IconThemeData(
            color: states.contains(WidgetState.selected)
                ? p.accent
                : p.textMuted,
          ),
        ),
        labelTextStyle: WidgetStateProperty.resolveWith(
          (states) => TextStyle(
            fontSize: 12,
            fontWeight: states.contains(WidgetState.selected)
                ? FontWeight.w600
                : FontWeight.w500,
            color: states.contains(WidgetState.selected) ? p.text : p.textMuted,
          ),
        ),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? Colors.white
              : p.textMuted,
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (states) =>
              states.contains(WidgetState.selected) ? p.accent : p.track,
        ),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: p.accent,
        linearTrackColor: p.track,
        circularTrackColor: p.track,
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: p.surfaceHigh,
        surfaceTintColor: Colors.transparent,
        showDragHandle: true,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(cardRadius)),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: p.surfaceHigh,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(cardRadius),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        // Above the FITNS button in the corner, not over it.
        insetPadding: const EdgeInsets.fromLTRB(16, 8, 16, 90),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(controlRadius),
        ),
      ),
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: FadeForwardsPageTransitionsBuilder(),
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
        },
      ),
    );
  }
}

/// Glass's overrides, modelled on iOS (and XPENC's Glass): frosted cards
/// with a hairline edge, capsule buttons, dense frosted sheets and menus,
/// glass back buttons, iOS page transitions with swipe-back, no ripple.
ThemeData _liquidGlass(ThemeData t, Palette p, GlassBackdrop backdrop) {
  final tone = backdrop.tone;
  const stadium = StadiumBorder();
  final scheme = t.colorScheme.copyWith(
    // Material paints menus, pickers and dropdowns with these, over content
    // and with nothing blurred behind — so they stay near-opaque.
    surfaceContainerLowest: tone.solidFrost,
    surfaceContainerLow: tone.solidFrost,
    surfaceContainer: tone.solidFrost,
    surfaceContainerHigh: tone.solidFrost,
    outline: tone.separator,
    outlineVariant: tone.separator,
  );
  return t.copyWith(
    colorScheme: scheme,
    extensions: [AppSurface(glass: true, backdrop: backdrop)],
    // The wallpaper shows through every page (see [PageBackdrop]).
    scaffoldBackgroundColor: Colors.transparent,
    canvasColor: tone.solidFrost,
    splashFactory: NoSplash.splashFactory,
    highlightColor: tone.isDark
        ? const Color(0x1FFFFFFF)
        : const Color(0x14000000),
    // Clear over the wallpaper; frosted once the page scrolls beneath.
    appBarTheme: t.appBarTheme.copyWith(
      backgroundColor: WidgetStateColor.resolveWith(
        (states) => states.contains(WidgetState.scrolledUnder)
            ? tone.floating
            : Colors.transparent,
      ),
    ),
    cardTheme: t.cardTheme.copyWith(
      color: tone.frostHigh,
      elevation: 0,
      shape: RoundedSuperellipseBorder(
        borderRadius: BorderRadius.circular(AppTheme.cardRadius),
        side: BorderSide(color: tone.edge, width: 0.5),
      ),
    ),
    dividerTheme: DividerThemeData(
      color: tone.separator,
      thickness: 0.5,
      space: 1,
    ),
    chipTheme: t.chipTheme.copyWith(
      backgroundColor: tone.fill,
      side: BorderSide.none,
    ),
    inputDecorationTheme: t.inputDecorationTheme.copyWith(fillColor: tone.fill),
    filledButtonTheme: FilledButtonThemeData(
      style: t.filledButtonTheme.style?.copyWith(
        shape: const WidgetStatePropertyAll(stadium),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: t.outlinedButtonTheme.style?.copyWith(
        shape: const WidgetStatePropertyAll(stadium),
        side: WidgetStatePropertyAll(BorderSide(color: tone.edge)),
        backgroundColor: WidgetStatePropertyAll(tone.fill),
      ),
    ),
    floatingActionButtonTheme: t.floatingActionButtonTheme.copyWith(
      shape: stadium,
    ),
    bottomSheetTheme: t.bottomSheetTheme.copyWith(
      backgroundColor: tone.floating,
      modalBackgroundColor: tone.floating,
      modalBarrierColor: tone.barrier,
    ),
    dialogTheme: t.dialogTheme.copyWith(
      backgroundColor: tone.floating,
      barrierColor: tone.barrier,
    ),
    popupMenuTheme: PopupMenuThemeData(color: tone.solidFrost),
    datePickerTheme: DatePickerThemeData(
      backgroundColor: tone.solidFrost,
      surfaceTintColor: Colors.transparent,
    ),
    timePickerTheme: TimePickerThemeData(backgroundColor: tone.solidFrost),
    snackBarTheme: t.snackBarTheme.copyWith(
      backgroundColor: tone.floating,
      contentTextStyle: TextStyle(color: p.text),
      shape: stadium,
    ),
    progressIndicatorTheme: t.progressIndicatorTheme.copyWith(
      linearTrackColor: tone.track,
      circularTrackColor: tone.track,
    ),
    // iOS's slide, with swipe-back, on every platform.
    // iOS's slide, with swipe-back, on every platform — each page on its
    // own slice of the wallpaper, so a page sliding in stays opaque.
    pageTransitionsTheme: PageTransitionsTheme(
      builders: {
        for (final platform in TargetPlatform.values)
          platform: const _BackdropTransitionsBuilder(
            CupertinoPageTransitionsBuilder(),
          ),
      },
    ),
    actionIconTheme: ActionIconThemeData(
      backButtonIconBuilder: (_) =>
          const GlassNavGlyph(Icons.arrow_back_ios_new_rounded),
      closeButtonIconBuilder: (_) => const GlassNavGlyph(Icons.close_rounded),
    ),
  );
}

/// Paints the Glass wallpaper behind a page — the stand-in for
/// `scaffoldBackgroundColor`, which Glass leaves clear.
class PageBackdrop extends StatelessWidget {
  const PageBackdrop({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final backdrop = AppSurface.of(context).backdrop;
    if (backdrop == null) return child;
    // The RepaintBoundary keeps content changes from repainting the
    // wallpaper.
    return GlassWallpaper(
      backdrop: backdrop,
      child: RepaintBoundary(child: child),
    );
  }
}

/// [inner]'s transition, around a page that carries its own backdrop — so
/// clear Glass scaffolds stay opaque as whole routes.
class _BackdropTransitionsBuilder extends PageTransitionsBuilder {
  const _BackdropTransitionsBuilder(this.inner);

  final PageTransitionsBuilder inner;

  @override
  DelegatedTransitionBuilder? get delegatedTransition =>
      inner.delegatedTransition;

  @override
  Duration get transitionDuration => inner.transitionDuration;

  @override
  Duration get reverseTransitionDuration => inner.reverseTransitionDuration;

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) => inner.buildTransitions(
    route,
    context,
    animation,
    secondaryAnimation,
    PageBackdrop(child: child),
  );
}

extension FitnsColors on ThemeData {
  Color get accent => colorScheme.secondary;

  /// The hero gradient: FITNS orange into a deeper red-orange.
  LinearGradient get accentGradient => LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [accent, Color.lerp(accent, const Color(0xFFB91C1C), 0.55)!],
  );
  Color get muted => colorScheme.onSurfaceVariant;
  Color get track => colorScheme.surfaceContainerHighest;
}
