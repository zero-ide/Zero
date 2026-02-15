import Foundation

/// Zero 앱의 표준 에러 타입
enum ZeroError: Error, Equatable {
    // MARK: - Docker Errors
    case dockerNotInstalled
    case containerCreationFailed(reason: String)
    case containerExecutionFailed(reason: String)
    case containerNotFound(name: String)
    case imageNotFound(name: String)
    
    // MARK: - Git Errors
    case gitNotInstalled
    case gitCloneFailed(reason: String)
    case gitAuthenticationFailed
    case invalidRepositoryURL
    
    // MARK: - GitHub Errors
    case githubAPIFailed(statusCode: Int)
    case githubAuthenticationFailed
    case githubRateLimited
    
    // MARK: - Build Configuration Errors
    case buildConfigurationFailed(reason: String)
    case jdkNotFound(id: String)
    case invalidJDKImage
    
    // MARK: - Session Errors
    case sessionNotFound(id: String)
    case sessionCreationFailed(reason: String)
    case sessionAlreadyExists(id: String)
    
    // MARK: - File Errors
    case fileNotFound(path: String)
    case fileReadFailed(path: String)
    case fileWriteFailed(path: String)
    
    // MARK: - Keychain Errors
    case keychainSaveFailed
    case keychainLoadFailed
    case keychainDeleteFailed
    
    // MARK: - General Errors
    case runtimeCommandFailed(userMessage: String, debugDetails: String)
    case unknown(message: String)
    case notImplemented
    
    // MARK: - User-Friendly Descriptions
    
    var localizedDescription: String {
        switch self {
        case .dockerNotInstalled:
            return "Docker가 설치되어 있지 않습니다. Docker Desktop을 설치해주세요."
            
        case .containerCreationFailed(let reason):
            return "개발 환경 생성 실패: \(reason)"
            
        case .containerExecutionFailed(let reason):
            return "명령어 실행 실패: \(reason)"
            
        case .containerNotFound(let name):
            return "컨테이너를 찾을 수 없습니다: \(name)"
            
        case .imageNotFound(let name):
            return "Docker 이미지를 찾을 수 없습니다: \(name)"
            
        case .gitNotInstalled:
            return "Git이 설치되어 있지 않습니다."
            
        case .gitCloneFailed(let reason):
            return "저장소 복제 실패: \(reason)"
            
        case .gitAuthenticationFailed:
            return "Git 인증에 실패했습니다. GitHub 토큰을 확인해주세요."
            
        case .invalidRepositoryURL:
            return "유효하지 않은 저장소 URL입니다."
            
        case .githubAPIFailed(let statusCode):
            return "GitHub API 오류 (상태 코드: \(statusCode))"
            
        case .githubAuthenticationFailed:
            return "GitHub 로그인이 필요합니다."
            
        case .githubRateLimited:
            return "GitHub API 요청 한도에 도달했습니다. 잠시 후 다시 시도해주세요."
            
        case .buildConfigurationFailed(let reason):
            return "빌드 설정 오류: \(reason)"
            
        case .jdkNotFound(let id):
            return "JDK를 찾을 수 없습니다: \(id)"
            
        case .invalidJDKImage:
            return "유효하지 않은 JDK 이미지입니다."
            
        case .sessionNotFound(let id):
            return "세션을 찾을 수 없습니다: \(id.prefix(8))..."
            
        case .sessionCreationFailed(let reason):
            return "세션 생성 실패: \(reason)"
            
        case .sessionAlreadyExists(let id):
            return "이미 존재하는 세션입니다: \(id.prefix(8))..."
            
        case .fileNotFound(let path):
            return "파일을 찾을 수 없습니다: \(path)"
            
        case .fileReadFailed(let path):
            return "파일 읽기 실패: \(path)"
            
        case .fileWriteFailed(let path):
            return "파일 쓰기 실패: \(path)"
            
        case .keychainSaveFailed:
            return "키체인 저장 실패"
            
        case .keychainLoadFailed:
            return "키체인 읽기 실패"
            
        case .keychainDeleteFailed:
            return "키체인 삭제 실패"
            
        case .runtimeCommandFailed(let userMessage, _):
            return userMessage

        case .unknown(let message):
            return "알 수 없는 오류: \(message)"
            
        case .notImplemented:
            return "아직 구현되지 않은 기능입니다."
        }
    }
    
    // MARK: - Recovery Suggestions
    
    var recoverySuggestion: String? {
        switch self {
        case .dockerNotInstalled:
            return "https://www.docker.com/products/docker-desktop/ 에서 Docker Desktop을 다운로드하세요."
            
        case .githubAuthenticationFailed, .gitAuthenticationFailed:
            return "설정에서 GitHub 로그인을 다시 시도하세요."
            
        case .githubRateLimited:
            return "잠시 후에 다시 시도하세요."
            
        case .containerExecutionFailed, .runtimeCommandFailed:
            return "컨테이너 상태를 확인하고 다시 시도하세요."
            
        default:
            return nil
        }
    }
    
    // MARK: - Is Recoverable
    
    var isRecoverable: Bool {
        switch self {
        case .dockerNotInstalled, .gitNotInstalled:
            return false
        case .githubRateLimited:
            return true
        case .containerExecutionFailed, .gitCloneFailed:
            return true
        default:
            return true
        }
    }

    var telemetryCode: String {
        switch self {
        case .dockerNotInstalled:
            return "docker_not_installed"
        case .containerCreationFailed:
            return "container_creation_failed"
        case .containerExecutionFailed:
            return "container_execution_failed"
        case .containerNotFound:
            return "container_not_found"
        case .imageNotFound:
            return "image_not_found"
        case .gitNotInstalled:
            return "git_not_installed"
        case .gitCloneFailed:
            return "git_clone_failed"
        case .gitAuthenticationFailed:
            return "git_authentication_failed"
        case .invalidRepositoryURL:
            return "invalid_repository_url"
        case .githubAPIFailed:
            return "github_api_failed"
        case .githubAuthenticationFailed:
            return "github_authentication_failed"
        case .githubRateLimited:
            return "github_rate_limited"
        case .buildConfigurationFailed:
            return "build_configuration_failed"
        case .jdkNotFound:
            return "jdk_not_found"
        case .invalidJDKImage:
            return "invalid_jdk_image"
        case .sessionNotFound:
            return "session_not_found"
        case .sessionCreationFailed:
            return "session_creation_failed"
        case .sessionAlreadyExists:
            return "session_already_exists"
        case .fileNotFound:
            return "file_not_found"
        case .fileReadFailed:
            return "file_read_failed"
        case .fileWriteFailed:
            return "file_write_failed"
        case .keychainSaveFailed:
            return "keychain_save_failed"
        case .keychainLoadFailed:
            return "keychain_load_failed"
        case .keychainDeleteFailed:
            return "keychain_delete_failed"
        case .runtimeCommandFailed:
            return "runtime_command_failed"
        case .unknown:
            return "unknown"
        case .notImplemented:
            return "not_implemented"
        }
    }
}

// MARK: - Result Extension

extension Result {
    /// Result의 에러를 ZeroError로 변환
    func mapErrorToZeroError() -> Result<Success, ZeroError> where Failure == Error {
        self.mapError { error in
            if let zeroError = error as? ZeroError {
                return zeroError
            }
            return .unknown(message: error.localizedDescription)
        }
    }
}
