// Ported from GitHub Desktop (MIT): app/src/lib/progress/{git,fetch,push,clone,checkout}.ts

/// One phase of a git operation and its share of the total.
class ProgressStep {
  const ProgressStep(this.title, this.weight);
  final String title;
  final double weight;
}

class ProgressLine {
  const ProgressLine({required this.title, required this.percent, this.value, this.total});
  final String title;
  final int percent;
  final int? value;
  final int? total;
}

final _progressLine = RegExp(r'^(.+?):\s+(\d{1,3})%(?:\s+\((\d+)/(\d+)\))?');

/// Parses a git `--progress` line like `Receiving objects:  45% (450/1000), 1.2 MiB`.
ProgressLine? parseProgressLine(String line) {
  final match = _progressLine.firstMatch(line.trim());
  if (match == null) return null;
  return ProgressLine(
    title: match.group(1)!,
    percent: int.parse(match.group(2)!).clamp(0, 100),
    value: match.group(3) == null ? null : int.parse(match.group(3)!),
    total: match.group(4) == null ? null : int.parse(match.group(4)!),
  );
}

/// Combines weighted steps into one overall 0..1 progress value.
class WeightedProgress {
  WeightedProgress(List<ProgressStep> steps) : _steps = _normalize(steps);

  final List<ProgressStep> _steps;
  var _stepIndex = 0;
  var _overall = 0.0;

  static List<ProgressStep> _normalize(List<ProgressStep> steps) {
    final total = steps.fold<double>(0, (sum, s) => sum + s.weight);
    return [for (final s in steps) ProgressStep(s.title, s.weight / total)];
  }

  static final fetch = [
    const ProgressStep('remote: Compressing objects', 0.1),
    const ProgressStep('Receiving objects', 0.7),
    const ProgressStep('Resolving deltas', 0.2),
  ];
  static final push = [
    const ProgressStep('Compressing objects', 0.2),
    const ProgressStep('Writing objects', 0.7),
    const ProgressStep('remote: Resolving deltas', 0.1),
  ];
  static final clone = [
    const ProgressStep('remote: Compressing objects', 0.1),
    const ProgressStep('Receiving objects', 0.6),
    const ProgressStep('Resolving deltas', 0.1),
    const ProgressStep('Checking out files', 0.2),
  ];

  /// Feeds a line; returns the new overall value and step title, or null.
  ({double value, String title})? feed(String line) {
    final parsed = parseProgressLine(line);
    if (parsed == null) return null;
    for (var i = _stepIndex; i < _steps.length; i++) {
      if (_steps[i].title != parsed.title) continue;
      _stepIndex = i;
      final before = _steps.take(i).fold<double>(0, (sum, s) => sum + s.weight);
      final fraction = parsed.total != null && parsed.total! > 0
          ? parsed.value! / parsed.total!
          : parsed.percent / 100;
      final next = before + _steps[i].weight * fraction.clamp(0, 1);
      if (next >= _overall) _overall = next;
      return (value: _overall, title: parsed.title);
    }
    return null;
  }
}
