// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Korean (`ko`).
class L10nKo extends L10n {
  L10nKo([String locale = 'ko']) : super(locale);

  @override
  String get appName => 'GitHub+';

  @override
  String get libraryTitle => '라이브러리';

  @override
  String get libraryFilter => '저장소 검색  (Ctrl+P)';

  @override
  String get libraryEmpty => '아직 저장소가 없습니다.';

  @override
  String get libraryAdd => '저장소 추가';

  @override
  String get groupLocal => '로컬';

  @override
  String get groupHub => '허브';

  @override
  String get groupGithub => 'GitHub';

  @override
  String get repoMissing => '찾을 수 없음';

  @override
  String repoChanges(int count) {
    return '변경 $count';
  }

  @override
  String get addExisting => '로컬 저장소 추가…';

  @override
  String get addCreate => '새 저장소 만들기…';

  @override
  String addClone(String clone) {
    return '저장소 $clone…';
  }

  @override
  String get pickRepositoryFolder => '저장소 폴더 선택';

  @override
  String notARepository(String path) {
    return '$path은(는) Git 저장소가 아닙니다.';
  }

  @override
  String get welcomeTitle => 'GitHub+에 오신 것을 환영합니다';

  @override
  String get welcomeBody =>
      '내부망 허브와 한눈에 보이는 상태 표시를 갖춘 가벼운 Git 클라이언트입니다. 시작하려면 저장소를 추가하세요.';

  @override
  String get questFirstTitle => '첫 퀘스트';

  @override
  String get questAddRepo => '저장소 추가하기';

  @override
  String questFirstCommit(String commit) {
    return '첫 $commit';
  }

  @override
  String questFirstPush(String remote, String push) {
    return '$remote에 첫 $push';
  }

  @override
  String branchLabel(String branch) {
    return '$branch';
  }

  @override
  String detachedHead(String sha) {
    return '분리된 HEAD $sha';
  }

  @override
  String noBranch(String branch) {
    return '$branch 없음';
  }

  @override
  String actionCommit(String commit) {
    return '$commit';
  }

  @override
  String actionPush(String push, int count) {
    return '$push $count';
  }

  @override
  String actionPull(String pull, int count) {
    return '$pull $count';
  }

  @override
  String actionPublish(String publish) {
    return '$publish';
  }

  @override
  String actionFetch(String fetch) {
    return '$fetch';
  }

  @override
  String actionResolve(String conflict) {
    return '$conflict 해결';
  }

  @override
  String lastFetched(String fetch, String time) {
    return '마지막 $fetch $time';
  }

  @override
  String neverFetched(String fetch) {
    return '아직 $fetch 안 함';
  }

  @override
  String hudChanges(String changes) {
    return '$changes';
  }

  @override
  String hudToPush(String push) {
    return '$push 대기';
  }

  @override
  String hudToPull(String pull) {
    return '$pull 대기';
  }

  @override
  String hudStashes(String stash) {
    return '$stash';
  }

  @override
  String hudConflicts(String conflict) {
    return '$conflict';
  }

  @override
  String get hudHub => '허브';

  @override
  String get hudHubOnline => '연결됨';

  @override
  String get hudHubOffline => '끊김';

  @override
  String get hudHubNone => '없음';

  @override
  String hudChangesTip(String commit) {
    return '아직 $commit하지 않은 바뀐 파일 수';
  }

  @override
  String hudToPushTip(String remote, String push, String commitUnit) {
    return '이 PC에만 있고 아직 $remote에 $push하지 않은 $commitUnit 수';
  }

  @override
  String hudToPullTip(String remote, String pull, String commitUnit) {
    return '$remote에 새로 올라왔고 아직 $pull하지 않은 $commitUnit 수';
  }

  @override
  String goalPush(String push) {
    return '$push 대기 목표';
  }

  @override
  String goalDailyCommits(String commitUnit) {
    return '오늘의 $commitUnit';
  }

  @override
  String get goalReached => '목표 달성!';

  @override
  String goalRemaining(int count) {
    return '목표까지 $count';
  }

  @override
  String tabChanges(String changes) {
    return '$changes';
  }

  @override
  String tabHistory(String history) {
    return '$history';
  }

  @override
  String get tabExpeditions => '작업 현황';

  @override
  String get expeditionsTitle => '작업 현황';

  @override
  String expeditionsEmpty(String push, String pull, String clone) {
    return '진행 중인 작업이 없습니다. $push·$pull·$clone처럼 시간이 걸리는 작업이 여기에 표시됩니다.';
  }

  @override
  String get expeditionRunning => '진행 중';

  @override
  String get expeditionDone => '완료';

  @override
  String get expeditionFailed => '실패';

  @override
  String get expeditionCollect => '결과 보기';

  @override
  String get expeditionDismiss => '닫기';

  @override
  String expeditionElapsed(String time) {
    return '경과 $time';
  }

  @override
  String expeditionRemaining(String time) {
    return '남은 시간 약 $time';
  }

  @override
  String expeditionTo(String destination) {
    return '대상: $destination';
  }

  @override
  String get settingsTitle => '환경설정';

  @override
  String get settingsLanguage => '언어 / Language';

  @override
  String get settingsTheme => '테마';

  @override
  String get themeDark => '다크';

  @override
  String get themeLight => '라이트';

  @override
  String get themeSystem => '시스템 설정';

  @override
  String get settingsGoals => '목표 바';

  @override
  String settingsDailyGoal(String commitUnit) {
    return '하루 $commitUnit 목표';
  }

  @override
  String settingsPushGoal(String push) {
    return '$push 대기 목표';
  }

  @override
  String get settingsReduceMotion => '애니메이션 줄이기';

  @override
  String get commonCancel => '취소';

  @override
  String get commonClose => '닫기';

  @override
  String get commonOk => '확인';

  @override
  String get commonRetry => '다시 시도';

  @override
  String get commonLoading => '불러오는 중…';

  @override
  String get commonDetails => '자세히';

  @override
  String get windowMinimize => '최소화';

  @override
  String get windowMaximize => '최대화';

  @override
  String get windowClose => '닫기';

  @override
  String get openSettings => '환경설정';

  @override
  String hudStashesTip(String stash) {
    return '$stash로 잠시 치워 둔 작업 수';
  }

  @override
  String get hudConflictsTip => '두 작업이 같은 곳을 고쳐서 직접 골라야 하는 파일 수 — 충돌(Conflict)';

  @override
  String jobPull(String name, String pull) {
    return '$name에서 $pull';
  }

  @override
  String jobPush(String name, String push) {
    return '$name에 $push';
  }

  @override
  String jobPublish(String name, String publish) {
    return '$name $publish';
  }

  @override
  String jobFetch(String name, String fetch) {
    return '$name $fetch';
  }

  @override
  String resultSent(String commitUnit, int count, String push) {
    return '$commitUnit $count개 $push 완료';
  }

  @override
  String resultReceived(String commitUnit, int count) {
    return '새 $commitUnit $count개 받음';
  }

  @override
  String get resultUpToDate => '이미 최신 상태입니다';

  @override
  String get settingsTerms => '용어 표시';

  @override
  String get termPlain => '쉬운 말 (Git이 처음인 분)';

  @override
  String get termGit => 'Git 용어 (GitHub 사용자)';

  @override
  String termExample(String plain, String git) {
    return '예: $plain  ↔  $git';
  }

  @override
  String gitTermHint(String term) {
    return 'Git 용어: $term';
  }
}
