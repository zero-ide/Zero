# Zero 프로젝트 문서 인덱스

## 전체 문서 목록

### 핵심 문서 (필수)
- `README.md` - 개발 핵심 원칙 (1페이지 분량)

### 프로젝트 정보
- `project-overview.md` - Zero 프로젝트 개요, 기술 스택, 구조
- `conversation-context.md` - 대화 핵심 내용, 결정사항

### 상세 가이드 (rules/)
- `rules/development.md` - 전체 개발 가이드
  - Git 워크플로우 (상세)
  - PR 규칙 (상세)
  - 커밋 시간 조작 규칙
  - 작업 분해 원칙
  - 금지 사항
  
- `rules/tdd-commit.md` - TDD 커밋 가이드
  - Red-Green-Blue 개념
  - 커밋 메시지 규칙
  - 예시 시나리오
  
- `rules/workflow.md` - 개발 워크플로우 체크리스트
  - 작업 시작 전
  - TDD 사이클
  - PR 생성 전/후
  - 커밋 메시지 검증

### 템플릿 (templates/)
- `templates/pr.md` - PR 템플릿 및 타이틀 규칙

---

## 작업 유형별 읽기 가이드

### 새 기능 개발 시
1. `README.md` - 핵심 원칙 확인
2. `rules/development.md` - 개발 가이드 (상세)
3. `.github/pull_request_template.md` - GitHub PR 템플릿

### 커밋 작성 시
1. `README.md` - 핵심 원칙 확인
2. `rules/tdd-commit.md` - TDD 커밋 가이드

### PR 작성 시
1. `templates/pr.md` - PR 타이틀 규칙
2. `.github/pull_request_template.md` - GitHub 템플릿 적용

### 전체 파악 시
- 모든 문서 순차적으로 읽기

---

## 핵심 규칙 요약

### 브랜치/PR
- 브랜치: `feature/IDE-{number}-{desc}`
- PR 타이틀: `branch-name | 한글 설명`
- main 직접 커밋 금지
- Squash Merge 금지

### TDD 커밋
- Red: 테스트만 (`test(scope): ...`)
- Green: 최소 구현 (`feat(scope): ...`)
- Blue: 리팩토링 (`refactor(scope): ...`)

### 작업 분해
- 어려운 작업은 단순한 단위까지 쪼개기
- PR도 분리 (200줄+이면 검토)

### 단순함
- 어려운 문제를 복잡하게 풀지 말고, 단순하게 접근
