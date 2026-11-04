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
  String get addFailed => '저장소를 추가하지 못했습니다.';

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
  String get changesSelectAll => '전체 선택';

  @override
  String changesIncluded(int total, int included) {
    return '$total개 중 $included개 포함';
  }

  @override
  String changesConflicts(int count) {
    return '충돌 $count개를 먼저 해결하세요';
  }

  @override
  String get changesAdded => '추가';

  @override
  String get changesModified => '수정';

  @override
  String get changesDeleted => '삭제';

  @override
  String get changesRenamed => '이름 변경';

  @override
  String changesConflict(String count) {
    return '충돌 · $count';
  }

  @override
  String get changesSummary => '요약 (필수)';

  @override
  String get changesDescription => '설명';

  @override
  String changesRemaining(int count) {
    return '권장 길이까지 $count자';
  }

  @override
  String changesAmend(String commit) {
    return '마지막 $commit 고치기(amend)';
  }

  @override
  String changesCommit(String branch, String commit) {
    return '$branch에 $commit';
  }

  @override
  String changesCommitted(String commit, String sha) {
    return '$commit 완료 · $sha';
  }

  @override
  String get changesDiscard => '버리기';

  @override
  String get changesDiscardFile => '이 파일 버리기';

  @override
  String get changesCopyPath => '경로 복사';

  @override
  String changesDiscardTitle(int count) {
    return '파일 $count개의 변경을 버릴까요?';
  }

  @override
  String get changesDiscardBody => '백업 폴더에 사본을 남긴 뒤 되돌립니다.';

  @override
  String get changesCancel => '취소';

  @override
  String get changesDiscarded => '변경을 버렸습니다 · 백업 폴더 열기';

  @override
  String get changesSaved => '모두 저장됨';

  @override
  String changesEmptyHint(String push, int count) {
    return '작업 현황을 확인하거나 $push 대기 $count개를 확인하세요.';
  }

  @override
  String get changesPickFile => '파일을 골라 바뀐 내용을 확인하세요.';

  @override
  String get changesFailed => '작업을 마치지 못했습니다.';

  @override
  String get changesRetry => '다시 시도';

  @override
  String get changesDetached => '현재 위치';

  @override
  String get changesResize => '파일 목록 너비 조절';

  @override
  String get changesBusy => '처리 중…';

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
  String conflictQuestTitle(String operation, String name) {
    return '$operation 진행 중 · $name';
  }

  @override
  String conflictRebaseStep(String operation, int step, int total) {
    return '$operation $step/$total 단계';
  }

  @override
  String conflictProgress(int resolved, int total) {
    return '충돌 파일 $resolved/$total개 해결';
  }

  @override
  String get conflictSteps => '① 충돌 해결 → ② 해결됨 표시 → ③ 이어서 하기';

  @override
  String conflictContinue(String operation) {
    return '$operation 이어서 하기';
  }

  @override
  String conflictAbort(String operation) {
    return '$operation 그만두기';
  }

  @override
  String get conflictAbortBody => '진행 중인 작업과 충돌 해결 내용을 취소하고 시작 전 상태로 돌아갑니다.';

  @override
  String mergeMessage(String merge) {
    return '$merge 메시지 확인';
  }

  @override
  String get conflictOurs => '내 쪽(현재)';

  @override
  String get conflictTheirs => '들어온 쪽';

  @override
  String get conflictBoth => '둘 다';

  @override
  String get conflictAllOurs => '모두 내 쪽';

  @override
  String get conflictAllTheirs => '모두 들어온 쪽';

  @override
  String get conflictSave => '저장하고 해결됨 표시';

  @override
  String get conflictSideOnly =>
      '바이너리·삭제 충돌 또는 읽을 수 없는 파일입니다. 파일 전체를 한쪽으로 선택하세요.';

  @override
  String get conflictStale => '파일이 바뀌었습니다. 다시 열어 내용을 확인하세요.';

  @override
  String mergeInto(String branch, String merge) {
    return '현재 $branch로 $merge';
  }

  @override
  String rebaseOnto(String branch, String rebase) {
    return '이 $branch 위로 $rebase';
  }

  @override
  String rebaseWarning(String rebase) {
    return '$rebase는 이미 올린 버전도 다시 쓸 수 있습니다. 함께 작업하는 사람이 있다면 먼저 확인하세요.';
  }

  @override
  String mergeConflicts(String changes) {
    return '충돌이 있습니다. $changes 탭에서 해결하세요.';
  }

  @override
  String mergeCompleted(String operation) {
    return '$operation 완료';
  }

  @override
  String get mergeNothing => '이미 최신입니다';

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

  @override
  String get tabOverview => '개요';

  @override
  String get overviewWorkingTree => '작업 폴더';

  @override
  String historyCurrent(String branch) {
    return '현재 $branch';
  }

  @override
  String historyAll(String branch) {
    return '모든 $branch';
  }

  @override
  String get historySearch => '요약·작성자 검색 (불러온 기록)';

  @override
  String historyEmpty(String commitUnit) {
    return '아직 $commitUnit이 없습니다';
  }

  @override
  String get historyNoResults => '일치하는 기록이 없습니다';

  @override
  String get historySelect => '목록에서 기록을 선택하세요';

  @override
  String historyFiles(int count) {
    return '바뀐 파일 $count개';
  }

  @override
  String get historyNoFiles => '바뀐 파일이 없습니다';

  @override
  String get historySelectFile => '파일을 선택해 바뀐 내용을 확인하세요';

  @override
  String historyParents(String commitUnit) {
    return '부모 $commitUnit';
  }

  @override
  String get historyCopySha => 'SHA 복사';

  @override
  String get historyCopied => 'SHA를 복사했습니다';

  @override
  String get historyLoadMore => '다음 200개 불러오기';

  @override
  String get historyRetry => '다시 시도';

  @override
  String get historyResize => '목록과 상세 너비 조절';

  @override
  String get historyClose => '닫기';

  @override
  String branchSearch(String branch) {
    return '$branch 검색';
  }

  @override
  String get branchCurrent => '현재';

  @override
  String branchLocal(String branch) {
    return '로컬 $branch';
  }

  @override
  String branchRemote(String branch) {
    return '원격 $branch';
  }

  @override
  String branchCreate(String branch) {
    return '새 $branch 만들기';
  }

  @override
  String branchName(String branch) {
    return '$branch 이름';
  }

  @override
  String get branchNameHint => '공백은 -로 바뀝니다';

  @override
  String get branchExists => '이미 있는 이름입니다';

  @override
  String get branchInvalid => '올바른 이름을 입력하세요';

  @override
  String get branchRename => '이름 바꾸기';

  @override
  String get branchDelete => '삭제';

  @override
  String get branchCancel => '취소';

  @override
  String get branchSave => '저장';

  @override
  String branchSwitch(String name) {
    return '$name(으)로 전환';
  }

  @override
  String branchSwitchWarning(String name) {
    return '바뀐 파일이 있습니다. $name(으)로 전환할까요? 수정 내용이 겹치면 전환할 수 없습니다.';
  }

  @override
  String get branchContinue => '전환';

  @override
  String branchDeleteConfirm(String name) {
    return '$name을(를) 삭제할까요?';
  }

  @override
  String branchForce(String merge) {
    return '아직 $merge하지 않은 내용도 삭제';
  }

  @override
  String get branchDeleteRemote => '원격에서도 삭제';

  @override
  String get branchRemoteWarning => '원격 삭제를 선택하지 않으면 이 PC의 추적 항목만 삭제합니다.';

  @override
  String get branchFailed => '작업을 완료하지 못했습니다';

  @override
  String get branchEmpty => '일치하는 항목이 없습니다';

  @override
  String branchMenu(String name) {
    return '$name 메뉴';
  }

  @override
  String branchAheadBehind(int ahead, int behind) {
    return '앞섬 $ahead · 뒤처짐 $behind';
  }

  @override
  String overviewWorkingTreeTip(String commit) {
    return '지금 폴더에 있는 그대로 보여 줍니다. 아직 $commit하지 않은 수정도 보이고, .gitignore로 숨긴 파일은 빠집니다.';
  }

  @override
  String overviewHead(String commitUnit) {
    return '마지막 $commitUnit (HEAD)';
  }

  @override
  String overviewHeadTip(String branch) {
    return '현재 $branch에 마지막으로 저장된 내용을 보여 줍니다. 다른 PC나 허브에서 보는 모습과 같습니다.';
  }

  @override
  String get overviewRefresh => '새로 고침';

  @override
  String stashTitle(String stash) {
    return '$stash';
  }

  @override
  String stashCreate(String stash) {
    return '지금 바뀐 파일 $stash';
  }

  @override
  String get stashMessage => '메시지 (선택)';

  @override
  String get stashUntracked => '새 파일 포함';

  @override
  String get stashEmpty => '보관한 항목이 없습니다.';

  @override
  String get stashPop => '꺼내기';

  @override
  String get stashApply => '적용만';

  @override
  String get stashDrop => '버리기';

  @override
  String get stashDropConfirm => '이 항목을 버릴까요? 보관한 내용은 복구할 수 없습니다.';

  @override
  String get stashSelect => '항목을 펼쳐 파일을 선택하세요.';

  @override
  String get historyActionMenu => '작업 메뉴';

  @override
  String get historyActionCancel => '취소';

  @override
  String get historyActionClose => '닫기';

  @override
  String get historyActionConfirm => '계속';

  @override
  String get historyActionDone => '작업을 완료했습니다.';

  @override
  String get historyActionNothing => '처리할 내용이 없습니다.';

  @override
  String historyActionConflicts(String changes) {
    return '충돌이 있습니다. $changes 탭에서 해결하세요.';
  }

  @override
  String get historyActionFailed => '작업에 실패했습니다.';

  @override
  String historyActionRevert(String commitUnit, String revert) {
    return '이 $commitUnit $revert';
  }

  @override
  String historyActionRevertConfirm(String commitUnit) {
    return '선택한 내용을 되돌리는 새 $commitUnit을 만들까요?';
  }

  @override
  String historyActionPick(String branch, String cherryPick) {
    return '현재 $branch로 $cherryPick';
  }

  @override
  String historyActionUndo(String commitUnit) {
    return '마지막 $commitUnit 취소';
  }

  @override
  String historyActionUndoConfirm(String commitUnit) {
    return '마지막 $commitUnit의 저장을 취소하고 바뀐 파일로 남길까요?';
  }

  @override
  String historyActionUndoMessage(String message) {
    return '저장을 취소했습니다. 메시지: $message';
  }

  @override
  String get historyActionCopyMessage => '메시지 복사';

  @override
  String historyActionSquash(String squash) {
    return '$squash…';
  }

  @override
  String get historyActionMessage => '메시지';

  @override
  String get historyActionUp => '위로 옮기기';

  @override
  String get historyActionDown => '아래로 옮기기';

  @override
  String get historyActionPublished =>
      '이미 원격에 올린 기록이 바뀝니다. 함께 작업하는 사람과 확인한 뒤 계속하세요.';

  @override
  String historyActionSelection(int count) {
    return '$count개 선택 · Ctrl/Shift+클릭으로 여러 개 선택';
  }

  @override
  String tagCreate(String tag) {
    return '$tag 만들기…';
  }

  @override
  String get tagName => '이름';

  @override
  String get tagDescription => '설명 (선택)';

  @override
  String tagPush(String tag) {
    return '$tag 원격에 올리기';
  }

  @override
  String tagDelete(String tag) {
    return '$tag 지우기';
  }

  @override
  String get tagRemote => '원격에서도 지우기';

  @override
  String tagDeleteConfirm(String name) {
    return '$name을 지울까요?';
  }

  @override
  String get overviewOpenFolder => '탐색기에서 열기';

  @override
  String get overviewEmptyFolder => '빈 폴더입니다.';

  @override
  String get overviewNoReadme =>
      'README가 없습니다. README.md 파일을 만들면 이 자리에 저장소 소개가 보입니다.';

  @override
  String overviewNoCommits(String commitUnit) {
    return '아직 $commitUnit이 없습니다. 작업 폴더 기준으로 보세요.';
  }

  @override
  String overviewTooLarge(String size) {
    return '파일이 너무 커서 미리 볼 수 없습니다 ($size).';
  }

  @override
  String overviewBinary(String size) {
    return '텍스트가 아닌 파일이라 미리 볼 수 없습니다 ($size).';
  }

  @override
  String get overviewMissing => '파일을 찾을 수 없습니다.';

  @override
  String get overviewBlocked => '저장소 밖을 가리켜서 열지 않았습니다.';

  @override
  String get overviewSubmodule => '하위 저장소';

  @override
  String get overviewSymlink => '바로 가기 링크';

  @override
  String overviewRemoteImage(String alt) {
    return '외부 이미지: $alt';
  }

  @override
  String get overviewRaw => '원문';

  @override
  String get overviewRendered => '미리보기';

  @override
  String overviewLoadError(String error) {
    return '불러오지 못했습니다: $error';
  }

  @override
  String get diffNoChanges => '바뀐 내용이 없습니다.';

  @override
  String diffLarge(String size) {
    return '바뀐 내용이 커서($size) 접어 두었습니다.';
  }

  @override
  String get diffShowAnyway => '그래도 보기';

  @override
  String get diffBinary => '텍스트가 아닌 파일이라 바뀐 내용을 보여 줄 수 없습니다.';

  @override
  String get diffUnrenderable => '이 파일의 바뀐 내용은 표시할 수 없습니다.';

  @override
  String diffSubmodule(String from, String to) {
    return '하위 저장소가 $from → $to로 바뀌었습니다.';
  }

  @override
  String get diffBidiWarning =>
      '보이지 않는 방향 제어 문자가 있습니다. 화면에 보이는 코드와 실제 코드가 다를 수 있으니 확인하세요.';

  @override
  String diffLineEndings(String from, String to) {
    return '줄바꿈이 $from에서 $to로 바뀝니다.';
  }

  @override
  String get diffImageBefore => '이전';

  @override
  String get diffImageAfter => '이후';
}
