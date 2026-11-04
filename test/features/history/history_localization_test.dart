import 'package:flutter_test/flutter_test.dart';
import 'package:github_plus/core/models/app_models.dart';
import 'package:github_plus/features/history/history_view.dart';
import 'package:github_plus/l10n/app_localizations.dart';
import 'history_test_support.dart';

void main() {
  for (final style in TermStyle.values) {
    testWidgets('Korean $style empty history uses the selected vocabulary', (tester) async {
      final fixture = (await tester.runAsync(HistoryFixture.create))!;
      addTearDown(fixture.repos.dispose);
      drainGitOnTearDown(tester, fixture);
      await tester.pumpWidget(
        fixture.app(
          HistoryView(repo: fixture.repo),
          language: AppLanguage.ko,
          terms: style,
        ),
      );
      final context = tester.element(find.byType(HistoryView));
      final empty = L10n.of(context).historyEmpty(style == TermStyle.plain ? '\uBC84\uC804' : '\uCEE4\uBC0B');
      await pumpUntil(tester, () => find.text(empty).evaluate().isNotEmpty);
      expect(tester.takeException(), isNull);
    });
  }
}
