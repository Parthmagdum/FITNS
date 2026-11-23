// The floating tab bar, adapted from XPENC's Glass tab bar
// (https://github.com/PATILYASHH/XPENC — MIT License, Copyright (c) 2026
// Yash Patil). See CREDITS.md.

import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../theme/glass.dart';

/// One tab: icon, selected icon, label.
typedef TabSpec = (IconData, IconData, String);

/// The tab bar as a capsule floating over the page, after iOS (and XPENC):
/// a droplet slides to the selected tab, stretching a little in flight.
/// Liquid Glass under Glass; a raised card in the other themes.
class FloatingTabBar extends StatelessWidget {
  const FloatingTabBar({
    super.key,
    required this.tabs,
    required this.selected,
    required this.onSelect,
    this.showLabels = true,
    this.extraBottom = 0,
  });

  final List<TabSpec> tabs;
  final int selected;
  final ValueChanged<int> onSelect;
  final bool showLabels;

  /// Extra room below the bar (Settings → Navigation → Bottom spacing).
  final double extraBottom;

  /// The capsule's height, with labels and without.
  static double heightFor({required bool labels}) => labels ? 62 : 54;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final glass = AppSurface.isGlass(context);
    final tone = AppSurface.of(context).tone;
    final height = heightFor(labels: showLabels);
    final tabsRow = LayoutBuilder(
      builder: (context, box) {
        final itemWidth = box.maxWidth / tabs.length;
        return Stack(
          children: [
            _Droplet(
              index: selected,
              itemWidth: itemWidth,
              glass: glass,
              color: glass
                  ? tone.selected
                  : theme.accent.withValues(alpha: 0.13),
            ),
            Row(
              children: [
                for (final (i, tab) in tabs.indexed)
                  Expanded(
                    child: _Tab(
                      key: Key('tab-$i'),
                      tab: tab,
                      selected: i == selected,
                      showLabel: showLabels,
                      onTap: () => onSelect(i),
                    ),
                  ),
              ],
            ),
          ],
        );
      },
    );
    final Widget capsule = glass
        ? LiquidGlass(
            borderRadius: BorderRadius.circular(height / 2),
            frost: tone.barFrost,
            blur: GlassStyle.barBlur,
            child: tabsRow,
          )
        : DecoratedBox(
            decoration: ShapeDecoration(
              color: theme.colorScheme.surfaceContainerHigh,
              shape: StadiumBorder(
                side: BorderSide(
                  color: theme.colorScheme.outlineVariant.withValues(
                    alpha: theme.brightness == Brightness.dark ? 1 : 0.6,
                  ),
                  width: 0.5,
                ),
              ),
              shadows: [
                BoxShadow(
                  color: Colors.black.withValues(
                    alpha: theme.brightness == Brightness.dark ? 0.5 : 0.12,
                  ),
                  blurRadius: 24,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: ClipPath(
              clipper: const ShapeBorderClipper(shape: StadiumBorder()),
              child: tabsRow,
            ),
          );
    return RepaintBoundary(
      child: SafeArea(
        top: false,
        minimum: const EdgeInsets.only(bottom: 10),
        child: Padding(
          padding: EdgeInsets.fromLTRB(16, 0, 16, extraBottom),
          child: Align(
            heightFactor: 1,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: SizedBox(height: height, child: capsule),
            ),
          ),
        ),
      ),
    );
  }
}

/// The selected-tab droplet. It glides to the new tab on a smooth ease and
/// stretches a little in flight, the way a drop of liquid elongates as it
/// moves, then settles round.
class _Droplet extends StatefulWidget {
  const _Droplet({
    required this.index,
    required this.itemWidth,
    required this.glass,
    required this.color,
  });

  final int index;
  final double itemWidth;
  final bool glass;
  final Color color;

  @override
  State<_Droplet> createState() => _DropletState();
}

class _DropletState extends State<_Droplet>
    with SingleTickerProviderStateMixin {
  late final _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 380),
    value: 1,
  );
  late double _from = widget.index.toDouble();
  late double _to = widget.index.toDouble();

  @override
  void didUpdateWidget(_Droplet old) {
    super.didUpdateWidget(old);
    if (old.index != widget.index) {
      // Start from wherever the droplet is now, even mid-flight.
      _from = _position;
      _to = widget.index.toDouble();
      _controller.forward(from: 0);
    }
  }

  double get _t => Curves.easeInOutCubic.transform(_controller.value);
  double get _position => _from + (_to - _from) * _t;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final w = widget.itemWidth;
        // Stretch peaks mid-flight and grows with how far it travels.
        final distance = (_to - _from).abs().clamp(0.0, 1.5);
        final stretch =
            1 + 0.22 * distance * math.sin(math.pi * _controller.value);
        final width = (w - 8) * stretch;
        final centre = _position * w + w / 2;
        return Positioned(
          left: centre - width / 2,
          top: 4,
          bottom: 4,
          width: width,
          child: child!,
        );
      },
      child: widget.glass
          ? LiquidGlass(
              frost: widget.color,
              backdrop: false,
              shadow: false,
              child: const SizedBox.expand(),
            )
          : DecoratedBox(
              decoration: ShapeDecoration(
                color: widget.color,
                shape: const StadiumBorder(),
              ),
            ),
    );
  }
}

class _Tab extends StatefulWidget {
  const _Tab({
    super.key,
    required this.tab,
    required this.selected,
    required this.showLabel,
    required this.onTap,
  });

  final TabSpec tab;
  final bool selected;
  final bool showLabel;
  final VoidCallback onTap;

  @override
  State<_Tab> createState() => _TabState();
}

class _TabState extends State<_Tab> {
  /// A finger is on this tab: its glyph dips the moment it lands and
  /// springs back as it lifts.
  bool _down = false;

  void _setDown(bool v) {
    if (_down != v) setState(() => _down = v);
  }

  @override
  Widget build(BuildContext context) {
    final (icon, selectedIcon, label) = widget.tab;
    final selected = widget.selected;
    final theme = Theme.of(context);
    // On dark glass the orange is lifted a step, or it sinks into the
    // droplet behind it.
    final accent = theme.brightness == Brightness.dark
        ? Color.lerp(theme.accent, Colors.white, 0.18)!
        : theme.accent;
    final color = selected
        ? accent
        : theme.colorScheme.onSurface.withValues(alpha: 0.78);
    return Semantics(
      selected: selected,
      button: true,
      label: label,
      excludeSemantics: true,
      child: Listener(
        onPointerDown: (_) => _setDown(true),
        onPointerUp: (_) => _setDown(false),
        onPointerCancel: (_) => _setDown(false),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: widget.onTap,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              AnimatedScale(
                scale: _down ? 0.86 : (selected ? 1.06 : 1),
                duration: Duration(milliseconds: _down ? 90 : 300),
                curve: Curves.easeOutCubic,
                child: Icon(
                  selected ? selectedIcon : icon,
                  size: 24,
                  color: color,
                ),
              ),
              if (widget.showLabel) ...[
                const SizedBox(height: 3),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      label,
                      maxLines: 1,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: color,
                        fontSize: 10.5,
                        fontWeight: FontWeight.w600,
                        letterSpacing: -0.1,
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
