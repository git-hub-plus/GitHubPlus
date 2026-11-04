import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;

import '../../core/content/repo_content.dart';
import '../../core/models/app_models.dart';
import '../../l10n/app_localizations.dart';
import '../../l10n/terms.dart';
import '../../state/content_state.dart';
import '../../ui/format.dart';
import '../../ui/theme.dart';
import 'markdown_view.dart';

/// Overview tab of a local repository: [ContentBrowser] over the working
/// folder or HEAD.
class OverviewView extends ConsumerStatefulWidget {
  const OverviewView({super.key, required this.repo});
  final RepositoryInfo repo;

  @override
  ConsumerState<OverviewView> createState() => _OverviewViewState();
}

class _OverviewViewState extends ConsumerState<OverviewView> {
  var _view = ContentView.workingTree;

  ContentKey get _key => (repoId: widget.repo.id, view: _view);

  @override
  Widget build(BuildContext context) {
    final l = L10n.of(context);
    final t = Terms.of(context);
    return ContentBrowser(
      source: ref.watch(contentSourceProvider(_key)),
      rootLabel: widget.repo.name,
      localRoot: _view == ContentView.workingTree ? widget.repo.path : null,
      errorHint: _view == ContentView.head ? l.overviewNoCommits(t.commitUnit) : null,
      onRefresh: () => ref.invalidate(contentSourceProvider(_key)),
      leading: SegmentedButton<ContentView>(
        showSelectedIcon: false,
        segments: [
          ButtonSegment(
            value: ContentView.workingTree,
            tooltip: l.overviewWorkingTreeTip(t.commit),
            label: Text(l.overviewWorkingTree),
          ),
          ButtonSegment(
            value: ContentView.head,
            tooltip: l.overviewHeadTip(t.branch),
            label: Text(l.overviewHead(t.commitUnit)),
          ),
        ],
        selected: {_view},
        onSelectionChanged: (v) => setState(() => _view = v.first),
      ),
    );
  }
}

/// GitHub-style repository page: breadcrumbs, file list, README and a file
/// viewer over any [RepoContentSource] (working folder, a commit, or a hub
/// repository through its HTTP API).
class ContentBrowser extends ConsumerStatefulWidget {
  const ContentBrowser({
    super.key,
    required this.source,
    required this.rootLabel,
    this.leading,
    this.onRefresh,
    this.localRoot,
    this.errorHint,
  });

  /// Null while the source is unavailable (nothing is shown).
  final RepoContentSource? source;
  final String rootLabel;

  /// Shown before the breadcrumbs (e.g. a view switch).
  final Widget? leading;
  final VoidCallback? onRefresh;

  /// Folder on disk for "Open in Explorer"; null hides the button.
  final String? localRoot;

  /// Replaces the raw error when listing fails (e.g. "no commits yet").
  final String? errorHint;

  @override
  ConsumerState<ContentBrowser> createState() => _ContentBrowserState();
}

class _ContentBrowserState extends ConsumerState<ContentBrowser> {
  var _dir = '';
  String? _file;

  void _openDir(String dir) => setState(() {
    _dir = dir;
    _file = null;
  });

  void _openFile(String path) => setState(() {
    _dir = p.posix.dirname(path) == '.' ? '' : p.posix.dirname(path);
    _file = path;
  });

  /// Follows a repository link from a README: folder or file.
  Future<void> _navigate(String path) async {
    final parent = p.posix.dirname(path) == '.' ? '' : p.posix.dirname(path);
    final entries = await widget.source?.list(parent) ?? const <TreeEntry>[];
    final entry = entries.where((e) => e.path == path).firstOrNull;
    if (!mounted) return;
    if (path.isEmpty || entry?.isDirectory == true) {
      _openDir(path);
    } else {
      _openFile(path);
    }
  }

  Future<void> _openInExplorer() async {
    final root = widget.localRoot;
    if (root == null) return;
    final dir = Directory(p.join(root, p.joinAll(p.posix.split(_dir))));
    if (!dir.existsSync()) return;
    // Absolute path: a bare 'explorer.exe' is also searched for in the current directory.
    final windows = Platform.environment['SystemRoot'] ?? r'C:\Windows';
    await Process.run(p.join(windows, 'explorer.exe'), [dir.path]);
  }

  void _openEntry(TreeEntry entry) {
    if (entry.isDirectory) {
      _openDir(entry.path);
    } else if (entry.kind != EntryKind.submodule) {
      _openFile(entry.path);
    }
  }

  @override
  Widget build(BuildContext context) {
    final file = _file;
    final source = widget.source;
    final Widget body;
    if (source == null) {
      body = const SizedBox.shrink();
    } else if (file == null) {
      body = _FolderPage(
        source: source,
        dir: _dir,
        errorHint: widget.errorHint,
        onOpen: _openEntry,
        onNavigate: _navigate,
      );
    } else {
      body = _FilePage(key: ValueKey(file), source: source, path: file, onNavigate: _navigate);
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Toolbar(
          rootLabel: widget.rootLabel,
          leading: widget.leading,
          dir: _dir,
          file: file,
          onDir: _openDir,
          onRefresh: widget.onRefresh,
          onOpenFolder: widget.localRoot == null ? null : _openInExplorer,
        ),
        Expanded(child: body),
      ],
    );
  }
}

class _Toolbar extends StatelessWidget {
  const _Toolbar({
    required this.rootLabel,
    required this.leading,
    required this.dir,
    required this.file,
    required this.onDir,
    required this.onRefresh,
    required this.onOpenFolder,
  });

  final String rootLabel;
  final Widget? leading;
  final String dir;
  final String? file;
  final ValueChanged<String> onDir;
  final VoidCallback? onRefresh;
  final VoidCallback? onOpenFolder;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final l = L10n.of(context);
    final segments = dir.isEmpty ? const <String>[] : dir.split('/');
    final crumbs = <Widget>[
      _Crumb(label: rootLabel, onTap: () => onDir(''), strong: true),
      for (var i = 0; i < segments.length; i++) ...[
        Text(' / ', style: TextStyle(color: c.muted)),
        _Crumb(label: segments[i], onTap: () => onDir(segments.take(i + 1).join('/'))),
      ],
      if (file != null) ...[
        Text(' / ', style: TextStyle(color: c.muted)),
        Text(
          p.posix.basename(file!),
          style: TextStyle(fontWeight: FontWeight.w700, color: c.text),
        ),
      ],
    ];
    return Padding(
      padding: const EdgeInsets.fromLTRB(Space.xl, Space.md, Space.xl, Space.sm),
      child: Row(
        children: [
          if (leading != null) ...[leading!, const SizedBox(width: Space.lg)],
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(children: crumbs),
            ),
          ),
          if (onOpenFolder != null)
            IconButton(
              tooltip: l.overviewOpenFolder,
              onPressed: onOpenFolder,
              icon: Icon(Icons.folder_open_rounded, size: 18, color: c.muted),
            ),
          if (onRefresh != null)
            IconButton(
              tooltip: l.overviewRefresh,
              onPressed: onRefresh,
              icon: Icon(Icons.refresh_rounded, size: 18, color: c.muted),
            ),
        ],
      ),
    );
  }
}

class _Crumb extends StatelessWidget {
  const _Crumb({required this.label, required this.onTap, this.strong = false});
  final String label;
  final VoidCallback onTap;
  final bool strong;

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(Radii.sm),
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      child: Text(
        label,
        style: TextStyle(color: context.colors.accent, fontWeight: strong ? FontWeight.w700 : FontWeight.w500),
      ),
    ),
  );
}

/// Shared card frame for the listing, README and file viewer.
class _Card extends StatelessWidget {
  const _Card({required this.child, this.header, this.expand = false});
  final Widget child;
  final Widget? header;

  /// Fill the remaining height (the file viewer scrolls inside the card).
  final bool expand;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(Radii.lg),
        border: Border.all(color: c.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (header != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: Space.lg, vertical: Space.sm + 2),
              decoration: BoxDecoration(
                border: Border(bottom: BorderSide(color: c.border)),
              ),
              child: header,
            ),
          if (expand) Expanded(child: child) else child,
        ],
      ),
    );
  }
}

class _Message extends StatelessWidget {
  const _Message(this.text, {this.icon = Icons.info_outline_rounded});
  final String text;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Padding(
      padding: const EdgeInsets.all(Space.xl),
      child: Row(
        children: [
          Icon(icon, size: 18, color: c.muted),
          const SizedBox(width: Space.sm),
          Expanded(
            child: Text(text, style: TextStyle(color: c.muted)),
          ),
        ],
      ),
    );
  }
}

class _FolderPage extends ConsumerWidget {
  const _FolderPage({
    required this.source,
    required this.dir,
    required this.errorHint,
    required this.onOpen,
    required this.onNavigate,
  });
  final RepoContentSource source;
  final String? errorHint;
  final String dir;
  final ValueChanged<TreeEntry> onOpen;
  final ValueChanged<String> onNavigate;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = L10n.of(context);
    final tree = ref.watch(treeProvider((source: source, dir: dir)));
    final Widget listing = switch (tree) {
      AsyncData(:final value) when value.isEmpty => _Message(l.overviewEmptyFolder),
      AsyncData(:final value) => Column(
        children: [for (final e in value) _EntryRow(entry: e, onTap: () => onOpen(e))],
      ),
      AsyncError() when errorHint != null => _Message(errorHint!),
      AsyncError(:final error) => _Message(l.overviewLoadError('$error'), icon: Icons.error_outline_rounded),
      _ => const Padding(padding: EdgeInsets.all(Space.xl), child: LinearProgressIndicator(minHeight: 2)),
    };
    final readme = findReadme(tree.value ?? const []);
    return ListView(
      padding: const EdgeInsets.fromLTRB(Space.xl, Space.sm, Space.xl, Space.xl),
      children: [
        _Card(child: listing),
        const SizedBox(height: Space.lg),
        if (readme != null)
          _ReadmeCard(source: source, entry: readme, onNavigate: onNavigate)
        else if (tree.hasValue)
          _Card(child: _Message(l.overviewNoReadme, icon: Icons.menu_book_rounded)),
      ],
    );
  }
}

class _EntryRow extends StatelessWidget {
  const _EntryRow({required this.entry, required this.onTap});
  final TreeEntry entry;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final l = L10n.of(context);
    final (icon, color) = switch (entry.kind) {
      EntryKind.directory => (Icons.folder_rounded, c.accent),
      EntryKind.submodule => (Icons.widgets_outlined, c.warning),
      EntryKind.symlink => (Icons.link_rounded, c.muted),
      EntryKind.file => (Icons.insert_drive_file_outlined, c.muted),
    };
    final note = switch (entry.kind) {
      EntryKind.submodule => l.overviewSubmodule,
      EntryKind.symlink => l.overviewSymlink,
      _ => entry.size == null ? '' : formatBytes(entry.size!),
    };
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: Space.lg, vertical: Space.sm),
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: c.border.withValues(alpha: 0.5))),
        ),
        child: Row(
          children: [
            Icon(icon, size: 18, color: color),
            const SizedBox(width: Space.md),
            Expanded(
              child: Text(
                entry.name,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: c.text),
              ),
            ),
            Text(note, style: TextStyle(fontSize: 12, color: c.muted)),
          ],
        ),
      ),
    );
  }
}

class _ReadmeCard extends ConsumerWidget {
  const _ReadmeCard({required this.source, required this.entry, required this.onNavigate});
  final RepoContentSource source;
  final TreeEntry entry;
  final ValueChanged<String> onNavigate;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final blob = ref.watch(blobProvider((source: source, path: entry.path)));
    return _Card(
      header: Row(
        children: [
          Icon(Icons.menu_book_rounded, size: 16, color: c.muted),
          const SizedBox(width: Space.sm),
          Text(
            entry.name,
            style: TextStyle(fontWeight: FontWeight.w700, color: c.text),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(Space.xl),
        child: _BlobBody(blob: blob, source: source, path: entry.path, onNavigate: onNavigate, rendered: true),
      ),
    );
  }
}

class _FilePage extends ConsumerStatefulWidget {
  const _FilePage({super.key, required this.source, required this.path, required this.onNavigate});
  final RepoContentSource source;
  final String path;
  final ValueChanged<String> onNavigate;

  @override
  ConsumerState<_FilePage> createState() => _FilePageState();
}

class _FilePageState extends ConsumerState<_FilePage> {
  var _rendered = true;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final l = L10n.of(context);
    final blob = ref.watch(blobProvider((source: widget.source, path: widget.path)));
    final size = switch (blob.value) {
      TextBlob(:final size) || BinaryBlob(:final size) || TooLargeBlob(:final size) => formatBytes(size),
      ImageBlob(:final bytes) => formatBytes(bytes.length),
      _ => '',
    };
    return Padding(
      padding: const EdgeInsets.fromLTRB(Space.xl, Space.sm, Space.xl, Space.xl),
      child: _Card(
        expand: true,
        header: Row(
          children: [
            Text(size, style: TextStyle(fontSize: 12, color: c.muted)),
            const Spacer(),
            if (isMarkdownPath(widget.path))
              SegmentedButton<bool>(
                showSelectedIcon: false,
                style: const ButtonStyle(visualDensity: VisualDensity.compact),
                segments: [
                  ButtonSegment(value: true, label: Text(l.overviewRendered)),
                  ButtonSegment(value: false, label: Text(l.overviewRaw)),
                ],
                selected: {_rendered},
                onSelectionChanged: (v) => setState(() => _rendered = v.first),
              ),
          ],
        ),
        child: switch (blob.value) {
          // Source text scrolls itself so long files build lazily.
          TextBlob(:final text) when !(_rendered && isMarkdownPath(widget.path)) => _SourceText(text: text),
          _ => SingleChildScrollView(
            padding: const EdgeInsets.all(Space.lg),
            child: _BlobBody(
              blob: blob,
              source: widget.source,
              path: widget.path,
              onNavigate: widget.onNavigate,
              rendered: _rendered,
            ),
          ),
        },
      ),
    );
  }
}

/// The body of a file: markdown, source text, image or a reason it is hidden.
class _BlobBody extends StatelessWidget {
  const _BlobBody({
    required this.blob,
    required this.source,
    required this.path,
    required this.onNavigate,
    required this.rendered,
  });

  final AsyncValue<BlobContent> blob;
  final RepoContentSource source;
  final String path;
  final ValueChanged<String> onNavigate;
  final bool rendered;

  @override
  Widget build(BuildContext context) {
    final l = L10n.of(context);
    final dir = p.posix.dirname(path) == '.' ? '' : p.posix.dirname(path);
    return switch (blob) {
      AsyncData(value: TextBlob(:final text)) when rendered && isMarkdownPath(path) => RepoMarkdown(
        text: text,
        source: source,
        baseDir: dir,
        onNavigate: onNavigate,
      ),
      AsyncData(value: TextBlob(:final text)) => SelectableText(
        text,
        style: TextStyle(fontFamily: 'Consolas', fontSize: 13, height: 1.5, color: context.colors.text),
      ),
      AsyncData(value: ImageBlob(:final bytes)) => Align(
        alignment: Alignment.centerLeft,
        child: Image.memory(
          Uint8List.fromList(bytes),
          cacheWidth: 1600,
          errorBuilder: (_, _, _) => _Message(l.overviewBinary(formatBytes(bytes.length))),
        ),
      ),
      AsyncData(value: BinaryBlob(:final size)) => _Message(l.overviewBinary(formatBytes(size))),
      AsyncData(value: TooLargeBlob(:final size)) => _Message(l.overviewTooLarge(formatBytes(size))),
      AsyncData(value: BlockedBlob()) => _Message(l.overviewBlocked, icon: Icons.block_rounded),
      AsyncData(value: MissingBlob()) => _Message(l.overviewMissing),
      AsyncError(:final error) => _Message(l.overviewLoadError('$error'), icon: Icons.error_outline_rounded),
      _ => const LinearProgressIndicator(minHeight: 2),
    };
  }
}

/// Plain text with line numbers. Lines build lazily so big files stay smooth.
/// Only used where it can scroll on its own; the README card renders markdown.
class _SourceText extends StatelessWidget {
  const _SourceText({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final lines = text.split('\n');
    final gutter = '${lines.length}'.length * 9.0 + Space.md;
    final style = TextStyle(fontFamily: 'Consolas', fontSize: 13, height: 1.5, color: c.text);
    return SelectionArea(
      child: ListView.builder(
        padding: const EdgeInsets.all(Space.lg),
        itemCount: lines.length,
        itemBuilder: (_, i) => Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SelectionContainer.disabled(
              child: SizedBox(
                width: gutter,
                child: Text('${i + 1}', style: style.copyWith(color: c.muted)),
              ),
            ),
            Expanded(child: Text(lines[i].replaceAll('\r', ''), style: style)),
          ],
        ),
      ),
    );
  }
}
