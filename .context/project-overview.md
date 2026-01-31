# Zero 프로젝트 이해 및 컨텍스트

## 프로젝트 개요

**Zero**는 macOS용 네이티브 IDE로, Docker 기반의 격리된 개발 환경을 제공하는 애플리케이션이다.

### 핵심 철학
- **Zero Pollution**: 로컬 파일 시스템을 건드리지 않음 (무균실 개발)
- **Zero Config**: URL만 넣으면 즉시 개발 환경 세팅
- **Native Experience**: macOS Native (SwiftUI)의 쾌적함

### 기술 스택
- **언어**: Swift 5.9
- **UI 프레임워크**: SwiftUI (macOS 14+)
- **컨테이너 엔진**: Docker (Swift Client)
- **에디터**: Monaco Editor (VS Code 기반) + Highlightr

### 주요 기능
1. **Docker 환경 생성**: Alpine Linux 컨테이너 (~50MB)를 초 단위로 생성
2. **Git 통합**: GitHub 로그인, 저장소 탐색 및 클론
3. **코드 에디터**: 190+ 언어 지원, 구문 강조
4. **세션 관리**: 격리된 개발 세션 관리

### 프로젝트 구조
```
Zero/
├── Sources/Zero/
│   ├── Core/           # 핵심 로직
│   ├── Services/       # 서비스 레이어
│   │   ├── AuthManager.swift       # GitHub 인증
│   │   ├── DockerService.swift     # Docker 연동
│   │   ├── ContainerOrchestrator.swift  # 컨테이너 오케스트레이션
│   │   ├── ExecutionService.swift  # 코드 실행
│   │   ├── FileService.swift       # 파일 관리
│   │   ├── GitHubService.swift     # GitHub API
│   │   ├── GitService.swift        # Git 연동
│   │   └── SessionManager.swift    # 세션 관리
│   ├── Models/         # 데이터 모델
│   │   ├── Organization.swift
│   │   ├── Repository.swift
│   │   └── Session.swift
│   ├── Views/          # SwiftUI 뷰
│   │   ├── AppState.swift
│   │   ├── CodeEditorView.swift
│   │   ├── EditorView.swift
│   │   ├── FileExplorerView.swift
│   │   ├── LoginView.swift
│   │   ├── MonacoWebView.swift     # Monaco 에디터 통합
│   │   ├── OutputView.swift
│   │   └── RepoListView.swift
│   ├── Helpers/        # 유틸리티
│   ├── Utils/          # 공통 유틸
│   └── Resources/      # 리소스 파일
├── Tests/              # 테스트 코드
├── docs/               # 문서
│   └── specs/          # 기능 명세
└── scripts/            # 빌드 스크립트
```

### 개발 워크플로우 규칙
1. **TDD (Test-Driven Development)**: Red → Green → Refactor 사이클 필수
2. **브랜치**: `feature/IDE-{number}-{desc}` (예: `feature/IDE-1-auth`)
3. **PR 타이틀**: `{Branch Name} | {Description}`
4. **PR 머지**: 리뷰 후 승인 받아야 머지

### 히스토리
- **IDE-1**: Auth (GitHub 로그인, Keychain)
- **IDE-2**: Docker Integration (CommandRunner, DockerService)
- **IDE-3**: Git Clone & Session Management
- **IDE-4~6**: UI Integration, Editor
- **IDE-7**: File I/O
- **IDE-8**: Lightweight Container (Alpine), Organization Support
- **IDE-9**: Java Build Configuration (JDK 선택, Maven/Gradle, Spring Boot)
- **IDE-10**: Settings Panel Integration (BuildConfigurationView in Settings)
- **IDE-11**: Container Image Selection (JDK 이미지, 프로젝트 타입별)
- **IDE-12**: Maven/Gradle Auto-detection (Spring Boot 지원)
- **IDE-13**: Testing & Quality Improvement (계획)
- **IDE-14**: Git Integration Enhancement (commit, branch, push - 계획)

### 저장소
- GitHub: https://github.com/ori0o0p/Zero
