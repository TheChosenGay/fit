# 标准动作序列系统

## 概述

标准动作序列系统用于生成、存储、播放和对比健身动作的标准参考数据。系统将标准视频转化为结构化的关节轨迹数据（JSON），客户端消费这些数据实现两大功能：
1. **教学展示** — 播放标准动作的 3D 骨架动画
2. **实时对比** — 用户运动时，逐帧对比用户姿态与标准姿态，给出偏差反馈

---

## 整体架构

```
┌─────────────────────────────────────────────────────────┐
│                     标准动作生成                          │
│                                                         │
│  标准视频 (.mp4)                                         │
│      │                                                  │
│      ▼                                                  │
│  RTMPose 2D (设备端/服务端)                               │
│      │  逐帧检测 133 个关节点 (x, y)                      │
│      ▼                                                  │
│  StandardActionSequence JSON                            │
│      │  保存到 Documents/StandardSequences/               │
│      ▼                                                  │
│  StandardSequenceCatalog (SwiftData 索引)                │
└─────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────┐
│                     客户端消费                            │
│                                                         │
│  ┌──────────────┐         ┌──────────────────┐         │
│  │  教学模式     │         │  实时对比模式      │         │
│  │              │         │                  │         │
│  │  加载 JSON   │         │  加载 JSON        │         │
│  │      ↓       │         │      ↓           │         │
│  │  帧插值播放   │         │  用户实时检测      │         │
│  │      ↓       │         │      ↓           │         │
│  │  蓝色骨架动画 │         │  时间对齐(阶段)    │         │
│  │              │         │      ↓           │         │
│  │              │         │  空间归一化        │         │
│  │              │         │      ↓           │         │
│  │              │         │  角度对比+位置对比  │         │
│  │              │         │      ↓           │         │
│  │              │         │  双骨架叠加显示    │         │
│  └──────────────┘         └──────────────────┘         │
└─────────────────────────────────────────────────────────┘
```

---

## 生成流程详解

### 入口

训练 Tab → "生成标准动作" → `StandardSequenceGeneratorView`

### 步骤

1. **选择视频** — 用户从相册选择一段标准动作视频
2. **输入元信息** — 填写动作 ID（如 `squat`）和动作名称（如 `深蹲`）
3. **逐帧检测** — 使用设备端 RTMPose CoreML 模型：
   - 按 30fps 采样（若原视频 fps 更高则跳帧）
   - 每帧输出 133 个关节的归一化 2D 坐标 (x, y ∈ [0, 1])
   - 记录每帧的时间戳 (timeMs)
4. **组装序列** — 将所有帧打包为 `StandardActionSequence` 结构
5. **保存 JSON** — 写入 `Documents/StandardSequences/{exerciseId}_standard_v1.json`

### 数据格式 (StandardActionSequence JSON)

```json
{
  "id": "squat_standard_v1",
  "version": 1,
  "metadata": {
    "exerciseName": "深蹲",
    "exerciseId": "squat",
    "author": "user",
    "createdAt": "2026-05-18T10:00:00Z",
    "difficulty": "intermediate",
    "durationMs": 3200,
    "sourceVideoHash": null,
    "tags": ["lower_body"]
  },
  "config": {
    "fps": 30,
    "jointSet": "coco_wholebody_133",
    "coordinateSpace": "normalized_2d",
    "rootJoint": "left_hip",
    "isLoopable": true,
    "phaseMarkers": [
      { "timeMs": 0, "phase": "standing" },
      { "timeMs": 800, "phase": "descending" },
      { "timeMs": 1600, "phase": "bottom" },
      { "timeMs": 2400, "phase": "ascending" }
    ],
    "criticalJoints": ["left_knee", "right_knee", "left_hip", "right_hip"],
    "toleranceProfile": { "global": 0.15, "jointOverrides": { "left_knee": 0.10 } }
  },
  "frames": [
    {
      "timeMs": 0,
      "joints": {
        "nose": { "x": 0.50, "y": 0.85, "z": 0.0 },
        "left_shoulder": { "x": 0.42, "y": 0.75, "z": 0.0 },
        "...": "..."
      }
    }
  ]
}
```

---

## 对比算法

### 第一步：时间对齐

用膝关节角度判断用户处于哪个动作阶段（standing / descending / bottom / ascending），然后从标准序列的 `phaseMarkers` 找到对应时间范围内的帧。

### 第二步：空间归一化

1. 计算 root（髋中心）→ 所有关节减去 root 坐标（消除位置差异）
2. 计算躯干长度（root 到 neck 距离）→ 所有坐标除以躯干长度（消除体型差异）

### 第三步：双维度对比

| 维度 | 方法 | 输出示例 |
|------|------|----------|
| 角度 | 比较关键关节角度差值 | "左膝弯曲不足 15°" |
| 位置 | 比较归一化后关节位移方向 | "膝盖内扣，需要向外推" |

综合评分 = 角度得分 × 0.6 + 位置得分 × 0.4

---

## 文件结构

```
fit/
├── Core/
│   ├── Coach/
│   │   ├── StandardActionService.swift          # 协议 + 本地加载实现
│   │   ├── SequenceComparisonService.swift      # 对比算法（角度+位置）
│   │   └── SequenceAnimationService.swift       # 帧→BodyJoints + 播放流
│   └── Data/Models/
│       ├── StandardActionSequence.swift         # JSON Codable 模型
│       └── StandardSequenceCatalog.swift        # SwiftData 目录索引
├── Features/ActionTeaching/
│   ├── ViewModels/
│   │   ├── ActionTeachingViewModel.swift        # 教学播放控制
│   │   └── StandardSequenceGeneratorViewModel.swift  # 视频→序列生成
│   └── Views/
│       ├── ActionTeachingView.swift             # 骨架动画教学页
│       └── StandardSequenceGeneratorView.swift  # 【入口】视频导入分析
├── Features/ExerciseForm/Feedback/
│   └── Skeleton3DRenderer.swift                 # 修改：支持 color/opacity
└── Resources/StandardSequences/                 # 预置标准序列 JSON
```

---

## 关键设计决策

1. **复用设备端 RTMPose 2D** — 标准序列和用户实时检测用同一模型，误差互抵
2. **2D 为主，暂不依赖 3D** — 角度计算只需 2D，位置对比通过归一化处理体型差异
3. **JSON 格式解耦** — 客户端只消费 JSON，生成方式可以是设备端或 Python 服务端
4. **本地优先** — Phase 1 本地存储，格式设计兼容未来的远程市场
5. **双骨架叠加** — Skeleton3DRenderer 新增 color 参数，绿色=用户，蓝色=标准

---

## 未来扩展

- **Phase 2**: Python 服务端用更强模型（SMPL-X）生成高精度 3D 标准序列
- **Phase 3**: 开放市场，教练/用户上传标准视频 → 审核 → 发布
- **自动 phaseMarkers**: 通过角度曲线的峰谷检测自动标注动作阶段
- **DTW 时间规整**: 替代简单的阶段匹配，支持更灵活的速度变化对齐
