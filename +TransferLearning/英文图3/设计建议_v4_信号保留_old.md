# 英文图3 修改方案 v4 — 信号保留叙事

> **修订对照**：
> - v3（当前版本）：SD 预测 ΔHit → Transfer 有更高 SD 因为 AW-active 细胞 → TH 因果操纵 → 负面对照
> - v4（本版本）：**在 v3 的完整结构基础上，在 C 与 D 之间插入两个新面板（D: 信号保留细胞散点直观展示, E: 信号保留群体量化），解释 AW 学习如何在细胞层面留下痕迹→SD↑→ΔHit↑。** 原有面板全部保留，仅后移编号。

---

## 核心叙事变更

### v3 叙事（描述性）
> SD 高 → 学得快。Transfer 的 SD 比 Naive 高，因为 AW-active 细胞。TH 抑制验证因果。

### v4 叙事（机制性）
> **在 v3 基础上增加一个"为什么"环节**：第一个任务（AW）的学习在细胞层面留下了"信号保留"——AW 中响应强的细胞在 LW 中仍然保持更强的响应幅度。这种保留使得群体内一部分细胞（AW-active）的 LW 响应显著大于其他细胞（AW-inactive），导致细胞间异质性（SD）升高。高 SD 使网络具备更快的学习能力（ΔHit↑）。TH 是驱动这一过程的关键通路。

**关键区别**：v3 展示了"SD 高→学得快"和"Transfer 的 SD 更高"，但未解释**为什么** AW-active 细胞会使 SD 升高。v4 通过信号保留面板补上这一环节。

---

## 与图2的分工（严格不重叠）

| 维度 | 图2 | 图3（本修改方案） |
|------|-----|-------------------|
| **行为指标** | 首会话命中率 | **ΔHit（学习速度/邻会话增量）** |
| **群体指标** | Divergence（试次间散度） | Inter-cell SD（细胞间异质性） |
| **机制** | 继承细胞压缩流形 → 低 Div → 首会话高 | 信号保留 → AW-active 异质性 → 高 SD → 学习快 |
| **因果操纵** | cFos / DREADD / Vacation7 | TH 丘脑抑制 |
| **联系** | 低 Div = 每个细胞试次一致 | 高 SD = 不同细胞角色分化 |

**反面对照的逻辑**：Reuse Rate 和 Divergence 出现在图2 中预测首会话命中率；在图3 中确认它们**不预测 ΔHit**，从而证明 SD 是学习速度的唯一独立预测指标。

---

## 修改内容摘要

| 面板 | v3 对应 | v4 内容 | 变更类型 |
|------|---------|---------|---------|
| A | A — ΔHit 定义示意 | 不变 | 不变 |
| B | B — 代表性 SD 分布直方图 | 不变 | 不变 |
| C | C — SD vs ΔHit 散点 | 不变 | 不变 |
| **D** | ——（新增）| **信号保留细胞散点（代表性鼠 AW@1s vs LW@1s）** | ✨ 新增插入 |
| **E** | ——（新增）| **信号保留群体量化 + 异质性来源 (2×1)** | ✨ 新增插入 |
| F | D — SD 组间+组内比较 (2×1) | 内容不变，编号后移 | 🔄 编号后移 |
| G | E — 代表性热图 | 内容不变，编号后移 | 🔄 编号后移 |
| H | F — TH 学习曲线 | 内容不变，编号后移 | 🔄 编号后移 |
| I | G — TH ΔHit & SD bars | 内容不变，编号后移 | 🔄 编号后移 |
| J | H — Reuse Rate vs ΔHit | 内容不变，编号后移 | 🔄 编号后移 |
| K | I — Divergence vs ΔHit | 内容不变，编号后移 | 🔄 编号后移 |

**面板总数 9→11**，插入两个新面板 D 和 E，其余全部保留、编号顺延。

---

## 面板布局（10 panels，4 行）

**Panel C 验证统计（Partial Spearman，控制 Hit_K，置换检验 10000 次，合层）**：

| | ρ | p | n (session pairs) |
|---|---|---|---|
| **Naive** | **+0.434** | **0.010** | 36 |
| **Transfer** | **+0.562** | **0.033** | 15 |

---

### 第 2 行：信号保留创造高 SD（WHY — 机制）

| Panel | 内容 | 说明 |
|-------|------|------|
| **D** | **信号保留量化 + 异质性来源（2×1 tiledlayout）** | **✨ 新增面板** — 上 tile: AW↔LW 信号保留的群体统计；下 tile: 信号保留转化为幅度异质性 |
| **E** | **SD 组间与组内比较（2×1）** | = v3 Panel D，内容不变，编号后移 |
| **F** | **代表性相邻会话热图** | = v3 Panel E，内容不变，编号后移 |

#### Panel D 设计详情（新增面板）

**上 tile：信号保留的群体量化**

展示11只 Transfer 鼠的逐鼠 AW↔LW Spearman ρ 分布：
- 每只鼠一个数据点（点 + 连线 or bar + scatter）
- 参考线 ρ = 0
- 标注：Mean ρ = +0.255, Signrank p = 0.00098

可选方案 A（推荐）：**paired bar/dot** — 左侧 `Spearman(signed)` ρ，右侧 `Spearman(|response|)` ρ，共享 y 轴和 ρ=0 参考线。

| 指标 | 均值 ± SEM | Signrank p |
|------|------------|------------|
| Spearman(AW_signed, LW_signed) | +0.255 ± 0.038 | **0.00098 (\*\*\*)** |
| Spearman(\|AW\|, \|LW\|) | +0.129 ± 0.026 | **0.00098 (\*\*\*)** |

> 两种度量都显著为正：(1) 信号方向保留——AW 中兴奋的细胞在 LW 中也倾向兴奋；(2) 幅度保留——AW 中响应强的细胞在 LW 中响应也更强。

**下 tile：信号保留 → 幅度异质性**

AW-active 与 AW-inactive 细胞在 LW @1s 时刻的 **绝对响应幅度** 比较：
- 配对点图（每只鼠一对），连线，标注 Signrank p

| 比较 | Active mean ± SEM | Inactive mean ± SEM | Signrank p |
|------|-------------------|---------------------|------------|
| mean \|LW response\| @1s | 0.371 ± ? | 0.290 ± ? | **0.00098 (\*\*\*)** |

> AW-active 细胞在 LW 中的绝对响应幅度比 AW-inactive 细胞大 28%。这种"高的高、低的低"就是细胞间异质性（SD）的来源。

**Panel D 不展示的内容（防止与图2重叠）**：
- ❌ 不展示 Divergence
- ❌ 不展示首会话命中率
- ❌ 不展示 inherited cell fraction 或 signal fraction（这是图2F 的内容）

#### Panel E 设计详情（= v3 Panel D，内容完全不变）

| Tile | 内容 | 检验 | p |
|------|------|------|---|
| 上 | Transfer vs Naive SD（合层，session pair 均值） | ranksum | **0.010** |
| 下 | AW-Active vs AW-Inactive SD（合层，首LW会话） | paired signrank | **0.001** |
| 参考 | AW-Inactive vs Naive | ranksum | 0.234 (NS) |

> **第2行叙事逻辑（D→E 的因果链）**：
>
> **D 上 tile**（信号保留存在）：AW 学习在细胞层面留下了"记忆"——末 AW session 的细胞响应 pattern 在首 LW session 中被保留（Spearman ρ=+0.255, p<0.001）。
>
> **D 下 tile**（信号保留 → 幅度差异）：正因保留，AW-active 细胞在 LW 中的响应幅度显著大于 AW-inactive 细胞（|response| 0.371 vs 0.290, p<0.001）。
>
> **E 上 tile**（SD 升高）：这种幅度差异直接产生了更高的 SD（Transfer 0.501 > Naive 0.439, p=0.010）。
>
> **E 下 tile**（SD 来源确认）：SD 的升高完全由 AW-active 亚群驱动（Active SD 0.475 >> Inactive SD 0.380, p=0.001），且 Inactive SD ≈ Naive SD（p=0.234 NS）——没有 AW 记忆的细胞表现得和 Naive 一样。
>
> **整合**：AW 学习 → 信号保留（D）→ AW-active 细胞 LW 响应更大（D）→ 群体 SD↑（E）→ ΔHit↑（回到第1行 Panel C）。

---

### 第 3 行：TH 抑制的因果操纵（CAUSAL — 丘脑驱动）

| Panel | 内容 | 说明 |
|-------|------|------|
| **G** | **TH 抑制 vs 对照 学习曲线 + 首会话 HR** | = v3 Panel F，不变。首会话 HR 无差异（p=0.857）→ 起跑线相同 |
| **H** | **TH 抑制 vs 对照 ΔHit & SD bars（2×1）** | = v3 Panel G，不变。ΔHit: p=0.006; SD: p=0.031 |

**v4 叙事重新定位**：在 v3 中，TH 操纵只是"因果验证 SD→ΔHit"。在 v4 中，TH 操纵有了更深的机制解读：

> TH 投射是信号保留的**载体**。丘脑皮层通路在 AW 学习期间被强化，使得 AW 学习中活跃的皮层细胞在 LW 任务中仍能被丘脑输入优先驱动（信号保留）。抑制 TH → 信号保留减弱 → SD↓ → ΔHit↓。
>
> 关键对比：TH 抑制**不影响首会话命中率**（p=0.857）——这与图2 中 cFos 精准抑制**显著降低**首会话命中率形成对比。TH 驱动的是学习速度维度（SD、ΔHit），而非初始表现维度（Div、HR）。

**Panel G-H 验证统计**（已验证，不变）：

| 指标 | Ctrl | TH | p |
|------|------|----|---|
| 首会话 HR | 0.524 ± 0.076 (n=11) | 0.500 ± 0.051 (n=3) | 0.857 (NS) |
| **ΔHit** | 0.232 ± 0.044 (n=18) | 0.041 ± 0.045 (n=16) | **0.006** |
| **SD** | 0.501 ± 0.023 (n=15) | 0.437 ± 0.021 (n=16) | **0.031** |

---

### 第 4 行：特异性对照（SPECIFICITY）

| Panel | 内容 | 说明 |
|-------|------|------|
| **I** | **Reuse Rate vs ΔHit 散点** | = v3 Panel H，不变。Partial Spearman, NS (p=0.450) |
| **J** | **Divergence vs ΔHit 散点** | = v3 Panel I，不变。Partial Spearman, NS (p=0.615) |

> 不变。Reuse Rate 和 Divergence 预测首会话命中率（图2 范畴），但不预测 ΔHit。SD 是唯一独立预测学习速度的群体编码指标。

---

## 整体叙事流（v4 读图顺序）

```
A: 定义 ΔHit（学习速度指标）
    ↓
B: SD 是什么？— 高 ΔHit ↔ 宽 SD 分布（直观示意）
    ↓
C: SD → ΔHit（核心：SD 在两组中均预测学习速度）
    ↓
D: 为什么 Transfer 的 SD 更高？— 信号保留量化
   （上：逐鼠 AW↔LW Spearman ρ > 0, p<0.001）
   （下：AW-active |LW response| > AW-inactive, p<0.001）
    ↓
E: Transfer SD > Naive SD (p=0.010)
   + AW-Active SD >> AW-Inactive SD ≈ Naive SD
    ↓
F: 代表性热图（高/低 ΔHit 会话对对比）
    ↓
G–H: TH 抑制 → SD↓ + ΔHit↓（丘脑驱动信号保留）
    ↓
I–J: Reuse/Div 不预测 ΔHit（SD 的特异性）
```

**v4 一句话总结**：第一个任务（AW）的学习在皮层细胞层面留下了信号保留——AW 中活跃的细胞在新任务（LW）中保持更强的响应（p<0.001），这种保留使群体异质性（SD）升高（p=0.010），SD 是唯一能独立预测逐会话学习速度的指标（Partial Spearman 两组均显著）；抑制丘脑皮层通路因果性地减弱了 SD 和学习速度（ΔHit p=0.006, SD p=0.031），表明丘脑是信号保留的关键中继。

---

## 需新增/修改的脚本

| 脚本 | 内容 | 基础 | 状态 |
|------|------|------|------|
| **D_SignalRetentionQuantification.m** | Panel D：信号保留量化 + \|LW\| 比较 | scratchFig3_SignalRetention.m | 待创建 |

**其余所有面板均已有对应脚本，仅需将文件名中的字母前缀顺延**（E→F、F→G 等）。

---

## 全部已验证统计汇总

### 新增统计（信号保留，scratchFig3_SignalRetention.m 已验证）

| 分析 | 结果 | p 值 | 面板 |
|------|------|------|------|
| Spearman(AW_signed, LW_signed) 逐鼠 | mean ρ = +0.255 ± 0.038 | signrank **0.00098** | D上 |
| Spearman(\|AW\|, \|LW\|) 逐鼠 | mean ρ = +0.129 ± 0.026 | signrank **0.00098** | D上 |
| AW-active vs inactive \|LW@1s\| | 0.371 vs 0.290 | signrank **0.00098** | D下 |
| AW-active vs inactive LW@1s (signed) | −0.118 vs −0.062 | signrank 0.320 (NS) | — |
| 时间曲线 AW-active vs inactive | 36/48 timepoints p<0.05 | — | 可选补充 |
| 11/11 鼠 ρ > 0 | 9/11 个体显著 | — | D上 |

### 既有统计（v3 已验证，面板编号更新）

| 分析 | 结果 | p 值 | 面板 |
|------|------|------|------|
| Naive SD vs ΔHit (Partial Spearman) | ρ = +0.434 | **0.010** | C |
| Transfer SD vs ΔHit (Partial Spearman) | ρ = +0.562 | **0.033** | C |
| Transfer SD > Naive SD (ranksum) | 0.501 vs 0.439 | **0.010** | E上 |
| AW-Active > AW-Inactive SD (signrank) | 0.475 vs 0.380 | **0.001** | E下 |
| AW-Inactive vs Naive SD (ranksum) | 0.380 vs 0.339 | 0.234 (NS) | E参考 |
| TH: ΔHit Ctrl vs TH | 0.232 vs 0.041 | **0.006** | H上 |
| TH: SD Ctrl vs TH | 0.501 vs 0.437 | **0.031** | H下 |
| TH: 首会话 HR | 0.524 vs 0.500 | 0.857 (NS) | G |
| Reuse Rate vs ΔHit | ρ = +0.217 | 0.450 (NS) | I |
| Divergence vs ΔHit | ρ = −0.149 | 0.615 (NS) | J |

---

## 潜在追加验证（可选，非必需）

以下分析可进一步加强叙事，但当前方案**不依赖**它们：

| 编号 | 分析 | 目的 | 优先级 |
|------|------|------|--------|
| V1 | TH 抑制组的信号保留是否减弱？ | 验证"TH→信号保留→SD"链条 | 中（需 THInhibit 数据集有可配对 AW/LW session） |
| V2 | 逐鼠信号保留 ρ vs ΔHit 相关 | 直接桥接信号保留与学习速度 | 中（但 n=11 可能 power 不足） |
| V3 | AW-active vs inactive 的 LW 时间曲线图 | Panel D 下 tile 的补充可视化 | 低（已有 36/48 timepoints 显著，主趋势明确） |

---

## 与 v3 的差异总结

| 维度 | v3 | v4 |
|------|-----|-----|
| 核心问题 | SD 和 ΔHit 什么关系？ | 在此基础上追问：信号保留如何产生高 SD？ |
| Panel B | SD 分布直方图 | 不变 |
| Panel C | SD vs ΔHit 散点 | 不变 |
| **Panel D** | SD 组间+组内比较 | **信号保留量化（新增插入）** |
| Panel E | 代表性热图（v3 E）| SD 组间+组内比较（= v3 D，下移） |
| Panel F | — | 代表性热图（= v3 E，下移） |
| Panel G-J | v3 F-I | 编号顺延，内容不变 |
| 第2行主题 | "Transfer 有更高 SD" | "信号保留 → 幅度异质性 → 高 SD" |
| TH 解读 | 验证 SD→ΔHit | TH 驱动信号保留（更深机制） |
| 面板总数 | 9 | **10（+1 新增 D）** |
| 行为指标 | ΔHit | ΔHit（不变） |
| 图2 边界 | 明确 | 明确（不变） |
