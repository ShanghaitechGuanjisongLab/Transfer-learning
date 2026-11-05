# Guyoton et al., 2025 — Cortical circuits for cross-modal generalization（阅读笔记）

> Guyoton, M., Matteucci, G., Foucher, C. G., Getz, M. P., Gjorgjieva, J., & El-Boustani, S. (2025).
> Cortical circuits for cross-modal generalization. *Nature Communications*, 16, 4230.
> https://doi.org/10.1038/s41467-025-59342-9
> 数据/代码：Zenodo `10.5281/zenodo.14712478`；网络模型代码：`github.com/comp-neural-circuits/Guyoton-Matteucci-etal-2025`

## 目录

- [Q1. 图 1f 中 top/bottom 条件舔舐概率几乎跌到 0，为什么 perf 仍约 50%？top/bottom 与 perf 分别怎么算？](#q1)

---

## Q1

### Q1. 图 1f 中 top/bottom 条件舔舐概率几乎跌到 0，为什么 perf 仍约 50%？top/bottom 与 perf 分别怎么算？

**结论一句话：** perf（判别表现）不是舔舐概率本身，而是"Hit 率"与"Correct-Reject 率"的平均；当动物完全停止舔舐时，Hit = 0 而 CR = 1，二者平均恰为 0.5。所以"两条 lick 曲线一起归零"与"perf 平在 50%"是**同一件事的两种表现**——50% 正是完全脱离任务（disengagement）的特征值，而不是"还在做题但做对了一半"。

#### 1. 三个量的定义（Methods → "Behavioral analysis"）

滑动窗口宽 60 trials，窗口内：

- **top / bottom / spont 三条曲线**：条件舔舐概率（conditional lick probability）
  - $\text{top} = P(\text{lick} \mid \text{top 刺激})$
  - $\text{bottom} = P(\text{lick} \mid \text{bottom 刺激})$
  - $\text{spont} = P(\text{lick} \mid \text{无刺激 / Catch 试次})$
  - 即"窗口内对该刺激舔舐的试次数 ÷ 该刺激在窗口内出现的试次数"。Go/No-go 的身份（哪一个算 Go）由当前任务规则决定，而画图时 top/bottom 恒指刺激的物理位置。

- **判别表现 discrimination performance（Fig. 1d–g 中的绿色 perf 曲线）**
  $$\text{perf} = \frac{1}{2}\Big(\underbrace{P(\text{lick}\mid \text{Go})}_{\text{Hit rate}} + \underbrace{1 - P(\text{lick}\mid \text{No-go})}_{\text{Correct Reject rate}}\Big)$$
  这种写法对 Go/No-go 试次比例不敏感（不会被"Go 试次占比变化"带偏）。

- **检测表现 detection performance（Fig. 1e/1g 右侧的紫色分布）**
  $$\text{det} = \max\Big(\tfrac{1}{2}\big(\text{Hit} + \text{CR}_\text{catch}\big),\ \tfrac{1}{2}\big(\text{FA} + \text{CR}_\text{catch}\big)\Big)$$
  其中 $\text{FA} = P(\text{lick}\mid \text{No-go})$，$\text{CR}_\text{catch} = 1 - \text{spont}$。

#### 2. 为什么"两条曲线跌到 0" ⟹ perf = 50%

规则反转切换后，小鼠先按**旧的空间规则**去舔（舔的是"旧奖赏位置 = 新 No-go"），随后迅速 disengage、**彻底停止舔舐**。停止舔舐时：

- Hit rate $= P(\text{lick}\mid\text{Go}) = 0$
- FA rate $= P(\text{lick}\mid\text{No-go}) = 0 \Rightarrow$ CR rate $= 1$

$$\Rightarrow \text{perf} = \frac{0 + 1}{2} = 0.5$$

所以 top（=Go 侧的物理位置之一）和 bottom 两条曲线**同时**归零，恰好把 perf 钉在 50%。

#### 3. 关键推论：这个指标下"乱舔"和"不舔"都 = 50%

- **完全不动**：Hit 0、CR 1 → 0.5 ✔（图 1f 后段）
- **对所有刺激都舔**（试次早期"回应两者"）：Hit 1、FA 1 → CR 0 → 0.5 ✔
- **只有按反转前的旧规则舔**（舔 No-go、不舔 Go）：Hit 0、FA 1 → CR 0 → **perf < 0.5** ✘

因此**低于 50% 才有信息量**：它唯一地表示"动物主动地、系统性地按（旧）规则舔错"。图 1f 中早期短暂跌破 50%、随后回到 50%，正是"先套用旧规则 → 失败 → 放弃"的过程；而 Fig. 1g / Supplementary Fig. 1 报告的"反转到随机或以下"也是同一机制。

#### 4. 附注

- **detection 也同时瘫到约 50%**（Fig. 1f 右：Det. 也显著下降），原因相同：不舔时 Go 检测率 $=(0+1)/2=0.5$、No-go 检测率 $=(0+1)/2=0.5$。
- 每只鼠**按会话汇总**的 perf 只在 engaged 试次上计算（会话结束判据：Go 条件舔舐概率跌破其峰值 66% 之后的那一刻），所以右侧分布图反映的是"参与任务"的部分；而左侧平滑曲线仍完整显示 disengage 段。
- 对照组中"规则保持"切换后两条曲线维持在"Go 高 / No-go 低"的分离状态，perf 因而保持高位——这与 1f 的"合并归零"形成直接对照。
