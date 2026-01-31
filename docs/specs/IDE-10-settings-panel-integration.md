# IDE-10: 설정 패널 UI 통합

## 목표
BuildConfigurationView를 Zero 앱의 설정 패널에 통합하여 사용자가 쉽게 접근할 수 있도록 함.

## 구현 내용

### 1. SettingsView 생성
- 기존 설정 항목들과 BuildConfigurationView 통합
- 탭 기반 또는 섹션 기반 UI

### 2. AppState 연동
- BuildConfigurationView를 AppState에서 관리
- 설정 변경 시 자동 저장

### 3. 메뉴 연동
- Window 메뉴 또는 Settings 메뉴에 "Build Configuration" 항목 추가
- 단축키 지원 (Cmd + Shift + B)

## 변경 파일
- Sources/Zero/Views/SettingsView.swift (신규)
- Sources/Zero/Views/AppState.swift (수정)
- Sources/Zero/ZeroApp.swift (수정)

## 테스트
- SettingsView 렌더링 테스트
- 메뉴 항목 테스트
