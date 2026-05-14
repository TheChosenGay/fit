# 模块A：拍照与照片选择

## 需求说明
- 自定义相机（含引导线 overlay）
- 从相册选择照片
- 拍完/选完后保存到本地沙盒
- 拍照后展示预览页，Toast 提示保存成功

---

## 方案选择

| 功能 | 方案 | 原因 |
|------|------|------|
| 相机预览 | AVFoundation + UIViewRepresentable 桥接 | SwiftUI 无原生相机预览组件，必须桥接 |
| 相册选择 | PHPickerViewController + UIViewControllerRepresentable | iOS 14+ 推荐方案，无需相册读权限，隐私合规 |
| 引导线 | SwiftUI Canvas 绘制简单几何线 | MVP 快速实现，无需设计资源 |
| 照片存储 | FileManager 沙盒（Documents/photos/） | 照片是 App 内部数据，不需要写相册权限 |
| 并发模型 | async/await，CameraSession 标记 @unchecked Sendable | Swift 6 严格 actor 隔离，AVCaptureSession 自身线程安全 |
| 照片预览 | fullScreenCover + PhotoPreviewView | 全屏展示更沉浸，同时承载 Toast 和分析入口 |

---

## 分层设计

```
CameraView (UI)
    └── CameraViewModel (@MainActor，业务状态)
            ├── CameraSession (@unchecked Sendable)  → AVFoundation 封装
            ├── PhotoPickerView                       → PHPicker 桥接
            ├── PhotoPreviewView                      → 预览 + Toast
            └── LocalPhotoStorageService              → 沙盒文件读写
```

---

## 文件清单

| 文件 | 层 | 职责 |
|------|----|------|
| `features/camera/models/CameraSession.swift` | Model | AVFoundation Session 配置、拍照 |
| `features/camera/view_models/CameraViewModel.swift` | ViewModel | 权限、状态、存储调度 |
| `features/camera/views/CameraView.swift` | View | 主界面，快门+相册+预览触发 |
| `features/camera/views/CameraPreviewView.swift` | View | UIViewRepresentable 预览桥接 |
| `features/camera/views/PhotoPickerView.swift` | View | UIViewControllerRepresentable 相册桥接 |
| `features/camera/views/PhotoPreviewView.swift` | View | 照片预览、Toast、重拍/分析入口 |
| `core/storage/PhotoStorageService.swift` | Core | 照片存储协议 |
| `core/storage/LocalPhotoStorageService.swift` | Core | 沙盒文件读写实现（JPEG，压缩率 0.85） |

---

## 数据流

```
拍照 / 选照片
    ↓
CameraViewModel.savePhoto(image)
    ↓
LocalPhotoStorageService.save(image)
    → 写入 Documents/photos/{UUID}.jpg
    → 返回 fileName
    ↓
capturedImage 有值
    → onChange 触发 showPreview = true
    → PhotoPreviewView 全屏弹出
        ├── Toast "照片已保存"（2秒消失）
        ├── 重拍 → 清空 capturedImage / lastSavedFileName
        └── 开始分析 → 传递 lastSavedFileName 给模块B（TODO）
```

---

## 遇到的坑

### 1. Swift 6 Actor 隔离问题
**现象**：`CameraSession` 被 `@MainActor` 的 ViewModel 持有后，其方法被推断为 main actor 隔离，在后台线程调用报错。

**解决**：给 `CameraSession` 标记 `@unchecked Sendable`，明确告知编译器该类自行保证线程安全（`AVCaptureSession` 本身线程安全），方法可在任意线程调用。

```swift
final class CameraSession: NSObject, @unchecked Sendable { ... }
```

### 2. PHPicker 回调在后台线程
**现象**：`provider.loadObject` 的回调在后台线程返回，直接更新 UI 会警告。

**解决**：这是 PhotosUI 框架内部行为无法替换，保留 `DispatchQueue.main.async` 作为合理例外，其余地方统一用 async/await。

### 3. `GraphicsContext.StrokeStyle` 不存在
**现象**：编译报错 `Type 'GraphicsContext' has no member 'StrokeStyle'`。

**解决**：直接用顶层 `StrokeStyle`，不需要 `GraphicsContext` 前缀。

### 4. `ObservableObject` / `@Published` 缺少 Combine import
**现象**：`Type 'CameraViewModel' does not conform to protocol 'ObservableObject'`。

**解决**：`ObservableObject` 和 `@Published` 依赖 Combine 框架，需显式 `import Combine`。

---

## 好的设计总结

### UIKit 桥接隔离原则
UIKit 只出现在两个桥接文件（`CameraPreviewView`、`PhotoPickerView`）里，对外完全表现为普通 SwiftUI View，业务层零感知。

### 存储协议抽象
`PhotoStorageService` 协议 + `LocalPhotoStorageService` 实现分离，上层只依赖协议，后续可替换为 iCloud、加密存储等实现，不改业务代码。

### 数据驱动预览
`capturedImage` 变化 → `onChange` 自动触发预览，不需要手动管理弹窗时机，符合 SwiftUI 数据驱动理念。

---

## 遗留事项

- [x] Xcode Target Info 标签页添加 `NSCameraUsageDescription`
- [x] 新增文件加入 Target Membership
- [ ] 下一步：模块B Vision 姿态检测，入参为 `lastSavedFileName`

---

**完成时间**：2026-05-09
