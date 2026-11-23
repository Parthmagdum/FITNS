// The Glass theme's building blocks, adapted from XPENC's Liquid Glass
// (https://github.com/PATILYASHH/XPENC — MIT License, Copyright (c) 2026
// Yash Patil). See CREDITS.md.

import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

/// Glass, modelled on iOS's Liquid Glass, over the wallpaper picked in
/// Settings ([GlassBackdrop]) — the way XPENC draws it. Two materials:
///  * **Content** ([GlassPane]): cards. A thin, see-through frost with a
///    rim that catches light along its top edge.
///  * **Controls** ([LiquidGlass]): what floats above content — the tab
///    bar, back buttons. Near-clear glass with real *lensing*: on Impeller a
///    fragment shader bends what's behind at the rim
///    (`shaders/liquid_glass.frag`); elsewhere it degrades to blur alone.
class GlassStyle {
  const GlassStyle._();

  /// Controls: barely any blur — the lens needs detail behind it to bend.
  static const double controlBlur = 3.5;

  /// The tab bar: whole rows of cards slide under it, so it diffuses a
  /// little more to stay calm.
  static const double barBlur = 9;
}

/// Every colour a glass surface takes, for one kind of background — XPENC's
/// four tones. Light glass is a whisper of white over a bright backdrop;
/// dark glass a smoky one over a dark backdrop, with softer rims and deeper
/// shadows.
@immutable
class GlassTone {
  const GlassTone({
    required this.brightness,
    required this.frostHigh,
    required this.frostLow,
    required this.controlFrost,
    required this.selected,
    required this.sheetFrost,
    required this.floating,
    required this.solidFrost,
    required this.fill,
    required this.separator,
    required this.rimStrength,
    required this.shadowOpacity,
    required this.barrier,
    required this.track,
    required this.edge,
    required this.ambient,
    this.ambientBlur = 18,
    Color? barFrost,
  }) : _barFrost = barFrost;

  final Brightness brightness;

  /// Content pane frost, top to bottom.
  final Color frostHigh;
  final Color frostLow;

  /// Control frost — nearly clear.
  final Color controlFrost;

  /// The selected-tab droplet.
  final Color selected;

  /// Sheets and dialogs hold forms and lists, so they frost denser.
  final Color sheetFrost;
  final Color floating;

  /// Menus and pickers Material paints with nothing blurred behind them.
  final Color solidFrost;

  /// Inputs, chips and secondary buttons.
  final Color fill;
  final Color separator;

  /// Multiplier on the white rim's brightness.
  final double rimStrength;
  final double shadowOpacity;
  final Color barrier;
  final Color track;

  /// Hairline edge of inputs and plain cards.
  final Color edge;

  /// Opacity of the coloured glow around cards (the wallpaper's light
  /// spilling round the glass); 0 for none.
  final double ambient;

  /// How far that glow may spread (its largest blur sigma).
  final double ambientBlur;

  /// The tab bar's frost: whole lists slide under it, so where content is
  /// busy it smokes over what passes beneath. Defaults to [controlFrost].
  Color get barFrost => _barFrost ?? controlFrost;
  final Color? _barFrost;

  bool get isDark => brightness == Brightness.dark;

  /// Light glass over a colourful, bright backdrop.
  static const light = GlassTone(
    brightness: Brightness.light,
    frostHigh: Color(0x61FFFFFF),
    frostLow: Color(0x38FFFFFF),
    controlFrost: Color(0x1FFFFFFF),
    selected: Color(0x1F787880),
    sheetFrost: Color(0xB8F7F8FC),
    floating: Color(0xF2FFFFFF),
    solidFrost: Color(0xF5F8F9FC),
    fill: Color(0x80FFFFFF),
    separator: Color(0x243C3C43),
    rimStrength: 1,
    shadowOpacity: 0.10,
    barrier: Color(0x29000000),
    track: Color(0x1F787880),
    ambient: 0.42,
    edge: Color(0xB3FFFFFF),
    barFrost: Color(0x66FFFFFF),
  );

  /// Light glass over a plain white page — cards need body to show at all.
  static const paper = GlassTone(
    brightness: Brightness.light,
    frostHigh: Color(0xF2FFFFFF),
    frostLow: Color(0xE0FFFFFF),
    controlFrost: Color(0x8CFFFFFF),
    selected: Color(0x1F787880),
    sheetFrost: Color(0xD9F7F8FC),
    floating: Color(0xF5FFFFFF),
    solidFrost: Color(0xF5F8F9FC),
    fill: Color(0xFFFFFFFF),
    separator: Color(0x243C3C43),
    rimStrength: 1,
    shadowOpacity: 0.08,
    barrier: Color(0x29000000),
    track: Color(0x1F787880),
    ambient: 0.18,
    edge: Color(0x1F3C3C43),
    barFrost: Color(0xB3FFFFFF),
  );

  /// Dark glass over a colourful, dark backdrop: smoky, the way iOS's dark
  /// glass reads over a vivid wallpaper.
  static const dark = GlassTone(
    brightness: Brightness.dark,
    frostHigh: Color(0x660E1020),
    frostLow: Color(0x8C0E1020),
    controlFrost: Color(0x4D12141F),
    selected: Color(0x1FFFFFFF),
    sheetFrost: Color(0xBF1C1C1E),
    floating: Color(0xF22C2C2E),
    solidFrost: Color(0xF22C2C2E),
    fill: Color(0x29FFFFFF),
    separator: Color(0x33FFFFFF),
    rimStrength: 0.55,
    shadowOpacity: 0.35,
    barrier: Color(0x66000000),
    track: Color(0x3D787880),
    ambient: 0.5,
    edge: Color(0x33FFFFFF),
    barFrost: Color(0x8012141F),
  );

  /// Dark glass over pure black — iOS's dark grouped look, in glass.
  static const ink = GlassTone(
    brightness: Brightness.dark,
    frostHigh: Color(0x29FFFFFF),
    frostLow: Color(0x1AFFFFFF),
    controlFrost: Color(0x29FFFFFF),
    selected: Color(0x38FFFFFF),
    sheetFrost: Color(0xD91C1C1E),
    floating: Color(0xF22C2C2E),
    solidFrost: Color(0xF22C2C2E),
    fill: Color(0x29FFFFFF),
    separator: Color(0x33FFFFFF),
    rimStrength: 0.5,
    shadowOpacity: 0.5,
    barrier: Color(0x80000000),
    track: Color(0x3D787880),
    // On black there's no wallpaper light to spill: cards stand on their
    // own top-lit rim.
    ambient: 0,
    ambientBlur: 7,
    edge: Color(0x33FFFFFF),
    barFrost: Color(0xA62C2C2E),
  );
}

// The five places light pools on a wallpaper, as (centre, radius as a
// fraction of the screen's longer side).
const _poolSpots = <(Alignment, double)>[
  (Alignment(-1.0, -0.95), 0.62),
  (Alignment(1.1, -0.45), 0.55),
  (Alignment(-0.9, 0.35), 0.50),
  (Alignment(1.0, 0.85), 0.58),
  (Alignment(-0.2, 1.15), 0.45),
];

/// What the Glass theme sits on — picked under Settings → Appearance. Plain
/// pages (white, black) or soft pools of colour, the way iOS wallpapers
/// glow behind its glass. XPENC's six, value for value.
///
/// The name is what gets stored, so **never rename a value**. Add new ones
/// at the end.
enum GlassBackdrop {
  aurora(
    label: 'Aurora',
    tone: GlassTone.light,
    base: Color(0xFFEFF2F8),
    pools: [
      Color(0xFFA9C4FF),
      Color(0xFFE6C8FF),
      Color(0xFFBDEBE0),
      Color(0xFFFFD6BF),
      Color(0xFFC9D6FF),
    ],
  ),
  white(label: 'White', tone: GlassTone.paper, base: Color(0xFFF2F2F7)),
  black(label: 'Black', tone: GlassTone.ink, base: Color(0xFF000000)),
  ocean(
    label: 'Ocean',
    tone: GlassTone.dark,
    base: Color(0xFF03101F),
    pools: [
      Color(0xFF0D5BA8),
      Color(0xFF0E8AA6),
      Color(0xFF2A3FB0),
      Color(0xFF0A7A72),
      Color(0xFF1B4C9E),
    ],
  ),
  sunset(
    label: 'Sunset',
    tone: GlassTone.light,
    base: Color(0xFFFFEDE3),
    pools: [
      Color(0xFFFFB08A),
      Color(0xFFFF8FBA),
      Color(0xFFC6A0FF),
      Color(0xFFFFD07A),
      Color(0xFFFF9E9E),
    ],
  ),
  nebula(
    label: 'Nebula',
    tone: GlassTone.dark,
    base: Color(0xFF07040F),
    pools: [
      Color(0xFF5B2BBF),
      Color(0xFFB0307E),
      Color(0xFF2A4FD6),
      Color(0xFF0F7F8A),
      Color(0xFF7A2BB0),
    ],
  );

  const GlassBackdrop({
    required this.label,
    required this.tone,
    required this.base,
    this.pools = const [],
  });

  final String label;
  final GlassTone tone;
  final Color base;

  /// Colours pooled at [_poolSpots]; empty for a plain page.
  final List<Color> pools;

  static const fallback = GlassBackdrop.aurora;

  bool get isDark => tone.isDark;

  static GlassBackdrop byName(String? name) =>
      values.asNameMap()[name] ?? fallback;

  /// The wallpaper's colour of light around [point] (screen coordinates):
  /// its pools blended by nearness, pushed a little more saturated so a
  /// glow reads as coloured light. Plain pages give a soft cool white.
  Color ambientAt(Offset point, Size screen) {
    if (pools.isEmpty) {
      return isDark ? const Color(0xFFFFFFFF) : const Color(0xFF8FA8FF);
    }
    final rect = Offset.zero & screen;
    final side = screen.longestSide;
    var r = 0.0, g = 0.0, b = 0.0, w = 0.0;
    for (var i = 0; i < pools.length && i < _poolSpots.length; i++) {
      final (align, radius) = _poolSpots[i];
      final d = (point - align.withinRect(rect)).distance / (side * radius);
      var weight = (1 - d).clamp(0.0, 1.0);
      weight *= weight;
      final c = pools[i];
      r += c.r * weight;
      g += c.g * weight;
      b += c.b * weight;
      w += weight;
    }
    if (w < 0.0001) return pools.first;
    final hsl = HSLColor.fromColor(
      Color.from(alpha: 1, red: r / w, green: g / w, blue: b / w),
    );
    return hsl
        .withSaturation((hsl.saturation * 1.25).clamp(0.0, 1.0))
        .withLightness(
          isDark
              ? (hsl.lightness * 1.25).clamp(0.2, 0.65)
              : hsl.lightness.clamp(0.5, 0.78),
        )
        .toColor();
  }

  /// Paints this wallpaper for a screen of [screen] size into [canvas],
  /// whose origin is the screen's top-left.
  void paint(Canvas canvas, Size screen) {
    final rect = Offset.zero & screen;
    canvas.drawRect(rect, Paint()..color = base);
    final side = screen.longestSide;
    for (var i = 0; i < pools.length && i < _poolSpots.length; i++) {
      final (align, r) = _poolSpots[i];
      final color = pools[i];
      final centre = align.withinRect(rect);
      final radius = side * r;
      canvas.drawCircle(
        centre,
        radius,
        Paint()
          ..shader = ui.Gradient.radial(
            centre,
            radius,
            [color, color.withValues(alpha: 0.55), color.withValues(alpha: 0)],
            const [0, 0.5, 1],
          ),
      );
    }
    if (pools.isEmpty) return;
    // Dark wallpapers sit a step back, so text printed straight on them
    // (section headers, big titles) stays readable over the colour.
    if (isDark) canvas.drawRect(rect, Paint()..color = const Color(0x40000000));
    // A veil at the top keeps the status bar and large titles crisp.
    final veil = isDark ? const Color(0x59000000) : const Color(0x8CFFFFFF);
    canvas.drawRect(
      rect,
      Paint()
        ..shader = ui.Gradient.linear(rect.topCenter, rect.center, [
          veil,
          veil.withValues(alpha: 0),
        ]),
    );
  }
}

/// Whether the current theme is Glass, and what it sits on. Read with
/// [AppSurface.of].
@immutable
class AppSurface extends ThemeExtension<AppSurface> {
  const AppSurface({required this.glass, this.backdrop});

  static const solid = AppSurface(glass: false);

  final bool glass;

  /// The Glass wallpaper, painted behind every page. `null` outside Glass.
  final GlassBackdrop? backdrop;

  GlassTone get tone => (backdrop ?? GlassBackdrop.fallback).tone;

  static AppSurface of(BuildContext context) =>
      Theme.of(context).extension<AppSurface>() ?? solid;

  static bool isGlass(BuildContext context) => of(context).glass;

  @override
  AppSurface copyWith({bool? glass, GlassBackdrop? backdrop}) => AppSurface(
    glass: glass ?? this.glass,
    backdrop: backdrop ?? this.backdrop,
  );

  @override
  AppSurface lerp(AppSurface? other, double t) =>
      t < 0.5 ? this : (other ?? this);
}

/// Paints the Glass wallpaper behind [child], in *screen* coordinates — so a
/// page nested inside another shows exactly the slice of wallpaper around
/// it, with no seam where they meet.
class GlassWallpaper extends SingleChildRenderObjectWidget {
  const GlassWallpaper({required this.backdrop, super.child, super.key});

  final GlassBackdrop backdrop;

  @override
  RenderObject createRenderObject(BuildContext context) =>
      RenderGlassWallpaper(MediaQuery.sizeOf(context), backdrop);

  @override
  void updateRenderObject(
    BuildContext context,
    RenderGlassWallpaper renderObject,
  ) {
    renderObject
      ..screen = MediaQuery.sizeOf(context)
      ..backdrop = backdrop;
  }
}

class RenderGlassWallpaper extends RenderProxyBox {
  RenderGlassWallpaper(this._screen, this._backdrop);

  Size _screen;
  set screen(Size value) {
    if (value == _screen) return;
    _screen = value;
    markNeedsPaint();
  }

  GlassBackdrop _backdrop;
  set backdrop(GlassBackdrop value) {
    if (value == _backdrop) return;
    _backdrop = value;
    markNeedsPaint();
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    final canvas = context.canvas;
    final rect = offset & size;
    final origin = localToGlobal(Offset.zero);
    if (_backdrop.pools.isEmpty || _screen.isEmpty || !origin.isFinite) {
      // A plain page: one flat fill, nothing worth caching.
      canvas.drawRect(rect, Paint()..color = _backdrop.base);
    } else {
      final image = _WallpaperCache.imageFor(_backdrop, _screen);
      // The slice of the screen-sized wallpaper this box covers.
      final src = Rect.fromLTWH(
        origin.dx * image.width / _screen.width,
        origin.dy * image.height / _screen.height,
        size.width * image.width / _screen.width,
        size.height * image.height / _screen.height,
      );
      canvas.drawImageRect(
        image,
        src,
        rect,
        Paint()..filterQuality = FilterQuality.low,
      );
    }
    super.paint(context, offset);
  }
}

/// The wallpaper, rasterised once per background and screen size, at
/// logical resolution: soft gradients scale up invisibly.
class _WallpaperCache {
  static GlassBackdrop? _backdrop;
  static Size? _screen;
  static ui.Image? _image;

  static ui.Image imageFor(GlassBackdrop backdrop, Size screen) {
    final cached = _image;
    if (cached != null && _backdrop == backdrop && _screen == screen) {
      return cached;
    }
    final recorder = ui.PictureRecorder();
    backdrop.paint(Canvas(recorder), screen);
    final picture = recorder.endRecording();
    final image = picture.toImageSync(
      screen.width.ceil().clamp(1, 4096),
      screen.height.ceil().clamp(1, 4096),
    );
    picture.dispose();
    cached?.dispose();
    _backdrop = backdrop;
    _screen = screen;
    return _image = image;
  }
}

/// A small picture of [backdrop], for picking one.
class GlassBackdropSwatch extends StatelessWidget {
  const GlassBackdropSwatch(this.backdrop, {super.key});

  final GlassBackdrop backdrop;

  @override
  Widget build(BuildContext context) => CustomPaint(
    painter: _SwatchPainter(backdrop),
    child: const SizedBox.expand(),
  );
}

class _SwatchPainter extends CustomPainter {
  _SwatchPainter(this.backdrop);

  final GlassBackdrop backdrop;

  @override
  void paint(Canvas canvas, Size size) => backdrop.paint(canvas, size);

  @override
  bool shouldRepaint(_SwatchPainter old) => old.backdrop != backdrop;
}

/// Loads and holds the lens shader. [program] stays `null` where the
/// renderer can't run shader filters (Skia, tests), and every glass surface
/// then falls back to blur alone.
class LiquidGlassShader {
  const LiquidGlassShader._();

  static ui.FragmentProgram? _program;
  static ui.FragmentProgram? get program => _program;

  /// Call once before `runApp`. Never throws: a failure only costs the lens.
  static Future<void> load() async {
    if (_program != null || !ui.ImageFilter.isShaderFilterSupported) return;
    try {
      _program = await ui.FragmentProgram.fromAsset(
        'shaders/liquid_glass.frag',
      );
    } catch (e) {
      debugPrint('Liquid Glass lens unavailable: $e');
    }
  }
}

/// A content pane — a card. A thin, see-through frost over the wallpaper in
/// iOS's continuous-corner squircle, a light-catching rim, and *ambient
/// light*: a soft glow around it, tinted by the wallpaper colour where the
/// card sits, as if the backdrop's light spilled around the glass.
///
/// No backdrop blur: behind a card is only the wallpaper, already a soft
/// wash of colour, so a blur pass would cost GPU time for nothing.
class GlassPane extends StatelessWidget {
  const GlassPane({
    required this.child,
    required this.borderRadius,
    this.shadow = true,
    super.key,
  });

  final Widget child;
  final BorderRadius borderRadius;

  /// The ambient glow outside the pane.
  final bool shadow;

  @override
  Widget build(BuildContext context) {
    final surface = AppSurface.of(context);
    final tone = surface.tone;
    final pane = ClipRSuperellipse(
      borderRadius: borderRadius,
      child: CustomPaint(
        foregroundPainter: GlassRimPainter(
          borderRadius,
          strength: 0.85 * tone.rimStrength,
          continuous: true,
          topLit: true,
        ),
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              // Lit from above, like the rim: the slab is brightest where
              // the light enters it.
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [tone.frostHigh, tone.frostLow],
            ),
          ),
          child: child,
        ),
      ),
    );
    if (!shadow || tone.ambient <= 0) return pane;
    return _AmbientLight(
      backdrop: surface.backdrop ?? GlassBackdrop.fallback,
      radius: borderRadius,
      screen: MediaQuery.sizeOf(context),
      child: pane,
    );
  }
}

/// Paints a pane's ambient glow — outside it, mostly — with the glow's
/// colour sampled from the wallpaper at the pane's place on screen.
class _AmbientLight extends SingleChildRenderObjectWidget {
  const _AmbientLight({
    required this.backdrop,
    required this.radius,
    required this.screen,
    super.child,
  });

  final GlassBackdrop backdrop;
  final BorderRadius radius;
  final Size screen;

  @override
  RenderObject createRenderObject(BuildContext context) =>
      _RenderAmbientLight(backdrop, radius, screen);

  @override
  void updateRenderObject(BuildContext context, _RenderAmbientLight r) => r
    ..backdrop = backdrop
    ..radius = radius
    ..screen = screen;
}

class _RenderAmbientLight extends RenderProxyBox {
  _RenderAmbientLight(this._backdrop, this._radius, this._screen);

  GlassBackdrop _backdrop;
  set backdrop(GlassBackdrop v) {
    if (v == _backdrop) return;
    _backdrop = v;
    markNeedsPaint();
  }

  BorderRadius _radius;
  set radius(BorderRadius v) {
    if (v == _radius) return;
    _radius = v;
    markNeedsPaint();
  }

  Size _screen;
  set screen(Size v) {
    if (v == _screen) return;
    _screen = v;
    markNeedsPaint();
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    final rect = offset & size;
    // Where the pane is on screen; not finite while it's scaled to nothing
    // (a pane growing in from a point), and then there's no glow to draw.
    final centre = localToGlobal(size.center(Offset.zero));
    if (!rect.isEmpty && centre.isFinite) {
      // A plain blurred rrect, drawn analytically (nearly free), where a
      // blurred squircle would cost a full blur pass per card per frame —
      // and inside a soft glow the two shapes look the same.
      final shape = _radius.toRRect(rect);
      final tone = _backdrop.tone;
      final glow = _backdrop.ambientAt(centre, _screen);
      final side = size.shortestSide;
      final spread = tone.ambientBlur;
      context.canvas.drawRRect(
        shape.inflate((side * 0.03).clamp(1.0, spread / 4.5)),
        Paint()
          ..color = glow.withValues(alpha: tone.ambient * 0.7)
          ..maskFilter = MaskFilter.blur(
            BlurStyle.normal,
            (side * 0.14).clamp(math.min(7.0, spread), spread),
          ),
      );
    }
    super.paint(context, offset);
  }
}

/// Liquid Glass — the control material. Clear, lensed glass for anything
/// that floats above content.
///
/// [borderRadius] defaults to a capsule (half the shorter side, resolved
/// from the laid-out size).
class LiquidGlass extends StatelessWidget {
  const LiquidGlass({
    required this.child,
    this.borderRadius,
    this.frost,
    this.blur = GlassStyle.controlBlur,
    this.refraction = 18,
    this.band = 22,
    this.light = 1,
    this.shadow = true,
    this.backdrop = true,
    super.key,
  });

  final Widget child;
  final BorderRadius? borderRadius;

  /// Defaults to the near-clear control frost.
  final Color? frost;
  final double blur;

  /// Lens strength (logical pixels the rim pulls the backdrop inward) and
  /// the width of the curved rim band.
  final double refraction;
  final double band;

  /// How strongly the glass takes the light of what's behind it. Needs the
  /// lens shader; 0 turns it off.
  final double light;
  final bool shadow;

  /// Whether to read (blur, bend) what's behind. Off for glass that only
  /// ever sits on the plain page, where a backdrop pass shows nothing new.
  final bool backdrop;

  @override
  Widget build(BuildContext context) {
    final tone = AppSurface.of(context).tone;
    Widget body = DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          // Thickness: light pools at the top of the slab, a shade at its
          // foot.
          colors: [
            Colors.white.withValues(alpha: 0.2 * tone.rimStrength),
            Colors.white.withValues(alpha: 0),
            Colors.black.withValues(alpha: 0.03),
          ],
          stops: const [0, 0.45, 1],
        ),
      ),
      child: child,
    );
    body = DecoratedBox(
      decoration: BoxDecoration(color: frost ?? tone.controlFrost),
      child: body,
    );
    final continuous = borderRadius != null;
    Widget glass = CustomPaint(
      foregroundPainter: GlassRimPainter(
        borderRadius,
        strength: tone.rimStrength,
        continuous: continuous,
      ),
      child: body,
    );
    final lens = !backdrop || (blur <= 0 && refraction <= 0 && light <= 0)
        ? glass
        : _LensFilter(
            radius: borderRadius?.topLeft.x,
            blur: blur,
            refraction: refraction,
            band: band,
            light: light,
            dark: tone.isDark,
            dpr: MediaQuery.devicePixelRatioOf(context),
            screen: MediaQuery.sizeOf(context),
            child: glass,
          );
    glass = continuous
        ? ClipRSuperellipse(borderRadius: borderRadius!, child: lens)
        : ClipRRect(clipper: _GlassClipper(borderRadius), child: lens);
    if (!shadow) return glass;
    return CustomPaint(
      painter: GlassShadowPainter(borderRadius, opacity: tone.shadowOpacity),
      child: glass,
    );
  }
}

/// [radius], or a capsule of whatever size the pane turned out to be.
BorderRadius _resolve(BorderRadius? radius, Size size) =>
    radius ?? BorderRadius.circular(size.shortestSide / 2);

class _GlassClipper extends CustomClipper<RRect> {
  _GlassClipper(this.radius);

  final BorderRadius? radius;

  @override
  RRect getClip(Size size) =>
      _resolve(radius, size).toRRect(Offset.zero & size);

  @override
  bool shouldReclip(_GlassClipper old) => old.radius != radius;
}

/// The backdrop filter behind a [LiquidGlass]: on Impeller the lens shader
/// (after a light blur), otherwise blur alone.
class _LensFilter extends SingleChildRenderObjectWidget {
  const _LensFilter({
    required this.radius,
    required this.blur,
    required this.refraction,
    required this.band,
    required this.light,
    required this.dark,
    required this.dpr,
    required this.screen,
    super.child,
  });

  /// Dark glass: the light it takes adds rather than tints.
  final bool dark;

  /// `null` = a capsule, resolved from the laid-out size.
  final double? radius;
  final double blur;
  final double refraction;
  final double band;
  final double light;
  final double dpr;
  final Size screen;

  @override
  RenderObject createRenderObject(BuildContext context) => _RenderLensFilter()
    ..radius = radius
    ..blur = blur
    ..refraction = refraction
    ..band = band
    ..light = light
    ..dark = dark
    ..dpr = dpr
    ..screen = screen;

  @override
  void updateRenderObject(BuildContext context, _RenderLensFilter r) => r
    ..radius = radius
    ..blur = blur
    ..refraction = refraction
    ..band = band
    ..light = light
    ..dark = dark
    ..dpr = dpr
    ..screen = screen;
}

class _RenderLensFilter extends RenderProxyBox {
  double? _radius;
  double _blur = 0, _refraction = 0, _band = 0, _dpr = 1, _light = 0;
  Size _screen = Size.zero;

  set radius(double? v) {
    if (_radius == v) return;
    _radius = v;
    markNeedsPaint();
  }

  set blur(double v) => _set(_blur, v, (x) => _blur = x);
  set refraction(double v) => _set(_refraction, v, (x) => _refraction = x);
  set band(double v) => _set(_band, v, (x) => _band = x);
  set dpr(double v) => _set(_dpr, v, (x) => _dpr = x);
  set light(double v) => _set(_light, v, (x) => _light = x);

  bool _dark = true;
  set dark(bool v) {
    if (_dark == v) return;
    _dark = v;
    markNeedsPaint();
  }

  set screen(Size v) {
    if (_screen == v) return;
    _screen = v;
    markNeedsPaint();
  }

  void _set(double old, double v, void Function(double) write) {
    if (old == v) return;
    write(v);
    markNeedsPaint();
  }

  @override
  bool get alwaysNeedsCompositing => child != null;

  final _blurLayer = LayerHandle<BackdropFilterLayer>();
  final _lensLayer = LayerHandle<BackdropFilterLayer>();

  @override
  void dispose() {
    _blurLayer.layer = null;
    _lensLayer.layer = null;
    super.dispose();
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    if (child == null) return;
    // Two passes, not one composed filter: composing lets the engine pad
    // the shader's input by the blur radius, and the lens then can't tell
    // where the pane sits in it. Blur first, then the lens bends the
    // blurred backdrop.
    final program = LiquidGlassShader.program;
    final lens = program != null && (_refraction > 0 || _light > 0);
    if (_blur > 0) {
      _blurLayer.layer ??= BackdropFilterLayer();
      _blurLayer.layer!.filter = ui.ImageFilter.blur(
        sigmaX: _blur,
        sigmaY: _blur,
        tileMode: TileMode.mirror,
      );
    } else {
      _blurLayer.layer = null;
    }
    if (!lens) {
      _lensLayer.layer = null;
      if (_blurLayer.layer == null) {
        super.paint(context, offset);
      } else {
        context.pushLayer(_blurLayer.layer!, super.paint, offset);
      }
      return;
    }
    final origin = localToGlobal(Offset.zero) * _dpr;
    final shader = program.fragmentShader()
      // 0–1: uSize, written by the engine.
      ..setFloat(2, origin.dx)
      ..setFloat(3, origin.dy)
      ..setFloat(4, size.width * _dpr)
      ..setFloat(5, size.height * _dpr)
      ..setFloat(6, (_radius ?? size.shortestSide / 2) * _dpr)
      ..setFloat(7, _refraction * _dpr)
      ..setFloat(8, _band * _dpr)
      ..setFloat(9, 0.18)
      ..setFloat(10, 1.04)
      ..setFloat(11, _screen.width * _dpr)
      ..setFloat(12, _screen.height * _dpr)
      ..setFloat(13, _light)
      ..setFloat(14, _dark ? 1 : 0);
    _lensLayer.layer ??= BackdropFilterLayer();
    _lensLayer.layer!.filter = ui.ImageFilter.shader(shader);
    void lensPass(PaintingContext context, Offset offset) =>
        context.pushLayer(_lensLayer.layer!, super.paint, offset);
    if (_blurLayer.layer == null) {
      lensPass(context, offset);
    } else {
      context.pushLayer(_blurLayer.layer!, lensPass, offset);
    }
  }
}

/// The glyph inside a Glass back/close button: a small glass disc. Used by
/// the Glass theme's `actionIconTheme`, so every app bar's automatic back
/// button wears it with no per-screen change.
class GlassNavGlyph extends StatelessWidget {
  const GlassNavGlyph(this.icon, {super.key});

  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: 40,
      child: LiquidGlass(
        backdrop: false,
        child: Center(
          child: Icon(
            icon,
            size: 20,
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
      ),
    );
  }
}

/// The rim of a glass pane: bright where light would catch it (top-left),
/// all but gone along the sides, catching again at the bottom-right.
///
/// [topLit] is the content-pane rim: light enters along the top edge and
/// fades within the first few points, with only a faint hairline below.
class GlassRimPainter extends CustomPainter {
  GlassRimPainter(
    this.radius, {
    this.strength = 1,
    this.continuous = false,
    this.topLit = false,
  });

  /// `null` = a capsule.
  final BorderRadius? radius;
  final double strength;

  /// iOS continuous (squircle) corners rather than circular ones.
  final bool continuous;
  final bool topLit;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final inner = rect.deflate(0.5);
    final Shader shader;
    if (topLit) {
      // A fixed depth, not a fraction of the pane, so a tall card and a
      // short row catch the same sliver of light.
      final lit = (28 / math.max(size.height, 1)).clamp(0.0, 0.5);
      shader = ui.Gradient.linear(
        rect.topCenter,
        rect.bottomCenter,
        [
          Colors.white.withValues(alpha: 0.85 * strength),
          Colors.white.withValues(alpha: 0.16 * strength),
          Colors.white.withValues(alpha: 0.08 * strength),
          Colors.white.withValues(alpha: 0.14 * strength),
        ],
        [0, lit, 1 - lit * 0.5, 1],
      );
    } else {
      // Swept round the centre, so the light sits on the corners whatever
      // the shape. Angles run clockwise from 3 o'clock.
      shader = ui.Gradient.sweep(
        rect.center,
        [
          for (final a in const [
            0.22, // right
            0.6, // bottom-right
            0.05, // bottom
            0.05, // bottom-left
            0.3, // left
            0.95, // top-left — where the light comes from
            0.28, // top
            0.08, // top-right
            0.22, // right again
          ])
            Colors.white.withValues(alpha: a * strength),
        ],
        const [0, 0.125, 0.25, 0.375, 0.5, 0.625, 0.75, 0.875, 1],
      );
    }
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..shader = shader;
    final r = _resolve(radius, size);
    if (continuous) {
      canvas.drawRSuperellipse(r.toRSuperellipse(inner), paint);
    } else {
      canvas.drawRRect(r.toRRect(inner), paint);
    }
  }

  @override
  bool shouldRepaint(GlassRimPainter old) =>
      old.radius != radius ||
      old.strength != strength ||
      old.continuous != continuous ||
      old.topLit != topLit;
}

/// A soft drop shadow drawn only *outside* the pane — under translucent
/// glass a shadow would otherwise show through and grey the frost.
class GlassShadowPainter extends CustomPainter {
  GlassShadowPainter(this.radius, {this.opacity = 0.1});

  /// `null` = a capsule.
  final BorderRadius? radius;
  final double opacity;

  @override
  void paint(Canvas canvas, Size size) {
    final rrect = _resolve(radius, size).toRRect(Offset.zero & size);
    final side = size.shortestSide;
    final spread = (side * 0.1).clamp(3.0, 14.0);
    final lift = (side * 0.06).clamp(1.5, 6.0);
    final outside = Path.combine(
      PathOperation.difference,
      Path()..addRect((Offset.zero & size).inflate(48)),
      Path()..addRRect(rrect),
    );
    canvas
      ..save()
      ..clipPath(outside)
      ..drawRRect(
        rrect.shift(Offset(0, lift)),
        Paint()
          ..color = Color.fromRGBO(30, 34, 60, opacity)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, spread),
      )
      ..restore();
  }

  @override
  bool shouldRepaint(GlassShadowPainter old) =>
      old.radius != radius || old.opacity != opacity;
}
