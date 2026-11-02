# GitHub+ 기획서 v1.0 — 새 뼈대 + 필요한 것만 이식

- 작성일: 2026-11-02
- 변경 배경: v0.3은 GitHub Desktop을 통째로 fork해서 고치는 방식이었다. 실제로 해 보니 앱 코드 약 17만 줄, 의존성 50개 이상(Copilot SDK, xterm, CodeMirror 등)을 그대로 떠안게 되어 **"필요한 기능만 최적화해서 가져오기"라는 원래 의도와 맞지 않았다**.
- v1.0 방향: **새 뼈대를 처음부터 짜고, GitHub Desktop(MIT)에서 검증된 Git 처리 코드만 골라 이식**한다. 화면, 허브, i18n은 처음부터 새로 만든다.
- 목표 규모: 앱 코드 2~3만 줄, 런타임 의존성 15개 이하.

---

## 1. 기능 범위 (확정)

### 1.1 넣는 기능
| 분류 | 기능 |
|---|---|
| 기본 Git | 저장소 추가·생성·복제(clone), 변경 사항(스테이징·부분 스테이징·버리기), 커밋, diff, 히스토리, 브랜치(생성·전환·이름 변경·삭제), push·pull·fetch |
| 병합 | merge, 충돌 파일 목록·해결(내 것/상대 것 선택, 외부 수정 후 완료 처리), merge 중단 |
| 임시 저장 | stash 만들기·적용·버리기·목록 |
| 되돌리기 | revert, 마지막 커밋 수정(amend), 커밋 취소(undo), 태그 생성·삭제 |
| 고급 히스토리 편집 | rebase, squash, cherry-pick, 커밋 순서 바꾸기 |
| **로컬 허브** | 내부망 Git 서버(호스트 모드), 허브 찾기·clone·게시(클라이언트), 히스토리 보존, 허브 히스토리 보기 |
| GitHub.com 연동 | 로그인, 내 저장소 목록에서 clone, 새 저장소로 게시. **PR·체크런·이슈·알림 같은 무거운 연동은 넣지 않는다** |
| AI 커밋 메시지 | 스테이징된 변경을 보고 커밋 메시지 초안 생성(Claude 또는 OpenAI 호환, 사용자 API 키) |
| Git LFS·서브모듈 | LFS 추적 파일 처리, 서브모듈 상태 표시·업데이트 |
| 편의 | 파일·폴더 드래그&드롭 → 저장소에 복사 → 커밋·푸시 |
| UI | 한국어 기본/영어 전환, 라이트·다크 테마, 새 레이아웃(2장) |

### 1.2 넣지 않는 기능
GitHub Enterprise, PR·체크런·이슈 자동완성·알림, Copilot 계열, 외부 에디터·터미널·탐색기 열기, 내장 터미널, 튜토리얼·배너·릴리스 노트·약관, 시크릿 스캔, 사용 통계·오류 보고, 자동 업데이트(나중에 별도 검토), 워크트리, CLI 명령.

## 2. 화면 구성 (사용자 불편 반영)

사용자가 꼽은 불편: ① 저장소 전환이 불편 ② 히스토리가 보기 어려움 ③ 툴바·버튼 배치.

```
┌───────────────────────────────────────────────────────────────┐
│ [브랜치 ▾ main]  [↓ 풀 2] [↑ 푸시 1] [⟳ 가져오기]   허브 ● 연결됨 │ ← 툴바: 현재 저장소 작업만
├──────────────┬────────────────────────────────────────────────┤
│ 저장소        │ [변경 사항] [히스토리]                            │
│ ▸ 로컬        │ ┌──────────────┬───────────────────────────────┐│
│   GitHubPlus ●│ │ 파일/커밋 목록 │ diff / 커밋 상세                ││
│   mod-server  │ │ (히스토리는   │                               ││
│ ▸ 허브(사무실)│ │  커밋 그래프) │                               ││
│   team-api    │ │              │                               ││
│ ▸ GitHub      │ ├──────────────┤                               ││
│   ...         │ │ 커밋 입력창    │                               ││
│ [+ 추가]      │ └──────────────┴───────────────────────────────┘│
└──────────────┴────────────────────────────────────────────────┘
```

- ① **저장소 사이드바**: 항상 보이는 왼쪽 목록. 로컬/허브/GitHub 그룹, 변경·동기화 상태 배지, 검색(Ctrl+P), 즐겨찾기 고정.
- ② **히스토리 = 커밋 그래프**: 브랜치 흐름을 선(레인)으로 그리는 그래프 뷰. 커밋을 누르면 오른쪽에 파일 목록·diff. 그래프에서 바로 체리픽·되돌리기·태그(우클릭 메뉴).
- ③ **툴바**: 현재 저장소의 브랜치·동기화(풀/푸시 개수 표시)·허브 상태만 둔다. 앱 전체 기능은 메뉴와 커맨드 팔레트(Ctrl+K)로.
- 디자인 시안은 N6 전에 2~3안을 만들어 고른다. 그 전 단계는 기본 토큰(색·간격·타이포)만 정해서 일관되게 만든다.

## 3. 기술 구성

| 항목 | 선택 | 이유 |
|---|---|---|
| 셸 | Electron (최신 안정판) | 원본과 같은 플랫폼, dugite 재사용 |
| 빌드 | electron-vite (main / preload / renderer) | 원본의 webpack 다중 설정보다 단순·빠름. 한글 경로 문제를 일으킨 yarn 중첩 호출 제거 |
| UI | React 19 + TypeScript strict | 원본(React 16)보다 최신 |
| 상태 | Zustand | 원본의 7,800줄짜리 app-store 대신 기능별 작은 스토어 |
| 스타일 | CSS 변수 토큰 + CSS Modules | 테마 전환이 쉽고 의존성 없음 |
| Git | dugite (Git 번들) + 원본 `lib/git` 이식 | 검증된 명령 조합·파서 재사용 |
| 보안 | `contextIsolation: true`, `nodeIntegration: false`, 타입 지정된 preload 브리지 | 원본은 renderer에서 Node를 직접 씀. 새 앱은 renderer에 Node 노출 안 함 |
| 비밀값 저장 | Electron `safeStorage`로 암호화한 파일 | keytar(유지보수 중단)·네이티브 모듈 제거 |
| Git 인증 | GIT_ASKPASS 도우미 스크립트 → main 프로세스에서 자격 증명 제공 | 원본의 네이티브 trampoline 모듈 제거 |
| GitHub 로그인 | OAuth **Device Flow** | client secret이 필요 없어 public 저장소에 비밀값을 둘 일이 없음 |
| 패키징 | electron-builder (NSIS 설치 파일) | Squirrel 대신 단순한 설치·제거 |
| 테스트 | Vitest(단위) + Playwright for Electron(E2E) | |
| 패키지 관리 | npm (lockfile 커밋) | 워커가 `npm.cmd`로 일관되게 사용 |

- **네이티브 모듈 0개**가 목표다. 그러면 Visual Studio Build Tools 없이도 설치·빌드된다.
- 구조: Git 명령과 허브 서버는 main 프로세스(무거운 작업은 utilityProcess)에서 실행한다. renderer는 IPC로 요청만 한다.

```
src/
  main/            # 앱 수명주기, 창, 메뉴, IPC 등록
    git/           # 원본 lib/git 이식 (dugite 호출 + 파서)
    hub/           # 로컬 허브 서버 (Smart HTTP, 발견, 푸시 기록)
    github/        # Device Flow 로그인, 저장소 목록·게시
    ai/            # 커밋 메시지 생성
    store/         # 설정·저장소 목록·비밀값(safeStorage)
  preload/         # contextBridge로 타입 지정 API 노출
  shared/          # IPC 계약 타입, 모델(Repository, Commit, Status, Diff...), i18n 사전
  renderer/        # React 화면 (sidebar, toolbar, changes, history, dialogs...)
```

## 4. 원본에서 이식할 것 (MIT 고지 유지)

| 원본 | 대상 | 비고 |
|---|---|---|
| `app/src/lib/git/*` 중 필요한 것 | `src/main/git/` | core, status, diff, log, branch, checkout, commit, fetch/pull/push, clone, remote, config, merge, merge-tree, rebase, cherry-pick, squash, reorder, revert, reset, stash, tag, lfs, submodule, apply, stage, update-index, rev-parse, rev-list, for-each-ref, gitignore 등. **worktree·interpret-trailers(코파일럿용)·format-patch 등은 제외** |
| `app/src/lib/diff-parser.ts`, `status-parser.ts`, `patch-formatter.ts` | `src/main/git/` | 부분 스테이징에 필요 |
| `app/src/models/` 중 Git 모델 | `src/shared/models/` | repository, commit, branch, status, diff, remote, stash, tag, progress, conflicts |
| `app/src/lib/progress/` | `src/main/git/progress/` | clone·fetch·push 진행률 파싱 |
| 우리가 M0에서 만든 `app/src/lib/i18n/` | `src/shared/i18n/` | 그대로 재사용 |
| 해당 파일들의 단위 테스트 | `tests/` | Vitest로 변환 |

- 이식 원칙: 그대로 복사하지 말고 **새 구조에 맞게 정리**한다(전역 상태·Electron 의존 제거, 순수 함수화). 원본 테스트를 함께 옮겨 동작이 같음을 확인한다.
- `LICENSE`에 원본 저작권 고지("Copyright (c) GitHub, Inc.")와 GitHub+ 고지를 함께 둔다. `NOTICE.md`에 이식한 파일 목록을 남긴다.
- 화면 컴포넌트는 이식하지 않는다(새로 만듦). diff 화면은 원본을 참고해 가볍게 새로 만들고, 문법 강조는 N6에서 선택 사항으로 둔다.

## 5. 로컬 허브 (v0.3에서 확정한 내용 유지)

- 호스트 PC의 앱이 main 프로세스 HTTP 서버로 Git Smart HTTP를 제공한다(dugite의 `git upload-pack` / `git receive-pack --stateless-rpc` 직접 연결). 일반 git CLI로도 접속할 수 있다.
- **인증 없음**: 사설 IP 대역과 localhost만 허용한다.
- **히스토리 보존**: `receive.denyNonFastForwards=true`, `receive.denyDeletes=true`, `gc.reflogExpire=never`. 삭제는 호스트 화면에서만, 저장소 삭제는 휴지통으로.
- **푸시 기록**: 시각·저장소·브랜치·이전/새 커밋·접속 PC(IP·호스트명).
- 클라이언트: mDNS/UDP로 허브 자동 발견 + IP 직접 입력, 사이드바 "허브" 그룹, 허브 저장소 히스토리 보기(clone 없이), 허브에 게시.
- 트레이 상주, 윈도우 시작 시 자동 실행(선택), 방화벽 안내.

## 6. GitHub.com·AI

- **GitHub 로그인**: OAuth Device Flow(브라우저에 코드 입력). GitHub+ 전용 OAuth App의 client id만 코드에 넣고, secret은 쓰지 않는다. 토큰은 safeStorage에 저장한다.
- GitHub 기능은 "내 저장소 목록 → clone", "로컬 저장소 → GitHub에 새 저장소로 게시" 두 가지만.
- **AI 커밋 메시지**: 스테이징된 diff 요약을 보내 커밋 메시지 초안을 받는다. 공급자 인터페이스를 두고 **Claude API와 OpenAI 호환 API(주소·키·모델 지정, 로컬 LLM 포함) 둘 다** 지원한다. 환경설정에서 공급자를 고르고 키는 safeStorage에 저장한다. Claude 모델은 구현 시점 최신으로 정한다. 보내기 전에 어떤 내용이 전송되는지 사용자에게 보여 주고, 설정이 없으면 기능을 숨긴다.

## 7. 저장소 전환 계획 (확정: 깨끗한 히스토리로 교체)

1. 현재 fork의 `main`을 원격에 `legacy-fork` 브랜치로 보관한다(이식 참고용).
2. 로컬 폴더 `GitHub+`를 `GitHubPlus-legacy`로 이름 바꿔 참고용으로 둔다(node_modules·빌드 결과 유지 → 원본 동작 비교 실행 가능).
3. 새 폴더 `GitHub+`에 새 저장소를 만들고, N0 결과를 첫 커밋으로 `git-hub-plus/GitHubPlus`의 `main`에 **force push**한다.
4. 원격 기본 브랜치는 `main`(새 앱) 그대로.

## 8. 단계 (마일스톤)

| 단계 | 내용 | 완료 기준 |
|---|---|---|
| **N0 뼈대·계약** | electron-vite 프로젝트, 보안 설정, 타입 IPC 계약(`shared/ipc.ts`), 모델 타입, i18n 이식, 디자인 토큰, 레이아웃 껍데기(사이드바·툴바·탭), lint·test·빌드 스크립트, LICENSE/NOTICE | `npm run dev`로 빈 레이아웃이 한/영 전환되며 뜸, 단위 테스트·타입 검사 통과, 네이티브 모듈 0개 |
| **N1 Git 코어** | `lib/git` 이식(1차: status·diff·commit·log·branch·checkout·remote·config·fetch/pull/push·clone) + 진행률, 저장소 목록 저장 | 이식한 원본 테스트 통과, 실제 저장소로 상태 조회·커밋·푸시 |
| **N2 기본 화면** | 사이드바(로컬), 변경 사항(부분 스테이징 포함)·커밋 입력, diff 뷰, 히스토리(커밋 그래프), 브랜치 메뉴, 동기화 버튼, clone·추가·생성 대화상자 | 앱만으로 일상 작업(수정→커밋→푸시→다른 브랜치) 가능 |
| **N3 로컬 허브** | 허브 서버·히스토리 보존·푸시 기록, 발견, 허브 그룹·게시·허브 히스토리 보기, 트레이 | 두 PC(또는 VM)에서 clone·push·pull, force push·삭제 거부 확인 |
| **N4 고급 Git** | merge·충돌 해결, stash, revert·amend·undo·태그, rebase·squash·cherry-pick·순서 바꾸기 | 각 기능 E2E 시나리오 통과 |
| **N5 연동·편의** | GitHub Device Flow 로그인·clone·게시, AI 커밋 메시지, LFS·서브모듈, 드래그&드롭 업로드, 커맨드 팔레트 | 기능별 E2E 통과 |
| **N6 마감** | 디자인 시안 선택·적용, 문법 강조(선택), 접근성 점검, electron-builder 설치 파일, 성능(대형 저장소) 점검 | 설치 파일로 깨끗한 PC에 설치·실행 |

- 병렬화: **N0(뼈대·계약)은 직렬로 먼저 확정**한다. 이후 N1의 Git 이식은 명령 묶음별로, N2의 화면은 영역별로 여러 워커가 동시에 진행한다(계약 파일만 공유, 담당 파일은 겹치지 않게).
- 각 단계는 타입 검사·단위 테스트·해당 E2E를 통과해야 완료로 본다.

## 9. 리스크

- **커밋 그래프 성능**: 커밋 수만 개 저장소에서 레인 계산·렌더링. 가상 스크롤 + 점진 로딩으로 대응.
- **부분 스테이징·충돌 해결의 정확도**: 원본 로직과 테스트를 그대로 이식해서 동작을 맞춘다.
- **Git 인증(askpass) 다양성**: HTTPS 토큰, SSH 키, 허브(인증 없음)를 모두 처리해야 한다. 원본 trampoline 동작을 참고해 시나리오별 테스트를 둔다.
- **이식 범위가 커질 위험**: 4장 표에 없는 원본 파일을 가져오려면 이유를 기획서에 먼저 적는다.
