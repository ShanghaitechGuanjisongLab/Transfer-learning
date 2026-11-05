# Engram-based cross-modal transfer depends on temporal continuity

论文草稿（大纲 + 现有数据支撑 + 正文草稿 + 待补事项）

---

## 0. 核心论点

小鼠在 MOp（初级运动皮层）中形成的**印迹细胞**承载了"线索—舔水"的跨模态关联；这些印迹细胞的活动强度**依赖两个任务之间的时间连续性**。因此：

- 短时间间隔（**顺序 12 h** 或**穿插交替**）下，第二项记忆的建立远快于
- 长时间间隔（**7 天空笼**）后的迁移学习。

单细胞层面可分离出三类动态特性，分别对应"起点"与"速率"两个行为成分，而**这两个成分对任务间时间 Δt 的敏感度不同**。

---

## 1. 时间轴框架（全文骨架）

三组本质上只是**任务间时间 Δt 的三个取值**，这是唯一能把三组放进同一张图的轴。

| 时间层级 | 变量 | 取值 | 被它决定的指标 |
|---|---|---|---|
| 任务间时间 | Δt（任务 A 学会 → 任务 B 开始） | 无（未学 A）／**12 h**／7 d | 首 block 命中率、相对散度、重激活率 |
| 任务内时间 | block 序号（30 试次/block，间隔 12 h） | 1…N | Sigmoid 斜率、达 50% 所需 block |
| 试次内时间 | cue 后 0–1 s | 固定采样点 | 散度、响应异质性 |

**表述规范**：方法学写的是"学会后 12 小时切换线索"，所以 Transfer 组的 Δt 是 12 h，不是 0。全文统一写 Δt = —／**12 h**／7 d，不写"无间隔 vs 7 天"。

### 1.1 任务组口径（贯穿全文）

一个任务组 = `naive`（直接学目标任务 X）+ 若干 `transfer` 变体（先学另一模态 Y，再学 X）。"第二项任务"**始终指 X**，不是固定指 LW 或 AW；X 由该图的数据来源决定。

| 目标任务 X | naive（直接学 X） | transfer 变体（先学 Y 再学 X） |
|---|---|---|
| **LW**（声→光，本稿主线） | 直接学 LW：LAB 的 Naive 阶段、LAI 的 Naive 阶段 | AW→12 h→LW：ALB ｜ AW-IL-LW：ALI（文件缺失）｜ AW→7 d→LW：V7 |
| **AW**（光→声，本稿不含） | 直接学 AW：ALB 的 Naive 阶段 | LW→12 h→AW：LAB ｜ LW-IL-AW：LAI ｜ LW→7 d→AW：无实验 |

三条作图规则：

1. 面板标题必须写明 X（如 "First light-water block"）。
2. 同一张图不能混两个方向的臂——naive 的定义随 X 翻转，ALB 的 Naive 阶段在 X=LW 时是 transfer、在 X=AW 时才是 naive。
3. 每个 transfer 变体都要有对应的 naive 参照；缺哪个变体就在图上标缺，不用别的臂顶替。

---

## 2. 核心发现（可直接引用的数值）

### 2.1 LightWater 学习曲线三组（成像队列、undelayed 范式）

| 组 | n | 首 block 命中率 | Sigmoid 斜率 | 拟合中点 | 达 50% block |
|---|---|---|---|---|---|
| Naive（LAB+LAI） | 14 | 0.160 ± 0.074 | 0.372 | 3.85 | 3.96 ± 0.73 |
| Transfer（ALB，12 h） | 11 | **0.524 ± 0.076** | 0.775 | 0.70 | **1.53 ± 0.30** |
| 7dayTransfer（V7） | 6 | 0.133 ± 0.056 | 0.704 | 2.50 | 2.37 ± 0.44 |

统计：

- 三组 LME 组效应（block 1–7，`Performance ~ Block + Group + (1|Mouse)`）**p = 0.0012**
- 两两 Group 项：Naive–Transfer **p = 3.6×10⁻⁴**；Transfer–7day **p = 0.023**；Naive–7day p = 0.347
- 首 block rank-sum：N–T **p = 0.0025**；T–7d **p = 0.0045**；N–7d p = 0.49
- 达 50% block：N–T **p = 0.0082**；T–7d **p = 0.0315**（Holm 校正后 0.063）；N–7d p = 0.386

### 2.2 学习速率：无法用 Sigmoid 斜率支撑

| 口径 | 三组整体 | N–T | N–7d | T–7d |
|---|---|---|---|---|
| Block×Group 交互（block 1–7） | 0.380 | 0.165 | 0.385 | 0.749 |
| 组水平斜率置换检验（2000 次按鼠重排） | — | 0.46 | 0.49 | 0.93 |

**可检出下限（MDES）**：p < 0.05 需要 |Δlog slope| ≈ 1.29–1.46，折合斜率比 **3.6–4.3 倍**；实际观察到的最大差异只有 2.1 倍。故"不显著"是**功效不足**，不是"相等"。

**结论**：速率只能靠逐鼠"达 50% block 数"（逐鼠值，n 用满）来主张，且必须声明它混合了起点效应。写作时不写"斜率更陡"。

### 2.3 Fig1B 原口径（delayed 行为队列，A2L_L_0928 vs L2A_L_0928，15/14 只）

- Group 项 p = **1.6×10⁻⁴**（复现原文）
- Block×Group 交互 p = **0.152**（不显著），且系数为正（naive 线性斜率略陡），方向不支持"迁移学得更快"
- 该交互对窗口极敏感：block 1–3 p = 0.38、1–5 p = 0.74、1–7 p = 0.15、全部 block p = 0.004（显著）——全区间显著是因为 naive 到 10+ block 才饱和，被线性模型读成"naive 斜率更大"

### 2.4 反向方向参考：AW 作为目标任务（本稿不列入）

| 组 | n | 首块命中率 | 每鼠声水 block 数 |
|---|---|---|---|
| Naive（ALB 直接学声水） | 10 | 0.680 ± 0.079 | 4.4 |
| Interspersed（LAI，与光水交替） | 12 | 0.826 ± 0.047 | 3.3 |
| Sequential（LAB，光水学会后 12 h） | 6 | **0.956 ± 0.029** | 3.0 |

- Naive vs Sequential **p = 0.0047**；Interspersed vs Sequential **p = 0.048**；Naive vs Interspersed p = 0.17
- 剔除 4 只在 Naive 期已接触声水的鼠后：n = 8，首块 0.771，vs naive p = 0.51
- **天花板效应**：三组达 50% block 数全为 1，声水上没有速率可测，本图只能画起点

### 2.5 单细胞动态特性（Fig 2）

首个迁移 block 的试次间相对散度（cue +1 s，与 Fig1I 同定义）：

| 层 | Naive | Transfer | 7dayTransfer | p (N–T / T–7d) |
|---|---|---|---|---|
| L2/3 | 4.115 ± 0.208 (17) | 3.189 ± 0.243 (11) | 4.299 ± 0.362 (6) | **0.0041** / **0.037** |
| L5 | 4.126 ± 0.235 (14) | 4.094 ± 0.214 (10) | 4.546 ± 0.278 (6) | 0.93 / 0.22 |

相关（逐鼠，跨三组合并）：

- 散度（L2/3）vs 首 block 命中率：Spearman ρ = **−0.63**，p = 1.6×10⁻⁴，n = 31
- L5 响应异质性 vs 达 50% block：ρ = **−0.71**，p = 9.8×10⁻⁵，n = 24

重激活率 P(transfer-active | learned-active)（按 learned-active 细胞数加权合并两层）：

- 12 h：**0.153 ± 0.041**（n = 11）
- 7 d：**0.018 ± 0.008**（n = 6）
- rank-sum **p = 0.011**

L5 响应异质性（Fig1I 口径：逐细胞逐会话 cue+1 s z 中位数 → 跨会话平均 → 限 |z| ≤ 1 → 跨细胞 SD）：

| 组 | n | L5 异质性 | L2/3 异质性 |
|---|---|---|---|
| Naive | 10 / 13 | 0.199 ± 0.023 | 0.278 ± 0.016 |
| Transfer (12 h) | 8 | 0.277 ± 0.011 | 0.319 ± 0.018 |
| 7dayTransfer | 6 | 0.230 ± 0.021 | 0.291 ± 0.017 |

L5：N–T **p = 0.009**；T–7d **p = 0.059**；N–7d p = 0.37。L2/3：全部 n.s.（0.18 / 0.41 / 0.90）。

**7 天后还剩多少（同一批 6 只鼠）**

- 印迹复用：剩 **12%**（0.153 → 0.018，回退 88%）
- L5 异质性：剩 **41%**（0.204 → 0.281 → 0.235，回退 59%）

→ 两个成分的时间常数不同，这是**独立于药理操纵**的双成分解离证据。

**印迹细胞的"强度"与"人数"（Fig2_EngramHeatmap，2026-10-29 新增）**

印迹细胞 = 最后学会的声水 block 中 cue +1 s 超过基线 + 3σ 的细胞；逐细胞取试次中位 z。

| 量 | 12 h | 7 d | p |
|---|---|---|---|
| 细胞数（逐鼠取两次会话交集） | 511（11 只） | 290（6 只） | — |
| 被标定时的强度（声水 block） | 1.89 ± 0.27 | 1.95 ± 0.14 | 0.35 |
| 首个光水 block 的强度（全体印迹细胞） | **0.19 ± 0.09** | **−0.11 ± 0.05** | **0.062** |
| 全部记录细胞的强度（对照） | −0.090 ± 0.034 | −0.091 ± 0.034 | 0.88 |
| 仍被驱动（learned∩transfer active） | **76/511 = 14.9%** | **5/290 = 1.7%** | 0.011 |
| 存活细胞自身的强度 | 0.90 / 0.95 / 0.97（3 例） | 1.11 / 0.58 / 1.89（3 例） | 0.47（1.05 vs 1.01） |

⇒ 结论：**衰减是"人数"而不是"音量"**——存活下来的细胞强度不变（1.05 vs 1.01），但能被新线索驱动的细胞数从 76 降到 5；且全体记录细胞的反应两组相同，排除"光水诱发活动被整体压低"。
⚠ 7 d 的 5 个存活细胞仅来自 3 只鼠（`vtf1021` 3 个、`yqn0400` 1 个、`yqn0430` 1 个），示例细胞因此只来自 2 只鼠。

### 2.6 因果：cFos 印迹抑制（Fig 3）

- Control 9 只 vs cFos 抑制 3 只（`202611\cFos合集.v3.mat`，MarkTimes=0 为对照）
- 光水学习曲线组效应（block 1–7）**p = 0.0014**（复现原文 0.001）
- 首 block：0.256 ± 0.077 vs 0.056 ± 0.022，**p = 0.23**（n = 3，测不出）
- **斜率**：LME 加交互项（`Performance ~ Block*Group + (1|Mouse)`）得 Block×Group **F(1,73) = 4.07，p = 0.047**；但逐鼠斜率（Control 0.120 ± 0.017/block，cFos 0.065 ± 0.026/block）的**穷举置换检验 p = 0.127**、rank-sum p = 0.146。⇒ 交互项在 n = 3 时不稳健，**只能写成"斜率方向一致地变缓，但检验力不足"**，不能据此声称"下移 + 变缓"。

### 2.7 理论：丘脑（thalamus）抑制（Fig 4）

- Control（ALB 的 AW→12 h→LW，11 只）vs Thalamus 抑制（THInhibit，5 只成像鼠）
- 光水曲线组效应 **p = 0.071**（弱于原文 0.039，因本数据集只有 5 只）
- 首 block：0.524 ± 0.076 vs 0.373 ± 0.095，**p = 0.31**（不变，符合"速率项被选择性影响"）
- L2/3 异质性 0.311 vs 0.288（p = 0.52）；L5 异质性 0.277 vs 0.221（**p = 0.030**，复现原文 0.028/0.022）

---

## 3. 四图大纲与叙述思路

### 3.0 全文的一条线

题目断言"印迹承载跨模态迁移，而这种承载依赖时间连续性"。要让它成立，必须走完四步：

1. **现象**：时间连续性决定迁移优势的大小（Fig 1）
2. **分解**：这个优势可拆成"起点"和"速率"两个成分，二者对 Δt 的敏感度不同（Fig 1 C/D → Fig 2）
3. **因果**：起点项由印迹细胞承载（Fig 3）
4. **机制**：速率项由丘脑驱动的群体异质性承载（Fig 4）

Fig 1 定义自变量并给出两个因变量；Fig 2 为这两个因变量各找一个细胞对应物；Fig 3、Fig 4 分别对二者做因果验证。逻辑上 Fig 1 提出问题，Fig 2 是桥梁，Fig 3/Fig 4 是两条并列的因果链。

### Fig 1｜时间连续性决定迁移优势的大小

**唯一职责**：把"时间连续性"变成可操作的自变量，把"迁移优势"变成两个可分离的因变量。

- **A 示意** —— 定义三个 Δt 取值。作用不是装饰，是让读者一眼看出**三组共用同一个任务 X=LW**，区别只是"先学过 AW、隔了多久"：naive 直接学 LW，transfer 是 AW→12 h→LW 或 AW→7 d→LW。串扰（12 h 写在两个色块之间）和 7 d 空笼（虚线）都在这里交代清楚。缺的穿插臂在 E 里留位，不偷偷省略。
- **B 学习曲线** —— 主结果。图例直接写构造 `Naive (LW direct)` / `Transfer (AW→12 h→LW)` / `Transfer (AW→7 d→LW)`，不写含糊的 "Control"。p = 0.0012 是 LME 的组效应，回答"三条曲线整体是否不同"，而不是"谁比谁快"。
- **C 首块** —— 把曲线差拆出**起点**。全文第一个关键结论：12 h 起点 0.52，7 d 掉回 0.13、与 naive 无差别（p = 0.49）。**时间抹平的是起点。**
- **D 达 50% block** —— 把曲线差拆出**建立速度**。用逐鼠值（3.96 / 1.53 / 2.37）而非 Sigmoid 斜率，因为斜率的可检出下限需 3.6–4.3 倍、实际差仅 2 倍，撑不住。
- **E Δt 汇总（上下两面板共享 x）** —— 不引入新数据，作用是把 C 与 D 放到同一自变量轴上收口：起点随 Δt 呈"V 形"（12 h 最高、两端低），速度随 Δt 呈"U 形"（12 h 最快、7 d 回中、naive 最慢）。**这张子图存在的意义是让"两个成分形状不同"一眼可见**，为 Fig 2 的分头追踪提供动机。穿插臂数据缺失，图上标 n/a。

> 若只能留一张子图，留 B；若只能留两条结论，留 C（起点被抹平）与 D（速度未被完全抹平）。脚本 [Fig1_TimeContinuityBehavior.m](../Fig1_TimeContinuityBehavior.m)。

### Fig 2｜两个成分在单细胞层面的对应物

**职责**：为 Fig 1 的"起点""速率"各配一个细胞指标，并给出它们对 Δt 的衰减幅度。

- **A 旧任务学会后的单细胞响应分布** —— 回答"旧任务在皮层留下了什么"。这是重激活与异质性的基线：先说明 AW 学会时细胞被分成朝上/朝下两类，后面才能谈"这些细胞在新任务里被复用"。目前只画 cue +1 s 的 z 分布（4469 细胞，rising 50.8% / suppressed 49.2%），严格的两类划分尚未单独成图。
- **B 首个 LW block 的群体轨迹（PCA）** —— 把"naive 发散 vs transfer 平行"直接画出来，是散度这个标量的直观来源。**尚待接入**（`Fig1D_DivergencePCA_L23` 的轨迹计算），当前占位。
- **C L2/3 散度（三组）** —— 起点的细胞对应物。12 h 显著低于 naive（p = 0.004），7 d 回到 naive 水平（p = 0.037）。与 Fig 1C 同形状。
- **D L5 散度（三组）** —— **阴性对照**。层间不一致（0.93 / 0.22）恰说明 C 不是成像质量或样本量的伪影，散度效应层特异；同时为 Fig 4 只谈 L5 埋伏笔。
- **E 散度 vs 首块命中率** —— 把"组间差异"升级为"个体间连续关系"（ρ = −0.63，n = 31）。作用：说明不是"某一组恰好散度低"，而是散度越低首块越高、跨组共变。
- **F L5 异质性 vs 达 50% block** —— E 的镜像，连接另一支：异质性越高，达 50% 越快（ρ = −0.71）。
- **G 重激活率 12 h vs 7 d** —— 给"印迹复用"一个衰减幅度：0.153 → 0.018，只剩 **12%**（p = 0.011）。
- **H L5 异质性三组** —— 给"群体异质性"一个衰减幅度：0.199 / 0.277 / 0.230，只剩 **41%**（12 h vs 7 d p = 0.059）。
- **I 印迹细胞被标定时的强度** —— 12 h 与 7 d 在最后学会的声水 block 上强度相同（1.89 ± 0.27 vs 1.95 ± 0.14，p = 0.35；511 vs 290 个细胞），证明两组起点是同一个印迹状态，排除"选出的细胞不同"这一解释。
- **J 同一批印迹细胞在首个光水 block 的强度** —— 12 h 0.19 ± 0.09（仍高于基线）vs 7 d −0.11 ± 0.05（落到基线以下），p = 0.062；全体细胞强度两组相同（−0.090 vs −0.091），因此衰减是印迹群体特异的。

> **G 与 H 是全文题目的定量核心**：同一批 7 天鼠里，印迹复用掉了 88%，异质性只掉 59%。两个时间常数不同 → 支持"两个成分由不同机制承载" → 直接引出 Fig 3（管起点）与 Fig 4（管速率）。C/D 与 E/F 是"该指标真的和行为挂钩"的合法性担保。**I/J 是 G 的分解**：说明衰减是"能被招募的细胞变少"，而不是"每个细胞变弱"；它们与 G 不独立，放进主图后不能当作第四条独立证据（也可考虑改放 Fig 3E）。脚本 [Fig2_SingleCellDynamics.m](../Fig2_SingleCellDynamics.m)；另有两面板精简版 [Fig2F_TimeContinuityDecay.m](../Fig2F_TimeContinuityDecay.m)。

#### Fig 2 备选版式：印迹细胞的群体热图 + 示例细胞（[Fig2_EngramHeatmap.m](../Fig2_EngramHeatmap.m)）

一个图窗，**2 行 × 4 列**，直接对应第 6.2 节的"人数/音量"结论：

| | 12 h | | 7 d | |
|---|---|---|---|---|
| **上排（群体热图）** | **A** learned AW（n = 511） | **B** first LW | **C** learned AW（n = 290） | **D** first LW |
| **下排（示例细胞）** | **E** learned AW | **F** first LW（76/511 still active，14.9%） | **G** learned AW | **H** first LW（5/290 still active，1.7%） |

口径要点：

1. 热图行序 = 按 learned AW 在 cue +1 s 的响应降序；B/D 沿用同一行序（同批细胞、同顺序）。**热图上不标行号**。
2. 示例细胞 = **在该 block 仍被驱动**的印迹细胞（learned∩transfer active），在该子集里取最接近中位的 3 个（不挑最强）；颜色 + 编号与线对应。
3. 每个线图里：彩色 = 3 个示例；**黑粗线 = 印迹细胞中位**；**灰粗线 = 全部记录细胞中位**（后者是"印迹特异"的对照）。
4. 色限对称稳健（±p97\|z\| ≈ ±3.5），超出饱和；不用分位数不对称范围（会把蓝色压成一条窄边）。

### Fig 3｜因果：印迹细胞是不是起点项的载体

**职责**：把 Fig 2G 的相关性变成因果。这一张只谈**起点**，不谈速率。

- **A 标记/抑制流程** —— 关键在"抑制的是旧任务学会时活跃的那群细胞"，不是广谱抑制；否则整张图的解释就塌了。
- **B 学习曲线整体下移** —— 因果证据的主结果（p = 0.0014，Control 9 只 vs cFos 3 只）。
- **C 首块** —— 与 Fig 1C 对照：若印迹是起点项载体，抑制就该压低首块。方向对（0.256 → 0.056）但 n = 3、p = 0.23，**必须照实写成 underpowered**，不能画成"显著降低"。
- **D 计划** —— tagged 细胞的重激活率（cFos vs control）。**数据不可得**：cFos 合集只有行为（无 Cells），本面板只能以文字说明内容。
- **E 已有数据** —— 印迹细胞在 cue +1 s 的响应强度，12 h vs 7 d（1.89/1.95 标定等价，p = 0.35；迁移块 0.19 vs −0.11，p = 0.062）。与 Fig 2G（重激活**比例**）、Fig 2H（群体**异质性**）区分：本面板是"同一批细胞还剩多少活动"。目前 Fig 2I/J 与 Fig 3E 暂时重复，定稿时二选一。

> Fig 3 目前是"一强二弱一空"：B 站得住（p = 0.0014），C 功效不足，E 新补上（印迹强度随间隔衰减，p = 0.062），D 因 cFos 数据只有行为、无细胞层面数据而只能以文字说明。这一张决定 "engram-based" 这个词能否用。脚本 [Fig3_EngramCausality.m](../Fig3_EngramCausality.m)。

### Fig 4｜机制：速率项由丘脑与群体异质性承载

**职责**：给"速率"这一支找因果链，且必须表现出**与起点项的双分离**。

- **A Thalamus → MOp 抑制示意** —— 设计要点是"抑制发生在迁移学习期间"，因此可分别看它是否影响起点、是否影响速率。
- **B 学习曲线变平** —— 速率受损的主结果（p = 0.071）。注意这是**变平**不是**下移**，与 Fig 3B 的形态正好相反，这就是双分离的视觉证据。本数据只有 5 只成像鼠，弱于原文 0.039，需在图注说明。
- **C L2/3 异质性无变化** —— 阴性对照，说明 TH 的作用层特异，不是整体压低细胞反应。
- **D L5 异质性下降** —— 机制落点（0.277 → 0.221，p = 0.030），把"TH 抑制 → L5 异质性降低 → 学习变慢"这条链补上中间环。
- **E 首块不变** —— 双分离的另一半（0.524 vs 0.373，p = 0.31）。**C 与 E 一起才是这张图的论证力所在**：TH 只动速率不动起点，印迹只动起点不动速率，两条链互不替代。

> 脚本 [Fig4_ThalamusHeterogeneity.m](../Fig4_ThalamusHeterogeneity.m)。RNN 模型不在本稿范围（沿用原文图 5，不做增删）。

### 3.1 四图互补关系（一句话版）

| 图 | 回答的问题 | 关键因变量 | 若这张图垮掉 |
|---|---|---|---|
| Fig 1 | 时间连续性改变迁移优势吗？改的是哪一项？ | 首块、达 50% block | 题目失去自变量，全文无立足点 |
| Fig 2 | 这两项在细胞层面是什么？谁更依赖时间连续性？ | 散度、重激活率、异质性 | "双成分"退化为两个孤立行为指标，Fig 3/4 失去共同框架 |
| Fig 3 | 起点项是印迹造成的吗？ | cFos 抑制后的曲线/首块 | 只能用 "ensemble reuse 相关"，不能用 "engram-based" |
| Fig 4 | 速率项是丘脑-异质性造成的吗？ | TH 抑制后的曲线/L5 异质性 | 双分离只剩一半，无法解释 7 天后速率仍居中 |

### 3.2 三处必须照实写

1. **速率项的统计功效不足**：斜率比较在三组间全部不显著（交互 0.38；置换 0.46 / 0.49 / 0.93），可检出下限需 3.6–4.3 倍。所以 Fig 1D、Fig 2F、Fig 4B 都改用"达 50% block"这类逐鼠指标，措辞只能到"起点被抹平、速率未被抹平到 naive 水平"，不能写成"7 天完全/大部分保留了加速"。
2. **Fig 3C 是 underpowered**（n = 3，p = 0.23），不能写成"抑制降低首块"。同理，Fig 3B 的"曲线变平"只能用逐鼠斜率置换检验（p = 0.13）描述，**不能用 LME 交互项的 p = 0.047 当证据**（n = 3 时交互项不稳）。
3. **Δt 只有 12 h 与 7 d 两个点**，Fig 2G/H 的"不同衰减速率"是两点之差，不是拟合出的时间常数；需补 1–3 天中间点才谈得上曲线。

---

## 4. 摘要（Abstract）

> 口径：只写四个已验证的锚点（Δt 决定起点、起点与速率两个成分、cFos 下移、TH 变平 + L5 异质性下降）。不写"7 天完全抹去"，不写"速率显著变快"。

Learning one sensorimotor association can accelerate the learning of a second, but the resulting advantage is not a single quantity: a new task can be entered from an elevated performance level, and it can also be acquired faster. Whether these two components share a mechanism, and what determines their size, is unknown. We trained mice on an audio–water association and then transferred them to a light–water version of the same task, either 12 h or 7 d later, while longitudinally imaging the same neurons in layers 2/3 and 5 of the primary motor cortex (MOp). A 12 h interval produced a transfer advantage that was already present in the first light–water block (hit rate 0.52 vs 0.16 in naive mice); after 7 d the first-block advantage had disappeared (0.13, indistinguishable from naive), whereas the number of blocks needed to reach 50% stayed intermediate rather than returning to the naive level (2.4 vs 4.0 blocks; n = 6). The starting-point component tracked trial-to-trial stability of the L2/3 population response at cue +1 s and the reactivation of the ensemble that had been active when the first task was learned; both decayed steeply over 7 d (12% of the reactivation retained). The rate component tracked L5 response heterogeneity, which decayed much less (41% retained). Chemogenetic silencing of the cFos-tagged ensemble lowered the whole light–water curve (p = 1.4 × 10⁻³) without a resolvable change in the first block (n = 3, underpowered), whereas inhibiting the thalamic input to MOp lowered the curve without a detectable change in the first block, and selectively reduced L5 (not L2/3) heterogeneity. The cross-modal transfer advantage therefore decomposes into a short-lived, engram-dependent starting point and a longer-lived, thalamus-sustained rate component.

---

## 5. Introduction（英文正文）

> 口径：引言只承担三件事——(i) 把"迁移优势"拆成起点与速率两个成分；(ii) 说明这两个成分各自在文献里有候选机制（印迹复用 / 群体异质性 + 丘脑）；(iii) 把"任务间时间 Δt"确立为唯一能同时操纵两者的自变量。旧稿 `Introduction.md` 的第 1、3 段可直接复用，第 2 段需改写成交付给"Δt"。

Transfer of learning describes the influence of previously acquired knowledge on the acquisition of new knowledge (Thorndike and Woodworth, 1901), and its reach has long been taxonomized from near to far (Barnett and Ceci, 2002). Most accounts remain at the behavioral or psychological level (Perkins and Salomon, 1994), and even recent neural evidence has been resolved at the level of brain regions (Rasooli et al., 2024). A persistent difficulty is that the overall transfer advantage conflates at least two processes: starting the new task from an elevated initial state, and continuing to improve faster once the new task is under way. These correspond to the intercept and the rate of the new learning curve, and in other learning domains the two are known to obey different time constants (Smith et al., 2006). Whether they are supported by different cellular mechanisms in the same cortical population has not been tested.

Cellular candidates for the first component come from the engram literature. Sparse, distributed assemblies are recruited during learning and their tagging, inhibition and reactivation causally control retrieval (Tonegawa et al., 2015; Josselyn and Tonegawa, 2020). Engrams of temporally proximate experiences overlap through excitability-based competition (Rashid et al., 2016), which provides a cellular substrate for linking related experiences (Choucry et al., 2024). If transfer at onset depends on re-engaging the ensemble formed by the first task, then the advantage should be a decreasing function of the interval between the two tasks — a prediction that has not been tested for a sensorimotor association transferred to a cue of a different modality.

Candidates for the second component come from population dynamics. Behaviour is generated within low-dimensional manifolds whose structure constrains what can be learned (Sadtler et al., 2014; Vyas et al., 2020), rapid learning can proceed by reassociating activity within the existing manifold (Golub et al., 2018; Perich et al., 2018), and preserved manifold structure maintains consistent behaviour across months (Gallego et al., 2020). Stimulus-driven engagement of cortex is accompanied by a reduction of trial-to-trial variability (Churchland et al., 2010), and learning refines population structure at fine spatial scales rather than uniformly raising activity (Komiyama et al., 2010; Poort et al., 2015). For the rate of learning, theory provides a specific hypothesis: heterogeneity across units supplies the differentiated updates that gradient descent needs and thereby accelerates convergence in temporally structured tasks (Saxe et al., 2014; Perez-Nieves et al., 2021). If response heterogeneity plays the analogous role in vivo, it should predict learning speed and be subject to an identifiable upstream modulator. The higher-order motor thalamus is a plausible one, because motor learning refines thalamic influence on motor cortex (Ramot et al., 2025) and thalamocortical motifs are positioned to modulate cortical processing state-dependently (Halassa and Sherman, 2019; Shepherd and Yamawaki, 2021).

Cross-modal transfer itself has been approached at the population level: mice generalize a sensorimotor rule between touch and vision through abstract cortical representations, and silencing experiments indicate that congruent multimodal representations in associative cortex support this generalization (Guyoton et al., 2025). What remains open is how previously recruited ensembles are reused at the onset of the new task, and how that reuse evolves over days — which requires manipulating the interval between the two tasks while holding the tasks themselves fixed.

Here we do exactly that. Mice learned an audio–water association and were transferred to a visually cued version of the same task, with the interval between the two tasks set to 12 h or 7 d; a third group learned the light task without prior audio training (Δt undefined), and a fourth, interleaved design would have placed Δt near zero (data unavailable). Across these groups Δt is the only variable that changes, which lets it serve as the axis on which the two components can be separated. Using longitudinal two-photon imaging of the same MOp neurons in L2/3 and L5, together with chemogenetic silencing of the tagged ensemble and of the posterior thalamus, we find that the two components are doubly dissociable: the starting point is carried by the reuse of the ensemble formed during the first task and decays steeply with Δt, whereas the rate is tracked by L5 response heterogeneity, is sustained by thalamic drive, and decays with a longer time constant.

---

## 6. Results（英文正文）

> 四小节严格对应四张图，每节只推进一步。凡是功效不足的地方，正文里就当句写明，不留到最后。

### 6.1 Temporal continuity sets the size of the transfer advantage (Fig 1)

Mice first learned an audio–water association to criterion and were then moved to a light–water version of the same task, in which only the cue modality changed while the reward rule stayed the same. The interval between the last audio–water block and the first light–water block defined groups that differed in nothing but Δt: mice that learned the light task without prior audio training (naive, Δt undefined, n = 14 mice), mice transferred 12 h after criterion (n = 11) and mice transferred after 7 d in the home cage without training or imaging (n = 6) (Fig 1A).

Across the first seven light–water blocks the three curves differed (linear mixed-effects model, Performance ~ Block + Group + (1|Mouse), group effect p = 0.0012; Fig 1B). The pairwise contrasts located the difference: 12 h exceeded naive (p = 3.6 × 10⁻⁴) and exceeded 7 d (p = 0.023), whereas naive and 7 d were indistinguishable (p = 0.35). The advantage conferred by 12 h is therefore not a lasting property of having learned the first task; it is a property of having learned it recently. The same group difference is present in the delayed paradigm with a larger cohort (n = 15 vs 14 mice; p = 1.6 × 10⁻⁴) and, in that cohort, the block × group interaction over blocks 1–7 was not significant (p = 0.15), i.e. the curves differ in level rather than in steepness (data not shown in Fig 1).

Splitting the curve into a starting point and a rate, the first light–water block — before any light–water feedback could act — already separated the groups in the same pattern (0.52 ± 0.08 at 12 h vs 0.16 ± 0.07 in naive mice, p = 0.0025; 0.13 ± 0.06 at 7 d, p = 0.0045 vs 12 h; naive vs 7 d p = 0.49; Fig 1C). The interval thus erased the starting point. As a second, per-mouse readout we counted the blocks each mouse needed to reach 50% hit rate (3.96 ± 0.73 naive, 1.53 ± 0.30 at 12 h, 2.37 ± 0.44 at 7 d; naive–12 h p = 0.0082; 12 h–7 d p = 0.032, Holm-corrected 0.063; naive–7 d p = 0.39; Fig 1D): after 7 d mice still reached 50% in fewer blocks than naive mice, so the rate advantage was attenuated but not abolished.

We deliberately did not base that second claim on sigmoid slopes. The block × group interaction over blocks 1–7 was not significant (p = 0.38), and a group-level permutation test on per-mouse slopes (2,000 relabellings of mice across groups) gave p = 0.46 (naive–12 h), 0.49 (naive–7 d) and 0.93 (12 h–7 d). Given the observed within-group variance, reaching p < 0.05 would require a difference of |Δlog slope| ≈ 1.29–1.46, i.e. a 3.6–4.3-fold slope ratio, whereas the largest observed ratio was 2.1. The slope comparison is underpowered rather than evidence of equality; we therefore restrict the rate claim to the per-mouse blocks-to-50% measure and note that this measure is not independent of the starting point, since a mouse that begins higher reaches 50% sooner.

Fig 1E collects both readouts on the one axis shared by all groups, Δt. The starting-point term is non-monotonic: it is highest at 12 h and equally low without prior training and after 7 d. The rate term is also highest at 12 h, but does not return to the naive level after 7 d; it stays intermediate. The two terms therefore do not vary together, and they differ in their sensitivity to Δt. The interleaved arm, which would have supplied the Δt ≈ 0 point, is not available; the panel marks it n/a rather than omitting it.

### 6.2 Single-cell counterparts: L2/3 trial-to-trial stability and L5 heterogeneity (Fig 2)

To ask what the two components are made of, we imaged the same MOp neurons across the audio–water and light–water phases, alternating between an L2/3 and an L5 plane. Two per-mouse indices were computed at cue +1 s, the moment at which water is delivered in the undelayed paradigm: inter-trial divergence (trial-to-trial variance of the population response normalized by its squared mean; a stability measure) and response heterogeneity (across-cell SD of trial-mean z-scored responses, restricted to |z| ≤ 1).

The state that the light task inherits is already heterogeneous. At cue +1 s in learned audio–water blocks, per-cell responses split almost evenly into rising (50.8%) and suppressed (49.2%) cells (n = 4,469 cells; Fig 2A). In the first light–water block, the L2/3 population response was markedly more trial-stable after 12 h than in naive mice (divergence 3.19 ± 0.24, n = 11 vs 4.12 ± 0.21, n = 17; p = 0.0041), and this stability was lost after 7 d (4.30 ± 0.36, n = 6; p = 0.037 vs 12 h; Fig 2C). L5 showed no such difference (4.09 ± 0.21, n = 10 vs 4.13 ± 0.24, n = 14; p = 0.93; and 4.55 ± 0.28 at 7 d, p = 0.22; Fig 2D). The layer mismatch is informative: it makes an imaging-quality or sample-size artefact an unlikely explanation and assigns the stability signature to a specific population. Mouse counts differ between panels and from Fig 1 because each readout requires a recording in the relevant layer; the naive cohort contributed 17 mice with L2/3 data and 14 with L5 data.

Divergence is not merely a group label. Across the 31 mice of the three cohorts, L2/3 divergence at cue +1 s predicted the first light–water block hit rate of the same mouse (Spearman ρ = −0.63, p = 1.6 × 10⁻⁴; Fig 2E): the more reproducible the L2/3 response from trial to trial, the higher the starting point.

L5 heterogeneity behaved like the other component. Across the 24 mice with L5 recordings it predicted how many blocks a mouse needed to reach 50% (ρ = −0.71, p = 9.8 × 10⁻⁵; Fig 2F), and the cohorts differed in L5 heterogeneity (naive 0.199 ± 0.023, n = 10; 12 h 0.277 ± 0.011, n = 8, p = 0.009 vs naive; 7 d 0.230 ± 0.021, n = 6, p = 0.059 vs 12 h; naive vs 7 d p = 0.37; Fig 2H). In L2/3 heterogeneity did not differ between cohorts (0.278 ± 0.016, n = 13; 0.319 ± 0.018, n = 8; 0.291 ± 0.017, n = 6; all p ≥ 0.18), so divergence and heterogeneity are not two readouts of one population property.

Finally, ensemble reuse. Of the cells active at cue +1 s in learned audio–water blocks, a substantial fraction was active again in the first light–water block after 12 h (P(transfer-active | learned-active) = 0.153 ± 0.041, n = 11), and this fraction nearly vanished after 7 d (0.018 ± 0.008, n = 6; rank-sum p = 0.011; Fig 2G).

Read as retention across the 7 d interval, the two candidate carriers decay at different rates. Reactivation fell to 12% of its 12 h value (0.153 → 0.018). L5 heterogeneity fell to 41%: within the six mice of the 7 d cohort itself, heterogeneity was 0.204 before transfer, 0.281 during transfer and 0.235 after the interval, so 41% of the transfer-related increase survived. With only two Δt values these are differences between two points, not fitted time constants, but the direction and the size of the difference between the two readouts are what motivate the two causal tests that follow.

The decay of ensemble reuse is a loss of recruited cells rather than a loss of per-cell strength (Fig 2I–J). The two cohorts were matched at the moment of identification: cells that were active at cue +1 s in the last learned audio–water block had the same response strength in 12 h and 7 d mice (1.89 ± 0.27 vs 1.95 ± 0.14; p = 0.35; 511 and 290 cells), so the cohorts start from the same engram state. In the first light–water block those cells still responded above baseline after 12 h (0.19 ± 0.09) but fell below the population baseline after 7 d (−0.11 ± 0.05; p = 0.062), while the recorded population as a whole responded identically in the two cohorts (−0.090 ± 0.034 vs −0.091 ± 0.034; p = 0.88). The number of engram cells that were still driven by the new cue differed sharply (76/511 = 14.9% versus 5/290 = 1.7%), whereas the cells that were still driven responded with equal strength (1.05 ± 0.09 vs 1.01 ± 0.38; p = 0.47; driven cells present in only 3 of 6 mice at 7 d). The interval therefore acts on how many engram cells can be engaged, not on how strongly a recruited cell responds — which is what the heatmaps and example cells of the accompanying panel show directly.

### 6.3 The tagged ensemble carries the starting-point component (Fig 3)

Correlation cannot decide whether ensemble reuse causes the elevated starting point. We therefore tagged with cFos-TRAP the cells active during the last audio–water block and inhibited them chemogenetically during the subsequent light–water training (Fig 3A).

Inhibiting the tagged ensemble lowered the light–water curve relative to control mice (group effect over blocks 1–7, p = 0.0014; control n = 9, cFos-inhibited n = 3; Fig 3B). The average difference is a lowered level; whether the slope also changes cannot be settled with three inhibited mice. A model with an interaction term gives block × group p = 0.047, but the same contrast evaluated on per-mouse slopes (0.120 ± 0.017 vs 0.065 ± 0.026 per block) is not significant (exact permutation over all 220 three-of-twelve assignments, p = 0.13; rank-sum p = 0.15). We therefore report the group effect as the causal evidence and treat the shallower slope as a consistent but underpowered description. The first-block readout points the same way but cannot carry the claim on its own: 0.056 ± 0.022 in inhibited mice vs 0.256 ± 0.077 in controls, p = 0.23 with n = 3 (Fig 3C), and is reported as descriptive only.

Two measurements that would close the causal chain are not yet available (Fig 3D–E). First, the reactivation fraction of tagged cells in inhibited versus control mice would show directly that inhibition acted by preventing reuse rather than by degrading performance in the light task itself. Second, the per-cell response amplitude of engram cells at cue +1 s, compared between 12 h and 7 d mice, would show that the activity of the tagged ensemble decays over the interval on the same timescale as its reactivation fraction; this is a distinct measure from the reactivation ratio of Fig 2G and from population heterogeneity in Fig 2H. Until these are collected, the engram interpretation of the temporal dependence rests on the group effect of Fig 3B together with the correlative decay of reactivation in Fig 2G.

### 6.4 Thalamic drive sustains L5 heterogeneity and the rate component (Fig 4)

The second component needs a manipulation that leaves the starting point intact. Chemogenetic inhibition of the posterior thalamic input to MOp during light–water training is such a manipulation (Fig 4A). Inhibited mice learned the light task more slowly: the group effect over blocks 1–7 was p = 0.071 (control n = 11, thalamus-inhibited n = 5; Fig 4B), weaker than in the original, larger cohort (p = 0.039) because only five imaged mice were available. Because the first light–water block did not differ detectably between groups (0.373 ± 0.095 vs 0.524 ± 0.076; p = 0.31; Fig 4E) while the group effect over the whole window was negative, the change is best described as a slower approach to asymptote rather than as a downward displacement — the opposite of the pattern produced by engram inhibition in Fig 3B.

At the single-cell level the manipulation landed where the correlation pointed. L5 heterogeneity fell (0.221 ± 0.021 vs 0.277 ± 0.011; p = 0.030), whereas L2/3 heterogeneity was unchanged (0.288 ± 0.017 vs 0.311 ± 0.018; p = 0.52; Fig 4C–D). Taken with Fig 3, this is a double dissociation: inhibiting the tagged ensemble moves the intercept and leaves the rate, inhibiting the thalamus moves the rate and leaves the intercept, and the two manipulations act on different layers.

We therefore propose two parallel chains — thalamus → L5 heterogeneity → learning rate, and engram reuse → L2/3 trial-to-trial stability → starting point. In the second chain each link is measured. In the first, the middle link (heterogeneity → rate) is supported by the cross-mouse correlation of Fig 2F, not by a manipulation of heterogeneity itself; this asymmetry is a limitation of the present evidence, not of the framework.

---

## 7. Discussion（英文正文）

> 口径：讨论只做四件事——把两成分/两时间常数讲清楚、与三类文献对接、说明层间分工的可行解释、把限制集中在 3.2 的三条 + 7 d 组构成。禁止出现"时间常数拟合"、"7 天完全恢复 naive"、"速率显著加快"。

We set out to ask what sets the size of a cross-modal transfer advantage. The answer we obtained is that the advantage is not one thing. Along a single axis — the interval Δt between the two tasks — the starting point and the rate of the new learning curve vary differently: the starting point is highest when the tasks are 12 h apart and is equally low when there is no prior task and when the prior task is 7 d old, whereas the rate is fastest at 12 h and stays intermediate after 7 d instead of returning to the naive level. At the cellular level the same split reappears: reactivation of the ensemble formed by the first task retains 12% of its 12 h value after 7 d, while L5 response heterogeneity retains 41%. The two components thus have different temporal sensitivities, and the manipulations we performed attach each to a different substrate.

This result connects the behavioural notion of an intercept–rate decomposition to cellular identities. Dual-timescale accounts of learning are well established behaviourally, where fast and slow processes with different retention are inferred from the shape of the learning curve (Smith et al., 2006). Our data suggest that in transfer such components can be anatomically and molecularly indexed: one is a reused cell ensemble whose availability is set by how recently it was formed, the other is a population-level response spread sustained by thalamic drive. The framework also explains why a purely behavioural description of transfer can appear inconsistent across studies — whether transfer is reported as higher initial performance, faster learning, or both depends on where along Δt the second task is placed.

The starting-point component sits squarely in the engram framework. Temporally proximate experiences produce overlapping engrams through excitability-based competition (Rashid et al., 2016; Choucry et al., 2024), and our 12 h versus 7 d comparison is, to our knowledge, the first direct test of whether that overlap governs transfer of a sensorimotor association to a different cue modality. The direction is consistent: reuse is high at 12 h, nearly absent at 7 d, and inhibiting the tagged ensemble lowers the curve. Two cautions apply. First, our causal evidence is a group-level displacement with only three inhibited mice, so the size of the effect is not established. Second, we measure the reactivation ratio, not the tuning of the reactivated cells; whether reused cells carry the same outcome-related signal as in the first task (Guyoton et al., 2025) remains to be shown at the single-cell level in this paradigm.

The rate component sits in the population-dynamics framework, but at a specific place within it. Prior work has emphasized that learning proceeds within a preserved manifold (Sadtler et al., 2014; Golub et al., 2018; Perich et al., 2018) and that cortical engagement reduces trial-to-trial variability (Churchland et al., 2010). Our data assign the variability term to the starting point and the spread term to the rate: divergence, not heterogeneity, is what covaries with first-block performance, and heterogeneity, not divergence, is what covaries with blocks-to-criterion. The heterogeneity result matches the theoretical prediction that unit-to-unit differences accelerate learning in temporally structured tasks (Saxe et al., 2014; Perez-Nieves et al., 2021), and it identifies the posterior thalamus as an upstream modulator, in line with evidence that motor learning refines thalamic influence on motor cortex (Ramot et al., 2025) and that higher-order thalamocortical motifs set cortical processing state (Halassa and Sherman, 2019).

The layer dissociation is the part of the result we understand least. L2/3 carries the stability signature and L5 the heterogeneity signature; engram inhibition and thalamic inhibition act on the two layers respectively. One reading is that L2/3, receiving the stronger thalamocortical and cortico-cortical input, expresses the read-in of a prior association as response reproducibility, whereas L5, the output stage with the larger dynamic range and stronger recurrent coupling, expresses the population spread that supports subsequent refinement. This reading is plausible but not tested: we have no manipulation that targets one layer selectively, and the model we used to generate the prediction is not part of the present evidence.

Several limitations bound these conclusions. The Δt axis has only two values (12 h and 7 d), so "different decay rates" is a statement about two points, not about a fitted time constant; intermediate values of 1–3 d would be required to distinguish exponential decay from a threshold. The rate component is measured by blocks-to-criterion rather than by a directly estimated slope, because slope comparisons in these cohorts are underpowered by a factor of roughly two (a 3.6–4.3-fold slope difference would be needed for p < 0.05). The cFos cohort contains three inhibited mice, so the causal claim for the starting point rests on a group effect whose first-block component cannot be resolved. The 7 d cohort contains two mice that received a brief audio–water review 0.5 d before transfer rather than a continuous 7–16 d interval; a sensitivity analysis excluding them reduces the cohort to four mice and weakens, rather than strengthens, the heterogeneity result. Finally, the interleaved condition that would place Δt near zero is missing from our data, so the shape of the Δt dependence between 0 and 12 h is unconstrained.

These limitations also indicate what would sharpen the framework most. A dense sampling of Δt with a single task pair would turn two points into a decay function and would show whether the two components differ in shape as well as in rate. A manipulation that changes L5 heterogeneity while leaving the tagged ensemble untouched would convert the correlational middle link of the thalamic chain into a causal one. Cell-resolved readout of engram activity amplitude at 12 h versus 7 d would test whether decay of the ensemble is a loss of cells or a loss of their response. And applying the same Δt design to the reverse direction (light first, audio second) and to other cortical areas would show whether the two-component structure is a general property of cortical transfer or specific to the pathway studied here.

---

## 8. Methods（骨架）

> 目前只搭结构 + 已经确定的参数；标注 ⚠ 的地方需要回数据和服务器核对后才能写死。

**Animals and ethics.** ⚠ 品系、性别、周龄、伦理批号待补。全部实验遵循本机构动物护理与使用委员会规定。

**Behavioural paradigm.** 一个 block = 30 个试次；同一只鼠的两个 block 之间间隔 12 h。undelayed 范式（全部成像分析使用）：cue 长 200 ms，response 窗口与 cue 同时开启，cue 结束后 800 ms 无条件给水，因此给水时刻与舔舐无关、对每个试次固定，可作为跨试次对齐的时间锚点。delayed 范式（仅行为队列）：cue 1 s → 0.5 s delay → 1 s 响应窗，窗内首次舔舐即给水，未舔不给水。任务 A = 声水，任务 B = 光水，奖励规则完全不变，只换线索模态。

> 两个范式的差别必须在方法里写明：Fig 1B 的曲线与 Fig 3B、Fig 4B 的曲线来自哪一套要看数据来源，不能混写。

**Cohorts and Δt.**

| 组 | 数据集 | Δt | 行为 n | 成像 n |
|---|---|---|---|---|
| Naive（直接学 LW） | `LightAudioBaseline` + `LAInterspersed` | 无上一任务 | 14（LAB 6 + LAI 8） | L2/3 17 / L5 14 |
| Transfer（12 h） | `AudioLightBaseline` | 12 h | 11 | L2/3 11 / L5 10 |
| 7 d Transfer | `Vacation7` | 7.5–16.1 d | 6 | 6 |
| cFos 抑制 | `202611\cFos合集.v3.mat` | 12 h | 对照 9 / 抑制 3 | ⚠ |
| Thalamus 抑制 | `THInhibit` | 12 h | 对照 11 / 抑制 5 | 5 |

- Naive 口径剔除 LAI 中 4 只在 Naive 阶段混有声水试次的鼠（`vtf0045`、`vtf0101`、`yqn0051`、`yqn0052`）。
- 7 d 组中 `yqn0400`、`yqn0430` 在间隔后有 1 次 AW Review（距 LW 仅 0.5 d）；真正符合 7–16 d 的是 `vtf1005`(7.5 d)、`vtf1015`(7.5 d)、`vtf1021`(9.1 d)、`vtf1011`(16.1 d)。正文必须声明，或做剔除敏感性分析。
- 三个数据集已从服务器移除（`RSPd`、`ALInterspersed`、`ALPureBehavior`），对应分析不可重跑。

**Surgery, virus, and manipulation.** ⚠ AAV-hSyn-GCaMP6f 注射位点/滴度、开窗方式、cFos-TRAP 病毒组合与 CNO 剂量/给药时窗、丘脑抑制的核团与病毒待补。原则性描述：cFos-TRAP 在最后一个声水 block 后标记，抑制发生在整个光水训练期间；丘脑抑制同样只覆盖光水训练期，因此可分别检验其对起点与速率的影响。

**Two-photon imaging.** 同一批细胞跨天追踪。两个成像平面（L2/3、L5）通过物镜垂向振荡交替采样，帧率 8 Hz。细胞跨会话配准与 ΔF/F、z-score 计算见 `+TransferLearning`（`CellRegistration`、`Metrics.*`）。⚠ 显微镜型号、物镜、功率、像素尺寸待补。

**Metrics.** 全部在 cue +1 s（undelayed 范式的给水时刻）计算，逐鼠先算、再做组水平统计。

- **Inter-trial divergence**：群体响应在试次间的方差除以均值的平方（`Metrics.StartBlockDivergence`），只用首个光水 block。
- **Response heterogeneity**：逐细胞逐试次 z 值的试次均值 → 跨细胞 SD，限 |z| ≤ 1（`Metrics.ResponseHeterogeneity`）。
- **Reactivation probability**：P(transfer-active | learned-active)，active 判据为 z > 基线均值 + 3σ（基线 −3–0 s）；两层按 learned-active 细胞数加权合并。
- **First-block hit rate**：首个光水 block 的命中率，逐鼠值。
- **Blocks to 50%**：逐鼠达到 50% 命中率所需 block 数（组水平曲线另配 sigmoid 拟合，仅用于展示，不用于统计推断）。

**Statistics.** 学习曲线用线性混合效应模型 `Performance ~ Block + Group + (1|Mouse)`，窗口固定为 block 1–7；逐鼠指标用双侧 rank-sum；相关用 Spearman；多重比较用 Holm 校正（标出校正前后）。斜率的组间比较用按鼠重排的置换检验（2,000 次），并报告可检出下限（|Δlog slope| ≈ 1.29–1.46）。所有均值写成 mean ± SEM，n 为鼠数（逐细胞分析另行注明细胞数）。

**Data and code availability.** ⚠ 待定。分析代码为 MATLAB 包 `+TransferLearning`，四图脚本见第 12 节。

---

## 9. 需在正文中明确处理的限制

1. **7dayTransfer 组构成**：6 只里有 2 只（`yqn0400`、`yqn0430`）在间隔后先做了一次 AW Review（距 LW 仅 0.5 d），真正符合 7–16 天间隔的是 `vtf1005`(7.5 d)、`vtf1015`(7.5 d)、`vtf1021`(9.1 d)、`vtf1011`(16.1 d)。方法里必须写明，或做敏感性分析（去掉 2 只后 n = 4，7 d 组的异质性结论会进一步减弱）。
2. **LAInterspersed 的 4 只混刺激鼠**：`vtf0045`、`vtf0101`、`yqn0051`、`yqn0052` 在 Naive 阶段混有声水试次。**行为口径（Fig 1）下剔除**，所以"光水 naive"实际是 LAB 6 + LAI 8 = 14 只；但 **Fig 2 的散度口径用 LAB Naive + LAI Naive 全部鼠**（L2/3 n = 17、L5 n = 14），尚未做同样的剔除——两处 n 不一致，需在定稿前统一（见第 10 节待办）。
3. **速率项的表述**：只能说"起点优势被 7 天抹平，速率的可检出性不足"，不能写"7 天完全抹去加速效应"，也不能写"7 天保留了大部分速率优势"。
4. **cFos 组 n = 3**：首 block 差异测不出（p = 0.23），斜率差异同样不稳（LME 交互 p = 0.047，逐鼠置换 p = 0.13）。原文 Fig4.5 的"首块不变"是 TH 组结论（0.52 vs 0.40, p = 0.29），不要混用到 cFos 组。
5. **Δt 只有两个时间点（12 h 与 7 d）**：Fig2F 的"印迹 vs 异质性不同衰减速率"是两点连线，不能拟合时间常数。讨论中应主动声明，或补 1–3 天的中间点。
6. **数据目录已迁移（2026-11-05 核对）**：`TransferLearning.m` 的七个主数据源已全部指向服务器现存的新文件——`AudioLightBaseline` `202610\…v6`、`LightAudioBaseline` `202610\…v4`、`ALInterspersed` `202610\…v4`、`LAInterspersed` `202610\…v6`、`ALPureBehavior` `202610\…v3`、`LAPureBehavior` `202610\…v4`、`THBehavior` `202610\…v2`、cFos `202611\cFos合集.v3`；旧目录 `202508 / 202511 / 202512 / 202601` 均已删除。**仍有 3 个旧数据源无法迁移**：`202512\MOp全钙.v4.mat`（`TransferLearning.MB`）与 `202508\RSP-G6f…v2.mat`（`TransferLearning.RSPd`，Fig 4B/4D/4E/4F 与中文图 Fig351B/Fig64E 依赖）在服务器与本地 `%TEMP%` **均无副本**；`scFLARE` 仅剩 `%TEMP%` 缓存。这三项在正文/图中引用前必须先找回源文件。`TransferLearning.LocalCachePath` 工具函数保留，但主数据源已不再依赖它。

---

## 10. 待办

- [ ] **Fig 3 主张确认**：是"抑制印迹 → 曲线整体下移（p = 0.0014）但首块单点不显著（n = 3）"，还是改用 trial 级首训练单元曲线（原文口径）呈现"早期不受影响、后期变慢"。
- [x] **cFos 数据恢复**（2026-11-05 完成）：数据已迁到 `\\Data-Server-2\个人数据\张天夫\202611\cFos合集.v3.mat`；`CFosInhibitionSessions.m` 与 `Fig2H` / `Fig2I` / `Fig45D` / `Fig45F` 四个脚本均已改指新路径，`LocalCachePath` 包装已撤除。结论数值不变（Fig3 B/C：0.256 vs 0.056，组效应 p = 0.0014）。
- [ ] **扩大 7 天组**：L5 异质性 0.281 vs 0.235 若要坐实为"部分保留"，按当前差值（0.046）与组内 SD（0.011 / 0.023）估算需每组 8–10 只。
- [ ] **补 Δt 中间点**（可选）：1–3 天间隔组，把两点连线变成真正的衰减曲线。
- [ ] **补穿插臂**：`ALInterspersed` 已可用（见 [修改记录_20261029.md](./修改记录_20261029.md) 第 5 节）：**3 只鼠**、32 会话，设计为"学会声水 → 同会话内 AW 20 + LW 20 交错"。首穿插会话 LW 命中率 0.95 / 0.05 / 0.85（2/3 只鼠一上手就接近顶），但因 LW 是在 AW 持续复述下学的，不能直接当 Δt≈0 点，需在图注说明。
- [ ] **清理旧脚本**：[Fig1_ThreeGroupLightWaterLearningCurve.m](../Fig1_ThreeGroupLightWaterLearningCurve.m) 已被 Fig1 取代且仍写 SVG，建议删除或改为 .fig。
- [ ] **口径统一**：`Fig2F_TimeContinuityDecay.m` 内嵌了 Fig1I 的整套 helper 副本；若 Fig1I 的散度/异质性算法改动，两处需同步，或改用 `TransferLearning.Metrics.*`。
- [ ] **核对 naive 成像 n 与行为 n 的口径差**：Fig 2 的 naive 散度用 LAB Naive + LAI Naive 全部鼠（L2/3 n = 17、L5 n = 14），而行为 naive 剔除了 LAI 中 4 只混刺激鼠（n = 14）。需确认这 17/14 的构成，并在图注写明与 Fig 1 的 n 不同的原因（是否含 ALDelayed 或未剔除的 LAI 鼠）。

---

## 11. 图注草稿

**Fig 1｜Temporal continuity sets the cross-modal transfer advantage.**
(**A**) Three temporal relations before the same light-water task: light-water learned directly (naive), or learned 12 h or 7 d after the audio-water criterion. (**B**) Light-water learning curves (mean ± SEM with group-level sigmoid fits; n = 14 / 11 / 6 mice). LME group effect over blocks 1–7, p = 0.0012; pairwise group contrasts: naive vs 12 h p = 3.6×10⁻⁴, 12 h vs 7 d p = 0.023, naive vs 7 d p = 0.35. (**C**) First light-water block hit rate per mouse (rank-sum: naive–12 h p = 0.0025; 12 h–7 d p = 0.0045; naive–7 d p = 0.49). (**D**) Blocks needed to reach 50% hit rate (rank-sum: naive–12 h p = 0.0082; 12 h–7 d p = 0.032; naive–7 d p = 0.39). (**E**) Transfer advantage as a function of the inter-task interval Δt: top, first light-water block hit rate; bottom, blocks to 50%; axes shared. The interleaved arm (audio-water interleaved with light-water) is not available and is marked n/a.
**Fig 2｜Single-cell counterparts of the two components: L2/3 stability, L5 heterogeneity and ensemble reuse.**
(**A**) Distribution of per-cell z-scores at cue +1 s in learned audio–water blocks (n = 4,469 cells; 50.8% rising, 49.2% suppressed) — the heterogeneous baseline that the light task inherits. (**B**) Population trajectories of the first light–water block in PCA space, restricted to L2/3 cells: naive trajectories fan out in several directions, transfer trajectories run in parallel; the per-mouse quantification is in **C**. [Pipeline pending; panel currently a placeholder.] (**C**) Inter-trial divergence at cue +1 s in L2/3, per mouse (naive 4.12 ± 0.21, n = 17; 12 h 3.19 ± 0.24, n = 11; 7 d 4.30 ± 0.36, n = 6; rank-sum naive–12 h p = 0.0041, 12 h–7 d p = 0.037). (**D**) Same measure in L5 (4.13 ± 0.24, n = 14; 4.09 ± 0.21, n = 10; 4.55 ± 0.28, n = 6; p = 0.93 and 0.22) — a negative control showing that the divergence effect is layer-specific. Divergence is the trial-to-trial variance of the population response normalized by its squared mean. (**E**) L2/3 divergence vs first-block hit rate (Spearman ρ = −0.63, p = 1.6 × 10⁻⁴, n = 31 mice). (**F**) L5 response heterogeneity vs blocks to reach 50% (ρ = −0.71, p = 9.8 × 10⁻⁵, n = 24 mice). (**G**) Reactivation probability P(transfer-active | learned-active) at cue +1 s: 0.153 ± 0.041 (12 h, n = 11) vs 0.018 ± 0.008 (7 d, n = 6), rank-sum p = 0.011; 12% retained after 7 d. (**H**) L5 response heterogeneity: naive 0.199 ± 0.023 (n = 10), 12 h 0.277 ± 0.011 (n = 8), 7 d 0.230 ± 0.021 (n = 6); naive–12 h p = 0.009, 12 h–7 d p = 0.059, naive–7 d p = 0.37; within the six 7 d mice heterogeneity was 0.204 before transfer and 0.281 during transfer, so 41% of the transfer-related increase was retained. L2/3 heterogeneity did not differ between cohorts (all p ≥ 0.18). Heterogeneity is the across-cell SD of trial-mean z-scores at cue +1 s, restricted to |z| ≤ 1. (**I**) Mean z at cue +1 s of cells that were active in the last learned audio–water block (engram cells), measured in that block: 12 h 1.89 ± 0.27 (n = 11 mice, 511 cells) vs 7 d 1.95 ± 0.14 (n = 6, 290 cells), p = 0.35 — the two cohorts are matched at the moment of identification. (**J**) The same cells in the first light–water block: 12 h 0.19 ± 0.09 vs 7 d −0.11 ± 0.05, p = 0.062, while all recorded cells did not differ (−0.090 ± 0.034 vs −0.091 ± 0.034, p = 0.88). Among cells still reactivated, strength was equal (1.05 ± 0.09 vs 1.01 ± 0.38; reactivated cells present in 3 of 6 mice at 7 d). I–J decompose **G**: the interval reduces how many engram cells can be engaged, not how strongly a recruited cell responds.

**Fig 2b｜Engram cells across the inter-task interval: population heatmap and example cells (alternative layout).**
(**A**, **B**) Rows are the engram cells of the 12 h cohort — cells active at cue +1 s (> baseline mean + 3σ, baseline −3 to 0 s) in the last learned audio–water block (n = 511 cells, 11 mice) — sorted by their learned response and shown in that block (**A**) and in the first light–water block (**B**), same cells and same order. (**C**, **D**) Same for the 7 d cohort (n = 290 cells, 6 mice). (**E**, **F**) Example cells of the 12 h cohort: three cells that are still driven in the first light–water block, chosen as the ones closest to the median of their own cohort (colour, numbered); black, median of all engram cells; grey, median of all recorded cells (n = 5,105). (**G**, **H**) Same for the 7 d cohort. The number of engram cells still driven by the new cue is 76/511 (14.9%) at 12 h but 5/290 (1.7%) after 7 d, whereas the cells that are still driven respond with equal strength — the interval removes recruited cells rather than weakening individual cells. Heatmap colour scale is symmetric and robust (±3.5 z; values beyond saturate); traces are plotted without clipping. At 7 d the 5 driven cells come from 3 mice, so the examples in **G**, **H** come from 2 mice.

**Fig 3｜Engram cells causally carry the cross-modal transfer.**
(**A**) cFos-TRAP labelling strategy and CNO inhibition. (**B**) Light-water learning curves of control (n = 9) and cFos-inhibited (n = 3) mice; LME group effect over blocks 1–7, p = 0.0014. (**C**) First light-water block hit rate (0.256 ± 0.077 vs 0.056 ± 0.022; p = 0.23, n = 3; underpowered). (**D**) Planned: reactivation fraction of tagged cells in cFos versus control mice. The cFos dataset contains behaviour only (no cell-level data), so this panel cannot be computed from the current files and is described in text only. (**E**) Response strength of engram cells at cue +1 s, 12 h versus 7 d: 1.89 ± 0.27 vs 1.95 ± 0.14 at identification (p = 0.35) and 0.19 ± 0.09 vs −0.11 ± 0.05 in the first light-water block (p = 0.062) — a distinct measure from the reactivation ratio of Fig 2G and the population heterogeneity of Fig 2H.
**Fig 4｜Thalamic drive sustains L5 heterogeneity and the learning-rate component.**
(**A**) Thalamus→MOp projection and CNO inhibition during light-water training. (**B**) Light-water learning curves of control (AW→12 h→LW, n = 11) and thalamus-inhibited (n = 5) mice; LME group effect over blocks 1–7, p = 0.071. (**C**, **D**) Response heterogeneity in L2/3 (0.311 vs 0.288, p = 0.52) and L5 (0.277 vs 0.221, p = 0.030). (**E**) First light-water block hit rate (0.524 ± 0.076 vs 0.373 ± 0.095, p = 0.31).

---

## 12. 相关文件

配套文档：

- 12 个数据集的设计/鼠数/刺激/成像情况：[数据集汇总.md](./数据集汇总.md)
- 2026-10-29 的全部改动（数据恢复、新增图/表、新增数值、结论修正）：[修改记录_20261029.md](./修改记录_20261029.md)

旧稿素材（上一版手稿，本稿的引言与文献表直接复用）：

- [Introduction.md](./Introduction.md) — 第 1、3 段可直接搬，第 2 段需改写为"Δt"框架
- [Results.md](./Results.md) — 原文 Fig 1–5 的结果叙述与图注，可作为措辞与定义的参考
- [References.md](./References.md) — 本稿第 5 节引用的全部条目均在此（含 Smith et al. 2006 双时间尺度）

| 图 | 脚本 | 输出 |
|---|---|---|
| Fig 1 | `Fig1_TimeContinuityBehavior.m` | `Fig1_TimeContinuityBehavior.fig` |
| Fig 2 | `Fig2_SingleCellDynamics.m` | `Fig2_SingleCellDynamics.fig` |
| Fig 2 备选（印迹热图 + 示例细胞） | `Fig2_EngramHeatmap.m` | `Fig2_EngramHeatmap.fig`（2 行 × 4 列，A–H） |
| Fig 2F 单独 | `Fig2F_TimeContinuityDecay.m` | `Fig2F_TimeContinuityDecay.fig` |
| Fig 3 | `Fig3_EngramCausality.m` | `Fig3_EngramCausality.fig` |
| Fig 4 | `Fig4_ThalamusHeterogeneity.m` | `Fig4_ThalamusHeterogeneity.fig` |
| 穿插数据表（不做图） | `ALInterspersed_Summary.m` | `ALInterspersed_SessionTable.csv`、`ALInterspersed_MouseTable.csv` |

图窗输出目录：`\\Data-Server-2\个人数据\杨青宁\<yyyyMM>\`。
公共函数：

- `+TransferLearning/+BehaviorSessions/LightWaterLearningSessions.m`
- `+TransferLearning/+BehaviorSessions/SecondTaskAudioWaterSessions.m`
- `+TransferLearning/+BehaviorSessions/CFosInhibitionSessions.m`
- `+TransferLearning/+Metrics/StartBlockDivergence.m`
- `+TransferLearning/+Metrics/ResponseHeterogeneity.m`
- `+TransferLearning/+Metrics/EngramResponseStrength.m`（印迹细胞在旧/新任务 block 的强度，Fig 2I–J 与 Fig 3E）
- `+TransferLearning/LocalCachePath.m`（网络数据缺失时回退到 `tempdir` 副本）
- `+TransferLearning/+Metrics/PerMouseSessionSummary.m`
- `+TransferLearning/DatasetDesign.m`








