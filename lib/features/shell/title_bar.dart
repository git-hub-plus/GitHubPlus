import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';

import '../../l10n/app_localizations.dart';
import '../../ui/theme.dart';

/// Launcher-style title bar: logo, drag area, trailing actions, window buttons.
class GhpTitleBar extends StatelessWidget {
  const GhpTitleBar({super.key, this.actions = const []});

  final List<Widget> actions;

  static const height = 40.0;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final l = L10n.of(context);
    return Container(
      height: height,
      decoration: BoxDecoration(
        color: c.surface,
        border: Border(bottom: BorderSide(color: c.border)),
      ),
      child: Row(
        children: [
          Expanded(
            child: DragToMoveArea(
              child: Row(
                children: [
                  const SizedBox(width: Space.md),
                  Image.asset('assets/brand/emblem.png', width: 22, height: 22, filterQuality: FilterQuality.medium),
                  const SizedBox(width: Space.sm),
                  Text.rich(
                    TextSpan(
                      children: [
                        TextSpan(text: 'GitHub', style: TextStyle(color: c.text)),
                        TextSpan(text: '+', style: TextStyle(color: c.accent)),
                      ],
                    ),
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, letterSpacing: 0.2),
                  ),
                  const Spacer(),
                ],
              ),
            ),
          ),
          ...actions,
          const SizedBox(width: Space.xs),
          _WindowButton(icon: Icons.remove_rounded, tooltip: l.windowMinimize, onPressed: windowManager.minimize),
          _WindowButton(
            icon: Icons.crop_square_rounded,
            tooltip: l.windowMaximize,
            onPressed: () async =>
                await windowManager.isMaximized() ? windowManager.unmaximize() : windowManager.maximize(),
          ),
          _WindowButton(icon: Icons.close_rounded, tooltip: l.windowClose, onPressed: windowManager.close, danger: true),
        ],
      ),
    );
  }
}

class _WindowButton extends StatefulWidget {
  const _WindowButton({required this.icon, required this.tooltip, required this.onPressed, this.danger = false});

  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;
  final bool danger;

  @override
  State<_WindowButton> createState() => _WindowButtonState();
}

class _WindowButtonState extends State<_WindowButton> {
  var _hover = false;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Semantics(
      button: true,
      label: widget.tooltip,
      child: MouseRegion(
        onEnter: (_) => setState(() => _hover = true),
        onExit: (_) => setState(() => _hover = false),
        child: GestureDetector(
          onTap: widget.onPressed,
          child: AnimatedContainer(
            duration: context.motion(Motion.fast),
            width: 46,
            height: GhpTitleBar.height,
            color: _hover ? (widget.danger ? c.danger : c.raised) : Colors.transparent,
            child: Icon(widget.icon, size: 16, color: _hover && widget.danger ? Colors.white : c.muted),
          ),
        ),
      ),
    );
  }
}
