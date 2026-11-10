% 英文图1M：声水任务Naive/Transfer首block命中率和Sigmoid斜率，用上下两个BarScatterCompare tile展示。
% 上图行为队列同1L：Naive=AudioLightBaseline + ALPureBehavior；Transfer=LightAudioBaseline + LAPureBehavior。
% 下图使用同一完整行为队列，逐鼠拟合固定上下限0和1的Sigmoid，不按首次100%命中率截断。
% 复用FitSigmoidPerMouse，只保留有效正斜率；显示概率空间最大瞬时斜率k/4，至少两个block且命中率有变化才纳入。
% 两个tile独立使用BarScatterCompare默认统计；配色为ColorNaive/255和Color12h/255。
% 独立运行，保留原脚本及SVG命名以兼容现有引用，下tile已改为Sigmoid slope。

thisDir = fileparts(mfilename('fullpath'));
if ~exist('UniExp.DataSet', 'class')
	prjFile = fullfile(thisDir, '..', 'Transferlearning.prj');
	if exist(prjFile, 'file'), matlab.project.loadProject(prjFile); end
end

ALB = TransferLearning.AudioLightBaseline();
LAB = TransferLearning.LightAudioBaseline();
sessionParts = {
	iAudioSessions(ALB, "AudioLightBaseline", "Naive", "Learned", "Naive", true)
	iAudioSessions(TransferLearning.ALPureBehavior(), "ALPureBehavior", "Naive", "Learned", "Naive", false)
	iAudioSessions(LAB, "LightAudioBaseline", "Transfer", "Final", "Transfer", true)
	iAudioSessions(TransferLearning.LAPureBehavior(), "LAPureBehavior", "Transfer", "Final", "Transfer", false)
};
allSessions = vertcat(sessionParts{:});
if isempty(allSessions), error('Fig1M:EmptyData', '没有有效的声水学习会话。'); end
iValidateMice(allSessions);
allSessions = TransferLearning.DelayComparison.AddBlockIndex(allSessions);
firstSessions = allSessions(allSessions.Block == 1, :);
slopeTable = TransferLearning.DelayComparison.FitSigmoidPerMouse(allSessions, true);
slopeTable = slopeTable(isfinite(slopeTable.Slope) & slopeTable.Slope > 0, :);
slopeTable.ProbabilitySlope = slopeTable.Slope / 4;

cohorts = ["Naive", "Transfer"];
metricLabels = ["First block hit rate", "Sigmoid slope"];
metricValues = cell(2, 2);
for cohortIndex = 1:2
	metricValues{1, cohortIndex} = firstSessions.Performance(firstSessions.Group == cohorts(cohortIndex));
	metricValues{2, cohortIndex} = slopeTable.ProbabilitySlope(slopeTable.Group == cohorts(cohortIndex));
	for metricIndex = 1:2
		if numel(metricValues{metricIndex, cohortIndex}) < 2
			error('Fig1M:InsufficientMice', '%s的%s至少需要两只有效鼠。', cohorts(cohortIndex), metricLabels(metricIndex));
		end
	end
end
%%

groupColors = [TransferLearning.ColorNaive; TransferLearning.Color12h] / 255;
fig = figure('Color', 'w');
fig.Units = 'centimeters'; fig.Position(3:4) = [4,8];
layout = tiledlayout(fig, 2, 1, 'TileSpacing', 'tight', 'Padding', 'tight');
axesHandles = gobjects(2, 1);
comparisonsByTile = cell(2, 1);
for metricIndex = 1:2
	ax = nexttile(layout, metricIndex);
	plotValues = metricValues(metricIndex, :);
	[~, optional, bars, errorBars] = UniExp.BarScatterCompare(plotValues, table([1 2], 'VariableNames', {'GroupPair'}), ax, UniExp.Flags.IndividualErrorbars, 'AsteriskThreshold', 0.05);
	iStyleBars(bars, errorBars, groupColors);
	xticks(ax, 1:2); xticklabels(ax, cohorts);
	if metricIndex == 1, xticklabels(ax, {}); end
	ylabel(ax, metricLabels(metricIndex));
	box(ax, 'off');
	axesHandles(metricIndex) = ax;
	comparisonsByTile{metricIndex} = optional.MultiCompare;
end
title(layout, '🔊💧');
MATLAB.Graphics.UnifyAxesLims(axesHandles, @xlim);
TransferLearning.ApplyStandardExportStyle(fig, 2);
for metricIndex = 1:numel(comparisonsByTile)
	comparison = comparisonsByTile{metricIndex};
	MATLAB.Graphics.PLineRetune(comparison.PLine, comparison.PText);
end
svgPath = TransferLearning.StandardFigureSvgPath('English_Fig1M_AudioWater_FirstBlockHitRateAndDivergence.svg');
print(fig, svgPath, '-dsvg');

%% 局部函数
function sessions = iAudioSessions(DS, source, startPhase, endPhase, group, imagingCohort)
sessions = TransferLearning.DelayComparison.LightSessionTable(DS, "AudioWater", startPhase, endPhase);
sessions = sessions(isfinite(sessions.Performance) & sessions.NTrial > 0, :);
sessions.Source = repmat(source, height(sessions), 1);
sessions.Group = repmat(group, height(sessions), 1);
sessions.ImagingCohort = repmat(imagingCohort, height(sessions), 1);
end

function iValidateMice(sessions)
[groupId, mice] = findgroups(sessions.Mouse);
sourceCounts = splitapply(@(values) numel(unique(values)), sessions.Source, groupId);
cohortCounts = splitapply(@(values) numel(unique(values)), sessions.Group, groupId);
duplicateMice = mice(sourceCounts > 1 | cohortCounts > 1);
if ~isempty(duplicateMice)
	error('Fig1M:DuplicateMouse', '同一鼠出现在多个来源或队列：%s。', strjoin(duplicateMice, ', '));
end
end

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

function iUnifyErrorBarCapSizes(axList, barHandlesList, errorBarsList, capSizeRatio)
capSizes = nan(numel(axList), 1);
for tileIndex = 1:numel(axList)
	ax = axList(tileIndex); units = ax.Units; ax.Units = 'points';
	axWidth = ax.Position(3); ax.Units = units;
	barHandles = barHandlesList{tileIndex};
	capSizes(tileIndex) = axWidth * barHandles(1).BarWidth * barHandles(1).GroupWidth * capSizeRatio / (diff(xlim(ax)) * numel(barHandles));
end
capSize = mean(capSizes, 'omitnan');
for tileIndex = 1:numel(errorBarsList)
	errorBars = errorBarsList{tileIndex};
	for errorIndex = 1:height(errorBars)
		errorBar = errorBars.Object(errorIndex);
		if isgraphics(errorBar) && isprop(errorBar, 'CapSize'), errorBar.CapSize = capSize; end
	end
end
end