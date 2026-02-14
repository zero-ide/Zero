# UX Improv 03: Interaction + Accessibility Baseline

## 범위

- 키보드 탐색성
- VoiceOver 라벨링
- 상태 피드백 일관성

## 현재 문제점 (코드 근거)

- `Sources/Zero/Views/FileExplorerView.swift`: 다수 인터랙션이 gesture 중심(`onTapGesture`)으로 구현되어 키보드/보조기기 접근성이 약함.
- `Sources/Zero/Views/RepoListView.swift`: 아이콘 기반 destructive 액션에 설명 라벨이 부족.
- `Sources/Zero/Views/EditorView.swift`: unsaved dot/status text가 시각적 힌트 중심이며 보조기기 설명이 제한적.
- `Sources/Zero/Views/OutputView.swift`: 상태 텍스트는 있으나 액션(로그 복사/초기화) 및 명시적 접근성 설명 부족.

## 개선 제안

### P0

1. 핵심 액션에 접근성 라벨 부여
- 대상: Run/Save/Terminal/Resume/Delete/Expand/Collapse.
- 규칙: icon-only 버튼은 `accessibilityLabel` + `help` 필수.

2. Gesture 중심 row를 Button/focusable control로 전환
- 대상: File explorer row, repo row.
- 효과: 키보드 탐색/Space/Enter 동작 표준화.

3. 상태 메시지 표준 컴포넌트 도입
- idle/running/success/failed 상태를 공통 UI로 표현.
- 색상만이 아니라 아이콘/텍스트를 함께 제공해 색약 환경 대응.

4. destructive 액션 확인 단계 통일
- 세션 삭제/리셋/중단 등 파괴적 액션에 confirmation dialog 일괄 적용.

### P1

5. 단축키 안내 오버레이
- Cmd+R/Cmd+S 외 핵심 단축키를 한눈에 확인.

6. Dynamic type 대응(가능 범위 내)
- 고정 폭/고정 높이 요소를 단계적으로 유연화.

7. Empty/Error state의 문구 가이드라인 통일
- "무엇이 문제인지 + 다음 액션" 형태로 문구 표준화.

## 적용 우선순위

1. 접근성 라벨 + destructive dialog
2. focusable interaction 전환
3. 상태 컴포넌트 통일
4. 단축키/문구 가이드

## 체크리스트

- [ ] icon-only control 라벨링 완료
- [ ] File/Repo row keyboard-focus 지원
- [ ] 공통 상태 컴포넌트 정의
- [ ] confirmation dialog 표준화
