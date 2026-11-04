// Ported from GitHub Desktop (MIT): app/src/models/manual-conflict-resolution.ts (via GitHub+ v1 src/main/git/conflicts.ts)
// Pure marker parsing is new in Flutter; v1 only provided whole-file side choices.
// CONTRACT (owner: worker A1). Signatures are fixed; A1 implements the bodies.
import '../models/advanced.dart';

/// Finds conflict blocks (marker size [markerSize], diff3 base sections
/// included). [text] is split on '\n'; a trailing '\r' stays part of each
/// line so line endings survive [applyConflictChoices].
List<ConflictRegion> parseConflictMarkers(String text, {int markerSize = 7}) {
  if (markerSize < 1) throw ArgumentError.value(markerSize, 'markerSize');
  final lines = text.split('\n');
  bool marker(String line, String char, {bool separator = false}) {
    final clean = line.endsWith('\r') ? line.substring(0, line.length - 1) : line;
    final prefix = char * markerSize;
    return clean == prefix || (!separator && clean.startsWith('$prefix '));
  }

  String? label(String line) {
    final value = line.substring(markerSize).trim();
    return value.isEmpty ? null : value;
  }

  final regions = <ConflictRegion>[];
  for (var start = 0; start < lines.length; start++) {
    if (!marker(lines[start], '<')) continue;
    int? base;
    int? divider;
    for (var end = start + 1; end < lines.length; end++) {
      if (marker(lines[end], '<')) break; // incomplete or nested block
      if (divider == null && base == null && marker(lines[end], '|')) {
        base = end;
      } else if (divider == null && marker(lines[end], '=', separator: true)) {
        divider = end;
      } else if (divider != null && marker(lines[end], '>')) {
        regions.add(
          ConflictRegion(
            index: regions.length,
            startLine: start,
            endLine: end,
            ours: lines.sublist(start + 1, base ?? divider),
            theirs: lines.sublist(divider + 1, end),
            base: base == null ? null : lines.sublist(base + 1, divider),
            oursLabel: label(lines[start]),
            theirsLabel: label(lines[end]),
          ),
        );
        start = end;
        break;
      }
    }
  }
  return regions;
}

/// Rewrites [text] taking, for each block index in [choices], its ours,
/// theirs, or both (ours then theirs) side. Blocks without a choice stay as
/// they are (markers included).
String applyConflictChoices(String text, Map<int, ConflictChoice> choices, {int markerSize = 7}) {
  final regions = parseConflictMarkers(text, markerSize: markerSize);
  final lines = text.split('\n');
  final lastOriginalLine = lines.length - 1;
  for (final region in regions.reversed) {
    final choice = choices[region.index];
    if (choice == null) continue;
    final replacement = switch (choice) {
      ConflictChoice.ours => region.ours,
      ConflictChoice.theirs => region.theirs,
      ConflictChoice.both => [...region.ours, ...region.theirs],
    };
    // The selected content's last CR belonged to the newline before the
    // closing marker. Do not leave a bare CR when that marker was at EOF.
    if (region.endLine == lastOriginalLine && replacement.isNotEmpty && replacement.last.endsWith('\r')) {
      replacement[replacement.length - 1] = replacement.last.substring(0, replacement.last.length - 1);
    }
    lines.replaceRange(region.startLine, region.endLine + 1, replacement);
  }
  return lines.join('\n');
}
