% 英文图1L：声水任务Naive/Transfer的完整学习曲线，逐鼠按会话顺序对齐，显示均值±SEM。
% Naive取AudioLightBaseline + ALPureBehavior的Naive至Learned；Transfer取LightAudioBaseline + LAPureBehavior的Transfer至Final。
% 只取AudioWater回合，不按首次100%命中率截断；每个Mouse×DateTime先计算命中率，再进行跨鼠汇总。
% 图中标注前7个block的线性混合模型Group效应p，统计复用TwoWayAnovaGroupPValue。
% 配色为ColorNaive/255和Color12h/255；独立运行，输出English_Fig1L_AudioWater_NaiveVsTransfer_LearningCurve.svg。

thisDir = fileparts(mfilename('fullpath'));
if ~exist('UniExp.DataSet', 'class')
	prjFile = fullfile(thisDir, '..', 'Transferlearning.prj');
	if exist(prjFile, 'file'), matlab.project.loadProject(prjFile); end
end

sessionParts = {
	iAudioSessions(TransferLearning.AudioLightBaseline(), "AudioLightBaseline", "Naive", "Learned", "Naive", true)
	iAudioSessions(TransferLearning.ALPureBehavior(), "ALPureBehavior", "Naive", "Learned", "Naive", false)
	iAudioSessions(TransferLearning.LightAudioBaseline(), "LightAudioBaseline", "Transfer", "Final", "Transfer", true)
	iAudioSessions(TransferLearning.LAPureBehavior(), "LAPureBehavior", "Transfer", "Final", "Transfer", false)
};
allSessions = vertcat(sessionParts{:});
if isempty(allSessions), error('Fig1L:EmptyData', '没有有效的声水学习会话。'); end
iValidateMice(allSessions);
allSessions = TransferLearning.DelayComparison.AddBlockIndex(allSessions);
cohorts = ["Naive", "Transfer"];
for cohortIndex = 1:numel(cohorts)
	if numel(unique(allSessions.Mouse(allSessions.Group == cohorts(cohortIndex)))) < 2
		error('Fig1L:InsufficientMice', '%s至少需要两只有效鼠。', cohorts(cohortIndex));
	end
end

[groupId, groupNames, blockNumbers] = findgroups(allSessions.Group, allSessions.Block);
meanHitRate = splitapply(@mean, allSessions.Performance, groupId);
semHitRate = splitapply(@(values) std(values) / sqrt(numel(values)), allSessions.Performance, groupId);
mouseCounts = splitapply(@numel, allSessions.Performance, groupId);
summaryCurve = table(groupNames, blockNumbers, meanHitRate, semHitRate, mouseCounts, 'VariableNames', {'Group', 'Block', 'Mean', 'SEM', 'NMice'});
summaryCurve = sortrows(summaryCurve, {'Group', 'Block'});
sessions7 = allSessions(allSessions.Block <= 7, :);
groupP7 = TransferLearning.Style.TwoWayAnovaGroupPValue(sessions7, 'Performance', 'Block', 'Group', 'Mouse');
groupPAll = TransferLearning.Style.TwoWayAnovaGroupPValue(allSessions, 'Performance', 'Block', 'Group', 'Mouse');
statistics = table(groupP7, groupPAll, 'VariableNames', {'GroupPBlocks1To7', 'GroupPAllBlocks'});
%%

groupColors = [TransferLearning.ColorNaive; TransferLearning.Color12h] / 255;
meanCurves = cell(1, 2); semCurves = cell(1, 2); xCurves = cell(1, 2);
for cohortIndex = 1:2
	use = summaryCurve.Group == cohorts(cohortIndex);
	meanCurves{cohortIndex} = summaryCurve.Mean(use);
	semCurves{cohortIndex} = summaryCurve.SEM(use);
	xCurves{cohortIndex} = summaryCurve.Block(use);
end

fig = figure('Color', 'w', 'Name', 'English Fig1L AudioWater Naive vs Transfer learning curve');
fig.Units = 'centimeters'; fig.Position(3:4) = [9, 8];
ax = axes(fig); hold(ax, 'on');
patches = MATLAB.Graphics.MultiShadowedLines(meanCurves, semCurves, X=xCurves, EdgeColors=groupColors);
legendHandle = legend(ax, patches(1:2), cellstr(cohorts), 'Location', 'best', 'Box', 'off');
legendHandle.Title.String = '🔊💧';
legendHandle.Title.FontName = 'Segoe UI Emoji';
xlabel(ax, 'Block'); ylabel(ax, 'Hit rate');
title(ax, TransferLearning.Style.iFormatPText(groupP7));
box(ax, 'off'); grid(ax, 'off');
if isprop(ax, 'Toolbar') && ~isempty(ax.Toolbar), ax.Toolbar.Visible = 'off'; end
svgPath = TransferLearning.ExportStandardFigure(fig, 2, 'English_Fig1L_AudioWater_NaiveVsTransfer_LearningCurve.svg');
fprintf('Wrote: %s\n', svgPath);

for cohortIndex = 1:2
	use = allSessions.Group == cohorts(cohortIndex);
	fprintf('%s：%d只鼠，%d个有效会话\n', cohorts(cohortIndex), numel(unique(allSessions.Mouse(use))), sum(use));
end
fprintf('前7个block的LMM Group p=%.8g；全曲线p=%.8g\n', groupP7, groupPAll);
matPath = TransferLearning.CachePath('English_Fig1L_AudioWaterLearningCurve.mat');
save(matPath, 'allSessions', 'summaryCurve', 'statistics', 'svgPath');
writetable(summaryCurve, fullfile(fileparts(matPath), 'English_Fig1L_AudioWaterLearningCurve_Summary.csv'));
assignin('base', 'Fig1L_AudioWaterLearningSessions', allSessions);
assignin('base', 'Fig1L_AudioWaterLearningSummary', summaryCurve);
assignin('base', 'Fig1L_AudioWaterLearningStatistics', statistics);

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
	error('Fig1L:DuplicateMouse', '同一鼠出现在多个来源或队列：%s。', strjoin(duplicateMice, ', '));
end
end