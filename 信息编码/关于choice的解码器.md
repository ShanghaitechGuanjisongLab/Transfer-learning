# 关于 choice 的解码器（hit/miss）

> 整理自 hit/miss（choice）解码器的讨论记录。
> 主题：用群体钙成像**解码 hit/miss（行为/choice）**，主任务为 hit/miss，cue（audio vs light）作为对照。检验 pre-Transfer 训练能否解码行为，以及能否泛化到 Transfer。
> 数据：`UniExp.AudioLightBaseline`；刺激 `AudioWater / AudioOnly / LightOnly / LightWater`；阶段 `Naive / Learned / Transfer`（**无 Recall**）。
> 运行：MATLAB MCP（不用 `matlab batch`）。

---

## 1. 涉及脚本

| 脚本 | 角色 |
|---|---|
| `DecodePreTransfer_HitMiss.m` | 主脚本：choice（hit/miss）解码器，四种方案，cue 为对照 |
| （对照参考）`DecodePreTransfer_Cue.m` | cue 解码器（audio vs light）——见 `关于cue的解码器.md` |

---

## 2. 设计方案（`DecodePreTransfer_HitMiss.m`）

- **主任务**：解码 hit/miss（`Behavior`，hit=1 / miss=0）。
- **对照**：解码 cue（audio=0 / light=1），在同一训练数据上训练。
- **四种训练方案**：
  - 方案1（allPre）：全部 pre-Transfer 数据（AudioWater Naive/Learned/无标注 + AudioOnly + LightOnly，无 Recall）
  - 方案2（audioOnly）：仅 AudioWater
  - 方案3（audioOnlyPerf50）：仅 AudioWater 中 block Performance>0.5 的高表现块
  - 方案4（audioOnlyLowPerf）：仅 AudioWater 中 block Performance<0.6 的低表现块
  - （`Performance` 为 0–1 分数，>0.5 即命中率>50%）
- **测试两阶段**：Stage1 = pre-Transfer（5 折 CV out-of-fold）；Stage2 = Transfer LightWater（held-out）。
- **指标**：解码互信息 MI（主）、平衡准确率、tendency（P(hit) / P(audio)）。
- **方法**：linear + glm。
- **基线归一化**：`doBaselineNorm`（逐 trial-细胞减刺激前均值），用于检验刺激前 tonic 状态的影响。

### 输出图片（当前最终版 = 仅方案2，其余方案只算不画）

| 图 | 布局 |
|---|---|
| `HitMissFinal_Fig1_..._audioOnly__linear...png` | 方案2 linear 2×2：上排 Stage1/Stage2 MI（hit/miss 主 + cue 对照）；下排 Stage1/Stage2 tendency（P(hit) 主 + P(audio) cue 对照） |
| `HitMissFinal_Fig2_..._audioOnly__glm...png` | 方案2 glm 同上 |
| `HitMissFinal_Fig3_..._CV_vs_in-sample...png` | 方案2 Stage1：CV（留出）vs in-sample MI 对比 |

图例约定：**hit=1、miss=0**；主任务实线（橙/蓝），cue 对照虚线（绿/紫）；不含 MAIN/CONTROL 字样。
（方案1/3/4 仅计算不输出图：`for sc = 2` 只画方案2，改回 `1:4` 可全部输出。）

---

## 3. 结果数值

### 3.1 方案1（全部 pre-Transfer）—— Stage1 hit/miss MI 很高但**含混杂**
| | Stage1 hit/miss MI | Stage2 hit/miss MI | Stage1 cue MI（对照） |
|---|---|---|---|
| linear | **0.197** | 0.026 | 0.072 |
| glm | **0.196** | 0.031 | 0.080 |

- 方案1 的 Stage1 hit/miss MI（~0.20）远高于 cue MI（~0.07）与方案2（~0.075）。
- 原因：训练里 hit≈audio≈任务、miss≈light≈校准，解码器"解 hit/miss"很大程度在读 cue/上下文轴 → **虚高**。

### 3.2 方案2（仅 AudioWater）—— 同上下文内真实 hit/miss（基线归一化后）
| | Stage1 | Stage2 |
|---|---|---|
| MI（linear/glm） | 0.070 / 0.068 | 0.021 / 0.019 |
| 平衡准确率（linear/glm） | **0.667 / 0.676**（10/10 鼠，p=0.002） | 0.513 / 0.524（9/10 鼠，p=0.022） |
| P(hit) hit vs miss（linear/glm） | 0.591/0.428；0.695/0.351 | 0.497/0.484；0.519/0.426 |

> 注：现脚本 `doBaselineNorm=true`（去 tonic 均值），但 Stage1 分离仍平坦（见 4.2/4.3）；Stage2 只剩微弱刺激后成分。

### 3.3 方案3 / 方案4（按 block performance 筛选，仅讨论、不输出图）
| 方案 | 训练数据 | 有效鼠 | Stage1 balacc (linear/glm) | Stage1 MI | Stage2 balacc |
|---|---|---|---|---|---|
| 3 audioOnlyPerf50 | AW Perf>0.5 高表现块 | 8 | 0.654 / 0.660 | 0.056 / 0.050 | 0.506 / 0.509（不显著） |
| 4 audioOnlyLowPerf | AW Perf<0.6 低表现块 | 4 | 0.703 / 0.697 | 0.176 / 0.160 | 0.495 / 0.497（不显著） |

---

## 4. 关键发现与更正

### 4.1 方案1 的高 hit/miss MI 主要是混杂
方案1 的 Stage1 hit/miss 高解码率来自 cue×绩效混杂（hit≈audio≈任务、miss≈light≈校准），**不是纯净的行为解码**。

### 4.2 Stage1 的 hit/miss 分离是"刺激前 tonic 状态"，不是刺激驱动 ⚠️
方案2 Stage1 的 P(hit) 两条线**全程平坦**，刺激前后分离几乎不变：
| | 基线区(t<0) 分离 | 刺激后(t>0) 分离 |
|---|---|---|
| linear | 0.165 | 0.160 |
| glm | 0.327 | 0.359 |

即解码器在**刺激出现之前**就能把 hit/miss 分开 → 读的是 hit/miss trial 之间**预先存在的群体状态**（警觉/参与/准备状态），**不是刺激诱发的响应**。

### 4.3 基线归一化去不掉 Stage1 的分离（是跨细胞模式）
逐 trial-细胞减刺激前均值后，Stage1 分离几乎不变（linear 0.158/0.161，glm 0.311/0.365；balacc 0.671/0.687）——说明这是 **hit/miss 间跨细胞的群体模式差异**（非简单加性偏移）。
Stage2 则不同：基线归一化把刺激前分离归零（linear −0.002，glm −0.031），只留下微弱刺激后成分（glm 0.119）；Stage2 balacc 降到 0.513/0.524。

### 4.4 结论
- **"Stage1 能区分 hit/miss" 需修正为**：能区分 hit/miss 的 **trial 状态（刺激前已存在）**，而非刺激驱动的行为编码。
- **Stage2**：基线归一化后只剩微弱的刺激后 hit/miss 信号（glm），泛化证据弱。
- 与 cue 解码器结论一致：群体行为信号在任务上下文内可解（但多为 tonic），跨到 Transfer 泛化很弱。

### 4.5 方案3/4：tonic 状态与"有 miss 可学"相关
- 方案3（高表现块，Perf>0.5）：训练里 miss 太少（有的鼠只剩 1–2 个）→ Stage1 反而更难解（balacc 略降）。
- 方案4（低表现块，Perf<0.6）：hit/miss 数量平衡、可学性强 → Stage1 可解码性最高（balacc ~0.70，接近方案1）；但仅 4 只鼠、sign test 不显著（p=0.125–0.25）。
- 两方案 Stage2 都不泛化；且刺激前 tonic 分离依旧平坦（基线≈刺激后）。
- 说明：hit/miss 的可解码性主要来自"训练里有多少 miss 可学 + tonic 群体状态"，与刺激处理关系不大。

### 4.6 过拟合检查：in-sample 严重虚高 ⚠️
用全部训练数据训练+测试（in-sample）时：
| 方案 | CV balacc | in-sample balacc | MI 放大 |
|---|---|---|---|
| 1 allPre | 0.72 | 0.998 | 4.8× |
| 2 audioOnly | 0.67 | 0.998 | 7.1× |
| 3 audioOnlyPerf50 | 0.65 | 1.000 | 6.8× |
| 4 audioOnlyLowPerf | 0.70 | 1.000 | 5.0× |

- in-sample 平衡准确率高达 0.95–1.0（几乎全对），MI 放大 3.5–7 倍——**必须用 CV/held-out**。
- 原因：细胞数（几百）≫ trial 数（100–200），欠定线性解码器能"背下"训练 trial（含 tonic 状态）。

---

## 5. 方法学备注
- 方案1/3/4 只计算不输出图（`for sc = 2` 只画方案2；改回 `1:4` 可全部输出）。
- 图例去掉 MAIN/CONTROL 字样，hit/miss 标注 `(1)/(0)`。
- `doBaselineNorm=true`（去 tonic 均值）；类别不平衡用 `iBalanceTrain` 降采样；`rng(42)` 固定；未捕获防御性异常。
- MI 是"解码器预测 ↔ 真实标签"的互信息（解码后信息），**依赖解码器方法/阈值**，不是直接从神经活动算的（DPI 下为真实 MI 的下界）。
- 5 折 CV 为随机分块（不分层），折内缺类时退回众数预测；逐鼠/逐时间点/逐方法各自独立随机（`rng(42)` 可复现）。
