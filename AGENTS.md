# GitHub+ 개발 규칙 (Flutter)

기획은 `PLAN.md`(v2.0)가 기준이다. v1(Electron)은 원격 `electron` 브랜치에 있고, 로직·테스트 기대값의 참고 자료로만 쓴다.

## 구조

| 위치 | 역할 | 규칙 |
| --- | --- | --- |
| `lib/core/` | Git·허브·저장소 로직, 모델 | Flutter 위젯 import 금지. `flutter test test/core`로 단위 테스트 |
| `lib/core/git/` | Git 실행기와 명령 (v1·GitHub Desktop 이식) | 이식 파일 맨 위에 원본 경로 주석, `NOTICE.md`에 한 줄 |
| `lib/state/` | Riverpod 공급자 | 화면 상태와 core 호출을 잇는다 |
| `lib/features/` | 화면 단위 위젯 | 색·간격은 `lib/ui/theme.dart`의 `context.colors`, `Space`, `Radii`만 사용 |
| `lib/ui/` | 디자인 시스템(테마, HUD, 게이지, 알림) | |
| `lib/l10n/` | ARB 번역 (ko 기준) | 화면 문자열은 전부 여기. 한국어 표기는 `docs/GLOSSARY.md` 규칙(`업로드(Push)`) |
| `test/` | 단위·위젯 테스트 | Git을 쓰는 테스트는 `test/core/git/helpers.dart`의 임시 저장소 사용, 전역 git 설정 변경 금지 |

## 명령

```shell
python tool/vendor_git.py        # 포터블 Git 준비 (처음 한 번)
flutter gen-l10n                 # ARB 수정 후
flutter test                     # 테스트
flutter build windows --debug    # 빌드 → build/windows/x64/runner/Debug/GitHubPlus.exe
```

- `flutter analyze` 전체 실행은 이 PC에서 분석 서버가 죽으므로 `dart analyze lib`, `dart analyze test`로 나눠 실행한다.
- 애니메이션은 `context.motion(...)`을 거쳐 "애니메이션 줄이기"를 따른다. 0.2~0.4초 이내, 흔들림·소리 없음.

## 보안 규칙

- Git은 `GitRunner`로만 실행한다. 기본으로 `core.fsmonitor=false`가 붙는다. 저장소의 `.git/config`가 명령을 실행하지 못하게 하려는 것이다.
- 사용자·원격이 정한 값(URL, ref, 경로)을 Git 인수로 넘길 때는 `--`나 `--end-of-options`로 옵션과 분리한다. ref는 `-`로 시작하면 거부한다.
- 나중에 diff를 붙일 때는 `--no-ext-diff --no-textconv`를 쓴다.
- 오류·알림·로그에 URL을 보여 줄 때는 `redactCredentials`를 거친다. 토큰은 `GitAuthProvider`로만 넘기고 인수에 넣지 않는다.
- 저장소 내용을 읽을 때는 `normalizeRepoPath`를 거친다(`..`, 절대 경로, `.git` 거부). 화면에 링크를 열 때는 http·https·mailto만 허용한다.
- 외부 프로그램은 절대 경로로 실행한다(예: `%SystemRoot%\explorer.exe`). 이름만 쓰면 Windows가 현재 폴더부터 찾는다.
- 비밀값(토큰·API 키)은 저장소에 커밋하지 않는다. OAuth client id는 환경 변수, 저장은 DPAPI.

