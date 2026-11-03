import 'package:flutter/widgets.dart';

bool _isKorean(BuildContext context) => Localizations.localeOf(context).languageCode == 'ko';

/// Compact duration: "1분 12초" / "1m 12s".
String formatDuration(BuildContext context, Duration duration) {
  final ko = _isKorean(context);
  final h = duration.inHours, m = duration.inMinutes % 60, s = duration.inSeconds % 60;
  if (h > 0) return ko ? '$h시간 $m분' : '${h}h ${m}m';
  if (m > 0) return ko ? '$m분 $s초' : '${m}m ${s}s';
  return ko ? '$s초' : '${s}s';
}

/// Relative time: "방금 전", "3분 전" / "just now", "3m ago".
String formatAgo(BuildContext context, DateTime time, {DateTime? now}) {
  final ko = _isKorean(context);
  final diff = (now ?? DateTime.now()).difference(time);
  if (diff.inSeconds < 45) return ko ? '방금 전' : 'just now';
  if (diff.inMinutes < 60) return ko ? '${diff.inMinutes}분 전' : '${diff.inMinutes}m ago';
  if (diff.inHours < 24) return ko ? '${diff.inHours}시간 전' : '${diff.inHours}h ago';
  return ko ? '${diff.inDays}일 전' : '${diff.inDays}d ago';
}

/// File size: "512 B", "12.4 KB", "3.1 MB".
String formatBytes(int bytes) {
  if (bytes < 1024) return '$bytes B';
  if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
  return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
}
