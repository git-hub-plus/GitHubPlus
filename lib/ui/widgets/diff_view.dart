import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/models/diff.dart';
import '../../l10n/app_localizations.dart';
import '../format.dart';
import '../theme.dart';

const _mono = 'Consolas';

/// Any [FileDiff]: text (optionally with line selection), image, or a short
/// explanation for binary, large, submodule and unrenderable diffs.
class FileDiffView extends StatefulWidget {
  const FileDiffView({super.key, required this.diff, this.selection, this.onSelectionChanged});

  final FileDiff diff;

  /// Line selection for the next commit; null shows a read-only diff.
  final DiffSelection? selection;
  final ValueChanged<DiffSelection>? onSelectionChanged;

  @override
  State<FileDiffView> createState() => _FileDiffViewState();
}

class _FileDiffViewState extends State<FileDiffView> {
  var _showLarge = false;

  @override
  void didUpdateWidget(FileDiffView old) {
    super.didUpdateWidget(old);
    if (!identical(old.diff, widget.diff)) _showLarge = false;
  }

  @override
  Widget build(BuildContext context) {
    final l = L10n.of(context);
    return switch (widget.diff) {
      TextDiff diff when diff.hunks.isEmpty => _DiffMessage(l.diffNoChanges, icon: Icons.check_rounded),
      TextDiff diff => DiffView(diff: diff, selection: widget.selection, onSelectionChanged: widget.onSelectionChanged),
      LargeDiff(:final diff) when _showLarge =>
        DiffView(diff: diff, selection: widget.selection, onSelectionChanged: widget.onSelectionChanged),
      LargeDiff(:final size) => _DiffMessage(
        l.diffLarge(formatBytes(size)),
        icon: Icons.unfold_more_rounded,
        action: TextButton(onPressed: () => setState(() => _showLarge = true), child: Text(l.diffShowAnyway)),
      ),
      BinaryDiff() => _DiffMessage(l.diffBinary, icon: Icons.memory_rounded),
      ImageDiff(:final previous, :final current) => _ImageDiffView(previous: previous, current: current),
      SubmoduleDiff(:final oldSha, :final newSha) => _DiffMessage(
        l.diffSubmodule(_short(oldSha), _short(newSha)),
        icon: Icons.widgets_outlined,
      ),
      UnrenderableDiff() => _DiffMessage(l.diffUnrenderable, icon: Icons.visibility_off_outlined),
    };
  }

  static String _short(String? sha) => sha == null ? '-' : (sha.length > 7 ? sha.substring(0, 7) : sha);
}

class _DiffMessage extends StatelessWidget {
  const _DiffMessage(this.text, {required this.icon, this.action});
  final String text;
  final IconData icon;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(Space.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 32, color: c.muted),
            const SizedBox(height: Space.md),
            Text(text, textAlign: TextAlign.center, style: TextStyle(color: c.muted)),
            if (action != null) ...[const SizedBox(height: Space.sm), action!],
          ],
        ),
      ),
    );
  }
}

/// Unified text diff with line numbers. When [onSelectionChanged] is given,
/// the selection gutter is clickable: click toggles a line, Shift+click
/// selects a range from the last clicked line, clicking a hunk header
/// toggles the whole hunk. Lines build lazily.
class DiffView extends StatefulWidget {
  const DiffView({super.key, required this.diff, this.selection, this.onSelectionChanged});

  final TextDiff diff;
  final DiffSelection? selection;
  final ValueChanged<DiffSelection>? onSelectionChanged;

  @override
  State<DiffView> createState() => _DiffViewState();
}

class _DiffViewState extends State<DiffView> {
  int? _anchor;

  late List<DiffLine> _rows;

  @override
  void initState() {
    super.initState();
    _rows = _flatten(widget.diff);
  }

  @override
  void didUpdateWidget(DiffView old) {
    super.didUpdateWidget(old);
    if (!identical(old.diff, widget.diff)) {
      _rows = _flatten(widget.diff);
      _anchor = null;
    }
  }

  static List<DiffLine> _flatten(TextDiff diff) => [for (final hunk in diff.hunks) ...hunk.lines];

  bool get _selectable => widget.selection != null && widget.onSelectionChanged != null;

  void _toggleLine(DiffLine line) {
    final selection = widget.selection!;
    final shift = HardwareKeyboard.instance.isShiftPressed;
    final anchor = _anchor;
    if (shift && anchor != null) {
      final from = anchor < line.originalLineNumber ? anchor : line.originalLineNumber;
      final to = anchor < line.originalLineNumber ? line.originalLineNumber : anchor;
      widget.onSelectionChanged!(selection.withRangeSelection(from, to - from + 1, selection.isSelected(anchor)));
      return;
    }
    _anchor = line.originalLineNumber;
    widget.onSelectionChanged!(selection.withToggledLine(line.originalLineNumber));
  }

  void _toggleHunk(DiffLine header) {
    final selection = widget.selection!;
    final hunk = widget.diff.hunks.firstWhere((h) => identical(h.lines.first, header));
    final changes = hunk.lines.where((l) => l.isChange).map((l) => l.originalLineNumber).toList();
    if (changes.isEmpty) return;
    final allSelected = changes.every(selection.isSelected);
    var next = selection;
    for (final line in changes) {
      next = next.withLineSelection(line, !allSelected);
    }
    widget.onSelectionChanged!(next);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final l = L10n.of(context);
    final digits = '${widget.diff.maxLineNumber}'.length.clamp(3, 7);
    final change = widget.diff.lineEndingsChange;
    final notes = [
      if (widget.diff.hasHiddenBidiChars) _Note(l.diffBidiWarning, color: c.warning, icon: Icons.warning_amber_rounded),
      if (change != null)
        _Note(l.diffLineEndings(change.from.name.toUpperCase(), change.to.name.toUpperCase()), color: c.muted),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ...notes,
        Expanded(
          child: SelectionArea(
            child: ListView.builder(
              itemCount: _rows.length,
              itemBuilder: (_, i) => _DiffRow(
                line: _rows[i],
                digits: digits,
                selection: widget.selection,
                onToggle: _selectable ? _toggle : null,
              ),
            ),
          ),
        ),
      ],
    );
  }

  void _toggle(DiffLine line) => line.type == DiffLineType.hunk ? _toggleHunk(line) : _toggleLine(line);
}

class _Note extends StatelessWidget {
  const _Note(this.text, {required this.color, this.icon = Icons.info_outline_rounded});
  final String text;
  final Color color;
  final IconData icon;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: Space.md, vertical: Space.xs + 2),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.12),
      border: Border(bottom: BorderSide(color: context.colors.border)),
    ),
    child: Row(
      children: [
        Icon(icon, size: 15, color: color),
        const SizedBox(width: Space.sm),
        Expanded(child: Text(text, style: TextStyle(fontSize: 12, color: color))),
      ],
    ),
  );
}

class _DiffRow extends StatelessWidget {
  const _DiffRow({required this.line, required this.digits, required this.selection, required this.onToggle});

  final DiffLine line;
  final int digits;
  final DiffSelection? selection;
  final ValueChanged<DiffLine>? onToggle;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final numberWidth = digits * 7.5 + Space.sm;
    final style = TextStyle(fontFamily: _mono, fontSize: 12.5, height: 1.45, color: c.text);
    final background = switch (line.type) {
      DiffLineType.add => c.diffAdd,
      DiffLineType.delete => c.diffDelete,
      DiffLineType.hunk => c.raised,
      DiffLineType.context => Colors.transparent,
    };
    final numbers = SelectionContainer.disabled(
      child: Row(
        children: [
          _Number(line.oldLineNumber, width: numberWidth, style: style.copyWith(color: c.muted)),
          _Number(line.newLineNumber, width: numberWidth, style: style.copyWith(color: c.muted)),
        ],
      ),
    );
    final text = line.type == DiffLineType.hunk ? line.text : line.text.replaceAll('\r', '');
    return Container(
      color: background,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SelectionGutter(line: line, selection: selection, onToggle: onToggle),
          numbers,
          const SizedBox(width: Space.sm),
          Expanded(
            child: Text(
              text,
              style: line.type == DiffLineType.hunk ? style.copyWith(color: c.muted) : style,
            ),
          ),
        ],
      ),
    );
  }
}

class _Number extends StatelessWidget {
  const _Number(this.value, {required this.width, required this.style});
  final int? value;
  final double width;
  final TextStyle style;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: width,
    child: Text(value?.toString() ?? '', textAlign: TextAlign.right, style: style),
  );
}

/// The clickable strip that shows whether a line goes into the commit.
class _SelectionGutter extends StatelessWidget {
  const _SelectionGutter({required this.line, required this.selection, required this.onToggle});
  final DiffLine line;
  final DiffSelection? selection;
  final ValueChanged<DiffLine>? onToggle;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final selection = this.selection;
    final canToggle = onToggle != null && (line.isChange || line.type == DiffLineType.hunk);
    final selected = selection != null && line.isChange && selection.isSelected(line.originalLineNumber);
    final strip = SelectionContainer.disabled(
      child: Container(
        width: 14,
        height: 18,
        margin: const EdgeInsets.only(right: 2),
        color: selected ? c.accent : (line.isChange && selection != null ? c.track : Colors.transparent),
      ),
    );
    if (!canToggle) return strip;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(onTap: () => onToggle!(line), child: strip),
    );
  }
}

class _ImageDiffView extends StatelessWidget {
  const _ImageDiffView({this.previous, this.current});
  final DiffImage? previous;
  final DiffImage? current;

  @override
  Widget build(BuildContext context) {
    final l = L10n.of(context);
    return Padding(
      padding: const EdgeInsets.all(Space.lg),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: _ImagePane(title: l.diffImageBefore, image: previous, tone: context.colors.danger)),
          const SizedBox(width: Space.lg),
          Expanded(child: _ImagePane(title: l.diffImageAfter, image: current, tone: context.colors.success)),
        ],
      ),
    );
  }
}

class _ImagePane extends StatelessWidget {
  const _ImagePane({required this.title, required this.image, required this.tone});
  final String title;
  final DiffImage? image;
  final Color tone;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final image = this.image;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          image == null ? title : '$title · ${formatBytes(image.bytes.length)}',
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: tone),
        ),
        const SizedBox(height: Space.sm),
        Container(
          decoration: BoxDecoration(
            border: Border.all(color: tone.withValues(alpha: 0.6)),
            borderRadius: BorderRadius.circular(Radii.sm),
          ),
          padding: const EdgeInsets.all(Space.sm),
          constraints: const BoxConstraints(minHeight: 120),
          alignment: Alignment.center,
          child: image == null
              ? Icon(Icons.remove_rounded, color: c.muted)
              : Image.memory(
                  image.bytes,
                  cacheWidth: 1600,
                  fit: BoxFit.contain,
                  errorBuilder: (_, _, _) => Icon(Icons.broken_image_outlined, color: c.muted),
                ),
        ),
      ],
    );
  }
}
