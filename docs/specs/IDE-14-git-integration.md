# IDE-14: Git 통합 개선 (commit, branch)

## 목표
Zero IDE에서 직접 Git commit, branch 생성 등 기본 Git 작업 수행

## 현재 상태
- Git clone만 지원
- Commit/Branch 작업은 터미널에서 수행 필요

## 구현 범위

### Phase 1: Git 기본 작업 지원
- Git commit UI
- Git add (스테이징) UI
- Commit 메시지 작성 인터페이스

### Phase 2: Branch 관리
- Branch 생성
- Branch 전환 (checkout)
- Branch 목록 조회
- Branch 삭제

### Phase 3: Git History
- Commit 로그 조회
- Diff 보기
- 파일 변경 이력

### Phase 4: 고급 기능
- Git stash
- Git merge/rebase
- Git push/pull
- 충돌 해결 UI

## UI 설계

### Git Panel
```
┌─────────────────────────────┐
│  🌿 Git                     │
├─────────────────────────────┤
│  Branches                   │
│  [main]                     │
│  [feature/new-ide]*         │
│  [origin/main]              │
├─────────────────────────────┤
│  Changes                    │
│  [M] src/main.swift         │
│  [A] src/new.swift          │
│  [D] src/old.swift          │
├─────────────────────────────┤
│  Commit Message             │
│  [____________________]     │
│                             │
│  [Commit] [Stash] [Pull]    │
└─────────────────────────────┘
```

## 예상 변경 파일
- Sources/Zero/Services/GitService.swift (확장)
- Sources/Zero/Views/GitPanelView.swift (신규)
- Sources/Zero/Views/BranchSelectorView.swift (신규)
- Sources/Zero/Views/CommitView.swift (신규)

## 의존성
- IDE-13 완료 후 진행 권장 (테스트 기반 안정화)
