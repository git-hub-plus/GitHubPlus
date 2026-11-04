// Diff shapes adapted from GitHub Desktop (MIT): app/src/models/diff/*
// (via GitHub+ v1 src/shared/models/diff.ts and diff-selection.ts).
import 'dart:typed_data';

import 'status.dart';

enum DiffLineType { context, add, delete, hunk }

class DiffLine {
  const DiffLine({
    required this.text,
    required this.type,
    required this.originalLineNumber,
    this.oldLineNumber,
    this.newLineNumber,
    this.noTrailingNewLine = false,
  });

  /// The raw line including its leading '+', '-', ' ' or '@@ ... @@'.
  final String text;
  final DiffLineType type;

  /// Index of the line in the unified diff body; line selection uses this.
  final int originalLineNumber;
  final int? oldLineNumber;
  final int? newLineNumber;
  final bool noTrailingNewLine;

  /// The line without its one-character prefix (hunk headers stay as is).
  String get content => type == DiffLineType.hunk || text.isEmpty ? text : text.substring(1);

  bool get isChange => type == DiffLineType.add || type == DiffLineType.delete;
}

class DiffHunkHeader {
  const DiffHunkHeader({
    required this.oldStartLine,
    required this.oldLineCount,
    required this.newStartLine,
    required this.newLineCount,
  });

  final int oldStartLine;
  final int oldLineCount;
  final int newStartLine;
  final int newLineCount;
}

class DiffHunk {
  const DiffHunk({
    required this.header,
    required this.lines,
    required this.unifiedDiffStart,
    required this.unifiedDiffEnd,
  });

  final DiffHunkHeader header;

  /// Includes the hunk header line as the first element.
  final List<DiffLine> lines;
  final int unifiedDiffStart;
  final int unifiedDiffEnd;
}

enum LineEnding { cr, lf, crlf }

sealed class FileDiff {
  const FileDiff();
}

class TextDiff extends FileDiff {
  const TextDiff({
    required this.text,
    required this.hunks,
    required this.maxLineNumber,
    this.lineEndingsChange,
    this.hasHiddenBidiChars = false,
  });

  /// Unified diff body (everything after the file header).
  final String text;
  final List<DiffHunk> hunks;
  final int maxLineNumber;
  final ({LineEnding from, LineEnding to})? lineEndingsChange;

  /// Unicode bidi control characters that can hide code (Trojan Source).
  final bool hasHiddenBidiChars;

  /// `originalLineNumber`s of added/deleted lines: what can be selected.
  List<int> get selectableLines => [
    for (final hunk in hunks)
      for (final line in hunk.lines)
        if (line.isChange) line.originalLineNumber,
  ];
}

/// Too big to show by default (still committable as a whole file).
class LargeDiff extends FileDiff {
  const LargeDiff({required this.diff, required this.size});
  final TextDiff diff;
  final int size;
}

class BinaryDiff extends FileDiff {
  const BinaryDiff();
}

class DiffImage {
  const DiffImage({required this.bytes, required this.mediaType});
  final Uint8List bytes;
  final String mediaType;
}

class ImageDiff extends FileDiff {
  const ImageDiff({this.previous, this.current});
  final DiffImage? previous;
  final DiffImage? current;
}

class SubmoduleDiff extends FileDiff {
  const SubmoduleDiff({required this.path, this.url, this.status, this.oldSha, this.newSha});
  final String path;
  final String? url;
  final SubmoduleStatus? status;
  final String? oldSha;
  final String? newSha;
}

class UnrenderableDiff extends FileDiff {
  const UnrenderableDiff();
}

enum SelectionType { all, partial, none }

/// Which lines of a working file go into the next commit.
///
/// Port of GitHub Desktop's immutable `DiffSelection`: every selectable line
/// follows [defaultSelectionType] except the ones in [divergingLines].
/// Line numbers are [DiffLine.originalLineNumber].
class DiffSelection {
  const DiffSelection._(this.defaultSelectionType, this.divergingLines, this.selectableLines);

  factory DiffSelection.all([List<int>? selectableLines]) =>
      DiffSelection._(SelectionType.all, const {}, selectableLines?.toSet());

  factory DiffSelection.none([List<int>? selectableLines]) =>
      DiffSelection._(SelectionType.none, const {}, selectableLines?.toSet());

  /// [SelectionType.all] or [SelectionType.none].
  final SelectionType defaultSelectionType;
  final Set<int> divergingLines;

  /// When known (after the diff loaded), only these lines can be selected.
  final Set<int>? selectableLines;

  /// Overall state, for the file's checkbox.
  SelectionType get selectionType {
    if (divergingLines.isEmpty) return defaultSelectionType;
    final selectable = selectableLines;
    if (selectable != null && selectable.length == divergingLines.length && selectable.containsAll(divergingLines)) {
      return defaultSelectionType == SelectionType.all ? SelectionType.none : SelectionType.all;
    }
    return SelectionType.partial;
  }

  bool isSelected(int line) {
    final diverging = divergingLines.contains(line);
    return defaultSelectionType == SelectionType.all ? !diverging : diverging;
  }

  bool isSelectable(int line) => selectableLines?.contains(line) ?? true;

  /// Same selection, now aware of the diff's selectable lines.
  DiffSelection withSelectableLines(List<int> lines) =>
      DiffSelection._(defaultSelectionType, divergingLines.intersection(lines.toSet()), lines.toSet());

  DiffSelection withLineSelection(int line, bool selected) => withRangeSelection(line, 1, selected);

  /// Selects or deselects [length] lines starting at [from] (non-selectable lines are skipped).
  DiffSelection withRangeSelection(int from, int length, bool selected) {
    final diverging = {...divergingLines};
    final wantDiverging = defaultSelectionType == SelectionType.all ? !selected : selected;
    for (var line = from; line < from + length; line++) {
      if (!isSelectable(line)) continue;
      wantDiverging ? diverging.add(line) : diverging.remove(line);
    }
    return _normalized(diverging);
  }

  DiffSelection withToggledLine(int line) => withLineSelection(line, !isSelected(line));

  DiffSelection withSelectAll() => DiffSelection.all(selectableLines?.toList());
  DiffSelection withSelectNone() => DiffSelection.none(selectableLines?.toList());

  /// Collapses "everything diverges" into the opposite default.
  DiffSelection _normalized(Set<int> diverging) {
    final next = DiffSelection._(defaultSelectionType, diverging, selectableLines);
    return switch (next.selectionType) {
      SelectionType.all => withSelectAll(),
      SelectionType.none => withSelectNone(),
      SelectionType.partial => next,
    };
  }
}
