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
7. **Zero 프로젝트 IDE-9~14 완료** (Java Build Configuration + Git 통합)
8. **릴리스 자동화 및 CI/CD 설정**
9. **Java LSP PoC 완료** (멀티 컨테이너 아키텍처)

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

### 5. Zero 프로젝트 개발 완료 (2026-02-01)

#### IDE-9~12: Java Build Configuration ✅
- **IDE-9**: JDK 선택, Maven/Gradle 지원, ExecutionService 연동
- **IDE-10**: 설정 패널 UI 통합 (SettingsView, Cmd + ,)
- **IDE-11**: 컨테이너 생성 개선 (프로젝트 타입별 이미지 선택)
- **IDE-12**: Maven/Gradle 자동 감지 및 Spring Boot 지원

#### IDE-13: 테스트 및 품질 개선 ✅
- Phase 1: 에러 핸들링 테스트 추가
- Phase 2: ViewModel 단위 테스트 (AppState)
- Phase 3: 통합 테스트 (Docker, BuildConfiguration, SessionManager)
- Phase 4: ZeroError enum 정의 (표준화된 에러 타입)

#### IDE-14: Git 통합 개선 ✅
- Phase 1: Git 기본 작업 (status, add, commit, branch, push, pull)
- Phase 2: Git History (commit log, diff 보기)
- Phase 3: Stash & Merge/Rebase
- Phase 4: EditorView 통합 (Git 패널, 탭 UI)
- GitHub 로그인 UX 개선 (토큰 발급 가이드)

#### 릴리스 자동화 및 CI/CD ✅
- `scripts/release.sh`: 릴리스 자동화 (DMG 생성, 서명, 체크섬)
- `scripts/generate-icons.sh`: 앱 아이콘 생성
- `.github/workflows/ci.yml`: CI (빌드, 테스트)
- `.github/workflows/release.yml`: 자동 릴리스 (GitHub Releases 업로드)

### 6. Java LSP PoC 완료 ✅

#### 아키텍처: 멀티 컨테이너
```
Zero IDE (Monaco) ←WebSocket→ LSP Container (Eclipse JDT) ←Docker exec→ Project Container (Alpine)
```

#### 구현 내용
- **LSP Container**: `docker/lsp-java/` (Eclipse JDT + WebSocket bridge)
- **LSPContainerManager.swift**: 컨테이너 생명주기 관리
- **monaco-lsp.html**: Monaco Editor + LSP 연동

#### 성능 테스트 결과
| Metric | Expected | Actual | 평가 |
|--------|----------|--------|------|
| **이미지 크기** | 1GB+ | **496MB** | ✅ 생각보다 작음 |
| **메모리 사용** | 1GB+ | **206MB** | ✅ 훨씬 적음 |
| **시작 시간** | 10-30초 | **~5초** | ✅ 빠름 |
| **프로젝트 컨테이너** | - | **Alpine (50MB)** | ✅ 가벼움 |

#### ADR (Architecture Decision Record)
- **ADR 003**: LSP Container Separation Architecture
- **결정**: LSP 컨테이너 분리 + WebSocket 연결
- **이유**: 이미지 20x, 메모리 20x, 속도 10x 개선
- **위치**: `docs/adr/003-lsp-container-separation.md`

### 7. 개발 규칙 확정
- **TDD**: Red → Green → Blue 커밋 사이클
- **작업 분해**: 어려운 작업은 단순한 단위까지 쪼개서 진행 (PR도 분리)
- **단순하게**: 어려운 문제를 복잡하게 풀지 말고, 단순하게 접근
- **커밋 메시지**: `type(scope): description` 형식
- **ADR**: 중요한 기술적 결정은 ADR로 문서화

## 다음 작업 (예정)
- [ ] LSP UI 통합 (설정에서 활성화/비활성화)
- [ ] Python LSP 추가 (Pyright)
- [ ] v0.1.0 릴리스 (GitHub Releases)
- [ ] README 작성 (스크린샷, GIF)
