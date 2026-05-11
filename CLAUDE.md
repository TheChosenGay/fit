# Project Knowledge

## Navigation

Use `AppNavigationStack` (shared/components/AppNavigationStack.swift) as the generic navigation wrapper. Each tab in MainTabView wraps its root content in AppNavigationStack, which provides NavigationStack + navigationBarHidden. Pages within a tab use `.navigationDestination(isPresented:)` to push new screens — these automatically get right-swipe-back gesture support from the enclosing NavigationStack.

Do NOT nest NavigationStack inside individual pages. The NavigationStack lives at the tab level via AppNavigationStack. Individual views only need `.navigationDestination` modifiers.

## Architecture

- MVVM with SwiftUI: ViewModel is @MainActor ObservableObject, injected via @StateObject
- Service layer: protocol abstraction (e.g., PoseDetectService), with concrete implementations in core/
- Vision framework isolation: feature layer models (PosePoint, PoseAngle) use String types, not Vision types

## API

- Endpoints centralized in ServiceEndpoint.swift (core/network/)
- API keys in Secrets.swift (core/network/, gitignored)
- AI analysis uses DeepSeek API (OpenAI-compatible format)
