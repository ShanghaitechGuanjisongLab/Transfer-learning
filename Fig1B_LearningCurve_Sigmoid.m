% Fig1B trial-wise hit rate: Naive vs Continual LightWater sessions
%
% Output:
% - SVG figure to \\Data-Server-2\个人数据\杨青宁\202605
% - Excel workbook with per-trial data and group summary
% - script copy to the same directory

outDirUNC = '\\Data-Server-2\个人数据\杨青宁\202605';
svgName = 'Fig1B_LearningCurve_Trialwise.svg';
excelName = 'Fig1B_LearningCurve_Trialwise.xlsx';
scriptCopyName = 'Fig1B_LearningCurve_Sigmoid.m';

targetTrialCount = 30;

if ~exist('UniExp.DataSet', 'class')
	thisFile = mfilename('fullpath');
	thisDir = fileparts(thisFile);
	prjFile = fullfile(thisDir, 'Transferlearning.prj');
	if ~exist(prjFile, 'file')
		prjFile = fullfile(thisDir, '..', 'Transferlearning.prj');
	end
	if exist(prjFile, 'file')
		matlab.project.loadProject(prjFile);
	end
end

LAB  = UniExp.DataSet('\\Data-Server-2\个人数据\张天夫\202512\光声迁移无穿插MOp成像（含学会后三次）.v3.mat');
ALB  = UniExp.DataSet('\\Data-Server-2\个人数据\张天夫\202512\声光迁移MOp成像（含学会后三次）.v5.mat');
LAPB = UniExp.DataSet('\\Data-Server-2\个人数据\张天夫\202601\基本迁移行为 光水转声水.v3.mat');
ALPB = UniExp.DataSet('\\Data-Server-2\个人数据\张天夫\202511\基本迁移行为 声水转光水.v2.mat');
LAI  = UniExp.DataSet('\\data-server-2\个人数据\张天夫\202601\光声迁移MOp成像有穿插.v5.mat');

naiveA = iLightWaterTrialsForStage(LAB,  'LightAudioBaseline', 'Naive', false);
naiveB = iLightWaterTrialsForStage(LAPB, 'LAPureBehavior',     'Naive', false);
naiveC = iLightWaterTrialsForStage(LAI,  'LAInterspersed',     'Naive', true);
contA  = iLightWaterTrialsForStage(ALB,  'AudioLightBaseline', 'Transfer', false);
contB  = iLightWaterTrialsForStage(ALPB, 'ALPureBehavior',     'Transfer', false);

naive = [naiveA; naiveB; naiveC];
continual = [contA; contB];
naive.Group(:) = "Naive";
continual.Group(:) = "Continual";

iAssertNoCrossSourceDuplicateMice(naive, "Naive");
iAssertNoCrossSourceDuplicateMice(continual, "Continual");

allTrials = [naive; continual];
iAssertNoMouseAppearsInMultipleGroups(allTrials);
if isempty(allTrials)
	error('Fig1B_Trialwise:EmptyData', 'No LightWater trial data found for Fig1B trial-wise plot.');
end

selectedNaive = iSelectOneSessionPerMouse(naive, targetTrialCount, "Naive");
selectedContinual = iSelectOneSessionPerMouse(continual, targetTrialCount, "Continual");

if isempty(selectedNaive) || isempty(selectedContinual)
	error('Fig1B_Trialwise:InsufficientSelectedSessions', 'Naive or Continual group has no valid 30-trial session after filtering.');
end

selectedTrials = [selectedNaive; selectedContinual];
selectedTrials = sortrows(selectedTrials, {'Group', 'Mouse', 'Trial'});

summaryNaive = iSummarizeTrials(selectedNaive, targetTrialCount, "Naive");
summaryContinual = iSummarizeTrials(selectedContinual, targetTrialCount, "Continual");
summaryTable = [summaryNaive; summaryContinual];

f = figure('Color', 'w', 'Name', 'Fig1B trial-wise learning curve');
f.Units = 'centimeters';
f.Position(3:4) = [12, 8.5];
ax = axes(f);
hold(ax, 'on');

palette = TransferLearning.FigurePalette(2);
hNaive = iPlotMeanSem(ax, summaryNaive, palette(1,:));
hContinual = iPlotMeanSem(ax, summaryContinual, palette(2,:));

xlabel(ax, 'Trial', 'FontSize', 12);
ylabel(ax, 'Hit rate', 'FontSize', 12);
xlim(ax, [1 targetTrialCount]);
ylim(ax, [0 1.02]);
ax.FontSize = 12;
box(ax, 'off');
grid(ax, 'off');
lg = legend(ax, [hNaive, hContinual], ...
	{sprintf('Naive (n=%d)', numel(unique(string(selectedNaive.Mouse)))), ...
	 sprintf('Continual (n=%d)', numel(unique(string(selectedContinual.Mouse))))}, ...
	'Location', 'southoutside');
lg.Box = 'off';
lg.NumColumns = 2;
title(ax, 'Fig1B trial-wise LightWater hit rate', 'FontSize', 12, 'FontWeight', 'normal');

if ~isfolder(outDirUNC)
	mkdir(outDirUNC);
end

if isprop(ax, 'Toolbar') && ~isempty(ax.Toolbar)
	ax.Toolbar.Visible = 'off';
end

thisFile = mfilename('fullpath');
copyfile([thisFile, '.m'], fullfile(outDirUNC, scriptCopyName));
svgPath = fullfile(outDirUNC, svgName);
exportgraphics(f, svgPath, 'ContentType', 'vector');

excelPath = fullfile(outDirUNC, excelName);
perTrialTable = selectedTrials(:, {'Group', 'Mouse', 'Source', 'DateTime', 'Trial', 'Hit', 'TotalHitRate', 'ValidTrialCount'});
perTrialTable.Properties.VariableNames = {'Group', 'Mouse', 'Source', 'DateTime', 'Trial', 'IsHit', 'TotalHitRate', 'SelectedSessionValidTrialCount'};
sessionTable = unique(selectedTrials(:, {'Group', 'Mouse', 'Source', 'DateTime', 'TotalHitRate', 'ValidTrialCount'}), 'rows');
sessionTable.Properties.VariableNames = {'Group', 'Mouse', 'Source', 'DateTime', 'TotalHitRate', 'SelectedSessionValidTrialCount'};
writetable(perTrialTable, excelPath, 'Sheet', 'PerTrial');
writetable(summaryTable, excelPath, 'Sheet', 'TrialSummary');
writetable(sessionTable, excelPath, 'Sheet', 'SelectedSession');

fprintf('Wrote: %s\n', svgPath);
fprintf('Wrote: %s\n', excelPath);
fprintf('Wrote: %s\n', fullfile(outDirUNC, scriptCopyName));
fprintf('Naive mice: %d\n', numel(unique(string(selectedNaive.Mouse))));
fprintf('Continual mice: %d\n', numel(unique(string(selectedContinual.Mouse))));

assignin('base', 'Fig1B_Trialwise_SelectedTrials', selectedTrials);
assignin('base', 'Fig1B_Trialwise_Summary', summaryTable);
assignin('base', 'Fig1B_Trialwise_PerTrial', perTrialTable);

function out = iLightWaterTrialsForStage(DS, sourceName, stageName, excludeAudioMixedNaive)
	T = iQueryLightWaterTrialRows(DS);
	if isempty(T)
		out = iEmptyTrialTable();
		return;
	end

	if excludeAudioMixedNaive && strcmpi(char(stageName), 'Naive')
		badMice = iFindMiceWithAudioWaterInStage(DS, stageName);
		if ~isempty(badMice)
			T = T(~ismember(T.Mouse, badMice), :);
		end
	end

	stageMask = strcmpi(cellstr(T.Stage), cellstr(string(stageName)));
	T = T(stageMask, :);
	if isempty(T)
		out = iEmptyTrialTable();
		return;
	end

	T.Source = repmat(string(sourceName), height(T), 1);
	out = T(:, {'Mouse', 'DateTime', 'Stage', 'Hit', 'Source', 'OrderInSession'});
end

function T = iQueryLightWaterTrialRows(DS)
	querySets = {
		["Mouse", "DateTime", "Stimulus", "Phase", "Behavior", "Performance"], ...
		["Mouse", "DateTime", "Stimulus", "Stage", "Behavior", "Performance"], ...
		["Mouse", "DateTime", "Stimulus", "Phase", "Behavior"], ...
		["Mouse", "DateTime", "Stimulus", "Stage", "Behavior"], ...
		["Mouse", "DateTime", "Stimulus", "Phase", "Performance"], ...
		["Mouse", "DateTime", "Stimulus", "Stage", "Performance"] ...
	};

	T = table;
	for iQuery = 1:numel(querySets)
		try
			T = DS.TableQuery(querySets{iQuery}, Stimulus="LightWater");
			break;
		catch
		end
	end

	if isempty(T)
		return;
	end

	T.Mouse = string(T.Mouse);
	T.DateTime = iNormalizeDateTime(T.DateTime);
	T.Stimulus = string(T.Stimulus);
	T = T(T.Stimulus == "LightWater", :);
	if isempty(T)
		return;
	end

	if ismember('Phase', T.Properties.VariableNames)
		T.Stage = string(T.Phase);
	elseif ismember('Stage', T.Properties.VariableNames)
		T.Stage = string(T.Stage);
	else
		T.Stage = repmat("", height(T), 1);
	end

	if ismember('Behavior', T.Properties.VariableNames)
		hit = double(T.Behavior);
	else
		hit = double(T.Performance);
	end
	hit(~ismember(hit, [0, 1])) = NaN;
	T.Hit = hit;

	T.SourceRow = (1:height(T)).';
	T = sortrows(T, {'Mouse', 'DateTime', 'SourceRow'});
	groupId = findgroups(T.Mouse, T.DateTime);
	T.OrderInSession = iBuildSequentialIndex(groupId);
	T = T(:, {'Mouse', 'DateTime', 'Stage', 'Hit', 'OrderInSession'});
end

function dt = iNormalizeDateTime(dt)
	dt = datetime(dt);
	if isdatetime(dt) && ~isempty(dt.TimeZone)
		dt.TimeZone = '';
	end
end

function seq = iBuildSequentialIndex(groupId)
	seq = zeros(numel(groupId), 1);
	if isempty(groupId)
		return;
	end
	counts = accumarray(groupId, 1);
	startIdx = 1;
	for iGroup = 1:numel(counts)
		stopIdx = startIdx + counts(iGroup) - 1;
		seq(startIdx:stopIdx) = (1:counts(iGroup)).';
		startIdx = stopIdx + 1;
	end
end

function badMice = iFindMiceWithAudioWaterInStage(DS, stageName)
	try
		Ta = DS.TableQuery("Mouse", Stimulus="AudioWater", Phase=char(stageName));
	catch
		Ta = DS.TableQuery("Mouse", Stimulus="AudioWater", Stage=char(stageName));
	end
	if isempty(Ta) || ~ismember("Mouse", string(Ta.Properties.VariableNames))
		badMice = string.empty(0, 1);
		return;
	end
	badMice = unique(string(Ta.Mouse));
end

function selected = iSelectOneSessionPerMouse(T, targetN, groupName)
	if isempty(T)
		selected = iEmptySelectedTrialTable();
		return;
	end

	T.Mouse = string(T.Mouse);
	T.Group = string(T.Group);
	T = sortrows(T, {'Mouse', 'DateTime', 'OrderInSession'});
	[sessionId, mouseVals, dtVals, groupVals, sourceVals] = findgroups(T.Mouse, T.DateTime, T.Group, T.Source);
	validCounts = splitapply(@(x) sum(isfinite(x)), T.Hit, sessionId);
	candidateMask = (validCounts == targetN) | (validCounts > targetN & validCounts < targetN + 5);
	if ~any(candidateMask)
		error('Fig1B_Trialwise:NoCandidateSession', 'Group %s has no session with %d to %d valid trials.', char(groupName), targetN, targetN + 4);
	end

	sessionSummary = table((1:max(sessionId)).', mouseVals, dtVals, groupVals, sourceVals, validCounts, candidateMask, ...
		'VariableNames', {'SessionId', 'Mouse', 'DateTime', 'Group', 'Source', 'ValidTrialCount', 'IsCandidate'});
	sessionSummary = sessionSummary(sessionSummary.IsCandidate, :);
	mice = unique(sessionSummary.Mouse, 'stable');
	selectedCell = cell(numel(mice), 1);
	for iMouse = 1:numel(mice)
		mouseRows = sessionSummary(sessionSummary.Mouse == mice(iMouse), :);
		if isempty(mouseRows)
			continue;
		end
		mouseRows.DiffFromTarget = abs(mouseRows.ValidTrialCount - targetN);
		mouseRows = sortrows(mouseRows, {'DiffFromTarget', 'DateTime'});
		bestSessionId = mouseRows.SessionId(1);
		selectedCell{iMouse} = iBuildSelectedTrialRows(T(sessionId == bestSessionId, :), targetN);
	end
	selectedCell = selectedCell(~cellfun(@isempty, selectedCell));
	if isempty(selectedCell)
		selected = iEmptySelectedTrialTable();
		return;
	end
	selected = vertcat(selectedCell{:});
end

function out = iBuildSelectedTrialRows(sessionRows, targetN)
	sessionRows = sortrows(sessionRows, 'OrderInSession');
	validMask = isfinite(sessionRows.Hit);
	validRows = sessionRows(validMask, :);
	validCount = height(validRows);
	if validCount == targetN
		keepRows = validRows;
	elseif validCount > targetN && validCount < targetN + 5
		keepIdx = iCenterWindow(validCount, targetN);
		keepRows = validRows(keepIdx, :);
	else
		out = iEmptySelectedTrialTable();
		return;
	end

	keepRows.Trial = (1:targetN).';
	keepRows.TotalHitRate = repmat(mean(keepRows.Hit, 'omitnan'), targetN, 1);
	keepRows.ValidTrialCount = repmat(validCount, targetN, 1);
	out = keepRows(:, {'Group', 'Mouse', 'Source', 'DateTime', 'Trial', 'Hit', 'TotalHitRate', 'ValidTrialCount'});
end

function keepIdx = iCenterWindow(totalCount, targetN)
	extra = totalCount - targetN;
	dropHead = floor(extra / 2);
	firstIdx = dropHead + 1;
	lastIdx = firstIdx + targetN - 1;
	keepIdx = (firstIdx:lastIdx).';
end

function summary = iSummarizeTrials(T, targetN, groupName)
	trialAxis = (1:targetN).';
	meanHitRate = nan(targetN, 1);
	semHitRate = nan(targetN, 1);
	nMouse = zeros(targetN, 1);
	for iTrial = 1:targetN
		rows = T.Trial == iTrial & isfinite(T.Hit);
		x = double(T.Hit(rows));
		nMouse(iTrial) = numel(x);
		if isempty(x)
			continue;
		end
		meanHitRate(iTrial) = mean(x, 'omitnan');
		if numel(x) > 1
			semHitRate(iTrial) = std(x, 0, 'omitnan') / sqrt(numel(x));
		else
			semHitRate(iTrial) = 0;
		end
	end
	summary = table(repmat(string(groupName), targetN, 1), trialAxis, meanHitRate, semHitRate, nMouse, ...
		'VariableNames', {'Group', 'Trial', 'MeanHitRate', 'SemHitRate', 'MouseCount'});
end

function hLine = iPlotMeanSem(ax, summary, lineColor)
	x = double(summary.Trial);
	y = double(summary.MeanHitRate);
	s = double(summary.SemHitRate);
	fillX = [x; flipud(x)];
	fillY = [y - s; flipud(y + s)];
	patch(ax, fillX, fillY, lineColor, 'FaceAlpha', 0.18, 'EdgeColor', 'none');
	hLine = plot(ax, x, y, '-', 'Color', lineColor, 'LineWidth', 2.2);
	plot(ax, x, y, 'o', 'Color', lineColor, 'MarkerFaceColor', 'w', 'MarkerSize', 4, 'LineWidth', 1);
end

function iAssertNoCrossSourceDuplicateMice(T, groupName)
	if isempty(T)
		return;
	end
	T.Mouse = string(T.Mouse);
	T.Source = string(T.Source);
	[groupId, mice] = findgroups(T.Mouse);
	nSource = splitapply(@(x) numel(unique(string(x))), T.Source, groupId);
	dup = mice(nSource > 1);
	if ~isempty(dup)
		msgLines = strings(numel(dup), 1);
		for iMouse = 1:numel(dup)
			mouseName = dup(iMouse);
			sourceNames = unique(T.Source(T.Mouse == mouseName));
			msgLines(iMouse) = mouseName + ": " + strjoin(sourceNames, ",");
		end
		error('Fig1B_Trialwise:DuplicateMouseAcrossSources', 'Group %s has duplicated mice across sources.\n%s', char(groupName), char(strjoin(msgLines, newline)));
	end
end

function iAssertNoMouseAppearsInMultipleGroups(T)
	if isempty(T)
		return;
	end
	T.Mouse = string(T.Mouse);
	T.Group = string(T.Group);
	[groupId, mice] = findgroups(T.Mouse);
	nGroup = splitapply(@(x) numel(unique(string(x))), T.Group, groupId);
	dup = mice(nGroup > 1);
	if ~isempty(dup)
		msgLines = strings(numel(dup), 1);
		for iMouse = 1:numel(dup)
			mouseName = dup(iMouse);
			groupNames = unique(T.Group(T.Mouse == mouseName));
			msgLines(iMouse) = mouseName + ": " + strjoin(groupNames, ",");
		end
		error('Fig1B_Trialwise:MouseInMultipleGroups', 'Some mice appear in multiple groups.\n%s', char(strjoin(msgLines, newline)));
	end
end

function T = iEmptyTrialTable()
	T = table(string.empty(0, 1), NaT(0, 1), string.empty(0, 1), nan(0, 1), string.empty(0, 1), nan(0, 1), ...
		'VariableNames', {'Mouse', 'DateTime', 'Stage', 'Hit', 'Source', 'OrderInSession'});
end

function T = iEmptySelectedTrialTable()
	T = table(string.empty(0, 1), string.empty(0, 1), string.empty(0, 1), NaT(0, 1), nan(0, 1), nan(0, 1), nan(0, 1), nan(0, 1), ...
		'VariableNames', {'Group', 'Mouse', 'Source', 'DateTime', 'Trial', 'Hit', 'TotalHitRate', 'ValidTrialCount'});
end
