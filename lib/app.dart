import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/models/app_models.dart';
import 'features/shell/launcher_shell.dart';
import 'l10n/app_localizations.dart';
import 'l10n/terms.dart';
import 'state/app_state.dart';
import 'ui/theme.dart';

class GitHubPlusApp extends ConsumerWidget {
  const GitHubPlusApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    return MaterialApp(
      title: 'GitHub+',
      debugShowCheckedModeBanner: false,
      locale: Locale(settings.language.name),
      supportedLocales: L10n.supportedLocales,
      localizationsDelegates: const [
        L10n.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      theme: buildTheme(Brightness.light),
      darkTheme: buildTheme(Brightness.dark),
      themeMode: switch (settings.theme) {
        ThemePreference.dark => ThemeMode.dark,
        ThemePreference.light => ThemeMode.light,
        ThemePreference.system => ThemeMode.system,
      },
      // The app setting adds to the OS "reduce animations" preference.
      builder: (context, child) {
        final media = MediaQuery.of(context);
        return MediaQuery(
          data: media.copyWith(disableAnimations: media.disableAnimations || settings.reduceMotion),
          child: TermsScope(
            terms: Terms.resolve(settings.language, settings.termStyle),
            language: settings.language,
            child: child!,
          ),
        );
      },
      home: const LauncherShell(),
    );
  }
}
