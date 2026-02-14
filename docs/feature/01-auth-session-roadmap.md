# Feature Roadmap 01: Auth + Session Reliability

## 왜 지금 필요한가

현재 앱은 기본 흐름은 동작하지만, 인증/세션 레이어가 "데모 단계"에 머물러 있다.
특히 로그인 UX와 세션 복구 신뢰성이 낮아 실제 일상 개발에 투입하기 어렵다.

## 현재 상태 (코드 근거)

- `Sources/Zero/Views/LoginView.swift`: PAT 직접 입력 방식(`SecureField`) + 주석에 "추후 OAuth로 교체" 명시.
- `Sources/Zero/Services/AuthManager.swift`: OAuth URL 생성/코드 추출/토큰 교환 요청 유틸은 있으나 UI 플로우에 연결되지 않음.
- `Sources/Zero/Views/AppState.swift`: `resumeSession(_:)`는 컨테이너 생존 여부 검증 없이 화면만 전환.
- `Sources/Zero/Services/SessionManager.swift`: 세션 메타데이터 저장/삭제는 있으나 Docker 실제 상태와 동기화 로직 없음.

## 제안 기능

### P0

1. GitHub OAuth 정식 로그인 플로우
- 목표: PAT 수동 입력 제거, 웹 인증 기반 로그인 제공.
- 구현 포인트: `LoginView`, `AuthManager`, `ZeroApp` URL callback 처리.
- 완료 기준: 앱 실행 -> GitHub 로그인 -> 토큰 저장 -> 재실행 시 자동 로그인.

2. 세션 재개 전 컨테이너 헬스체크
- 목표: 죽은 컨테이너로 에디터 진입하는 실패 경험 제거.
- 구현 포인트: `SessionManager` + `DockerService`에 상태 검증 API 추가, `AppState.resumeSession(_:)` 보호.
- 완료 기준: stale session 감지 시 자동 정리/재생성 선택 UX 제공.

3. Zombie session 정리 잡
- 목표: `~/.zero/sessions.json`과 Docker 실제 상태 불일치 해소.
- 구현 포인트: 앱 시작 시 동기화 루틴 (`AppState.loadSessions()` 전/후).
- 완료 기준: 존재하지 않는 컨테이너 세션이 목록에 남지 않음.

### P1

4. 토큰 상태 검증 + 만료 대응
- 목표: 잘못된/만료 토큰에서 조용히 실패하는 상황 방지.
- 구현 포인트: `GitHubService` 호출 실패 시 인증 에러 분리, 재로그인 유도 UI.
- 완료 기준: 인증 실패 메시지가 사용자 액션(재로그인)으로 연결됨.

5. 조직/개인 컨텍스트 기억
- 목표: 매번 동일 org를 다시 고르는 반복 제거.
- 구현 포인트: 마지막 선택 org/local preference 저장.
- 완료 기준: 재실행 후 이전 컨텍스트 복원.

## 구현 순서 제안

1. OAuth UI/콜백 연결
2. 세션 헬스체크 + stale 정리
3. 인증 에러 타입 분리 + UX
4. 사용자 선호 컨텍스트 저장

## 테스트 포인트

- `Tests/ZeroTests/AuthManagerTests.swift` 확장: callback edge case, token exchange request 검증 강화.
- `Tests/ZeroTests/AppStateTests.swift` 확장: stale session 처리, resume 실패 분기 테스트.
- 신규 세션 동기화 테스트: `SessionManagerTests` + Docker mock 조합.
