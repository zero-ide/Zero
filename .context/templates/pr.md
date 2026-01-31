# PR 템플릿 (GitHub 기준)

```markdown
## Context
- **Issue**: #
- **Type**:
  - [ ] `feat`
  - [ ] `fix`
  - [ ] `refactor`
  - [ ] `docs`
  - [ ] `etc`

## Summary
<!-- 이번 PR의 핵심 요약 -->

## Key Changes
- 
- 

## Screenshots (Optional)
<!-- UI 변경이 있을 경우 스크린샷 첨부 -->
```

---

# PR 타이틀 규칙

## 형식
```
feature/IDE-{number}-{desc} | {한글 설명}
```

## 예시
- `feature/IDE-9-java-build | Java 빌드 설정 기능 구현`
- `bugfix/IDE-9-fix-build-error | Java 빌드 오류 수정`
- `refactor/IDE-9-extract-service | BuildConfigurationService 추출`

## 브랜치 네이밍
- **기능 개발**: `feature/IDE-{number}-{description}`
- **버그 수정**: `bugfix/IDE-{number}-{description}`
- **리팩토링**: `refactor/IDE-{number}-{description}`
- **문서**: `docs/IDE-{number}-{description}`

## 라벨
- `enhancement` - 기능 개발
- `bug` - 버그 수정
- `refactor` - 리팩토링
- `docs` - 문서
