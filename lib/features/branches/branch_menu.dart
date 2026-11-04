// EXTENSION POINT (owner: worker U2). Keep the function signature.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/expeditions/expedition.dart';
import '../../core/git/branches.dart';
import '../../core/git/git_runner.dart';
import '../../core/git/merge.dart';
import '../../core/git/rewrite.dart';
import '../../core/git/stage.dart';
import '../../core/models/advanced.dart';
import '../../core/models/app_models.dart';
import '../../core/models/commit.dart';
import '../../l10n/app_localizations.dart';
import '../../l10n/terms.dart';
import '../../state/app_state.dart';
import '../../state/changes_state.dart';
import '../../state/repo_state.dart';
import '../../ui/format.dart';
import '../../ui/theme.dart';
import '../../ui/widgets/feedback.dart';

final branchListProvider = FutureProvider.autoDispose.family<List<Branch>, RepositoryInfo>((ref, repo) {
  ref.watch(repoStatusProvider(repo.id));
  return getBranches(ref.watch(gitProvider), repo.path);
});

Future<void> showBranchMenu(BuildContext context, WidgetRef ref, RepositoryInfo repo) async {
  await showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (_) => _BranchMenu(repo: repo),
  );
}

class _BranchMenu extends ConsumerStatefulWidget {
  const _BranchMenu({required this.repo});
  final RepositoryInfo repo;
  @override
  ConsumerState<_BranchMenu> createState() => _BranchMenuState();
}

class _BranchMenuState extends ConsumerState<_BranchMenu> {
  String _query = '';
  bool _busy = false;
  bool _checking = false;
  RepositoryInfo get repo => widget.repo;

  Future<void> _integrate(Branch branch, bool movingBase) async {
    if (_busy || _checking || branch.isCurrent) return;
    _checking = true;
    final l = L10n.of(context);
    final t = Terms.of(context);
    final term = movingBase ? t.rebase : t.merge;
    final refresh = ref.read(changesProvider(repo.id).notifier).refreshStatus;
    try {
      final status = await ref.refresh(repoStatusProvider(repo.id).future);
      if (!mounted || status.inProgress != null) return;
      if (movingBase) {
        final accepted = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(l.rebaseOnto(t.branch, t.rebase)),
            content: Text(l.rebaseWarning(t.rebase)),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context, false), child: Text(l.branchCancel)),
              FilledButton(
                key: const Key('rebase-confirm'),
                onPressed: () => Navigator.pop(context, true),
                child: Text(t.rebase),
              ),
            ],
          ),
        );
        if (accepted != true || !mounted) return;
      }
      setState(() => _busy = true);
      final git = ref.read(gitProvider);
      String describe(OperationOutcome result) => switch (result) {
        OperationOutcome.conflicts => l.mergeConflicts(t.changes),
        OperationOutcome.completed => l.mergeCompleted(term),
        OperationOutcome.nothingToDo => l.mergeNothing,
      };
      final outcome = await ref
          .read(expeditionsProvider.notifier)
          .run<OperationOutcome>(
            kind: movingBase ? ExpeditionKind.rebase : ExpeditionKind.checkout,
            title: movingBase ? l.rebaseOnto(t.branch, term) : l.mergeInto(t.branch, term),
            destination: branch.name,
            repoId: repo.id,
            task: (_) => withRepositoryOperation(repo.path, () async {
              try {
                return await (movingBase ? rebase(git, repo.path, branch.name) : merge(git, repo.path, branch.name));
              } catch (error) {
                throw StateError(redactCredentials(error.toString()));
              }
            }),
            result: describe,
          );
      if (mounted) {
        showGhpToast(
          context,
          outcome == null ? l.branchFailed : describe(outcome),
          tone: outcome == null
              ? ToastTone.error
              : outcome == OperationOutcome.conflicts
              ? ToastTone.info
              : ToastTone.success,
        );
      }
    } catch (error) {
      if (mounted) {
        showGhpToast(context, l.branchFailed, tone: ToastTone.error, detail: redactCredentials(error.toString()));
      }
    } finally {
      refresh();
      if (mounted) ref.invalidate(branchListProvider(repo));
      _checking = false;
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<bool> _run(
    String title,
    String destination,
    Future<void> Function(void Function(double, String?) report) task,
  ) async {
    setState(() => _busy = true);
    String? failure;
    final result = await ref
        .read(expeditionsProvider.notifier)
        .run<bool>(
          kind: ExpeditionKind.checkout,
          title: title,
          destination: destination,
          repoId: repo.id,
          task: (report) async {
            try {
              await task(report);
              return true;
            } catch (error) {
              failure = redactCredentials(error.toString());
              throw StateError(failure!);
            }
          },
        );
    if (!mounted) return result == true;
    ref.invalidate(repoStatusProvider(repo.id));
    ref.invalidate(branchListProvider(repo));
    setState(() => _busy = false);
    if (failure != null) showGhpToast(context, L10n.of(context).branchFailed, tone: ToastTone.error, detail: failure);
    return result == true;
  }

  Future<bool> _warnChanges(String name) async {
    final status = await ref.refresh(repoStatusProvider(repo.id).future);
    if (!mounted) return false;
    if (status.files.isEmpty) return true;
    final l = L10n.of(context);
    return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(l.branchSwitch(name)),
            content: Text(l.branchSwitchWarning(name)),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context, false), child: Text(l.branchCancel)),
              FilledButton(
                key: const Key('branch-confirm-switch'),
                onPressed: () => Navigator.pop(context, true),
                child: Text(l.branchContinue),
              ),
            ],
          ),
        ) ??
        false;
  }

  Future<void> _checkout(Branch branch) async {
    if (branch.isCurrent || _busy || _checking) return;
    _checking = true;
    final git = ref.read(gitProvider);
    try {
      if (!await _warnChanges(branch.name) || !mounted) return;
      final success = await _run(
        L10n.of(context).branchSwitch(branch.name),
        branch.name,
        (report) => checkoutBranch(git, repo.path, branch, onProgress: report),
      );
      if (success && mounted) Navigator.pop(context);
    } catch (error) {
      if (mounted) {
        showGhpToast(
          context,
          L10n.of(context).branchFailed,
          tone: ToastTone.error,
          detail: redactCredentials(error.toString()),
        );
      }
    } finally {
      _checking = false;
    }
  }

  Future<void> _name({Branch? branch}) async {
    final l = L10n.of(context);
    final git = ref.read(gitProvider);
    final title = branch == null ? l.branchCreate(Terms.of(context).branch) : l.branchRename;
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) => _BranchNameDialog(
        title: title,
        initial: branch?.name ?? '',
        branchTerm: Terms.of(context).branch,
        submit: (name) async {
          final branches = await getBranches(git, repo.path);
          if (!mounted) return false;
          if (branches.any((b) => b.type == BranchType.local && b.name == name)) throw StateError(l.branchExists);
          if (branch == null && !await _warnChanges(name)) return false;
          if (!mounted) return false;
          final success = await _run(title, name, (report) async {
            if (branch != null) {
              await renameBranch(git, repo.path, branch.name, name);
            } else {
              await createBranch(git, repo.path, name, checkout: false);
              final created = (await getBranches(
                git,
                repo.path,
              )).firstWhere((b) => b.type == BranchType.local && b.name == name);
              await checkoutBranch(git, repo.path, created, onProgress: report);
            }
          });
          return success;
        },
      ),
    );
  }

  /// Row actions. The menu is shown and awaited here (not by a
  /// PopupMenuButton) so a choice still runs when the branch list rebuilds
  /// while the menu is open; PopupMenuButton drops it once it is unmounted.
  Future<void> _openRowMenu(BuildContext buttonContext, Branch b) async {
    final l = L10n.of(context);
    final t = Terms.of(context);
    final box = buttonContext.findRenderObject() as RenderBox?;
    final overlay = Overlay.of(buttonContext).context.findRenderObject() as RenderBox?;
    if (box == null || overlay == null) return;
    final topLeft = box.localToGlobal(Offset.zero, ancestor: overlay);
    final position = RelativeRect.fromRect(topLeft & box.size, Offset.zero & overlay.size);
    final idle = ref.read(repoStatusProvider(repo.id)).value?.inProgress == null;
    final action = await showMenu<String>(
      context: context,
      position: position,
      items: [
        if (!b.isCurrent) ...[
          PopupMenuItem(value: 'merge', enabled: idle, child: Text(l.mergeInto(t.branch, t.merge))),
          PopupMenuItem(value: 'rebase', enabled: idle, child: Text(l.rebaseOnto(t.branch, t.rebase))),
        ],
        if (b.type == BranchType.local) PopupMenuItem(value: 'rename', child: Text(l.branchRename)),
        PopupMenuItem(value: 'delete', enabled: !b.isCurrent, child: Text(l.branchDelete)),
      ],
    );
    if (!mounted || action == null) return;
    switch (action) {
      case 'merge':
        await _integrate(b, false);
      case 'rebase':
        await _integrate(b, true);
      case 'rename':
        await _name(branch: b);
      case 'delete':
        await _delete(b);
    }
  }

  Future<void> _delete(Branch branch) async {
    if (branch.isCurrent) return;
    final l = L10n.of(context);
    var force = false;
    var remote = false;
    final accepted = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, change) => AlertDialog(
          title: Text(l.branchDeleteConfirm(branch.name)),
          content: SizedBox(
            width: 400,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (branch.type == BranchType.local)
                  CheckboxListTile(
                    key: const Key('branch-force'),
                    contentPadding: EdgeInsets.zero,
                    value: force,
                    onChanged: (v) => change(() => force = v!),
                    title: Text(l.branchForce(Terms.of(context).merge)),
                  ),
                if (branch.type == BranchType.remote || branch.upstream != null)
                  CheckboxListTile(
                    key: const Key('branch-delete-remote'),
                    contentPadding: EdgeInsets.zero,
                    value: remote,
                    onChanged: (v) => change(() => remote = v!),
                    title: Text(l.branchDeleteRemote),
                  ),
                if (branch.type == BranchType.remote) Text(l.branchRemoteWarning),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: Text(l.branchCancel)),
            FilledButton(
              key: const Key('branch-confirm-delete'),
              style: FilledButton.styleFrom(backgroundColor: context.colors.danger),
              onPressed: () => Navigator.pop(context, true),
              child: Text(l.branchDelete),
            ),
          ],
        ),
      ),
    );
    if (accepted != true || !mounted) return;
    final git = ref.read(gitProvider);
    await _run(
      l.branchDeleteConfirm(branch.name),
      branch.name,
      (_) => deleteBranch(git, repo.path, branch, force: force, includeRemote: remote),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = L10n.of(context);
    final t = Terms.of(context);
    final c = context.colors;
    final branches = ref.watch(branchListProvider(repo));
    return PopScope(
      canPop: !_busy,
      child: Dialog(
        child: SizedBox(
          width: 540,
          height: MediaQuery.sizeOf(context).height * .75,
          child: Padding(
            padding: const EdgeInsets.all(Space.lg),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(child: Text(t.branch, style: Theme.of(context).textTheme.titleLarge)),
                    IconButton(
                      tooltip: l.historyClose,
                      onPressed: _busy ? null : () => Navigator.pop(context),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
                const SizedBox(height: Space.md),
                TextField(
                  key: const Key('branch-search'),
                  enabled: !_busy,
                  decoration: InputDecoration(hintText: l.branchSearch(t.branch), prefixIcon: const Icon(Icons.search)),
                  onChanged: (v) => setState(() => _query = v.trim().toLowerCase()),
                ),
                const SizedBox(height: Space.sm),
                if (_busy) const LinearProgressIndicator(),
                Expanded(
                  child: branches.when(
                    loading: () => const Center(child: CircularProgressIndicator()),
                    error: (e, _) => Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(redactCredentials(e.toString()), style: TextStyle(color: c.danger)),
                        TextButton(
                          onPressed: () => ref.invalidate(branchListProvider(repo)),
                          child: Text(l.historyRetry),
                        ),
                      ],
                    ),
                    data: (all) {
                      final filtered = all.where((b) => b.name.toLowerCase().contains(_query)).toList();
                      if (filtered.isEmpty) {
                        return Center(
                          child: Text(l.branchEmpty, style: TextStyle(color: c.muted)),
                        );
                      }
                      final sections = [
                        (l.branchCurrent, filtered.where((b) => b.isCurrent).toList()),
                        (
                          l.branchLocal(t.branch),
                          filtered.where((b) => b.type == BranchType.local && !b.isCurrent).toList(),
                        ),
                        (l.branchRemote(t.branch), filtered.where((b) => b.type == BranchType.remote).toList()),
                      ];
                      return ListView(
                        children: [
                          for (final (heading, entries) in sections)
                            if (entries.isNotEmpty) ...[
                              Padding(
                                padding: const EdgeInsets.only(top: Space.lg, bottom: Space.xs),
                                child: Text(
                                  heading,
                                  style: TextStyle(color: c.muted, fontSize: 12, fontWeight: FontWeight.w600),
                                ),
                              ),
                              for (final b in entries)
                                ListTile(
                                  key: ValueKey('branch-${b.type.name}-${b.name}'),
                                  contentPadding: EdgeInsets.zero,
                                  selected: b.isCurrent,
                                  enabled: !_busy,
                                  leading: Icon(
                                    b.isCurrent
                                        ? Icons.check_circle_outline
                                        : b.type == BranchType.remote
                                        ? Icons.cloud_outlined
                                        : Icons.account_tree_outlined,
                                    color: b.isCurrent ? c.accent : c.muted,
                                  ),
                                  title: Text(b.name, maxLines: 1, overflow: TextOverflow.ellipsis),
                                  subtitle: Row(
                                    children: [
                                      if (b.ahead != 0 || b.behind != 0)
                                        Padding(
                                          padding: const EdgeInsets.only(right: Space.sm),
                                          child: Tooltip(
                                            message: l.branchAheadBehind(b.ahead, b.behind),
                                            child: Text(
                                              '↑${b.ahead} ↓${b.behind}',
                                              style: TextStyle(color: c.accent, fontSize: 11),
                                            ),
                                          ),
                                        ),
                                      if (b.tipDate != null)
                                        Text(
                                          formatAgo(context, b.tipDate!),
                                          style: TextStyle(color: c.muted, fontSize: 11),
                                        ),
                                    ],
                                  ),
                                  onTap: b.isCurrent || _busy ? null : () => _checkout(b),
                                  trailing: Builder(
                                    builder: (buttonContext) => IconButton(
                                      key: ValueKey('branch-menu-${b.name}'),
                                      tooltip: l.branchMenu(b.name),
                                      icon: const Icon(Icons.more_vert_rounded),
                                      onPressed: _busy ? null : () => _openRowMenu(buttonContext, b),
                                    ),
                                  ),
                                ),
                            ],
                        ],
                      );
                    },
                  ),
                ),
                const Divider(),
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    key: const Key('branch-create'),
                    onPressed: _busy ? null : () => _name(),
                    icon: const Icon(Icons.add),
                    label: Text(l.branchCreate(t.branch)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _BranchNameDialog extends StatefulWidget {
  const _BranchNameDialog({required this.title, required this.initial, required this.branchTerm, required this.submit});
  final String title;
  final String initial;
  final String branchTerm;
  final Future<bool> Function(String) submit;
  @override
  State<_BranchNameDialog> createState() => _BranchNameDialogState();
}

class _BranchNameDialogState extends State<_BranchNameDialog> {
  late final _name = TextEditingController(text: widget.initial);
  bool _busy = false;
  String? _error;
  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final value = _name.text;
    final l = L10n.of(context);
    if (value.isEmpty ||
        value.startsWith('-') ||
        value.endsWith('.') ||
        value.endsWith('/') ||
        value.contains('..') ||
        value.contains('@{') ||
        value.contains('//') ||
        value == '@' ||
        RegExp(r'[\x00-\x20\x7f~^:?*\[\\]').hasMatch(value) ||
        value.split('/').any((p) => p.startsWith('.') || p.endsWith('.lock') || p.isEmpty)) {
      setState(() => _error = l.branchInvalid);
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final success = await widget.submit(value);
      if (!mounted) return;
      if (success) {
        Navigator.pop(context);
        return;
      }
      setState(() {
        _busy = false;
        _error = l.branchFailed;
      });
    } catch (error) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = redactCredentials(error.toString());
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = L10n.of(context);
    return PopScope(
      canPop: !_busy,
      child: AlertDialog(
        title: Text(widget.title),
        content: SizedBox(
          width: 360,
          child: TextField(
            key: const Key('branch-name'),
            controller: _name,
            autofocus: true,
            enabled: !_busy,
            inputFormatters: [_HyphenateSpaces()],
            decoration: InputDecoration(
              labelText: l.branchName(widget.branchTerm),
              helperText: l.branchNameHint,
              errorText: _error,
            ),
            onSubmitted: (_) {
              if (!_busy) _submit();
            },
          ),
        ),
        actions: [
          TextButton(onPressed: _busy ? null : () => Navigator.pop(context), child: Text(l.branchCancel)),
          FilledButton(key: const Key('branch-save'), onPressed: _busy ? null : _submit, child: Text(l.branchSave)),
        ],
      ),
    );
  }
}

class _HyphenateSpaces extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) =>
      newValue.copyWith(text: newValue.text.replaceAll(RegExp(r'\s'), '-'));
}
