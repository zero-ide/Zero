# IDE-12: Maven/Gradle 지원

## 목표
pom.xml 또는 build.gradle 파일을 자동으로 감지하여 Maven/Gradle 명령어 실행 지원.

## 구현 내용

### 1. ExecutionService 개선
- pom.xml/build.gradle 파일 존재 여부 확인
- 설정된 빌드 도구에 따라 명령어 실행
- 자동 빌드/테스트 명령어 지원

### 2. 자동 명령어 감지
- pom.xml → mvn clean install
- build.gradle → gradle build
- 없으면 javac 컴파일

### 3. Run 버튼 개선
- 프로젝트 타입에 따른 Run 명령어 자동 선택
- Maven: mvn spring-boot:run
- Gradle: gradle bootRun

## 변경 파일
- Sources/Zero/Services/ExecutionService.swift (수정)
- Sources/Zero/Views/EditorView.swift (수정 - Run 버튼)

## 테스트
- Maven 프로젝트 감지 테스트
- Gradle 프로젝트 감지 테스트
