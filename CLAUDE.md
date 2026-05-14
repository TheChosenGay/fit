# Project Knowledge

## Navigation

Use `AppNavigationStack` (shared/components/AppNavigationStack.swift) as the generic navigation wrapper. Each tab in MainTabView wraps its root content in AppNavigationStack, which provides NavigationStack + navigationBarHidden. Pages within a tab use `.navigationDestination(isPresented:)` to push new screens — these automatically get right-swipe-back gesture support from the enclosing NavigationStack.

Do NOT nest NavigationStack inside individual pages. The NavigationStack lives at the tab level via AppNavigationStack. Individual views only need `.navigationDestination` modifiers.

## Architecture

- MVVM with SwiftUI: ViewModel is @MainActor ObservableObject, injected via @StateObject
- Service layer: protocol abstraction (e.g., PoseDetectService), with concrete implementations in core/
- Vision framework isolation: feature layer models (PosePoint, PoseAngle) use String types, not Vision types

## Pose Detection

- Phase 1 (current): Integrating RTMPose-WholeBody CoreML model for 133 2D keypoints (body 17 + feet 6 + hands 42 + face 68)
- Phase 2 (planned): Dual-model — RTMPose 133-point 2D + Apple Vision 19-point 3D, aligned via shared joints
- Conversion pipeline: PyTorch (.pth) → ONNX (.onnx) → CoreML (.mlpackage)
- Feature layer keeps String-typed joint names — no CoreML/Vision types leak into features

## API

- Endpoints centralized in ServiceEndpoint.swift (core/network/)
- API keys in Secrets.swift (core/network/, gitignored)
- AI analysis uses DeepSeek API (OpenAI-compatible format)
