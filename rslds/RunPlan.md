# rSLDS 实跑说明（Stage 1 pilot）

> 对应笔记 `RecurrentSwitchingLinearDynamicalSystems_Notes.md` 的 **(q)** 设计 与 **(r)** 环境实测。
> 本文件是**开工前存档**：先写清楚"要跑什么、怎么跑、怎么判"，再动手。

---

## 0. 已完成的准备（无需再动）

| 项 | 状态 |
|---|---|
| Python 环境 | `rslds\.venv`（CPython 3.10.20）+ numpy 1.26.4 / scipy 1.15.3 / sklearn 1.7.2 / h5py 3.16.0 |
| `ssm` | `rslds\third_party\ssm`，C++ 扩展已编译（`SetupEnv.bat` + `SetupSSM.bat`） |
| 数据出口 | `rslds\ExportForRSLDS.m` 已跑通，`rslds\CheckExport.py` 校验 **CHECK_OK** |
| 冒烟测试 | ① 合成回归 0.934 ✔ ② K=1 退化 ✔ ③ 真实规模 **1.12 s/轮** ✔ |
| 已导出数据 | `rslds\data\ALB\` 的 3 个 block（`yqn0133`，238 细胞） |

---

## 1. 这一步要跑什么（Stage 1 pilot）

**只跑 1 个 block，6 次拟合，不是为了出结论，是为了验证流程与量级。**

| 项 | 值 |
|---|---|
| Block | `ALB_yqn0133_20240517-0835_AudioWater.mat`（Learned 阶段，20.8 min，238 细胞，T=10034 @8.03 Hz） |
| 为什么选它 | 三种事件（cue 30、给水 30、lick）齐全，时长接近中位 |
| 配置网格 | $K\in\{2,3,4\}$ × 去趋势 $\in\{$原始$,\ $双指数漂白$\}$ = **6 次拟合** |
| 迭代 | `num_iters=150`，`alpha=0.0`，`seed=0` |
| 预计耗时 | 6 × ~3 min ≈ **18 min**（按 1.12 s/轮 实测外推） |
| 不做什么 | 不做 CV、不扫潜维、不做跨阶段比较、不跑其余 block |

---

## 2. 精确流水线（每一步都可复现）

```
.mat (v7.3)  ──h5py──▶  X (T×N) 原始荧光
                          │
                          ├─ ① 丢掉 cellFiniteFrac < 1 的细胞（整段 NaN 的）
                          ├─ ② （可选）逐细胞双指数漂白去趋势
                          ├─ ③ 逐细胞 z-score
                          ├─ ④ FactorAnalysis → Y (T×10)
                          │
CD1/CD2/事件下标 ─────────┴─ ⑤ 构造输入 u (T×3)
                          │
                          └─ ⑥ ssm.SLDS(10, K, 10, M=3, transitions="recurrent", ...)
                                .initialize(Y, inputs=u)
                                .fit(Y, inputs=u, method="laplace_em", ...)
```

### ⑤ 输入的构造（3 个通道）

| 通道 | 定义 | 理由 |
|---|---|---|
| `cue` | `idx_TrialStart` 处 **1 s 方波**（0/1） | 单帧脉冲只影响一次转移，太弱；1 s 窗覆盖钙上升时间 |
| `lick` | `CD2 > median(CD2)+5` 二值 → **1 s 滑动平均** = 舔水率 | 与 Step1c/Step2 同口径；连续量比二值稳 |
| `reward` | `idx_GiveWater` 处 **1 s 方波** | 奖赏独立于 cue，且 `LAu` 块里给水恒为 0，是天然的对照 |

⚠ 输入全部来自**行为/刺激通道**，与钙信号无信息重叠，**不会泄漏**。
⚠ 输入**只进转移**：`transitions="recurrent"` 让 $u_t$ 只进 $\log p(z_t\mid z_{t-1})$；
发射里也存在一个 $F u_t$ 项，本 pilot **保持它存在**（`ssm` 的默认行为），
但在 Stage 2 要单独跑一次 `F` 被固定为 0 的对照——否则"输入影响状态"会被发射项混淆。

### ⑥ 模型配置（已核对过的实际 API）

```python
m = ssm.SLDS(10, K, 10, M=3,                    # ⚠ M 是**关键字**参数，默认 0
             transitions="recurrent",           # logit p = log_Ps[z_{t-1}] + x·R + u·W
             dynamics="diagonal_gaussian",      # A_k 是**满矩阵**，只有噪声对角
             emissions="gaussian_orthog",
             single_subspace=True)
m.initialize(Y, inputs=u)
elbos, q = m.fit(Y, inputs=u, method="laplace_em",
                 variational_posterior="structured_meanfield",
                 initialize=False, num_iters=150, alpha=0.0, verbose=0)
```

已实测的参数形状：`As` (K, D, D)、`bs`/`sigmasq` (K, D)、`Rs` (K, D)、
`Ws` (K, 3)、`log_Ps` (K, K)、`emissions.Cs` (1, 10, 10)。

---

## 3. 读出的量及其精确定义

| # | 量 | 怎么算 |
|---|---|---|
| (1) | **K 选择信号** | 最终 ELBO、ELBO/点。⚠ pilot 里 6 次拟合不是同一份留出集，**只做量级参考，不当证据** |
| (2) | **驻留时间** | `z = m.most_likely_states(x_hat, Y)` 硬指派 → 连续段长 × dt；报中位与分位；同时报**切换次数** |
| (3) | **τ 谱** | $A_k$ 特征值 $\lambda$ → $\tau_{k,i} = \dfrac{-1/f_s}{\ln\vert\lambda_{k,i}\vert}$；每状态取 $\lvert\lambda\rvert$ 最大者为该状态主 $\tau$ |
| (4) | **对齐** | PSP：$P(z_t=k)$ 相对 cue 的 −3…+3 s 曲线；另算 $\mathrm{corr}(q(z_t=k),\ \text{舔水率})$ 与相对给水的锁相 |
| (5) | **漂移** | 占用率 vs session 内时间：线性回归斜率 + Spearman；**去趋势前后对比** |

---

## 4. 事先声明的判读规则（沿用笔记 (q)，不看完数据再定）

| 观察到 | 判读 |
|---|---|
| 秒级驻留 + 与 cue/给水对齐 | 支持"任务状态"，**不支持**"慢动机状态" |
| 分钟级驻留 + 与舔水率共变 | 与"慢动机状态"一致，**但必须排除漂移** |
| 去趋势后 $K$、$\tau$ 谱不变 | 状态不是漂移假象 |
| 状态沿 session 内时间**单调** | 疑似漂移/饱食，**不可区分** → 不下结论 |
| 几乎每帧切换（切换次数 ~ T） | **退化解，该 block 无信息**，不能当结果用（冒烟测试 ③ 出现过） |

---

## 5. Pilot 的验收门槛（决定要不要放开 Stage 2）

四条**全部**满足才继续：

1. 单次拟合 < **5 min**（否则全量跑不完）；
2. 6 次拟合中**没有**"每帧切换"的退化解；
3. ELBO 在 150 轮内已接近平台（末 10 轮相对变化 < 1%）；
4. PSP 曲线**看得出结构**（不是平的）——否则说明 $D_\text{latent}$ 或 $K$ 选得不对。

**任一条不满足 → 停下来报告，不自行放开门槛。**

---

## 6. Pilot 之后（Stage 2，需再次确认）

1. 全量导出 `ALB`（112 个 block，排除 `Recall`，约 2 GB）；
2. 先跑 **44 个四阶段 block**（11 鼠 × 4 阶段），$K$ 由**留一 session 的 CV 似然**选；
3. 对照：`transitions="sticky"`（经典 SLDS，无循环项）+ HMM 基线；
4. 输出：CV 似然 vs $K$、占用率/驻留/转移矩阵/$\tau$ 谱、状态序列叠加 cue·给水·舔水、
   占用率 vs session 内时间、跨阶段·跨 session 的 $K$/$\tau$/转移矩阵相似度。

## 7. 这次不做

跨 session 状态对齐（label switching）；TH vs Ctrl 的 rSLDS 比较（n 太小）；
$\tau$ ~ 命中率的跨鼠相关；因果推断（本数据无干预）。
