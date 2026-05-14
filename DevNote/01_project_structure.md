# 项目结构搭建

## 需求说明
初始化 PostureAI（工程名 fit）项目的目录结构和基础代码骨架。

---

## 方案选择

### 架构模式
选择 **按 feature 模块拆分** 的 MVVM 架构。每个功能模块自包含 views / view_models / models，内聚性强，后续新增模块不影响已有代码。

### 存储层
采用**抽象 StorageService 协议**屏蔽版本差异：
- iOS 17+：SwiftDataStorageService（与 SwiftUI 更原生）
- iOS 16：CoreDataStorageService（兜底）
- 上层业务代码只依赖协议，不感知底层实现

### 最低支持版本
iOS 16（Swift Charts 需要 iOS 16+）

---

## 目录结构

```
fit/
├── features/                   # 按功能模块组织
│   ├── camera/                 # 模块A：拍照
│   ├── pose_analysis/          # 模块B+C：姿态检测+AI分析
│   ├── correction/             # 模块D：矫正动作
│   ├── history/                # 模块E：历史记录
│   └── subscription/           # 模块F：订阅付费
├── core/                       # 跨模块基础能力
│   ├── network/                # 网络层（AI API）
│   ├── storage/                # 存储抽象层
│   ├── vision/                 # Vision 封装
│   └── extensions/             # Swift 工具扩展
├── shared/                     # 共享 UI 组件和样式
│   ├── components/             # 通用组件（TabView 等）
│   └── styles/                 # 颜色/字体 Token
└── resources/                  # 静态资源
    ├── assets/
    └── exercises_data/         # 矫正动作 JSON
```

---

## 已创建文件清单

| 文件 | 说明 |
|------|------|
| `core/storage/StorageService.swift` | 存储协议定义 |
| `core/storage/StorageServiceFactory.swift` | 按系统版本返回实现 |
| `core/storage/CoreDataStorageService.swift` | iOS 16 实现 |
| `core/storage/SwiftDataStorageService.swift` | iOS 17+ 实现 |
| `core/network/NetworkService.swift` | 通用网络请求封装（async/await）|
| `core/vision/VisionPoseDetector.swift` | Vision 姿态检测封装 |
| `shared/components/MainTabView.swift` | 主 TabBar 导航 |
| `shared/styles/AppColors.swift` | 颜色 Token |
| `shared/styles/AppFonts.swift` | 字体 Token |
| `features/*/views/*.swift` | 各模块占位 View |
| `fitApp.swift` | App 入口，接入 MainTabView |

---

## 设计亮点

1. **StorageService 协议抽象**：业务层零感知存储实现，未来迁移 SwiftData 只需改 Factory，不动业务代码。
2. **VisionPoseDetector async/await 封装**：将 Vision 的 completion handler 包装为 async，与 SwiftUI 异步模型统一。
3. **NetworkService 泛型设计**：单一 `request<T: Decodable>` 方法覆盖所有 API 调用场景。

---

## 遗留事项

- [ ] 需要在 Xcode 中将新建的 .swift 文件手动加入 Target Membership（Xcode 不自动感知文件系统新增文件）
- [ ] AppColors 中的颜色 Token 需要在 Assets.xcassets 中配套创建 Color Set
- [ ] 下一步：模块A 拍照功能开发

---

**完成时间**：2026-05-08
