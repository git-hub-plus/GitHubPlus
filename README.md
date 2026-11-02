# GitHub+

가볍고 빠른 Git 데스크톱 클라이언트입니다. 내부망 **로컬 허브**를 지원하고, 화면은 한국어가 기본입니다.

> GitHub+는 GitHub, Inc.와 관련 없는 독립 프로젝트입니다. Git 처리 코드 일부는
> [GitHub Desktop](https://github.com/desktop/desktop)(MIT)에서 이식했습니다. 자세한 내용은 [NOTICE.md](NOTICE.md)를 보세요.

## 특징

- **필요한 기능만**: 변경 사항·커밋·diff·히스토리(커밋 그래프)·브랜치·동기화, 병합·충돌 해결, stash, 되돌리기, rebase·squash·cherry-pick
- **로컬 허브**: 내부망 PC 한 대가 Git 서버가 되어 여러 PC가 GitHub 없이 push·pull. 히스토리 덮어쓰기는 서버가 막습니다.
- **새 레이아웃**: 항상 보이는 저장소 사이드바, 현재 저장소 작업만 모은 툴바
- GitHub.com 로그인·clone·게시, AI 커밋 메시지(Claude / OpenAI 호환), Git LFS·서브모듈
- 한국어 / English 전환, 라이트·다크 테마
- 네이티브 모듈 없음 → Visual Studio Build Tools 없이 설치·빌드

기획과 진행 단계는 [PLAN.md](PLAN.md)에 있습니다.

## 개발

Node.js 24 이상이 필요합니다.

```shell
npm install      # 의존성 설치 (Git은 dugite가 내려받음)
npm run dev      # 개발 실행 (변경 사항 자동 반영)
npm run check    # 타입 검사 + 린트 + 단위 테스트
npm run build    # 프로덕션 빌드 (out/)
```

## 라이선스

[MIT](LICENSE)
