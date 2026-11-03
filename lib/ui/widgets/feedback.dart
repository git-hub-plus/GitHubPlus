import 'package:flutter/material.dart';

import '../theme.dart';

enum ToastTone { info, success, error }

/// Bottom-right notification. Errors stay until closed; others fade out.
void showGhpToast(BuildContext context, String message, {ToastTone tone = ToastTone.info, String? detail}) {
  final c = context.colors;
  final color = switch (tone) {
    ToastTone.info => c.accent,
    ToastTone.success => c.success,
    ToastTone.error => c.danger,
  };
  final icon = switch (tone) {
    ToastTone.info => Icons.info_outline_rounded,
    ToastTone.success => Icons.check_circle_rounded,
    ToastTone.error => Icons.error_outline_rounded,
  };
  final messenger = ScaffoldMessenger.maybeOf(context);
  if (messenger == null) return;
  messenger.showSnackBar(
    SnackBar(
      behavior: SnackBarBehavior.floating,
      width: 380,
      backgroundColor: c.raised,
      elevation: 6,
      duration: tone == ToastTone.error ? const Duration(days: 1) : const Duration(seconds: 4),
      showCloseIcon: true,
      closeIconColor: c.muted,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(Radii.md),
        side: BorderSide(color: color.withValues(alpha: 0.6)),
      ),
      content: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: Space.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(message, style: TextStyle(color: c.text, fontSize: 13)),
                if (detail != null && detail.isNotEmpty) ...[
                  const SizedBox(height: Space.xs),
                  SelectableText(
                    detail,
                    maxLines: 6,
                    style: TextStyle(color: c.muted, fontSize: 11.5, fontFamily: 'Consolas'),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    ),
  );
}
