RNN 相关中文图已按英文图2的空闲字母重制。保留现有英文图2文件及中文源脚本；新增脚本均可在 MATLAB 编辑器独立 Run/F5，SVG 统一经 `TransferLearning.StandardFigureSvgPath` 输出到标准月目录。共生成11张SVG，对应14个面板；R-S-T-U沿用源图的四行合并布局。

# 面板对应

| 英文面板 | 内容 | 中文来源 | 独立入口 |
|---|---|---|---|
| 2G | 当前RNN结构及细胞数量 | Fig381A | [Fig2G_ModelStructure.m](Fig2G_ModelStructure.m#L1) |
| 2J | 兴奋/抑制细胞比例 | Fig381B | [Fig2J_ModelNeuronTypePie.m](Fig2J_ModelNeuronTypePie.m#L1) |
| 2K | 权重初始化分布示意 | Fig381C | [Fig2K_ModelWeightInitialization.m](Fig2K_ModelWeightInitialization.m#L1) |
| 2L | Naive、首个预训练block、预训练后的权重分布 | Fig53D | [Fig2L_ModelStageWeightDistributions.m](Fig2L_ModelStageWeightDistributions.m#L1) |
| 2M | 四类连接的预训练前后权重分布 | Fig54A | [Fig2M_ModelConnectionWeightDistributions.m](Fig2M_ModelConnectionWeightDistributions.m#L1) |
| 2N | 连接权重SD及分层E/I响应异质性 | Fig54B | [Fig2N_ModelWeightStdAndHeterogeneity.m](Fig2N_ModelWeightStdAndHeterogeneity.m#L1) |
| 2P | Naive/Transfer的Cue B学习曲线 | Fig54C | [Fig2P_ModelNaiveTransferLearningCurve.m](Fig2P_ModelNaiveTransferLearningCurve.m#L1) |
| 2Q | Naive Cue A、Naive Cue B、Transfer Cue B的L5响应热图 | Fig54D | [Fig2Q_ModelDecisionHeatmap.m](Fig2Q_ModelDecisionHeatmap.m#L1) |
| 2R-S-T-U | 共享抑制连接、非行为细胞活动、噪声逆向学习及读出连接变化 | Fig55ABCD | [Fig2RSTU_ModelMechanismSummary.m](Fig2RSTU_ModelMechanismSummary.m#L1) |
| 2V | Transfer/TH inhibited模型学习曲线 | Fig63D | [Fig2V_ModelTHInhibitedLearningCurve.m](Fig2V_ModelTHInhibitedLearningCurve.m#L1) |
| 2W | TH抑制模型的分层E/I异质性 | Fig63E | [Fig2W_ModelLayerNeuronHeterogeneity.m](Fig2W_ModelLayerNeuronHeterogeneity.m#L1) |

# 数据与配色

- 未找到可复用的原共享模型结果，因此调用中文脚本原来的 `BuildFig382383SharedModelData`，固定 `SeedBase=38238307`、50只模拟鼠、8个正式block、每block 30 trial、10000次置换及 `PermutationSeed=1`；结果通过原有验收。不修改模型参数、训练流程或显著性阈值。
- [LoadRnnFigureData.m](../+TransferLearning/LoadRnnFigureData.m#L1) 将共享结果持久缓存至 `TransferLearning.CachePath`。阶段权重、决策热图及机制诊断分别缓存，重跑图不会重复计算同一结果；读取缓存时检查当前模型参数。
- 条形和直方图使用当前 `ColorNaive`、`ColorLearned`、`Color12h`、`ColorTH` 原色并除以255。Transfer对应Color12h，TH inhibited对应ColorTH。
- 学习曲线和机制曲线使用 `CurveNaive`、`Curve12h`、`CurveTH`，再除以255，以保持白底可读；不把0-255的RGB直接交给MATLAB。
- 结构图和E/I饼图沿用源图的蓝色兴奋性、红色抑制性区分，使用当前Mocha蓝/红色值；在这些图里蓝/红表示神经元类型，不表示Miss/Naive条件。结构图中的数量和TH教学缩放从当前参数读取，当前E/I总数为128/32。
- 热图连续色阶改为当前Mocha蓝-白-红，原始响应、排序、时间点保留及颜色范围计算不变。
- 学习曲线保留预计算sigmoid拟合、逐block跨鼠均值和SEM，以及前七block/全block的Two-way ANOVA组效应。分组条形图继续使用源图的默认BarScatterCompare统计，不用秩和结果替代默认显示P值。
- 机制诊断仍按源脚本报告秩和检验；其条形显示P值沿用BarScatterCompare默认结果。两种P值不是同一统计方法，不应混写。
- 现有英文Fig5等旧版脚本保留，未改号或删除；中文脚本也保留。四个共享绘图函数中的失效颜色引用已修正，因此重新运行对应中文图时也会使用当前配色。