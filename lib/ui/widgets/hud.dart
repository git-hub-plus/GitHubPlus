import 'package:flutter/material.dart';

import '../theme.dart';

/// How a value should read at a glance.
enum HudTone { neutral, good, attention, danger, accent }

extension HudToneColor on HudTone {
  Color color(GhpColors c) => switch (this) {
    HudTone.neutral => c.muted,
    HudTone.good => c.success,
    HudTone.attention => c.warning,
    HudTone.danger => c.danger,
    HudTone.accent => c.accent,
  };
}

/// An integer that counts smoothly to its new value (skipped when motion is reduced).
class AnimatedCount extends StatelessWidget {
  const AnimatedCount({super.key, required this.value, this.style});

  final int value;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(end: value.toDouble()),
      duration: context.motion(Motion.reward),
      curve: Motion.curve,
      builder: (context, v, _) => Text(
        v.round().toString(),
        style: (style ?? const TextStyle()).copyWith(fontFeatures: const [FontFeature.tabularFigures()]),
      ),
    );
  }
}

/// A slim gauge track with an animated fill.
class GaugeBar extends StatelessWidget {
  const GaugeBar({super.key, required this.fraction, required this.color, this.height = 6, this.glow = false});

  /// 0..1; values outside are clamped.
  final double fraction;
  final Color color;
  final double height;

  /// Soft glow on the fill, used when a goal is reached.
  final bool glow;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return ClipRRect(
      borderRadius: BorderRadius.circular(height),
      child: SizedBox(
        height: height,
        child: Stack(
          children: [
            Positioned.fill(child: ColoredBox(color: c.track)),
            TweenAnimationBuilder<double>(
              tween: Tween(end: fraction.clamp(0, 1)),
              duration: context.motion(Motion.reward),
              curve: Motion.curve,
              builder: (context, v, _) => FractionallySizedBox(
                widthFactor: v,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(colors: [color.withValues(alpha: 0.75), color]),
                    boxShadow: glow ? [BoxShadow(color: color.withValues(alpha: 0.6), blurRadius: 8)] : null,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// One HUD cell: icon, label, big number and an optional gauge toward [max].
class HudStat extends StatelessWidget {
  const HudStat({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
    this.max,
    this.tone = HudTone.neutral,
    this.tooltip,
    this.onTap,
  });

  final IconData icon;
  final String label;
  final int value;

  /// When set, a gauge shows value/max.
  final int? max;
  final HudTone tone;
  final String? tooltip;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final color = tone.color(c);
    final content = Container(
      padding: const EdgeInsets.symmetric(horizontal: Space.md, vertical: Space.sm + 2),
      decoration: BoxDecoration(
        color: c.surface.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(Radii.md),
        border: Border.all(color: tone == HudTone.neutral ? c.border : color.withValues(alpha: 0.55)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Icon(icon, size: 14, color: color),
              const SizedBox(width: Space.xs + 2),
              Expanded(
                child: Text(label, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 11.5, color: c.muted)),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              AnimatedCount(
                value: value,
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: value == 0 ? c.muted : c.text),
              ),
              if (max != null)
                Text(' / $max', style: TextStyle(fontSize: 12, color: c.muted, fontFeatures: const [FontFeature.tabularFigures()])),
            ],
          ),
          if (max != null) ...[
            const SizedBox(height: Space.xs + 2),
            GaugeBar(fraction: max == 0 ? 0 : value / max!, color: color),
          ],
        ],
      ),
    );
    final interactive = onTap == null
        ? content
        : MouseRegion(cursor: SystemMouseCursors.click, child: GestureDetector(onTap: onTap, child: content));
    return tooltip == null ? interactive : Tooltip(message: tooltip!, child: interactive);
  }
}

/// A donation-goal style bar: title, current/target and milestone ticks.
class GoalBar extends StatelessWidget {
  const GoalBar({
    super.key,
    required this.title,
    required this.current,
    required this.target,
    this.unit = '',
    this.tone = HudTone.accent,
    this.caption,
  });

  final String title;
  final int current;
  final int target;
  final String unit;
  final HudTone tone;

  /// Small text under the bar (e.g. "다음 목표까지 2").
  final String? caption;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final color = tone.color(c);
    final reached = target > 0 && current >= target;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(title, style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: c.text)),
            ),
            AnimatedCount(value: current, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: reached ? color : c.text)),
            Text(' / $target$unit', style: TextStyle(fontSize: 12.5, color: c.muted)),
            if (reached) ...[
              const SizedBox(width: Space.xs),
              Icon(Icons.emoji_events_rounded, size: 15, color: color),
            ],
          ],
        ),
        const SizedBox(height: Space.xs + 2),
        Stack(
          children: [
            GaugeBar(fraction: target == 0 ? 0 : current / target, color: color, height: 10, glow: reached),
            // Quarter milestones, like a donation goal's tick marks.
            Positioned.fill(
              child: Row(
                children: [
                  for (var i = 1; i <= 4; i++)
                    Expanded(
                      child: Align(
                        alignment: Alignment.centerRight,
                        child: i == 4 ? const SizedBox() : Container(width: 1.5, color: c.background.withValues(alpha: 0.7)),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
        if (caption != null) ...[
          const SizedBox(height: Space.xs),
          Text(caption!, style: TextStyle(fontSize: 11.5, color: c.muted)),
        ],
      ],
    );
  }
}
