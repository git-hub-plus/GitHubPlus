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
  String get addClone => '원격 저장소 내려받기(Clone)…';

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
  String get questFirstCommit => '첫 버전 저장하기(Commit)';

  @override
  String get questFirstPush => '원격 저장소에 업로드하기(Push)';

  @override
  String get branchLabel => '작업 갈래(Branch)';

  @override
  String detachedHead(String sha) {
    return '분리된 HEAD $sha';
  }

  @override
  String get noBranch => '작업 갈래 없음';

  @override
  String get actionCommit => '버전 저장(Commit)';

  @override
  String actionPush(int count) {
    return '업로드(Push) $count';
  }

  @override
  String actionPull(int count) {
    return '다운로드(Pull) $count';
  }

  @override
  String get actionPublish => '처음 올리기(Publish)';

  @override
  String get actionFetch => '변경 확인(Fetch)';

  @override
  String get actionResolve => '충돌 해결(Conflict)';

  @override
  String lastFetched(String time) {
    return '마지막 변경 확인 $time';
  }

  @override
  String get neverFetched => '아직 변경 확인 안 함';

  @override
  String get hudChanges => '바뀐 파일';

  @override
  String get hudToPush => '업로드 대기';

  @override
  String get hudToPull => '다운로드 대기';

  @override
  String get hudStashes => '임시 보관';

  @override
  String get hudConflicts => '충돌';

  @override
  String get hudHub => '허브';

  @override
  String get hudHubOnline => '연결됨';

  @override
  String get hudHubOffline => '끊김';

  @override
  String get hudHubNone => '없음';

  @override
  String get hudChangesTip => '아직 버전으로 저장(Commit)하지 않은 바뀐 파일 수';

  @override
  String get hudToPushTip => '이 PC에만 저장돼 있고 아직 원격 저장소에 업로드(Push)하지 않은 버전 수';

  @override
  String get hudToPullTip => '원격 저장소에 새로 올라왔고 아직 다운로드(Pull)하지 않은 버전 수';

  @override
  String get goalPush => '업로드 대기 목표';

  @override
  String get goalDailyCommits => '오늘 저장한 버전';

  @override
  String get goalReached => '목표 달성!';

  @override
  String goalRemaining(int count) {
    return '목표까지 $count';
  }

  @override
  String get tabChanges => '바뀐 파일';

  @override
  String get tabHistory => '버전 기록(History)';

  @override
  String get tabExpeditions => '작업 현황';

  @override
  String get expeditionsTitle => '작업 현황';

  @override
  String get expeditionsEmpty =>
      '진행 중인 작업이 없습니다. 업로드(Push)·다운로드(Pull)·내려받기(Clone)처럼 시간이 걸리는 작업이 여기에 표시됩니다.';

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
  String get settingsDailyGoal => '하루 버전 저장 목표';

  @override
  String get settingsPushGoal => '업로드 대기 목표';

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
  String get hudStashesTip => '잠시 치워 둔 작업 수 — 임시 보관(Stash)';

  @override
  String get hudConflictsTip => '두 작업이 같은 곳을 고쳐서 직접 골라야 하는 파일 수 — 충돌(Conflict)';

  @override
  String jobPull(String remote) {
    return '$remote에서 다운로드(Pull)';
  }

  @override
  String jobPush(String remote) {
    return '$remote에 업로드(Push)';
  }

  @override
  String jobPublish(String branch) {
    return '$branch 처음 올리기(Publish)';
  }

  @override
  String jobFetch(String remote) {
    return '$remote 변경 확인(Fetch)';
  }

  @override
  String resultSent(int count) {
    return '버전 $count개 업로드 완료';
  }

  @override
  String resultReceived(int count) {
    return '새 버전 $count개 다운로드 완료';
  }

  @override
  String get resultUpToDate => '이미 최신 상태입니다';
}
