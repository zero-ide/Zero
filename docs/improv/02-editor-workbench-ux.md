# UX Improv 02: Editor Workbench + Terminal

## 범위

- 에디터 상단 툴바
- 파일 탐색기
- 출력/터미널 패널

## 현재 문제점 (코드 근거)

- `Sources/Zero/Views/EditorView.swift`: Run/Save/Terminal 토글은 있으나 작업 흐름 제어(Stop, clear output, run config)가 부족.
- `Sources/Zero/Views/OutputView.swift`: 높이 고정(`.frame(height: 150)`), 로그 도구가 없어 긴 출력 탐색이 불편.
- `Sources/Zero/Views/EditorView.swift`: 하드코딩된 `.background(Color.white)`로 테마 일관성 저하 가능.
- `Sources/Zero/Views/FileExplorerView.swift`: 생성/삭제/이름변경 같은 파일 작업 액션 부재.

## 개선 제안

### P0

1. 실행 상태 중심 툴바
- Run 옆에 Stop/Restart 배치, 현재 상태 배지(Idle/Running/Success/Failed) 표준화.
- 실행 시간(ms/s) 표시로 피드백 강화.

2. 리사이저블 Output 패널
- 현재 고정 150px -> 드래그 리사이즈 지원.
- 최소/기본/최대 높이 규칙 제공.

3. Output 도구 추가
- Clear, Wrap, Copy All, Error Only 필터.
- 실패 시 첫 에러 위치로 빠른 이동 CTA 제공.

4. Unsaved changes guard
- 세션 전환/닫기 시 변경사항 확인 다이얼로그.

### P1

5. File Explorer 컨텍스트 메뉴
- New File/New Folder/Rename/Delete/Reveal path.

6. 상태바 정보 확장
- 현재 줄/컬럼 외에 LF/CRLF, indentation mode, tab size 표시.

7. 실행 프리셋 진입점
- 툴바 또는 상태바에서 프로젝트별 실행 커맨드 확인/수정.

## UI 구조 제안

1. 상단: Primary actions(Run/Stop/Save) + secondary(Terminal/Config)
2. 중앙: Editor
3. 하단: Output(Tabs: Output / Problems)

## 빠른 적용 체크리스트

- [ ] Output 패널 리사이즈 도입
- [ ] Stop 버튼 + 실행 시간 표시
- [ ] Output 도구 행 추가
- [ ] unsaved guard 추가
- [ ] File Explorer 메뉴 액션 추가
