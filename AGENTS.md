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
