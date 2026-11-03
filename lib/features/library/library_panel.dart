import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models/app_models.dart';
import '../../core/storage/repository_store.dart';
import '../../l10n/app_localizations.dart';
import '../../state/app_state.dart';
import '../../ui/theme.dart';
import '../../ui/widgets/feedback.dart';

/// Left "game library": repositories as cards, grouped by where they live.
class LibraryPanel extends ConsumerStatefulWidget {
  const LibraryPanel({super.key, required this.searchFocus});

  final FocusNode searchFocus;

  static const width = 288.0;

  @override
  ConsumerState<LibraryPanel> createState() => _LibraryPanelState();
}

class _LibraryPanelState extends ConsumerState<LibraryPanel> {
  final _query = TextEditingController();

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  Future<void> _addExisting() async {
    final l = L10n.of(context);
    final path = await FilePicker.platform.getDirectoryPath(dialogTitle: l.pickRepositoryFolder);
    if (path == null || !mounted) return;
    try {
      await ref.read(libraryProvider.notifier).add(path);
    } on NotARepositoryException catch (e) {
      if (mounted) showGhpToast(context, l.notARepository(e.path), tone: ToastTone.error);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final l = L10n.of(context);
    final library = ref.watch(libraryProvider);
    final query = _query.text.trim().toLowerCase();
    final visible =
        library.repositories.where((r) => query.isEmpty || r.displayName.toLowerCase().contains(query)).toList()
          ..sort((a, b) {
            if (a.pinned != b.pinned) return a.pinned ? -1 : 1;
            return a.displayName.toLowerCase().compareTo(b.displayName.toLowerCase());
          });
    final groups = {
      for (final group in RepositoryGroup.values) group: visible.where((r) => r.group == group).toList(),
    }..removeWhere((_, items) => items.isEmpty);

    return Container(
      width: LibraryPanel.width,
      decoration: BoxDecoration(color: c.surface, border: Border(right: BorderSide(color: c.border))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(Space.lg, Space.lg, Space.md, Space.sm),
            child: Row(
              children: [
                Text(l.libraryTitle.toUpperCase(),
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, letterSpacing: 1.2, color: c.muted)),
                const SizedBox(width: Space.sm),
                _CountPill(count: library.repositories.length),
                const Spacer(),
                PopupMenuButton<String>(
                  tooltip: l.libraryAdd,
                  icon: Icon(Icons.add_rounded, color: c.text),
                  color: c.raised,
                  onSelected: (value) {
                    if (value == 'existing') _addExisting();
                  },
                  itemBuilder: (_) => [
                    PopupMenuItem(value: 'existing', child: Text(l.addExisting)),
                    PopupMenuItem(value: 'create', enabled: false, child: Text(l.addCreate)),
                    PopupMenuItem(value: 'clone', enabled: false, child: Text(l.addClone)),
                  ],
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: Space.md),
            child: TextField(
              controller: _query,
              focusNode: widget.searchFocus,
              onChanged: (_) => setState(() {}),
              style: const TextStyle(fontSize: 13),
              decoration: InputDecoration(
                hintText: l.libraryFilter,
                prefixIcon: Icon(Icons.search_rounded, size: 18, color: c.muted),
                prefixIconConstraints: const BoxConstraints(minWidth: 36),
              ),
            ),
          ),
          const SizedBox(height: Space.sm),
          Expanded(
            child: library.repositories.isEmpty
                ? Padding(
                    padding: const EdgeInsets.all(Space.lg),
                    child: Column(
                      children: [
                        Text(l.libraryEmpty, style: TextStyle(color: c.muted)),
                        const SizedBox(height: Space.md),
                        FilledButton.icon(
                          onPressed: _addExisting,
                          icon: const Icon(Icons.add_rounded, size: 18),
                          label: Text(l.addExisting),
                        ),
                      ],
                    ),
                  )
                : ListView(
                    padding: const EdgeInsets.only(bottom: Space.lg),
                    children: [
                      for (final entry in groups.entries) ...[
                        _GroupHeader(group: entry.key, count: entry.value.length),
                        for (final repo in entry.value)
                          _RepositoryCard(
                            repo: repo,
                            selected: repo.id == library.selectedId,
                            onTap: () => ref.read(libraryProvider.notifier).select(repo.id),
                          ),
                      ],
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

class _CountPill extends StatelessWidget {
  const _CountPill({required this.count});
  final int count;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 1),
      decoration: BoxDecoration(color: c.raised, borderRadius: BorderRadius.circular(20)),
      child: Text('$count', style: TextStyle(fontSize: 11, color: c.muted, fontWeight: FontWeight.w600)),
    );
  }
}

class _GroupHeader extends StatelessWidget {
  const _GroupHeader({required this.group, required this.count});
  final RepositoryGroup group;
  final int count;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final l = L10n.of(context);
    final (label, icon) = switch (group) {
      RepositoryGroup.local => (l.groupLocal, Icons.computer_rounded),
      RepositoryGroup.hub => (l.groupHub, Icons.hub_rounded),
      RepositoryGroup.github => (l.groupGithub, Icons.public_rounded),
    };
    return Padding(
      padding: const EdgeInsets.fromLTRB(Space.lg, Space.md, Space.lg, Space.xs),
      child: Row(
        children: [
          Icon(icon, size: 13, color: c.muted),
          const SizedBox(width: Space.xs + 2),
          Text('$label · $count', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: c.muted)),
        ],
      ),
    );
  }
}

/// A library entry styled like a game tile: cover with initial, name, subtitle.
class _RepositoryCard extends StatefulWidget {
  const _RepositoryCard({required this.repo, required this.selected, required this.onTap});

  final RepositoryInfo repo;
  final bool selected;
  final VoidCallback onTap;

  @override
  State<_RepositoryCard> createState() => _RepositoryCardState();
}

class _RepositoryCardState extends State<_RepositoryCard> {
  var _hover = false;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final l = L10n.of(context);
    final repo = widget.repo;
    final cover = coverColor(repo.id);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: Space.sm, vertical: 2),
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hover = true),
        onExit: (_) => setState(() => _hover = false),
        child: Semantics(
          button: true,
          selected: widget.selected,
          label: repo.displayName,
          child: GestureDetector(
            onTap: widget.onTap,
            child: AnimatedContainer(
              duration: context.motion(Motion.fast),
              padding: const EdgeInsets.all(Space.sm),
              decoration: BoxDecoration(
                color: widget.selected ? c.accentSoft : (_hover ? c.raised : Colors.transparent),
                borderRadius: BorderRadius.circular(Radii.md),
                border: Border.all(color: widget.selected ? c.accent.withValues(alpha: 0.7) : Colors.transparent),
              ),
              child: Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(Radii.sm),
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [cover, Color.lerp(cover, Colors.black, 0.45)!],
                      ),
                    ),
                    child: Text(
                      repo.displayName.characters.first.toUpperCase(),
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 17),
                    ),
                  ),
                  const SizedBox(width: Space.sm + 2),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          repo.displayName,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 13.5,
                            color: repo.available ? c.text : c.muted,
                          ),
                        ),
                        const SizedBox(height: 1),
                        Text(
                          repo.available ? repo.path : l.repoMissing,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 11, color: repo.available ? c.muted : c.warning),
                        ),
                      ],
                    ),
                  ),
                  if (repo.pinned) Icon(Icons.push_pin_rounded, size: 13, color: c.muted),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Deterministic cover color per repository (like game box art accents).
Color coverColor(String id) {
  const palette = [
    Color(0xFF1F7AE0),
    Color(0xFF8B5CF6),
    Color(0xFF14B8A6),
    Color(0xFFF59E0B),
    Color(0xFFEF4444),
    Color(0xFF22C55E),
    Color(0xFFEC4899),
    Color(0xFF0EA5E9),
  ];
  return palette[id.codeUnits.fold<int>(0, (a, b) => a + b) % palette.length];
}
