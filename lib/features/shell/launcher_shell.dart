import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/app_localizations.dart';
import '../../state/app_state.dart';
import '../../ui/theme.dart';
import '../home/repo_home.dart';
import '../library/library_panel.dart';
import '../settings/settings_dialog.dart';
import '../welcome/welcome_view.dart';
import '../hub/host/hub_host_view.dart';
import '../../state/hub_host_state.dart';
import 'title_bar.dart';

/// Window layout: title bar, library on the left, selected repository on the right.
class LauncherShell extends ConsumerStatefulWidget {
  const LauncherShell({super.key});

  @override
  ConsumerState<LauncherShell> createState() => _LauncherShellState();
}

class _LauncherShellState extends ConsumerState<LauncherShell> {
  final _searchFocus = FocusNode();

  @override
  void initState() {
    super.initState();
    ref.read(hubStartupProvider);
  }

  @override
  void dispose() {
    _searchFocus.dispose();
    super.dispose();
  }

  Future<void> _addRepository() => addExistingRepository(context, ref);

  @override
  Widget build(BuildContext context) {
    final l = L10n.of(context);
    final library = ref.watch(libraryProvider);
    final selected = library.selected;

    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.keyP, control: true): _searchFocus.requestFocus,
        const SingleActivator(LogicalKeyboardKey.comma, control: true): () => showSettingsDialog(context),
      },
      child: Focus(
        autofocus: true,
        child: Scaffold(
          body: Column(
            children: [
              GhpTitleBar(
                actions: [
                  IconButton(
                    tooltip: l.hubOpen,
                    onPressed: () => showHubHost(context, ref),
                    icon: Icon(Icons.hub_rounded, size: 18, color: context.colors.muted),
                  ),
                  IconButton(
                    tooltip: l.openSettings,
                    onPressed: () => showSettingsDialog(context),
                    icon: Icon(Icons.settings_rounded, size: 18, color: context.colors.muted),
                  ),
                ],
              ),
              Expanded(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    LibraryPanel(searchFocus: _searchFocus),
                    Expanded(
                      child: AnimatedSwitcher(
                        duration: context.motion(Motion.normal),
                        child:
                            hubClientScreen(ref) ??
                            (selected == null
                                ? WelcomeView(key: const ValueKey('welcome'), onAddRepository: _addRepository)
                                : RepoHome(key: ValueKey(selected.id), repo: selected)),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
