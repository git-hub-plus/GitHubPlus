import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/hub/client.dart';
import '../../../core/hub/hub_models.dart';
import '../../../l10n/app_localizations.dart';
import '../../../state/hub_client_state.dart';
import '../../../ui/theme.dart';
import '../../../ui/widgets/feedback.dart';

String hubClientError(L10n l, Object error) {
  if (error is HubApiException) {
    if (error.statusCode == 409) return l.hubClientConflict;
    if (error.message.contains('timed out')) return l.hubClientTimeout;
    if (error.statusCode == 0) return l.hubClientUnavailable;
  }
  if (error is ArgumentError || error is FormatException) return l.hubClientInvalidAddress;
  return l.hubClientFailed;
}

Future<DiscoveredHub?> showAddHubDialog(BuildContext context) =>
    showDialog<DiscoveredHub>(context: context, builder: (_) => const _AddHubDialog());

class _AddHubDialog extends ConsumerStatefulWidget {
  const _AddHubDialog();
  @override
  ConsumerState<_AddHubDialog> createState() => _AddHubDialogState();
}

class _AddHubDialogState extends ConsumerState<_AddHubDialog> {
  final address = TextEditingController();
  bool busy = false;
  @override
  void dispose() {
    address.dispose();
    super.dispose();
  }

  Future<void> connect() async {
    final l = L10n.of(context);
    setState(() => busy = true);
    try {
      final hub = await ref.read(hubDiscoveryProvider).addManual(address.text.trim());
      if (mounted) Navigator.pop(context, hub);
    } catch (e) {
      if (mounted) showGhpToast(context, hubClientError(l, e), tone: ToastTone.error);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = L10n.of(context);
    return AlertDialog(
      title: Text(l.hubClientAdd),
      content: SizedBox(
        width: 400,
        child: TextField(
          key: const Key('hub-address'),
          controller: address,
          autofocus: true,
          enabled: !busy,
          decoration: InputDecoration(labelText: l.hubClientAddress, hintText: l.hubClientAddressHint),
          onSubmitted: (_) {
            if (!busy) connect();
          },
        ),
      ),
      actions: [
        TextButton(onPressed: busy ? null : () => Navigator.pop(context), child: Text(l.hubClientCancel)),
        FilledButton(onPressed: busy ? null : connect, child: Text(l.hubClientConnect)),
      ],
    );
  }
}

class HubLibrarySection extends ConsumerWidget {
  const HubLibrarySection({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = L10n.of(context);
    final c = context.colors;
    final hubs = ref.watch(discoveredHubsProvider);
    final selected = ref.watch(selectedHubProvider);
    return Material(
      color: c.surface,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.all(Space.md),
            child: Text(
              l.hubClientTitle,
              style: TextStyle(color: c.muted, fontWeight: FontWeight.w700),
            ),
          ),
          if (hubs.hasError) Padding(padding: const EdgeInsets.all(Space.md), child: Text(l.hubClientUnavailable)),
          if (hubs.value?.isEmpty ?? true)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: Space.md),
              child: Text(l.hubClientNone, style: TextStyle(color: c.muted, fontSize: 12)),
            ),
          for (final hub in hubs.value ?? <DiscoveredHub>[])
            ListTile(
              dense: true,
              selected: selected?.url == hub.url,
              leading: Tooltip(
                message: hub.online ? l.hubClientOnline : l.hubClientOffline,
                child: Icon(Icons.circle, size: 10, color: hub.online ? c.success : c.muted),
              ),
              title: Text(hub.name, maxLines: 1, overflow: TextOverflow.ellipsis),
              subtitle: Text(hub.url, maxLines: 1, overflow: TextOverflow.ellipsis),
              onTap: () => ref.read(selectedHubProvider.notifier).select(hub),
            ),
          TextButton.icon(
            icon: const Icon(Icons.add_rounded),
            label: Text(l.hubClientAdd),
            onPressed: () async {
              final hub = await showAddHubDialog(context);
              if (hub != null && ref.context.mounted) ref.read(selectedHubProvider.notifier).select(hub);
            },
          ),
        ],
      ),
    );
  }
}
