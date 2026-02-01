# ADR 003: LSP Container Separation Architecture

## Status
Accepted

## Context

Zero IDE는 Docker 기반의 격리된 개발 환경을 제공하는 것을 목표로 한다. 초기 설계에서는 프로젝트 컨테이너 하나만 사용했지만, Language Server Protocol (LSP)을 지원하면서 다음과 같은 문제들이 발생했다:

### 문제 1: 이미지 크기 증가
- **Alpine 기반 프로젝트 컨테이너**: ~50MB
- **Eclipse JDT LS 추가 시**: ~1GB (20배 증가)
- **영향**: 프로젝트 생성 시간 증가, 저장소 낭비

### 문제 2: 리소스 낭비
- LSP는 프로젝트 개수와 상관없이 동일한 기능 제공
- 각 프로젝트마다 별도의 LSP 인스턴스 = 메모리 중복 사용
- 예: Java 프로젝트 5개 = LSP 5개 (5GB 메모리)

### 문제 3: 시작 시간 지연
- LSP 초기화 시간: 5~10초
- 프로젝트마다 반복 = 사용자 경험 저하

### 대안 검토

| 대안 | 설명 | 장점 | 단점 |
|------|------|------|------|
| **A. 단일 컨테이너** | 프로젝트 + LSP 함께 | 구현 단순 | 이미지 큼, 리소스 낭비 |
| **B. Host LSP** | macOS에 LSP 설치 | 컨테이너 가벼움 | Host 오염, 설정 복잡 |
| **C. 멀티 컨테이너** | LSP 분리, WebSocket 연결 | 자원 공유, 확장성 | 구현 복잡 |

## Decision

**멀티 컨테이너 아키텍처 (대안 C) 채택**

```
┌─────────────────────────────────────────────────────────┐
│                      macOS Host                         │
│  ┌─────────────────┐          ┌─────────────────────┐  │
│  │   Zero IDE App  │◄────────►│  LSP Container      │  │
│  │  (SwiftUI +     │ WebSocket│  (Eclipse JDT LS)   │  │
│  │   Monaco)       │          │  - Persistent       │  │
│  └─────────────────┘          │  - Shared           │  │
│           │                   └─────────────────────┘  │
│           │                           ▲                │
│           │       Docker Network      │ Docker exec    │
│           ▼                           │                │
│  ┌─────────────────────────────────────────────────┐   │
│  │         Project Container (Alpine)             │   │
│  │  - User's code                                  │   │
│  │  - Build tools (Maven/Gradle)                   │   │
│  │  - Ephemeral (per session)                      │   │
│  └─────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────┘
```

### WebSocket 선택 이유

1. **표준성**: LSP는 기본적으로 JSON-RPC over stdio를 사용하지만, WebSocket은 널리 지원되는 표준
2. **언어 중립**: Swift (Zero) ↔ Node.js (Bridge) ↔ Java (LSP) 간 통신 가능
3. **도구 지원**: 브라우저 기반 Monaco와 직접 연동 가능
4. **확장성**: 원격 LSP 서버 지원 가능 (향후 클라우드 IDE)

## Consequences

### Positive
- ✅ **이미지 크기 감소**: 프로젝트 컨테이너 50MB 유지
- ✅ **자원 공유**: LSP 하나로 모든 프로젝트 지원
- ✅ **빠른 프로젝트 시작**: 1-2초 (LSP 초기화 제외)
- ✅ **언어 독립**: Java, Python, Go 각각 별도 LSP 컨테이너 가능
- ✅ **Zero 철학 유지**: "Zero Pollution" - 프로젝트는 여전히 가벼움

### Negative
- ❌ **아키텍처 복잡성**: 단일 컨테이너보다 관리 포인트 증가
- ❌ **네트워크 지연**: WebSocket 통신 오버헤드 (측정 결과 미미)
- ❌ **LSP 컨테이너 관리**: 생명주기 관리 필요 (시작/중지/복구)
- ❌ **초기 다운로드**: LSP 이미지 496MB 한 번 다운로드 필요

### Performance Results

| Metric | Single Container | Multi-Container | Improvement |
|--------|-----------------|-----------------|-------------|
| **Project Image** | 1GB | 50MB | **20x smaller** |
| **Memory (5 projects)** | 5GB | 256MB | **20x less** |
| **Project Startup** | 10s | 1s | **10x faster** |
| **LSP Startup** | 10s (per project) | 5s (once) | **Shared** |

## Implementation

### Components

1. **LSP Container** (`docker/lsp-java/`)
   - Eclipse JDT Language Server
   - Node.js WebSocket bridge
   - Exposes port 8080

2. **LSPContainerManager** (Swift)
   - 컨테이너 생명주기 관리
   - WebSocket 연결 관리
   - LSP 메시지 라우팅

3. **Monaco LSP Integration** (JavaScript)
   - WebSocket 클라이언트
   - 코드 자동완성 제공자
   - LSP 상태 표시

### Communication Flow

```
1. 사용자가 Java 파일 편집
        ↓
2. Monaco가 WebSocket으로 LSP Container에 요청
        ↓
3. LSP Bridge가 JSON-RPC로 Eclipse JDT에 전달
        ↓
4. JDT가 Project Container에서 파일 읽기 (Docker exec)
        ↓
5. 자동완성 결과 반환 (역순)
```

## Alternatives Considered

### 대안 1: Host LSP (거부)
- **이유**: Host에 Java/JDK 설치 필요, "Zero Pollution" 철학 위배

### 대안 2: gRPC (거부)
- **이유**: WebSocket보다 복잡, 브라우저 지원 필요 추가 라이브러리

### 대안 3: Shared Volume (거부)
- **이유**: 파일 시스템 경합 가능성, 실시간 동기화 어려움

## References

- [LSP Specification](https://microsoft.github.io/language-server-protocol/)
- [Eclipse JDT LS](https://github.com/eclipse/eclipse.jdt.ls)
- [ADR 002: Multi-Container Architecture](./002-lsp-multi-container-architecture.md)
- [Performance Test Results](../lsp-poc/PERFORMANCE_TEST.md)

## Date
2026-02-01
