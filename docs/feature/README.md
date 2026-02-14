# Feature Proposals

이 디렉토리는 "다음에 무엇을 구현할지"를 기능 관점으로 정리한 문서 모음이다.

## 문서 목록

- `docs/feature/01-auth-session-roadmap.md`
  - OAuth 로그인 전환
  - 세션 헬스체크/좀비 정리
  - 인증 실패 복구 UX

- `docs/feature/02-editor-execution-roadmap.md`
  - Stop/실시간 실행 출력
  - Dockerfile 우선 실행
  - 파일 생성/삭제/이름변경

- `docs/feature/03-git-workflow-roadmap.md`
  - status/diff/commit
  - branch/pull/push
  - 커밋 타임라인

## 추천 구현 순서

1. Auth + Session Reliability (`01`)
2. Editor + Execution (`02`)
3. Git Workflow (`03`)

## 원칙

- 먼저 P0를 끝내고 P1로 확장한다.
- 각 기능은 서비스 레이어 API -> AppState -> View 순으로 수직 슬라이스 구현한다.
- 신규 기능마다 최소 1개 이상 테스트 케이스를 함께 추가한다.
