# IDE-11: 컨테이너 생성 개선

## 목표
Alpine Linux 기본 이미지 대신 설정된 JDK 이미지를 사용하여 Java 프로젝트 컨테이너를 생성.

## 구현 내용

### 1. ContainerOrchestrator 개선
- 설정된 JDK 이미지로 컨테이너 생성
- Java 프로젝트 감지 시 JDK 이미지 사용
- 그 외 프로젝트는 기존 Alpine 사용

### 2. SessionManager 연동
- 세션 생성 시 BuildConfigurationService 조회
- 프로젝트 타입에 따른 이미지 선택

### 3. 자동 이미지 선택 로직
- pom.xml/build.gradle → 설정된 JDK 이미지
- package.json → Node 이미지
- 그 외 → Alpine

## 변경 파일
- Sources/Zero/Services/ContainerOrchestrator.swift (수정)
- Sources/Zero/Services/SessionManager.swift (수정)

## 테스트
- ContainerOrchestrator 테스트
- Java 프로젝트 컨테이너 생성 테스트
