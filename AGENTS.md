# GitHub+ 개발 규칙 (사람·AI 워커 공통)

기획은 `PLAN.md`가 기준이다. 범위(1장)·이식 목록(4장)에 없는 기능이나 원본 파일을 추가하려면 먼저 PLAN.md에 이유를 적는다.

## 구조

| 위치 | 역할 | 규칙 |
| --- | --- | --- |
| `src/main/` | Electron main 프로세스: 창, 메뉴, IPC 핸들러, git, 허브, 저장소 | Node·Electron 사용 가능 |
| `src/main/git/` | GitHub Desktop `app/src/lib/git` 이식 | 전역 상태 없이 순수 함수 위주. 파일 맨 위에 원본 경로 주석 |
| `src/preload/` | `window.ghp` 브리지 하나만 노출 | 로직을 넣지 않는다 |
| `src/shared/` | IPC 계약, 데이터 모델, i18n | main·renderer 양쪽에서 import. **Node·DOM API 금지** |
| `src/renderer/src/` | React 화면 | Node·Electron·dugite import 금지(ESLint가 막음). main 호출은 `ipc.ts`의 `invoke`/`subscribe`만 |
| `tests/` | Vitest 단위 테스트 (`tests/main`, `tests/shared`, `tests/renderer`) | renderer 테스트는 첫 줄에 `// @vitest-environment jsdom` |

## IPC 계약

- 채널과 이벤트는 `src/shared/ipc/*.ts`에 타입으로 정의한다. 새 도메인(hub, github, ai, 고급 git 등)은 **새 파일**을 만들고 `src/shared/ipc/index.ts`의 `IpcContract`/`IpcEventMap`에 한 줄씩 추가한다.
- IPC로 오가는 값은 **평범한 데이터**(클래스 인스턴스 금지, structured clone 가능)만 쓴다. 모델은 `src/shared/models/`.
- main 핸들러는 `src/main/ipc.ts`의 `handle()`로 등록한다. 실패를 특정 종류로 알리려면 `HandlerError(kind, message, detail)`을 던진다. renderer에서는 `GhpError.kind`로 받는다.
- 오래 걸리는 작업(clone/fetch/pull/push/checkout)은 `opId`를 받고 `git:progress` 이벤트로 진행률을 보낸다.

## 원본(GitHub Desktop) 이식 규칙

- 참고용 원본: `../GitHubPlus-legacy/app/src/` (같은 PC), 원격 `legacy-fork` 브랜치.
- 그대로 복사하지 말고 새 구조에 맞게 정리한다: 클래스 모델 → `src/shared/models`의 평범한 데이터, `Repository` 객체 → 저장소 경로 문자열, Electron/전역 의존 제거.
- 이식한 파일 맨 위에 `// Ported from GitHub Desktop (MIT): app/src/lib/git/xxx.ts` 주석을 달고, `NOTICE.md` 표에 한 줄 추가한다.
- 원본의 해당 단위 테스트도 Vitest로 옮겨 같은 동작을 확인한다. 테스트용 임시 저장소는 OS 임시 폴더에 만들고 끝나면 지운다.

## 문자열·스타일

- 화면 문자열은 전부 `t('key')`. 키는 `src/shared/i18n/locales/ko.ts`(기준)와 `en.ts`에 같이 추가한다(빠지면 컴파일 에러). 용어는 `src/shared/i18n/GLOSSARY.md`.
- 색·간격·글꼴은 `src/renderer/src/styles/tokens.css`의 CSS 변수만 쓴다. 컴포넌트 스타일은 CSS Modules(`*.module.css`).
- 상태는 Zustand 스토어를 기능별로 작게 나눈다(`src/renderer/src/state/`).

## 검증 (작업을 끝내기 전에 반드시)

```shell
npm run typecheck
npm run lint
npm test            # 또는 관련 파일만: npx vitest run tests/main/git/status.test.ts
npx prettier --check <바꾼 파일>
```

- Windows에서는 `npm.cmd` / `npx.cmd`로 실행한다(PowerShell).
- 의존성을 추가할 때는 이유를 적는다. 런타임 의존성은 15개 이하를 유지하고, **네이티브 모듈은 추가하지 않는다**.
