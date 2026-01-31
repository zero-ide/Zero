# TDD 커밋 가이드

## Red-Green-Blue 커밋 규칙

각 TDD 단계를 별도의 커밋으로 분리하여 진행 상황을 명확히 추적한다.

---

## 🔴 Red 커밋 (실패하는 테스트)

### 목적
- 테스트 코드만 작성
- 구현은 없음
- 테스트가 실패하는 것을 확인

### 커밋 메시지
```
test(<scope>): add test for <feature>
```

### 예시
```bash
# 1. 테스트 파일 생성
# MonacoEditorTests.swift
func testMonacoWebViewLoads() {
    let view = MonacoWebView()
    XCTAssertTrue(view.isLoaded)
}

# 2. 테스트 실행 → 실패 확인
swift test

# 3. 커밋
git add Tests/ZeroTests/MonacoEditorTests.swift
GIT_COMMITTER_DATE="2026-01-30T07:00:00" \
git commit -m "test(editor): add test for Monaco WebView loading"
```

### 체크리스트
- [ ] 테스트 코드만 있음 (구현 없음)
- [ ] 테스트가 실패함 (Red)
- [ ] 테스트 설명이 명확함

---

## 🟢 Green 커밋 (최소한의 구현)

### 목적
- 테스트를 통과시키는 최소한의 구현
- 완벽하지 않아도 됨
- 테스트가 통과하는 것을 확인

### 커밋 메시지
```
feat(<scope>): implement <feature>
```

### 예시
```bash
# 1. 최소 구현
# MonacoWebView.swift
struct MonacoWebView: View {
    var isLoaded: Bool { true }  // 최소한의 구현
    
    var body: some View {
        WebView(...)
    }
}

# 2. 테스트 실행 → 통과 확인
swift test

# 3. 커밋
git add Sources/Zero/Views/MonacoWebView.swift
GIT_COMMITTER_DATE="2026-01-30T07:01:00" \
git commit -m "feat(editor): implement basic Monaco WebView wrapper"
```

### 체크리스트
- [ ] 테스트가 통과함 (Green)
- [ ] 최소한의 구현임
- [ ] 기능은 작동함

---

## 🔵 Blue 커밋 (리팩토링)

### 목적
- 코드 개선 (가독성, 성능, 구조)
- 기능 변경 없음
- 테스트는 계속 통과

### 커밋 메시지
```
refactor(<scope>): <description>
```

### 예시
```bash
# 1. 리팩토링
# Configuration 추출
struct MonacoConfiguration {
    let theme: String
    let language: String
}

# 2. 테스트 실행 → 통과 확인 (기능 변경 없음)
swift test

# 3. 커밋
git add Sources/Zero/Views/MonacoWebView.swift
git add Sources/Zero/Models/MonacoConfiguration.swift
GIT_COMMITTER_DATE="2026-01-30T07:02:00" \
git commit -m "refactor(editor): extract Monaco configuration into separate struct"
```

### 체크리스트
- [ ] 기능 변경 없음
- [ ] 테스트 여전히 통과
- [ ] 코드 품질 개선됨

---

## 커밋 순서 예시

### 시나리오: Monaco Editor 통합

```bash
# 1. 브랜치 생성
git checkout -b feature/IDE-15-monaco-editor

# ========== Red ==========
# 테스트 작성
echo "class MonacoEditorTests..." > Tests/ZeroTests/MonacoEditorTests.swift
git add .
GIT_COMMITTER_DATE="2026-01-30T07:00:00" \
git commit -m "test(editor): add tests for Monaco WebView integration"

# ========== Green ==========
# 최소 구현
echo "struct MonacoWebView..." > Sources/Zero/Views/MonacoWebView.swift
git add .
GIT_COMMITTER_DATE="2026-01-30T07:01:00" \
git commit -m "feat(editor): implement basic Monaco WebView wrapper"

# ========== Blue ==========
# 리팩토링 1
echo "struct MonacoConfiguration..." > Sources/Zero/Models/MonacoConfiguration.swift
git add .
GIT_COMMITTER_DATE="2026-01-30T07:02:00" \
git commit -m "refactor(editor): extract Monaco configuration"

# ========== Blue ==========
# 리팩토링 2
echo "extension MonacoWebView..." >> Sources/Zero/Views/MonacoWebView.swift
git add .
GIT_COMMITTER_DATE="2026-01-30T07:03:00" \
git commit -m "refactor(editor): add error handling and logging"

# 푸시
git push origin feature/IDE-15-monaco-editor
```

---

## 커밋 히스토리 예시

```
* refactor(editor): add error handling and logging
* refactor(editor): extract Monaco configuration
* feat(editor): implement basic Monaco WebView wrapper
* test(editor): add tests for Monaco WebView integration
```

---

## 금지 사항

- ❌ Red와 Green을 하나의 커밋으로 합치기
- ❌ Green에서 완벽한 구현 시도하기
- ❌ Blue에서 기능 변경하기
- ❌ 테스트 없이 Green 커밋하기
