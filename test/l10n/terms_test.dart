import 'package:flutter_test/flutter_test.dart';
import 'package:github_plus/core/models/app_models.dart';
import 'package:github_plus/l10n/app_localizations_ko.dart';
import 'package:github_plus/l10n/terms.dart';

void main() {
  test('Korean plain and Git vocabularies differ where it matters', () {
    final plain = Terms.resolve(AppLanguage.ko, TermStyle.plain);
    final git = Terms.resolve(AppLanguage.ko, TermStyle.git);
    expect((plain.push, git.push), ('업로드', '푸시'));
    expect((plain.pull, git.pull), ('다운로드', '풀'));
    expect((plain.commit, git.commit), ('버전 저장', '커밋'));
    expect((plain.branch, git.branch), ('작업 갈래', '브랜치'));
    expect(plain.isPlain, isTrue);
    expect(git.isPlain, isFalse);
  });

  test('sentences take the active terms', () {
    final l = L10nKo();
    final plain = Terms.resolve(AppLanguage.ko, TermStyle.plain);
    final git = Terms.resolve(AppLanguage.ko, TermStyle.git);
    expect(l.actionPush(plain.push, 3), '업로드 3');
    expect(l.actionPush(git.push, 3), '푸시 3');
    expect(l.resultSent(plain.commitUnit, 4, plain.push), '버전 4개 업로드 완료');
    expect(l.resultSent(git.commitUnit, 4, git.push), '커밋 4개 푸시 완료');
  });

  test('tooltips name the Git term with the English original', () {
    expect(Terms.gitHint(AppLanguage.ko, (t) => t.push), '푸시 (Push)');
    expect(Terms.gitHint(AppLanguage.en, (t) => t.push), 'Push');
  });

  test('the term style is saved with the settings', () {
    final restored = AppSettings.fromJson(const AppSettings(termStyle: TermStyle.git).toJson());
    expect(restored.termStyle, TermStyle.git);
    expect(AppSettings.fromJson({'termStyle': 'bogus'}).termStyle, TermStyle.plain);
  });
}
