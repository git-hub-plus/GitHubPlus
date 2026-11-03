import 'package:flutter/widgets.dart';

import '../core/models/app_models.dart';

/// Git vocabulary in two registers (see docs/GLOSSARY.md):
/// - [TermStyle.git]: the words GitHub users already know (커밋, 푸시…).
/// - [TermStyle.plain]: everyday words for people new to Git (버전 저장, 업로드…).
/// Sentences live in the ARB files with `{term}` placeholders filled from here.
class Terms {
  const Terms({
    required this.style,
    required this.commit,
    required this.commitUnit,
    required this.push,
    required this.pull,
    required this.fetch,
    required this.publish,
    required this.clone,
    required this.branch,
    required this.merge,
    required this.conflict,
    required this.stash,
    required this.remote,
    required this.history,
    required this.changes,
    required this.rebase,
    required this.cherryPick,
    required this.squash,
    required this.tag,
    required this.revert,
    required this.amend,
  });

  final TermStyle style;

  /// Action: 버전 저장 / 커밋.
  final String commit;

  /// Countable unit: 버전 / 커밋.
  final String commitUnit;
  final String push;
  final String pull;
  final String fetch;
  final String publish;
  final String clone;
  final String branch;
  final String merge;
  final String conflict;
  final String stash;
  final String remote;
  final String history;
  final String changes;
  final String rebase;
  final String cherryPick;
  final String squash;
  final String tag;
  final String revert;
  final String amend;

  bool get isPlain => style == TermStyle.plain;

  static const _koGit = Terms(
    style: TermStyle.git,
    commit: '커밋',
    commitUnit: '커밋',
    push: '푸시',
    pull: '풀',
    fetch: '페치',
    publish: '게시',
    clone: '클론',
    branch: '브랜치',
    merge: '병합',
    conflict: '충돌',
    stash: '스태시',
    remote: '리모트',
    history: '히스토리',
    changes: '변경 사항',
    rebase: '리베이스',
    cherryPick: '체리픽',
    squash: '스쿼시',
    tag: '태그',
    revert: '리버트',
    amend: '커밋 수정(amend)',
  );

  static const _koPlain = Terms(
    style: TermStyle.plain,
    commit: '버전 저장',
    commitUnit: '버전',
    push: '업로드',
    pull: '다운로드',
    fetch: '변경 확인',
    publish: '처음 올리기',
    clone: '내려받기',
    branch: '작업 갈래',
    merge: '합치기',
    conflict: '충돌',
    stash: '임시 보관',
    remote: '원격 저장소',
    history: '버전 기록',
    changes: '바뀐 파일',
    rebase: '기준 옮기기',
    cherryPick: '골라 가져오기',
    squash: '하나로 합치기',
    tag: '꼬리표',
    revert: '되돌리기',
    amend: '마지막 버전 고치기',
  );

  static const _enGit = Terms(
    style: TermStyle.git,
    commit: 'Commit',
    commitUnit: 'commits',
    push: 'Push',
    pull: 'Pull',
    fetch: 'Fetch',
    publish: 'Publish',
    clone: 'Clone',
    branch: 'Branch',
    merge: 'Merge',
    conflict: 'Conflict',
    stash: 'Stash',
    remote: 'remote',
    history: 'History',
    changes: 'Changes',
    rebase: 'Rebase',
    cherryPick: 'Cherry-pick',
    squash: 'Squash',
    tag: 'Tag',
    revert: 'Revert',
    amend: 'Amend',
  );

  static const _enPlain = Terms(
    style: TermStyle.plain,
    commit: 'Save version',
    commitUnit: 'versions',
    push: 'Upload',
    pull: 'Download',
    fetch: 'Check for updates',
    publish: 'Publish',
    clone: 'Download repository',
    branch: 'Branch',
    merge: 'Combine',
    conflict: 'Conflict',
    stash: 'Set aside',
    remote: 'server',
    history: 'Version history',
    changes: 'Changed files',
    rebase: 'Move base',
    cherryPick: 'Pick changes',
    squash: 'Combine versions',
    tag: 'Label',
    revert: 'Undo changes',
    amend: 'Edit last version',
  );

  static Terms resolve(AppLanguage language, TermStyle style) => switch ((language, style)) {
    (AppLanguage.ko, TermStyle.git) => _koGit,
    (AppLanguage.ko, TermStyle.plain) => _koPlain,
    (AppLanguage.en, TermStyle.git) => _enGit,
    (AppLanguage.en, TermStyle.plain) => _enPlain,
  };

  /// The Git name to show next to a plain word (tooltips): "푸시 (Push)".
  static String gitHint(AppLanguage language, String Function(Terms t) pick) {
    final git = pick(resolve(language, TermStyle.git));
    final en = pick(_enGit);
    return language == AppLanguage.ko ? '$git ($en)' : en;
  }

  static Terms of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<TermsScope>()?.terms ?? _koPlain;
}

/// Provides the active [Terms] below the app (set from settings).
class TermsScope extends InheritedWidget {
  const TermsScope({super.key, required this.terms, required this.language, required super.child});

  final Terms terms;
  final AppLanguage language;

  @override
  bool updateShouldNotify(TermsScope oldWidget) => terms != oldWidget.terms;
}
