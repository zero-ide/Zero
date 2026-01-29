# Feature Spec: GitHub Auth & Container Clone

## Overview
Core 기능 구현: GitHub OAuth 로그인을 통해 인증하고, Docker 컨테이너 내에서 Private Repo를 Clone하는 기능을 구현한다.

## Goals
1. **GitHub OAuth 2.0 Flow**
   - `ASWebAuthenticationSession`을 사용한 macOS 네이티브 로그인 경험 제공
   - Access Token 안전한 저장 (Keychain 사용)
2. **Docker Container Management**
   - 개발 환경용 베이스 이미지(Ubuntu 등) Pull & Run
   - 호스트와 격리된 작업 공간(Volume) 생성
   - OrbStack/Docker Desktop 소켓 연동
3. **Repository Clone in Container**
   - 컨테이너 내부에서 `git clone` 실행
   - OAuth 토큰을 git credential로 주입하여 Private Repo 접근

## Tasks
- [ ] GitHub OAuth App 등록 (Client ID/Secret 확보)
- [ ] `AuthManager` 구현 (Login, Logout, Token Check)
- [ ] `DockerClient` 연동 (Docker Socket 통신)
- [ ] `GitService` 구현 (Container 내 명령어 실행)

## Technical Details
- **Auth**: `AuthenticationServices` 프레임워크 사용
- **Container**: `docker.sock`을 통한 HTTP API 통신 또는 Swift Docker 라이브러리 사용
- **Secure**: 토큰은 Keychain에 저장하고 메모리 내에서만 잠시 사용
