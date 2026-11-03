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
  String get addClone => '저장소 복제…';

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
  String get questFirstCommit => '첫 커밋 만들기';

  @override
  String get questFirstPush => '원격에 푸시하기';

  @override
  String get branchLabel => '브랜치';

  @override
  String detachedHead(String sha) {
    return '분리된 HEAD $sha';
  }

  @override
  String get noBranch => '브랜치 없음';

  @override
  String get actionCommit => '커밋하기';

  @override
  String actionPush(int count) {
    return '푸시 $count';
  }

  @override
  String actionPull(int count) {
    return '풀 $count';
  }

  @override
  String get actionPublish => '게시하기';

  @override
  String get actionFetch => '가져오기';

  @override
  String get actionResolve => '충돌 해결';

  @override
  String lastFetched(String time) {
    return '마지막 가져오기 $time';
  }

  @override
  String get neverFetched => '아직 가져오지 않음';

  @override
  String get hudChanges => '변경 파일';

  @override
  String get hudToPush => '푸시 대기';

  @override
  String get hudToPull => '풀 대기';

  @override
  String get hudStashes => '임시 저장';

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
  String get hudChangesTip => '커밋하지 않은 변경 파일 수';

  @override
  String get hudToPushTip => '이 PC에만 있고 아직 원격에 올리지 않은 커밋 수';

  @override
  String get hudToPullTip => '원격에 있고 아직 받지 않은 커밋 수';

  @override
  String get goalPush => '푸시 대기 목표';

  @override
  String get goalDailyCommits => '오늘의 커밋';

  @override
  String get goalReached => '목표 달성!';

  @override
  String goalRemaining(int count) {
    return '목표까지 $count';
  }

  @override
  String get tabChanges => '변경 사항';

  @override
  String get tabHistory => '히스토리';

  @override
  String get tabExpeditions => '파견';

  @override
  String get expeditionsTitle => '파견';

  @override
  String get expeditionsEmpty =>
      '진행 중인 파견이 없습니다. 푸시·풀·복제 같은 오래 걸리는 작업이 여기에 표시됩니다.';

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
    return '목적지: $destination';
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
  String get settingsDailyGoal => '하루 커밋 목표';

  @override
  String get settingsPushGoal => '푸시 대기 목표';

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
}
