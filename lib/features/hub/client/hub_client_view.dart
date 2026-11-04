import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../../core/content/repo_content.dart';
import '../../../core/expeditions/expedition.dart';
import '../../../core/git/clone.dart';
import '../../../core/git/git_runner.dart';
import '../../../core/history/graph.dart';
import '../../../core/hub/client.dart';
import '../../../core/hub/hub_models.dart';
import '../../../core/hub/validation.dart';
import '../../../core/models/commit.dart';
import '../../../core/models/diff.dart';
import '../../../l10n/app_localizations.dart';
import '../../../l10n/terms.dart';
import '../../../state/app_state.dart';
import '../../../state/hub_client_state.dart';
import '../../../ui/format.dart';
import '../../../ui/theme.dart';
import '../../../ui/widgets/diff_view.dart';
import '../../../ui/widgets/feedback.dart';
import '../../expeditions/expedition_panel.dart';
import '../../history/history_view.dart' show CommitGraphPainter;
import '../../overview/overview_view.dart';
import 'hub_library_section.dart';

/// LibraryPanel exports this adapter so the shell needs only its outlet line.
Widget? hubClientScreen(WidgetRef ref) {
  final hub = ref.watch(selectedHubProvider);
  return hub == null ? null : HubClientView(key: ValueKey(hub.url), hub: hub);
}

class HubClientView extends ConsumerStatefulWidget {
  const HubClientView({super.key, required this.hub});
  final DiscoveredHub hub;
  @override
  ConsumerState<HubClientView> createState() => _HubClientViewState();
}

class _HubClientViewState extends ConsumerState<HubClientView> {
  HubRepository? repository;
  @override
  Widget build(BuildContext context) {
    final l = L10n.of(context);
    final repos = ref.watch(hubRepositoriesProvider(widget.hub.url));
    ref.listen(hubRepositoriesProvider(widget.hub.url), (_, next) {
      if (next.hasError) showGhpToast(context, hubClientError(l, next.error!), tone: ToastTone.error);
    });
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.all(Space.lg),
          child: Row(
            children: [
              if (repository != null)
                IconButton(
                  tooltip: l.hubClientBack,
                  icon: const Icon(Icons.arrow_back_rounded),
                  onPressed: () => setState(() => repository = null),
                ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(repository?.name ?? widget.hub.name, style: Theme.of(context).textTheme.headlineSmall),
                    Text(widget.hub.url, style: TextStyle(color: context.colors.muted)),
                  ],
                ),
              ),
              IconButton(
                tooltip: l.overviewRefresh,
                icon: const Icon(Icons.refresh_rounded),
                onPressed: () => ref.invalidate(hubRepositoriesProvider(widget.hub.url)),
              ),
            ],
          ),
        ),
        Expanded(
          child: repository != null
              ? _RepositoryPage(key: ValueKey(repository!.name), hub: widget.hub, repository: repository!)
              : repos.when(
                  loading: () => const Center(child: CircularProgressIndicator()),
                  error: (e, _) => Center(child: Text(hubClientError(l, e))),
                  data: (items) => items.isEmpty
                      ? Center(child: Text(l.hubClientEmpty))
                      : GridView.builder(
                          padding: const EdgeInsets.all(Space.lg),
                          gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                            maxCrossAxisExtent: 380,
                            mainAxisExtent: 180,
                            mainAxisSpacing: Space.md,
                            crossAxisSpacing: Space.md,
                          ),
                          itemCount: items.length,
                          itemBuilder: (context, index) {
                            final repo = items[index];
                            return Material(
                              color: context.colors.surface,
                              borderRadius: BorderRadius.circular(Radii.md),
                              child: InkWell(
                                borderRadius: BorderRadius.circular(Radii.md),
                                onTap: () => setState(() => repository = repo),
                                child: Padding(
                                  padding: const EdgeInsets.all(Space.lg),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        repo.name,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: Theme.of(context).textTheme.titleLarge,
                                      ),
                                      if (repo.description != null)
                                        Expanded(
                                          child: Text(repo.description!, maxLines: 3, overflow: TextOverflow.ellipsis),
                                        )
                                      else
                                        const Spacer(),
                                      if (repo.lastPushAt != null)
                                        Text(
                                          l.hubClientLastPush(
                                            Terms.of(context).push,
                                            formatAgo(context, repo.lastPushAt!),
                                          ),
                                          style: TextStyle(color: context.colors.muted, fontSize: 12),
                                        ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                ),
        ),
        if (ref.watch(expeditionsProvider).isNotEmpty) const SizedBox(height: 200, child: ExpeditionPanel()),
      ],
    );
  }
}

class _RepositoryPage extends ConsumerStatefulWidget {
  const _RepositoryPage({super.key, required this.hub, required this.repository});
  final DiscoveredHub hub;
  final HubRepository repository;
  @override
  ConsumerState<_RepositoryPage> createState() => _RepositoryPageState();
}

class _RepositoryPageState extends ConsumerState<_RepositoryPage> {
  late final HubClient client;
  late RepoContentSource source;
  late Future<List<Commit>> history;
  late Future<List<HubPushRecord>> pushes;
  late final branchInput = TextEditingController(text: widget.repository.defaultBranch ?? 'HEAD');
  String? branch;
  int tab = 0;
  int limit = 200;
  bool cloning = false;
  @override
  void initState() {
    super.initState();
    client = HubClient(widget.hub.url);
    branch = widget.repository.defaultBranch;
    reload();
  }

  void reload() {
    source = _NotifyingContentSource(client.contentSource(widget.repository.name, ref: branch), (error) {
      if (mounted) showGhpToast(context, hubClientError(L10n.of(context), error), tone: ToastTone.error);
    });
    history = client.log(widget.repository.name, ref: branch, limit: limit);
    pushes = client.pushes(widget.repository.name);
    // Hidden tabs still start requests; consume their errors until displayed.
    history.ignore();
    pushes.ignore();
  }

  @override
  void dispose() {
    client.close();
    branchInput.dispose();
    super.dispose();
  }

  Future<void> clone() async {
    final l = L10n.of(context);
    final title = l.hubClientClone(Terms.of(context).clone);
    // The hub response supplies the folder name. Validate before joining paths.
    if (!isValidRepositoryName(widget.repository.name)) {
      showGhpToast(context, l.hubClientInvalidName, tone: ToastTone.error);
      return;
    }
    final bootstrap = ref.read(bootstrapProvider);
    final library = ref.read(libraryProvider.notifier);
    final expeditions = ref.read(expeditionsProvider.notifier);
    final configured = ref.read(settingsProvider).defaultRepositoryDirectory;
    setState(() => cloning = true);
    try {
      final initial = configured ?? p.join((await getApplicationDocumentsDirectory()).path, 'GitHubPlus');
      await Directory(initial).create(recursive: true);
      final parent = await FilePicker.getDirectoryPath(dialogTitle: l.hubClientFolder, initialDirectory: initial);
      if (parent == null || !mounted) return;
      final target = p.join(parent, widget.repository.name);
      String? failure;
      final result = await expeditions.run<bool>(
        kind: ExpeditionKind.clone,
        title: title,
        destination: redactCredentials(widget.repository.url),
        task: (report) async {
          try {
            // Ensure the matcher exists even when this view is used directly.
            ref.read(hubDiscoveryProvider);
            await cloneRepository(
              bootstrap.git,
              Uri.parse(widget.hub.url).replace(pathSegments: ['${widget.repository.name}.git']).toString(),
              target,
              branch: branch,
              onProgress: (v, _) => report(v, title),
            );
            await library.add(target);
            return true;
          } catch (e) {
            failure = hubClientError(l, e);
            throw failure!;
          }
        },
        result: (_) => l.hubClientDone,
      );
      if (!mounted) return;
      if (result == true) {
        ref.read(selectedHubProvider.notifier).select(null);
        showGhpToast(context, l.hubClientDone);
      } else {
        showGhpToast(context, failure ?? l.hubClientFailed, tone: ToastTone.error);
      }
    } catch (e) {
      if (mounted) showGhpToast(context, hubClientError(l, e), tone: ToastTone.error);
    } finally {
      if (mounted) setState(() => cloning = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = L10n.of(context);
    final t = Terms.of(context);
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: Space.lg),
          child: Row(
            children: [
              Expanded(child: Text(widget.repository.description ?? '', maxLines: 2, overflow: TextOverflow.ellipsis)),
              const SizedBox(width: Space.md),
              FilledButton.icon(
                key: const Key('hub-clone'),
                onPressed: cloning ? null : clone,
                icon: const Icon(Icons.download_rounded),
                label: Text(l.hubClientClone(t.clone)),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(Space.md),
          child: Row(
            children: [
              Expanded(
                child: SegmentedButton<int>(
                  showSelectedIcon: false,
                  segments: [
                    ButtonSegment(value: 0, label: Text(l.hubClientOverview)),
                    ButtonSegment(value: 1, label: Text(l.hubClientHistory(t.history))),
                    ButtonSegment(value: 2, label: Text(l.hubClientPushes(t.push))),
                  ],
                  selected: {tab},
                  onSelectionChanged: (v) => setState(() => tab = v.first),
                ),
              ),
              IconButton(
                tooltip: l.overviewRefresh,
                icon: const Icon(Icons.refresh_rounded),
                onPressed: () => setState(reload),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: Space.lg),
          child: Autocomplete<String>(
            initialValue: branchInput.value,
            optionsBuilder: (value) => <String>{
              widget.repository.defaultBranch ?? 'HEAD',
              ...?lastBranches,
            }.where((b) => b.contains(value.text)),
            onSelected: selectBranch,
            fieldViewBuilder: (context, controller, focus, submit) => TextField(
              key: const Key('hub-branch'),
              controller: controller,
              focusNode: focus,
              decoration: InputDecoration(
                labelText: l.hubClientBranch(t.branch),
                suffixIcon: IconButton(
                  tooltip: l.hubClientConnect,
                  icon: const Icon(Icons.arrow_forward_rounded),
                  onPressed: () => selectBranch(controller.text),
                ),
              ),
              onSubmitted: selectBranch,
            ),
          ),
        ),
        const SizedBox(height: Space.sm),
        Expanded(
          child: switch (tab) {
            0 => ContentBrowser(
              source: source,
              rootLabel: widget.repository.name,
              errorHint: l.hubClientUnavailable,
              onRefresh: () => setState(reload),
            ),
            1 => _RemoteFuture<List<Commit>>(
              future: history,
              builder: (commits) {
                lastBranches = {
                  for (final c in commits)
                    for (final r in c.refs)
                      if (r != 'HEAD' && !r.startsWith('tag: ') && !r.startsWith('-')) r.replaceFirst('HEAD -> ', ''),
                };
                return Column(
                  children: [
                    Expanded(
                      child: _RemoteHistory(client: client, name: widget.repository.name, commits: commits),
                    ),
                    if (commits.length == limit)
                      TextButton(
                        onPressed: () => setState(() {
                          limit += 200;
                          reload();
                        }),
                        child: Text(l.hubClientMore),
                      ),
                  ],
                );
              },
            ),
            _ => _RemoteFuture<List<HubPushRecord>>(
              future: pushes,
              builder: (records) => records.isEmpty
                  ? Center(child: Text(l.hubClientNoPush(t.push)))
                  : ListView(
                      children: [
                        for (final record in records)
                          ListTile(
                            title: Text(record.clientHost ?? record.clientAddress),
                            subtitle: Text('${record.ref}\n${record.oldSha} → ${record.newSha}'),
                            trailing: Text(formatAgo(context, record.at)),
                          ),
                      ],
                    ),
            ),
          },
        ),
      ],
    );
  }

  Set<String>? lastBranches;
  void selectBranch(String value) {
    final name = value.trim();
    if (name.isEmpty || name.startsWith('-')) return;
    setState(() {
      branch = name;
      branchInput.text = name;
      limit = 200;
      reload();
    });
  }
}

class _RemoteFuture<T> extends StatefulWidget {
  const _RemoteFuture({required this.future, required this.builder});
  final Future<T> future;
  final Widget Function(T) builder;
  @override
  State<_RemoteFuture<T>> createState() => _RemoteFutureState<T>();
}

class _RemoteFutureState<T> extends State<_RemoteFuture<T>> {
  Future<T>? reported;
  @override
  Widget build(BuildContext context) => FutureBuilder<T>(
    future: widget.future,
    builder: (context, snapshot) {
      if (snapshot.connectionState != ConnectionState.done) {
        return const Center(child: CircularProgressIndicator());
      }
      if (snapshot.hasError) {
        final message = hubClientError(L10n.of(context), snapshot.error!);
        if (reported != widget.future) {
          reported = widget.future;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) showGhpToast(context, message, tone: ToastTone.error);
          });
        }
        return Center(child: Text(message));
      }
      if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
      return widget.builder(snapshot.data as T);
    },
  );
}

class _RemoteHistory extends StatefulWidget {
  const _RemoteHistory({required this.client, required this.name, required this.commits});
  final HubClient client;
  final String name;
  final List<Commit> commits;
  @override
  State<_RemoteHistory> createState() => _RemoteHistoryState();
}

class _RemoteHistoryState extends State<_RemoteHistory> {
  Commit? selected;
  Future<List<CommittedFile>>? files;
  Future<FileDiff>? diff;
  String? selectedPath;
  @override
  void didUpdateWidget(covariant _RemoteHistory oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.commits != widget.commits) {
      selected = null;
      files = null;
      diff = null;
    }
  }

  void choose(Commit c) => setState(() {
    selected = c;
    selectedPath = null;
    diff = null;
    files = widget.client.commitFiles(widget.name, c.sha);
  });
  @override
  Widget build(BuildContext context) {
    final l = L10n.of(context);
    final c = context.colors;
    if (widget.commits.isEmpty) return Center(child: Text(l.historyEmpty(Terms.of(context).commitUnit)));
    final graph = layoutGraph(widget.commits);
    final palette = [c.accent, c.success, c.warning, c.danger];
    final list = ListView.builder(
      itemCount: widget.commits.length,
      itemBuilder: (context, i) {
        final commit = widget.commits[i];
        return SizedBox(
          height: 76,
          child: ListTile(
            selected: selected?.sha == commit.sha,
            leading: SizedBox(
              width: Space.sm * 2 + 16 * graph[i].laneCount,
              height: 76,
              child: CustomPaint(
                painter: CommitGraphPainter(
                  row: graph[i],
                  previous: i == 0 ? null : graph[i - 1],
                  palette: palette,
                  background: c.background,
                ),
              ),
            ),
            title: Text(commit.summary, maxLines: 1, overflow: TextOverflow.ellipsis),
            subtitle: Text(
              '${commit.shortSha} · ${commit.author.name} · ${formatAgo(context, commit.author.date)}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            onTap: () => choose(commit),
          ),
        );
      },
    );
    final details = selected == null
        ? Center(child: Text(l.historySelect))
        : Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 160),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(Space.md),
                  child: SelectableText('${selected!.summary}\n${selected!.body}'),
                ),
              ),
              SizedBox(
                height: 140,
                child: _RemoteFuture<List<CommittedFile>>(
                  future: files!,
                  builder: (items) => items.isEmpty
                      ? Center(child: Text(l.historyNoFiles))
                      : ListView(
                          children: [
                            for (final file in items)
                              ListTile(
                                dense: true,
                                selected: selectedPath == file.path,
                                title: Text(file.path),
                                onTap: () => setState(() {
                                  selectedPath = file.path;
                                  diff = widget.client.commitDiff(widget.name, selected!.sha, file.path);
                                }),
                              ),
                          ],
                        ),
                ),
              ),
              if (diff != null)
                Expanded(
                  child: _RemoteFuture<FileDiff>(
                    future: diff!,
                    builder: (value) => FileDiffView(diff: value),
                  ),
                ),
            ],
          );
    return LayoutBuilder(
      builder: (context, constraints) => constraints.maxWidth < 680
          ? Column(
              children: [
                Expanded(child: list),
                Expanded(child: details),
              ],
            )
          : Row(
              children: [
                Expanded(child: list),
                VerticalDivider(color: c.border),
                Expanded(child: details),
              ],
            ),
    );
  }
}

/// ContentBrowser owns its loading UI; the adapter adds the shared error toast.
class _NotifyingContentSource implements RepoContentSource {
  _NotifyingContentSource(this.inner, this.onError);
  final RepoContentSource inner;
  final void Function(Object) onError;
  bool reported = false;
  Future<T> guard<T>(Future<T> Function() read) async {
    try {
      return await read();
    } catch (error) {
      if (!reported) {
        reported = true;
        onError(error);
      }
      rethrow;
    }
  }

  @override
  Future<List<TreeEntry>> list(String dir) => guard(() => inner.list(dir));
  @override
  Future<BlobContent> read(String path) => guard(() => inner.read(path));
}
