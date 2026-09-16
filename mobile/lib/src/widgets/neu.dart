import 'package:flutter/material.dart';

import '../theme.dart';

/// The one primitive every surface is built from: flat fill, thick border,
/// hard offset shadow, no blur and no gradient.
///
/// When [onTap] is set the box presses into its own shadow — the shadow
/// shrinks to zero while the box translates by the same distance, so the
/// outer silhouette stays put and the whole thing reads as a physical key.
class NeuBox extends StatefulWidget {
  const NeuBox({
    super.key,
    required this.child,
    this.color,
    this.padding = const EdgeInsets.all(16),
    this.onTap,
    this.shadow = true,
    this.radius,
    this.borderWidth,
    this.width,
    this.height,
    this.alignment,
  });

  final Widget child;
  final Color? color;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  final bool shadow;
  final double? radius;
  final double? borderWidth;
  final double? width;
  final double? height;
  final AlignmentGeometry? alignment;

  @override
  State<NeuBox> createState() => _NeuBoxState();
}

class _NeuBoxState extends State<NeuBox> {
  bool _pressed = false;
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final NeuTokens neu = context.neu;
    final bool interactive = widget.onTap != null;
    final double base = widget.shadow ? neu.shadowOffset : 0;
    // Hover lifts, press sinks. Both only move the shadow, never the layout.
    final double offset = !widget.shadow
        ? 0
        : _pressed
            ? 0
            : _hovered
                ? base + 2
                : base;

    final Widget box = AnimatedContainer(
      duration: const Duration(milliseconds: 120),
      curve: Curves.easeOut,
      width: widget.width,
      height: widget.height,
      alignment: widget.alignment,
      transform: Matrix4.translationValues(base - offset, base - offset, 0),
      padding: widget.padding,
      decoration: BoxDecoration(
        color: widget.color ?? Theme.of(context).colorScheme.surface,
        border: Border.all(
          color: neu.line,
          width: widget.borderWidth ?? neu.borderWidth,
        ),
        borderRadius: BorderRadius.circular(widget.radius ?? neu.radius),
        boxShadow: offset == 0 ? null : neu.shadowAt(offset),
      ),
      child: widget.child,
    );

    if (!interactive) {
      return box;
    }

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (_) => setState(() => _pressed = true),
        onTapUp: (_) => setState(() => _pressed = false),
        onTapCancel: () => setState(() => _pressed = false),
        onTap: widget.onTap,
        child: box,
      ),
    );
  }
}

/// Filled action button. [color] defaults to the yellow primary.
class NeuButton extends StatelessWidget {
  const NeuButton({
    super.key,
    required this.label,
    this.icon,
    this.onPressed,
    this.color,
    this.expanded = true,
    this.busy = false,
  });

  final String label;
  final IconData? icon;
  final VoidCallback? onPressed;
  final Color? color;
  final bool expanded;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final NeuTokens neu = context.neu;
    final bool enabled = onPressed != null && !busy;
    final Color fill = color ?? neu.yellow;

    final Widget content = Row(
      mainAxisSize: expanded ? MainAxisSize.max : MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: <Widget>[
        if (busy)
          SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(
              strokeWidth: 3,
              color: neu.onAccent,
            ),
          )
        else if (icon != null)
          Icon(icon, size: 20, color: neu.onAccent),
        if (busy || icon != null) const SizedBox(width: 10),
        Flexible(
          child: Text(
            label,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: neu.onAccent,
              fontWeight: FontWeight.w900,
              fontSize: 15,
              letterSpacing: 0.2,
            ),
          ),
        ),
      ],
    );

    return Opacity(
      opacity: enabled ? 1 : 0.45,
      child: NeuBox(
        color: fill,
        onTap: enabled ? onPressed : null,
        shadow: enabled,
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        child: content,
      ),
    );
  }
}

/// Square icon-only button, used where a label would not fit.
class NeuIconButton extends StatelessWidget {
  const NeuIconButton({
    super.key,
    required this.icon,
    this.onPressed,
    this.color,
    this.tooltip,
    this.size = 44,
  });

  final IconData icon;
  final VoidCallback? onPressed;
  final Color? color;
  final String? tooltip;
  final double size;

  @override
  Widget build(BuildContext context) {
    final NeuTokens neu = context.neu;
    final bool enabled = onPressed != null;

    final Widget button = Opacity(
      opacity: enabled ? 1 : 0.4,
      child: NeuBox(
        color: color ?? Theme.of(context).colorScheme.surfaceContainerHighest,
        onTap: onPressed,
        shadow: enabled,
        width: size,
        height: size,
        padding: EdgeInsets.zero,
        alignment: Alignment.center,
        child: Icon(icon, size: 20, color: neu.line),
      ),
    );

    return tooltip == null ? button : Tooltip(message: tooltip!, child: button);
  }
}

/// Small bordered label. [selected] fills it with an accent.
class NeuChip extends StatelessWidget {
  const NeuChip({
    super.key,
    required this.label,
    this.icon,
    this.color,
    this.selected = false,
    this.onTap,
    this.dense = false,
  });

  final String label;
  final IconData? icon;
  final Color? color;
  final bool selected;
  final VoidCallback? onTap;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final NeuTokens neu = context.neu;
    final Color fill = selected
        ? (color ?? neu.yellow)
        : Theme.of(context).colorScheme.surfaceContainerHighest;
    final Color ink = selected ? neu.onAccent : neu.line;

    return NeuBox(
      color: fill,
      onTap: onTap,
      shadow: selected || onTap != null,
      radius: 999,
      borderWidth: 2,
      padding: EdgeInsets.symmetric(
        horizontal: dense ? 10 : 12,
        vertical: dense ? 4 : 7,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          if (icon != null) ...<Widget>[
            Icon(icon, size: 14, color: ink),
            const SizedBox(width: 6),
          ],
          Text(
            label,
            style: TextStyle(
              color: ink,
              fontWeight: FontWeight.w800,
              fontSize: dense ? 11 : 12.5,
            ),
          ),
        ],
      ),
    );
  }
}

/// Section heading: an accent-filled icon tile next to an all-caps title.
class NeuHeading extends StatelessWidget {
  const NeuHeading({
    super.key,
    required this.icon,
    required this.title,
    this.color,
  });

  final IconData icon;
  final String title;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final NeuTokens neu = context.neu;
    return Row(
      children: <Widget>[
        NeuBox(
          color: color ?? neu.yellow,
          shadow: false,
          radius: 6,
          borderWidth: 2,
          padding: const EdgeInsets.all(5),
          child: Icon(icon, size: 15, color: neu.onAccent),
        ),
        const SizedBox(width: 9),
        Expanded(
          child: Text(
            title.toUpperCase(),
            style: TextStyle(
              color: neu.line,
              fontWeight: FontWeight.w900,
              fontSize: 12.5,
              letterSpacing: 0.9,
            ),
          ),
        ),
      ],
    );
  }
}

/// Heading plus a paragraph — the shape every card-meaning section uses.
class NeuSection extends StatelessWidget {
  const NeuSection({
    super.key,
    required this.icon,
    required this.title,
    required this.body,
    this.color,
  });

  final IconData icon;
  final String title;
  final String body;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          NeuHeading(icon: icon, title: title, color: color),
          const SizedBox(height: 9),
          Text(body, style: Theme.of(context).textTheme.bodyMedium),
        ],
      ),
    );
  }
}

/// Text field wrapped in the same border-and-shadow treatment as everything
/// else, because Material's underline and filled variants both fight the style.
class NeuField extends StatelessWidget {
  const NeuField({
    super.key,
    required this.controller,
    this.hintText,
    this.labelText,
    this.minLines,
    this.maxLines = 1,
    this.obscureText = false,
    this.suffix,
    this.onSubmitted,
    this.onChanged,
    this.prefixIcon,
  });

  final TextEditingController controller;
  final String? hintText;
  final String? labelText;
  final int? minLines;
  final int? maxLines;
  final bool obscureText;
  final Widget? suffix;
  final ValueChanged<String>? onSubmitted;
  final ValueChanged<String>? onChanged;
  final IconData? prefixIcon;

  @override
  Widget build(BuildContext context) {
    final NeuTokens neu = context.neu;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        if (labelText != null) ...<Widget>[
          Text(
            labelText!.toUpperCase(),
            style: TextStyle(
              color: neu.line,
              fontWeight: FontWeight.w900,
              fontSize: 11,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 6),
        ],
        NeuBox(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: <Widget>[
              if (prefixIcon != null) ...<Widget>[
                Icon(prefixIcon, size: 18, color: neu.line),
                const SizedBox(width: 8),
              ],
              Expanded(
                child: TextField(
                  controller: controller,
                  minLines: minLines,
                  maxLines: maxLines,
                  obscureText: obscureText,
                  autocorrect: !obscureText,
                  enableSuggestions: !obscureText,
                  onSubmitted: onSubmitted,
                  onChanged: onChanged,
                  cursorColor: neu.line,
                  style: TextStyle(
                    color: neu.line,
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
                  ),
                  decoration: InputDecoration(
                    hintText: hintText,
                    hintStyle: TextStyle(
                      color: neu.line.withValues(alpha: 0.45),
                      fontWeight: FontWeight.w600,
                    ),
                    isDense: true,
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
              if (suffix != null) suffix!,
            ],
          ),
        ),
      ],
    );
  }
}
