# GitHub+ 기획서 (초안 v0.3)

- 작성일: 2026-11-02 (v0.2: 앱 이름 GitHub+ 확정, 독립 앱으로 방향 전환 / v0.3: 원본 코드 기반 확정, i18n, 허브 무인증+히스토리 보존, public 저장소)
- 앱 이름: **GitHub+**
- 기반: `desktop/desktop` (`development` 브랜치, `952326e87`) — Electron 44 · TypeScript · React 16 · dugite(Git 번들) · MIT
- 성격: GitHub Desktop의 업데이트판이 아니라 **별개의 새 앱**. 원본 코드는 출발점으로만 쓰고, 정체성(이름·아이콘·식별자·데이터 폴더)은 완전히 분리한다. 업스트림은 추적하지 않고, 보안 수정만 필요할 때 골라서 반영한다.

---

## 1. 목표

1. **로컬 허브(내부망 Git 서버)**: 내부망 PC 한 대를 호스트로 두고, 여러 클라이언트 PC가 GitHub 없이 그 호스트에 push·pull·clone한다. 별도 서버 프로그램 없이 **같은 앱**이 호스트 모드와 클라이언트 모드를 모두 담당한다.
2. **UI/UX 개량**: 한국어화, 테마·디자인 리뉴얼, 레이아웃 재구성, 드래그&드롭 업로드 같은 편의 기능.
3. 기존 GitHub.com 연동 기능은 **유지**한다(제거 대상 아님).

## 2. 로컬 허브

### 2.1 구성

```
[호스트 PC] GitHub+ (허브 모드 ON)
   ├─ main-process 안의 HTTP Git 서버 (기본 포트 예: 8765, 설정 가능)
   ├─ 허브 저장소 폴더: <허브 루트>/<저장소명>.git  (bare 저장소)
   ├─ 푸시 기록(JSON Lines): 시각·저장소·브랜치·이전/새 커밋·접속 PC(IP·호스트명)
   └─ 허브 정보 API (/api/repos 등: 저장소 목록·브랜치·커밋 히스토리)
        ▲  http://<호스트IP>:<포트>/<저장소명>.git
        │  (Git Smart HTTP, 인증 없음)
[클라이언트 PC들] GitHub+ (또는 일반 git CLI)
```

- **Git 프로토콜 구현 방식**: Node HTTP 서버가 Git Smart HTTP 요청을 받아 dugite에 번들된 `git upload-pack` / `git receive-pack --stateless-rpc`를 직접 실행해 연결한다. `git-http-backend`나 Gitea 같은 외부 서버를 번들하지 않아도 되고, 일반 git CLI·VS Code 등 다른 도구로도 그대로 접속할 수 있다.
  - 대안: `git daemon`(히스토리 보호 훅·푸시 기록을 붙이기 어려움), Gitea 내장(무겁고 관리 포인트가 늘어남).
- **접근: 인증 없음(확정)**. 내부망 전제로 같은 네트워크의 누구나 clone·push할 수 있다. 계정·권한 체계는 만들지 않는다.
  - 커밋 작성자는 각 PC의 git `user.name`이 그대로 기록된다(자기 신고). 허브는 푸시 기록에 **접속 PC의 IP·호스트명**을 남겨서 누가 올렸는지 추적할 수 있게 한다.
  - 접속 허용 범위 옵션: 기본은 사설 IP 대역(10.x, 172.16–31.x, 192.168.x)과 localhost만 허용한다. 공인 IP에서 오는 요청은 거부한다.
- **전송**: HTTP. 내부망 전용이다.

### 2.2 버전 히스토리 보존 (필수)

인증이 없어서 누구나 push할 수 있으므로, 실수나 악의로 **이전 코드가 사라지지 않게** 서버가 강제한다.

- **덮어쓰기 금지**: 모든 허브 저장소에 `receive.denyNonFastForwards=true`, `receive.denyDeletes=true`를 설정한다. force push와 브랜치·태그 삭제는 서버가 거부하고, 거부 사유를 클라이언트에 한국어로 보여 준다.
- **가비지 컬렉션 억제**: `gc.reflogExpire=never`, `core.logAllRefUpdates=true`를 설정해서 서버 쪽 ref 변경 이력도 영구 보존한다.
- **삭제는 호스트에서만**: 브랜치·저장소 삭제는 호스트 PC의 허브 관리 화면에서만 할 수 있다. 저장소를 삭제하면 바로 지우지 않고 허브 휴지통 폴더로 옮긴다.
- **히스토리 보기**: 앱에서 허브 저장소의 브랜치별 커밋 목록, 커밋별 변경 파일·diff, 특정 시점 파일 내용을 볼 수 있다. clone하지 않아도 허브 API로 조회하고, 특정 버전을 그대로 받거나(체크아웃·zip) 되돌리는(revert 커밋) 동작을 제공한다.
- **백업(선택)**: 허브 전체를 주기적으로 다른 폴더나 드라이브에 미러링(`git bundle`)하는 옵션.

### 2.3 호스트 기능

- 환경설정에 **"로컬 허브" 탭**: 허브 켜기/끄기, 포트, 허브 루트 폴더, 접속 주소 표시(IP·QR), 백업 설정.
- 허브 관리 화면: 저장소 생성·이름 변경·삭제(휴지통), 푸시 기록 조회, 접속 PC 목록.
- **트레이 상주**: 창을 닫아도 서버가 계속 돌도록 트레이 아이콘으로 상주하고, 윈도우 시작 시 자동 실행을 선택할 수 있게 한다.
- Windows 방화벽 인바운드 허용 안내(처음 켤 때 1회).
- 호스트 PC의 사용자도 자기 허브(`localhost`)를 일반 클라이언트처럼 clone해서 작업한다.

### 2.4 클라이언트 기능

- **허브 찾기**: 같은 내부망에서 mDNS/UDP 브로드캐스트로 허브를 자동 발견하고, IP:포트 직접 입력도 지원한다.
- **클론 대화상자에 "로컬 허브" 탭**: 허브 저장소 목록에서 골라 바로 clone한다(현재 GitHub.com / Enterprise / URL 탭 옆).
- **"허브에 게시"**: 로컬 저장소를 허브에 새 저장소로 만들고 push한다(원본의 "Publish repository"와 같은 흐름).
- 허브 연결 상태 표시: 연결됨/오프라인, push 거부(덮어쓰기 금지) 안내.

### 2.5 미정

- [ ] 허브 동시 사용 규모(클라이언트 몇 대?) → 단일 Node 서버로 충분한지 판단
- [ ] 이슈·코드 리뷰(PR) 같은 협업 기능 → MVP 범위 밖, 나중에 검토

## 3. UI/UX 개량

### 3.1 다국어(i18n) — 한국어 기본, 영어 전환 (확정)

- 원본에는 i18n 체계가 없다. 문자열은 `app/src/ui/**`(TSX)와 `app/src/main-process/menu/`(메뉴)에 직접 박혀 있다.
- **방식**: `t('key')` 기반 i18n 레이어를 도입한다.
  - 번역 파일: `app/src/locales/ko.ts`, `en.ts`. 키를 TypeScript 타입으로 묶어서 **빠진 키나 오타는 컴파일 에러**가 나게 한다.
  - renderer(React)와 main-process(메뉴·트레이·네이티브 대화상자) 양쪽에서 같은 번역 파일을 쓴다.
  - 기본 언어는 한국어, 환경설정에서 English로 전환할 수 있다. 메뉴는 전환 즉시 다시 그리고, 나머지 화면은 재시작 없이 반영되는 것을 목표로 한다.
  - 라이브러리: 자체 경량 모듈(의존성 없음)과 i18next 중 M0에서 결정한다. 타입 안전성과 번들 크기를 기준으로 본다.
- **원칙**: i18n 기반은 M0에서 먼저 깔고, 이후 새로 만드는 UI(허브·드래그&드롭 등)는 처음부터 `t()`로 작성한다. 기존 화면 문자열 전환은 M5에서 일괄 처리한다.
- 날짜·숫자 포맷(`format-date.ts`, `format-relative.ts`)은 선택한 언어의 로케일(`ko-KR`/`en-US`)을 따른다.
- Git 용어 표기 원칙(예: commit=커밋, push=푸시, branch=브랜치, stash=임시 저장)을 용어집으로 고정한다.

### 3.2 테마·디자인 리뉴얼

- 테마 변수는 `app/styles/_variables.scss`와 `app/styles/themes/_dark.scss`에 있다. 색상·타이포·간격 토큰을 새로 정의해서 라이트·다크를 모두 갈아끼운다.
- 한글 가독성을 위한 기본 폰트 지정(예: Pretendard 번들 또는 시스템 Malgun Gothic 폴백).
- 디자인 방향(미니멀/고밀도/카드형 등)은 시안 2~3개를 만들어 고른다.

### 3.3 레이아웃 재구성 (구체안 필요)

후보:
- 저장소 목록을 드롭다운에서 **항상 보이는 왼쪽 사이드바**로 바꾸고, 허브 저장소도 같은 목록에 그룹으로 표시
- 변경사항·히스토리 탭을 한 화면에 통합하거나 커밋 그래프 뷰 추가
- 상단 툴바 재배치(브랜치·동기화·허브 상태)

→ **현재 원본에서 불편한 점을 사용자에게 받아서** 확정한다.

### 3.4 편의 기능

- **드래그&드롭 업로드**: 열려 있는 저장소 창에 파일·폴더를 끌어다 놓으면
  1. 저장소 안 어느 경로에 넣을지 선택(기본: 루트 또는 현재 선택한 폴더)
  2. 작업 폴더로 복사 → 변경사항 목록에 바로 표시
  3. 옵션: "커밋 메시지 입력 → 커밋 → 푸시"를 한 번에
  - 원본에도 `app.tsx`에 드롭 처리가 있지만, **Git 저장소 폴더를 저장소로 추가하는 용도**뿐이다. 저장소가 아닌 파일 드롭은 새 흐름으로 분기한다.
- 그 밖의 후보(우선순위는 나중에 결정): 커맨드 팔레트(Ctrl+K), 단축키 확장, 확인창 줄이기

## 4. GitHub+ 정체성 분리 (필수)

- **표시 이름과 내부 이름 분리**: 화면·창 제목·바로가기 이름은 `GitHub+`로 하고, 파일명·식별자처럼 기계가 읽는 곳에는 `+` 없는 `github-plus`/`GitHubPlus`를 쓴다(`+`가 URL·설치 프로그램·셸에서 문제를 일으키지 않게).

  | 항목 | 위치 | 원본 | GitHub+ (안) |
  |---|---|---|---|
  | 표시 이름 | `app/package.json` `productName` | GitHub Desktop | GitHub+ |
  | 패키지 이름 | `app/package.json` `name` | desktop | github-plus |
  | 앱 ID | `app/package.json` `bundleID` | com.github.GitHubClient | com.devsnowflake.githubplus |
  | 제작자 | `companyName`, `author` | GitHub, Inc. | Dev-Snow-flake |
  | 실행 파일 | `script/dist-info.ts` | GitHubDesktop.exe | GitHubPlus.exe |
  | 데이터 폴더 | userData | %APPDATA%\GitHub Desktop | %APPDATA%\GitHub+ (개발 빌드 %APPDATA%\GitHub+-dev) |
  | 프로토콜 | `main.ts`, `script/build.ts` | x-github-client, x-github-desktop-auth | x-github-plus, x-github-plus-auth |
  | 설명 | `description` | Simple collaboration from your desktop | 내부망 허브를 지원하는 Git 데스크톱 클라이언트 (안) |

- 공식 GitHub Desktop과 **동시에 설치·실행**해도 설정, 저장된 계정, 프로토콜 링크가 섞이지 않아야 한다(M0 완료 기준).
- GitHub.com 로그인(OAuth)은 원본의 OAuth 앱 자격 증명을 쓴다. 독립 앱이면 **내 GitHub OAuth App을 따로 등록**해서 교체해야 한다(콜백 프로토콜이 바뀌므로).
- 앱 내 "GitHub Desktop" 문구, 도움말·이슈 신고 링크, 릴리스 노트, 튜토리얼을 GitHub+ 기준으로 교체하거나 제거한다.
- **자동 업데이트 끄기**: `main-process/app-window.ts`의 `autoUpdater`. 켜 두면 공식판이 개량판을 덮어쓴다.
- **사용 통계 전송 끄기**: `lib/stats/stats-store.ts` (central.github.com).
- GitHub+ 전용 아이콘 제작. MIT `LICENSE`와 원저작권 표시는 유지한다(정보 화면의 오픈소스 고지 포함).
- 상표: "GitHub"와 Octocat 로고는 GitHub, Inc.의 상표다. 저장소를 public으로 두므로 **설치 파일을 공개 배포하는 시점에는 이름을 다시 검토**한다. 아이콘에는 Octocat을 쓰지 않는다.
- **원격 저장소: public `git-hub-plus/GitHubPlus`(확정)**. https://github.com/git-hub-plus/GitHubPlus 를 `origin`(main)으로, 원본 `desktop/desktop`은 `upstream` 리모트로 둔다. (처음에는 Dev-Snow-flake/GitHubPlus로 만들었다가 조직으로 이전함)
  - public이므로 **비밀값은 절대 커밋하지 않는다**: OAuth App의 client secret은 빌드 시 환경 변수(`DESKTOP_OAUTH_CLIENT_ID` / `DESKTOP_OAUTH_CLIENT_SECRET` 계열)로만 주입하고, `.env` 파일은 `.gitignore`에 넣는다.
  - README를 GitHub+ 소개로 교체하고, "GitHub Desktop(MIT) 기반 비공식 파생 앱이며 GitHub, Inc.와 무관"하다는 고지를 넣는다.

## 5. 단계 (마일스톤)

| 단계 | 내용 | 완료 기준 |
|---|---|---|
| M0 | 개발 환경·GitHub+ 정체성·i18n 기반 | `yarn` → `yarn build:dev` → `yarn start` 실행, 이름·ID·데이터 폴더 분리, 업데이트·통계 끄기, 공식 GitHub Desktop과 동시 실행 확인, `t()` 레이어 동작(샘플 화면 한/영 전환), public 저장소 생성·첫 push |
| M1 | 로컬 허브 서버(호스트) | 다른 PC의 일반 `git clone/push` 성공, force push·브랜치 삭제 거부 확인, 푸시 기록에 IP·호스트명 남음 |
| M2 | 허브 클라이언트·히스토리 보기 | 앱에서 허브 발견 → clone → 커밋 → push → 다른 PC에서 pull, 허브 저장소 커밋 히스토리·diff 조회와 이전 버전 받기 |
| M3 | 드래그&드롭 업로드 | 파일 드롭 → 커밋·푸시까지 한 흐름으로 동작 |
| M4 | 테마·레이아웃 리뉴얼 | 확정된 시안대로 라이트·다크 적용 |
| M5 | 기존 화면 다국어 전환 | 메뉴·대화상자·오류 메시지 전부 `t()` 경유, 한국어/영어 누락 키 0, 용어집 일치 |

- 순서 근거: i18n 기반을 M0에서 먼저 깔아서 새 UI는 처음부터 다국어로 만든다. 그다음 핵심 가치(허브)를 검증한다. 기존 화면 문자열 전환은 레이아웃이 확정된 뒤 한 번에 처리한다.
- 각 단계는 테스트(`yarn test:unit`, 허브는 실제 2대 또는 VM으로 통합 검증)를 통과해야 완료로 본다.

## 6. 리스크

- **Visual C++ Build Tools 미설치**: 네이티브 모듈 빌드가 실패하면 설치가 필요하다(M0에서 확인).
- **Node 버전**: 원본 권장 v24.22.1, 현재 v24.16.0. 문제가 생기면 맞춘다.
- **호스트 PC가 꺼지면 허브도 중단**: 트레이 상주와 자동 실행으로 완화한다. 백업 정책은 2.4에서 결정한다.
- **업스트림 추적 포기**: 대규모 UI 변경으로 원본 업데이트 병합이 어려워진다. 보안 수정만 골라서 반영한다.
