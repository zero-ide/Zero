# 개발 워크플로우 체크리스트

## 작업 시작 전

- [ ] main 브랜치가 최신인지 확인 (`git pull origin main`)
- [ ] 새 브랜치 생성 (`git checkout -b feature/IDE-{number}-{desc}`)
- [ ] 브랜치 이름이 규칙에 맞는지 확인

## TDD 사이클

### 🔴 Red 단계
- [ ] 테스트 코드만 작성
- [ ] 구현은 아직 없음
- [ ] 테스트 실행 → 실패 확인
- [ ] 커밋 (test scope 사용)

### 🟢 Green 단계
- [ ] 최소한의 구현
- [ ] 테스트 실행 → 통과 확인
- [ ] 커밋 (feat scope 사용)

### 🔵 Blue 단계
- [ ] 리팩토링 진행
- [ ] 테스트 실행 → 여전히 통과
- [ ] 커밋 (refactor scope 사용)

## PR 생성 전

- [ ] 모든 테스트 통과
- [ ] Red-Green-Blue 커밋이 모두 있음
- [ ] 커밋 메시지 규칙 준수
- [ ] 커밋이 작은 단위로 나뉘어 있음
- [ ] 불필요한 코드/주석 없음

## PR 생성

- [ ] PR 타이틀 형식 준수 (`branch-name | description`)
- [ ] PR 템플릿 작성
- [ ] 관련 이슈 연결
- [ ] 리뷰어 지정

## 머지 전

- [ ] 최소 1명의 리뷰 승인
- [ ] CI/CD 통과
- [ ] Conflict 없음
- [ ] "Create a merge commit" 선택
- [ ] Squash merge 금지

## 머지 후

- [ ] 브랜치 삭제
- [ ] main 브랜치 최신화
- [ ] 다음 작업 준비

---

## 커밋 메시지 검증

```bash
# 커밋 메시지 형식 확인
# <type>(<scope>): <subject>

# 올바른 예:
test(editor): add test for Monaco WebView loading
feat(docker): implement container orchestration
refactor(auth): extract GitHub authentication logic

# 잘못된 예:
add test                    # type 없음
feat: some feature          # scope 없음 (생략 가능하지만 권장 안함)
WIP: working on something   # 모호한 메시지
fix bug                     # 구체적이지 않음
```
