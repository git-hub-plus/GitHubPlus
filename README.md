# GitHub+

GitHub+는 [GitHub Desktop](https://github.com/desktop/desktop)(MIT)을 출발점으로 만드는
독립 Git 데스크톱 클라이언트입니다. Electron, TypeScript, React로 작성합니다.

> GitHub+는 **비공식 파생 앱**이며 GitHub, Inc.와 아무 관련이 없습니다.
> 공식 GitHub Desktop과 같은 PC에 함께 설치해도 설정과 데이터가 섞이지 않습니다.

## 주요 목표

- **로컬 허브**: 내부망의 PC 한 대를 호스트로 두고, 여러 PC가 GitHub 없이 그 호스트에
  push·pull·clone합니다. 별도 서버 프로그램 없이 같은 앱이 호스트와 클라이언트를 모두 맡습니다.
  누구나 접속할 수 있지만 force push와 브랜치 삭제는 서버가 막아서 버전 히스토리가 보존됩니다.
- **한국어 우선 UI**: 기본 언어는 한국어이고 영어로 전환할 수 있습니다.
- **UI/UX 개량**: 저장소 사이드바, 보기 쉬운 히스토리, 툴바 재배치, 테마 리뉴얼,
  파일을 끌어다 놓아 바로 커밋·푸시하는 편의 기능.

자세한 기획과 진행 단계는 [PLAN.md](PLAN.md)를 보세요.

## 개발 환경

Windows 기준으로 다음이 필요합니다.

- Node.js (`.nvmrc` 버전 권장)
- Yarn 1.x (`npm i -g yarn`)
- Python 3
- Visual Studio Build Tools 2022, "C++를 사용한 데스크톱 개발" 워크로드

```shell
yarn            # 의존성 설치 (네이티브 모듈 빌드 포함)
yarn build:dev  # 개발 빌드
yarn start      # 실행 (변경 사항은 Ctrl+Alt+R로 다시 불러오기)
```

원본의 개발 문서는 [docs/](docs/)에 있습니다.

### GitHub.com 로그인 (프로덕션 빌드)

개발 빌드는 원본 저장소가 공개해 둔 개발용 OAuth App으로 로그인합니다.
프로덕션 빌드는 직접 등록한 GitHub OAuth App이 필요합니다. 콜백 URL은 `x-github-plus-auth://oauth`입니다.
자격 증명은 빌드할 때 환경 변수로만 넣고 **절대 커밋하지 마세요**.

```shell
DESKTOP_OAUTH_CLIENT_ID=... DESKTOP_OAUTH_CLIENT_SECRET=... yarn build:prod
```

## 라이선스

**[MIT](LICENSE)**. 원본 GitHub Desktop의 저작권 고지를 유지합니다.

MIT 라이선스는 GitHub의 상표(로고 디자인 포함)에 대한 권리를 부여하지 않습니다.
GitHub®, 그 양식화된 표기, Invertocat 마크는 GitHub, Inc.의 상표 또는 등록 상표입니다.
GitHub+는 GitHub 로고를 앱 아이콘으로 사용하지 않습니다.
