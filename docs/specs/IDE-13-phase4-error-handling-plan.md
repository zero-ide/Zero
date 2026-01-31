# IDE-13 Phase 4: 에러 핸들링 개선 계획

## 현재 상태 분석

### 기존 에러 핸들링 방식
- throws를 사용한 예외 처리
- Error 타입을 직접 던짐
- catch에서 에러 처리

### 문제점
- 에러 타입이 일관되지 않음
- 에러 메시지가 사용자에게 친화적이지 않음
- 에러 처리 로직이 중복됨

## 개선 방안: Result 타입 도입

### 1. ZeroError enum 정의
```swift
enum ZeroError: Error {
    // Docker Errors
    case dockerNotInstalled
    case containerCreationFailed(String)
    case containerExecutionFailed(String)
    
    // Git Errors
    case gitCloneFailed(String)
    case authenticationFailed
    
    // Build Errors
    case buildConfigurationFailed
    case jdkNotFound
    
    // Session Errors
    case sessionNotFound
    case sessionCreationFailed
    
    // General Errors
    case unknown(String)
    
    var localizedDescription: String {
        switch self {
        case .dockerNotInstalled:
            return "Docker가 설치되어 있지 않습니다. Docker를 설치해주세요."
        case .containerCreationFailed(let reason):
            return "컨테이너 생성 실패: \(reason)"
        case .authenticationFailed:
            return "GitHub 인증에 실패했습니다. 다시 로그인해주세요."
        // ... etc
        }
    }
}
```

### 2. Result 타입 적용 예시
```swift
// Before
func runContainer(image: String, name: String) throws -> String

// After
func runContainer(image: String, name: String) -> Result<String, ZeroError>
```

### 3. 사용자 친화적 에러 UI
- 에러 알림 토스트
- 재시도 버튼
- 상세 에러 로그 (디버그용)

## 구현 우선순위

1. **ZeroError enum 정의** (이 PR)
2. **DockerService Result 타입 전환** (다음 PR)
3. **GitService Result 타입 전환** (다음 PR)
4. **UI 에러 처리 개선** (다음 PR)

## 테스트 전략
- 각 에러 케이스별 단위 테스트
- Result 타입 success/failure 검증
- 사용자 에러 메시지 검증

## 다음 작업
이 PR에서는 ZeroError enum 정의와 기본 구조만 추가.
실제 Service 전환은 IDE-14에서 진행.
