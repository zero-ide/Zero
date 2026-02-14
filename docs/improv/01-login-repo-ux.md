# UX Improv 01: Login + Repo List

## 범위

- 로그인 화면
- 레포지토리 리스트/세션 리스트

## 현재 문제점 (코드 근거)

- `Sources/Zero/Views/LoginView.swift`: PAT 입력 중심 UI, OAuth 동선이 시각적으로 드러나지 않음.
- `Sources/Zero/Views/RepoListView.swift`: 세션/레포 섹션 구분은 있으나 정보 우선순위가 약하고 빈 상태/실패 상태 UX가 제한적.
- `Sources/Zero/Views/RepoListView.swift`: `onChange(of:)` 구형 시그니처 사용으로 deprecation warning 발생.

## 개선 제안

### P0

1. 로그인 CTA 재구성
- 현재: "토큰 입력 -> Sign In"만 강조.
- 개선: "Sign in with GitHub" 1차 CTA + 고급 옵션(PAT) 2차 노출.
- 기대효과: 신규 사용자의 진입 장벽 감소.

2. 레포 카드 정보 계층 강화
- 현재: 이름/풀네임/Open 버튼의 단순 나열.
- 개선: private/public, last updated, 기본 브랜치, language 배지 추가.
- 기대효과: 어떤 repo를 열지 빠르게 판단 가능.

3. 로딩/빈 상태/오류 상태 분리
- 현재: 오버레이와 기본 텍스트 중심.
- 개선: skeleton row, empty state 액션(새로고침), 에러 상태 재시도 버튼.
- 기대효과: 네트워크 지연 시 체감 품질 상승.

### P1

4. 세션 리스트 액션 안전장치
- 현재: 삭제 버튼 즉시 실행.
- 개선: destructive 확인 dialog + "컨테이너만 삭제 / 세션만 제거" 선택.

5. 컨텍스트 전환 피드백
- 현재: org 전환 후 조용히 fetch.
- 개선: 상단 배지/토스트로 현재 컨텍스트 명시, 전환 중 진행 상태 표시.

6. Deprecated API 정리
- `onChange(of:perform:)`를 macOS 14+ 권장 시그니처로 교체.

## 빠른 적용 체크리스트

- [ ] Login 화면의 1차 CTA를 OAuth 중심으로 재배치
- [ ] RepoRow에 메타데이터 배지 추가
- [ ] Empty/Error/Skeleton 상태 컴포넌트 분리
- [ ] 세션 삭제 confirmation flow 추가
- [ ] `onChange` deprecation 제거
