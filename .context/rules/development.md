# Zero 프로젝트 개발 가이드

## 개발 철학
- **단순하게**: 어려운 문제를 복잡하게 풀려고 하지 말고, 단순하게 해결하려고 접근
- **TDD (Test-Driven Development)**: Red → Green → Refactor 사이클
- **작은 단위 커밋**: 한 번에 하나의 작업만
- **코드 리뷰 필수**: PR 없이 main에 직접 커밋 금지
- **작업 분해 원칙**: 어려운 작업은 단순한 단위까지 쪼개서 진행 (PR도 분리)

## Git 워크플로우

### 브랜치 전략
```
main
  └── feature/IDE-{number}-{description}
  └── bugfix/IDE-{number}-{description}
  └── refactor/IDE-{number}-{description}
```

### 브랜치 네이밍 규칙
- **기능 개발**: `feature/IDE-15-monaco-editor-integration`
- **버그 수정**: `bugfix/IDE-15-fix-syntax-highlighting`
- **리팩토링**: `refactor/IDE-15-extract-editor-component`

### 커밋 단계 (TDD)
각 단계별로 별도 커밋, 명확한 접두사 사용

#### 🔴 Red 커밋 (실패하는 테스트)
```bash
# 테스트 먼저 작성
# 테스트 실행 → 실패 확인
git commit -m "test(IDE-15): add test for syntax highlighting"
```
- 테스트 코드만 추가
- 구현은 없음
- 테스트 반드시 실패해야 함

#### 🟢 Green 커밋 (최소한의 구현)
```bash
# 최소한의 코드로 테스트 통과
git commit -m "feat(IDE-15): implement basic syntax highlighting"
```
- 테스트 통과를 위한 최소한의 구현
- 완벽하지 않아도 됨
- 테스트 반드시 통과해야 함

#### 🔵 Blue 커밋 (리팩토링)
```bash
# 코드 개선, 테스트는 그대로 통과
git commit -m "refactor(IDE-15): extract highlighting logic into separate class"
```
- 기능 변경 없음
- 가독성, 성능, 구조 개선
- 테스트 여전히 통과

### 커밋 메시지 규칙
```
<type>(<scope>): <subject>

<body>

<footer>
```

#### Type
- `feat`: 새로운 기능
- `fix`: 버그 수정
- `test`: 테스트 추가/수정
- `refactor`: 리팩토링 (기능 변경 없음)
- `docs`: 문서 수정
- `style`: 코드 포맷팅 (세미콜론, 공백 등)
- `chore`: 빌드, 설정 변경

#### Scope (Zero 프로젝트)
- `auth`: 인증 (AuthManager)
- `docker`: Docker 연동 (DockerService)
- `editor`: 에디터 (MonacoWebView, CodeEditorView)
- `github`: GitHub 통합 (GitHubService)
- `session`: 세션 관리 (SessionManager)
- `ui`: UI 컴포넌트 (SwiftUI Views)
- `core`: 핵심 로직

#### 예시
```
test(editor): add test for syntax highlighting in Monaco

- test: verify JavaScript syntax highlighting
- test: verify Swift syntax highlighting
- test: verify Python syntax highlighting

Related to IDE-15
```

## PR (Pull Request) 규칙

### PR 생성 규칙
1. **main 브랜치로 직접 커밋 금지** - 반드시 PR 통해 머지
2. **최소 1개의 리뷰 승인** 필요
3. **모든 테스트 통과** 필수
4. **Conflict 해결** 후 머지

### PR 타이틀 형식
```
feature/IDE-{number}-{desc} | {간단한 설명}
```

예시:
```
feature/IDE-15-monaco-editor | Monaco Editor 구현 및 SwiftUI 통합
```

### PR 템플릿
```markdown
## 🎯 목표
- 관련 이슈: IDE-{number}
- 구현 내용: {간단한 설명}

## 📝 변경사항
- [ ] Red 커밋: 테스트 추가
- [ ] Green 커밋: 기능 구현
- [ ] Blue 커밋: 리팩토링

## 🧪 테스트
- [ ] 단위 테스트 통과
- [ ] 통합 테스트 통과
- [ ] 수동 테스트 완료

## 📋 체크리스트
- [ ] TDD 사이클 완료 (Red-Green-Blue)
- [ ] 커밋 메시지 규칙 준수
- [ ] 작은 단위로 커밋
- [ ] 불필요한 코드 없음

## 🖼️ 스크린샷 (UI 변경 시)
{스크린샷 첨부}

## ⚠️ 주의사항
- {리뷰어가 알아야 할 특이사항}
```

### 머지 규칙
- **Squash and Merge** 사용 금지 (커밋 히스토리 유지)
- **Create a merge commit** 사용
- 머지 후 브랜치 삭제

## 개발 프로세스

### 1. 작업 시작
```bash
# 1. main 브랜치 최신화
git checkout main
git pull origin main

# 2. 기능 브랜치 생성
git checkout -b feature/IDE-15-monaco-editor
```

### 2. TDD 사이클
```bash
# Red: 테스트 작성 → 커밋
git add .
git commit -m "test(editor): add test for Monaco integration"

# Green: 최소 구현 → 커밋
git add .
git commit -m "feat(editor): implement Monaco WebView wrapper"

# Blue: 리팩토링 → 커밋
git add .
git commit -m "refactor(editor): extract Monaco configuration"
```

### 3. PR 생성
```bash
# 브랜치 푸시
git push origin feature/IDE-15-monaco-editor

# GitHub에서 PR 생성
# Title: feature/IDE-15-monaco-editor | Monaco Editor 구현
# Template 작성
```

### 4. 리뷰 및 머지
- 리뷰어 지정
- 피드백 반영 (새로운 커밋으로)
- 승인 받은 후 머지

## 예시 시나리오

### 기능 개발: Monaco Editor 통합

```bash
# 브랜치 생성
git checkout -b feature/IDE-15-monaco-editor

# Red: 테스트 작성
echo "class MonacoEditorTests..." > Tests/ZeroTests/MonacoEditorTests.swift
git add .
git commit -m "test(editor): add tests for Monaco WebView integration"

# Green: 최소 구현
echo "struct MonacoWebView..." > Sources/Zero/Views/MonacoWebView.swift
git add .
git commit -m "feat(editor): implement basic Monaco WebView wrapper"

# Blue: 리팩토링
# - Configuration 분리
# - Theme 설정 추가
git add .
git commit -m "refactor(editor): extract Monaco configuration and theme settings"

# Blue: 추가 리팩토링
# - Error handling 개선
git add .
git commit -m "refactor(editor): add error handling for WebView loading"

# 푸시 및 PR 생성
git push origin feature/IDE-15-monaco-editor
```

## 작업 분해 원칙 (PR 분리)

### 원칙
**어려운 작업은 단순한 단위까지 쪼개서 진행 (PR도 분리)**

### 적용 기준
- 하나의 PR이 200줄 이상의 코드 변경을 포함하면 분리 검토
- 리뷰어가 한 번에 이해하기 어려운 복잡도면 분리
- 독립적으로 배포/테스트 가능한 단위면 분리

### 분리 예시

#### ❌ 잘못된 예 (하나의 PR에 모든 것)
```
feature/IDE-9-java-build | Java 빌드 설정 전체 구현
- JDK 모델 추가
- UI 구현
- ExecutionService 수정
- 테스트 작성
```

#### ✅ 올바른 예 (단계별 PR 분리)
```
# PR 1: 모델 및 설정
feature/IDE-9-jdk-model | JDK Configuration 모델 및 서비스 구현

# PR 2: UI 구현
feature/IDE-9-build-config-ui | Build Configuration UI 구현

# PR 3: 연동
feature/IDE-9-execution-integration | ExecutionService JDK 연동

# PR 4: 테스트
feature/IDE-9-build-tests | Java 빌드 테스트 작성
```

### PR 분리 시 브랜치 전략
```
main
  └── feature/IDE-9-jdk-model (PR 1)
  └── feature/IDE-9-build-config-ui (PR 2, main 기반)
  └── feature/IDE-9-execution-integration (PR 3, PR 2 머지 후 rebase)
```

### 금지 사항

- ❌ main에 직접 커밋
- ❌ Squash Merge
- ❌ Red, Green, Blue 커밋을 하나로 합치기
- ❌ "WIP", "임시", "작업중" 같은 모호한 커밋 메시지
- ❌ 테스트 없는 기능 구현
- ❌ 여러 기능을 한 번에 커밋
- ❌ 너무 큰 PR (200줄+)
