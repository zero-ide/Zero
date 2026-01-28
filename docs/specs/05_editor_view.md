# Feature Spec: Editor View & Container Orchestration

## Overview
레포지토리 선택 후 컨테이너를 생성하고, Monaco Editor 기반의 코드 편집 환경을 제공한다. Xcode와 유사한 레이아웃(File Tree + Editor + Terminal)을 구현한다.

## Goals
1. **Container Orchestrator**
   - `DockerService` + `GitService` + `SessionManager` 통합
   - 단일 호출로 컨테이너 생성 → Clone → 세션 저장 플로우 실행
   - Progress 상태 콜백 (UI 업데이트용)

2. **Editor View (Monaco)**
   - `WKWebView`에 Monaco Editor 임베드
   - 파일 열기/저장 기능 (`docker exec` 기반 파일 I/O)
   - Syntax Highlighting (언어 자동 감지)

3. **File Explorer**
   - 컨테이너 내부 파일 트리 표시 (`docker exec ls -laR`)
   - 폴더 확장/축소, 파일 클릭 시 에디터에 로드
   - 새 파일/폴더 생성, 삭제

4. **Terminal**
   - 컨테이너 내부 쉘 연결 (`docker exec -it /bin/bash`)
   - `Process` + Pseudo-TTY 또는 WebSocket 기반 xterm.js

## Architecture
### ContainerOrchestrator
```swift
class ContainerOrchestrator {
    func startSession(repo: Repository, token: String) async throws -> Session
    func stopSession(_ session: Session) throws
    func deleteSession(_ session: Session) throws
}
```

### EditorView Layout (3-Column)
```
+------------------+------------------------+------------------+
|   File Explorer  |      Monaco Editor     |     Terminal     |
|   (Sidebar)      |      (Main)            |   (Bottom/Side)  |
+------------------+------------------------+------------------+
```

## Tasks
- [ ] `ContainerOrchestrator`: 통합 플로우 구현
- [ ] `MonacoWebView`: WKWebView + Monaco Editor 래핑
- [ ] `FileExplorerView`: 파일 트리 SwiftUI 컴포넌트
- [ ] `TerminalView`: xterm.js 또는 네이티브 PTY 연결
- [ ] `EditorView`: 3-Column 레이아웃 통합

## Migration Path (Future)
1차: Monaco (WKWebView) → 2차: CodeEdit 라이브러리 (네이티브 SwiftUI)
