# Feature Spec: Docker Integration via CLI

## Overview
사용자의 로컬 Docker CLI(`docker`)를 직접 실행하여 격리된 개발 환경(Container)을 생성, 실행, 제거하는 기능을 구현한다.

## Goals
1. **Docker CLI Wrapper**
   - `Process` (구 `NSTask`)를 사용하여 `docker` 명령어 실행
   - 표준 출력(stdout) 및 표준 에러(stderr) 캡처하여 로그 처리
2. **Container Lifecycle Management**
   - `create`: Ubuntu/Debian 기반의 개발용 이미지 실행
   - `exec`: 컨테이너 내부에서 명령어 실행 (`git clone` 등)
   - `cleanup`: 작업 종료 시 컨테이너 및 볼륨 강제 삭제 (`rm -f`)
3. **Volume Mounting**
   - 호스트의 특정 경로(또는 Docker Volume)를 작업 공간으로 마운트

## Tasks
- [ ] `CommandRunner`: 쉘 명령어 실행 및 결과 반환 유틸리티 구현
- [ ] `DockerService`: `CommandRunner`를 주입받아 Docker 명령어 조합
    - `checkInstallation()`: Docker 설치 여부 및 실행 상태 확인
    - `runContainer(image:name:)`: 컨테이너 실행
    - `executeCommand(container:command:)`: `docker exec` 래퍼
    - `removeContainer(name:)`: 정리 로직

## Technical Details
- **Execution**: `Process` 객체를 사용하여 `/usr/local/bin/docker` 또는 환경변수 경로의 docker 실행
- **Error Handling**: Exit Code가 0이 아닌 경우 `DockerError` throw
- **Ephemerality**: 컨테이너 실행 시 `--rm` 옵션 사용 검토 (종료 시 자동 삭제) 또는 명시적 삭제
