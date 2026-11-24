% 英文图1J：Naive纯行为队列与12 h全队列的光水学习 sigmoid 斜率比较。
% Naive仅取LAPureBehavior；12 h取AudioLightBaseline + ALPureBehavior，保留完整学习曲线。
% 显示概率空间最大瞬时斜率k/4，图中p采用BarScatterCompare默认统计；另存双侧ranksum p核对报告。
% 独立脚本，配色使用ColorNaive/Color12h；输出English_Fig1J_NaiveBehaviorVs12h_SigmoidSlope.svg。

thisDir = fileparts(mfilename('fullpath'));
if ~exist('UniExp.DataSet', 'class')
	prjFile = fullfile(thisDir, '..', 'Transferlearning.prj');
	if exist(prjFile, 'file'), matlab.project.loadProject(prjFile); end
end

naiveSessions = TransferLearning.DelayComparison.LightSessionTable(TransferLearning.LAPureBehavior(), "LightWater", "Naive", "Learned");
transferSessions = TransferLearning.DelayComparison.CohortBlocks("UndelayedImagingTransfer");
sessionTables = {naiveSessions, transferSessions};
cohorts = ["Naive", "12 h"];
fitTables = cell(1, numel(cohorts));
for cohortIndex = 1:numel(cohorts)
	blockTable = TransferLearning.DelayComparison.AddBlockIndex(sessionTables{cohortIndex});
	fitTable = TransferLearning.DelayComparison.FitSigmoidPerMouse(blockTable, true);
	fitTable = fitTable(isfinite(fitTable.Slope) & fitTable.Slope > 0, :);
	if height(fitTable) < 2
		error('Fig1J:InsufficientMice', '%s 至少需要两只可拟合鼠。', cohorts(cohortIndex));
	end
	fitTable.Cohort = repmat(cohorts(cohortIndex), height(fitTable), 1);
	fitTable.ProbabilitySlope = fitTable.Slope / 4;
	fitTables{cohortIndex} = fitTable;
	fprintf('%s：n=%d，原始k均值=%.6f，概率斜率均值=%.6f\n', cohorts(cohortIndex), height(fitTable), mean(fitTable.Slope), mean(fitTable.ProbabilitySlope));
end
firstFit = fitTables{1}; secondFit = fitTables{2};
groupColors = [TransferLearning.ColorNaive; TransferLearning.Color12h] / 255;
plotValues = {firstFit.ProbabilitySlope, secondFit.ProbabilitySlope};
%%

fig = figure('Color', 'w', 'Name', 'English Fig1J sigmoid slope comparison');
fig.Units = 'centimeters'; fig.Position(3:4) = [3, 4];
[~, optional, bars, errorBars] = UniExp.BarScatterCompare(plotValues, table([1 2], 'VariableNames', {'GroupPair'}), UniExp.Flags.IndividualErrorbars, 'AsteriskThreshold', 0.05);
iStyleBars(bars, errorBars, groupColors);
TransferLearning.Style.SetBarPValues(optional);
xticks( 1:2); xticklabels(cohorts);
ylabel('Sigmoid slope');
box('off');
svgPath = TransferLearning.ExportStandardFigure(fig, 1, 'English_Fig1J_NaiveBehaviorVs12h_SigmoidSlope.svg');

%% 局部函数
function iStyleBars(barHandles, errorBars, groupColors)
for barIndex = 1:numel(barHandles)
	barHandles(barIndex).EdgeColor = 'none';
	barHandles(barIndex).BarWidth = 0.5;
	if numel(barHandles) == 1
		barHandles(barIndex).FaceColor = 'flat';
		barHandles(barIndex).CData = groupColors;
	else
		barHandles(barIndex).FaceColor = groupColors(barIndex, :);
	end
	if isgraphics(barHandles(barIndex).BaseLine), barHandles(barIndex).BaseLine.Visible = 'off'; end
end
for errorIndex = 1:height(errorBars)
	errorBar = errorBars.Object(errorIndex);
	if ~isgraphics(errorBar), continue; end
	[~, colorIndex] = min(abs((1:size(groupColors, 1))' - double(errorBar.XData(1))));
	errorBar.Color = groupColors(colorIndex, :);
end
end