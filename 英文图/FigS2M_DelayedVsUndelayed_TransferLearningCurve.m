% FigS2M（英文图）：有延迟 vs 无延迟的 Transfer 学习曲线（LightWater，两条线）。
%
% 组别：
% - Undelayed（实线）：英文图/FigS1D_UndelayedLearningCurveAndFirstBlock.m 的 Transfer 口径
%   （AudioLightBaseline + ALPureBehavior）。
% - Delayed（虚线）：英文图/Fig1B_LearningCurve_Sigmoid.m 的 AL Light 口径
%   （A2L_L_0928.mat：cue 1 s，给水在 cue + 2.5 s）。
%
% 口径：每鼠每 session 一个 block（同一天多个 block 取会话均值），横轴为每鼠 block 序号；
% errorbar 为组均值±SEM，实线/虚线为组水平 sigmoid 拟合（下渐近线固定 0、上渐近线固定 1，同 Fig1B），
% p 线取 blocks 1-7 的线性混合模型 Group 效应；两组均只显示前 10 个 block（同 FigS1D）。
%
% 执行方式（硬性要求）：本文件保持为脚本，在 MATLAB Editor 中直接 Run/F5。

% --- 0) Ensure project loaded
if ~exist('TransferLearning', 'class') || ~exist('UniExp.DataSet', 'class')
	thisFile = mfilename('fullpath');
	thisDir = fileparts(thisFile);
	prjFile = fullfile(thisDir, '..', 'Transferlearning.prj');
	if exist(prjFile, 'file')
		matlab.project.loadProject(prjFile);
	end
end

%% 1) 数据
Undelayed = TransferLearning.DelayComparison.CohortBlocks("UndelayedImagingTransfer");
Delayed   = TransferLearning.DelayComparison.CohortBlocks("DelayedBehaviorTransfer");
Undelayed = TransferLearning.DelayComparison.AddBlockIndex(Undelayed);
Delayed   = TransferLearning.DelayComparison.AddBlockIndex(Delayed);

nMiceUndelayed = numel(unique(Undelayed.Mouse));
nMiceDelayed   = numel(unique(Delayed.Mouse));
fprintf('Undelayed (FigS1D): %d mice, %d sessions\n', nMiceUndelayed, height(Undelayed));
fprintf('Delayed (Fig1B): %d mice, %d sessions\n', nMiceDelayed, height(Delayed));

nBlocksShow = 10;
xMax = max([Undelayed.Block; Delayed.Block]);
X = (1:xMax).';
[MeanU, SemU] = TransferLearning.DelayComparison.CurveSummary(Undelayed, X);
[MeanD, SemD] = TransferLearning.DelayComparison.CurveSummary(Delayed, X);

% 拟合规格统一为 Fig1B 口径：下渐近线固定 0、上渐近线固定 1；拟合用全部 block（同 FigS1D）
FitU = TransferLearning.DelayComparison.FitSigmoidGroup(Undelayed, "Undelayed", true);
FitD = TransferLearning.DelayComparison.FitSigmoidGroup(Delayed, "Delayed", true);
fprintf('Sigmoid slope (lower fixed at 0): undelayed=%.4f, delayed=%.4f\n', FitU.Slope, FitD.Slope);

% 显示只取前 nBlocksShow 个 block（同 FigS1D）
nPlot = min(nBlocksShow, xMax);
X = X(1:nPlot);
MeanU = MeanU(1:nPlot);
SemU = SemU(1:nPlot);
MeanD = MeanD(1:nPlot);
SemD = SemD(1:nPlot);

% 组间 p（blocks 1-7，线性混合模型 Group 效应；口径同 Fig1B）
Cmp = [Undelayed; Delayed];
Cmp.Group(:) = [repmat("Undelayed", height(Undelayed), 1); repmat("Delayed", height(Delayed), 1)];
Cmp = Cmp(Cmp.Block <= 7, :);
groupP = TransferLearning.Style.TwoWayAnovaGroupPValue(Cmp, 'Performance', 'Block', 'Group', 'Mouse');
fprintf('Group effect P (blocks 1-7) = %.4g\n', groupP);

%% 2) 绘图（参 Fig1B：errorbar 均值±SEM + 组水平 sigmoid + p 线）
f = figure('Color', 'w', 'Name', 'FigS2M delayed vs undelayed transfer learning curve');
f.Units = 'centimeters';
f.Position(3:4) = [12, 8];
f.PaperUnits = 'centimeters';
f.PaperSize = [12, 8];
f.PaperPositionMode = 'auto';

ax = axes(f);
hold(ax, 'on');
ax.FontSize = 12;
ax.LineWidth = 2;
ax.Color = 'none';
box(ax, 'off');

colorTransfer = TransferLearning.TransferColor;

% 实心圆+实线 = undelayed；空心方+虚线 = delayed
hU = errorbar(ax, X, MeanU, SemU, 'o', 'Color', colorTransfer, ...
	'MarkerFaceColor', colorTransfer, 'MarkerEdgeColor', colorTransfer, 'MarkerSize', 5, ...
	'LineWidth', 1.5, 'CapSize', 4, 'LineStyle', 'none');
hD = errorbar(ax, X, MeanD, SemD, 's', 'Color', colorTransfer, ...
	'MarkerFaceColor', 'w', 'MarkerEdgeColor', colorTransfer, 'MarkerSize', 6, ...
	'LineWidth', 1.5, 'CapSize', 4, 'LineStyle', 'none');

xFit = linspace(0, nPlot, 200).';
plot(ax, xFit, TransferLearning.DelayComparison.SigmoidCurve(FitU, xFit), '-', ...
	'Color', colorTransfer, 'LineWidth', 2, 'HandleVisibility', 'off');
plot(ax, xFit, TransferLearning.DelayComparison.SigmoidCurve(FitD, xFit), '--', ...
	'Color', colorTransfer, 'LineWidth', 2, 'HandleVisibility', 'off');

% 图例用不可见的 line+marker 代理，使线型（实线/虚线）与填充（实心/空心）同时出现在图例里
hLU = plot(ax, NaN, NaN, '-o', 'Color', colorTransfer, 'LineWidth', 2, ...
	'MarkerFaceColor', colorTransfer, 'MarkerEdgeColor', colorTransfer, 'MarkerSize', 5);
hLD = plot(ax, NaN, NaN, '--s', 'Color', colorTransfer, 'LineWidth', 2, ...
	'MarkerFaceColor', 'w', 'MarkerEdgeColor', colorTransfer, 'MarkerSize', 6);

% p 线：横跨 blocks 1-7，贴组均值上缘
max7 = min(7, nPlot);
yTop7 = max([max(MeanU(1:max7)), max(MeanD(1:max7))]);
yPLine = yTop7 + 0.06;
textY = yPLine + 0.05;
plot(ax, [1, 7], [yPLine, yPLine], 'k-', 'LineWidth', 1, 'HandleVisibility', 'off');
if groupP < 0.001
	starStr = '＊＊＊＊';
else
	starStr = TransferLearning.Style.iFormatPText(groupP);
end
text(ax, 4, textY, starStr, 'HorizontalAlignment', 'center', ...
	'VerticalAlignment', 'top', 'FontSize', 12, 'HandleVisibility', 'off');

xlabel(ax, 'Block', 'FontSize', 12);
ylabel(ax, 'Hit rate', 'FontSize', 12);
ylim(ax, [0, yPLine + 0.14]);
yt = yticks(ax);
yticks(ax, yt(yt <= 1 + 1e-6));
xticks(ax, 1:nPlot);

lgd = legend(ax, [hLU, hLD], ...
	{sprintf('Undelayed (n=%d)', nMiceUndelayed), ...
	 sprintf('Delayed (n=%d)', nMiceDelayed)}, ...
	'Location', 'southeast', 'FontSize', 10, 'Box', 'off');
lgd.AutoUpdate = 'off';

allAxes = findall(f, 'Type', 'axes');
for axItem = reshape(allAxes, 1, [])
	if isprop(axItem, 'Toolbar') && ~isempty(axItem.Toolbar)
		axItem.Toolbar.Visible = 'off';
	end
end

svgPath = TransferLearning.ExportStandardFigure(f, 2, 'English_FigS2M_DelayedVsUndelayed_TransferLearningCurve.svg');
fprintf('Wrote: %s\n', svgPath);

assignin('base', 'FigS2M_UndelayedBlocks', Undelayed);
assignin('base', 'FigS2M_DelayedBlocks', Delayed);
assignin('base', 'FigS2M_SigmoidFit', table(["Undelayed";"Delayed"], [FitU.Slope; FitD.Slope], ...
	[FitU.Midpoint; FitD.Midpoint], [FitU.RSquared; FitD.RSquared], ...
	'VariableNames', {'Group','Slope','Midpoint','RSquared'}));
assignin('base', 'FigS2M_GroupP', groupP);
