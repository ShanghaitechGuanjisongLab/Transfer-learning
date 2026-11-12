**三种学习速度与响应异质性统计汇总**

计算日期：2026-11-08。统计脚本：[AnalyzeLearningSpeedMetricsComplete.m](AnalyzeLearningSpeedMetricsComplete.m)。

## 分析口径

- **队列**：Naive = LightAudioBaseline + LAPureBehavior + LAInterspersed；12 h = AudioLightBaseline + ALPureBehavior；7 d = Vacation7；TH = THInhibit + PO 纯行为；cFos 使用其行为数据。行为分析均保留完整原始光水学习曲线，不再按首次命中率 100% 截断。
- **BlocksTo50**：达到 50% 命中率所需的 block 数，相邻 block 间线性插值；数值越小表示越快达到标准。
- **Sigmoid slope**：下限固定 0、上限固定 1，斜率和中点自由；至少两个 block 且命中率有变化才可拟合。数值越大表示曲线越陡。
- **LearningSpeed**：
  $$LS=\frac{\sum_{i=2}^{n}(y_i-y_1)}{\sum_{i=1}^{n}(1-y_i)}。$$
  每组比较取两组最大 block 数，不足部分以该鼠历史最高命中率向右补齐；数值越大表示相对起点的增益面积越大。
- **响应异质性**：仅成像鼠。逐细胞逐会话取 cue +1 s 的 z 分数中位数，跨会话取均值，仅保留 $|z|\le 1$ 的细胞，计算跨细胞标准差；每层至少三个有效细胞。合并层按两层有效细胞数加权。
- **组间差异**：双侧 Mann–Whitney 秩和检验。**相关**：Spearman 相关。
- 下述 p 值均为**未进行多重比较校正的原始 p 值**；以 $p<0.05$ 为显著。cFos 无成像数据，不纳入异质性分析。

## 各组学习速度汇总

| 指标 | 组别 | n | 均值 ± SEM | 中位数 |
|---|---|---:|---:|---:|
| BlocksTo50 | Naive | 27 | 3.856 ± 0.529 | 2.625 |
| BlocksTo50 | 12 h | 22 | 1.396 ± 0.179 | 1.000 |
| BlocksTo50 | 7 d | 6 | 2.372 ± 0.444 | 2.212 |
| BlocksTo50 | TH | 12 | 2.347 ± 0.757 | 1.479 |
| BlocksTo50 | cFos 对照 | 9 | 2.617 ± 0.588 | 1.882 |
| BlocksTo50 | cFos 抑制 | 3 | 8.667 ± 2.729 | 7.000 |
| Sigmoid slope | Naive | 27 | 2.651 ± 0.685 | 1.315 |
| Sigmoid slope | 12 h | 22 | 3.722 ± 0.947 | 2.011 |
| Sigmoid slope | 7 d | 6 | 2.018 ± 0.483 | 2.003 |
| Sigmoid slope | TH | 12 | 0.809 ± 0.226 | 0.527 |
| Sigmoid slope | cFos 对照 | 9 | 1.175 ± 0.324 | 0.874 |
| Sigmoid slope | cFos 抑制 | 3 | 0.353 ± 0.130 | 0.418 |
| LearningSpeed（组内最大 block 数） | Naive（17） | 27 | 5.314 ± 0.750 | 4.604 |
| LearningSpeed（组内最大 block 数） | 12 h（7） | 22 | 3.964 ± 0.374 | 4.780 |
| LearningSpeed（组内最大 block 数） | 7 d（9） | 6 | 3.987 ± 1.093 | 3.645 |
| LearningSpeed（组内最大 block 数） | TH（29） | 12 | 8.596 ± 1.970 | 7.349 |
| LearningSpeed（组内最大 block 数） | cFos 对照（9） | 9 | 2.509 ± 0.621 | 1.690 |
| LearningSpeed（组内最大 block 数） | cFos 抑制（13） | 3 | 0.636 ± 0.301 | 0.618 |

注意：LearningSpeed 的组间比较另行统一两组 block 数，不能直接用本表的组内均值解释组间差异。

## 学习速度组间差异

方向均为“前者 − 后者”。BlocksTo50 的负差值表示前者更快；另外两个指标的正差值表示前者学习速度更高。

| 指标 | 比较 | n（前/后） | 均值（前 vs 后） | 均值差 | 秩和 p | 结论 |
|---|---|---:|---:|---:|---:|---|
| BlocksTo50 | 12 h − Naive | 22 / 27 | 1.396 vs 3.856 | −2.460 | **9.45×10⁻⁵** | **12 h 显著更少 block** |
| BlocksTo50 | 12 h − 7 d | 22 / 6 | 1.396 vs 2.372 | −0.977 | **0.00448** | **12 h 显著更少 block** |
| BlocksTo50 | 12 h − TH | 22 / 12 | 1.396 vs 2.347 | −0.951 | **0.0432** | **12 h 显著更少 block** |
| BlocksTo50 | 12 h − cFos | 22 / 3 | 1.396 vs 8.667 | −7.271 | **0.00277** | **12 h 显著更少 block** |
| BlocksTo50 | cFos 对照 − cFos | 9 / 3 | 2.617 vs 8.667 | −6.050 | **0.0182** | **cFos 对照显著更少 block** |
| Sigmoid slope | 12 h − Naive | 22 / 27 | 3.722 vs 2.651 | +1.071 | 0.2913 | 不显著 |
| Sigmoid slope | 12 h − 7 d | 22 / 6 | 3.722 vs 2.018 | +1.704 | 0.8446 | 不显著 |
| Sigmoid slope | 12 h − TH | 22 / 12 | 3.722 vs 0.809 | +2.913 | **0.00295** | **12 h 显著更高** |
| Sigmoid slope | 12 h − cFos | 22 / 3 | 3.722 vs 0.353 | +3.368 | **0.0136** | **12 h 显著更高** |
| Sigmoid slope | cFos 对照 − cFos | 9 / 3 | 1.175 vs 0.353 | +0.822 | 0.1000 | 不显著 |
| LearningSpeed（共同 block 数） | 12 h − Naive（17） | 22 / 27 | 11.054 vs 5.314 | +5.741 | **5.10×10⁻⁵** | **12 h 显著更高** |
| LearningSpeed（共同 block 数） | 12 h − 7 d（9） | 22 / 6 | 5.382 vs 3.987 | +1.395 | 0.2745 | 不显著 |
| LearningSpeed（共同 block 数） | 12 h − TH（29） | 22 / 12 | 19.563 vs 8.596 | +10.967 | **0.000538** | **12 h 显著更高** |
| LearningSpeed（共同 block 数） | 12 h − cFos（13） | 22 / 3 | 8.218 vs 0.636 | +7.582 | **0.00653** | **12 h 显著更高** |
| LearningSpeed（共同 block 数） | cFos 对照 − cFos（13） | 9 / 3 | 4.037 vs 0.636 | +3.401 | 0.0636 | 不显著 |

## Sigmoid 斜率的置换检验

采用逐鼠组标签置换，统计量为两组斜率**均值差**的双侧置换检验。由于每只鼠独立拟合，置换标签不会改变其曲线，置换逐鼠斜率标签与“置换后重新拟合”在数学上等价。组合数不超过 5000 时精确枚举，否则随机置换 5000 次。

| 比较 | n（前/后） | 斜率均值（前 vs 后） | 均值差 | 置换方法 | p 值 | 结论 |
|---|---:|---:|---:|---|---:|---|
| 12 h − Naive | 22 / 27 | 3.722 vs 2.651 | +1.071 | 5000 次随机置换 | 0.3593 | 不显著 |
| 12 h − 7 d | 22 / 6 | 3.722 vs 2.018 | +1.704 | 5000 次随机置换 | 0.4605 | 不显著 |
| 12 h − TH | 22 / 12 | 3.722 vs 0.809 | +2.913 | 5000 次随机置换 | **0.0166** | **12 h 显著更高** |
| 12 h − cFos | 22 / 3 | 3.722 vs 0.353 | +3.368 | 精确枚举全部标签分配 | 0.0713 | 不显著 |
| cFos 对照 − cFos | 9 / 3 | 1.175 vs 0.353 | +0.822 | 精确枚举全部标签分配 | 0.1719 | 不显著 |

因此，12 h 与 TH 的 sigmoid 斜率差异在秩和和置换检验中均显著；12 h 与 cFos 的秩和检验显著，但精确置换检验不显著，应以后者的小样本精确结果为主要限制说明。

## 纯行为数据库的学习速度结果

| Sigmoid 斜率比较范围 | n（12 h / Naive） | 均值（12 h vs Naive） | 双侧秩和 p | 结论 |
|---|---:|---:|---:|---|
| 12 h 全队列（AudioLightBaseline + ALPureBehavior）vs Naive 纯行为（LAPureBehavior） | 22 / 13 | 3.722 vs 1.158 | **0.0357403** | **12 h 显著更高** |
| 两组均为纯行为：12 h（ALPureBehavior）vs Naive（LAPureBehavior） | 11 / 13 | 2.527 vs 1.158 | 0.353830 | 不显著 |

## 三种学习速度与响应异质性的 Spearman 相关

| 指标 | 组别 | 层 | n | $\rho$ | p 值 | 结论 |
|---|---|---|---:|---:|---:|---|
| BlocksTo50 | Naive | MOp2/3 | 13 | −0.770 | **0.00206** | **显著负相关** |
| BlocksTo50 | Naive | MOp5 | 10 | −0.576 | 0.0878 | 不显著 |
| BlocksTo50 | Naive | 合并 | 13 | −0.484 | 0.0936 | 不显著 |
| BlocksTo50 | 12 h | MOp2/3 | 8 | −0.024 | 0.9786 | 不显著 |
| BlocksTo50 | 12 h | MOp5 | 8 | −0.683 | 0.0750 | 不显著 |
| BlocksTo50 | 12 h | 合并 | 8 | −0.561 | 0.1610 | 不显著 |
| BlocksTo50 | 7 d | MOp2/3 | 6 | −0.429 | 0.4194 | 不显著 |
| BlocksTo50 | 7 d | MOp5 | 6 | −0.143 | 0.8028 | 不显著 |
| BlocksTo50 | 7 d | 合并 | 6 | −0.543 | 0.2972 | 不显著 |
| BlocksTo50 | TH | MOp2/3 | 5 | +0.500 | 0.4500 | 不显著 |
| BlocksTo50 | TH | MOp5 | 5 | +0.900 | 0.0833 | 不显著 |
| BlocksTo50 | TH | 合并 | 5 | +0.600 | 0.3500 | 不显著 |
| Sigmoid slope | Naive | MOp2/3 | 13 | +0.253 | 0.4043 | 不显著 |
| Sigmoid slope | Naive | MOp5 | 10 | +0.358 | 0.3128 | 不显著 |
| Sigmoid slope | Naive | 合并 | 13 | +0.516 | 0.0740 | 不显著 |
| Sigmoid slope | 12 h | MOp2/3 | 8 | +0.643 | 0.0962 | 不显著 |
| Sigmoid slope | 12 h | MOp5 | 8 | +0.738 | **0.0458** | **显著正相关** |
| Sigmoid slope | 12 h | 合并 | 8 | +0.905 | **0.00456** | **显著正相关** |
| Sigmoid slope | 7 d | MOp2/3 | 6 | +0.143 | 0.8028 | 不显著 |
| Sigmoid slope | 7 d | MOp5 | 6 | +0.314 | 0.5639 | 不显著 |
| Sigmoid slope | 7 d | 合并 | 6 | +0.486 | 0.3556 | 不显著 |
| Sigmoid slope | TH | MOp2/3 | 5 | +0.600 | 0.3500 | 不显著 |
| Sigmoid slope | TH | MOp5 | 5 | +0.600 | 0.3500 | 不显著 |
| Sigmoid slope | TH | 合并 | 5 | +0.600 | 0.3500 | 不显著 |
| LearningSpeed | Naive | MOp2/3 | 13 | +0.654 | **0.0183** | **显著正相关** |
| LearningSpeed | Naive | MOp5 | 10 | +0.673 | **0.0394** | **显著正相关** |
| LearningSpeed | Naive | 合并 | 13 | +0.434 | 0.1404 | 不显著 |
| LearningSpeed | 12 h | MOp2/3 | 8 | +0.643 | 0.0962 | 不显著 |
| LearningSpeed | 12 h | MOp5 | 8 | +0.738 | **0.0458** | **显著正相关** |
| LearningSpeed | 12 h | 合并 | 8 | +0.905 | **0.00456** | **显著正相关** |
| LearningSpeed | 7 d | MOp2/3 | 6 | +0.116 | 0.8444 | 不显著 |
| LearningSpeed | 7 d | MOp5 | 6 | +0.261 | 0.5944 | 不显著 |
| LearningSpeed | 7 d | 合并 | 6 | +0.406 | 0.4333 | 不显著 |
| LearningSpeed | TH | MOp2/3 | 5 | +0.200 | 0.7833 | 不显著 |
| LearningSpeed | TH | MOp5 | 5 | +0.300 | 0.6833 | 不显著 |
| LearningSpeed | TH | 合并 | 5 | +0.300 | 0.6833 | 不显著 |

BlocksTo50 的显著负相关表示异质性越高，达到 50% 所需 block 数越少；其余显著正相关表示异质性越高，对应学习速度越大。

## 响应异质性组间差异

方向为 12 h − 对照组；n 按“12 h 成像鼠 / 对照组成像鼠”列出。

| 比较 | 层 | n | 均值（12 h vs 对照） | 均值差 | 秩和 p | 结论 |
|---|---|---:|---:|---:|---:|---|
| 12 h − Naive | MOp2/3 | 8 / 13 | 0.311 vs 0.275 | +0.036 | 0.2616 | 不显著 |
| 12 h − Naive | MOp5 | 8 / 10 | 0.277 vs 0.199 | +0.078 | **0.00855** | **12 h 显著更高** |
| 12 h − Naive | 合并 | 8 / 13 | 0.292 vs 0.252 | +0.040 | 0.1579 | 不显著 |
| 12 h − 7 d | MOp2/3 | 8 / 6 | 0.311 vs 0.275 | +0.036 | 0.1812 | 不显著 |
| 12 h − 7 d | MOp5 | 8 / 6 | 0.277 vs 0.230 | +0.047 | 0.0593 | 不显著，12 h 偏高 |
| 12 h − 7 d | 合并 | 8 / 6 | 0.292 vs 0.247 | +0.045 | **0.0426** | **12 h 显著更高** |
| 12 h − TH | MOp2/3 | 8 / 5 | 0.311 vs 0.288 | +0.023 | 0.5237 | 不显著 |
| 12 h − TH | MOp5 | 8 / 5 | 0.277 vs 0.221 | +0.056 | **0.0295** | **12 h 显著更高** |
| 12 h − TH | 合并 | 8 / 5 | 0.292 vs 0.251 | +0.041 | 0.3543 | 不显著 |

## LearningSpeed 与面积型学习指标的文献关系

本项目的公式可写为“起点校正后的命中率曲线下面积”与“命中率距满分曲线上方面积”之比：

$$LS=\frac{\sum_{i=2}^{n}(y_i-y_1)}{\sum_{i=1}^{n}(1-y_i)}。$$

检索到支持以学习曲线面积概括学习表现的文献，但**尚未找到与本项目完全相同的面积比公式**，不能直接称该公式为既有标准算法。

1. Viering T, Loog M. *The Shape of Learning Curves: a Review*. IEEE Transactions on Pattern Analysis and Machine Intelligence, 2023. 其中 Summarizing Learning Curves 一节介绍 **area under the learning curve (AULC)**：对若干训练规模处的表现取平均，将曲线概括为一个数；同时提醒单一面积指标不能区分交叉的学习曲线。[全文](https://arxiv.org/abs/2103.10948)
2. Settles B, Craven M. *An Analysis of Active Learning Strategies for Sequence Labeling Tasks*. EMNLP 2008. 该综述所列文献中，AULC 被用于比较不同主动学习策略的学习表现，支持“用曲线面积作为学习过程概括指标”的一般思路。[ACL Anthology](https://aclanthology.org/D08-1112/)
3. 该综述引用的早期工作 Ghiselli EE. *A comparison of methods of scoring maze and discrimination learning*. Journal of General Psychology, 1937，说明以曲线面积评价学习表现有较长历史；但其具体任务与公式和本项目不同。[书目信息由上述综述参考文献列出](https://arxiv.org/html/2103.10948)

因此，更稳妥的表述是：**LearningSpeed 是本项目自定义的、基线校正的“曲线下/上面积比”指标，与 AULC 等面积型学习表现指标在思想上相近，但不能直接援引上述文献证明该具体公式已被使用或验证。**

## 结果使用注意

- 三种指标捕捉的内容不同：BlocksTo50 是阈值时间，Sigmoid slope 是拟合曲线陡峭程度，LearningSpeed 同时受起点、上限、曲线长度和补全规则影响，不能相互替代。
- 组间 LearningSpeed 的比较随共同 block 数变化；该窗口应视为分析口径的一部分。
- TH 与 cFos 的部分分析样本量较小，尤其 cFos 抑制组仅 3 只；精确置换检验不显著的结果不应写成“已证明无差异”。
- 本报告包含大量未校正检验。若用于论文主结论，建议预先限定主要指标和主要比较，再对次要结果标注探索性分析。

**Naive 混合刺激 block 敏感性分析（2026-11-11）**

主分析的 Naive 仍包含 LAB 6 只、LAI 8 只、LAPureBehavior 13 只，共 27 只；没有排除全部成像鼠。此前仅 Naive 纯行为的 p=0.0357 是另外一种队列比较，不能作为主队列结果。

审计发现，LAB 已纳入的 48 个光水 block 中有 4 个混有其他刺激，LAI 的 69 个中有 23 个混合 block；LAB 另有 2 个 MustWarn block。这些 block 的命中率原本只使用 LightWater trial，其他刺激并未直接参与命中率均值，但混合训练背景可能影响学习过程。

使用[敏感性分析脚本](AnalyzeNaiveSigmoidBlockSensitivity.m)，按实际刺激构成和既有质量标记定义以下规则，不依据斜率或 p 值挑选排除对象。12 h 保持全队列 22 只及斜率均值 3.721601 不变；只删除 Naive 中符合规则的 block，重算剩余光水 trial 的会话命中率后连续编号，保持完整学习曲线的固定 0/1 上下限 sigmoid 拟合。

| Naive block 排除规则 | 删除 block 数 | n（12 h / Naive） | Naive 斜率均值 ± SEM | 差值（12 h − Naive） | 双侧秩和 p | 结论 |
|---|---:|---:|---:|---:|---:|---|
| 原始纳入规则 | 0 | 22 / 27 | 2.650679 ± 0.684809 | +1.070922 | 0.29126823 | 不显著 |
| 所有混刺激 block | 27 | 22 / 27 | 3.096346 ± 0.762298 | +0.625255 | 0.51352556 | 不显著 |
| 仅 MustWarn block | 2 | 22 / 27 | 2.648375 ± 0.684916 | +1.073226 | 0.28217539 | 不显著 |
| 混刺激和 MustWarn block | 29 | 22 / 27 | 3.094042 ± 0.762446 | +0.627559 | 0.50065390 | 不显著 |
| 仅 AudioWater 混入及 MustWarn block | 16 | 22 / 27 | 2.771133 ± 0.691741 | +0.950468 | 0.45095922 | 不显著 |

所有规则均保留 27 只 Naive 鼠。按这些客观规则清洗，没有使 12 h 与 Naive 的 sigmoid 斜率差异达到显著；剔除混刺激 block 反而使 Naive 斜率升高，缩小两组均值差。成像质量警告未必意味着行为记录无效，删除早期 block 后重新编号也会改变曲线起点；因此这些结果属于多规则探索性敏感性分析，不自动替代主分析，也不应按显著性选择清洗规则。
