# Design Improvement Proposals

이 디렉토리는 UI/UX 개선점을 영역별로 정리한 문서 모음이다.

## 문서 목록

- `docs/improv/01-login-repo-ux.md`
  - 로그인 진입 UX
  - 레포/세션 리스트 정보 계층
  - 로딩/에러/빈 상태 개선

- `docs/improv/02-editor-workbench-ux.md`
  - 에디터 툴바/상태바 개선
  - Output 패널 리사이즈/도구
  - 파일 탐색기 작업 액션 확장

- `docs/improv/03-interaction-accessibility.md`
  - 키보드 탐색성/접근성 라벨링
  - destructive action 안전장치
  - 상태 피드백 표준화

## 추천 적용 순서

1. Interaction + Accessibility baseline (`03`)
2. Login + Repo UX (`01`)
3. Editor Workbench UX (`02`)

## 운영 원칙

- 모든 UX 변경은 구현 전/후 스크린샷과 함께 검토한다.
- visual polish보다 task completion time 단축을 우선한다.
- 한 번에 큰 리디자인보다 작은 개선을 연속 배포한다.
