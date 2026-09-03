# 关于 cue 的解码器

> 整理自 `DecodePreTransfer_Cue.m` 创建之后的讨论与迭代记录。
> 主题：用**群体钙成像**训练 **Audio vs Light（cue）解码器**，检验其在 pre-Transfer 阶段的 cue 解码能力，以及在 **Transfer LightWater** 上的泛化；并补充 hit/miss 副对照与"更纯净"的 cue 解码器版本。
> 数据：`UniExp.AudioLightBaseline`；刺激类型 `AudioWater / LightOnly / AudioOnly / LightWater`；阶段 `Naive / Learned / Transfer`（**不含 Recall**）。
> 所有脚本用 **MATLAB MCP** 运行（不用 `matlab batch`）。

---

## 1. 涉及脚本一览

| 脚本 | 角色 | 说明 |
|---|---|---|
| `DecodePreTransfer_ChoiceCuePerf.m` | 父脚本 | 3 个解码器（choice / cue / performance），12 张图；`DecodePreTransfer_Cue.m` 由它拆出 |
| **`DecodePreTransfer_Cue.m`** | **主脚本** | cue 解码器（本次迭代核心），大图 + hit/miss 副对照 |
| `DecodeCalibCue_TaskContexts.m` | 尝试脚本 | 仅用 LAu/LAuW 校准 trial 训练（同上下文），检验上下文混杂 |
| `DecodePureCue_CalibMiss.m` | 纯净版脚本 | 校准 + **仅 miss** 训练（上下文、行为都匹配，只差 cue） |
| `CheckCellOverlap_PreTransfer_Transfer.m` | 辅助检查 | pre-Transfer AW ↔ Transfer LW 细胞对齐：10/11 鼠 100%，yqn0240 99.5% |

---

## 2. 主脚本 `DecodePreTransfer_Cue.m`

### 2.1 设计
- **训练**：pre-Transfer 的 `AudioWater`（Naive/Learned/无标注阶段）+ `AudioOnly` + `LightOnly`（LAu/LAuW），**无 Recall**；cue 标签 Audio=0 / Light=1。
- **Stage1 测试**：pre-Transfer 数据 5 折交叉验证（out-of-fold，`iCvPredict`），有真实两类 → 输出**解码互信息 MI**。
- **Stage2 测试**：Transfer LightWater（held-out，全为 light）→ 单类 MI 无意义，改为输出 **tendency to Audio** `P(audio) = 1 − P(light)`。
- **方法**：linear readout（`iLinDecode`）+ GLM 朴素贝叶斯（`iGlmDecode`）。
- **基线归一化**：`doBaselineNorm = true`（逐 trial-细胞减去刺激前基线）——实验证明**结果几乎不变**（见 §5.1）。
- **类别平衡**：`iBalanceTrain` 降采样，避免类别不平衡。

### 2.2 输出图片（最终版）

| 图片 | 含义 |
|---|---|
| `DecodeCue_Combined_Fig1.png` | **linear** 大图，1×3：①Stage1 解码 MI → ②Stage1 tendency to Audio → ③Stage2 tendency to Audio |
| `DecodeCue_Combined_Fig2.png` | **glm** 大图，同上 |
| `DecodeCue_HitMiss_Fig7.png` | **linear** hit/miss 副对照（2×2） |
| `DecodeCue_HitMiss_Fig8.png` | **glm** hit/miss 副对照（2×2） |

（早期按面板拆分的中间图 `DecodeCue_Audio_Fig1..6.png` 已被合并大图取代。）

### 2.3 数值与含义（10 只有效鼠）

**面板① Stage1 解码 MI**
- linear 均值 0.062 bits（峰值 0.110 @+0.96s）；glm 均值 0.070 bits（峰值 0.134 @+0.96s）
- → pre-Transfer 群体活动携带 cue 信息，刺激后上升；但量级小，单时间点区分度弱。

**面板② Stage1 tendency to Audio**
| 曲线 | linear 均值/峰值 | glm 均值/峰值 |
|---|---|---|
| audio only | 0.576 / 0.594 | 0.618 / 0.777 |
| light only | 0.433 / 0.447 | 0.184 / 0.252 |
| audio hit | 0.559 / 0.582 | 0.574 / 0.749 |
| audio miss | 0.624 / 0.645 | 0.739 / 0.876 |

- → 解码器能分开两类：audio trial 倾向 audio、light trial 倾向 light（glm 后验更极端）；audio miss 反而比 audio hit 更"audio"——读的是 cue 而非行为。

**面板③ Stage2 tendency to Audio（Transfer LightWater）**
| 曲线 | linear 均值/峰值 | glm 均值/峰值 |
|---|---|---|
| light hit | 0.514 / 0.545 | 0.558 / 0.721 |
| light miss | 0.500 / 0.516 | 0.493 / 0.592 |

- → **关键负结果**：Transfer LightWater 没有被判成 light（P(audio)≥chance，glm 甚至升到 0.72），即 pre-Transfer 训练的 cue 表征没有泛化到 Transfer 的 light 任务。

### 2.4 hit/miss 副对照（用同一 cue 解码器解行为）

设计：以解码器得分阈值预测 hit/miss，算**平衡准确率**；并按 hit/miss 分组的 **P(hit)=sigmoid(−score)** 曲线。Stage1 只取 **AudioWater**、Stage2 只取 **LightWater**。

| 阶段 | balacc（linear/glm） | P(hit) hit vs miss（linear/glm，t>0） |
|---|---|---|
| Stage1 AudioWater | 0.499 / 0.503（chance） | 0.566 / 0.564；0.650 / 0.670（几乎不分开） |
| Stage2 LightWater | 0.542 / 0.534（显著 >chance） | 0.521 / 0.495；0.610 / 0.475（t>0 分开） |

- Stage1（AudioWater 任务上下文内）：**解不出 hit/miss**（chance）。
- Stage2（LightWater）：**能显著分开**（glm 10/10 鼠、sign-test p=0.002）——这并非独立行为解码，而是暴露训练轴里 **cue×绩效混杂**：训练 audio 类含任务/高表现、light 类全来自校准/低表现；在 Transfer LW 上 hit trial 更像训练 audio 侧、miss trial 更像 light 侧。
- **Stage1=chance、Stage2=显著 的不对称**正是该混杂的直接证据。

---

## 3. 尝试脚本 `DecodeCalibCue_TaskContexts.m`

### 3.1 设计
- 训练**仅**用 `AudioOnly + LightOnly`（LAu/LAuW 校准块，同一上下文）→ 从训练中去除"任务 vs 校准"上下文混杂。
- 测试：Naive AudioWater、Transfer LightWater。输出 P(light)（该脚本仍为 P(light) 框架，0=audio、1=light）。

### 3.2 输出图片
| 图片 | 含义 |
|---|---|
| `CalibCue_Fig1.png` | linear：P(light) 在 Naive AW（左）与 Transfer LW（右），all/hit/miss |
| `CalibCue_Fig2.png` | glm：同上 |

### 3.3 数值与含义（9 只有效鼠，vtf0354 缺 Naive AW）
- **Naive AudioWater**：glm P(light) 峰值 ≈ 0.27（强倾向 audio）——audio 的 cue 表征能跨"校准→Naive 任务"泛化。
- **Transfer LightWater**：P(light) 接近 chance（linear）甚至轻微偏 audio（glm 0.43）——**仍判不出 light**。
- **基线回到 chance**：两个测试条件下 t<0 基线 ≈ 0.50，证明原脚本的基线分离来自上下文混杂（任务 AudioWater vs 校准 LightOnly）。

---

## 4. 纯净版 `DecodePureCue_CalibMiss.m`

### 4.1 设计（只差 cue，别无其他）
- 训练：`AudioOnly vs LightOnly`（LAu/LAuW 校准），**且都只用 miss trial**。
- 两类在**上下文**（都校准）与**行为**（都 miss）上完全匹配 → **唯一差异是刺激 cue**。
- 测试：Naive AudioWater、Transfer LightWater。输出 P(audio)。

### 4.2 输出图片
| 图片 | 含义 |
|---|---|
| `PureCue_Fig1.png` | linear：P(audio) 在 Naive AW（左）与 Transfer LW（右），all/hit/miss |
| `PureCue_Fig2.png` | glm：同上 |

### 4.3 数值与含义（9 只有效鼠）
| | Naive AW 基线→峰值 | Transfer LW 基线→峰值 |
|---|---|---|
| linear | 0.496 → 0.539（弱 audio） | 0.500 → ~0.50（无 light） |
| glm | 0.447 → **0.706**（强 audio） | 0.508 → 0.597（**偏 audio**） |

- ① **基线干净**：linear 两条件下基线 ≈ 0.50（对比原解码器 glm 基线 0.80–0.85）。
- ② **audio 泛化成立**：纯解码器仍把 Naive AW 判成 audio（glm P(audio)→0.71）。
- ③ **Transfer LW 仍判不出 light**：排除"训练混杂导致解不出 light"的解释 → 是 **light 表征在 Transfer 阶段被重构**（light 变成任务相关刺激后，其群体表征与校准 light 不再相似）。

---

## 5. 关键结论与踩坑

### 5.1 主要科学结论
1. **基线归一化无效**：逐 trial-细胞减基线几乎不改变结果（原值 vs 归一化后几乎相同）→ 基线分离不是简单加性偏移，而是群体模式差异。
2. **上下文混杂确实存在**：训练 audio（任务、高表现）vs light（校准、低表现）导致解码器基线处偏离 chance；纯校准训练后基线回到 chance。
3. **audio 的 cue 表征能泛化**（校准→Naive 任务），**light 的表征不能泛化**到 Transfer LightWater——负结果稳健，即使最纯的解码器也如此。
4. **hit/miss 副对照**：Stage1（AudioWater 内）chance、Stage2（LightWater 内）显著——不对称暴露 cue×绩效混杂；cue 解码器读的是 cue 轴，不是纯净行为轴，也不是纯净刺激轴。

### 5.2 方法学踩坑（已修正/记录）
- **Stage2 balacc 符号错误**：原先用 `sTe>0` 预测 hit，但数据表明 hit trial 判到 audio 侧（`sTe<0`）；修正后 Stage2 balacc 0.46 → **0.54**（显著）。
- **Stage1 hit/miss 需限定 AudioWater**：最初把 AudioOnly/LightOnly 混入，导致 Stage1 对照不纯；用 `Src` 列标记（1=AudioWater, 2=AudioOnly, 3=LightOnly）后只取 AudioWater。
- **P 的语义**：主图 y 轴为 `P(audio)`；hit/miss 副对照 y 轴为 `P(hit)=sigmoid(−score)`（同一数值，不同语义）。
- **图片合并**：主图按模型合并为 `[MI] [Stage1] [Stage2]` 大图；hit/miss 副对照保持独立 2×2。
- **运行规范**：MATLAB MCP 运行、不用 `matlab batch`、无 Recall、`rng(42)` 固定。
