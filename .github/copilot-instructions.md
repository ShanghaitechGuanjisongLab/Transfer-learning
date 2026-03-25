始终用MCP工具执行MATLAB代码，不得用 matlab batch。修改代码后，自动运行输出图到`\\Data-Server-2\个人数据\张天夫\yyyyMM`，其中yyyyMM为当前年月。运行结束返回后，再用fetch_images进行视觉验证（MATLAB运行和fetch_images不能同时运行）。脚本撰写中尽量用向量化算法，避免循环。禁止使用 clear all 等非针对性的全局清理命令。，

取单回合数据用UniExp.DataSet.QueryNTS，取会话整体数据用UniExp.DataSet.QueryNTATS。两种方法都要使用ZScore归一化。两种方法都支持表格化批量查询，以及多条件查询，应尽量避免循环调用，而是将所有查询条件一次性输入。

所有图的高度必须是40㎜的整数倍；宽度必须是15㎜的整数倍，但不低于30㎜。所有字号设为6pt。但是，所有包含legend或colorbar的图，全脚本所有图使用12pt字号。

# 学习过程
对每只鼠，将其所有Block按DateTime排序。对Naive组每只鼠，包含从Phase=Naive到Phase=Learned之间的所有会话（包括Phase=missing的）；对其它鼠，则包含从Phase=Transfer到Phase=Final之间的所有会话（包括Phase=missing的）。然后，排除所有穿插了 AudioWater Trial 的会话。还要取这些会话的Performance，如果会话中不是只有 LightWater Trial，必须用仅 LightWater Trial 的Behavior手动计算Performance；纯LightWater会话则可以直接取用数据库中的Performance。然后，排除Performance达到100%及以后的会话。

# ΔHit
对每只鼠，取其学习过程所有会话，然后将相邻会话两两配对，则N个会话能配成N-1对。然后配对中的后一个会话的Performance减去前一个会话的Performance，即为ΔHit。

# 响应异质性（Response heterogeneity）
取计算范围内的 1s z-score，将所有回合或会话平均掉，取[-1,1]范围内的细胞，计算它们的标准差。

所有和学习曲线合成同一个脚本的条形图：必须使用透明背景，但不要显示xticklabels，而是用颜色和学习曲线保持对应关系，宽高都是40㎜。

除非没有其它方法实现功能，否则禁用try-catch，一律fail-fast。

禁用LightWater、AudioWater等文本标注，一律用emoji标注为💡💧、🔊💧

所有plot线条、坐标轴线、MultiShadowedLines线、xline线全部设置线宽为1磅。特别地，包含colorbar或legend的全脚本所有图线宽2磅。但是，legend、colorbar和bar的边框线要全部去掉。所有scatter的边缘宽0.2磅。

凡是要求“模仿某张现有图”，必须先重读被模仿脚本，再逐项复用其关键参数与调用方式；禁止凭印象手改配色、色程、ylabel位置、标题、标签、图窗尺寸。

对 UniExp.LanearHeatmap，必须先查帮助或源码再决定调用方式。该函数明确支持 cell / struct 输入来绘制不对齐泳道；当不同泳道细胞数不同但用户仍要求统一热图风格时，优先单次调用 LanearHeatmap，禁止因为主观臆断而拆成两次调用，更禁止用手写 imagesc 替代。

热图如果要模仿既有图，默认应沿用原图的 LMHColor、Flags、CLim 计算逻辑、Layout 级 xlabel / ylabel、colorbar 放置方式；尤其要先核对整体观感是否与模板一致，避免把应当“白里透红”的图误画成整体偏蓝。

涉及细胞数标注时，先检查模板是轴级 ylabel 还是 layout 级 ylabel。若模板像 331A 那样使用 layout 级 ylabel 显示细胞数，则必须照搬这一层级，禁止自作主张改挂到单个 axis。

出现“初始”一词时，统一翻译为 Naive，不得写成 Initial。

对条形图，必须画单侧误差线；不能保留上下双帽的默认样式。

当我问你一个图改了之后还显不显著时，意思就是不显著就不要改图

配色顺序：[1,0,0;0,0,1;0,0,0;0,0.6809,0]

所有LanearHeatmap的CLim参数，设为实际数据范围最大最小值的平方根。

不得因为视觉检查变成方块就去掉emoji