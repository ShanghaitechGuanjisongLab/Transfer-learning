% 英文图4D：12 h 光水迁移队列的 Sigmoid 斜率与合并层响应异质性相关。
% Sigmoid 使用完整原始学习曲线，下限固定 0、上限固定 1，斜率和中点自由；不排除学会后的 block。
% 响应异质性沿用统计报告的计算函数和会话筛选，两层结果按有效细胞数加权合并，每鼠仅一个点；这不是将两层原始细胞混合后重新计算标准差。
% 单面板使用普通坐标轴；输出 English_Fig4D_SigmoidSlopeVsHeterogeneity.svg，保持脚本形式，在 MATLAB 编辑器中运行（F5）。

thisDir = fileparts(mfilename('fullpath'));
if ~exist('UniExp.DataSet', 'class')
	prjFile = fullfile(thisDir, '..', 'Transferlearning.prj');
	if exist(prjFile, 'file')
		matlab.project.loadProject(prjFile);
	end
end

DS = TransferLearning.AudioLightBaseline();
behaviorSessions = TransferLearning.DelayComparison.CohortBlocks("UndelayedRecordingTransfer");
blockTable = TransferLearning.DelayComparison.AddBlockIndex(behaviorSessions);
fitTable = TransferLearning.DelayComparison.FitSigmoidPerMouse(blockTable, true);

heterogeneitySessions = iPreCeilingSessions(behaviorSessions);
heterogeneityTable = TransferLearning.Metrics.ResponseHeterogeneity(DS, heterogeneitySessions, "LightWater");
validLayers = ismember(string(heterogeneityTable.Layer), ["MOp2/3", "MOp5"]);
heterogeneityTable = heterogeneityTable(validLayers & isfinite(heterogeneityTable.SD) & heterogeneityTable.NCells > 0, :);
if isempty(heterogeneityTable)
	error('Fig4D:EmptyHeterogeneity', '没有可用于合并层相关分析的响应异质性数据。');
end

[poolGroup, mouseNames] = findgroups(string(heterogeneityTable.Mouse));
pooledValues = splitapply(@(spread, cellCounts) sum(spread .* cellCounts) / sum(cellCounts), heterogeneityTable.SD, heterogeneityTable.NCells, poolGroup);
pooledCellCounts = splitapply(@sum, heterogeneityTable.NCells, poolGroup);
pooledTable = table(mouseNames, pooledValues, pooledCellCounts, 'VariableNames', {'Mouse', 'Heterogeneity', 'NCells'});
plotData = innerjoin(fitTable, pooledTable, 'Keys', 'Mouse');
plotData = plotData(isfinite(plotData.Slope) & isfinite(plotData.Heterogeneity), :);
plotData = sortrows(plotData, 'Mouse');
nMice = height(plotData);
if nMice < 3 || std(plotData.Slope) == 0 || std(plotData.Heterogeneity) == 0
	error('Fig4D:InsufficientVariation', '相关分析至少需要三个有效鼠，且两个指标都必须有变异。');
end

[rho, pValue] = corr(plotData.Heterogeneity, plotData.Slope, 'Type', 'Spearman');
stats = table("12 h", nMice, rho, pValue, 'VariableNames', {'Group', 'NMice', 'SpearmanRho', 'PValue'});
%% 

f = figure('Color', 'w', 'Name', 'English Fig4D sigmoid slope vs response heterogeneity (12 h)');
f.Units = 'centimeters';
f.Position(3:4) = [6, 8];

groupColor = TransferLearning.Color12h / 255;
hScatter = scatter(plotData.Heterogeneity, plotData.Slope, 10, groupColor, 's', 'filled');
fitCoefficients = polyfit(plotData.Heterogeneity, plotData.Slope, 1);
xFit = [min(plotData.Heterogeneity), max(plotData.Heterogeneity)];
hold on;
plot( xFit, polyval(fitCoefficients, xFit), '-', 'Color', [0.5, 0.5, 0.5]);
xlabel('Response heterogeneity');
ylabel('Sigmoid slope');
title('Transfer')
annotationText = sprintf('ρ = %.2g\np = %.2g', rho, pValue);
text(0.03, 0.94, annotationText, 'Units', 'normalized', 'HorizontalAlignment', 'left', 'VerticalAlignment', 'top', 'FontSize', 12);

svgPath = TransferLearning.ExportStandardFigure(f, 2, 'English_Fig4D_SigmoidSlopeVsHeterogeneity.svg');

function selectedSessions = iPreCeilingSessions(sessions)
% 仅异质性排除首次命中率达到 100% 的会话及其后会话，并要求至少两个未学满会话；行为拟合不使用此筛选。
sessions = sortrows(sessions, {'Mouse', 'DateTime'});
keep = false(height(sessions), 1);
mouseNames = unique(string(sessions.Mouse), 'stable');
for mouseIndex = 1:numel(mouseNames)
	sessionIndices = find(string(sessions.Mouse) == mouseNames(mouseIndex));
	firstCeiling = find(double(sessions.Performance(sessionIndices)) >= 1 - 1e-12, 1, 'first');
	if isempty(firstCeiling)
		availableIndices = sessionIndices;
	else
		availableIndices = sessionIndices(1:firstCeiling - 1);
	end
	if numel(availableIndices) >= 2
		keep(availableIndices) = true;
	end
end
selectedSessions = sessions(keep, :);
end