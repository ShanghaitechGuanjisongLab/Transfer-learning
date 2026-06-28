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

---

## 最终结论

### MNIST 基线过强
- 纯 CE（无方差正则）在 epoch 2 即可达到 90%+ 验证准确率
- 方差项的梯度信号被 CE 主导淹没

### 最优配置
- **`varWeight=0.01, res3only`**（仅 `res3b_relu` 的隐藏层方差）
- 但在最优配置下相对于基线的 epoch 5 提升仅 +0.5 pp，不具备实质意义

### 核心发现
1. **无论选什么层组合、什么 varWeight，方差正则都不能稳定提升 MNIST 早期学习速度**
2. **epoch 3 的表面提升（+3–4pp）几乎全部来自随机种子噪音**——固定 checkpoint 后消失
3. **res5 层的 feature variance 天然偏高**，加入方差正则时反而损害精度
4. **当前乘除式 loss**（$CE/(1+\lambda·var)$）在 MNIST 快速收敛场景下无法拉开有/无方差的差距

### 建议
- 换更难的任务对（如 CIFAR-10→Fashion-MNIST, CIFAR-100, STL-10 等）
- 尝试加性 loss 形式（$CE + \alpha·var$）在有限步数下比较差异
- 多随机种子重复实验以获得可靠 p 值
- 考虑在 TaskB 上也加方差正则，而不仅限于 TaskA

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
*对应代码：`RunResNetTaskABWithVarianceLoss.m`, `ComputeModelGradientsVarianceLoss.m`, `CleanSweepLayerSets.m`, `CleanSweepLayerSetsPar.m`*

Top 10 by acc5 diff:
           tag            valAcc3    valAcc5    finalVal    diff3      diff5      diffF 
    __________________    _______    _______    ________    ______    _______    _______

    "vw=0.01_res3only"    0.9522     0.9692      0.9633     0.0393      0.005    -0.0123
    "vw=0.10_res3only"    0.9441     0.9691      0.9735     0.0312     0.0049    -0.0021
    "vw=0.10_res2-5"      0.9526     0.9685       0.968     0.0397     0.0043    -0.0076
    "vw=0.01_res3-4"      0.9441     0.9676      0.9684     0.0312     0.0034    -0.0072
    "vw=0.00_res4only"     0.947     0.9668      0.9694     0.0341     0.0026    -0.0062
    "vw=0.10_res3-4"      0.9491     0.9664      0.9518     0.0362     0.0022    -0.0238
    "vw=0.01_res4only"    0.9497     0.9645      0.9645     0.0368     0.0003    -0.0111
    "vw=0.00_res2-4"      0.9129     0.9642      0.9756          0          0          0
    "vw=0.10_res2-3"      0.9423     0.9641      0.9713     0.0294    -0.0001    -0.0043
    "vw=0.05_res3-4"      0.9433     0.9633      0.9644     0.0304    -0.0009    -0.0112


Top 10 by acc3 diff:
           tag            valAcc3    valAcc5    finalVal    diff3      diff5      diffF 
    __________________    _______    _______    ________    ______    _______    _______

    "vw=0.00_res3-4"      0.9582     0.9602      0.9509     0.0453     -0.004    -0.0247
    "vw=0.05_res4only"    0.9576     0.9585       0.972     0.0447    -0.0057    -0.0036
    "vw=0.05_res2-4"      0.9548     0.9413      0.9654     0.0419    -0.0229    -0.0102
    "vw=0.10_res2-5"      0.9526     0.9685       0.968     0.0397     0.0043    -0.0076
    "vw=0.01_res3only"    0.9522     0.9692      0.9633     0.0393      0.005    -0.0123
    "vw=0.01_res2-5"      0.9512     0.9626      0.9656     0.0383    -0.0016      -0.01
    "vw=0.01_res4only"    0.9497     0.9645      0.9645     0.0368     0.0003    -0.0111
    "vw=0.10_res3-4"      0.9491     0.9664      0.9518     0.0362     0.0022    -0.0238
    "vw=0.10_res2-4"      0.9489     0.9594      0.9641      0.036    -0.0048    -0.0115
    "vw=0.00_res4only"     0.947     0.9668      0.9694     0.0341     0.0026    -0.0062