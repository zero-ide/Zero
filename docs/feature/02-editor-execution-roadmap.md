# Feature Roadmap 02: Editor + Execution Workflow

## 왜 지금 필요한가

에디터 기본 기능(열기/수정/저장/실행)은 이미 존재한다.
하지만 실행 피드백/터미널/파일 조작 기능이 제한적이라 "IDE" 경험이 완성되지 않았다.

## 현재 상태 (코드 근거)

- `Sources/Zero/Views/EditorView.swift`: Run/Save 버튼은 있으나 Stop 버튼 없음.
- `Sources/Zero/Services/ExecutionService.swift`: `executeShell` 결과를 완료 후 한번에 append (실시간 스트리밍 아님).
- `Sources/Zero/Services/FileService.swift`: list/read/write만 존재, create/rename/delete API 없음.
- `Sources/Zero/Views/OutputView.swift`: 고정 높이 `150`, 리사이즈/clear/filter 부재.
- `docs/IDE-11-build-and-run.md`: Stop 버튼/출력 스트리밍 목표가 문서에 있으나 구현 미완료.

## 제안 기능

### P0

1. 실행 중지(Stop) 기능
- 목표: 장시간/무한 실행 작업을 UI에서 즉시 중단.
- 구현 포인트: `ExecutionService`에 cancel handle + 상태 전이(`running -> failed/cancelled`) 추가.
- UI 변경: `EditorView` toolbar에 Stop 버튼 추가.
- 완료 기준: 실행 중 Stop 클릭 시 프로세스 중단, Output에 종료 원인 표시.

2. 출력 스트리밍 실행
- 목표: 긴 빌드/테스트 명령에서 "멈춘 것처럼 보이는" UX 제거.
- 구현 포인트: `CommandRunner`/`DockerService` 확장해서 stdout/stderr line streaming.
- 완료 기준: 명령 실행 중 Output가 실시간 갱신.

3. Dockerfile 우선 실행 전략
- 목표: 실제 프로젝트 의존성/런타임을 더 정확히 반영.
- 구현 포인트: `ExecutionService.detectRunCommand`에서 `Dockerfile` 우선 체크.
- 완료 기준: Dockerfile 존재 시 해당 전략으로 실행 경로 분기.

### P1

4. 프로젝트별 Run Profile
- 목표: 자동 감지 실패 시 사용자 커스텀 실행 커맨드 저장 가능.
- 구현 포인트: 세션/레포 기반 실행 명령 저장소 추가.
- 완료 기준: 저장된 run command 재사용 + UI에서 수정 가능.

5. 파일 작업 API 확장(create/rename/delete)
- 목표: 에디터 내부에서 기본 파일 작업 완결.
- 구현 포인트: `FileService`, `FileExplorerView` 액션 메뉴/컨텍스트 메뉴.
- 완료 기준: 새 파일/폴더 생성, 이름 변경, 삭제가 컨테이너 파일시스템에 반영.

6. OutputView 도구 추가
- 목표: 로그 탐색 효율 개선.
- 구현 포인트: clear 버튼, wrap toggle, 오류 하이라이트.
- 완료 기준: 대용량 출력에서도 탐색 가능.

## 구현 순서 제안

1. Stop + streaming(가장 체감 큰 UX)
2. Dockerfile 우선 실행
3. Run profile
4. 파일 작업 확장
5. OutputView 고도화

## 테스트 포인트

- `Tests/ZeroTests/ExecutionServiceTests.swift`: cancel/streaming/command strategy 테스트 추가.
- `Tests/ZeroTests/DockerServiceTests.swift`: streaming callback 및 shell cancellation 검증.
- 신규 파일 작업 테스트: `FileService` 경로/권한/escape 케이스.
