# Fit 项目待办清单

Phase 2 代码实现已完成，以下为后续工作，按类别排列。

---

## 一、新能力建设

### 1. 标准动作模型后台

搭建标准动作生成管线，为 ExerciseFormEvaluator 提供科学评分基准。

**后台：**
- FastAPI / Gin 服务搭建
- MediaPipe 姿态提取
- 动作周期检测（自相关 / 峰值检测）
- 关键帧提取 + 角度归一化
- 标准模型 JSON 存储 + API 端点

**客户端：**
- 模型下载 + 本地缓存（带版本号）
- ExerciseFormEvaluator 改造：读标准模型 → 偏差计算 → 分项评分

### 2. VideoPose3D 集成

在 RTMPose (2D) 后叠加 VideoPose3D (2D→3D)，输出 133 点 3D。

**Python 端：**
- 跑通 VideoPose3D 预训练模型
- `torch.onnx.export` → ONNX → CoreML

**iOS 端：**
- `VideoPose3DDetector`：滑动窗口缓存 → CoreML 推理 → 3D 坐标
- `Skeleton3DRenderer` 利用真实 `position3D.z`
- 训练后回放分析（3D 轨迹可视化）

### 3. 动作配置批量生成

按 Schema 让 AI 生成 20+ 个动作配置，人审后入仓。

**动作清单：** 自由重量 7 + 自体重 6 + 器械 8 = 21 个

---

## 二、技术债重构

### 🔴 P0 — API 密钥移除

Secrets.swift 硬编码密钥 → xcconfig + Info.plist。旧密钥在 Git 历史中，需在 DeepSeek 后台吊销。

### 🟡 P1

- **HTTPClient 协议抽象：** NetworkService 单例 → 协议注入，支持 mock 测试
- **OpenAI 类型提取：** DeepSeekRequest/Response 在 5 个文件中重复 → 提取为 `Core/Network/OpenAITypes.swift`
- **Markdown 清理提取：** `stripMarkdownCodeBlock` 在 4 处重复 → `String` 扩展
- **CoachContextBuilder 改协议注入：** enum 静态方法 → 协议 + init 注入

### 🟢 P2

- **WorkoutSessionViewModel 拆分：** 200 行拆为 CameraManager + CoachingEngine + ViewModel
- **ExerciseFormEvaluator 评分校准：** 魔法数字 → 标准模型驱动（依赖新能力 #1）
