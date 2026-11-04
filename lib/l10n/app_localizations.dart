import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_ko.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of L10n
/// returned by `L10n.of(context)`.
///
/// Applications need to include `L10n.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: L10n.localizationsDelegates,
///   supportedLocales: L10n.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the L10n.supportedLocales
/// property.
abstract class L10n {
  L10n(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static L10n of(BuildContext context) {
    return Localizations.of<L10n>(context, L10n)!;
  }

  static const LocalizationsDelegate<L10n> delegate = _L10nDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('ko'),
  ];

  /// No description provided for @appName.
  ///
  /// In ko, this message translates to:
  /// **'GitHub+'**
  String get appName;

  /// No description provided for @libraryTitle.
  ///
  /// In ko, this message translates to:
  /// **'라이브러리'**
  String get libraryTitle;

  /// No description provided for @libraryFilter.
  ///
  /// In ko, this message translates to:
  /// **'저장소 검색  (Ctrl+P)'**
  String get libraryFilter;

  /// No description provided for @libraryEmpty.
  ///
  /// In ko, this message translates to:
  /// **'아직 저장소가 없습니다.'**
  String get libraryEmpty;

  /// No description provided for @libraryAdd.
  ///
  /// In ko, this message translates to:
  /// **'저장소 추가'**
  String get libraryAdd;

  /// No description provided for @groupLocal.
  ///
  /// In ko, this message translates to:
  /// **'로컬'**
  String get groupLocal;

  /// No description provided for @groupHub.
  ///
  /// In ko, this message translates to:
  /// **'허브'**
  String get groupHub;

  /// No description provided for @groupGithub.
  ///
  /// In ko, this message translates to:
  /// **'GitHub'**
  String get groupGithub;

  /// No description provided for @repoMissing.
  ///
  /// In ko, this message translates to:
  /// **'찾을 수 없음'**
  String get repoMissing;

  /// No description provided for @repoChanges.
  ///
  /// In ko, this message translates to:
  /// **'변경 {count}'**
  String repoChanges(int count);

  /// No description provided for @addExisting.
  ///
  /// In ko, this message translates to:
  /// **'로컬 저장소 추가…'**
  String get addExisting;

  /// No description provided for @addCreate.
  ///
  /// In ko, this message translates to:
  /// **'새 저장소 만들기…'**
  String get addCreate;

  /// No description provided for @addClone.
  ///
  /// In ko, this message translates to:
  /// **'저장소 {clone}…'**
  String addClone(String clone);

  /// No description provided for @pickRepositoryFolder.
  ///
  /// In ko, this message translates to:
  /// **'저장소 폴더 선택'**
  String get pickRepositoryFolder;

  /// No description provided for @notARepository.
  ///
  /// In ko, this message translates to:
  /// **'{path}은(는) Git 저장소가 아닙니다.'**
  String notARepository(String path);

  /// No description provided for @addFailed.
  ///
  /// In ko, this message translates to:
  /// **'저장소를 추가하지 못했습니다.'**
  String get addFailed;

  /// No description provided for @welcomeTitle.
  ///
  /// In ko, this message translates to:
  /// **'GitHub+에 오신 것을 환영합니다'**
  String get welcomeTitle;

  /// No description provided for @welcomeBody.
  ///
  /// In ko, this message translates to:
  /// **'내부망 허브와 한눈에 보이는 상태 표시를 갖춘 가벼운 Git 클라이언트입니다. 시작하려면 저장소를 추가하세요.'**
  String get welcomeBody;

  /// No description provided for @questFirstTitle.
  ///
  /// In ko, this message translates to:
  /// **'첫 퀘스트'**
  String get questFirstTitle;

  /// No description provided for @questAddRepo.
  ///
  /// In ko, this message translates to:
  /// **'저장소 추가하기'**
  String get questAddRepo;

  /// No description provided for @questFirstCommit.
  ///
  /// In ko, this message translates to:
  /// **'첫 {commit}'**
  String questFirstCommit(String commit);

  /// No description provided for @questFirstPush.
  ///
  /// In ko, this message translates to:
  /// **'{remote}에 첫 {push}'**
  String questFirstPush(String remote, String push);

  /// No description provided for @branchLabel.
  ///
  /// In ko, this message translates to:
  /// **'{branch}'**
  String branchLabel(String branch);

  /// No description provided for @detachedHead.
  ///
  /// In ko, this message translates to:
  /// **'분리된 HEAD {sha}'**
  String detachedHead(String sha);

  /// No description provided for @noBranch.
  ///
  /// In ko, this message translates to:
  /// **'{branch} 없음'**
  String noBranch(String branch);

  /// No description provided for @actionCommit.
  ///
  /// In ko, this message translates to:
  /// **'{commit}'**
  String actionCommit(String commit);

  /// No description provided for @actionPush.
  ///
  /// In ko, this message translates to:
  /// **'{push} {count}'**
  String actionPush(String push, int count);

  /// No description provided for @actionPull.
  ///
  /// In ko, this message translates to:
  /// **'{pull} {count}'**
  String actionPull(String pull, int count);

  /// No description provided for @actionPublish.
  ///
  /// In ko, this message translates to:
  /// **'{publish}'**
  String actionPublish(String publish);

  /// No description provided for @actionFetch.
  ///
  /// In ko, this message translates to:
  /// **'{fetch}'**
  String actionFetch(String fetch);

  /// No description provided for @actionResolve.
  ///
  /// In ko, this message translates to:
  /// **'{conflict} 해결'**
  String actionResolve(String conflict);

  /// No description provided for @lastFetched.
  ///
  /// In ko, this message translates to:
  /// **'마지막 {fetch} {time}'**
  String lastFetched(String fetch, String time);

  /// No description provided for @neverFetched.
  ///
  /// In ko, this message translates to:
  /// **'아직 {fetch} 안 함'**
  String neverFetched(String fetch);

  /// No description provided for @hudChanges.
  ///
  /// In ko, this message translates to:
  /// **'{changes}'**
  String hudChanges(String changes);

  /// No description provided for @hudToPush.
  ///
  /// In ko, this message translates to:
  /// **'{push} 대기'**
  String hudToPush(String push);

  /// No description provided for @hudToPull.
  ///
  /// In ko, this message translates to:
  /// **'{pull} 대기'**
  String hudToPull(String pull);

  /// No description provided for @hudStashes.
  ///
  /// In ko, this message translates to:
  /// **'{stash}'**
  String hudStashes(String stash);

  /// No description provided for @hudConflicts.
  ///
  /// In ko, this message translates to:
  /// **'{conflict}'**
  String hudConflicts(String conflict);

  /// No description provided for @hudHub.
  ///
  /// In ko, this message translates to:
  /// **'허브'**
  String get hudHub;

  /// No description provided for @hudHubOnline.
  ///
  /// In ko, this message translates to:
  /// **'연결됨'**
  String get hudHubOnline;

  /// No description provided for @hudHubOffline.
  ///
  /// In ko, this message translates to:
  /// **'끊김'**
  String get hudHubOffline;

  /// No description provided for @hudHubNone.
  ///
  /// In ko, this message translates to:
  /// **'없음'**
  String get hudHubNone;

  /// No description provided for @hudChangesTip.
  ///
  /// In ko, this message translates to:
  /// **'아직 {commit}하지 않은 바뀐 파일 수'**
  String hudChangesTip(String commit);

  /// No description provided for @hudToPushTip.
  ///
  /// In ko, this message translates to:
  /// **'이 PC에만 있고 아직 {remote}에 {push}하지 않은 {commitUnit} 수'**
  String hudToPushTip(String remote, String push, String commitUnit);

  /// No description provided for @hudToPullTip.
  ///
  /// In ko, this message translates to:
  /// **'{remote}에 새로 올라왔고 아직 {pull}하지 않은 {commitUnit} 수'**
  String hudToPullTip(String remote, String pull, String commitUnit);

  /// No description provided for @goalPush.
  ///
  /// In ko, this message translates to:
  /// **'{push} 대기 목표'**
  String goalPush(String push);

  /// No description provided for @goalDailyCommits.
  ///
  /// In ko, this message translates to:
  /// **'오늘의 {commitUnit}'**
  String goalDailyCommits(String commitUnit);

  /// No description provided for @goalReached.
  ///
  /// In ko, this message translates to:
  /// **'목표 달성!'**
  String get goalReached;

  /// No description provided for @goalRemaining.
  ///
  /// In ko, this message translates to:
  /// **'목표까지 {count}'**
  String goalRemaining(int count);

  /// No description provided for @tabChanges.
  ///
  /// In ko, this message translates to:
  /// **'{changes}'**
  String tabChanges(String changes);

  /// No description provided for @changesSelectAll.
  ///
  /// In ko, this message translates to:
  /// **'전체 선택'**
  String get changesSelectAll;

  /// No description provided for @changesIncluded.
  ///
  /// In ko, this message translates to:
  /// **'{total}개 중 {included}개 포함'**
  String changesIncluded(int total, int included);

  /// No description provided for @changesConflicts.
  ///
  /// In ko, this message translates to:
  /// **'충돌 {count}개를 먼저 해결하세요'**
  String changesConflicts(int count);

  /// No description provided for @changesAdded.
  ///
  /// In ko, this message translates to:
  /// **'추가'**
  String get changesAdded;

  /// No description provided for @changesModified.
  ///
  /// In ko, this message translates to:
  /// **'수정'**
  String get changesModified;

  /// No description provided for @changesDeleted.
  ///
  /// In ko, this message translates to:
  /// **'삭제'**
  String get changesDeleted;

  /// No description provided for @changesRenamed.
  ///
  /// In ko, this message translates to:
  /// **'이름 변경'**
  String get changesRenamed;

  /// No description provided for @changesConflict.
  ///
  /// In ko, this message translates to:
  /// **'충돌 · {count}'**
  String changesConflict(String count);

  /// No description provided for @changesSummary.
  ///
  /// In ko, this message translates to:
  /// **'요약 (필수)'**
  String get changesSummary;

  /// No description provided for @changesDescription.
  ///
  /// In ko, this message translates to:
  /// **'설명'**
  String get changesDescription;

  /// No description provided for @changesRemaining.
  ///
  /// In ko, this message translates to:
  /// **'권장 길이까지 {count}자'**
  String changesRemaining(int count);

  /// No description provided for @changesAmend.
  ///
  /// In ko, this message translates to:
  /// **'마지막 {commit} 고치기(amend)'**
  String changesAmend(String commit);

  /// No description provided for @changesCommit.
  ///
  /// In ko, this message translates to:
  /// **'{branch}에 {commit}'**
  String changesCommit(String branch, String commit);

  /// No description provided for @changesCommitted.
  ///
  /// In ko, this message translates to:
  /// **'{commit} 완료 · {sha}'**
  String changesCommitted(String commit, String sha);

  /// No description provided for @changesDiscard.
  ///
  /// In ko, this message translates to:
  /// **'버리기'**
  String get changesDiscard;

  /// No description provided for @changesDiscardFile.
  ///
  /// In ko, this message translates to:
  /// **'이 파일 버리기'**
  String get changesDiscardFile;

  /// No description provided for @changesCopyPath.
  ///
  /// In ko, this message translates to:
  /// **'경로 복사'**
  String get changesCopyPath;

  /// No description provided for @changesDiscardTitle.
  ///
  /// In ko, this message translates to:
  /// **'파일 {count}개의 변경을 버릴까요?'**
  String changesDiscardTitle(int count);

  /// No description provided for @changesDiscardBody.
  ///
  /// In ko, this message translates to:
  /// **'백업 폴더에 사본을 남긴 뒤 되돌립니다.'**
  String get changesDiscardBody;

  /// No description provided for @changesCancel.
  ///
  /// In ko, this message translates to:
  /// **'취소'**
  String get changesCancel;

  /// No description provided for @changesDiscarded.
  ///
  /// In ko, this message translates to:
  /// **'변경을 버렸습니다 · 백업 폴더 열기'**
  String get changesDiscarded;

  /// No description provided for @changesSaved.
  ///
  /// In ko, this message translates to:
  /// **'모두 저장됨'**
  String get changesSaved;

  /// No description provided for @changesEmptyHint.
  ///
  /// In ko, this message translates to:
  /// **'작업 현황을 확인하거나 {push} 대기 {count}개를 확인하세요.'**
  String changesEmptyHint(String push, int count);

  /// No description provided for @changesPickFile.
  ///
  /// In ko, this message translates to:
  /// **'파일을 골라 바뀐 내용을 확인하세요.'**
  String get changesPickFile;

  /// No description provided for @changesFailed.
  ///
  /// In ko, this message translates to:
  /// **'작업을 마치지 못했습니다.'**
  String get changesFailed;

  /// No description provided for @changesRetry.
  ///
  /// In ko, this message translates to:
  /// **'다시 시도'**
  String get changesRetry;

  /// No description provided for @changesDetached.
  ///
  /// In ko, this message translates to:
  /// **'현재 위치'**
  String get changesDetached;

  /// No description provided for @changesResize.
  ///
  /// In ko, this message translates to:
  /// **'파일 목록 너비 조절'**
  String get changesResize;

  /// No description provided for @changesBusy.
  ///
  /// In ko, this message translates to:
  /// **'처리 중…'**
  String get changesBusy;

  /// No description provided for @tabHistory.
  ///
  /// In ko, this message translates to:
  /// **'{history}'**
  String tabHistory(String history);

  /// No description provided for @tabExpeditions.
  ///
  /// In ko, this message translates to:
  /// **'작업 현황'**
  String get tabExpeditions;

  /// No description provided for @expeditionsTitle.
  ///
  /// In ko, this message translates to:
  /// **'작업 현황'**
  String get expeditionsTitle;

  /// No description provided for @expeditionsEmpty.
  ///
  /// In ko, this message translates to:
  /// **'진행 중인 작업이 없습니다. {push}·{pull}·{clone}처럼 시간이 걸리는 작업이 여기에 표시됩니다.'**
  String expeditionsEmpty(String push, String pull, String clone);

  /// No description provided for @conflictQuestTitle.
  ///
  /// In ko, this message translates to:
  /// **'{operation} 진행 중 · {name}'**
  String conflictQuestTitle(String operation, String name);

  /// No description provided for @conflictRebaseStep.
  ///
  /// In ko, this message translates to:
  /// **'{operation} {step}/{total} 단계'**
  String conflictRebaseStep(String operation, int step, int total);

  /// No description provided for @conflictProgress.
  ///
  /// In ko, this message translates to:
  /// **'충돌 파일 {resolved}/{total}개 해결'**
  String conflictProgress(int resolved, int total);

  /// No description provided for @conflictSteps.
  ///
  /// In ko, this message translates to:
  /// **'① 충돌 해결 → ② 해결됨 표시 → ③ 이어서 하기'**
  String get conflictSteps;

  /// No description provided for @conflictContinue.
  ///
  /// In ko, this message translates to:
  /// **'{operation} 이어서 하기'**
  String conflictContinue(String operation);

  /// No description provided for @conflictAbort.
  ///
  /// In ko, this message translates to:
  /// **'{operation} 그만두기'**
  String conflictAbort(String operation);

  /// No description provided for @conflictAbortBody.
  ///
  /// In ko, this message translates to:
  /// **'진행 중인 작업과 충돌 해결 내용을 취소하고 시작 전 상태로 돌아갑니다.'**
  String get conflictAbortBody;

  /// No description provided for @mergeMessage.
  ///
  /// In ko, this message translates to:
  /// **'{merge} 메시지 확인'**
  String mergeMessage(String merge);

  /// No description provided for @conflictOurs.
  ///
  /// In ko, this message translates to:
  /// **'내 쪽(현재)'**
  String get conflictOurs;

  /// No description provided for @conflictTheirs.
  ///
  /// In ko, this message translates to:
  /// **'들어온 쪽'**
  String get conflictTheirs;

  /// No description provided for @conflictBoth.
  ///
  /// In ko, this message translates to:
  /// **'둘 다'**
  String get conflictBoth;

  /// No description provided for @conflictAllOurs.
  ///
  /// In ko, this message translates to:
  /// **'모두 내 쪽'**
  String get conflictAllOurs;

  /// No description provided for @conflictAllTheirs.
  ///
  /// In ko, this message translates to:
  /// **'모두 들어온 쪽'**
  String get conflictAllTheirs;

  /// No description provided for @conflictSave.
  ///
  /// In ko, this message translates to:
  /// **'저장하고 해결됨 표시'**
  String get conflictSave;

  /// No description provided for @conflictSideOnly.
  ///
  /// In ko, this message translates to:
  /// **'바이너리·삭제 충돌 또는 읽을 수 없는 파일입니다. 파일 전체를 한쪽으로 선택하세요.'**
  String get conflictSideOnly;

  /// No description provided for @conflictStale.
  ///
  /// In ko, this message translates to:
  /// **'파일이 바뀌었습니다. 다시 열어 내용을 확인하세요.'**
  String get conflictStale;

  /// No description provided for @mergeInto.
  ///
  /// In ko, this message translates to:
  /// **'현재 {branch}로 {merge}'**
  String mergeInto(String branch, String merge);

  /// No description provided for @rebaseOnto.
  ///
  /// In ko, this message translates to:
  /// **'이 {branch} 위로 {rebase}'**
  String rebaseOnto(String branch, String rebase);

  /// No description provided for @rebaseWarning.
  ///
  /// In ko, this message translates to:
  /// **'{rebase}는 이미 올린 버전도 다시 쓸 수 있습니다. 함께 작업하는 사람이 있다면 먼저 확인하세요.'**
  String rebaseWarning(String rebase);

  /// No description provided for @mergeConflicts.
  ///
  /// In ko, this message translates to:
  /// **'충돌이 있습니다. {changes} 탭에서 해결하세요.'**
  String mergeConflicts(String changes);

  /// No description provided for @mergeCompleted.
  ///
  /// In ko, this message translates to:
  /// **'{operation} 완료'**
  String mergeCompleted(String operation);

  /// No description provided for @mergeNothing.
  ///
  /// In ko, this message translates to:
  /// **'이미 최신입니다'**
  String get mergeNothing;

  /// No description provided for @expeditionRunning.
  ///
  /// In ko, this message translates to:
  /// **'진행 중'**
  String get expeditionRunning;

  /// No description provided for @expeditionDone.
  ///
  /// In ko, this message translates to:
  /// **'완료'**
  String get expeditionDone;

  /// No description provided for @expeditionFailed.
  ///
  /// In ko, this message translates to:
  /// **'실패'**
  String get expeditionFailed;

  /// No description provided for @expeditionCollect.
  ///
  /// In ko, this message translates to:
  /// **'결과 보기'**
  String get expeditionCollect;

  /// No description provided for @expeditionDismiss.
  ///
  /// In ko, this message translates to:
  /// **'닫기'**
  String get expeditionDismiss;

  /// No description provided for @expeditionElapsed.
  ///
  /// In ko, this message translates to:
  /// **'경과 {time}'**
  String expeditionElapsed(String time);

  /// No description provided for @expeditionRemaining.
  ///
  /// In ko, this message translates to:
  /// **'남은 시간 약 {time}'**
  String expeditionRemaining(String time);

  /// No description provided for @expeditionTo.
  ///
  /// In ko, this message translates to:
  /// **'대상: {destination}'**
  String expeditionTo(String destination);

  /// No description provided for @settingsTitle.
  ///
  /// In ko, this message translates to:
  /// **'환경설정'**
  String get settingsTitle;

  /// No description provided for @settingsLanguage.
  ///
  /// In ko, this message translates to:
  /// **'언어 / Language'**
  String get settingsLanguage;

  /// No description provided for @settingsTheme.
  ///
  /// In ko, this message translates to:
  /// **'테마'**
  String get settingsTheme;

  /// No description provided for @themeDark.
  ///
  /// In ko, this message translates to:
  /// **'다크'**
  String get themeDark;

  /// No description provided for @themeLight.
  ///
  /// In ko, this message translates to:
  /// **'라이트'**
  String get themeLight;

  /// No description provided for @themeSystem.
  ///
  /// In ko, this message translates to:
  /// **'시스템 설정'**
  String get themeSystem;

  /// No description provided for @settingsGoals.
  ///
  /// In ko, this message translates to:
  /// **'목표 바'**
  String get settingsGoals;

  /// No description provided for @settingsDailyGoal.
  ///
  /// In ko, this message translates to:
  /// **'하루 {commitUnit} 목표'**
  String settingsDailyGoal(String commitUnit);

  /// No description provided for @settingsPushGoal.
  ///
  /// In ko, this message translates to:
  /// **'{push} 대기 목표'**
  String settingsPushGoal(String push);

  /// No description provided for @settingsReduceMotion.
  ///
  /// In ko, this message translates to:
  /// **'애니메이션 줄이기'**
  String get settingsReduceMotion;

  /// No description provided for @commonCancel.
  ///
  /// In ko, this message translates to:
  /// **'취소'**
  String get commonCancel;

  /// No description provided for @commonClose.
  ///
  /// In ko, this message translates to:
  /// **'닫기'**
  String get commonClose;

  /// No description provided for @commonOk.
  ///
  /// In ko, this message translates to:
  /// **'확인'**
  String get commonOk;

  /// No description provided for @commonRetry.
  ///
  /// In ko, this message translates to:
  /// **'다시 시도'**
  String get commonRetry;

  /// No description provided for @commonLoading.
  ///
  /// In ko, this message translates to:
  /// **'불러오는 중…'**
  String get commonLoading;

  /// No description provided for @commonDetails.
  ///
  /// In ko, this message translates to:
  /// **'자세히'**
  String get commonDetails;

  /// No description provided for @windowMinimize.
  ///
  /// In ko, this message translates to:
  /// **'최소화'**
  String get windowMinimize;

  /// No description provided for @windowMaximize.
  ///
  /// In ko, this message translates to:
  /// **'최대화'**
  String get windowMaximize;

  /// No description provided for @windowClose.
  ///
  /// In ko, this message translates to:
  /// **'닫기'**
  String get windowClose;

  /// No description provided for @openSettings.
  ///
  /// In ko, this message translates to:
  /// **'환경설정'**
  String get openSettings;

  /// No description provided for @hudStashesTip.
  ///
  /// In ko, this message translates to:
  /// **'{stash}로 잠시 치워 둔 작업 수'**
  String hudStashesTip(String stash);

  /// No description provided for @hudConflictsTip.
  ///
  /// In ko, this message translates to:
  /// **'두 작업이 같은 곳을 고쳐서 직접 골라야 하는 파일 수 — 충돌(Conflict)'**
  String get hudConflictsTip;

  /// No description provided for @jobPull.
  ///
  /// In ko, this message translates to:
  /// **'{name}에서 {pull}'**
  String jobPull(String name, String pull);

  /// No description provided for @jobPush.
  ///
  /// In ko, this message translates to:
  /// **'{name}에 {push}'**
  String jobPush(String name, String push);

  /// No description provided for @jobPublish.
  ///
  /// In ko, this message translates to:
  /// **'{name} {publish}'**
  String jobPublish(String name, String publish);

  /// No description provided for @jobFetch.
  ///
  /// In ko, this message translates to:
  /// **'{name} {fetch}'**
  String jobFetch(String name, String fetch);

  /// No description provided for @resultSent.
  ///
  /// In ko, this message translates to:
  /// **'{commitUnit} {count}개 {push} 완료'**
  String resultSent(String commitUnit, int count, String push);

  /// No description provided for @resultReceived.
  ///
  /// In ko, this message translates to:
  /// **'새 {commitUnit} {count}개 받음'**
  String resultReceived(String commitUnit, int count);

  /// No description provided for @resultUpToDate.
  ///
  /// In ko, this message translates to:
  /// **'이미 최신 상태입니다'**
  String get resultUpToDate;

  /// No description provided for @settingsTerms.
  ///
  /// In ko, this message translates to:
  /// **'용어 표시'**
  String get settingsTerms;

  /// No description provided for @termPlain.
  ///
  /// In ko, this message translates to:
  /// **'쉬운 말 (Git이 처음인 분)'**
  String get termPlain;

  /// No description provided for @termGit.
  ///
  /// In ko, this message translates to:
  /// **'Git 용어 (GitHub 사용자)'**
  String get termGit;

  /// No description provided for @termExample.
  ///
  /// In ko, this message translates to:
  /// **'예: {plain}  ↔  {git}'**
  String termExample(String plain, String git);

  /// No description provided for @gitTermHint.
  ///
  /// In ko, this message translates to:
  /// **'Git 용어: {term}'**
  String gitTermHint(String term);

  /// No description provided for @tabOverview.
  ///
  /// In ko, this message translates to:
  /// **'개요'**
  String get tabOverview;

  /// No description provided for @overviewWorkingTree.
  ///
  /// In ko, this message translates to:
  /// **'작업 폴더'**
  String get overviewWorkingTree;

  /// No description provided for @historyCurrent.
  ///
  /// In ko, this message translates to:
  /// **'현재 {branch}'**
  String historyCurrent(String branch);

  /// No description provided for @historyAll.
  ///
  /// In ko, this message translates to:
  /// **'모든 {branch}'**
  String historyAll(String branch);

  /// No description provided for @historySearch.
  ///
  /// In ko, this message translates to:
  /// **'요약·작성자 검색 (불러온 기록)'**
  String get historySearch;

  /// No description provided for @historyEmpty.
  ///
  /// In ko, this message translates to:
  /// **'아직 {commitUnit}이 없습니다'**
  String historyEmpty(String commitUnit);

  /// No description provided for @historyNoResults.
  ///
  /// In ko, this message translates to:
  /// **'일치하는 기록이 없습니다'**
  String get historyNoResults;

  /// No description provided for @historySelect.
  ///
  /// In ko, this message translates to:
  /// **'목록에서 기록을 선택하세요'**
  String get historySelect;

  /// No description provided for @historyFiles.
  ///
  /// In ko, this message translates to:
  /// **'바뀐 파일 {count}개'**
  String historyFiles(int count);

  /// No description provided for @historyNoFiles.
  ///
  /// In ko, this message translates to:
  /// **'바뀐 파일이 없습니다'**
  String get historyNoFiles;

  /// No description provided for @historySelectFile.
  ///
  /// In ko, this message translates to:
  /// **'파일을 선택해 바뀐 내용을 확인하세요'**
  String get historySelectFile;

  /// No description provided for @historyParents.
  ///
  /// In ko, this message translates to:
  /// **'부모 {commitUnit}'**
  String historyParents(String commitUnit);

  /// No description provided for @historyCopySha.
  ///
  /// In ko, this message translates to:
  /// **'SHA 복사'**
  String get historyCopySha;

  /// No description provided for @historyCopied.
  ///
  /// In ko, this message translates to:
  /// **'SHA를 복사했습니다'**
  String get historyCopied;

  /// No description provided for @historyLoadMore.
  ///
  /// In ko, this message translates to:
  /// **'다음 200개 불러오기'**
  String get historyLoadMore;

  /// No description provided for @historyRetry.
  ///
  /// In ko, this message translates to:
  /// **'다시 시도'**
  String get historyRetry;

  /// No description provided for @historyResize.
  ///
  /// In ko, this message translates to:
  /// **'목록과 상세 너비 조절'**
  String get historyResize;

  /// No description provided for @historyClose.
  ///
  /// In ko, this message translates to:
  /// **'닫기'**
  String get historyClose;

  /// No description provided for @branchSearch.
  ///
  /// In ko, this message translates to:
  /// **'{branch} 검색'**
  String branchSearch(String branch);

  /// No description provided for @branchCurrent.
  ///
  /// In ko, this message translates to:
  /// **'현재'**
  String get branchCurrent;

  /// No description provided for @branchLocal.
  ///
  /// In ko, this message translates to:
  /// **'로컬 {branch}'**
  String branchLocal(String branch);

  /// No description provided for @branchRemote.
  ///
  /// In ko, this message translates to:
  /// **'원격 {branch}'**
  String branchRemote(String branch);

  /// No description provided for @branchCreate.
  ///
  /// In ko, this message translates to:
  /// **'새 {branch} 만들기'**
  String branchCreate(String branch);

  /// No description provided for @branchName.
  ///
  /// In ko, this message translates to:
  /// **'{branch} 이름'**
  String branchName(String branch);

  /// No description provided for @branchNameHint.
  ///
  /// In ko, this message translates to:
  /// **'공백은 -로 바뀝니다'**
  String get branchNameHint;

  /// No description provided for @branchExists.
  ///
  /// In ko, this message translates to:
  /// **'이미 있는 이름입니다'**
  String get branchExists;

  /// No description provided for @branchInvalid.
  ///
  /// In ko, this message translates to:
  /// **'올바른 이름을 입력하세요'**
  String get branchInvalid;

  /// No description provided for @branchRename.
  ///
  /// In ko, this message translates to:
  /// **'이름 바꾸기'**
  String get branchRename;

  /// No description provided for @branchDelete.
  ///
  /// In ko, this message translates to:
  /// **'삭제'**
  String get branchDelete;

  /// No description provided for @branchCancel.
  ///
  /// In ko, this message translates to:
  /// **'취소'**
  String get branchCancel;

  /// No description provided for @branchSave.
  ///
  /// In ko, this message translates to:
  /// **'저장'**
  String get branchSave;

  /// No description provided for @branchSwitch.
  ///
  /// In ko, this message translates to:
  /// **'{name}(으)로 전환'**
  String branchSwitch(String name);

  /// No description provided for @branchSwitchWarning.
  ///
  /// In ko, this message translates to:
  /// **'바뀐 파일이 있습니다. {name}(으)로 전환할까요? 수정 내용이 겹치면 전환할 수 없습니다.'**
  String branchSwitchWarning(String name);

  /// No description provided for @branchContinue.
  ///
  /// In ko, this message translates to:
  /// **'전환'**
  String get branchContinue;

  /// No description provided for @branchDeleteConfirm.
  ///
  /// In ko, this message translates to:
  /// **'{name}을(를) 삭제할까요?'**
  String branchDeleteConfirm(String name);

  /// No description provided for @branchForce.
  ///
  /// In ko, this message translates to:
  /// **'아직 {merge}하지 않은 내용도 삭제'**
  String branchForce(String merge);

  /// No description provided for @branchDeleteRemote.
  ///
  /// In ko, this message translates to:
  /// **'원격에서도 삭제'**
  String get branchDeleteRemote;

  /// No description provided for @branchRemoteWarning.
  ///
  /// In ko, this message translates to:
  /// **'원격 삭제를 선택하지 않으면 이 PC의 추적 항목만 삭제합니다.'**
  String get branchRemoteWarning;

  /// No description provided for @branchFailed.
  ///
  /// In ko, this message translates to:
  /// **'작업을 완료하지 못했습니다'**
  String get branchFailed;

  /// No description provided for @branchEmpty.
  ///
  /// In ko, this message translates to:
  /// **'일치하는 항목이 없습니다'**
  String get branchEmpty;

  /// No description provided for @branchMenu.
  ///
  /// In ko, this message translates to:
  /// **'{name} 메뉴'**
  String branchMenu(String name);

  /// No description provided for @branchAheadBehind.
  ///
  /// In ko, this message translates to:
  /// **'앞섬 {ahead} · 뒤처짐 {behind}'**
  String branchAheadBehind(int ahead, int behind);

  /// No description provided for @overviewWorkingTreeTip.
  ///
  /// In ko, this message translates to:
  /// **'지금 폴더에 있는 그대로 보여 줍니다. 아직 {commit}하지 않은 수정도 보이고, .gitignore로 숨긴 파일은 빠집니다.'**
  String overviewWorkingTreeTip(String commit);

  /// No description provided for @overviewHead.
  ///
  /// In ko, this message translates to:
  /// **'마지막 {commitUnit} (HEAD)'**
  String overviewHead(String commitUnit);

  /// No description provided for @overviewHeadTip.
  ///
  /// In ko, this message translates to:
  /// **'현재 {branch}에 마지막으로 저장된 내용을 보여 줍니다. 다른 PC나 허브에서 보는 모습과 같습니다.'**
  String overviewHeadTip(String branch);

  /// No description provided for @overviewRefresh.
  ///
  /// In ko, this message translates to:
  /// **'새로 고침'**
  String get overviewRefresh;

  /// No description provided for @stashTitle.
  ///
  /// In ko, this message translates to:
  /// **'{stash}'**
  String stashTitle(String stash);

  /// No description provided for @stashCreate.
  ///
  /// In ko, this message translates to:
  /// **'지금 바뀐 파일 {stash}'**
  String stashCreate(String stash);

  /// 메시지 (선택)
  ///
  /// In ko, this message translates to:
  /// **'메시지 (선택)'**
  String get stashMessage;

  /// 새 파일 포함
  ///
  /// In ko, this message translates to:
  /// **'새 파일 포함'**
  String get stashUntracked;

  /// 보관한 항목이 없습니다.
  ///
  /// In ko, this message translates to:
  /// **'보관한 항목이 없습니다.'**
  String get stashEmpty;

  /// 꺼내기
  ///
  /// In ko, this message translates to:
  /// **'꺼내기'**
  String get stashPop;

  /// 적용만
  ///
  /// In ko, this message translates to:
  /// **'적용만'**
  String get stashApply;

  /// 버리기
  ///
  /// In ko, this message translates to:
  /// **'버리기'**
  String get stashDrop;

  /// 이 항목을 버릴까요? 보관한 내용은 복구할 수 없습니다.
  ///
  /// In ko, this message translates to:
  /// **'이 항목을 버릴까요? 보관한 내용은 복구할 수 없습니다.'**
  String get stashDropConfirm;

  /// 항목을 펼쳐 파일을 선택하세요.
  ///
  /// In ko, this message translates to:
  /// **'항목을 펼쳐 파일을 선택하세요.'**
  String get stashSelect;

  /// 작업 메뉴
  ///
  /// In ko, this message translates to:
  /// **'작업 메뉴'**
  String get historyActionMenu;

  /// 취소
  ///
  /// In ko, this message translates to:
  /// **'취소'**
  String get historyActionCancel;

  /// 닫기
  ///
  /// In ko, this message translates to:
  /// **'닫기'**
  String get historyActionClose;

  /// 계속
  ///
  /// In ko, this message translates to:
  /// **'계속'**
  String get historyActionConfirm;

  /// 작업을 완료했습니다.
  ///
  /// In ko, this message translates to:
  /// **'작업을 완료했습니다.'**
  String get historyActionDone;

  /// 처리할 내용이 없습니다.
  ///
  /// In ko, this message translates to:
  /// **'처리할 내용이 없습니다.'**
  String get historyActionNothing;

  /// No description provided for @historyActionConflicts.
  ///
  /// In ko, this message translates to:
  /// **'충돌이 있습니다. {changes} 탭에서 해결하세요.'**
  String historyActionConflicts(String changes);

  /// 작업에 실패했습니다.
  ///
  /// In ko, this message translates to:
  /// **'작업에 실패했습니다.'**
  String get historyActionFailed;

  /// No description provided for @historyActionRevert.
  ///
  /// In ko, this message translates to:
  /// **'이 {commitUnit} {revert}'**
  String historyActionRevert(String commitUnit, String revert);

  /// No description provided for @historyActionRevertConfirm.
  ///
  /// In ko, this message translates to:
  /// **'선택한 내용을 되돌리는 새 {commitUnit}을 만들까요?'**
  String historyActionRevertConfirm(String commitUnit);

  /// No description provided for @historyActionPick.
  ///
  /// In ko, this message translates to:
  /// **'현재 {branch}로 {cherryPick}'**
  String historyActionPick(String branch, String cherryPick);

  /// No description provided for @historyActionUndo.
  ///
  /// In ko, this message translates to:
  /// **'마지막 {commitUnit} 취소'**
  String historyActionUndo(String commitUnit);

  /// No description provided for @historyActionUndoConfirm.
  ///
  /// In ko, this message translates to:
  /// **'마지막 {commitUnit}의 저장을 취소하고 바뀐 파일로 남길까요?'**
  String historyActionUndoConfirm(String commitUnit);

  /// No description provided for @historyActionUndoMessage.
  ///
  /// In ko, this message translates to:
  /// **'저장을 취소했습니다. 메시지: {message}'**
  String historyActionUndoMessage(String message);

  /// 메시지 복사
  ///
  /// In ko, this message translates to:
  /// **'메시지 복사'**
  String get historyActionCopyMessage;

  /// No description provided for @historyActionSquash.
  ///
  /// In ko, this message translates to:
  /// **'{squash}…'**
  String historyActionSquash(String squash);

  /// 메시지
  ///
  /// In ko, this message translates to:
  /// **'메시지'**
  String get historyActionMessage;

  /// 위로 옮기기
  ///
  /// In ko, this message translates to:
  /// **'위로 옮기기'**
  String get historyActionUp;

  /// 아래로 옮기기
  ///
  /// In ko, this message translates to:
  /// **'아래로 옮기기'**
  String get historyActionDown;

  /// 이미 원격에 올린 기록이 바뀝니다. 함께 작업하는 사람과 확인한 뒤 계속하세요.
  ///
  /// In ko, this message translates to:
  /// **'이미 원격에 올린 기록이 바뀝니다. 함께 작업하는 사람과 확인한 뒤 계속하세요.'**
  String get historyActionPublished;

  /// No description provided for @historyActionSelection.
  ///
  /// In ko, this message translates to:
  /// **'{count}개 선택 · Ctrl/Shift+클릭으로 여러 개 선택'**
  String historyActionSelection(int count);

  /// No description provided for @tagCreate.
  ///
  /// In ko, this message translates to:
  /// **'{tag} 만들기…'**
  String tagCreate(String tag);

  /// 이름
  ///
  /// In ko, this message translates to:
  /// **'이름'**
  String get tagName;

  /// 설명 (선택)
  ///
  /// In ko, this message translates to:
  /// **'설명 (선택)'**
  String get tagDescription;

  /// No description provided for @tagPush.
  ///
  /// In ko, this message translates to:
  /// **'{tag} 원격에 올리기'**
  String tagPush(String tag);

  /// No description provided for @tagDelete.
  ///
  /// In ko, this message translates to:
  /// **'{tag} 지우기'**
  String tagDelete(String tag);

  /// 원격에서도 지우기
  ///
  /// In ko, this message translates to:
  /// **'원격에서도 지우기'**
  String get tagRemote;

  /// No description provided for @tagDeleteConfirm.
  ///
  /// In ko, this message translates to:
  /// **'{name}을 지울까요?'**
  String tagDeleteConfirm(String name);

  /// No description provided for @overviewOpenFolder.
  ///
  /// In ko, this message translates to:
  /// **'탐색기에서 열기'**
  String get overviewOpenFolder;

  /// No description provided for @overviewEmptyFolder.
  ///
  /// In ko, this message translates to:
  /// **'빈 폴더입니다.'**
  String get overviewEmptyFolder;

  /// No description provided for @overviewNoReadme.
  ///
  /// In ko, this message translates to:
  /// **'README가 없습니다. README.md 파일을 만들면 이 자리에 저장소 소개가 보입니다.'**
  String get overviewNoReadme;

  /// No description provided for @overviewNoCommits.
  ///
  /// In ko, this message translates to:
  /// **'아직 {commitUnit}이 없습니다. 작업 폴더 기준으로 보세요.'**
  String overviewNoCommits(String commitUnit);

  /// No description provided for @overviewTooLarge.
  ///
  /// In ko, this message translates to:
  /// **'파일이 너무 커서 미리 볼 수 없습니다 ({size}).'**
  String overviewTooLarge(String size);

  /// No description provided for @overviewBinary.
  ///
  /// In ko, this message translates to:
  /// **'텍스트가 아닌 파일이라 미리 볼 수 없습니다 ({size}).'**
  String overviewBinary(String size);

  /// No description provided for @overviewMissing.
  ///
  /// In ko, this message translates to:
  /// **'파일을 찾을 수 없습니다.'**
  String get overviewMissing;

  /// No description provided for @overviewBlocked.
  ///
  /// In ko, this message translates to:
  /// **'저장소 밖을 가리켜서 열지 않았습니다.'**
  String get overviewBlocked;

  /// No description provided for @overviewSubmodule.
  ///
  /// In ko, this message translates to:
  /// **'하위 저장소'**
  String get overviewSubmodule;

  /// No description provided for @overviewSymlink.
  ///
  /// In ko, this message translates to:
  /// **'바로 가기 링크'**
  String get overviewSymlink;

  /// No description provided for @overviewRemoteImage.
  ///
  /// In ko, this message translates to:
  /// **'외부 이미지: {alt}'**
  String overviewRemoteImage(String alt);

  /// No description provided for @overviewRaw.
  ///
  /// In ko, this message translates to:
  /// **'원문'**
  String get overviewRaw;

  /// No description provided for @overviewRendered.
  ///
  /// In ko, this message translates to:
  /// **'미리보기'**
  String get overviewRendered;

  /// No description provided for @overviewLoadError.
  ///
  /// In ko, this message translates to:
  /// **'불러오지 못했습니다: {error}'**
  String overviewLoadError(String error);

  /// No description provided for @diffNoChanges.
  ///
  /// In ko, this message translates to:
  /// **'바뀐 내용이 없습니다.'**
  String get diffNoChanges;

  /// No description provided for @diffLarge.
  ///
  /// In ko, this message translates to:
  /// **'바뀐 내용이 커서({size}) 접어 두었습니다.'**
  String diffLarge(String size);

  /// No description provided for @diffShowAnyway.
  ///
  /// In ko, this message translates to:
  /// **'그래도 보기'**
  String get diffShowAnyway;

  /// No description provided for @diffBinary.
  ///
  /// In ko, this message translates to:
  /// **'텍스트가 아닌 파일이라 바뀐 내용을 보여 줄 수 없습니다.'**
  String get diffBinary;

  /// No description provided for @diffUnrenderable.
  ///
  /// In ko, this message translates to:
  /// **'이 파일의 바뀐 내용은 표시할 수 없습니다.'**
  String get diffUnrenderable;

  /// No description provided for @diffSubmodule.
  ///
  /// In ko, this message translates to:
  /// **'하위 저장소가 {from} → {to}로 바뀌었습니다.'**
  String diffSubmodule(String from, String to);

  /// No description provided for @diffBidiWarning.
  ///
  /// In ko, this message translates to:
  /// **'보이지 않는 방향 제어 문자가 있습니다. 화면에 보이는 코드와 실제 코드가 다를 수 있으니 확인하세요.'**
  String get diffBidiWarning;

  /// No description provided for @diffLineEndings.
  ///
  /// In ko, this message translates to:
  /// **'줄바꿈이 {from}에서 {to}로 바뀝니다.'**
  String diffLineEndings(String from, String to);

  /// No description provided for @diffImageBefore.
  ///
  /// In ko, this message translates to:
  /// **'이전'**
  String get diffImageBefore;

  /// No description provided for @diffImageAfter.
  ///
  /// In ko, this message translates to:
  /// **'이후'**
  String get diffImageAfter;
}

class _L10nDelegate extends LocalizationsDelegate<L10n> {
  const _L10nDelegate();

  @override
  Future<L10n> load(Locale locale) {
    return SynchronousFuture<L10n>(lookupL10n(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'ko'].contains(locale.languageCode);

  @override
  bool shouldReload(_L10nDelegate old) => false;
}

L10n lookupL10n(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return L10nEn();
    case 'ko':
      return L10nKo();
  }

  throw FlutterError(
    'L10n.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
