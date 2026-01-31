# Zero 프로젝트 개발 가이드

## 핵심 원칙 (반드시 지킬 것)

### 1. 작업 시작 전 필수 체크
- [ ] `.context/` 문서 확인
- [ ] Git 브랜치 생성: `feature/IDE-{number}-{desc}`

### 2. 개발 철학
- **단순하게**: 어려운 문제를 복잡하게 풀지 말고, 단순하게 접근
- **작업 분해**: 어려운 작업은 단순한 단위까지 쪼개서 진행 (PR도 분리)
- **TDD**: Red → Green → Blue 커밋 사이클

### 3. Git 워크플로우
- **main 직접 커밋 금지** → 반드시 PR
- **브랜치명**: `feature/IDE-{number}-{desc}`
- **PR 타이틀**: `branch-name | 한글 설명`
- **머지**: Squash Merge 금지, Create a merge commit 사용

### 4. 커밋 규칙
- **Red**: 테스트만 (`test(scope): ...`)
- **Green**: 최소 구현 (`feat(scope): ...`)
- **Blue**: 리팩토링 (`refactor(scope): ...`)

### 5. PR 분리 기준
- 200줄 이상이면 분리 검토
- 리뷰어가 한 번에 이해하기 어려우면 분리

---

## 작업 유형별 가이드

| 작업 | 읽을 문서 |
|------|----------|
| **새 기능 개발** | README + `rules/development.md` |
| **커밋 작성** | README + `rules/tdd-commit.md` |
| **PR 작성** | `templates/pr.md` |
| **전체 가이드** | `SUMMARY.md` |

---

## 파일 위치

```
.context/
├── README.md              # 이 파일 (핵심 규칙)
├── SUMMARY.md             # 전체 인덱스
├── project-overview.md    # 프로젝트 개요
├── conversation-context.md # 대화 컨텍스트
├── rules/
│   ├── development.md     # 개발 가이드 (상세)
│   ├── tdd-commit.md      # TDD 커밋 가이드
│   └── workflow.md        # 워크플로우 체크리스트
└── templates/
    └── pr.md              # PR 템플릿
```
