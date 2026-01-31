# IDE-13: 테스트 및 품질 개선

## 목표
Zero 프로젝트의 테스트 커버리지 향상 및 코드 품질 개선

## 현재 문제점
- ViewInspector 의존성 (테스트 실패 원인)
- UI 테스트 부족
- 통합 테스트 부족
- 에러 핸들링 불완전

## 구현 범위

### Phase 1: 테스트 인프라 개선
- ViewInspector 의존성 완전 제거
- XCTest 기반 UI 테스트 작성
- 테스트 유틸리티 클래스 생성

### Phase 2: 단위 테스트 강화
- ViewModel 테스트 (AppState 등)
- Service 계층 테스트
- Model 테스트 보강

### Phase 3: 통합 테스트
- Docker 연동 테스트
- GitHub API 통합 테스트 (mock)
- 파일 I/O 통합 테스트

### Phase 4: 에러 핸들링 개선
- Result 타입 도입 검토
- 에러 로깅 강화
- 사용자 친화적 에러 메시지

## 예상 변경 파일
- Tests/ZeroTests/* (대부분 수정)
- Sources/Zero/Services/* (에러 핸들링)
- Package.swift (ViewInspector 제거)

## 성공 기준
- 테스트 커버리지 70% 이상
- 모든 테스트 통과
- ViewInspector 의존성 0
