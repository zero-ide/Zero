# Feature Roadmap 04: Platform Hardening + Observability

## 왜 지금 필요한가

현재 기능 구현은 빠르게 되어 있지만, 환경 차이(arm64/x86, Docker 경로, 아이콘 경로)와 런타임 실패 분석 수단이 약하다.
릴리즈/운영 관점에서 안정성 레이어가 필요하다.

## 현재 상태 (코드 근거)

- `scripts/build_dmg.sh`: arm64 빌드 경로와 로컬 절대 아이콘 경로에 의존.
- `Sources/Zero/Services/DockerService.swift`: Docker binary 자동 탐색은 있으나 상태 진단 정보가 단순.
- `Sources/Zero/Core/CommandRunner.swift`: stderr 분리/구조화 로그 없이 문자열 기반 예외.
- `Sources/Zero/Views/AppState.swift`: 여러 실패가 `print("Failed...")`로만 소비됨.

## 제안 기능

### P0

1. 환경 진단 패널 (Diagnostics)
- 목표: "왜 안 되는지"를 사용자가 바로 확인 가능.
- 내용: Docker 설치/실행 상태, 권한, 현재 컨테이너 상태, 네트워크 체크.
- 구현 포인트: 새 `DiagnosticsService` + settings/debug panel.

2. 구조화 에러 모델
- 목표: 문자열 기반 실패를 분류 가능한 도메인 에러로 치환.
- 구현 포인트: `CommandRunner`, `DockerService`, `ExecutionService`, `AppState`.
- 완료 기준: 사용자 메시지 + 개발자용 디버그 detail 분리.

3. 작업 로그 내보내기
- 목표: 이슈 재현/보고 효율 향상.
- 구현 포인트: 실행 로그/서비스 로그를 하나의 텍스트 번들로 export.
- 완료 기준: "Export Logs"로 최근 실행 히스토리 공유 가능.

### P1

4. DMG 스크립트 이식성 개선
- 목표: 특정 머신 경로 의존 제거.
- 구현 포인트: icon fallback 정책, 아키텍처 감지, 실패 시 친절한 가이드.

5. Command timeout + retry 정책
- 목표: 무한 대기/일시 실패 회복.
- 구현 포인트: 네트워크/패키지 설치 계열 커맨드 timeout/retry 캡슐화.

6. 경량 텔레메트리 (옵트인)
- 목표: 실제 실패 패턴 수집(로컬 우선).
- 구현 포인트: 실행 성공률, 평균 실행시간, 주요 에러 코드 집계.

## 구현 순서 제안

1. 에러 모델 표준화
2. diagnostics 패널
3. 로그 export
4. 패키징/timeout/retry

## 테스트 포인트

- 서비스별 실패 시나리오 단위 테스트(권한 없음, Docker 미설치, command 실패).
- Diagnostics snapshot 테스트.
- timeout/retry deterministic 테스트.
