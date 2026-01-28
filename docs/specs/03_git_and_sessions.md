# Feature Spec: Git Clone & Session Management

## Overview
Docker 컨테이너 내부에서 Git Repository를 Clone하고, 해당 작업 환경(Container)을 영속적인 '세션(Session)' 단위로 관리하여 작업 재개 및 리셋 기능을 제공한다.

## Goals
1. **Session Management**
   - **Data Model**: `Session` 구조체 정의 (ID, Repo URL, Container Name, Timestamp)
   - **Persistence**: `~/.zero/sessions.json` 파일에 세션 목록 저장 및 로드
   - **Lifecycle**: 세션 생성(New), 조회(Resume), 삭제(Reset) 로직 구현
   - **Validation**: 저장된 세션 정보와 실제 Docker 컨테이너 상태 동기화 (Zombie 세션 정리)

2. **Git Operations (in Container)**
   - **Credential Injection**: `AuthManager`에서 획득한 토큰을 사용하여 `git clone` 실행
   - **Command Execution**: `DockerService`를 통해 `docker exec {container} git clone ...` 수행
   - **Status Check**: Clone 성공 여부 및 브랜치 확인

## Architecture
### Session Manager
- `loadSessions(for repoURL: URL) -> [Session]`: 특정 레포의 세션 목록 조회
- `createSession(repoURL: URL) -> Session`: 새 컨테이너 생성 및 메타데이터 저장
- `deleteSession(_ session: Session)`: 컨테이너 삭제(`rm -f`) 및 메타데이터 제거

### Git Service
- `clone(repoURL: URL, token: String, targetDir: String)`
- 인증 방식: HTTPS URL에 토큰 포함 (`https://x-access-token:{token}@github.com/...`) 또는 `git config` 설정

## User Flow
1. 사용자가 Repo URL 입력/선택
2. `SessionManager`가 해당 Repo의 기존 세션 검색
3. **세션 존재 시**: [Resume] 또는 [New / Reset] 선택 팝업
4. **세션 없음/New 선택 시**:
   - Docker Container 생성 (`run -d ...`)
   - Git Clone 실행
   - `Session` 정보 저장
