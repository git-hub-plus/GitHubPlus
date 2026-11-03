import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models/app_models.dart';
import '../../l10n/app_localizations.dart';
import '../../l10n/terms.dart';
import '../../state/app_state.dart';
import '../../ui/theme.dart';

Future<void> showSettingsDialog(BuildContext context) =>
    showDialog<void>(context: context, builder: (_) => const _SettingsDialog());

/// Language, theme, goal targets and motion apply immediately.
class _SettingsDialog extends ConsumerWidget {
  const _SettingsDialog();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final l = L10n.of(context);
    final settings = ref.watch(settingsProvider);
    final notifier = ref.read(settingsProvider.notifier);
    final t = Terms.of(context);
    final plain = Terms.resolve(settings.language, TermStyle.plain);
    final git = Terms.resolve(settings.language, TermStyle.git);

    Widget section(String title, Widget child) => Padding(
      padding: const EdgeInsets.only(bottom: Space.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: c.muted)),
          const SizedBox(height: Space.sm),
          child,
        ],
      ),
    );

    Widget goalField(int value, void Function(int) onChanged) => SizedBox(
      width: 90,
      child: TextFormField(
        initialValue: '$value',
        keyboardType: TextInputType.number,
        onChanged: (text) {
          final parsed = int.tryParse(text);
          if (parsed != null && parsed > 0 && parsed <= 1000) onChanged(parsed);
        },
      ),
    );

    return AlertDialog(
      title: Text(l.settingsTitle, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
      content: SizedBox(
        width: 440,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            section(
              l.settingsLanguage,
              SegmentedButton<AppLanguage>(
                segments: const [
                  ButtonSegment(value: AppLanguage.ko, label: Text('한국어')),
                  ButtonSegment(value: AppLanguage.en, label: Text('English')),
                ],
                selected: {settings.language},
                onSelectionChanged: (v) => notifier.update((s) => s.copyWith(language: v.first)),
              ),
            ),
            section(
              l.settingsTheme,
              SegmentedButton<ThemePreference>(
                segments: [
                  ButtonSegment(value: ThemePreference.dark, label: Text(l.themeDark)),
                  ButtonSegment(value: ThemePreference.light, label: Text(l.themeLight)),
                  ButtonSegment(value: ThemePreference.system, label: Text(l.themeSystem)),
                ],
                selected: {settings.theme},
                onSelectionChanged: (v) => notifier.update((s) => s.copyWith(theme: v.first)),
              ),
            ),
            section(
              l.settingsTerms,
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SegmentedButton<TermStyle>(
                    segments: [
                      ButtonSegment(value: TermStyle.plain, label: Text(l.termPlain)),
                      ButtonSegment(value: TermStyle.git, label: Text(l.termGit)),
                    ],
                    selected: {settings.termStyle},
                    onSelectionChanged: (v) => notifier.update((s) => s.copyWith(termStyle: v.first)),
                  ),
                  const SizedBox(height: Space.xs + 2),
                  Text(
                    [
                      l.termExample(plain.push, git.push),
                      l.termExample(plain.commit, git.commit),
                      l.termExample(plain.branch, git.branch),
                    ].join('   '),
                    style: TextStyle(fontSize: 12, color: c.muted),
                  ),
                ],
              ),
            ),
            section(
              l.settingsGoals,
              Row(
                children: [
                  Text(l.settingsDailyGoal(t.commitUnit)),
                  const SizedBox(width: Space.sm),
                  goalField(settings.dailyCommitGoal, (v) => notifier.update((s) => s.copyWith(dailyCommitGoal: v))),
                  const SizedBox(width: Space.xl),
                  Text(l.settingsPushGoal(t.push)),
                  const SizedBox(width: Space.sm),
                  goalField(settings.pushGoal, (v) => notifier.update((s) => s.copyWith(pushGoal: v))),
                ],
              ),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(l.settingsReduceMotion),
              value: settings.reduceMotion,
              onChanged: (v) => notifier.update((s) => s.copyWith(reduceMotion: v)),
            ),
          ],
        ),
      ),
      actions: [TextButton(onPressed: () => Navigator.of(context).pop(), child: Text(l.commonClose))],
    );
  }
}
