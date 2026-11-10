% 英文图1N：光水任务Naive/7 d的完整学习曲线，沿用1L的均值±SEM画法。
% Naive取LightAudioBaseline + LAPureBehavior + LAInterspersed，排除LAI在Naive阶段已有声水经验的鼠；7 d取Vacation7。
% 每个Mouse×DateTime先计算光水命中率，再按逐鼠会话序号汇总；不按首次100%命中率截断。
% 图中标注前7个block的LMM Group效应p，配色为ColorNaive/255和Color7d/255。
% 独立运行，输出English_Fig1N_LightWater_NaiveVs7d_LearningCurve.svg。

thisDir = fileparts(mfilename('fullpath'));
if ~exist('UniExp.DataSet', 'class')
	prjFile = fullfile(thisDir, '..', 'Transferlearning.prj');
	if exist(prjFile, 'file'), matlab.project.loadProject(prjFile); end
end

naiveSessions = TransferLearning.DelayComparison.CohortBlocks("UndelayedImagingNaive");
naiveSessions = naiveSessions(isfinite(naiveSessions.Performance), :);
naiveSessions.Group = repmat("Naive", height(naiveSessions), 1);
naiveSessions.ImagingCohort = string(naiveSessions.Source) ~= "LAPureBehavior";
gapSessions = TransferLearning.DelayComparison.LightSessionTable(TransferLearning.Vacation7(), "LightWater", "Transfer", "Final");
gapSessions = gapSessions(isfinite(gapSessions.Performance) & gapSessions.NTrial > 0, :);
gapSessions.Source = repmat("Vacation7", height(gapSessions), 1);
gapSessions.Group = repmat("7 d", height(gapSessions), 1);
gapSessions.ImagingCohort = true(height(gapSessions), 1);
sessionColumns = {'Mouse', 'DateTime', 'Performance', 'Source', 'Group', 'ImagingCohort'};
allSessions = [naiveSessions(:, sessionColumns); gapSessions(:, sessionColumns)];
if isempty(allSessions), error('Fig1N:EmptyData', '没有有效的光水学习会话。'); end
iValidateMice(allSessions);
allSessions = TransferLearning.DelayComparison.AddBlockIndex(allSessions);
cohorts = ["Naive", "7 d"];
for cohortIndex = 1:numel(cohorts)
	if numel(unique(allSessions.Mouse(allSessions.Group == cohorts(cohortIndex)))) < 2
		error('Fig1N:InsufficientMice', '%s至少需要两只有效鼠。', cohorts(cohortIndex));
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

groupColors = [TransferLearning.ColorNaive; TransferLearning.Color7d] / 255;
meanCurves = cell(1, 2); semCurves = cell(1, 2); xCurves = cell(1, 2);
for cohortIndex = 1:2
	use = summaryCurve.Group == cohorts(cohortIndex);
	meanCurves{cohortIndex} = summaryCurve.Mean(use);
	semCurves{cohortIndex} = summaryCurve.SEM(use);
	xCurves{cohortIndex} = summaryCurve.Block(use);
end

fig = figure('Color', 'w', 'Name', 'English Fig1N LightWater Naive vs 7d learning curve');
fig.Units = 'centimeters'; fig.Position(3:4) = [9, 8];
ax = axes(fig); hold(ax, 'on');
patches = MATLAB.Graphics.MultiShadowedLines(meanCurves, semCurves, X=xCurves, EdgeColors=groupColors);
legendHandle = legend(ax, patches(1:2), cellstr(cohorts), 'Location', 'best', 'Box', 'off');
legendHandle.Title.String = '💡💧';
legendHandle.Title.FontName = 'Segoe UI Emoji';
xlabel(ax, 'Block'); ylabel(ax, 'Hit rate');
title(ax, TransferLearning.Style.iFormatPText(groupP7));
box(ax, 'off'); grid(ax, 'off');
if isprop(ax, 'Toolbar') && ~isempty(ax.Toolbar), ax.Toolbar.Visible = 'off'; end
svgPath = TransferLearning.ExportStandardFigure(fig, 2, 'English_Fig1N_LightWater_NaiveVs7d_LearningCurve.svg');
fprintf('Wrote: %s\n', svgPath);

for cohortIndex = 1:2
	use = allSessions.Group == cohorts(cohortIndex);
	fprintf('%s：%d只鼠，%d个有效会话\n', cohorts(cohortIndex), numel(unique(allSessions.Mouse(use))), sum(use));
end
fprintf('前7个block的LMM Group p=%.8g；全曲线p=%.8g\n', groupP7, groupPAll);
matPath = TransferLearning.CachePath('English_Fig1N_LightWaterLearningCurve.mat');
save(matPath, 'allSessions', 'summaryCurve', 'statistics', 'svgPath');
writetable(summaryCurve, fullfile(fileparts(matPath), 'English_Fig1N_LightWaterLearningCurve_Summary.csv'));
assignin('base', 'Fig1N_LightWaterLearningSessions', allSessions);
assignin('base', 'Fig1N_LightWaterLearningSummary', summaryCurve);
assignin('base', 'Fig1N_LightWaterLearningStatistics', statistics);

%% 局部函数
function iValidateMice(sessions)
[groupId, mice] = findgroups(sessions.Mouse);
sourceCounts = splitapply(@(values) numel(unique(values)), sessions.Source, groupId);
cohortCounts = splitapply(@(values) numel(unique(values)), sessions.Group, groupId);
duplicateMice = mice(sourceCounts > 1 | cohortCounts > 1);
if ~isempty(duplicateMice)
	error('Fig1N:DuplicateMouse', '同一鼠出现在多个来源或队列：%s。', strjoin(duplicateMice, ', '));
end
end