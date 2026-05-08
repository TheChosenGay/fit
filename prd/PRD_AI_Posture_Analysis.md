# AI 体态分析助手 - 产品需求文档

## 一、产品概述

### 1.1 产品名称
体态AI（暂定）/ PostureAI

### 1.2 一句话定义
用手机拍照即可分析体态问题，提供个性化矫正方案并追踪改善进度的iOS App。

### 1.3 目标用户
- 25-40岁办公室白领（久坐导致体态问题）
- 健身初学者（想了解自身体态问题）
- 有外貌焦虑/体态焦虑的年轻人
- 产后恢复女性

### 1.4 核心价值主张
- **对比通用AI工具的差异**：需要摄像头实时拍照 + 长期数据追踪 + 可视化对比，这些是豆包/ChatGPT无法提供的
- **对比线下体态评估**：线下单次评估200-500元，App订阅30-50元/月，性价比碾压
- **对比Keep等健身App**：专注体态分析这一垂直场景，不做通用健身

### 1.5 商业模式
- 免费版：每周1次体态分析，基础报告
- 订阅版（¥30/月 或 ¥198/年）：无限次分析、详细报告、矫正方案、历史趋势对比、导出报告

---

## 二、功能模块总览

| 模块 | MVP | 完整版 | 优先级 |
|------|-----|--------|--------|
| 拍照/选照片 | ✅ | ✅ | P0 |
| 姿态检测与标注 | ✅ | ✅ | P0 |
| AI体态问题分析 | ✅ | ✅ | P0 |
| 矫正动作推荐 | ✅（图文） | ✅（视频） | P0 |
| 历史记录与对比 | ✅（基础） | ✅（完整） | P0 |
| 订阅付费墙 | ✅ | ✅ | P0 |
| 用户引导/拍照指引 | ✅ | ✅ | P1 |
| 详细分析报告 | ❌ | ✅ | P1 |
| 矫正计划（周/月） | ❌ | ✅ | P1 |
| 提醒与打卡 | ❌ | ✅ | P1 |
| 社区分享 | ❌ | ✅ | P2 |
| Apple Watch联动 | ❌ | ✅ | P2 |
| 实时动作指导（AI教练） | ❌ | ✅ | P1 |
| HealthKit集成 | ❌ | ✅ | P1 |
| 多语言（英文出海） | ❌ | ✅ | P2 |

---

## 三、MVP 功能详细设计（第一版）

### 3.1 模块A：拍照与照片选择

**功能描述**：
- 提供标准拍照引导（正面/侧面站姿轮廓线参考）
- 支持从相册选择已有照片
- 拍照时显示半透明人体轮廓辅助站位

**交互流程**：
1. 用户点击"开始分析" → 选择"拍照"或"从相册选择"
2. 拍照模式下显示正面/侧面引导线
3. 拍摄完成后自动进入分析流程

**技术方案**：
- AVFoundation 自定义相机
- 轮廓引导层用 SwiftUI overlay
- 照片存储用 Core Data + 本地文件系统

**预计开发时间**：3-4天

---

### 3.2 模块B：姿态检测与标注

**功能描述**：
- 检测人体17个关键骨骼点
- 在照片上标注关键点和连线
- 计算关键角度（头部前倾角、肩部倾斜度、骨盆倾斜角等）

**技术方案**：
- Apple Vision Framework 的 `VNDetectHumanBodyPoseRequest`
- 检测到的关键点坐标 → 计算各关节角度
- Core Graphics 在原图上绘制标注

**关键角度计算**：
```
- 头部前倾角：耳朵-肩膀连线与垂直线的夹角
- 肩部高低差：左右肩关节点的Y轴差值
- 圆肩程度：肩关节-耳朵连线与垂直线的夹角
- 骨盆前倾角：髋关节-膝关节连线与垂直线的夹角
- 腿型检测：髋-膝-踝三点的偏移度
```

**预计开发时间**：5-7天

---

### 3.3 模块C：AI体态问题分析

**功能描述**：
- 根据姿态检测结果 + 原始照片，AI给出体态分析报告
- 输出3-5个主要问题，每个问题标注严重程度（轻微/中等/明显）
- 配合可视化图示说明问题所在

**分析维度**：
| 检测项目 | 正常范围 | 问题判定 |
|---------|---------|---------|
| 头前伸 | 0-5° | >10°为明显 |
| 圆肩 | 0-10° | >15°为明显 |
| 高低肩 | 0-1cm差 | >2cm为明显 |
| 骨盆前倾 | 0-10° | >15°为明显 |
| X/O型腿 | 膝距<2cm | >3cm为明显 |

**技术方案**：
- 第一步：本地Vision框架算出角度数据
- 第二步：将角度数据 + 照片发送到 Claude/GPT API，生成自然语言分析报告
- Prompt工程：预设体态分析专家角色，输入结构化角度数据，输出结构化JSON报告

**API调用示例结构**：
```json
{
  "input": {
    "head_forward_angle": 12.5,
    "shoulder_diff_cm": 1.8,
    "round_shoulder_angle": 18.0,
    "pelvic_tilt_angle": 14.0,
    "leg_alignment_offset": 1.2
  },
  "output": {
    "issues": [
      {
        "name": "圆肩",
        "severity": "moderate",
        "description": "肩关节前旋明显，胸肌紧张...",
        "score": 65
      }
    ],
    "overall_score": 72
  }
}
```

**预计开发时间**：4-5天

---

### 3.4 模块D：矫正动作推荐

**功能描述**：
- 针对每个体态问题推荐2-3个矫正动作
- 每个动作包含：名称、图示、步骤说明、每组次数、每日建议组数
- MVP阶段用静态图+文字，后续迭代加视频

**内容规划**（MVP预置动作库）：
```
圆肩矫正：
  - 墙壁天使（Wall Angel）
  - 面拉（Face Pull弹力带版）
  - 胸肌拉伸

头前伸矫正：
  - 收下巴训练（Chin Tuck）
  - 颈部后侧拉伸
  - 胸锁乳突肌放松

骨盆前倾矫正：
  - 死虫式（Dead Bug）
  - 臀桥（Glute Bridge）
  - 髂腰肌拉伸

高低肩矫正：
  - 单侧上斜方肌拉伸
  - 低侧耸肩训练
  - 侧卧旋转拉伸

X/O型腿矫正：
  - 蚌式开合
  - 靠墙静蹲（夹球）
  - 单腿平衡训练
```

**技术方案**：
- 本地JSON数据库存储动作信息
- 动作图片素材（可用AI生成或购买版权图）
- 根据AI分析结果自动匹配推荐

**预计开发时间**：3-4天（含内容制作）

---

### 3.5 模块E：历史记录与对比

**功能描述**：
- 记录每次分析结果（日期、评分、各项角度数据）
- 支持两次记录的照片左右对比
- 简单趋势图展示改善进度

**技术方案**：
- Core Data 存储分析记录
- SwiftUI Charts 展示趋势
- 照片本地存储，按日期索引

**预计开发时间**：3-4天

---

### 3.6 模块F：订阅付费墙

**功能描述**：
- 免费用户：每周1次分析，基础报告（仅告诉问题，不给详细方案）
- 订阅用户：无限次分析 + 完整矫正方案 + 历史趋势 + 导出PDF报告
- 提供3天免费试用

**订阅方案**：
- 月付：¥30/月（海外 $4.99/月）
- 年付：¥198/年（海外 $39.99/年）
- 试用：3天免费，到期自动续订

**技术方案**：
- StoreKit 2
- 服务端receipt验证（可选，初期可仅客户端验证）
- RevenueCat SDK（简化订阅管理，推荐使用）

**预计开发时间**：2-3天

---

## 四、完整版功能设计（后续迭代）

### 4.1 V1.1 - 详细分析报告（MVP上线后2周）

- PDF/图片格式导出
- 包含所有角度数据 + 体态评分 + 改善建议
- 可分享到社交媒体（自带App水印 = 免费传播）

### 4.2 V1.2 - 矫正计划系统（MVP上线后1个月）

- 根据体态问题自动生成4周矫正计划
- 每日任务清单（3-5个动作，每次10-15分钟）
- 本地通知提醒训练
- 完成打卡 + 连续天数统计

### 4.3 V1.3 - 视频动作库（MVP上线后2个月）

- 每个矫正动作配真人演示视频
- 支持跟练模式（倒计时+语音提示）
- 可与Apple Health联动记录运动数据

### 4.4 V1.5 - HealthKit集成（MVP上线后1.5个月）

**读取数据**：
- 自动获取用户身高、体重（Onboarding免手动输入）
- 读取每日步数、活动消耗（判断用户活动水平）
- 读取体重变化趋势（结合体态改善给建议）

**写入数据**：
- 矫正训练记录为Workout（类型：functionalStrengthTraining）
- 记录训练时长、估算消耗卡路里
- 用户在Apple健康App中可看到"体态矫正训练"记录

**权限设计**：
- 首次使用时弹出HealthKit授权（明确说明用途）
- 用户可拒绝，不影响核心功能使用
- Info.plist需配置NSHealthShareUsageDescription和NSHealthUpdateUsageDescription

**技术方案**：
- HealthKit Framework
- HKHealthStore读写
- HKWorkoutType记录训练
- HKQuantityType读取身体指标

**预计开发时间**：3-4天

---

### 4.5 V2.0 - 实时动作指导模块 / AI教练（MVP上线后2-3个月）

**产品定义**：
用户跟着矫正动作训练时，打开摄像头，AI实时检测动作是否标准，语音/视觉提醒纠正。

**核心体验**：
```
用户选择矫正动作 → 打开前置摄像头 → 开始跟练
     ↓
实时检测骨骼关节角度（每秒15-30帧）
     ↓
对比"标准动作"角度范围
     ↓
偏差超过阈值 → 语音提示"手臂再抬高一点" / 屏幕标红提示
     ↓
动作达标 → 计次 + 语音鼓励"很好，继续"
```

**功能详细设计**：

1. **动作识别与计次**
   - 每个动作定义多个阶段（起始位→目标位→回落）
   - 自动检测完成一次rep
   - 自动计次 + 组间休息倒计时

2. **实时纠错反馈**
   - 关节角度偏离标准范围 → 触发提醒
   - 视觉反馈：骨骼线变红，箭头指示正确方向
   - 语音反馈：AVSpeechSynthesizer播报提示语
   - 防抖设计：偏差持续>0.5秒才触发，避免抖动误报

3. **动作评分**
   - 每次rep评分（动作标准度0-100）
   - 整组训练评分
   - 历史评分趋势

**支持的初始动作库（V2.0首批10个）**：
```
圆肩矫正：墙壁天使、弹力带面拉
头前伸矫正：收下巴训练
骨盆前倾矫正：臀桥、死虫式
通用矫正：猫牛式、鸟狗式
拉伸类：胸肌拉伸、髂腰肌拉伸、上斜方肌拉伸
```

**每个动作的数据定义**：
```json
{
  "exercise_id": "glute_bridge",
  "name": "臀桥",
  "phases": [
    {
      "name": "起始",
      "duration_hint": "准备姿势",
      "joint_rules": [
        {"joint": "knee", "angle_range": [85, 95], "feedback": "膝盖弯曲约90度"}
      ]
    },
    {
      "name": "顶点",
      "duration_hint": "臀部抬到最高点",
      "joint_rules": [
        {"joint": "hip_extension", "angle_range": [160, 180], "feedback": "臀部再抬高一点"},
        {"joint": "knee", "angle_range": [85, 100], "feedback": "膝盖保持不动"},
        {"joint": "spine", "angle_range": [170, 180], "feedback": "不要塌腰，收紧核心"}
      ]
    },
    {
      "name": "回落",
      "duration_hint": "缓慢放下",
      "joint_rules": [
        {"joint": "hip_speed", "max_speed": 0.3, "feedback": "放慢速度，控制下落"}
      ]
    }
  ],
  "reps_per_set": 12,
  "sets": 3,
  "rest_between_sets": 30,
  "common_mistakes": [
    {"pattern": "lumbar_hyperextension", "feedback": "不要用腰代偿，核心收紧"},
    {"pattern": "knees_caving_in", "feedback": "膝盖不要内扣，往外推"}
  ]
}
```

**技术架构（独立Swift Package设计）**：
```
PoseCoachKit (Swift Package)
├── Sources/
│   ├── PoseCoach.swift           // 核心引擎入口
│   ├── PoseDetector.swift        // Vision实时检测封装
│   ├── AngleCalculator.swift     // 关节角度计算
│   ├── PhaseTracker.swift        // 动作阶段追踪（起始→顶点→回落）
│   ├── RepCounter.swift          // 自动计次逻辑
│   ├── FeedbackEngine.swift      // 反馈触发规则引擎
│   ├── VoiceFeedback.swift       // 语音播报
│   └── Models/
│       ├── Exercise.swift        // 动作定义模型
│       ├── JointRule.swift       // 关节角度规则
│       └── PoseFeedback.swift    // 反馈数据模型
└── Tests/
```

**对外接口设计**：
```swift
public class PoseCoach {
    /// 初始化，传入目标动作
    public init(exercise: Exercise)
    
    /// 绑定相机Session开始实时检测
    public func startSession(camera: AVCaptureSession)
    
    /// 停止检测
    public func stopSession()
    
    /// 实时反馈回调（动作不标准时触发）
    public var onFeedback: ((PoseFeedback) -> Void)?
    
    /// 完成一次rep回调
    public var onRepComplete: ((RepResult) -> Void)?
    
    /// 完成一组回调
    public var onSetComplete: ((SetResult) -> Void)?
    
    /// 当前检测状态
    public var currentPhase: Phase { get }
    public var repCount: Int { get }
    public var setCount: Int { get }
}
```

**独立模块的复用策略**：
| 使用方式 | 说明 |
|---------|------|
| 集成到体态分析App | 作为"AI教练"高级功能，提升订阅价值 |
| 独立App上架 | "AI动作教练"，单独变现 |
| SDK对外授权 | 卖给其他健身App开发者（B2B） |

**技术要点**：
- 全部本地运行，不需要网络，不调API，零边际成本
- Vision Framework实时处理（iPhone 12+可达30fps）
- AVSpeechSynthesizer本地语音合成（不需要TTS API）
- 低电量优化：降至15fps，减少计算负荷

**预计开发时间**：2-3周（10个动作的完整规则定义+测试）

---

### 4.6 V2.1 - 社区与出海

- 用户体态改善前后对比社区
- 多语言支持（英语、日语）
- 内容本地化

---

## 五、技术架构

### 5.1 整体架构

```
┌─────────────────────────────────────────────────┐
│              UI Layer (SwiftUI)                   │
├─────────────────────────────────────────────────┤
│            ViewModel Layer                        │
├──────────┬──────────┬──────────┬────────────────┤
│  Camera  │  Vision  │  AI      │  PoseCoachKit  │
│  Module  │  Module  │ Analysis │  (独立Package) │
├──────────┴──────────┴──────────┴────────────────┤
│           Data Layer                              │
│  Core Data | FileManager | UserDefaults           │
├─────────────────────────────────────────────────┤
│        Service Layer                              │
│  StoreKit 2 | Network | RevenueCat | HealthKit    │
└─────────────────────────────────────────────────┘
```

### 5.2 技术选型

| 层级 | 技术 | 说明 |
|------|------|------|
| UI | SwiftUI | 主要UI框架 |
| 架构 | MVVM + Coordinator | 标准iOS架构 |
| 相机 | AVFoundation | 自定义拍照+实时视频流 |
| 姿态检测 | Vision Framework | Apple原生，本地运行，无需网络 |
| 实时动作指导 | PoseCoachKit（自建Swift Package） | 独立模块，可复用可单独上架 |
| AI分析 | Claude API / OpenAI API | 生成分析报告（仅传角度数据，不传照片） |
| 本地存储 | Core Data + FileManager | 记录+照片 |
| 图表 | Swift Charts | iOS 16+ 原生图表 |
| 订阅 | RevenueCat + StoreKit 2 | 订阅管理 |
| 健康数据 | HealthKit | 读取身高体重/写入训练记录 |
| 语音反馈 | AVSpeechSynthesizer | 本地语音合成，零成本 |
| 网络 | URLSession + async/await | 原生网络层 |
| 最低版本 | iOS 16.0 | Vision姿态检测需iOS 14+，Charts需iOS 16+ |

### 5.3 核心技术详解

#### 5.3.1 Vision Framework（本地姿态检测）

**是什么**：Apple内置的机器学习框架，在设备本地运行预训练的CNN模型，通过Neural Engine加速推理。不需要网络、不上传数据、零API成本。

**为什么能本地运行**：
- Apple在iOS系统中预装了训练好的人体姿态检测模型
- 运行在iPhone的Neural Engine芯片上（A12及以后，即iPhone XS+）
- 模型随iOS更新自动升级，开发者无需管理

**能检测的17个关键点**：
```
头部：鼻子、左眼、右眼、左耳、右耳
上肢：左肩、右肩、左肘、右肘、左腕、右腕
躯干：颈部、躯干中心
下肢：左髋、右髋、左膝、右膝、左踝、右踝
```

**每个点返回的数据**：
- (x, y) 归一化坐标（0-1范围）
- confidence 置信度（0-1，>0.5可信）

**性能指标**：
- 静态图片检测：30-100ms
- 实时视频流：iPhone 12+ 可达30fps
- 支持同时检测多人

**关键API使用**：
```swift
import Vision

// 静态图片检测
let request = VNDetectHumanBodyPoseRequest()
let handler = VNImageRequestHandler(cgImage: photo, options: [:])
try handler.perform([request])
let bodyPose = request.results?.first

// 获取关节点
let leftShoulder = try bodyPose?.recognizedPoint(.leftShoulder)
let rightShoulder = try bodyPose?.recognizedPoint(.rightShoulder)
let leftEar = try bodyPose?.recognizedPoint(.leftEar)

// 实时视频流检测（用于V2.0实时动作指导）
// AVCaptureVideoDataOutput → 每帧送入VNImageRequestHandler
```

**在本App中的两种使用模式**：
| 模式 | 用于 | 频率 |
|------|------|------|
| 静态图片检测 | MVP拍照分析 | 拍一次检测一次 |
| 实时视频流检测 | V2.0动作指导 | 每秒15-30帧持续检测 |

**与AI API的分工**：
```
Vision（免费本地） → 检测骨骼点坐标 → 计算角度数值
                                          ↓ 仅传数字
Claude API（付费云端） ← 接收角度数据 → 生成自然语言分析报告
```
照片永远不出设备，API只接收几个角度数字，既保隐私又省成本。

---

#### 5.3.2 HealthKit集成方案

**是什么**：Apple的健康数据统一框架，管理用户在Apple健康App中的所有健康和运动数据。

**在本App中的作用**：

| 功能 | 读/写 | 数据类型 | 用途 |
|------|-------|---------|------|
| 自动获取身高体重 | 读 | HKQuantityType.height/bodyMass | 免去用户手动输入 |
| 读取活动水平 | 读 | stepCount/activeEnergyBurned | 评估用户运动习惯 |
| 记录矫正训练 | 写 | HKWorkoutType | 用户在Apple健康看到训练记录 |
| 记录训练消耗 | 写 | activeEnergyBurned | 训练卡路里同步 |
| 体重趋势 | 读 | bodyMass | 结合体态变化给出综合建议 |

**权限申请设计**：
```swift
// 申请读取
let readTypes: Set<HKObjectType> = [
    HKQuantityType(.height),
    HKQuantityType(.bodyMass),
    HKQuantityType(.stepCount),
    HKQuantityType(.activeEnergyBurned)
]

// 申请写入
let writeTypes: Set<HKSampleType> = [
    HKWorkoutType.workoutType(),
    HKQuantityType(.activeEnergyBurned)
]

// 授权弹窗（向用户解释为什么需要）
healthStore.requestAuthorization(toShare: writeTypes, read: readTypes)
```

**Info.plist必须配置**：
```xml
<key>NSHealthShareUsageDescription</key>
<string>读取身高体重用于个性化体态分析，读取运动数据用于评估活动水平</string>

<key>NSHealthUpdateUsageDescription</key>
<string>记录你的矫正训练数据到Apple健康</string>
```

**用户体验设计原则**：
- HealthKit是可选的，拒绝授权不影响核心功能
- 首次使用时引导授权，说明具体好处
- 授权后自动填入身高体重，减少一步手动操作

---

### 5.4 关键技术风险与对策

| 风险 | 影响 | 对策 |
|------|------|------|
| 照片角度不标准导致检测不准 | 分析结果不可信 | 强引导拍照姿势 + 质量检测（检测到不合格照片提示重拍） |
| Vision框架检测精度有限 | 角度计算误差大 | 多次检测取均值 + 设置容错阈值 |
| AI API调用成本 | 用户量大时成本高 | 本地规则引擎处理简单case，复杂case才调API；只传角度数据不传图片 |
| 苹果审核风险（健康类声明） | 被拒 | 声明"仅供参考，非医疗建议"，避免使用"诊断""治疗"等词 |
| HealthKit授权被拒 | 部分功能不可用 | 设计为可选功能，拒绝后手动输入即可 |
| 实时检测耗电 | 用户体验差 | 限制训练时长提示+低电量自动降帧到15fps |

---

## 六、开发排期（MVP）

**总预估：4-5周**（按每天2-3小时业余时间计算）

| 周次 | 任务 | 产出 |
|------|------|------|
| 第1周 | 项目搭建 + 相机模块 + 拍照引导 | 能拍照/选照片 |
| 第2周 | Vision姿态检测 + 角度计算 + 标注绘制 | 照片上能看到骨骼标注 |
| 第3周 | AI分析接入 + 报告UI展示 + 矫正动作内容 | 核心链路跑通 |
| 第4周 | 历史记录 + 对比功能 + 订阅付费 | 完整MVP功能 |
| 第5周 | 测试 + UI打磨 + App Store提审 | 上线 |

---

## 七、运营与增长策略

### 7.1 内容营销（零成本获客）

**小红书**：
- "拍张照AI帮你分析体态问题"——用户晒分析结果截图，天然UGC
- 体态改善前后对比——自带传播力
- 办公室体态自救指南——知识类内容

**视频号/抖音**：
- 演示App使用过程（15秒就能讲清楚）
- "你以为的站姿 vs AI看到的"——反差内容
- 矫正动作教学——引流到App

### 7.2 增长飞轮

```
用户拍照分析 → 分享结果图到社交平台 → 
新用户看到下载App → 拍照分析 → 分享...
```

关键设计：分析结果图自带App水印+二维码

### 7.3 关键指标

- DAU / WAU
- 付费转化率（目标：免费→订阅 5-8%）
- 周留存率（目标：>30%）
- 单用户API调用成本（目标 <¥0.5/次）

---

## 八、成本估算

### MVP阶段月成本

| 项目 | 费用 |
|------|------|
| Apple Developer 账号 | ¥688/年 ≈ ¥57/月 |
| AI API调用（1000用户 × 4次/月） | ¥200-400/月 |
| 服务器（如需后端） | ¥0（初期可纯客户端） |
| 设计素材（动作图） | 一次性¥500-1000（AI生成） |
| **总计** | ¥300-500/月 |

### 盈亏平衡点
- 月订阅¥30，苹果抽成后约¥21/用户/月
- 需约20个付费用户即可覆盖运营成本
- 目标：6个月内达到500付费用户 = ¥10,500/月

---

## 九、竞品分析

| 竞品 | 定位 | 优势 | 劣势 | 我们的差异化 |
|------|------|------|------|-------------|
| Keep | 综合健身 | 用户量大 | 体态分析非核心功能 | 我们专注体态，更深更准 |
| 体态评估小程序 | 体态检测 | 微信生态 | 功能简陋，无追踪 | 原生App体验+长期追踪 |
| Posture by Muscle & Motion | 海外体态App | 专业度高 | 无AI，手动标注 | AI自动分析，零门槛 |
| AI健身类通用App | 综合AI健身 | 功能多 | 不专注体态 | 垂直场景做到极致 |

---

## 十、里程碑与成功标准

| 里程碑 | 时间 | 成功标准 |
|--------|------|---------|
| MVP上线 | 第5周 | App Store审核通过 |
| 种子用户验证 | 第8周 | 100+下载，10+付费 |
| 内容营销启动 | 第6周 | 小红书首篇笔记发布 |
| PMF验证 | 第12周 | 500+付费用户，周留存>30% |
| V2.0规划启动 | 第16周 | 月收入过万 |
