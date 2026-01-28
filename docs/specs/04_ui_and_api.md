# Feature Spec: UI Integration & GitHub API

## Overview
Core 서비스들을 SwiftUI 기반의 UI와 연결하고, GitHub API를 통해 사용자의 리포지토리 목록을 가져오는 기능을 구현한다.

## Goals
1. **GitHub API Integration (`GitHubService`)**
   - **Endpoint**: `GET /user/repos` (페이지네이션 지원)
   - **Model**: `Repository` 구조체 (name, full_name, private/public, html_url 등)
   - **Authentication**: `AuthManager`가 저장한 Keychain 토큰 사용

2. **UI Architecture (MVVM)**
   - **LoginView**: "Sign in with GitHub" 버튼 및 OAuth Flow 트리거
   - **RepoListView**:
     - 사용자 레포지토리 목록 + 로컬 세션(작업 중인 컨테이너) 목록 통합 표시
     - 검색 및 필터링
   - **LoadingView**: 컨테이너 생성 및 Clone 진행 상태 표시 (Spinner + Log)

3. **App Lifecycle**
   - 앱 실행 시 토큰 유무 체크 -> `LoginView` 또는 `RepoListView`로 라우팅
   - `SceneDelegate` (또는 `App` struct)에서 `OnOpenURL` 처리 (OAuth Callback)

## Tasks
- [ ] `GitHubService`: URLSession을 이용한 API 통신 구현
- [ ] `Repository`: Codable 데이터 모델 정의
- [ ] `LoginViewModel`: 로그인 상태 관리 (`@Published`)
- [ ] `RepoListViewModel`: 레포 목록 Fetch 및 세션 병합 로직
- [ ] SwiftUI Views 구현 (`LoginView`, `RepoListView`, `RepoRow`)

## User Flow
1. **Login**: 앱 실행 -> 로그인 버튼 클릭 -> 웹 인증 -> 콜백 -> 메인 화면 진입
2. **Dashboard**:
   - 상단: "Active Sessions" (작업 중인 컨테이너)
   - 하단: "All Repositories" (GitHub API)
3. **Action**: 레포 클릭 -> (세션 유무 판단) -> Resume 또는 New Container -> 작업 시작
