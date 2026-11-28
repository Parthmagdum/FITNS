import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../theme/glass.dart';

/// A tab-level page: One UI's large title that collapses into the bar as
/// the content scrolls, over a padded list of [children].
class AppPage extends StatelessWidget {
  const AppPage({
    super.key,
    required this.title,
    required this.children,
    this.actions,
    this.floatingActionButton,
    this.bottom,
  });

  final String title;
  final List<Widget> children;
  final List<Widget>? actions;
  final Widget? floatingActionButton;

  /// Pinned under the list, above the system bar — a primary action.
  final Widget? bottom;

  /// The big title over a tab, as in XPENC: Inter at 36, heavy and tight.
  static TextStyle? largeTitle(ThemeData theme) =>
      theme.textTheme.headlineMedium?.copyWith(
        fontSize: 36,
        height: 1.1,
        fontWeight: FontWeight.w800,
        letterSpacing: -1.3,
      );

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final glass = AppSurface.of(context).backdrop;
    // Over the floating tab bar, which the page runs on beneath: the page's
    // bottom padding includes the bar, the system's doesn't.
    final lift = math.max(
      0.0,
      MediaQuery.paddingOf(context).bottom -
          MediaQuery.viewPaddingOf(context).bottom,
    );
    return Scaffold(
      floatingActionButton: floatingActionButton == null || lift == 0
          ? floatingActionButton
          : Padding(
              padding: EdgeInsets.only(bottom: lift),
              child: floatingActionButton,
            ),
      // Bottom-left: the bottom-right corner is the FITNS button's.
      floatingActionButtonLocation: FloatingActionButtonLocation.startFloat,
      bottomNavigationBar: bottom == null
          ? null
          : SafeArea(
              minimum: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: bottom!,
            ),
      body: CustomScrollView(
        slivers: [
          // The large title takes the expanded style from headlineMedium;
          // only here is it XPENC's size, so other headlines keep theirs.
          if (glass != null)
            // Glass: the wallpaper itself behind the title, frosting as it
            // collapses — no grey band, nothing showing through.
            SliverAppBar(
              pinned: true,
              expandedHeight: 156,
              toolbarHeight: 64,
              backgroundColor: Colors.transparent,
              surfaceTintColor: Colors.transparent,
              scrolledUnderElevation: 0,
              actions: actions,
              flexibleSpace: _GlassHeader(
                title: title,
                backdrop: glass,
                actions: actions?.length ?? 0,
              ),
            )
          else
            Theme(
              data: theme.copyWith(
                textTheme: theme.textTheme.copyWith(
                  headlineMedium: largeTitle(theme),
                ),
              ),
              child: SliverAppBar.large(
                expandedHeight: 156,
                title: Text(title),
                actions: actions,
              ),
            ),
          SliverPadding(
            // Clear of the FAB and of the FITNS button in the corner.
            padding: EdgeInsets.fromLTRB(
              16,
              4,
              16,
              96 + MediaQuery.paddingOf(context).bottom,
            ),
            sliver: SliverList.list(children: children),
          ),
        ],
      ),
    );
  }
}

/// A bold card on the orange gradient, for the one thing a screen is about
/// — starting a workout, the day's headline.
/// A tab page's header under Glass: its slice of the wallpaper, the large
/// title shrinking into the bar as the page scrolls, and a frost and a
/// hairline once it has.
class _GlassHeader extends StatelessWidget {
  const _GlassHeader({
    required this.title,
    required this.backdrop,
    required this.actions,
  });

  final String title;
  final GlassBackdrop backdrop;
  final int actions;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tone = backdrop.tone;
    final settings = context
        .dependOnInheritedWidgetOfExactType<FlexibleSpaceBarSettings>();
    final span = settings == null
        ? 0.0
        : settings.maxExtent - settings.minExtent;
    // 1 open, 0 collapsed into the bar.
    final t = settings == null || span <= 0
        ? 1.0
        : ((settings.currentExtent - settings.minExtent) / span).clamp(
            0.0,
            1.0,
          );
    final big = AppPage.largeTitle(theme);
    final size = lerpDouble(20, big?.fontSize ?? 36, t)!;
    final veil = tone.isDark
        ? Colors.black.withValues(alpha: 0.28 * (1 - t))
        : Colors.white.withValues(alpha: 0.45 * (1 - t));
    return GlassWallpaper(
      backdrop: backdrop,
      child: Stack(
        fit: StackFit.expand,
        children: [
          ColoredBox(color: veil),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            height: 0.5,
            child: ColoredBox(
              color: tone.separator.withValues(
                alpha: tone.separator.a * (1 - t),
              ),
            ),
          ),
          Positioned(
            left: 20,
            right: 16 + 48.0 * actions * (1 - t),
            // Collapsed: centred in the 64-point bar.
            bottom: lerpDouble((64 - size * 1.2) / 2, 14, t),
            child: Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: big?.copyWith(
                fontSize: size,
                letterSpacing: lerpDouble(-0.3, big.letterSpacing, t),
                color: theme.colorScheme.onSurface,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class HeroCard extends StatelessWidget {
  const HeroCard({
    super.key,
    required this.child,
    this.onTap,
    this.padding = const EdgeInsets.all(20),
  });

  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final radius = BorderRadius.circular(AppTheme.cardRadius);
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: radius,
        gradient: theme.accentGradient,
        boxShadow: [
          BoxShadow(
            color: theme.accent.withValues(alpha: 0.35),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Material(
        type: MaterialType.transparency,
        borderRadius: radius,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: padding,
            child: DefaultTextStyle.merge(
              style: const TextStyle(color: Colors.white),
              child: IconTheme.merge(
                data: const IconThemeData(color: Colors.white),
                child: child,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A raised card with the standard inner padding.
class SectionCard extends StatelessWidget {
  const SectionCard({
    super.key,
    required this.child,
    this.onTap,
    this.padding = const EdgeInsets.all(20),
  });

  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final content = InkWell(
      onTap: onTap,
      child: Padding(padding: padding, child: child),
    );
    if (AppSurface.isGlass(context)) {
      // Glass: a frosted pane lit along its top edge (XPENC's GlassPane).
      return GlassPane(
        borderRadius: BorderRadius.circular(AppTheme.cardRadius),
        child: Material(type: MaterialType.transparency, child: content),
      );
    }
    return Card(clipBehavior: Clip.antiAlias, child: content);
  }
}

/// The small label above a group of cards.
class SectionLabel extends StatelessWidget {
  const SectionLabel(this.text, {super.key, this.trailing});

  final String text;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 24, 4, 10),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 16,
            margin: const EdgeInsets.only(right: 8),
            decoration: BoxDecoration(
              color: theme.accent,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Expanded(
            child: Text(
              text,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          ?trailing,
        ],
      ),
    );
  }
}

/// What an empty list shows instead: an icon, one line, maybe an action.
class EmptyHint extends StatelessWidget {
  const EmptyHint({
    super.key,
    required this.icon,
    required this.message,
    this.action,
  });

  final IconData icon;
  final String message;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
      child: Column(
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: theme.accent.withValues(alpha: 0.12),
            ),
            child: Icon(icon, size: 34, color: theme.accent),
          ),
          const SizedBox(height: 14),
          Text(
            message,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(color: theme.muted),
          ),
          if (action != null) ...[const SizedBox(height: 12), action!],
        ],
      ),
    );
  }
}

/// Rebuilds once a second with the current time — running clocks.
class TickerBuilder extends StatefulWidget {
  const TickerBuilder({super.key, required this.builder});

  final Widget Function(BuildContext context, DateTime now) builder;

  @override
  State<TickerBuilder> createState() => _TickerBuilderState();
}

class _TickerBuilderState extends State<TickerBuilder> {
  late final Timer _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => setState(() {}));
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.builder(context, DateTime.now());
}

/// A small label-over-value figure: `Duration / 52m`.
class StatTile extends StatelessWidget {
  const StatTile({super.key, required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: theme.textTheme.labelMedium?.copyWith(color: theme.muted),
        ),
        const SizedBox(height: 2),
        Text(value, style: theme.textTheme.titleMedium),
      ],
    );
  }
}

/// Asks for one line of text. Resolves to null when cancelled.
Future<String?> promptText(
  BuildContext context, {
  required String title,
  String initial = '',
  String? hint,
  String? suffix,
  TextInputType? keyboardType,
  int? maxLength,
  String action = 'Save',
}) => showDialog<String>(
  context: context,
  builder: (_) => _TextPromptDialog(
    title: title,
    initial: initial,
    hint: hint,
    suffix: suffix,
    keyboardType: keyboardType,
    maxLength: maxLength,
    action: action,
  ),
);

/// Owns its controller, so it is disposed after the closing animation rather
/// than while the field is still on screen.
class _TextPromptDialog extends StatefulWidget {
  const _TextPromptDialog({
    required this.title,
    required this.initial,
    required this.hint,
    required this.suffix,
    required this.keyboardType,
    required this.maxLength,
    required this.action,
  });

  final String title;
  final String initial;
  final String? hint;
  final String? suffix;
  final TextInputType? keyboardType;
  final int? maxLength;
  final String action;

  @override
  State<_TextPromptDialog> createState() => _TextPromptDialogState();
}

class _TextPromptDialogState extends State<_TextPromptDialog> {
  late final _controller = TextEditingController(text: widget.initial);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: TextField(
        controller: _controller,
        autofocus: true,
        keyboardType: widget.keyboardType,
        maxLength: widget.maxLength,
        textCapitalization: TextCapitalization.sentences,
        decoration: InputDecoration(
          hintText: widget.hint,
          suffixText: widget.suffix,
        ),
        onSubmitted: (value) => Navigator.pop(context, value),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context, _controller.text),
          child: Text(widget.action),
        ),
      ],
    );
  }
}

/// A yes/no question. Resolves to false when dismissed.
Future<bool> confirm(
  BuildContext context, {
  required String title,
  String? message,
  required String action,
  bool destructive = false,
}) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title),
      content: message == null ? null : Text(message),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Cancel'),
        ),
        TextButton(
          style: destructive
              ? TextButton.styleFrom(
                  foregroundColor: Theme.of(context).colorScheme.error,
                )
              : null,
          onPressed: () => Navigator.pop(context, true),
          child: Text(action),
        ),
      ],
    ),
  );
  return result ?? false;
}

/// "Removed …" with an Undo button. Takes the messenger rather than a
/// context, so it can be grabbed before a sheet or page closes.
void showUndo(
  ScaffoldMessengerState messenger,
  String message,
  Future<void> Function() undo,
) {
  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Text(message),
        action: SnackBarAction(label: 'Undo', onPressed: undo),
      ),
    );
}

/// A calendar to jump straight to a day, up to [last] (usually today).
Future<DateTime?> pickDay(
  BuildContext context, {
  required DateTime initial,
  required DateTime last,
}) async {
  final picked = await showDatePicker(
    context: context,
    initialDate: initial.isAfter(last) ? last : initial,
    firstDate: DateTime(2000),
    lastDate: last,
  );
  return picked == null
      ? null
      : DateTime(picked.year, picked.month, picked.day);
}

/// The middle of a ‹ day › switcher: the label, tappable to pick a day.
class DayLabelButton extends StatelessWidget {
  const DayLabelButton({super.key, required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return TextButton(
      onPressed: onTap,
      style: TextButton.styleFrom(foregroundColor: theme.colorScheme.onSurface),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Flexible(
            child: Text(
              label,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.titleMedium,
            ),
          ),
          const SizedBox(width: 4),
          Icon(Icons.calendar_month_outlined, size: 18, color: theme.muted),
        ],
      ),
    );
  }
}
