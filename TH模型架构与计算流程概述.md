# TH 抑制性神经元模型架构与计算流程概述

## 1. 模型目的

这个脚本是一个最小化的 rate model，用来同时复现三类定性现象：

1. Transfer 组在首场学习时比 Naive 组有更高的起点。
2. TH 相关的抑制性竞争会塑造响应异质性。
3. 更高的 L2/3 响应异质性会对应更快的后续学习。

对应实现文件为 THInhibitoryHeterogeneitySimulation.m。

## 2. 总体架构

模型包含三类神经元群体和三类内部状态：

### 神经元群体

1. L2/3 兴奋性群体
2. L5 兴奋性群体
3. 抑制性中间神经元群体

### 内部状态

1. prior pattern：表示迁移学习带来的可复用先验
2. learn state：表示随 session 逐步累积的学习状态
3. eligibility trace：表示任务相关活动留下、并可被 TH 门控兑现的短时可塑性痕迹

### 外部调制

1. THNetworkLevel：控制 TH 对抑制群体竞争和 L5 结构化模式表达的影响
2. THPlasticityLevel：控制 TH 对 eligibility trace 兑现为学习更新的门控强度
3. PriorGain：控制迁移先验对表征复用和塑性阈值的影响

下文中的 TH 均指以后部丘脑 PO 为中心的 thalamocortical drive，而不是多巴胺或酪氨酸羟化酶信号。

整体上，这不是一个生物细节完备模型，而是一个机制型、可解释的低维生成模型。

### 参数族与神经科学依据

这份脚本中的标量数值不是逐一从单篇实验论文直接拟合出来的“真实生理常数”，而是在若干生物学约束下选取的工作点：

1. 神经活动必须是有界的，不能在递归耦合下发散。
2. 群体响应必须允许出现 trial-to-trial 波动、个体差异、层间耦合和学习过程中的缓慢累积。
3. 模型必须同时满足三条现象约束：Transfer 首场起点更高、TH 抑制削弱后续学习、L2/3 异质性预测学习加速。

因此，文档里给出的“合理性解释”主要对应参数族的生物学角色，而不是声称某个具体数值已经被单独实验精确测量。

| 参数族 | 代码参数 | 神经科学含义 | 合理性解释 / 参考文献 |
|---|---|---|---|
| 仿真规模与有界速率 | NumMice, NumSessions, NumTrials, NE23, NE5, NI, ResponseScale, Ceiling | 用少量群体单元近似层级网络，用有界 rate 表征平均放电/钙活动 | 这是典型 reduced population model 做法；tanh 和 ceiling 用于保证活动不发散，并保留群体均值与异质性的可解释性 |
| 个体差异与试次波动 | HeteroGain, Noise23, Noise5, NoiseI | 鼠间差异、细胞群体增益差异和 trial-to-trial variability | 神经元相关变异与跨动物差异是群体记录中的常见事实；这里把它们压缩成少数随机参数，而不是逐细胞拟合。参考 Cohen and Kohn, 2011 |
| 感觉驱动与行为判别 | CueTo23, CueTo5, BaseTo23, BaseTo5, ReadoutGain, HitThreshold, BaselinePenalty, Readout | 线索驱动、基线驱动以及下游读出阈值 | 该组参数表达的是“cue relative to baseline”的判别，而不是绝对放电值；与当前实验中命中率由任务相关群体分离度决定的设定一致。低维群体读出与稳定行为映射的思想可参考 Perich et al., 2018；Gallego et al., 2020 |
| 迁移先验 / 抽象结构复用 | Prior23, Prior5, PriorGain, PriorBias, PriorThresholdShift | 已学任务在新任务中的可复用表征、初始偏置和较低的进入可塑状态门槛 | 这里的 prior 不是额外奖励项，而是抽象/共享结构在新任务中的再利用，因此能提高首会话 cue-baseline 可分性，并减少额外学习所需的表征重排。参考 Bernardi et al., 2020；Wakhloo et al., 2026 |
| 学习相关表征累积 | Learn23, Learn5, LearnTo23, LearnTo5, MaxLearnState, InitialLearnState | 随 session 累积的任务相关群体模式和可用学习状态 | 这些参数把慢性学习过程压缩成一个跨 session 状态变量，用于表达“旧结构调用之后仍需继续优化”的事实；与快速学习中群体活动在已有 manifold 上再组织的思路一致。参考 Perich et al., 2018 |
| 抑制性竞争与归一化 | WIE, WEI23, WEI5, Comp23, Comp5 | 兴奋-抑制回路、增益控制和竞争性归一化 | 抑制不仅降低总活动，也会塑造选择性、竞争和群体解相关；模型把这种作用压缩成反馈抑制与 competition 参数。参考 Isaacson and Scanziani, 2011；Carandini and Heeger, 2012 |
| 层间耦合 | W523, Coupling23To5, Cue5, Base5 | L2/3 到 L5 的任务相关传播，以及深层输出相关整合 | 实验上深层输出并不独立生成，而是综合浅层输入、局部状态和外来驱动；模型用一组跨层权重近似这种传播关系，服务于“浅层异质性影响后续学习”的现象解释 |
| 后部丘脑在线驱动 | THToI, THL5Pattern, THPatternTo5, THNetworkLevel, BaselineTHFraction | 后部丘脑对抑制性竞争、深层结构化模式和在线状态表达的支持 | 这组参数用于表达后部丘脑不只是提供统一加性输入，而是可以偏置 cortical state 并更强地影响深层输出结构。相关思想可参考 thalamocortical loop 对皮层状态维持与运动模式驱动的工作：Guo et al., 2017；Sauerbrei et al., 2020 |
| eligibility trace 与学习门控 | LearnFromH23, H23Threshold, EligibilityDecay, MaxEligibilityTrace, BaseLearnRate, THPlasticityLevel | 任务相关异质性留下短时可塑性痕迹，并在合适门控下兑现成慢性学习更新 | 这组参数对应三因子学习规则：局部活动痕迹 + 全局门控 + 行为结果共同决定可塑性。eligibility trace 本身有明确理论和实验支持；这里把 THPlasticityLevel 解释为后部丘脑对“能否把当前任务状态固化为下一步学习”的门控强度。参考 Gerstner et al., 2018；Guo et al., 2017；Sauerbrei et al., 2020 |

## 3. 计算层次

脚本按四层嵌套运行：

1. 条件层：Naive、Transfer、TH inhibited
2. 个体层：每个条件下模拟多只鼠
3. Session 层：每只鼠跨多个 session 学习
4. Trial 层：每个 session 内模拟多次 trial 响应并生成 hit rate

可以概括成：

```text
Condition
  -> Mouse
    -> Session
      -> Trial population response
        -> Performance / heterogeneity
      -> update learn state
  -> aggregate per-mouse metrics
-> group summary and figure export
```

## 4. 单鼠初始化

每只鼠先随机生成一组固定的个体特征，用来制造鼠间差异和细胞群体差异。

主要包括：

1. HeteroGain：控制该鼠整体异质性强弱
2. Learn23：L2/3 学习相关模式
3. Prior23：与 Learn23 部分对齐的 L2/3 先验模式
4. WIE、WEI23、WEI5：兴奋到抑制、抑制到 L2/3、抑制到 L5 的连接权重
5. W523：L2/3 到 L5 的跨层耦合
6. Learn5、Prior5：L5 学习模式与先验模式
7. THToI：TH 到抑制群体的驱动强度
8. THL5Pattern：TH 通过抑制网络在 L5 上形成的结构化模式
9. Readout：把 L5 群体活动映射到行为输出的读出权重

其中最关键的设计是：

1. L2/3 的学习模式和 prior 不是独立的，而是部分对齐
2. TH 不仅仅提供一个统一偏置，还会通过 THL5Pattern 在 L5 中形成结构化影响
3. 鼠间差异主要通过 HeteroGain 放大到多个子模块

## 5. 单个 session 的响应生成

每个 session 的计算分三步：

### 第一步：生成 L2/3 活动

L2/3 的预激活由三项组成：

1. 当前学习状态乘以 Learn23
2. 迁移先验乘以 Prior23
3. trial-by-trial 噪声

然后先取正值得到 excitatory drive，再送入抑制群体。

### 第二步：生成抑制群体活动

抑制群体输入包括：

1. 来自 L2/3 兴奋输入的汇总驱动
2. THNetworkLevel 调制下的 THToI 输入
3. 抑制群体自身噪声

这一步代表的是 TH 影响抑制性网络竞争强度，而不是直接给行为加一个常数项。

### 第三步：生成 L5 活动

L5 的预激活现在分为 cue 和 baseline 两类条件分别计算。cue 条件下主要由以下几项共同决定：

1. L2/3 到 L5 的跨层输入
2. 线索相关模式 Cue5
3. 当前学习状态乘以 Learn5
4. 迁移先验乘以 Prior5
5. THNetworkLevel 调制下的 THL5Pattern
6. trial-by-trial 噪声

baseline 条件下只保留较弱的基础驱动、较弱的 TH 结构项和噪声。两类条件都再减去来自抑制群体的竞争项，并经过 tanh 压缩得到最终 L5 响应。

这个结构的意图是：

1. Transfer 的首场优势主要来自 prior
2. TH 对网络在线表达的影响主要通过抑制竞争和深层模式塑形体现
3. L5 异质性可以随着 TH 抑制而下降
4. TH inhibited 组的首场表现可以保留大部分 transfer 优势，但后续学习兑现仍会因为 TH 塑性门控降低而受限

## 6. 从群体响应到行为输出

行为输出不是直接由 L2/3 决定，而是通过 L5 的 cue-baseline 判别读出实现：

1. 分别计算 cue trial 和 baseline trial 的 L5 群体读出
2. 用 cue 读出去减 baseline 读出，得到判别变量
3. 通过 logistic 函数映射成每个 trial 的命中概率
4. 对所有 trial 取平均得到该 session 的 performance

因此，模型中的行为改进有两个来源：

1. 首场由 prior 带来的更好 cue-baseline 可分性
2. 随学习状态增长而提升的 cue-baseline 群体分离性

## 7. 响应异质性的定义

每个 session 都会更新一次“截至当前增长段的累计异质性”，但最终用于相关性的不是单 session 值，而是增长段整体平均后的细胞间异质性。

计算方式是：

1. 对每个 session，先分别计算每个细胞在 cue 和 baseline 下的 session mean
2. 用 cue 减 baseline，得到该 session 的细胞调制量
3. 找到学习过程中首个达到 100% 的会话，并排除该会话及其之后的所有会话
4. 对剩余增长段内的细胞调制量按细胞跨会话求平均
5. 只保留落在 [-1, 1] 范围内的细胞均值
6. 对这些细胞均值计算标准差

这相当于用增长段整段平均后的任务相关细胞离散程度，来表示响应异质性，而不是单回合或单 session 的离散程度。

## 8. 学习更新规则

每个 session 结束后，会根据当前表现和异质性更新 learn state。

学习更新被约束为一个可解释的三因子框架，并显式加入了文献中常见的 eligibility trace：

1. eligibility increment：任务相关的 L2/3 异质性超过阈值后的有效部分
2. eligibility trace：上一 session 留下并按固定时间常数衰减的可塑性痕迹
3. modulatory gate：THPlasticityLevel 提供的塑性门控
4. reward-like signal：当前行为成功率提供的强化信号

其中，prior 不再作为独立 boost 加到学习驱动里，而是只通过两种方式影响学习：

1. 在表征层改善 cue 相关群体模式
2. 以 metaplasticity-like 方式下调 L2/3 进入可塑状态所需的 eligibility 阈值

于是每个 session 结束后的学习更新是：先由该 session 当下的 L2/3 任务相关异质性产生 eligibility increment，再与上一时刻遗留的 eligibility trace 相加并衰减，最后由 TH gate 和 reward-like signal 将这段 trace 兑现成 learn state 的增加。

模型把 TH 相关作用显式拆成两条通道：

1. THNetworkLevel：决定当前 session 中抑制竞争和 L5 结构化模式能表达多少
2. THPlasticityLevel：决定当前 session 产生的 eligibility trace 有多少能被兑现成下一步学习

这样做的动机是表达一个与当前数据一致、也与 thalamocortical 状态门控文献一致的现象：急性后部丘脑抑制更容易削弱后续学习增益，而不一定完全抹掉已经形成的迁移先验表达。这里的 THPlasticityLevel 不是声称后部丘脑直接等同于突触可塑性分子开关，而是把“后部丘脑对任务状态维持、上下文选择和后续学习更新的必要性”压缩成一个可计算门控量。

最终学习更新满足几个直觉：

1. 任务相关异质性越高，累计出的 eligibility trace 越大，后续学习越容易推进
2. TH 越完整，已有 eligibility trace 越容易被兑现成学习更新
3. 有先验时，网络更容易越过可塑性阈值，但先验本身不再作为独立学习因子显式相加
4. TH 被抑制后，首场表现不一定完全消失，但后续学习增益会明显变弱

## 9. 单鼠统计量

每只鼠最终输出四个核心指标：

1. Slope：排除达到 100% 的会话及之后，只用剩余增长段 performance 拟合得到的学习斜率
2. MeanDeltaHit：相邻 session performance 差值的平均
3. MeanH23：增长段整段平均后的 L2/3 细胞间异质性
4. MeanH5：增长段整段平均后的 L5 细胞间异质性

如果某只鼠在第 1 个会话就达到 100%，则该鼠被排除出 slope-heterogeneity 相关性统计。

## 10. 群体聚合与图形输出

脚本在所有条件和所有鼠完成后，会聚合出：

1. 各条件的学习曲线
2. 各条件的累计 L2/3 异质性时间程
3. L2/3 异质性与学习斜率的相关关系
4. 各条件的 L5 异质性条带散点图
5. 各条件的 Mean Delta Hit 条带散点图
6. Transfer 与 TH inhibited 的代表性 process-mean L5 响应分布对比

此外还会：

1. 计算 L2/3 heterogeneity 与 slope 的 Spearman 相关
2. 计算 L5 heterogeneity 与 slope 的 Spearman 相关
3. 把结果保存到 base workspace 中的 THInhibitoryHeterogeneityModel
4. 把 SVG 图导出到当月网络目录

## 11. 这套模型当前表达的机制解释

用一句话概括，这个模型表达的是：

Transfer 给系统一个更好的初始 cue prior，TH 通过抑制性网络和深层模式塑形维持任务相关响应异质性，而更高的 L2/3 异质性又会给后续学习提供更强的更新驱动。

因此，这个模型给出的机制解释是：

1. Transfer 会抬高首场表现
2. TH inhibited 不会完全抹掉迁移优势，因为 prior 的表达主要依赖已有表征，而不是完全依赖当下的 TH 塑性门控
3. TH inhibited 会削弱后续学习，因为 THPlasticityLevel 更低，eligibility trace 更难兑现成 learn state 增加
4. TH inhibited 会降低 L5 异质性，因为 THNetworkLevel 下降后，抑制竞争和 TH 相关深层结构化模式都变弱
5. 行为表现来自 cue 与 baseline 的可分性，而不是单侧正活动的绝对值

从建模原则上，这个模型避免加入缺乏可解释性的条件额外 boost。保留在学习规则中的因子，均对应到可解释的神经科学概念：任务相关 eligibility increment、带衰减的 eligibility trace、TH 的网络表达通道、TH 的塑性门控通道、成功强化，以及先验导致的 metaplastic threshold shift。

## 12. 局限

这仍然是一个概念验证模型，不应直接等同于真实生理回路。

当前简化主要包括：

1. 没有显式建模具体突触可塑性规则
2. 没有把感觉输入、决策变量和动作输出拆成独立模块
3. TH 的作用虽然已拆成网络表达和塑性门控两条通道，但仍然是低维参数化，而不是完整的递质动力学模型
4. 响应异质性是从生成响应中读出的统计量，而不是单独被优化的状态变量

但它的优势是结构清晰、可调、可直接对接现在的 Figure 3 现象解释。

## 13. 参考文献

1. Isaacson JS, Scanziani M. How inhibition shapes cortical activity. Neuron 72, 231-243 (2011).
2. Carandini M, Heeger DJ. Normalization as a canonical neural computation. Nature Reviews Neuroscience 13, 51-62 (2012).
3. Cohen MR, Kohn A. Measuring and interpreting neuronal correlations. Nature Neuroscience 14, 811-819 (2011).
4. Gerstner W et al. Eligibility traces and plasticity on behavioral time scales: experimental support of neoHebbian three-factor learning rules. Trends in Neurosciences 41, 878-892 (2018).
5. Guo ZV et al. Maintenance of persistent activity in a frontal thalamocortical loop. Nature 545, 181-186 (2017).
6. Sauerbrei BA et al. Cortical pattern generation during dexterous movement is input-driven by motor thalamus. Nature 577, 386-391 (2020).
7. Perich MG, Gallego JA, Miller LE. A neural population mechanism for rapid learning. Neuron 100, 964-976 (2018).
8. Gallego JA et al. Long-term stability of cortical population dynamics underlying consistent behavior. Nature Neuroscience 23, 260-270 (2020).
9. Bernardi S et al. The geometry of abstraction in hippocampus and prefrontal cortex. Cell 183, 954-967 (2020).
10. Wakhloo AJ, Slatton W, Chung S. Neural population geometry and optimal coding of tasks with shared latent structure. Nature Neuroscience (2026).