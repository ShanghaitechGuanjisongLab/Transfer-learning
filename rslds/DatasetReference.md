# ALB `UniExp.DataSet` 参考

> 目的：把数据库的结构、字段语义、三套时间基和既有分析约定固定下来，
> 避免再靠猜。所有数字均为 2026-10-23 在 MATLAB R2026a 上实测。

---

## 0. 加载

```matlab
cd('d:\git\Transfer-Learning');
if ~exist('UniExp.DataSet','class')
    matlab.project.loadProject('D:\git\Transfer-Learning\Transferlearning.prj');
end
DS = TransferLearning.AudioLightBaseline();     % 约 133 s，有大量 TagSplitTrial 警告
```

同类函数：`TransferLearning.LightAudioBaseline()`（LAB 队列）、`THInhibit()`、`LAInterspersed()`。
`Mice.Paradigm` 目前只有一类：`声光无穿插`。

---

## 1. 七张表总览

| 表 | 尺寸 | 关键列 |
|---|---|---|
| `Mice` | 11 × 2 | Mouse, Paradigm |
| `DateTimes` | **114** × 5 | DateTime, Mouse, Metadata, **Phase**, SeriesInterval |
| `Blocks` | **114** × 12 | DateTime, Design, BlockUID, BlockRI, BlockTags, EventLog, Performance, **MustWarn**, TiffPath, BreakTime, PrefixTrials, BlockIndex |
| `Trials` | **3721** × 10 | TrialUID, BlockUID, TrialIndex, Time, **Stimulus**, Behavior, TrialRI, **SampleRange**, TrialTags, ResampledTags |
| `Cells` | **5108** × 8 | Center, Radius, CellIndex, **ZLayer**, CellType, **CellUID**, Mouse, PixelXY |
| `BlockSignals` | 50966 × 3 | BlockUID, CellUID, **BlockSignal**（连续原始荧光）|
| `TrialSignals` | 1589752 × 4 | CellUID, TrialUID, TrialSignal, **ResampledSignal** |
| `Manipulation` | 0 × 0 | 本队列未用 |

---

## 2. 各表详解

### 2.1 `DateTimes` — 会话表（114 个会话）

- `Phase`（categorical，5 类）：`Naive / Learned / Transfer / Final / Recall`
- **64 个会话有 Phase 标签，50 个未标注**（`ismember` 后为 `<undefined>`）
- `Metadata`：cell，逐会话的采集参数
- `SeriesInterval`：duration，同一 Series 内相邻会话间隔

**Phase × Design 实测交叉表**

| Phase | AudioWater | LAu | LAuW | LightWater |
|---|---|---|---|---|
| Naive | 11 | 4 | 6 | 0 |
| Learned | 11 | 0 | 0 | 0 |
| Transfer | 0 | 0 | 0 | 11 |
| Final | 0 | 0 | 0 | 11 |
| Recall | 10 | 0 | 0 | 0 |
| （未标注）| 39 | 0 | 0 | 11 |

⇒ **Learned / Transfer / Final 每只鼠恰好 1 个会话，Phase 标签无歧义**。
只有 Naive 有 1–2 个（LAu/LAuW 在当天早上，AudioWater 在当天晚上；yqn1130 无 LAu/LAuW）。

`Recall` 是回忆测试，任务结构与学习序列不可比，**导出时已跳过**。

### 2.2 `Blocks` — 114 个采集 block

| 列 | 含义 |
|---|---|
| `BlockRI` | **同一 Design 内的会话序号**（1 起）。实测 vtf0233 的 AudioWater：RI=1 Naive、2–4 未标注、5 Learned、6 Recall |
| `Design` | categorical：`AudioWater / LightWater / LAu / LAuW` |
| `BlockTags` | cell，每 block 一个 timetable（**CD1/CD2 模拟通道就在这里**）|
| `EventLog` | cell，行为事件 timetable（**行为时钟**，见 §3）|
| `Performance` | double 0–1，112/114 非空（会话级命中率）|
| **`MustWarn`** | string，数据质量标记，只有 8/114 非空（见 §6）|
| `TiffPath` | 路径，实测形如 `\\Data-Server-2\...\<鼠>\文件间配准\<鼠>.<时间>.<Design>.变换.tif` —— **“文件间配准”即跨会话图像配准** |
| `BreakTime` | uint16，仅 1 个 block 非零（最大 7620）|

### 2.3 `Trials` — 3721 个回合

- `Stimulus`（categorical，7 类）：`AudioWater, LightWater, AudioOnly, LightOnly, WaterOnly, StartMonitor, StopMonitor`
  - **`StartMonitor` / `StopMonitor` 是伪 trial，必须剔除**
  - 主阶段会话内刺激单一：AudioWater 会话 = 100% AudioWater；LightWater 会话 = 100% LightWater（无 catch trial）
  - `AudioOnly / LightOnly / WaterOnly` 只出现在 **LAu / LAuW**（学习前的线索/结果单独表征）
- `Behavior`：0/1（1 = 命中）
- `TrialRI`：回合内/会话内重复序号 1..30
- `SampleRange`：table {`Start`, `Tag`, `End`}，**采样下标（1 基）**，`Tag` = cue onset。
  实测窗口长度中位 **49 样本**，`Tag` 位于窗口 **49%** 处（近似居中）。
- `TrialTags` / `ResampledTags`：cell{table}，每回合一个 48 行 × {CD1, CD2} 的**重采样模拟通道**

### 2.4 `Cells` — 5108 个细胞

| 列 | 含义 |
|---|---|
| `CellUID` | **全局唯一 1..5108**，按鼠连续分区、跨鼠无重复 |
| `Mouse` | categorical |
| **`ZLayer`** | categorical：`MOp2/3`、`MOp5`、`L2`（**L2 无细胞**）。**每只鼠都有 MOp2/3 与 MOp5 两层**，yqn1130 例外（只有 MOp2/3）|
| `CellType` | categorical：`All`、`hSyn` —— **本队列 5108 个细胞全部是 hSyn**，`All` 无细胞 |
| `CellIndex` | uint16，**在 (鼠, ZLayer) 内从 1 起编号**，不是全局 |
| `Center` | table {X, Y}，像素坐标 |
| `Radius` | table {X, Y}，ROI 半径 |
| `PixelXY` | cell，ROI 掩膜像素坐标（画图用）|

**每鼠细胞数（MOp2/3 + MOp5）**

| 鼠 | MOp2/3 | MOp5 | 合计 |
|---|---|---|---|
| vtf0233 | 253 | 297 | 550 |
| vtf0352 | 307 | 329 | 636 |
| vtf0353 | 104 | 239 | 343 |
| vtf0354 | 156 | 222 | 378 |
| vtf1233 | 339 | 432 | 771 |
| yqn0020 | 269 | 363 | 632 |
| yqn0133 | 125 | 113 | 238 |
| yqn0240 | 282 | 281 | 563 |
| yqn0411 | 210 | 210 | 420 |
| yqn1018 | 183 | 253 | 436 |
| yqn1130 | 141 | — | 141 |

### 2.5 `BlockSignals` — 连续原始荧光

`(BlockUID, CellUID, BlockSignal)`，`BlockSignal` 为 double 行向量，长度 = 该 block 的采样点数（约 7000–10000 @ 8 Hz）。
**这是连续轨迹分析（吸引子/流场）唯一正确的入口**。

每个 block 的细胞数是可变子集（实测出现过 0 / 141 / 238 / … / 771）。
yqn0240 的 Naive 只有 511 个细胞，后续会话才 561–562 ⇒ **细胞是逐会话检测的，跨会话取交集时必须按会话逐一处理**。

### 2.6 `TrialSignals` — 回合信号（两个变体）

| 列 | 内容 |
|---|---|
| `TrialSignal` | double 行向量，**原始**长度（多数 49，少数 181）|
| `ResampledSignal` | **double 1×48，已重采样到统一种子** |

**`ResampledSignal` 的确切语义（已实测验证）**
- 时间轴 = **线索 −3 s ~ +3 s**，48 点，`dt = 0.128 s`（即 8 Hz）
- 与 `ResampledTags` 的时间轴一致（`LickTrace` 用 `TagTime = linspace(-3,3,nTag)`）
- 内容是**原始荧光**（实测 min > 0）
- 对齐来源是 `SampleRange.Tag`，**不是 EventLog** ⇒ 可信

⇒ **所有 cue 锁时分析都可以直接用 `ResampledSignal`，不必自己做事件对齐。**

---

## 3. 三套时间基（最容易踩的坑）

| 时间基 | 载体 | 单位 | 用途 |
|---|---|---|---|
| **① 行为时钟** | `Blocks.EventLog` (timetable) | 秒，block 内绝对 | **只可做同钟内的差（如 RT = 命中 − 线索）**。不能换算成采样下标 |
| **② 采样下标** | `Trials.SampleRange.{Start,Tag,End}` | 整数，1 基 | **对齐钙数据的唯一权威**。`Tag` = cue onset |
| ③ 重采样网格 | `ResampledTags` / `ResampledSignal` | 48 点，−3~+3 s | 回合级分析 |

数据来源：数据库由**成像记录**（`BlockTags` 的 CD 通道）与**行为学记录**（`EventLog`/`Trials`）合并而成。
钙成像通常早于行为学记录开始、晚于其结束，**两套时钟逐会话偏移不同**（实测 −23.8 ~ +11.3 s）。

**硬规则**
1. 只有 `BlockTags` / `SampleRange` 能直接对齐钙数据
2. `EventLog` 派生的 `idx_SoundOn` / `idx_LightOn` / `idx_Hit` 等**永不可用于对齐**
3. cue（声或光）→ `CD1` 上升沿；舔水/给水 → `CD2` 上升沿
4. CD 通道是 512 基线的模拟量（基线≈512，峰≈750），阈值必须用 `median + frac×(max−median)`，不能用 0/1
5. 偏移逐会话不同，**永不硬编码**

**快速校验**：0–1 s 窗内 `|t|>3` 细胞比例 vs 线索前窗，正确时应有 3–7 倍富集（8–9% vs 1–3%）。

---

## 4. 查询接口

```matlab
% 通用表查询，可按任意列筛选（Mouse / Phase / Design / Stimulus / DateTime / ZLayer / CellUID / BlockRI / ...）
T = DS.TableQuery(["ResampledSignal","CellUID","TrialUID","Behavior"], ...
                  struct('Mouse','vtf0233','Stimulus','AudioWater'));

% 回合信号 + 内置归一化 + 基线
nts = DS.QueryNTS(struct('Stimulus','LightWater','DateTime',dts), ...
                  UniExp.Flags.ZScore, 1:24, 'ExtraColumns', ["DateTime"]);
```

- 归一化选项（`UniExp.Flags`）：`dFdF0` / `log2FdF0` / `ZScore`；`F0Samples` 指定基线点
- 支持**一次批量查多会话**（`DateTime` 传向量），不要循环逐会话查
- 查询结果默认 **memoize**，数据更新后需 `clearCache`
- 其他有用方法：`ResampleTrials`、`TagSplitTrial`、`QueryBPC`、`QueryNTATS`、`ExtractMice`、`SetDesignByStimuli`

`DS.ValidTableNames()` 返回 7 个表名，**新式接口只支持这 7 张表**；`DateTimes.Phase` 等列可直接作为筛选条件。

---

## 5. 既有分析流水线 —— 哪些可用、哪些不参考

> **用户 2026-10-23 明确划定范围**：下面的 5.1 与 5.2 属于**其他方向的尝试**，
> 本项目（rslds 吸引子）**不参考、也不需要与它们对齐措辞**。
> 记录在此仅为避免以后重复翻找，不代表要复用。

| 流水线 | 调用者 | 本项目是否使用 |
|---|---|---|
| `QueryZScoreNts → BuildTrialMatrix → DecodeCuePrePostTransfer` | Fig3D / 信息编码 | ❌ 另一方向 |
| `EarlyOnsetCells → CellResponseTable` | 英文图/*Onset* | ❌ 仍在尝试中 |
| `LickTrace` | **仅** `EarlyOnsetCells.m:72` | ❌ 随上一条一起排除 |
| `BuildTrialTiming` | EarlyOnsetCells / LearnedSessions / PlateauDropouts / 两个图脚本 | ⚪ 可选（见下）|
| `LearnedSessions` / `PlateauDropouts` | 无上层调用者（工具函数）| ⚪ 可选（会话 QC）|

`BuildTrialTiming` 有独立价值：`LearnedSessions`（命中率 ≥0.80 连续 2 会话 = 已学会）
与 `PlateauDropouts`（到平台后又掉线，如 yqn2200 光水末次 0.38）都是**纯行为学会判据**，
与解码/onset 那条线无关。本项目若需要 RT / Outcome / 行为学会判据可用它，
但**它的 `CueTime` 是行为钟，不可用于对齐钙数据**（见 §3）。

> `LickTrace` 的 CD2 阈值写法 `median + max(3×MAD, 1)`（基线取 pre-cue）
> 与本项目 `event_align.py` 的 `median + frac×(max−median)` 属同一族稳健阈值，
> 说明"绝不用 0/1 绝对阈值"是团队既有标准。**仅作交叉印证，不调用。**

---

### 5.1 回合解码（Fig3D / 信息编码）— 不参考
```
QueryZScoreNts(DS, Mouse, Stimulus)   % 逐细胞逐回合行内 z-score（整条 48 点）
  → BuildTrialMatrix(RawTbl, CellUIDs) % trials × cells × time 立方体
  → DecodeCuePrePostTransfer(Task, tVec, NPerm)
       pre(−1~0 s) vs post(0~1 s)，LASSO logistic，λ = 0.02/sqrt(2·nTrain)
       Stage1 5 折 trial-aware CV；Stage2 训练集全量拟合后测新阶段
       null = 只打乱训练标签的置换检验
```
**⇒ 记录备查。本项目不与之对齐措辞（用户 2026-10-23 指定）。**

### 5.2 行为 timing 与舔舐 — 仅作交叉印证
```
BuildTrialTiming(DS)   % 每回合：TrialStart/CueTime/CueKind/OutcomeTime/Outcome/RT（秒，行为钟）
LickTrace(TrialTags)   % CD2 二值化：median + max(3×MAD, 1)，基线取 pre-cue
```
**注意**：`BuildTrialTiming` 的 `CueTime` 是**行为钟**，不可用于对齐钙数据；但 `RT`、`Outcome`、`Stimulus`、`Phase`、`Design` 可用（同钟相减，偏移抵消）。

### 5.3 运动相关细胞 / onset — 不参考
```
EarlyOnsetCells(DS, Stimulus=..., Designs=..., ExcludePhases="Naive", ...)
  → R.Cells (Class/Onset/IsEarlyOnset), R.Traces, R.CueTraces
CellResponseTable(R)   % 每细胞一行：ActiveFrac, RespCue, RespMove
```
约定：cue 响应窗 0–1 s；运动 onset 以 **线索后首次超过 CD2 阈值** 定义（无杠杆轨迹）；
排序/打乱零模型 1000 次，95/5 百分位判 movement-active / -suppressed。

---

## 6. 数据质量标记

`Blocks.MustWarn` 只有 **8/114** 非空：

| 标记 | 数量 |
|---|---|
| `CD1没记到` | 3 |
| `中断两次，行为和钙对不上` | 2 |
| `2/5层亮度反相` | 1 |
| `拍错Z层，舍弃信号` | 1 |
| `水滴漏了，没有拍到` | 1 |

加载时 `TagSplitTrial` 还会抛另一批警告（按 Block 序号）：
- `No_TagPeaks_found`：Block 36 / 37 / 38 / 100 / 14 —— CD1 里找不到 cue 峰
- `Split_trials_less_than_existing_Trials`：Block 4–7、58–60、63–70、73（等 20+ 个）
- `Block_lacks_BlockTag`：Block 51

**⇒ 做任何分析前必须先按 `MustWarn` + `ResampledTags` 是否有峰过滤 block/trial。**

---

## 7. 对当前分析（rslds 吸引子项目）的直接影响

1. **混层问题**：此前所有 `Step4`–`Step15` 都在 `MOp2/3 + MOp5` 合并后的群体上做。
   应至少加一次分层复算，或明确声明"2/3 层与 5 层合并"。
2. **导出缺字段**：`rslds/ExportForRSLDS.m` 目前缺
   - `stimCode`（每 trial 的 Stimulus）→ 无法在 Python 侧区分 AudioOnly / LightOnly / WaterOnly
   - `ZLayer`（每细胞）
   - `MustWarn`、`Performance`（每 block）
3. **回合级分析不必自己对齐**：`ResampledSignal` 已经是正确的 cue 锁定 −3~+3 s 张量
4. **连续分析仍用导出**：`BlockSignals.BlockSignal` 是连续轨迹的唯一入口，导出为 `X` 后再在 Python 侧做 ΔF/F → 去漂移 → z-score
5. **`naive` 有两种**，必须按 `Design` 显式区分：`LAu`/`LAuW`（线索/结果单独）与 `AudioWater`（同任务未学）

---

## 8. 已知坑

| 坑 | 现象 | 处置 |
|---|---|---|
| `TransferLearning.Xs` 不存在 | `CellResponseTable.m` 第 11 行 `TransferLearning.Xs(:).'` 会报 "无法识别" | 该函数当前不可用；需要自己给时间轴 `linspace(-3,3,48)` |
| 函数定义不能写在 MCP eval 里 | `function ... end` 报"函数定义在此上下文中不受支持" | 写成 .m 文件，或把循环内联 |
| `fprintf` 遇 `<missing>` 报错 | `MustWarn`/`Phase` 有空值 | 先 `if ismissing(x); x=""; end` |
| `DS.Trials.Stimulus` 与 string 直接 `[a;b]` 拼接报错 | categorical | 先 `s = string(...)` 并 `(:)` |
| `BlockSignals` 有 0 细胞 block | `BlockSignal` 为空 | 加载时过滤 |
| `p.Type` 是 `matlab.metadata.Type` | 直接 `fprintf('%s')` 报错 | 用 `p.Type.Name` |
| 加载有 20+ 条警告 | 正常（TagSplitTrial 的数据质量报告）| 不要把警告当错误 |
