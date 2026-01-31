# IDE-9: Java Build Configuration 구현 계획

## 🎯 목표
Java 프로젝트 빌드를 위한 JDK 이미지 선택 및 설정 저장 기능 구현

## 📝 개요
현재 ExecutionService는 Alpine Linux 기반으로 openjdk21을 하드코딩하여 설치하고 있다. 이를 개선하여 사용자가 원하는 JDK 이미지를 선택하고, 해당 설정을 저장할 수 있도록 한다.

## 🏗️ 구현 범위

### Phase 1: JDK 이미지 선택 UI
- 설정 패널에 "Build Configuration" 섹션 추가
- JDK 이미지 드롭다운 (미리 정의된 이미지 목록)
- 커스텀 이미지 입력 필드 (고급 사용자용)

### Phase 2: 설정 저장/로드
- UserDefaults 또는 파일 기반 설정 저장
- 프로젝트별 JDK 설정 저장
- 기본값 설정 기능

### Phase 3: 빌드 시스템 연동
- ExecutionService 수정: 하드코딩된 Java 설치 로직 제거
- 선택된 JDK 이미지로 컨테이너 실행
- Maven/Gradle 지원 검토

### Phase 4: UI Polish
- 현재 디자인 시스템과 일관성 유지
- 로딩 상태 표시
- 에러 처리 및 피드백

## 📋 상세 설계

### 1. 데이터 모델

```swift
struct JDKConfiguration: Codable, Identifiable {
    let id: UUID
    let name: String
    let image: String
    let version: String
    let isCustom: Bool
}

struct BuildConfiguration: Codable {
    var selectedJDK: JDKConfiguration
    var buildTool: BuildTool
    var customArgs: [String]
    
    enum BuildTool: String, Codable {
        case javac, maven, gradle
    }
}
```

### 2. 미리 정의된 JDK 이미지

```swift
extension JDKConfiguration {
    static let predefined: [JDKConfiguration] = [
        JDKConfiguration(id: UUID(), name: "OpenJDK 21", image: "openjdk:21-slim", version: "21", isCustom: false),
        JDKConfiguration(id: UUID(), name: "OpenJDK 17", image: "openjdk:17-slim", version: "17", isCustom: false),
        JDKConfiguration(id: UUID(), name: "OpenJDK 11", image: "openjdk:11-slim", version: "11", isCustom: false),
        JDKConfiguration(id: UUID(), name: "Eclipse Temurin 21", image: "eclipse-temurin:21-jdk", version: "21", isCustom: false),
        JDKConfiguration(id: UUID(), name: "Amazon Corretto 21", image: "amazoncorretto:21", version: "21", isCustom: false),
    ]
}
```

### 3. UI 컴포넌트

#### BuildConfigurationView
- 설정 패널 난이바 항목 추가
- JDK 선택 드롭다운
- 빌드 도구 선택 (javac, Maven, Gradle)
- 저장 버튼

#### JDKSelectorView
- 드롭다운 메뉴
- 커스텀 이미지 입력 필드 (토글로 표시/숨김)
- 이미지 유효성 검사 (선택사항)

### 4. 서비스 수정

#### ExecutionService
```swift
// 기존: 하드코딩된 Java 설치
if command.contains("javac") {
    _ = try dockerService.executeShell(container: container, script: "apk add --no-cache openjdk21")
}

// 변경: 선택된 JDK 이미지 사용
// 컨테이너 생성 시 JDK 이미지로 생성
```

#### BuildConfigurationService (신규)
- 설정 저장/로드
- 파일 경로: `~/.zero/build-config.json`

## 🎨 UI/UX 설계

### 디자인 원칙
- 현재 Zero 앱의 다크 모드 테마 유지
- Material Design 아이콘 사용
- 간결하고 직관적인 인터페이스

### 화면 구성
```
┌─────────────────────────────┐
│  ⚙️ Build Configuration     │
├─────────────────────────────┤
│  JDK Image                  │
│  ┌─────────────────────┐    │
│  │ OpenJDK 21      ▼   │    │
│  └─────────────────────┘    │
│                             │
│  [ ] Use custom image       │
│  ┌─────────────────────┐    │
│  │ eclipse-temurin:21  │    │
│  └─────────────────────┘    │
│                             │
│  Build Tool                 │
│  ○ javac  ● Maven  ○ Gradle │
│                             │
│  ┌─────────────────────┐    │
│  │     Save Settings   │    │
│  └─────────────────────┘    │
└─────────────────────────────┘
```

## 🔧 구현 순서

### Week 1: 모델 및 서비스
1. JDKConfiguration 모델 구현
2. BuildConfigurationService 구현
3. 설정 저장/로드 테스트

### Week 2: UI 구현
1. BuildConfigurationView 구현
2. JDKSelectorView 구현
3. 설정 패널 통합

### Week 3: ExecutionService 연동
1. ExecutionService 수정
2. ContainerOrchestrator 수정
3. 선택된 JDK로 컨테이너 생성

### Week 4: 테스트 및 Polish
1. UI 테스트
2. 통합 테스트
3. 에러 처리
4. 문서화

## 📁 파일 변경 예상

### 신규 파일
- `Sources/Zero/Models/JDKConfiguration.swift`
- `Sources/Zero/Models/BuildConfiguration.swift`
- `Sources/Zero/Services/BuildConfigurationService.swift`
- `Sources/Zero/Views/BuildConfigurationView.swift`
- `Sources/Zero/Views/JDKSelectorView.swift`

### 수정 파일
- `Sources/Zero/Services/ExecutionService.swift`
- `Sources/Zero/Services/ContainerOrchestrator.swift`
- `Sources/Zero/Views/AppState.swift` (설정 패널 연결)

## 🧪 테스트 계획

### 단위 테스트
- JDKConfiguration Codable 테스트
- BuildConfigurationService 저장/로드 테스트

### 통합 테스트
- JDK 이미지로 컨테이너 생성 테스트
- Java 프로젝트 빌드 테스트

### 수동 테스트
- UI 흐름 테스트
- 설정 저장/복구 테스트

## ⚠️ 고려사항

1. **Docker 이미지 크기**: slim 버전 사용으로 경량화
2. **호환성**: Maven/Gradle은 별도 이미지 또는 설치 필요
3. **보안**: 커스텀 이미지 입력 시 검증 로직
4. **성능**: 이미지 캐싱으로 빠른 컨테이너 생성

## 📚 참고

- Docker Hub OpenJDK 이미지: https://hub.docker.com/_/openjdk
- Eclipse Temurin 이미지: https://hub.docker.com/_/eclipse-temurin
