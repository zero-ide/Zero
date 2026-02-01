# GitHub 인증 가이드

## OAuth vs Personal Access Token

### OAuth (권장 - 구현 복잡)
- **장점**: 사용자가 직접 GitHub에 로그인, 토큰 관리 불필요
- **단점**: Backend 서버 필요 (client_secret 보관)
- **현재 상태**: Zero는 macOS 네이티브 앱이라 OAuth 완전 구현 어려움

### Personal Access Token (현재 방식)
- **장점**: 즉시 사용 가능, 서버 불필요
- **단점**: 사용자가 직접 토큰 발급 필요

## Personal Access Token 발급 방법

### 1. GitHub 설정 페이지 이동
https://github.com/settings/tokens

### 2. "Generate new token (classic)" 클릭

### 3. 토큰 설정
- **Note**: "Zero IDE" (또는 원하는 이름)
- **Expiration**: 90 days (또는 No expiration)

### 4. 필요한 권한 (Scopes) 선택

#### 필수 권한
- [x] **repo** - 저장소 접근 (clone, pull, push)
  - repo:status
  - repo_deployment
  - public_repo
  - repo:invite
  - security_events

#### 선택 권한 (추가 기능)
- [ ] **workflow** - GitHub Actions 워크플로우 수정
- [ ] **read:org** - 조직 저장소 접근
- [ ] **read:user** - 사용자 정보 읽기

### 5. "Generate token" 클릭

### 6. 토큰 복사
⚠️ **중요**: 토큰은 한 번만 표시됩니다. 반드시 복사해서 안전한 곳에 저장하세요.

## Zero에 토큰 입력

1. Zero 앱 실행
2. "GitHub Login" 버튼 클릭
3. 발급받은 토큰 붙여넣기
4. "Login" 클릭

## 토큰 보안

- 토큰은 macOS Keychain에 안전하게 저장됩니다
- 다른 앱과 공유되지 않습니다
- 토큰이 유출되면 즉시 GitHub에서 삭제하고 재발급 받으세요

## 문제 해결

### "Bad credentials" 오류
- 토큰이 만료되었거나 잘못 복사됨
- 새 토큰 발급 필요

### "Repository not found" 오류
- 토큰에 `repo` 권한이 없음
- 토큰 재발급 시 권한 확인

### 조직 저장소 접근 불가
- 토큰에 `read:org` 권한 필요
- 또는 조직의 SSO 설정 확인
