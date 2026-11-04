// EXTENSION POINT (owner: worker H3b). Public signature is fixed.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/expeditions/expedition.dart';
import '../../../core/hub/client.dart';
import '../../../core/hub/validation.dart';
import '../../../core/models/app_models.dart';
import '../../../l10n/app_localizations.dart';
import '../../../state/app_state.dart';
import '../../../state/hub_client_state.dart';
import '../../../state/repo_state.dart';
import '../../../ui/theme.dart';
import '../../../ui/widgets/feedback.dart';
import '../../expeditions/expedition_panel.dart';
import 'hub_library_section.dart';

Future<void> showPublishToHubDialog(BuildContext context, WidgetRef ref, RepositoryInfo repo) async {
  await showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (_) => _PublishDialog(repo: repo),
  );
}

class _PublishDialog extends ConsumerStatefulWidget {
  const _PublishDialog({required this.repo});
  final RepositoryInfo repo;
  @override
  ConsumerState<_PublishDialog> createState() => _PublishDialogState();
}

class _PublishDialogState extends ConsumerState<_PublishDialog> {
  late final name = TextEditingController(text: widget.repo.name);
  final address = TextEditingController();
  final description = TextEditingController();
  final form = GlobalKey<FormState>();
  String? selectedUrl;
  bool busy = false;
  @override
  void dispose() {
    name.dispose();
    address.dispose();
    description.dispose();
    super.dispose();
  }

  Future<void> publish() async {
    if (!form.currentState!.validate()) return;
    final l = L10n.of(context);
    final discovery = ref.read(hubDiscoveryProvider);
    final bootstrap = ref.read(bootstrapProvider);
    final library = ref.read(libraryProvider.notifier);
    final expeditions = ref.read(expeditionsProvider.notifier);
    final repo = widget.repo;
    final repoName = name.text.trim();
    final detail = description.text.trim();
    final input = address.text.trim().isNotEmpty ? address.text.trim() : selectedUrl!;
    setState(() => busy = true);
    String? failure;
    final result = await expeditions.run<bool>(
      kind: ExpeditionKind.hubPublish,
      title: l.hubClientPublish,
      destination: repoName,
      repoId: repo.id,
      task: (report) async {
        try {
          final hub = await discovery.addManual(input);
          final remote = await publishToHub(
            bootstrap.git,
            repo.path,
            hubUrl: hub.url,
            name: repoName,
            description: detail.isEmpty ? null : detail,
            onProgress: (v, _) => report(v, l.hubClientPublish),
          );
          final url = (await bootstrap.git.run(['remote', 'get-url', '--', remote], cwd: repo.path)).stdout.trim();
          await library.update(repo.id, (r) => r.copyWith(remoteUrl: url, group: RepositoryGroup.hub));
          if (mounted) {
            ref.invalidate(repoStatusProvider(repo.id));
            ref.invalidate(hubRepositoriesProvider(hub.url));
          }
          return true;
        } catch (e) {
          failure = hubClientError(l, e);
          throw failure!;
        }
      },
      result: (_) => l.hubClientDone,
    );
    if (!mounted) return;
    setState(() => busy = false);
    if (result == true) {
      Navigator.pop(context);
      showGhpToast(context, l.hubClientDone);
    } else {
      showGhpToast(context, failure ?? l.hubClientFailed, tone: ToastTone.error);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = L10n.of(context);
    final hubs = ref.watch(discoveredHubsProvider).value ?? [];
    return PopScope(
      canPop: !busy,
      child: AlertDialog(
        title: Text(l.hubClientPublish),
        content: SizedBox(
          width: 520,
          child: SingleChildScrollView(
            child: Form(
              key: form,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  DropdownButtonFormField<String>(
                    key: ValueKey(hubs.map((h) => h.url).join()),
                    initialValue: selectedUrl,
                    isExpanded: true,
                    decoration: InputDecoration(labelText: l.hubClientTitle),
                    items: [
                      for (final hub in hubs)
                        DropdownMenuItem(
                          value: hub.url,
                          child: Text(hub.name, overflow: TextOverflow.ellipsis),
                        ),
                    ],
                    onChanged: busy ? null : (url) => setState(() => selectedUrl = url),
                  ),
                  const SizedBox(height: Space.md),
                  TextFormField(
                    key: const Key('publish-hub-address'),
                    controller: address,
                    enabled: !busy,
                    decoration: InputDecoration(labelText: l.hubClientAddress, hintText: l.hubClientAddressHint),
                    validator: (v) => v!.trim().isEmpty && selectedUrl == null ? l.hubClientInvalidAddress : null,
                  ),
                  const SizedBox(height: Space.md),
                  TextFormField(
                    key: const Key('publish-hub-name'),
                    controller: name,
                    enabled: !busy,
                    decoration: InputDecoration(labelText: l.hubClientName),
                    validator: (v) => isValidRepositoryName(v!.trim()) ? null : l.hubClientInvalidName,
                  ),
                  const SizedBox(height: Space.md),
                  TextFormField(
                    controller: description,
                    enabled: !busy,
                    decoration: InputDecoration(labelText: l.hubClientDescription),
                  ),
                  if (busy) SizedBox(height: 220, child: ExpeditionPanel(repoId: widget.repo.id)),
                ],
              ),
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: busy ? null : () => Navigator.pop(context), child: Text(l.hubClientCancel)),
          FilledButton(
            key: const Key('publish-hub-submit'),
            onPressed: busy ? null : publish,
            child: Text(l.hubClientPublish),
          ),
        ],
      ),
    );
  }
}
