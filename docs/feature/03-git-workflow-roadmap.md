# Feature Roadmap 03: Git Workflow Inside Zero

## 왜 지금 필요한가

현재는 repo clone 이후 개발 워크플로우가 외부 툴 의존적이다.
README의 "Git Integration" 기대치에 비해 실제 구현은 clone 중심이라 사용자가 컨텍스트를 자주 이탈한다.

## 현재 상태 (코드 근거)

- `Sources/Zero/Services/GitService.swift`: `clone(...)`만 존재.
- `Sources/Zero/Views/EditorView.swift`: 변경사항/브랜치/커밋 관련 UI 없음.
- `Sources/Zero/Views/RepoListView.swift`: 세션 열기/재개 중심, Git 작업 액션 부재.

## 제안 기능

### P0

1. Working Tree 상태 보기
- 목표: 수정/신규/삭제 파일을 에디터 내부에서 즉시 확인.
- 구현 포인트: `git status --porcelain` 래퍼 서비스 + `EditorView` 사이드 패널.
- 완료 기준: 파일별 상태 배지(M/A/D/?)가 UI에 표시.

2. 변경 파일 Diff 미리보기
- 목표: 커밋 전 변경 내용 검토 가능.
- 구현 포인트: `git diff` 출력 파싱 + 전용 Diff 뷰(읽기 전용).
- 완료 기준: 선택 파일의 hunks/라인 변화 확인 가능.

3. Commit 플로우 (메시지 + staged)
- 목표: 기본 커밋 작업을 앱 내부에서 처리.
- 구현 포인트: stage/unstage, commit 메시지 입력, 실행 결과 피드백.
- 완료 기준: 정상 커밋 시 상태 초기화 및 로그 반영.

### P1

4. Branch 전환/생성
- 목표: feature branch 작업을 컨텍스트 이탈 없이 수행.
- 구현 포인트: branch list/create/checkout 액션.
- 완료 기준: 현재 브랜치 표시 + 안전한 전환 UX(unsaved guard).

5. Pull/Push 기본 동작
- 목표: 원격 동기화 최소 기능 제공.
- 구현 포인트: credential 처리 정책 정리 후 `git pull`, `git push` 래핑.
- 완료 기준: 충돌/거절 상황에서 사용자 안내 제공.

6. 최근 커밋 타임라인
- 목표: "지금 어디까지 작업했는지" 맥락 제공.
- 구현 포인트: `git log --oneline` 기반 간단 타임라인 패널.
- 완료 기준: 최신 N개 커밋을 빠르게 확인 가능.

## 구현 순서 제안

1. status + diff
2. stage/commit
3. branch
4. pull/push + log

## 테스트 포인트

- `GitService` 확장 단위 테스트: status/diff/commit 명령 생성 검증.
- 실패 케이스 테스트: 충돌, auth 실패, empty commit 메시지.
- UI 상태 테스트: staged/unstaged 전환 시 리스트 동기화.
