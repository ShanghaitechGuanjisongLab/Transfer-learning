始终用MCP工具执行MATLAB代码，不得用 matlab batch。修改代码后，自动运行输出图到`\\Data-Server-2\个人数据\张天夫\202602`，然后用fetch_images进行视觉验证。脚本撰写中尽量用向量化算法，避免循环。禁止使用 clear all 等非针对性的全局清理命令。，

取单回合数据用UniExp.DataSet.QueryNTS，取会话整体数据用UniExp.DataSet.QueryNTATS。两种方法都要使用ZScore归一化。两种方法都支持表格化批量查询，以及多条件查询，应尽量避免循环调用，而是将所有查询条件一次性输入。

所有图的高度必须是40㎜的整数倍；宽度必须是15㎜的整数倍，但不低于30㎜。所有字号设为6pt。

# 学习过程
对每只鼠，将其所有Block按DateTime排序。对Naive组每只鼠，包含从Phase=Naive到Phase=Learned之间的所有会话（包括Phase=missing的）；对其它鼠，则包含从Phase=Transfer到Phase=Final之间的所有会话（包括Phase=missing的）。然后，排除所有穿插了 AudioWater Trial 的会话。还要取这些会话的Performance，如果会话中不是只有 LightWater Trial，必须用仅 LightWater Trial 的Behavior手动计算Performance；纯LightWater会话则可以直接取用数据库中的Performance。然后，排除Performance达到100%及以后的会话。

# ΔHit
对每只鼠，取其学习过程所有会话，然后将相邻会话两两配对，则N个会话能配成N-1对。然后配对中的后一个会话的Performance减去前一个会话的Performance，即为ΔHit。

# 响应异质性（Response heterogeneity）
取计算范围内的 1s z-score，将所有回合或会话平均掉，取[-1,1]范围内的细胞，计算它们的标准差。

所有和学习曲线合成同一个脚本的条形图：必须使用透明背景，但不要显示xticklabels，而是用颜色和学习曲线保持对应关系，宽高都是40㎜。所有包含legend或colorbar的图：全脚本所有图使用12pt字号。

除非没有其它方法实现功能，否则禁用try-catch，一律fail-fast。

禁用LightWater、AudioWater等文本标注，一律用emoji标注为💡💧、🔊💧

所有plot线条、坐标轴线、MultiShadowedLines线、xline线、bar框线全部设置线宽为1磅。特别地，包含colorbar或legend的全脚本所有图线宽2磅。legend边框全部去掉。所有scatter的边缘宽0.2磅。