# 화면 용어집 (한국어)

용어 표시는 설정 > **용어 표시**에서 두 가지 중 고른다. 코드 기준은 `lib/l10n/terms.dart`의 `Terms`.

| 모드 | 대상 | 화면 예 |
|---|---|---|
| 쉬운 말 (기본) | Git이 처음인 분 | `업로드 3`, `버전 4개 업로드 완료` |
| Git 용어 | GitHub 사용자 | `푸시 3`, `커밋 4개 푸시 완료` |

- 문장은 ARB에 `{push}`, `{commitUnit}`처럼 자리표시자로 두고, 호출하는 쪽에서 `Terms.of(context)` 값을 넣는다.
- 쉬운 말 모드의 HUD 툴팁에는 `Git 용어: 푸시 (Push)`를 함께 적어, 문서나 검색에서 쓰는 이름을 알 수 있게 한다.
- 영어 화면도 같은 두 모드를 쓴다(예: `Upload` ↔ `Push`).

아래 표의 "쉬운 말" 열이 쉬운 말 모드, 괄호 안이 Git 용어다. Git 용어 모드의 한국어 표기는 커밋·푸시·풀·페치·게시·클론·브랜치·스태시·리모트·히스토리.

| Git 용어 | 한국어 표기 | 메모 |
|---|---|---|
| Commit | 버전 저장(Commit) | 개수는 "버전 N개" |
| Push | 업로드(Push) | "업로드 대기" = 아직 올리지 않은 버전 |
| Pull | 다운로드(Pull) | "다운로드 대기" = 아직 받지 않은 버전 |
| Fetch | 변경 확인(Fetch) | 받기만 하고 합치지 않음 |
| Publish | 처음 올리기(Publish) | 원격에 없는 작업 갈래를 처음 업로드 |
| Clone | 내려받기(Clone) | |
| Branch | 작업 갈래(Branch) | |
| Merge | 합치기(Merge) | |
| Conflict | 충돌(Conflict) | |
| Stash | 임시 보관(Stash) | |
| Remote | 원격 저장소(Remote) | |
| Repository | 저장소 | |
| History / Log | 버전 기록(History) | |
| Diff | 바뀐 내용 | |
| Revert | 되돌리기(Revert) | |
| Reset / Undo commit | 저장 취소 | |
| Amend | 마지막 버전 고치기(Amend) | |
| Rebase | 기준 옮기기(Rebase) | |
| Cherry-pick | 골라 가져오기(Cherry-pick) | |
| Squash | 하나로 합치기(Squash) | |
| Tag | 꼬리표(Tag) | |
| Hub (GitHub+) | 로컬 허브 | 내부망 Git 서버 |
| 파견(작업 진행 카드) | 작업 현황 | 오래 걸리는 작업을 카드로 보여 주는 탭 |
