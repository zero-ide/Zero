# 대화 컨텍스트 - 2026-01-30 ~ 2026-02-01

## 참여자
- **User**: 스ㅇ원 (javaSpring, GitHub: ori0o0p)
- **AI**: Kimi Code (Clawdbot)

## 대화 주제
1. Discord 채널 설정 (멘션 없이 응답, 특정 사용자만 대화 가능하도록 설정)
2. coffee-time 저장소 분석 및 클론
3. 개발자 성장 로드맵 (신입/취준생/초보자)
4. 후배 멘토링 로드맵 (소마고 출신, 1.5년 후 취업)
5. 클라이밍 CRM 백엔드 프로젝트 기획
6. Zero 프로젝트 이해 및 컨텍스트 저장
7. **Zero 프로젝트 IDE-9~12 완료** (Java Build Configuration)
8. **Zero 프로젝트 IDE-13, 14 계획** (테스트 및 Git 통합)

## 핵심 결정사항

### 1. Discord 설정
- `groupPolicy`: `allowlist`로 변경
- 사용자 `1434058032094122026`, `842694939083014155`만 대화 가능

### 2. 멘토링 프로젝트: 클라이밍 CRM 백엔드
- **대상**: 소마고 출신 후배 (1.5년 후 취업)
- **기간**: 3개월
- **기술 스택**: Java, Spring Boot, JPA, Docker
- **목표**: 실제 클라이밍장에서 사용 가능한 서비스 배포

### 3. AI 활용 전략
- **Month 1**: AI 금지 (기초 체득)
- **Month 2**: AI 보조 (페어 프로그래머)
- **Month 3**: AI 마스터 (10배 생산성)
- **핵심**: AI 없이도 코딩 가능한 실력을 먼저 쌓고, 그 다음 AI 활용

### 4. 문서 저장 위치
- `~/Documents/mentoring/climbing-crm-backend/` - 멘토링 문서
- `~/zero/.context/` - Zero 프로젝트 관련 컨텍스트

### 5. Zero 프로젝트 개발 완료 (IDE-9~12)
- **IDE-9**: Java Build Configuration (JDK 선택, 설정 저장, UI, ExecutionService 연동)
- **IDE-10**: 설정 패널 UI 통합 (SettingsView, Cmd + ,)
- **IDE-11**: 컨테이너 생성 개선 (프로젝트 타입별 이미지 선택)
- **IDE-12**: Maven/Gradle 자동 감지 및 Spring Boot 지원

### 6. Zero 프로젝트 계획 (IDE-13, 14)
- **IDE-13**: 테스트 및 품질 개선 (ViewInspector 제거, 통합 테스트)
- **IDE-14**: Git 통합 개선 (commit, branch, push, pull UI)

### 7. 개발 규칙 확정
- **TDD**: Red → Green → Blue 커밋 사이클
- **작업 분해**: 어려운 작업은 단순한 단위까지 쪼개서 진행 (PR도 분리)
- **단순하게**: 어려운 문제를 복잡하게 풀지 말고, 단순하게 접근
- **커밋 메시지**: `type(scope): description` 형식

## 다음 작업
- IDE-13: 테스트 및 품질 개선
- IDE-14: Git 통합 개선
