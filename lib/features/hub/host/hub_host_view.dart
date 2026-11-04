// EXTENSION POINT (owner: worker H3a). Keep showHubHost's signature.
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/expeditions/expedition.dart';
import '../../../core/git/git_runner.dart';
import '../../../core/hub/hub_models.dart';
import '../../../core/hub/validation.dart';
import '../../../l10n/app_localizations.dart';
import '../../../l10n/terms.dart';
import '../../../state/app_state.dart';
import '../../../state/hub_host_state.dart';
import '../../../ui/format.dart';
import '../../../ui/theme.dart';
import '../../../ui/widgets/feedback.dart';
import '../../../ui/widgets/hud.dart';

Future<void> showHubHost(BuildContext context, WidgetRef ref) async {
  final container = ProviderScope.containerOf(context);
  await showDialog<void>(
    context: context,
    builder: (_) => UncontrolledProviderScope(container: container, child: const HubHostView()),
  );
}

class HubHostView extends ConsumerStatefulWidget {
  const HubHostView({super.key});
  @override
  ConsumerState<HubHostView> createState() => _HubHostViewState();
}

class _HubHostViewState extends ConsumerState<HubHostView> {
  bool _busy = false;
  String? _filter;
  String? _error;

  Future<void> _run(Future<void> Function() action, {String? success}) async {
    if (_busy || !mounted) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref.read(hubHostOperationsProvider).run(action);
      if (!mounted) return;
      ref.invalidate(hubHostSnapshotProvider);
      if (success != null) showGhpToast(context, success, tone: ToastTone.success);
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = redactCredentials(error.toString()));
      showGhpToast(context, L10n.of(context).hubHostFailed, tone: ToastTone.error, detail: _error);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _copy(String address) async {
    try {
      await Clipboard.setData(ClipboardData(text: address));
      if (mounted) showGhpToast(context, L10n.of(context).hubHostCopied);
    } catch (error) {
      if (mounted) {
        showGhpToast(
          context,
          L10n.of(context).hubHostFailed,
          tone: ToastTone.error,
          detail: redactCredentials(error.toString()),
        );
      }
    }
  }

  Future<void> _create() async {
    final input = await showDialog<({String name, String description})>(
      context: context,
      builder: (_) => const _NewRepositoryDialog(),
    );
    if (input == null || !mounted) return;
    final server = ref.read(hubServerProvider);
    await _run(() async {
      await server.createRepository(input.name, description: input.description);
    }, success: L10n.of(context).hubHostCreated);
  }

  Future<void> _delete(HubRepository repository) async {
    final l = L10n.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l.hubHostDeleteTitle(repository.name)),
        content: Text(l.hubHostTrashHint),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text(l.hubHostCancel)),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: Text(l.hubHostDelete)),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    final server = ref.read(hubServerProvider);
    await _run(() => deleteHubRepository(server, repository.name), success: l.hubHostDeleted);
  }

  Future<void> _backup(HubSettings settings) {
    final l = L10n.of(context);
    final server = ref.read(hubServerProvider);
    final expeditions = ref.read(expeditionsProvider.notifier);
    return _run(() async {
      final result = await expeditions.run(
        kind: ExpeditionKind.backup,
        title: l.hubHostBackup,
        destination: settings.backupDirectory!,
        task: (_) async {
          try {
            return await server.backupNow();
          } catch (error) {
            throw StateError(redactCredentials(error.toString()));
          }
        },
        result: (value) => l.hubHostBackupDone(value.repositories),
      );
      if (!mounted) return;
      showGhpToast(
        context,
        result == null ? l.hubHostFailed : l.hubHostBackupDone(result.repositories),
        tone: result == null ? ToastTone.error : ToastTone.success,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final l = L10n.of(context);
    final t = Terms.of(context);
    final c = context.colors;
    final settings = ref.watch(hubSettingsProvider);
    final settingsNotifier = ref.read(hubSettingsProvider.notifier);
    final status = ref.watch(hubStatusProvider).value ?? ref.watch(hubServerProvider).status;
    final snapshot = ref.watch(hubHostSnapshotProvider);
    final data = snapshot.value;
    final enabled = settings.value;
    final color = status.error != null
        ? c.danger
        : status.running
        ? c.success
        : c.muted;
    final stateLabel = status.error != null
        ? l.hubHostError
        : status.running
        ? l.hubHostRunning
        : l.hubHostStopped;
    final filters = <String>{...?(data?.repositories.map((r) => r.name)), ...?(data?.pushes.map((r) => r.repository))};
    final filter = filters.contains(_filter) ? _filter : null;
    final records = data?.pushes.where((r) => filter == null || r.repository == filter).take(100).toList() ?? [];

    Widget heading(String text) => Padding(
      padding: const EdgeInsets.only(top: Space.xl, bottom: Space.md),
      child: Text(text, style: Theme.of(context).textTheme.titleMedium),
    );

    return Dialog(
      insetPadding: const EdgeInsets.all(Space.xl),
      child: SizedBox(
        width: 1060,
        height: MediaQuery.sizeOf(context).height * .9,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(Space.lg),
              child: Row(
                children: [
                  Icon(Icons.dns_rounded, color: c.accent),
                  const SizedBox(width: Space.md),
                  Expanded(child: Text(l.hubHostTitle, style: Theme.of(context).textTheme.titleLarge)),
                  IconButton(
                    tooltip: l.hubHostClose,
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
            ),
            const Divider(height: Space.xs),
            if (_busy) const LinearProgressIndicator(),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(Space.xl),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(Space.lg),
                      decoration: BoxDecoration(
                        color: c.raised,
                        borderRadius: BorderRadius.circular(Radii.lg),
                        border: Border.all(color: c.border),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            children: [
                              AnimatedContainer(
                                duration: context.motion(Motion.normal),
                                width: Space.md,
                                height: Space.md,
                                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                              ),
                              const SizedBox(width: Space.sm),
                              Expanded(
                                child: Text(
                                  stateLabel,
                                  style: TextStyle(color: color, fontWeight: FontWeight.w700),
                                ),
                              ),
                              Semantics(
                                label: l.hubHostPower,
                                child: Switch(
                                  key: const Key('hub-host-power'),
                                  value: enabled?.enabled ?? status.running,
                                  onChanged: _busy || enabled == null
                                      ? null
                                      : (value) => _run(() => settingsNotifier.save((s) => s.copyWith(enabled: value))),
                                ),
                              ),
                            ],
                          ),
                          Text(enabled?.name ?? l.hubHostTitle, style: Theme.of(context).textTheme.headlineSmall),
                          const SizedBox(height: Space.xs),
                          Text(l.hubHostSubtitle, style: TextStyle(color: c.muted)),
                          const SizedBox(height: Space.md),
                          Text('${l.hubHostPort}: ${status.running ? status.port : enabled?.port ?? '—'}'),
                          if (status.error != null)
                            Padding(
                              padding: const EdgeInsets.only(top: Space.sm),
                              child: SelectableText(
                                redactCredentials(status.error!),
                                style: TextStyle(color: c.danger),
                              ),
                            ),
                          const SizedBox(height: Space.lg),
                          Text(l.hubHostAddresses, style: const TextStyle(fontWeight: FontWeight.w600)),
                          if (!status.running)
                            Padding(
                              padding: const EdgeInsets.only(top: Space.sm),
                              child: Text(l.hubHostStartHint),
                            ),
                          for (final (i, address) in status.addresses.indexed)
                            Padding(
                              padding: const EdgeInsets.only(top: Space.sm),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        if (i == 0)
                                          Text(
                                            l.hubHostConnectHint,
                                            style: TextStyle(color: c.accent, fontWeight: FontWeight.w600),
                                          ),
                                        SelectableText(address, style: TextStyle(color: i == 0 ? c.text : c.muted)),
                                      ],
                                    ),
                                  ),
                                  IconButton(
                                    tooltip: l.hubHostCopy,
                                    onPressed: () => _copy(address),
                                    icon: const Icon(Icons.copy_rounded),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: Space.md),
                    Row(
                      children: [
                        Expanded(
                          child: HudStat(
                            icon: Icons.folder_rounded,
                            label: l.hubHostRepositories,
                            value: status.repositoryCount,
                            tone: HudTone.accent,
                          ),
                        ),
                        const SizedBox(width: Space.md),
                        Expanded(
                          child: HudStat(
                            icon: Icons.upload_rounded,
                            label: l.hubHostToday(t.push),
                            value: data?.todayPushes ?? 0,
                            tone: HudTone.good,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: Space.lg),
                    Container(
                      padding: const EdgeInsets.all(Space.md),
                      decoration: BoxDecoration(
                        color: c.success.withValues(alpha: .10),
                        borderRadius: BorderRadius.circular(Radii.sm),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(Icons.shield_outlined, color: c.success),
                          const SizedBox(width: Space.sm),
                          Expanded(child: Text(l.hubHostProtection(t.push, t.branch, t.commitUnit))),
                        ],
                      ),
                    ),
                    if (_error != null)
                      Padding(
                        padding: const EdgeInsets.only(top: Space.md),
                        child: SelectableText(_error!, style: TextStyle(color: c.danger)),
                      ),
                    heading(l.hubHostSettings),
                    settings.when(
                      data: (value) => _HubSettingsForm(
                        settings: value,
                        busy: _busy,
                        onSave: (value) => _run(() => settingsNotifier.save((_) => value), success: l.hubHostSaved),
                      ),
                      loading: () => const LinearProgressIndicator(),
                      error: (error, _) => Text(l.hubHostFailed, style: TextStyle(color: c.danger)),
                    ),
                    heading(l.hubHostRepositories),
                    Wrap(
                      spacing: Space.md,
                      runSpacing: Space.sm,
                      children: [
                        FilledButton.icon(
                          key: const Key('hub-host-new'),
                          onPressed: _busy || !status.running ? null : _create,
                          icon: const Icon(Icons.add),
                          label: Text(l.hubHostNewRepository),
                        ),
                        OutlinedButton.icon(
                          onPressed: _busy || !status.running ? null : () => ref.invalidate(hubHostSnapshotProvider),
                          icon: const Icon(Icons.refresh),
                          label: Text(l.hubHostRefresh),
                        ),
                        OutlinedButton.icon(
                          key: const Key('hub-host-backup'),
                          onPressed:
                              _busy ||
                                  !status.running ||
                                  enabled?.backupDirectory == null ||
                                  enabled!.backupDirectory!.isEmpty
                              ? null
                              : () => _backup(enabled),
                          icon: const Icon(Icons.backup_outlined),
                          label: Text(l.hubHostBackup),
                        ),
                      ],
                    ),
                    if (enabled?.backupDirectory == null || enabled!.backupDirectory!.isEmpty || !status.running)
                      Padding(
                        padding: const EdgeInsets.only(top: Space.sm),
                        child: Text(l.hubHostBackupHint, style: TextStyle(color: c.muted)),
                      ),
                    if (snapshot.isLoading) const LinearProgressIndicator(),
                    if (snapshot.hasError)
                      Padding(
                        padding: const EdgeInsets.only(top: Space.md),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(l.hubHostFailed, style: TextStyle(color: c.danger)),
                            SelectableText(redactCredentials(snapshot.error.toString())),
                            TextButton(
                              onPressed: () => ref.invalidate(hubHostSnapshotProvider),
                              child: Text(l.hubHostRetry),
                            ),
                          ],
                        ),
                      ),
                    if (status.running && data != null && data.repositories.isEmpty)
                      Padding(padding: const EdgeInsets.all(Space.lg), child: Text(l.hubHostNoRepositories)),
                    for (final repository in data?.repositories ?? <HubRepository>[])
                      Padding(
                        key: ValueKey('hub-repository-${repository.name}'),
                        padding: const EdgeInsets.only(top: Space.md),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Row(
                              children: [
                                Expanded(child: Text(repository.name, style: Theme.of(context).textTheme.titleMedium)),
                                IconButton(
                                  tooltip: l.hubHostClone(t.clone),
                                  onPressed: () => _copy(repository.url),
                                  icon: const Icon(Icons.copy),
                                ),
                                IconButton(
                                  key: ValueKey('hub-delete-${repository.name}'),
                                  tooltip: l.hubHostDelete,
                                  onPressed: _busy ? null : () => _delete(repository),
                                  icon: Icon(Icons.delete_outline, color: c.danger),
                                ),
                              ],
                            ),
                            if (repository.description?.isNotEmpty == true) Text(repository.description!),
                            Wrap(
                              spacing: Space.lg,
                              runSpacing: Space.xs,
                              children: [
                                Text(
                                  l.hubHostDefaultBranch(t.branch, repository.defaultBranch ?? l.hubHostNever),
                                  style: TextStyle(color: c.muted),
                                ),
                                Text(
                                  l.hubHostLastPush(
                                    t.push,
                                    repository.lastPushAt == null
                                        ? l.hubHostNever
                                        : formatAgo(context, repository.lastPushAt!),
                                  ),
                                  style: TextStyle(color: c.muted),
                                ),
                              ],
                            ),
                            const SizedBox(height: Space.md),
                            const Divider(height: Space.xs),
                          ],
                        ),
                      ),
                    heading(l.hubHostPushLog(t.push)),
                    DropdownButtonFormField<String>(
                      key: ValueKey('hub-filter-$filter'),
                      initialValue: filter ?? '',
                      decoration: InputDecoration(labelText: l.hubHostRepositories),
                      items: [
                        DropdownMenuItem(value: '', child: Text(l.hubHostAllRepositories)),
                        for (final name in filters.toList()..sort()) DropdownMenuItem(value: name, child: Text(name)),
                      ],
                      onChanged: (value) => setState(() => _filter = value == '' ? null : value),
                    ),
                    if (records.isEmpty)
                      Padding(padding: const EdgeInsets.all(Space.lg), child: Text(l.hubHostNoPushes)),
                    for (final record in records)
                      Padding(
                        key: ValueKey('hub-push-${record.repository}-${record.newSha}'),
                        padding: const EdgeInsets.symmetric(vertical: Space.md),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Wrap(
                              spacing: Space.md,
                              runSpacing: Space.xs,
                              children: [
                                Text(record.repository, style: const TextStyle(fontWeight: FontWeight.w700)),
                                Text(record.ref),
                                Tooltip(
                                  message: record.at.toLocal().toString(),
                                  child: Text(formatAgo(context, record.at)),
                                ),
                              ],
                            ),
                            const SizedBox(height: Space.xs),
                            SelectableText(
                              '${_short(record.oldSha)} → ${_short(record.newSha)}',
                              style: const TextStyle(fontFamily: 'Consolas'),
                            ),
                            Text(
                              l.hubHostSender(record.clientAddress, record.clientHost ?? l.hubHostUnknownHost),
                              style: TextStyle(color: c.muted),
                            ),
                            const SizedBox(height: Space.md),
                            const Divider(height: Space.xs),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

String _short(String sha) => sha.length > 8 ? sha.substring(0, 8) : sha;

class _HubSettingsForm extends StatefulWidget {
  const _HubSettingsForm({required this.settings, required this.busy, required this.onSave});
  final HubSettings settings;
  final bool busy;
  final Future<void> Function(HubSettings) onSave;
  @override
  State<_HubSettingsForm> createState() => _HubSettingsFormState();
}

class _HubSettingsFormState extends State<_HubSettingsForm> {
  final _form = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.settings.name);
  late final _port = TextEditingController(text: '${widget.settings.port}');
  late final _root = TextEditingController(text: widget.settings.rootDirectory);
  late final _backup = TextEditingController(text: widget.settings.backupDirectory ?? '');
  late bool _keepRunning = widget.settings.keepRunningInTray;
  bool _picking = false;

  @override
  void dispose() {
    _name.dispose();
    _port.dispose();
    _root.dispose();
    _backup.dispose();
    super.dispose();
  }

  Future<void> _pick(TextEditingController controller) async {
    setState(() => _picking = true);
    try {
      final path = await FilePicker.getDirectoryPath(
        initialDirectory: controller.text.isEmpty ? null : controller.text,
      );
      if (mounted && path != null) setState(() => controller.text = path);
    } catch (error) {
      if (mounted) {
        showGhpToast(
          context,
          L10n.of(context).hubHostFailed,
          tone: ToastTone.error,
          detail: redactCredentials(error.toString()),
        );
      }
    } finally {
      if (mounted) setState(() => _picking = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = L10n.of(context);
    final disabled = widget.busy || _picking;
    Widget folder(TextEditingController controller, String label, String key, {bool required = false}) => Padding(
      padding: const EdgeInsets.only(top: Space.md),
      child: TextFormField(
        key: Key(key),
        controller: controller,
        readOnly: true,
        enabled: !disabled,
        validator: required ? (v) => v == null || v.trim().isEmpty ? l.hubHostRequired : null : null,
        decoration: InputDecoration(
          labelText: label,
          suffixIcon: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (!required && controller.text.isNotEmpty)
                IconButton(
                  tooltip: l.hubHostClear,
                  onPressed: disabled ? null : () => setState(controller.clear),
                  icon: const Icon(Icons.clear),
                ),
              IconButton(
                tooltip: l.hubHostChoose,
                onPressed: disabled ? null : () => _pick(controller),
                icon: const Icon(Icons.folder_open),
              ),
            ],
          ),
        ),
      ),
    );
    return Form(
      key: _form,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              final fields = [
                TextFormField(
                  key: const Key('hub-host-name'),
                  controller: _name,
                  enabled: !disabled,
                  decoration: InputDecoration(labelText: l.hubHostName),
                  validator: (v) => v == null || v.trim().isEmpty ? l.hubHostRequired : null,
                ),
                TextFormField(
                  key: const Key('hub-host-port'),
                  controller: _port,
                  enabled: !disabled,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(labelText: l.hubHostPort),
                  validator: (v) {
                    final port = int.tryParse(v ?? '');
                    return port == null || port < 1024 || port > 65535 ? l.hubHostInvalidPort : null;
                  },
                ),
              ];
              return constraints.maxWidth < 520
                  ? Column(
                      children: [
                        fields[0],
                        const SizedBox(height: Space.md),
                        fields[1],
                      ],
                    )
                  : Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(flex: 3, child: fields[0]),
                        const SizedBox(width: Space.md),
                        Expanded(child: fields[1]),
                      ],
                    );
            },
          ),
          folder(_root, l.hubHostRoot, 'hub-host-root', required: true),
          folder(_backup, l.hubHostBackupFolder, 'hub-host-backup-folder'),
          const SizedBox(height: Space.sm),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(l.hubHostKeepRunning),
            subtitle: Text(l.hubHostTrayHint),
            value: _keepRunning,
            onChanged: disabled ? null : (v) => setState(() => _keepRunning = v),
          ),
          const SizedBox(height: Space.sm),
          Text(l.hubHostRestartHint, style: TextStyle(color: context.colors.muted)),
          const SizedBox(height: Space.md),
          Align(
            alignment: Alignment.centerLeft,
            child: FilledButton(
              key: const Key('hub-host-save'),
              onPressed: disabled
                  ? null
                  : () {
                      if (!_form.currentState!.validate()) return;
                      widget.onSave(
                        HubSettings(
                          enabled: widget.settings.enabled,
                          port: int.parse(_port.text),
                          name: _name.text.trim(),
                          rootDirectory: _root.text,
                          backupDirectory: _backup.text.isEmpty ? null : _backup.text,
                          keepRunningInTray: _keepRunning,
                        ),
                      );
                    },
              child: Text(l.hubHostSave),
            ),
          ),
        ],
      ),
    );
  }
}

class _NewRepositoryDialog extends StatefulWidget {
  const _NewRepositoryDialog();
  @override
  State<_NewRepositoryDialog> createState() => _NewRepositoryDialogState();
}

class _NewRepositoryDialogState extends State<_NewRepositoryDialog> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _description = TextEditingController();
  @override
  void dispose() {
    _name.dispose();
    _description.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = L10n.of(context);
    return AlertDialog(
      title: Text(l.hubHostNewRepository),
      content: SizedBox(
        width: 460,
        child: Form(
          key: _form,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                key: const Key('hub-new-name'),
                controller: _name,
                autofocus: true,
                decoration: InputDecoration(labelText: l.hubHostRepositoryName),
                validator: (value) => isValidRepositoryName(value ?? '') ? null : l.hubHostInvalidName,
              ),
              const SizedBox(height: Space.md),
              TextFormField(
                key: const Key('hub-new-description'),
                controller: _description,
                decoration: InputDecoration(labelText: l.hubHostDescription),
                maxLines: 3,
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: Text(l.hubHostCancel)),
        FilledButton(
          key: const Key('hub-new-create'),
          onPressed: () {
            if (_form.currentState!.validate()) {
              Navigator.pop(context, (name: _name.text, description: _description.text));
            }
          },
          child: Text(l.hubHostCreate),
        ),
      ],
    );
  }
}
