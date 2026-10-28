本文档记录英文图 FigS4 系列（`英文图/FigS4A~F_*.m`，数据管线 `英文图/FigS4_PreCueStatePCA_Analysis.m`）与 Chen et al., *Targeted stimulation of motor cortex ensembles drives learned movements*, Nature 2026（doi:10.1038/s41586-026-11174-3，下文简称“文献”）的对应关系。2026-10-25 初次重做，2026-10-26 再按 PDF 原图复核并纠正 A 的配色、示例曲线与饼图。只保留文献已有的图型与视觉元素，不加入总标题、装饰性标记或图内统计标题。文献科学量明显适用的口径已直接校正；不适用的部分保留本工程科学量，并在下文明确标为“样式对应”，不称为同义复现。

| 本图 panel | 文献样式来源 | 对应边界 | 当前实现要点 |
|---|---|---|---|
| FigS4A-1/2：Learned/Transfer 热图 | Fig.1c 左 | 样式+运动 onset 类比 | 黑底红色活动、灰点线=lick onset、时间比例尺；每行一个神经元，行按 early→late→no onset 排序；无白色分组线 |
| FigS4A-3/4：每阶段 3 个独立示例子图 | Fig.1c 右 | 样式+运动 onset 类比 | 每图仅一条细胞跨 movement 均值曲线及 SEM 阴影；无常规坐标轴，仅保留时间与活动比例尺 |
| FigS4A-5/6：两阶段 early-onset 饼图 | Fig.2a | 样式+分类占比 | 黑色 early、浅灰其余细胞；比例为逐鼠 early/全部记录细胞的跨鼠均值，非 pooled 比例 |
| FigS4B-左：PC 轨迹 | Fig.4a/b 左 | 样式+状态轨迹类比 | cue 前 [-0.5,0] s；黑=Learned hit 均值；灰实线 >0.7、灰虚线 ≤0.5；严格只用 80% 方差 PC，故画 PC1–PC2 |
| FigS4B-右：距离时间过程 | ED Fig.10 | 仅样式；纵轴科学量不同 | hit/miss mean±SEM 误差线；0–0.2 s 浅粉 cue 带；纵轴是距离而非文献活动量 |
| FigS4C：距离—舔水相关散点 | Fig.4a/b 右、ED Fig.9a | 样式+运动相似度类比 | x=pre-distance，y=`corrT`；拟合线，不在图内额外标统计值 |
| FigS4D-左：结局间距离比较 | Fig.5a/b | 仅样式；纵轴科学量不同 | bar=逐鼠均值的 mean±SEM，点=每鼠；Movement/No movement |
| FigS4D-右：初始状态与运动概率 | ED Fig.9d | 样式+思路，非文献 decoder 复刻 | 四分位点的横纵 SEM+平滑 logistic 曲线；分箱点不连线；初始状态仍是距离 |
| FigS4E：pre/post 距离散点 | Fig.4c、ED Fig.9b | 样式+状态持续性类比 | Transfer 在上、Learned 在下；post 窗已改为 [0,1] s |
| FigS4F：四组预测精度箱线图 | Fig.3d 右 | 仅样式；解码科学量不同 | median/IQR、whisker、均值“+”；无逐鼠散点、无额外结果标题 |

**FigS4A 对应说明。** 两个热图均含 5105 个神经元（22 blocks、11 鼠），颜色范围由两阶段 pooled PSTH 的稳健上界确定，黑红映射、灰点线和比例尺按 PDF 的 Fig.1c 绘制。文献第三组为 movement-suppressed，本工程没有该 shuffle 分类，故第三组仍明确为 no onset，不能写成 suppressed。示例鼠为 `vtf1233`，按 Learned onset 排序的 25/50/75% 位置选细胞索引 `[203, 87, 107]`；Transfer 画同一批细胞。每阶段均有 3 个上下排列的独立示例子图，每个子图仅一条细胞曲线及其跨 movement SEM 阴影，不用跨细胞或跨鼠 SEM；无常规坐标轴，只有 1 s 与 0.5 z 比例尺。Fig.2a 原文是 late-onset 饼图（正文为全部神经元的 15.9±0.9%/session），不是比例条；本图只借其黑白饼图形式展示 early-onset。饼图数值按逐鼠比例取均值：Learned `5.20±1.30%`、Transfer `8.46±1.08%`（mean±SEM），不使用 pooled 计数代替。逐鼠 early 比例中位数为 3.44%→7.50%，10/11 鼠上升，Wilcoxon `p=0.001953`；该检验只在命令行报告。

**FigS4B 对应说明。** 文献在 trial 平均活动上拟合 PCA 后，通常至少有 3 个 PC 才达到 80% 方差；本数据重算后每鼠只需 1–2 个。经用户确认，不额外引入第 3 个 PC，示例鼠 `vtf1233`（`k=2`）画 PC1–PC2。其 Transfer 高相似 trial 12 个（`corrT>0.7`）、低相似 trial 13 个（`corrT≤0.5`），均逐 trial 绘制而非先按组平均。右图使用同鼠 17 hit、13 miss，mean±SEM 以误差线表示；粉色带严格对应本实验 cue 的 0–0.2 s，不照搬文献 0–0.3 s 刺激窗。右图仅借 ED Fig.10 的时间过程样式，纵轴并非文献的活动幅度或活动相关。

**FigS4C 对应说明。** 已纠正旧版把投影系数 `simT` 当作运动相关的做法：现在纵轴为 `corrT`，即舔水率 trace 与 Learned hit 模板的 Pearson r；横轴为 pre-distance 的鼠内 z。330 个 Transfer trial 中 319 个相关值有限。重算后 pooled `r=-0.380, p=2.16×10^-12`，Spearman `rho=-0.388`；逐鼠 Spearman 中位数 `-0.133`，9/11 鼠为负，Wilcoxon `p=0.0244`。这是本工程舔水模板的结果，不与文献 lever displacement 的数值直接比较。

**FigS4D 对应说明。** 左图保留“线索前距离是否区分结局”的本工程问题，Fig.5a/b 仅提供 bar+dot 样式。11 鼠均可用，5/11 鼠 hit>miss，配对 Wilcoxon `p=0.3203`。右图不能照搬文献 initial-state decoder：当前 Learned 为 329 hit/1 miss，不能可靠训练 movement/no-movement logistic 模型，因此初始状态仍为 pre-distance 的描述性 z 值。四分位点计算跨鼠 mean±SEM（横纵两个方向），pooled logistic 斜率 `p=0.1004`；三分位命中率 Friedman `p=0.3878`。这些统计不画成文献没有的结果标题。

**FigS4E 对应说明。** post-distance 已从旧版 `[0,0.5]` 改为文献的 `[0,1]` s。重算后 Learned pooled `r=0.664, p=2.36×10^-43`，逐鼠中位 `r=0.334`（9/11>0，Wilcoxon `p=0.00977`）；Transfer pooled `r=0.100, p=0.0702`，逐鼠中位 `r=0.559`（11/11>0，Wilcoxon `p=0.000977`）。pooled 与逐鼠结果同时保留，不用其中一个替代另一个作结论。

**FigS4F 对应说明。** 文献 Fig.3d 解码的是“全时段神经活动残差→lever 运动时间轨迹残差”，本工程则是“线索前 PC 均值→每 trial 一个舔水模板相关标量”。按用户确认，后者为体现跨情境迁移而保留，故 Fig.3d 仅是箱线图样式来源，不能写成同口径复刻。train/test 仍为 80/20 Learned 与全部 Transfer，训练集内 5 折 CV 选 lasso λ，测试目标置换 200 次。重算后 7 鼠进入成对比较，held-out Learned 和 Transfer 的 median r 均约为 0，vs shuffle 均 `p=1`；稀疏模型出现较多全零系数，该结果不应被解释为对文献机制的否定。

**全图共同口径与差异。** (1) 文献 movement 是 lever 前推，本工程是孤立舔水 bout；onset 搜索窗、基线和持续判据一致，但运动学与行为含义不同。(2) 文献用反卷积活动，本工程用 cue 前基线 z 化 ΔF/F，early 比例不能与文献直接作数值比较。(3) PCA 已按文献 Methods 改为：Learned non-early 细胞 cue±2 s 的 **trial 平均** `神经元×帧` 矩阵拟合，再投影单 trial；80% 方差阈值不变，原生帧率 8–30 Hz。(4) learned trajectory 与舔水模板保留本工程 cue 对齐、Learned hit 平均及 Learned 自身 trial 的 leave-one-out 防护；没有冒充文献的 movement-aligned、随机一半高立体性试次模板。(5) 高/低相似 trial 已改回固定阈值 `>0.7/≤0.5`，不再用鼠内三分位。(6) lick 锁定 PSTH 仍取全 trial 窗，显示右界按“每鼠×每阶段 movement 覆盖率≥90%”确定为 +0.99 s；窗内零 NaN 由硬断言保证，不用 AlphaData 或外推遮掩。onset 判定窗独立为 [-0.2,1.5] s，统计不受显示裁剪影响。(7) 全部坐标轴采用 Arial、细框线和文献式灰/粉分组；相关系数与 p 值保留在命令行和本文档，而非擅自加入文献图内。

**本次修订记录。** 初轮曾错误地把 Fig.1c 写成黑绿热图、把多个示例细胞叠在同一坐标轴且未画 SEM，并把 Fig.2a 误称为比例条；2026-10-26 直接渲染 PDF 后已全部纠正。A 现为黑红热图、每阶段 3 个独立无轴“单曲线+跨 movement SEM”示例子图及黑白 early-onset 饼图；逐细胞 SEM 已新增保存为 `psthCellSemL/T`。A 改用 `exportgraphics` 导出，因为 `print -dsvg` 在隐藏坐标尺的 axes 中漏掉示例曲线。B 删除 cue/lick 标记、组平均轨迹、距离总均值虚线和 pre 灰带，改为逐 trial 轨迹、误差线与真实 cue 色带；C 修正科学变量及坐标方向；D 删除统计标题和分箱点连线；E 改为上下排列；F 删除逐鼠散点及结果标题，只保留箱线、须和均值“+”。所有 6 个 SVG 均已实际运行导出并用图像工具检查。
