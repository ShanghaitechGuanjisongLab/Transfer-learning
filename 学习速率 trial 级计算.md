# 学习速率（sigmoid slope）：trial 级计算

> 整理自 2026-11-11 会话，范围：从"惩罚版是什么"到"逐 trial 拟合的参考文献"。
> 所有数字均为本机实测（MATLAB R2026a，`Transferlearning.prj`）。

---

## 0. 一句话结论

**决定"Naive vs 12 h 斜率显著与否"的是「用逐 trial 数据」而不是「用不用惩罚项」。**
换成纯 trial 级极大似然（去掉全部惩罚）后，组间差异依旧显著（p = 0.016），12 h 队列中斜率与响应异质性的相关也完全保持（ρ = 0.905，p = 0.0046）。

---

## 1. 三种斜率口径

| 口径 | 数据单位 | 目标函数 | 实现 |
|---|---|---|---|
| 会话级 LS | 每个 session 的**命中率**（1 个数） | $\sum_i (y_i-\hat p_i)^2$ | `DelayComparison.FitSigmoidPerMouse` |
| trial 惩罚版 | 每个 **trial** 的 0/1 | $-\big[\ell+\tfrac12\log\det I\big]+\tfrac12(\log k/2)^2$ | `TransferLearning.FitPenalizedSigmoid` |
| trial MLE（无惩罚） | 每个 **trial** 的 0/1 | $-\ell$ | 本次会话新增（脚本内 `iFitMLE`） |

共同的模型（`FixLowerZero=true`，下限固定 0、上限固定 1）：

$$p(x)=\frac{1}{1+e^{-k(x-m)}},\qquad k>0$$

- $x$：会话序号（block），按 `DateTime` 排序后 1…n
- $k$：log-odds 斜率 / block；概率空间最陡处斜率 $=k/4$
- $m$：中点

---

## 2. 惩罚版到底做了什么

`+TransferLearning/FitPenalizedSigmoid.m` 的目标函数：

$$\text{obj}(\theta)=-\Big[\underbrace{\ell(\theta)}_{\text{二项对数似然}}+\underbrace{\tfrac12\log\det I(\theta)}_{\text{Firth/Jeffreys}}\Big]+\underbrace{\tfrac12\Big(\tfrac{\log k}{2}\Big)^2}_{\text{弱先验}\ \log k\sim N(0,2^2)}$$

1. **二项对数似然**：每个 trial 参与，不是每个 session 一个点。
2. **Jeffreys / Firth 项** $\tfrac12\log\det I$：$I$ 由 sigmoid 解析导数算出的 Fisher 信息；一阶等价于给每个观测加半个"虚拟样本"，防止完全分离时 MLE 发散。代码实现为 `sum(log(diag(chol(I))))`。
3. **弱先验**：单靠 Jeffreys 项仍可能出现"无限阶梯"解，故再加 $\log k\sim N(0,2^2)$。

其他设定：

| 项 | 取值/规则 |
|---|---|
| 多起点网格 | `lowerStarts` 3 × `slopeStarts` 4（0.2/0.8/2/6）× `midpointStarts` ≤3（median/min/max $x$）→ 最多 36；`FixLowerZero` 时降到 12 |
| 优化器 | `fminsearch`（Nelder–Mead，无导数、局部） |
| 触界判定 | $k\ge 20$ → `AtSlopeBoundary=true` → `FitEligible=false`，从组间比较中剔除 |
| 两块曲线 | 强制 `FixLowerZero`（3 参数在 2 点上不可辨识） |
| 组间检验 | $\log k$ 上的**鼠级标签置换**；`nchoosek(n,nA) ≤ 5000` 时精确枚举，否则随机 5000 次；配对比较做 Holm 校正 |
| 标准误 | $\mathrm{inv}(I)$ 的对角（Laplace 近似） |

---

## 3. 多起点是不是"搜索"而不是确定性拟合？

**是确定性拟合。** 没有随机数；给定同一数据与同一初值网格，结果逐位可复现。它是"穷举起点 + 局部精修 + 取目标最小者"，属于确定性的多起点策略，而不是模拟退火/遗传算法这类随机搜索。缺点：只保证在给定网格下找到最好的局部解，**不保证全局最优**。

### 实测：8 个差异很大的初值全部收敛到同一解

| 鼠 | 数据量 | 8 个初值的收敛结果 | 目标值 |
|---|---|---|---|
| `yqn2005` | 6 block / 150 trial | 全部 $k=1.302$，$m=2.57$ | 61.790（完全一致） |
| `yqn1014` | 3 block / 90 trial | 全部 $k=2.064$，$m=0.27$ | 17.207（完全一致） |

对这批数据，多起点是保险措施，而非必需。表面非凸的来源是 $k$–$m$ 的"脊"（把 $k$ 调大同时把 $m$ 移出数据区间，预测几乎不变，`yqn1014` 拟合出 $m=0.27$ 而数据区间是 1–3）。

---

## 4. 惩罚项消融：两个惩罚都不是必需的

队列取自 `TransferLearning.BuildIntervalBehaviorCurves`（Naive 20 / 12 h 22），`FixLowerZero=true`，只改目标函数：

| 目标函数 | Naive 中位 | 12 h 中位 | Spearman/秩和 p | Naive mean / max | 12 h mean / max |
|---|---|---|---|---|---|
| **full**（Jeffreys + 弱先验） | 1.09 | 1.86 | **0.0114** | 1.16 / 3.4 | 1.77 / 3.3 |
| noJeff（只留弱先验） | 1.05 | 2.08 | **0.0162** | 1.29 / — | 2.26 / — |
| noPrior（只留 Jeffreys） | 1.10 | 1.90 | **0.0098** | 1.17 / — | 1.80 / — |
| **mle（两个都去掉）** | 1.05 | 2.14 | **0.0162** | 2.38 / 25.8 | 6.24 / 26.9 |
| 对照：会话级 LS | 1.13 | 2.01 | **0.195** | 2.12 / 10.8 | 3.72 / 13.9 |

读法：

1. **四种 trial 级设定全部显著**（p = 0.0098–0.0162），中位数几乎不动（1.05–1.13 vs 1.86–2.14）→ 显著性来自数据本身。
2. **惩罚项只压上尾与均值**（MLE 均值 2.38 / 6.24、最大 25.8 / 26.9 → full 1.16 / 1.77、最大 3.4 / 3.3），不改变结论。
3. **会话级 LS 才是那唯一不显著的**（p = 0.195）。

### 为什么 trial 级更有功效

| 估计 | Naive IQR | 12 h IQR |
|---|---|---|
| 会话级 LS | 0.78 – 2.43 | 0.93 – 3.49 |
| trial MLE | 0.66 – 1.51 | 1.01 – 3.56 |
| trial full | 0.68 – 1.48 | 1.02 – 2.20 |

LS 把每个 session 均值当**等方差**连续观测：接近天花板（0.9–1.0）时真实二项方差极小，LS 仍给同样权重；同时它会对"两三个 block 冲到 1.0"的曲线给出极端 $k$（最大 10.8 / 13.9），把组内分布拉宽、与另一组高度重叠。trial 级似然按二项方差加权，自动降低饱和区段的杠杆。

---

## 5. 斜率（各口径）与响应异质性的相关

异质性口径：`TransferLearning.Metrics.ResponseHeterogeneity`（cue+1 s 跨细胞 SD，$|z|\le1$，细胞数 ≥3），会话先做 pre-ceiling 筛选（剔除首次 100% 及其后、且至少 2 个未学满会话），两层按有效细胞数加权合并；相关用 Spearman。

### 12 h 队列（`AudioLightBaseline`，n = 8）

| 斜率口径 | 斜率范围 | Spearman ρ | p |
|---|---|---|---|
| 会话级 LS | 0.77 – 3.50 | +0.905 | 0.0046 |
| **trial MLE（无惩罚）** | 0.79 – 3.56 | **+0.905** | **0.0046** |
| trial 惩罚版 | 0.78 – 3.13 | +0.881 | 0.0072 |

⇒ **结论稳**。该队列没有出现 LS 式极端解（最大斜率仅 3.5），所以惩罚项无事可做。

### Naive 队列

| 队列 | n | LS | trial MLE | trial 惩罚 |
|---|---|---|---|---|
| `LightAudioBaseline` | 5 | +0.500 (0.45) | +0.800 (0.13) | +0.800 (0.13) |
| `LAInterspersed` | 8 | +0.619 (0.115) | **+0.071 (0.88)** | +0.071 (0.88) |
| 两者合并 | 13 | +0.516 (0.074) | **+0.203 (0.51)** | +0.203 (0.51) |

`LAInterspersed` 最能说明问题：LS 斜率范围 0.25–**16.29**，trial 级后变成 0.15–**1.38**，相关从 ρ=0.62 掉到 0.07。**不是惩罚造成的，是 trial 级似然本身消除了那个阶跃解。**

⇒ "学得越快 ↔ 跨细胞响应越不一致"这个正相关**只在 12 h 队列成立**；Naive 组任何口径都 n.s.。

---

## 6. 组间 slope 的队列敏感性（会话级 LS）

| 比较 | n | mean k | p |
|---|---|---|---|
| 成像 Naive（LAB+LAI）vs 成像 12 h（ALB） | 14 vs 11 | 4.04 vs 4.92 | 0.681 |
| 纯行为 Naive（LAPB）vs 纯行为 12 h（ALPB） | 13 vs 11 | 1.16 vs 2.53 | 0.354 |
| 成像 Naive vs 12 h 全部 | 14 vs 22 | 4.04 vs 3.72 | 0.783 |
| Naive 全部 vs 成像 12 h | 27 vs 11 | 2.65 vs 4.92 | 0.088 |
| Naive 全部 vs 12 h 全部 | 27 vs 22 | 2.65 vs 3.72 | 0.291 |

按来源拆解（LS）：

| 组 | 来源 | n | mean k |
|---|---|---|---|
| Naive | LightAudioBaseline（成像） | 6 | 3.64 |
| Naive | LAInterspersed（成像） | 8 | 4.34 |
| Naive | **LAPureBehavior（纯行为）** | 13 | **1.16** |
| 12 h | AudioLightBaseline（成像） | 11 | 4.92 |
| 12 h | **ALPureBehavior（纯行为）** | 11 | **2.53** |

⇒ 纯行为鼠在两组都学得更慢；混不混队列会显著改变结论，必须先定死口径。

---

## 7. 参考文献（可核实）

| 用途 | 文献 |
|---|---|
| 逐 trial 拟合学习曲线（核心） | Gallistel, Fairhurst & Balsam (2004) *PNAS* 101:13124–13131 |
| 二元观测的 sigmoid 极大似然拟合 | Wichmann & Hill (2001) *Percept Psychophys* 63:1293–1313 |
| 逐 trial 状态空间学习模型 | Smith et al. (2004) *J Neurosci* 24:447–461 |
| 完全分离的惩罚修正 | Firth (1993) *Biometrika* 80:27–38；Heinze & Schemper (2002) *Stat Med* 21:2409–2419 |
| 逐 trial 计算模型分析（综述） | Daw (2011) *Attention and Performance XXIII*, pp. 3–38 |

```bibtex
@article{gallistel2004learning,
  author  = {Gallistel, C. R. and Fairhurst, S. and Balsam, P.},
  title   = {The learning curve: implications of a quantitative analysis},
  journal = {Proceedings of the National Academy of Sciences},
  year    = {2004}, volume = {101}, number = {36}, pages = {13124--13131}
}
@article{wichmann2001psychometric,
  author  = {Wichmann, F. A. and Hill, N. J.},
  title   = {The psychometric function: {I}. Fitting, sampling, and goodness of fit},
  journal = {Perception \& Psychophysics},
  year    = {2001}, volume = {63}, number = {8}, pages = {1293--1313}
}
@article{smith2004dynamic,
  author  = {Smith, A. C. and Frank, L. M. and Wirth, S. and Yanike, M. and Hu, D.
             and Kubota, Y. and Graybiel, A. M. and Suzuki, W. A. and Brown, E. N.},
  title   = {Dynamic analysis of learning in behavioral experiments},
  journal = {Journal of Neuroscience},
  year    = {2004}, volume = {24}, number = {2}, pages = {447--461}
}
@article{firth1993bias,
  author  = {Firth, D.},
  title   = {Bias reduction of maximum likelihood estimates},
  journal = {Biometrika},
  year    = {1993}, volume = {80}, number = {1}, pages = {27--38}
}
@article{heinze2002solution,
  author  = {Heinze, G. and Schemper, M.},
  title   = {A solution to the problem of separation in logistic regression},
  journal = {Statistics in Medicine},
  year    = {2002}, volume = {21}, number = {16}, pages = {2409--2419}
}
```

> `refs.bib` 现有 21 条均为潜动力学/神经流形方向，上述 5 条尚未收录。
> 代码注释中出现的 `Deliano et al. (2016)`、`Levi et al. (2024)` 无法核实出处，建议替换或删除。

---

## 8. 建议的方法学写法

1. 主分析：**逐 trial 二项似然**，下限固定 0、上限固定 1，斜率与中点自由，极大似然；多起点（k 的 4 个初值 × m 的 3 个初值）取最优。
   > 引 Gallistel 2004（逐 trial 而非分块平均）+ Wichmann & Hill 2001（sigmoid 的 ML 拟合）。
2. 护栏：拟合斜率 $k>20$（一个 block 内完成 0→1）判为不可辨识，从组间比较中剔除，并报告剔除只数。
   > 引 Heinze & Schemper 2002。
3. 敏感性分析：给出"去惩罚（纯 MLE）"与"会话级 LS"两行结果，说明
   - 去惩罚：p = 0.016，结论不变；
   - 会话级 LS：p = 0.195，因为等方差假设使饱和区段杠杆过大、并产生 k 达 10–16 的阶跃解。
4. 相关性：12 h 队列可写 ρ ≈ 0.88–0.91（三种口径一致）；Naive 组写 n.s.，不要挑口径。
5. 队列口径必须在图注写明（成像 vs 含纯行为），并注意 `CohortBlocks("UndelayedImaging*")` 名称里虽含 "Imaging"，实际**包含纯行为鼠**；真正的纯成像队列是 `UndelayedRecording*`。

---

## 9. 脚本清单

| 脚本 | 作用 |
|---|---|
| `+TransferLearning/FitPenalizedSigmoid.m` | 单鼠 trial 级惩罚拟合（含多起点、触界判定、标准误） |
| `+TransferLearning/ComparePenalizedSigmoidSlopes.m` | 队列级批量拟合 + log k 置换检验 + Holm |
| `+TransferLearning/CompareIntervalLearningSlopes.m` | Firth logistic 斜率（另一实现） |
| `+TransferLearning/+DelayComparison/FitSigmoidPerMouse.m` | 会话级 LS（下限可固定 0/自由） |
| `+TransferLearning/+DelayComparison/FitSigmoidGroup.m` | 单条曲线的 LS 拟合 |
| `英文图/AnalyzePenaltyAblation.m` | 惩罚项消融（full / noJeff / noPrior / MLE + LS 对照） |
| `英文图/AnalyzePenalizedSlopeVsHeterogeneity.m` | 斜率 × 响应异质性，三口径并列（LS / trial MLE / trial 惩罚） |
| `英文图/Fig1C_PenalizedSigmoidSlopeHistogram.m` | 斜率分布直方图（惩罚版） |
| `英文图/Fig4D_SigmoidSlopeVsHeterogeneity.m` | 12 h 队列斜率 vs 异质性散点（会话级 LS） |

---

## 10. 待办 / 未决

- [ ] 主分析是否正式切到 **trial MLE**（去掉两个惩罚项）—— 结论不变，但方法学更简单
- [ ] `Fig4D` 是否按 trial MLE 重出（斜率范围 0.79–3.56，图形基本不变）
- [ ] `Fig1_MetricBars_ThreeGroups.m` / `Fig1_MetricBars_Pairwise.m` 的 slope 子图是否换成 trial 级
- [ ] Naive 组是否剔除 2025 批异常鼠（`yqn1013` / `yqn1014`；后者仅 2 个点、首点 0.87，LS 下 k=10.8 为退化解）
- [ ] 将 5 条参考文献计入 `refs.bib`
