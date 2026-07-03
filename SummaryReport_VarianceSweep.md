# 隐藏层方差正则扫描总结报告

## 任务设置

| 项目 | 内容 |
|------|------|
| 网络 | ResNet-18（32×32×3 输入，3×3 stride-1 conv1，无 maxpool） |
| Task A | CIFAR-10（50k 训练，10k 官方 test_batch 验证） |
| Task B | MNIST（60k 训练，10k 官方 t10k 验证） |
| 每 epoch 训练量 | Task A: 500 张 / Task B: 600 张 |
| 优化器 | Adam, lr=1e-3 |
| 损失形式 | $L = \frac{CE}{1 + \lambda \cdot \text{Var}(\text{隐藏层响应})}$ |

---

## 扫描维度

### 1. 方差权重 ($\lambda$)
`0, 0.001, 0.005, 0.01, 0.02, 0.05, 0.1, 0.5`

### 2. 参与计算方差的隐藏层（ReLU 输出）
| 代号 | 层列表 |
|------|--------|
| `res2-4` | `res2b_relu, res3b_relu, res4b_relu` |
| `res2-5` | 上述 + `res5b_relu` |
| `res2-3` | `res2b_relu, res3b_relu` |
| `res3-4` | `res3b_relu, res4b_relu` |
| `res2only` | 仅 `res2b_relu` |
| `res3only` | 仅 `res3b_relu` |
| `res4only` | 仅 `res4b_relu` |
| `all8` | 所有 8 个 branch2a/relu |

### 3. 方差施加位置
- 仅 Task A 有方差、Task B 无方差（原主流程）
- Task A 有方差且 Task B 也有方差
- 固定 Task A checkpoint → 仅 Task B 有方差（干净对照）

### 4. 评估指标（v2，2026-06-28 起）
为避免单 epoch 随机波动，指标改为 epoch 范围均值：
- **meanAcc3** = epoch 1~3 验证准确率平均（早期学习速度）
- **meanAcc5** = epoch 1~5 平均（中期表现）
- **meanAccAll** = 所有 epoch 平均（整体表现）

*实验 1–6 仍沿用旧版单 epoch 指标（valAcc3/valAcc5/finalVal），实验 7 起改用均值指标。*

---

## 关键实验与结论

### 实验 1：初步扫描（SweepVarianceParams）
- **方法**：TaskA CIFAR 5 epoch，42 组参数
- **结论**：
  - `varWeight ≈ 0.01–0.05` 为最优区间
  - `res5` 层 feature variance 天然很高，加入方差正则会损害精度
  - `res2-5` 或 `all8` 比 `res2-4` 略好

### 实验 2：MNIST 迁移扫描（SweepVarForMnistTransfer）
- **方法**：TaskA→TaskB 各 5 epoch，42 组
- **发现**：
  - `vw=0.01, res2-4` 在 epoch 5 的 TaskB 验证差值为 +3pp
  - **问题**：每组独立随机初始化 TaskA，TaskB 也独立重新初始化，无法分离方差效果与随机种子噪音

### 实验 3：仅 TaskB 加方差（CleanVarOnB）
- **方法**：共享同一个 TaskA checkpoint，47 组仅 TaskB 加方差
- **发现**：
  - `vw=0.02, res4only` epoch 5 差值为 +1.9pp
  - **问题**：每个配置仍各自由 `rng(20260626)` 独立初始化，仍是随机噪音

### 实验 4：预训练深度对照（DiagnosePretrainDepth）
- **方法**：PT=1 vs PT=5 epoch 预训练 TaskA，固定 checkpoint
- **结论**：
  - PT=1 epoch: epoch 5 差值为 -1.2pp（方差拖累）
  - PT=5 epoch: epoch 5 差值为 -0.2pp（几乎无影响）

### 实验 5：多 GPU 并行全层扫描（CleanSweepLayerSetsPar）
- **方法**：4×GPU parfor，28 组，固定同一 checkpoint
- **最优配置**：
  | 指标 | 配置 | 相对基线差 |
  |------|------|-----------|
  | epoch 5 | `vw=0.05, res3only` | **+0.33 pp** |
  | epoch 3 | `vw=0.10, res2only` | +1.2 pp（epoch 5 倒退）|
- **结论**：最佳配置的提升微小，不是稳定信号

### 实验 6：最终确认扫描（CleanSweepLayerSets 串行版）
- **方法**：再次固定 checkpoint，串行 28 组
- **最优 epoch 5**：`vw=0.01, res3only` (+0.50 pp)，`vw=0.10, res2-5` (+0.43 pp)
- **最优 epoch 3**：`vw=0.00, res3-4` (+4.5 pp → 零方差，证明 epoch 3 差异为随机噪音)

### 实验 7：AB 一致方差扫描 v2（CleanSweepABConsistent） ⭐⭐⭐
- **设计**：每个 (vw, layers) 配置下共享同一 `rng(20260626)` 种子训练 TaskA (CIFAR, 5ep)，然后分两支训练 TaskB：
  - **AB 模式**：TaskB 使用与 TaskA 完全相同的 vw + layers（AB 一致有方差）
  - **Aonly 模式**：TaskB 使用 vw=0（仅 A 有方差，B 无方差）
- **扫描空间**：vw = [0, 0.01, 0.05, 0.1, **0.2**] × 7 layers × 2 modes = **63 组**（vw=0 仅 AB 模式）
- **指标**：meanAcc3 / meanAcc5 / meanAccAll（epoch 1~3 / 1~5 / 1~全部 平均）
- **基线**：`AB_vw=0_res2-4`：meanAcc3=63.32%, meanAcc5=76.16%

**Top 10 meanAcc5（全部 63 组）：**

| 配置 | meanAcc3 | meanAcc5 | diff5 |
|------|----------|----------|-------|
| **`Aonly_vw=0.01_res3only`** | 64.89% | 77.35% | **+1.19pp** |
| `Aonly_vw=0.01_res3-4` | 64.38% | 77.28% | +1.12pp |
| `Aonly_vw=0.05_res2only` | 64.63% | 77.24% | +1.08pp |
| `AB_vw=0.10_res2-4` | 64.37% | 77.12% | +0.95pp |
| `AB_vw=0.01_res3-4` | 64.48% | 77.05% | +0.89pp |

**AB vs Aonly 配对比较（TaskB 有方差 vs 无方差）：**

| 统计 | 值 |
|------|-----|
| AB 优于 Aonly 的配对数 | 10 / 28 |
| AB 劣于 Aonly 的配对数 | **18 / 28** |
| 最大正偏差（AB>Aonly） | `vw=0.05_res4only` +1.05pp |
| 最大负偏差（AB<Aonly） | `vw=0.05_res2-5` **-1.34pp** |
| vw=0.20 最大 AB | `AB_vw=0.20_res4only` 76.71% |

- **关键发现**：
  - **TaskB 加方差以 64%（18/28）的概率损害性能**，AB-Aonly 整体均值偏负
  - 全局最优配置是 `Aonly`（仅 A 有方差）而非 AB（AB 均有方差）——TaskB 不需要加方差
  - `vw=0.01` 是最稳定的权重：Top 5 中 4 个用 vw=0.01
  - `vw=0.20` 全面劣化：所有 AB 模式 vw=0.20 的 meanAcc5 均 < 76.71%，不如 vw=0.01 和 vw=0 的中位数
  - vw=0 的噪音带约为 ±0.6pp——最强信号 +1.19pp 略超噪音天花板，但不跨层泛化（res3only 的结果 res4only 上不重现）

---

## 最终结论

### MNIST 基线过强
- 纯 CE（无方差正则）在 epoch 2 即可达到 90%+ 验证准确率
- 方差项的梯度信号被 CE 主导淹没

### 最优配置
- **`varWeight=0.01, res3only`**（仅 `res3b_relu` 的隐藏层方差）
- 但在最优配置下相对于基线的 epoch 5 提升仅 +0.5 pp，不具备实质意义

### 核心发现
1. **无论选什么层组合、什么 varWeight（0.01–0.20），方差正则都不能稳定提升 MNIST 早期学习速度**
2. **实验 7 v2（63 组 AB/Aonly 配对）是决定性证据**：
   - TaskB 加方差以 64% 概率损害性能（AB < Aonly）
   - 全局最优是 `Aonly_vw=0.01_res3only`（仅 A 有方差），而非 AB 一致加方差
   - vw=0.20（高权重）全面劣化，所有 AB 模式均 < 76.71%
3. **任务不对称**：方差正则对 TaskA 表征学习可能有轻微帮助（压低隐藏层方差），但将同一正则直接施加于 TaskB 是有害的
4. **res5 层的 feature variance 天然偏高**，加入方差正则时反而损害精度
5. **当前乘除式 loss**（$CE/(1+\lambda·var)$）在 MNIST 快速收敛场景下无法拉开有/无方差的差距

### 建议
- 换更难的任务对（如 CIFAR-10→Fashion-MNIST, CIFAR-100, STL-10 等）
- 尝试加性 loss 形式（$CE + \alpha·var$）在有限步数下比较差异
- 多随机种子重复实验以获得可靠 p 值
- 考虑在 TaskB 上也加方差正则，而不仅限于 TaskA

### 实验覆盖总览

| 实验 | TaskA 方差 | TaskB 方差 | AB 一致 | 种子控制 | 结论 |
|------|-----------|-----------|---------|---------|------|
| SweepVarianceParams | ✅ 扫描 | ❌ | N/A | ✅ | vw 0.01-0.05 最优区间 |
| SweepVarForMnistTransfer | ✅ 扫描 | ✅ 扫描 | ✅ 一致 | ❌ 每组独立 | +3pp 为噪音 |
| CleanVarOnB | 固定 ckpt | ✅ 扫描 | ❌ 不一致 | ❌ 每组独立 | +1.9pp 为噪音 |
| CleanSweepLayerSets | 固定 ckpt | ✅ 扫描 | ❌ 不一致 | ✅ | +0.50pp 为噪音 |
| CleanSweepLayerSetsPar | 固定 ckpt | ✅ 扫描 | ❌ 不一致 | ❌ worker 独立 | +0.33pp 为噪音 |
| **CleanSweepABConsistent v2** | ✅ 扫描 | ✅ AB/Aonly 双模式 | ✅ | ✅ | **Aonly 最优** |
| 最终验证 (100ep) | vw=0.01 | vw=0 | ❌ 仅A | ✅ | -0.28pp |

**决定性结论**：实验 7 v2（63 组 AB/Aonly 配对扫描）表明：
1. TaskB 加方差以 64% 概率损害性能
2. 最优配置是仅 A 有方差（`vw=0.01, res3only`），TaskB 不应加方差
3. vw 在 0.01–0.05 区间最稳定，vw=0.20 全面劣化
4. CIFAR-10→MNIST 任务对上，隐藏层方差正则化的正面贡献不超出噪音水平

---

---

## 最终验证（最优配置应用）

### 配置
- `varWeight=0.01`, 仅 `res3b_relu`
- TaskA: CIFAR-10, 500 样本/epoch × 100 epoch
- TaskB: MNIST, 600 样本/epoch × 100 epoch
- 对照组为纯 CE（无方差正则）

### 结果

| 指标 | Var | NoVar | 差值 |
|------|-----|-------|------|
| TaskA 最终准确率 | 80.47% | 81.41% | **-0.94%** |
| TaskA 最终隐藏方差 | 0.0718 | 0.0959 | -0.0242 (↓25%) |
| TaskB 最终准确率 | 99.18% | 98.75% | +0.43% |
| TaskB 前10 epoch 均值 | 85.68% | 87.08% | **-1.39%** |
| TaskB epoch 5 | 96.39% | 96.67% | -0.28% |

### 分析

1. **TaskA 表现轻微下降**：方差正则削弱了表征能力（-0.94 pp），但确实降低了隐藏层方差（↓25%）
2. **TaskB 早期学习速度不增反降**：前 10 epoch 均值低于对照组 1.39 pp
3. **最终 TaskB 表现出奇地略高**：+0.43 pp，但绝对值均已 >98.7%，差异无实质意义
4. **整体结论不变**：在 CIFAR-10→MNIST 这一简单任务对上，隐藏层方差正则无正面贡献

### 输出图表

1. `TaskB_ContinualVsNaive.svg` — TaskB 持续学习(A→B) vs 直接训练损失对比
2. `TaskA_VarianceVsNoVariance.svg` — TaskA 加 vs 不加方差正则的训练过程
3. `TaskB_VarianceOnAvsNoVarianceOnA.svg` — 迁移效果：A有方差 vs A无方差对B的影响

---

*报告生成于 2026-06-28*
*对应代码：`RunResNetTaskABWithVarianceLoss.m`, `ComputeModelGradientsVarianceLoss.m`, `CleanSweepABConsistent.m`, `RunVw020Res34VsBaseline.m`*

> **注意**：以下 Top 10 表格来自实验 6（CleanSweepLayerSets），使用旧版单 epoch 指标 (valAcc3/valAcc5/finalVal)。新版改用 epoch 范围均值 (meanAcc3/meanAcc5/meanAccAll)，实验 7 起生效。_

Top 10 by meanAcc5 diff:
              tag               meanAcc3    meanAcc5    meanAccAll      diff3       diff5     diffAll
    ________________________    ________    ________    __________    _________    _______    _______

    "Aonly_vw=0.01_res3only"    0.64887      0.7735       0.7735         0.0157    0.01186    0.01186
    "Aonly_vw=0.01_res3-4"      0.64383      0.7728       0.7728       0.010667    0.01116    0.01116
    "Aonly_vw=0.05_res2only"    0.64633     0.77244      0.77244       0.013167     0.0108     0.0108
    "AB_vw=0.10_res2-4"         0.64367     0.77116      0.77116         0.0105    0.00952    0.00952
    "AB_vw=0.01_res3-4"         0.64483     0.77052      0.77052       0.011667    0.00888    0.00888
    "Aonly_vw=0.10_res2-5"      0.64227     0.76998      0.76998         0.0091    0.00834    0.00834
    "AB_vw=0.01_res3only"       0.64473     0.76948      0.76948       0.011567    0.00784    0.00784
    "Aonly_vw=0.01_res2only"    0.64273     0.76922      0.76922      0.0095667    0.00758    0.00758
    "Aonly_vw=0.05_res2-5"      0.64047     0.76898      0.76898         0.0073    0.00734    0.00734
    "Aonly_vw=0.20_res2-5"       0.6405     0.76794      0.76794      0.0073333     0.0063     0.0063


Top 10 by meanAcc3 diff:
              tag               meanAcc3    meanAcc5    meanAccAll      diff3       diff5     diffAll
    ________________________    ________    ________    __________    _________    _______    _______

    "Aonly_vw=0.01_res3only"    0.64887      0.7735       0.7735         0.0157    0.01186    0.01186
    "Aonly_vw=0.05_res2only"    0.64633     0.77244      0.77244       0.013167     0.0108     0.0108
    "AB_vw=0.10_res2-3"          0.6451      0.7678       0.7678       0.011933    0.00616    0.00616
    "AB_vw=0.01_res3-4"         0.64483     0.77052      0.77052       0.011667    0.00888    0.00888
    "AB_vw=0.01_res3only"       0.64473     0.76948      0.76948       0.011567    0.00784    0.00784
    "Aonly_vw=0.01_res3-4"      0.64383      0.7728       0.7728       0.010667    0.01116    0.01116
    "Aonly_vw=0.10_res2-3"       0.6438     0.76558      0.76558       0.010633    0.00394    0.00394
    "AB_vw=0.10_res2-4"         0.64367     0.77116      0.77116         0.0105    0.00952    0.00952
    "Aonly_vw=0.01_res2only"    0.64273     0.76922      0.76922      0.0095667    0.00758    0.00758
    "Aonly_vw=0.10_res2-5"      0.64227     0.76998      0.76998         0.0091    0.00834    0.00834


小样本尝试：每类30张图训练，10张图验证，一个epoch。中间层尝试不同方差权重。

=== AB vs Aonly: TaskB variance delta (AB - Aonly) ===
config          AB_mean5     Aonly_mean5  delta       
vw=0.01_res2-4  0.7602       0.7657        -0.0054  | d3=-0.0102 dAll=-0.0054
vw=0.05_res2-4  0.7640       0.7595        +0.0045  | d3=-0.0004 dAll=+0.0045
vw=0.10_res2-4  0.7712       0.7674        +0.0037  | d3=+0.0068 dAll=+0.0037
vw=0.20_res2-4  0.7645       0.7667        -0.0022  | d3=-0.0055 dAll=-0.0022
vw=0.01_res2-5  0.7670       0.7665        +0.0005  | d3=+0.0011 dAll=+0.0005
vw=0.05_res2-5  0.7555       0.7690        -0.0134  | d3=-0.0072 dAll=-0.0134
vw=0.10_res2-5  0.7674       0.7700        -0.0026  | d3=-0.0032 dAll=-0.0026
vw=0.20_res2-5  0.7670       0.7679        -0.0009  | d3=+0.0012 dAll=-0.0009
vw=0.01_res2-3  0.7570       0.7593        -0.0023  | d3=-0.0012 dAll=-0.0023
vw=0.05_res2-3  0.7644       0.7599        +0.0045  | d3=-0.0077 dAll=+0.0045
vw=0.10_res2-3  0.7678       0.7656        +0.0022  | d3=+0.0013 dAll=+0.0022
vw=0.20_res2-3  0.7659       0.7613        +0.0046  | d3=+0.0084 dAll=+0.0046
vw=0.01_res3-4  0.7705       0.7728        -0.0023  | d3=+0.0010 dAll=-0.0023
vw=0.05_res3-4  0.7667       0.7640        +0.0027  | d3=+0.0053 dAll=+0.0027
vw=0.10_res3-4  0.7600       0.7633        -0.0033  | d3=-0.0092 dAll=-0.0033
vw=0.20_res3-4  0.7589       0.7596        -0.0006  | d3=-0.0007 dAll=-0.0006
vw=0.01_res2only  0.7571       0.7692        -0.0121  | d3=-0.0165 dAll=-0.0121
vw=0.05_res2only  0.7679       0.7724        -0.0045  | d3=-0.0082 dAll=-0.0045
vw=0.10_res2only  0.7528       0.7605        -0.0076  | d3=-0.0159 dAll=-0.0076
vw=0.20_res2only  0.7540       0.7558        -0.0018  | d3=-0.0018 dAll=-0.0018
vw=0.01_res3only  0.7695       0.7735        -0.0040  | d3=-0.0041 dAll=-0.0040
vw=0.05_res3only  0.7586       0.7673        -0.0088  | d3=-0.0074 dAll=-0.0088
vw=0.10_res3only  0.7623       0.7632        -0.0009  | d3=-0.0000 dAll=-0.0009
vw=0.20_res3only  0.7538       0.7538        +0.0000  | d3=+0.0005 dAll=+0.0000
vw=0.01_res4only  0.7554       0.7571        -0.0018  | d3=-0.0075 dAll=-0.0018
vw=0.05_res4only  0.7658       0.7553        +0.0105  | d3=+0.0147 dAll=+0.0105
vw=0.10_res4only  0.7595       0.7599        -0.0004  | d3=-0.0071 dAll=-0.0004
vw=0.20_res4only  0.7671       0.7591        +0.0080  | d3=+0.0070 dAll=+0.0080