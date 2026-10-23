本文档记录英文图 FigS4 系列（`英文图/FigS4A~F_*.m`，数据管线 `英文图/FigS4_PreCueStatePCA_Analysis.m`）与文献 Chen et al., *Targeted stimulation of motor cortex ensembles drives learned movements*, Nature 2026（doi:10.1038/s41586-026-11174-3，下文简称"文献"）各图面板的对应关系。对应分两类：**样式对应**（图型、坐标、分组方式一致）与**思路对应**（检验的科学问题与统计口径一致）。每个 panel 至少满足其一；不满足者已按文献面板重做（修订记录见文末）。

| 本图 panel | 文献对应面板 | 对应类型 |  replicated 口径要点 |
|---|---|---|---|
| FigS4A-1/2（early/late/no-onset 占比堆叠条，Learned 与 Transfer） | Fig.1c、Fig.2a（按 activity onset 排序的热图与分类）+ 正文占比（early 12.1±1.5%、late 15.9±0.9%） | 思路 | onset 判据逐条复制：lick(=movement) 锁定 PSTH、基线 [-1,-0.5] s +1 SD、持续 200 ms、200 Hz 上采样；onset<0 为 early |
| FigS4A-3（early 细胞 lick 锁定平均 PSTH ± SEM） | Fig.1c 右（example early-onset 细胞跨 movement 平均轨迹，虚线=movement onset） | 样式+思路 | 对齐 movement(lick) onset；跨鼠 mean±SEM |
| FigS4B-左（PC1–PC2 群体轨迹：learned 均值黑线 + 高/低相似 trial 灰实/虚线，cue 与 movement onset 标记） | Fig.4a/b 左（non-target 神经元 PC 空间轨迹，黑=learned、灰/粉=高/低相关 trial，含 cue 前 0.5 s） | 样式+思路 | PCA 于 non-early 细胞、保留 80% 方差；learned trajectory=Learned hit 均值（LOO） |
| FigS4B-右（到 learned trajectory 距离的时间过程，hit/miss mean±SEM，灰带=线索前窗） | Extended Data Fig.10（movement vs no-movement 的群体活动时间过程 mean±SEM） | 样式；思路=状态随结局分化 | 距离=d(t) 欧氏距离；灰带 [-0.5,0] s 同文献 pre 窗 |
| FigS4C（线索前距离 vs 舔水相似度散点 + 拟合线 + r） | Fig.4a 右、Fig.4b 右、ED Fig.9a（pre-stim/pre-cue distance vs correlation with learned movement，报 R） | 样式+思路 | pre 窗 [-0.5,0] s；相似度=与 learned 模板的相关 |
| FigS4D-左（Hit vs Miss 线索前距离 bar±SEM + 逐鼠点） | Fig.5a/b（movement vs no-movement 的 bar+dot 比较） | 样式；思路=结局间状态差异 | 鼠内 z；Wilcoxon 配对 |
| FigS4D-右（movement probability vs 初始状态四分位箱 + logistic 曲线） | ED Fig.9d（初始状态分箱的实际运动概率点±SEM + 拟合曲线） | 样式+思路 | 分箱=鼠内 z 距离四分位；曲线=pooled logistic GLM |
| FigS4E（pre vs post 距离散点 + r，两阶段） | Fig.4c、ED Fig.9b（pre- vs post-stim/cue 距离相关，R=0.527/0.382/0.834/0.850） | 样式+思路 | 同窗定义（pre [-0.5,0]、post [0,0.5] s） |
| FigS4F（四组 box+dot：Learned held-out / shuffled / Transfer / shuffled） | Fig.3d 右（Voluntary / shuffled / Opto / shuffled 预测精度 box-and-whisker） | 样式+思路 | 解码设计同 Fig.3d 左示意：train 80% voluntary→test 保留 20% voluntary + 另一情境；lasso；shuffle 对照 |

**FigS4A 对应说明。** 文献以热图（Fig.1c/2a）展示 onset 分类、以正文给出每 session 占比；本图把同一分类量化为跨阶段（Learned→Transfer）的占比堆叠条，属思路对应（分类与占比口径完全一致），堆叠条为本工程的展示选择。第三 panel 的 lick 锁定 PSTH 与 Fig.1c 右的示例轨迹在样式与口径上均一致。实测：early 占比 Learned 3.44% → Transfer 7.50%（Wilcoxon p=0.002，10/11 鼠上升）。

**FigS4B 对应说明。** 左 panel 复刻 Fig.4a/b 左的"learned 轨迹 + 高/低相似 trial 轨迹"PC 空间画法（含 cue onset 空心圆与 movement onset 实心点标记）；差异：文献为 PC1-2-3 三维，本工程为 PC1–PC2 二维（静态图更易读），且时间窗取 [-0.5, +1] s 以同时覆盖文献 Fig.3a（cue 后 1 s）与 Fig.4a/b（cue 前 0.5 s）两个窗。右 panel 的距离时间过程借用 ED Fig.10 的 mean±SEM 时间过程样式，按 hit/miss 分组。

**FigS4C 对应说明。** 与 Fig.4a/b 右、ED Fig.9a 完全同构：x=到 learned activity 的线索前距离，y=与 learned movement 的相关，报 Pearson R 与拟合线。差异：文献相似度来自 lever 运动学，本工程等价为舔水率 trace（CD2 阈值+200 ms 平滑）在 Learned hit 模板上的相关；文献为单 session 散点，本工程为鼠内 z 后 pooled（330 trial）。实测 pooled r=-0.016（p=0.78），逐鼠 9/11 为负（p=0.21）——方向同文献但效应不显著。

**FigS4D 对应说明。** 左 panel 的 bar+dot 样式取自 Fig.5a/b（该图以 bar+逐 session 点比较 movement vs no-movement）；科学问题（初始状态是否区分结局）对应正文"the initial state significantly predicted the probability of movement"。右 panel 直接复刻 ED Fig.9d 的画法：x=初始状态分箱、y=实际运动概率 mean±SEM、叠加拟合曲线；差异是文献的初始状态为 logistic 解码器输出，本工程用线索前距离本身（与 ED Fig.9a-c 同一状态量）。实测 logistic 斜率 p=0.77、三分位 Friedman p=0.57——零结果，与文献阳性相反，须在正文讨论。

**FigS4E 对应说明。** 与 Fig.4c / ED Fig.9b 同构（pre 与 post 距离的相关，用于检验线索前状态是否为独立测量）。实测 Learned r=+0.40、Transfer r=+0.30（均 p<0.003），量级与文献 voluntary（0.382/0.850）相当但低于 opto（0.527/0.834）；该中度相关提示本数据的线索前状态非完全独立测量。

**FigS4F 对应说明。** 解码设计与 Fig.3d 左示意逐条对齐：训练集=80% Learned（voluntary 等价）trial 的线索前 PC 均值，测试集=保留 20% Learned 与全部 Transfer（opto 等价）；lasso 回归（λ 由训练集内 5 折 CV 选）；shuffle=测试目标置换 200 次；展示为四组 box-and-whisker+逐鼠点（Fig.3d 右样式）。差异：文献每 session trial 数远多于本工程（30 trial/鼠 → 80/20=24/6），且文献目标为 lever 运动学、本工程为舔水模板相关。实测 held-out Learned 中位 r=-0.124（vs shuffle p=0.15）、Transfer 中位 r=-0.044（vs shuffle p=0.055，低于 chance）——无跨情境解码，与文献 Fig.3d 的阳性结果相反。

**全图共同口径与差异。** (1) movement 定义：文献为 lever 前推速度 >41.7 mm/s，本工程为孤立舔水 bout 起点（CD2 上升沿、前 1 s 无舔水），onset 搜索窗/基线/持续判据与文献 Methods 一致。(2) 活动信号：文献用 Suite2p 反卷积 spike，本工程用 cue 前基线 z 化的 ΔF/F（无反卷积工具），钙上升沿滞后会低估 early-onset 比例，须在正文注明。(3) PCA：文献对 non-target 神经元 cue 前后各 2 s（40 帧@10 Hz）做 PCA 保留 80% 方差；本工程同窗、原生帧率 8–30 Hz、同 80% 阈值。(4) 高/低相似 trial 划分：文献用固定阈值（>0.7 与 ≤0.3 或 ≤0.5），本工程因相关值域压缩改用鼠内三分位。(5) 循环论证防护：learned trajectory 与舔水模板对 Learned 自身 trial 一律 leave-one-out；early 分组仅在 Learned block 判定后用于 Transfer 展示。

**修订记录（按核对结果重做的部分）。** FigS4A 原为两 panel 堆叠条，核对后增加第三 panel（Fig.1c 右样式 PSTH）；FigS4B 原仅有距离时间过程，核对后增加 PC 轨迹 panel（Fig.4a/b 左样式）；FigS4D 原为配对连线+三分位折线，核对后改为 Fig.5b 样式 bar+dot 与 ED Fig.9d 样式分箱概率+拟合曲线；FigS4F 原为直方图+逐鼠条形且解码为"全量 Learned 训练→Transfer 测试"，核对后改为 Fig.3d 的 80/20 训练-测试设计与四组 box+dot。FigS4C、FigS4E 初版即与文献面板同构，未改。
