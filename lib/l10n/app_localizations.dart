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
  /// **'원격 저장소 내려받기(Clone)…'**
  String get addClone;

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
  /// **'첫 버전 저장하기(Commit)'**
  String get questFirstCommit;

  /// No description provided for @questFirstPush.
  ///
  /// In ko, this message translates to:
  /// **'원격 저장소에 업로드하기(Push)'**
  String get questFirstPush;

  /// No description provided for @branchLabel.
  ///
  /// In ko, this message translates to:
  /// **'작업 갈래(Branch)'**
  String get branchLabel;

  /// No description provided for @detachedHead.
  ///
  /// In ko, this message translates to:
  /// **'분리된 HEAD {sha}'**
  String detachedHead(String sha);

  /// No description provided for @noBranch.
  ///
  /// In ko, this message translates to:
  /// **'작업 갈래 없음'**
  String get noBranch;

  /// No description provided for @actionCommit.
  ///
  /// In ko, this message translates to:
  /// **'버전 저장(Commit)'**
  String get actionCommit;

  /// No description provided for @actionPush.
  ///
  /// In ko, this message translates to:
  /// **'업로드(Push) {count}'**
  String actionPush(int count);

  /// No description provided for @actionPull.
  ///
  /// In ko, this message translates to:
  /// **'다운로드(Pull) {count}'**
  String actionPull(int count);

  /// No description provided for @actionPublish.
  ///
  /// In ko, this message translates to:
  /// **'처음 올리기(Publish)'**
  String get actionPublish;

  /// No description provided for @actionFetch.
  ///
  /// In ko, this message translates to:
  /// **'변경 확인(Fetch)'**
  String get actionFetch;

  /// No description provided for @actionResolve.
  ///
  /// In ko, this message translates to:
  /// **'충돌 해결(Conflict)'**
  String get actionResolve;

  /// No description provided for @lastFetched.
  ///
  /// In ko, this message translates to:
  /// **'마지막 변경 확인 {time}'**
  String lastFetched(String time);

  /// No description provided for @neverFetched.
  ///
  /// In ko, this message translates to:
  /// **'아직 변경 확인 안 함'**
  String get neverFetched;

  /// No description provided for @hudChanges.
  ///
  /// In ko, this message translates to:
  /// **'바뀐 파일'**
  String get hudChanges;

  /// No description provided for @hudToPush.
  ///
  /// In ko, this message translates to:
  /// **'업로드 대기'**
  String get hudToPush;

  /// No description provided for @hudToPull.
  ///
  /// In ko, this message translates to:
  /// **'다운로드 대기'**
  String get hudToPull;

  /// No description provided for @hudStashes.
  ///
  /// In ko, this message translates to:
  /// **'임시 보관'**
  String get hudStashes;

  /// No description provided for @hudConflicts.
  ///
  /// In ko, this message translates to:
  /// **'충돌'**
  String get hudConflicts;

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
  /// **'아직 버전으로 저장(Commit)하지 않은 바뀐 파일 수'**
  String get hudChangesTip;

  /// No description provided for @hudToPushTip.
  ///
  /// In ko, this message translates to:
  /// **'이 PC에만 저장돼 있고 아직 원격 저장소에 업로드(Push)하지 않은 버전 수'**
  String get hudToPushTip;

  /// No description provided for @hudToPullTip.
  ///
  /// In ko, this message translates to:
  /// **'원격 저장소에 새로 올라왔고 아직 다운로드(Pull)하지 않은 버전 수'**
  String get hudToPullTip;

  /// No description provided for @goalPush.
  ///
  /// In ko, this message translates to:
  /// **'업로드 대기 목표'**
  String get goalPush;

  /// No description provided for @goalDailyCommits.
  ///
  /// In ko, this message translates to:
  /// **'오늘 저장한 버전'**
  String get goalDailyCommits;

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
  /// **'바뀐 파일'**
  String get tabChanges;

  /// No description provided for @tabHistory.
  ///
  /// In ko, this message translates to:
  /// **'버전 기록(History)'**
  String get tabHistory;

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
  /// **'진행 중인 작업이 없습니다. 업로드(Push)·다운로드(Pull)·내려받기(Clone)처럼 시간이 걸리는 작업이 여기에 표시됩니다.'**
  String get expeditionsEmpty;

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
  /// **'하루 버전 저장 목표'**
  String get settingsDailyGoal;

  /// No description provided for @settingsPushGoal.
  ///
  /// In ko, this message translates to:
  /// **'업로드 대기 목표'**
  String get settingsPushGoal;

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
  /// **'잠시 치워 둔 작업 수 — 임시 보관(Stash)'**
  String get hudStashesTip;

  /// No description provided for @hudConflictsTip.
  ///
  /// In ko, this message translates to:
  /// **'두 작업이 같은 곳을 고쳐서 직접 골라야 하는 파일 수 — 충돌(Conflict)'**
  String get hudConflictsTip;

  /// No description provided for @jobPull.
  ///
  /// In ko, this message translates to:
  /// **'{remote}에서 다운로드(Pull)'**
  String jobPull(String remote);

  /// No description provided for @jobPush.
  ///
  /// In ko, this message translates to:
  /// **'{remote}에 업로드(Push)'**
  String jobPush(String remote);

  /// No description provided for @jobPublish.
  ///
  /// In ko, this message translates to:
  /// **'{branch} 처음 올리기(Publish)'**
  String jobPublish(String branch);

  /// No description provided for @jobFetch.
  ///
  /// In ko, this message translates to:
  /// **'{remote} 변경 확인(Fetch)'**
  String jobFetch(String remote);

  /// No description provided for @resultSent.
  ///
  /// In ko, this message translates to:
  /// **'버전 {count}개 업로드 완료'**
  String resultSent(int count);

  /// No description provided for @resultReceived.
  ///
  /// In ko, this message translates to:
  /// **'새 버전 {count}개 다운로드 완료'**
  String resultReceived(int count);

  /// No description provided for @resultUpToDate.
  ///
  /// In ko, this message translates to:
  /// **'이미 최신 상태입니다'**
  String get resultUpToDate;
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
