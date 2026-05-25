% THInhibitVsCtrl learning curve using the same sigmoid and permutation
% significance method as Fig1B, restricted to the mice included by the
% current Ctrl/TH selection scope.
%
% Output:
% - SVG figure to \\Data-Server-2\个人数据\杨青宁\202605
% - CSV tables to the same directory
% - script copy to the same directory

outDirUNC = '\\Data-Server-2\个人数据\杨青宁\202605';
svgName = 'THInhibitVsCtrl_LearningCurve_Sigmoid.svg';
scriptCopyName = 'THInhibitVsCtrl_LearningCurve_Sigmoid.m';
fitCsvName = 'THInhibitVsCtrl_LearningCurve_SigmoidFit.csv';
summaryCsvName = 'THInhibitVsCtrl_LearningCurve_SigmoidSummary.csv';
permCsvName = 'THInhibitVsCtrl_LearningCurve_SigmoidPermutation.csv';
mouseCsvName = 'THInhibitVsCtrl_LearningCurve_SigmoidIncludedMice.csv';
statsTxtName = 'THInhibitVsCtrl_LearningCurve_SigmoidPermutation.txt';

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

CtrlDS = TransferLearning.AudioLightBaseline();
THDS = TransferLearning.THInhibit();

sessionForSummary = iBuildFig3GSessionSummary(CtrlDS, THDS);
if isempty(sessionForSummary)
	error('THInhibitVsCtrl_Sigmoid:EmptyData', 'No LightWater session data found for THInhibitVsCtrl sigmoid plot.');
end

sessionForSummary.Group = string(sessionForSummary.Group);
sessionForSummary.Mouse = string(sessionForSummary.Mouse);
sessionForSummary.DateTime = iNormalizeDateTime(sessionForSummary.DateTime);
sessionForSummary = unique(sessionForSummary(:, {'Mouse', 'DateTime', 'Performance', 'Group'}), 'rows');
sessionForSummary = sortrows(sessionForSummary, {'Group', 'Mouse', 'DateTime'});

Sess = sessionForSummary;
Sess = iAddSessionIndex(Sess);

[ctrlMice, thMice] = iSplitGroupMice(Sess);
[~, SummaryL] = evalc('UniExp.LearningSummarize(sessionForSummary)');
[meanMat, semMat, x] = iUnpackLearningSummarize(SummaryL, ["Ctrl", "TH"]);
nMat = iComputeNBySession(Sess, x, ["Ctrl", "TH"]);

displayedCtrl = Sess(string(Sess.Group) == "Ctrl", :);
displayedTH = Sess(string(Sess.Group) == "TH", :);

fitCtrl = iFitSigmoidCurve(displayedCtrl, "Ctrl", "fixed1");
fitTH = iFitSigmoidCurve(displayedTH, "TH", "free");
permResult = iPermutationTestSigmoidDifference(displayedCtrl, displayedTH, 10000, 1);

xFit = (1:max([max(fitCtrl.XObserved), max(fitTH.XObserved), max(x)])).';
ctrlFitCurve = iSigmoidFromFit(fitCtrl, xFit);
thFitCurve = iSigmoidFromFit(fitTH, xFit);

meanMatOut = nan(numel(xFit), size(meanMat, 2));
semMatOut = nan(numel(xFit), size(semMat, 2));
nMatOut = nan(numel(xFit), size(nMat, 2));
meanMatOut(1:size(meanMat, 1), :) = meanMat;
semMatOut(1:size(semMat, 1), :) = semMat;
nMatOut(1:size(nMat, 1), :) = nMat;

f = figure('Color', 'w', 'Name', 'THInhibitVsCtrl learning curve sigmoid');
f.Units = 'centimeters';
f.Position(3:4) = [16, 10.5];
t = tiledlayout(f, 1, 2, 'TileSpacing', 'loose', 'Padding', 'loose');

palette = TransferLearning.FigurePalette(2);
axCtrl = nexttile(t, 1);
iPlotGroupMouseCurves(axCtrl, displayedCtrl, xFit, ctrlFitCurve, palette(1,:), "Ctrl", fitCtrl);
axTH = nexttile(t, 2);
iPlotGroupMouseCurves(axTH, displayedTH, xFit, thFitCurve, palette(2,:), "TH", fitTH);

ylabel(axCtrl, 'Hit rate', 'FontSize', 12);
xlabel(axCtrl, 'Block', 'FontSize', 12);
xlabel(axTH, 'Block', 'FontSize', 12);
title(t, 'THInhibitVsCtrl learning curve sigmoid fit', 'FontSize', 12, 'FontWeight', 'normal');

if ~isfolder(outDirUNC)
	mkdir(outDirUNC);
end

allAxes = findall(f, 'Type', 'axes');
for ax = reshape(allAxes, 1, [])
	if isprop(ax, 'Toolbar') && ~isempty(ax.Toolbar)
		ax.Toolbar.Visible = 'off';
	end
end

thisFile = mfilename('fullpath');
copyfile([thisFile, '.m'], fullfile(outDirUNC, scriptCopyName));
svgPath = fullfile(outDirUNC, svgName);
exportgraphics(f, svgPath, 'ContentType', 'vector');

fitTable = table;
fitTable.Group = ["Ctrl"; "TH"];
fitTable.Lower = [fitCtrl.Lower; fitTH.Lower];
fitTable.Upper = [fitCtrl.Upper; fitTH.Upper];
fitTable.Slope = [fitCtrl.Slope; fitTH.Slope];
fitTable.Midpoint = [fitCtrl.Midpoint; fitTH.Midpoint];
fitTable.SSE = [fitCtrl.SSE; fitTH.SSE];
fitTable.RSquared = [fitCtrl.RSquared; fitTH.RSquared];
writetable(fitTable, fullfile(outDirUNC, fitCsvName));

permTable = table;
permTable.ObservedPooledSSE = permResult.ObservedPooledSSE;
permTable.ObservedSplitSSE = permResult.ObservedSplitSSE;
permTable.ObservedDeltaSSE = permResult.ObservedDeltaSSE;
permTable.PermutationPValue = permResult.PValue;
permTable.PermutationCount = permResult.NPermutation;
permTable.NullMeanDeltaSSE = mean(permResult.PermutedDeltaSSE, 'omitnan');
permTable.NullStdDeltaSSE = std(permResult.PermutedDeltaSSE, 'omitnan');
permTable.NullCI_Low = prctile(permResult.PermutedDeltaSSE, 2.5);
permTable.NullCI_High = prctile(permResult.PermutedDeltaSSE, 97.5);
writetable(permTable, fullfile(outDirUNC, permCsvName));

summaryTable = table;
summaryTable.Block = xFit(:);
summaryTable.CtrlLearningCurve = meanMatOut(:,1);
summaryTable.THLearningCurve = meanMatOut(:,2);
summaryTable.CtrlSem = semMatOut(:,1);
summaryTable.THSem = semMatOut(:,2);
summaryTable.CtrlN = nMatOut(:,1);
summaryTable.THN = nMatOut(:,2);
summaryTable.CtrlSigmoid = ctrlFitCurve(:);
summaryTable.THSigmoid = thFitCurve(:);
writetable(summaryTable, fullfile(outDirUNC, summaryCsvName));

includedMouseTable = table;
includedMouseTable.Group = [repmat("Ctrl", numel(ctrlMice), 1); repmat("TH", numel(thMice), 1)];
includedMouseTable.Mouse = [ctrlMice(:); thMice(:)];
writetable(includedMouseTable, fullfile(outDirUNC, mouseCsvName));

statsPath = fullfile(outDirUNC, statsTxtName);
fid = fopen(statsPath, 'w');
if fid < 0
	error('THInhibitVsCtrl_Sigmoid:OpenStatsTxtFailed', 'Cannot open %s for writing.', statsPath);
end
fprintf(fid, 'THInhibitVsCtrl sigmoid slope permutation test\n');
fprintf(fid, 'Observed pooled SSE: %.6f\n', permResult.ObservedPooledSSE);
fprintf(fid, 'Observed split SSE: %.6f\n', permResult.ObservedSplitSSE);
fprintf(fid, 'Observed delta SSE (pooled - split): %.6f\n', permResult.ObservedDeltaSSE);
fprintf(fid, 'Permutation count: %d\n', permResult.NPermutation);
fprintf(fid, 'Permutation p-value: %.6g\n', permResult.PValue);
fprintf(fid, 'Null delta SSE mean: %.6f\n', mean(permResult.PermutedDeltaSSE, 'omitnan'));
fprintf(fid, 'Null delta SSE std: %.6f\n', std(permResult.PermutedDeltaSSE, 'omitnan'));
fprintf(fid, 'Null delta SSE 95%% interval: [%.6f, %.6f]\n', prctile(permResult.PermutedDeltaSSE, 2.5), prctile(permResult.PermutedDeltaSSE, 97.5));
fclose(fid);

fprintf('Wrote: %s\n', svgPath);
fprintf('Wrote: %s\n', fullfile(outDirUNC, scriptCopyName));
fprintf('Wrote: %s\n', fullfile(outDirUNC, fitCsvName));
fprintf('Wrote: %s\n', fullfile(outDirUNC, summaryCsvName));
fprintf('Wrote: %s\n', fullfile(outDirUNC, permCsvName));
fprintf('Wrote: %s\n', fullfile(outDirUNC, mouseCsvName));
fprintf('Wrote: %s\n', statsPath);
fprintf('Ctrl sigmoid: lower=%.4f, upper=%.4f, slope=%.4f, midpoint=%.4f, R^2=%.4f\n', fitCtrl.Lower, fitCtrl.Upper, fitCtrl.Slope, fitCtrl.Midpoint, fitCtrl.RSquared);
fprintf('TH sigmoid: lower=%.4f, upper=%.4f, slope=%.4f, midpoint=%.4f, R^2=%.4f\n', fitTH.Lower, fitTH.Upper, fitTH.Slope, fitTH.Midpoint, fitTH.RSquared);
fprintf('Observed delta SSE (pooled - split): %.4f\n', permResult.ObservedDeltaSSE);
fprintf('Permutation p = %.4g (%d permutations)\n', permResult.PValue, permResult.NPermutation);

assignin('base', 'THInhibitVsCtrl_Sigmoid_Sessions', Sess);
assignin('base', 'THInhibitVsCtrl_Sigmoid_FitTable', fitTable);
assignin('base', 'THInhibitVsCtrl_Sigmoid_Summary', summaryTable);
assignin('base', 'THInhibitVsCtrl_Sigmoid_Permutation', permResult);
assignin('base', 'THInhibitVsCtrl_Sigmoid_IncludedMice', includedMouseTable);

function out = iLightWaterTrials(DS, sourceName)
	T = iQueryLightWaterTrialRows(DS);
	if isempty(T)
		out = iEmptyTrialTable();
		return;
	end
	T.Source = repmat(string(sourceName), height(T), 1);
	out = T(:, {'Mouse', 'DateTime', 'Stage', 'Hit', 'Source', 'OrderInSession'});
end

function sessionForSummary = iBuildFig3GSessionSummary(CtrlDS, THDS)
	Bc = iQueryLightWaterBlocks(CtrlDS);
	Bt = iQueryLightWaterBlocks(THDS);
	if isempty(Bc)
		Bc = table;
	else
		Bc.Group = repmat("Ctrl", height(Bc), 1);
		Bc.Mouse = string(Bc.Mouse);
		Bc.DateTime = iNormalizeDateTime(Bc.DateTime);
	end
	if isempty(Bt)
		Bt = table;
	else
		Bt.Group = repmat("TH", height(Bt), 1);
		Bt.Mouse = string(Bt.Mouse);
		Bt.DateTime = iNormalizeDateTime(Bt.DateTime);
	end
	J = MATLAB.DataTypes.MergeTables(Bc, Bt);
	if isempty(J)
		sessionForSummary = table(string.empty(0,1), NaT(0,1), nan(0,1), string.empty(0,1), ...
			'VariableNames', {'Mouse','DateTime','Performance','Group'});
		return;
	end
	J.Group = string(J.Group);
	vars = intersect(J.Properties.VariableNames, {'Mouse','DateTime','Behavior','Performance','Group','Phase'}, 'stable');
	Sess = iSessionizeByDateTime(J(:, vars));
	Sess = sortrows(Sess, {'Group','Mouse','DateTime'});
	sessionForSummary = Sess(:, {'Mouse','DateTime','Performance','Group'});

	poMatPath = "\\Data-Server-2\个人数据\张天夫\202505\化学遗传抑制PO.v1.mat";
	try
		if exist(poMatPath, 'file')
			PO = UniExp.DataSet(poMatPath);
			POTable = PO.TableQuery(["Mouse","DateTime","Performance","Phase"], Design="LightWater", Expression="溢出");
			if ~isempty(POTable)
				if ismember('Phase', POTable.Properties.VariableNames)
					POTable.Phase = string(POTable.Phase);
					POTable(POTable.Phase == "Recall", :) = [];
				end
				poSess = POTable(:, intersect(["Mouse","DateTime","Performance"], string(POTable.Properties.VariableNames), 'stable'));
				poSess.Mouse = string(poSess.Mouse);
				poSess.DateTime = iNormalizeDateTime(poSess.DateTime);
				poSess.Group = repmat("TH", height(poSess), 1);
				poSess = unique(poSess(:, ["Mouse","DateTime","Performance","Group"]), 'rows');
				sessionForSummary = [sessionForSummary; poSess];
			end
		end
	catch
	end

	sessionForSummary = unique(sessionForSummary(:, {'Mouse','DateTime','Performance','Group'}), 'rows');
	sessionForSummary = sortrows(sessionForSummary, {'Group','Mouse','DateTime'});
end

function [ctrlMice, thMice] = iSplitGroupMice(Sess)
	groupVals = string(Sess.Group);
	mouseVals = string(Sess.Mouse);
	ctrlMice = unique(mouseVals(groupVals == "Ctrl"), 'stable');
	thMice = unique(mouseVals(groupVals == "TH"), 'stable');
end

function T = iQueryLightWaterBlocks(DS)
	varsTry = ["Mouse","DateTime","Stimulus","Phase","Behavior"];
	varsFallback = ["Mouse","DateTime","Stimulus","Phase","Performance"];
	try
		T = DS.TableQuery(varsTry, Stimulus="LightWater");
	catch
		T = DS.TableQuery(varsFallback, Stimulus="LightWater");
	end
	if isempty(T)
		return;
	end
	T.Stimulus = string(T.Stimulus);
	T = T(T.Stimulus == "LightWater", :);
end

function S = iSessionizeByDateTime(T)
	useBehavior = ismember('Behavior', string(T.Properties.VariableNames));
	if ~ismember('Phase', T.Properties.VariableNames)
		T.Phase = repmat(missing, height(T), 1);
	end
	if useBehavior
		T = T(:, {'Mouse','DateTime','Behavior','Phase','Group'});
	else
		T = T(:, {'Mouse','DateTime','Performance','Phase','Group'});
	end
	T.Mouse = string(T.Mouse);
	T.Group = string(T.Group);
	T = sortrows(T, {'Group','Mouse','DateTime'});
	if useBehavior
		val = double(T.Behavior);
	else
		val = double(T.Performance);
	end
	[groupId, groupKeys, mouseKeys, dtKeys] = findgroups(T.Group, T.Mouse, T.DateTime);
	perf = splitapply(@(x) mean(x, 'omitnan'), val, groupId);
	phaseSession = splitapply(@(x) iPickSessionPhase(x), string(T.Phase), groupId);
	S = table(groupKeys, mouseKeys, dtKeys, perf, phaseSession, 'VariableNames', {'Group','Mouse','DateTime','Performance','Phase'});
end

function ph = iPickSessionPhase(phases)
	phases = string(phases);
	phases = phases(~ismissing(phases) & phases ~= "");
	if isempty(phases)
		ph = "";
		return;
	end
	[u, ~, ic] = unique(phases);
	counts = accumarray(ic, 1);
	[~, ix] = max(counts);
	ph = u(ix);
end

function out = iLightWaterTrialsFromPO(DS, sourceName)
	querySets = {
		["Mouse", "DateTime", "Stimulus", "Phase", "Behavior", "Performance", "Expression", "Design"], ...
		["Mouse", "DateTime", "Stimulus", "Phase", "Performance", "Expression", "Design"], ...
		["Mouse", "DateTime", "Phase", "Behavior", "Performance", "Expression", "Design"], ...
		["Mouse", "DateTime", "Phase", "Performance", "Expression", "Design"] ...
	};
	T = table;
	for iQuery = 1:numel(querySets)
		try
			T = DS.TableQuery(querySets{iQuery}, Design="LightWater", Expression="溢出");
			break;
		catch
		end
	end
	if isempty(T)
		out = iEmptyTrialTable();
		return;
	end
	T.Mouse = string(T.Mouse);
	T.DateTime = iNormalizeDateTime(T.DateTime);
	if ismember('Stimulus', T.Properties.VariableNames)
		T.Stimulus = string(T.Stimulus);
		T = T(T.Stimulus == "LightWater", :);
	end
	if ismember('Phase', T.Properties.VariableNames)
		T.Stage = string(T.Phase);
	else
		T.Stage = repmat("", height(T), 1);
	end
	T(T.Stage == "Recall", :) = [];
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
		error('THInhibitVsCtrl_Sigmoid:NoCandidateSession', 'Group %s has no session with %d to %d valid trials.', char(groupName), targetN, targetN + 4);
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
	validRows = sessionRows(isfinite(sessionRows.Hit), :);
	validCount = height(validRows);
	if validCount == targetN
		keepRows = validRows;
	elseif validCount > targetN && validCount < targetN + 5
		keepRows = validRows(iCenterWindow(validCount, targetN), :);
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

function Sess = iSessionizeFromTrials(T, groupName)
	if isempty(T)
		Sess = table(string.empty(0,1), string.empty(0,1), NaT(0,1), nan(0,1), strings(0,1), ...
			'VariableNames', {'Group','Mouse','DateTime','Performance','Phase'});
		return;
	end
	T.Mouse = string(T.Mouse);
	T.Stage = string(T.Stage);
	T = sortrows(T, {'Mouse', 'DateTime', 'OrderInSession'});
	[groupId, mouseVals, dtVals] = findgroups(T.Mouse, T.DateTime);
	perf = splitapply(@(x) mean(x, 'omitnan'), T.Hit, groupId);
	phaseCell = splitapply(@(x) {iPickSessionPhase(x)}, T.Stage, groupId);
	phaseVals = string(vertcat(phaseCell{:}));
	Sess = table(repmat(string(groupName), numel(mouseVals), 1), mouseVals, dtVals, perf, phaseVals, ...
		'VariableNames', {'Group','Mouse','DateTime','Performance','Phase'});
	Sess = Sess(isfinite(Sess.Performance), :);
end

function T = iAddSessionIndex(T)
	T.Group = string(T.Group);
	T.Mouse = string(T.Mouse);
	T = sortrows(T, {'Group', 'Mouse', 'DateTime'});
	[groupId, ~] = findgroups(T.Group, T.Mouse);
	sessCell = splitapply(@(x) {(1:numel(x))'}, T.DateTime, groupId);
	T.Session = vertcat(sessCell{:});
end

function [meanMat, semMat, x] = iUnpackLearningSummarize(SummaryL, groupOrder)
	groupOrder = string(groupOrder);
	if ~istable(SummaryL)
		if isstruct(SummaryL)
			SummaryL = struct2table(SummaryL);
		else
			error('THInhibitVsCtrl_Sigmoid:InvalidLearningSummarizeOutput', 'LearningSummarize output must be table or struct.');
		end
	end
	meanCells = SummaryL.MeanCurve(:);
	semCells = SummaryL.SemCurve(:);
	if ~isempty(SummaryL.Properties.RowNames)
		rn = string(SummaryL.Properties.RowNames);
	else
		rn = strings(numel(meanCells), 1);
	end
	idx = nan(1, numel(groupOrder));
	for k = 1:numel(groupOrder)
		ix = find(rn == groupOrder(k), 1, 'first');
		if isempty(ix) && k <= numel(meanCells)
			ix = k;
		end
		idx(k) = ix;
	end
	maxLen = 0;
	for k = 1:numel(groupOrder)
		if isfinite(idx(k))
			maxLen = max(maxLen, numel(meanCells{idx(k)}));
		end
	end
	meanMat = nan(maxLen, numel(groupOrder));
	semMat = nan(maxLen, numel(groupOrder));
	for k = 1:numel(groupOrder)
		if isfinite(idx(k))
			mv = double(meanCells{idx(k)}(:));
			sv = double(semCells{idx(k)}(:));
			meanMat(1:numel(mv), k) = mv;
			semMat(1:numel(sv), k) = sv;
		end
	end
	x = (1:maxLen).';
end

function nMat = iComputeNBySession(T, x, groups)
	nMat = zeros(numel(x), numel(groups));
	for g = 1:numel(groups)
		rowsG = string(T.Group) == string(groups(g));
		for s = 1:numel(x)
			rowsS = rowsG & (double(T.Session) == s) & isfinite(double(T.Performance));
			if any(rowsS)
				nMat(s, g) = numel(unique(string(T.Mouse(rowsS))));
			end
		end
	end
end

function iPlotGroupMouseCurves(ax, T, xFit, yFit, lineColor, groupName, fitStruct)
	hold(ax, 'on');
	ax.FontSize = 12;
	T = sortrows(T, {'Mouse', 'Session'});
	T.Mouse = string(T.Mouse);
	mice = unique(T.Mouse, 'stable');
	nMice = numel(mice);
	lightColor = 1 - (1 - lineColor) * 0.35;
	mouseHandles = gobjects(0, 1);
	for iMouse = 1:nMice
		rows = T.Mouse == mice(iMouse) & isfinite(double(T.Session)) & isfinite(double(T.Performance));
		if ~any(rows)
			continue;
		end
		xMouse = double(T.Session(rows));
		yMouse = double(T.Performance(rows));
		h = plot(ax, xMouse, yMouse, '-o', 'Color', lightColor, 'LineWidth', 0.9, 'MarkerSize', 4, 'MarkerFaceColor', lightColor, 'MarkerEdgeColor', lineColor);
		if isempty(mouseHandles)
			mouseHandles = h;
		end
	end
	fitHandle = plot(ax, xFit, yFit, '-', 'Color', lineColor, 'LineWidth', 2.8);
	if ~isempty(mouseHandles)
		lg = legend(ax, [mouseHandles(1), fitHandle], {'Per-mouse hit rate', 'Sigmoid fit'}, 'Location', 'southoutside');
		lg.FontSize = 9;
		lg.Box = 'off';
		lg.NumColumns = 2;
	end
	xlabel(ax, 'Block', 'FontSize', 12);
	ylim(ax, [0 1.02]);
	xlim(ax, [1 max(xFit)]);
	box(ax, 'off');
	grid(ax, 'off');
	title(ax, {sprintf('%s (n=%d mice)', char(groupName), nMice), sprintf('lower=%.3f, upper=%.3f', fitStruct.Lower, fitStruct.Upper), sprintf('slope=%.3f, midpoint=%.2f', fitStruct.Slope, fitStruct.Midpoint)}, 'FontSize', 10, 'FontWeight', 'normal');
end

function fitOut = iFitSigmoidCurve(T, groupName, upperMode)
	if nargin < 3 || strlength(string(upperMode)) == 0
		upperMode = "free";
	end
	T = sortrows(T, {'Mouse', 'DateTime'});
	xObs = double(T.Session(:));
	yObs = double(T.Performance(:));
	use = isfinite(xObs) & isfinite(yObs);
	xObs = xObs(use);
	yObs = yObs(use);
	if isempty(xObs)
		error('THInhibitVsCtrl_Sigmoid:NoDataForGroup', 'No valid session data for group %s.', char(groupName));
	end
	upperMode = string(upperMode);
	initLower = min(max(min(yObs, [], 'omitnan'), 0.01), 0.45);
	initMidpoint = log(max(median(xObs), 1));
	if upperMode == "fixed1"
		p0 = [iLogit(initLower); log(0.8); initMidpoint];
		obj = @(p) sum((yObs - iSigmoidFixedUpperFromParams(p, xObs)).^2, 'omitnan');
	else
		initUpper = min(max(max(yObs, [], 'omitnan'), initLower + 0.05), 0.99);
		upperFrac = min(max((initUpper - initLower) / max(1 - initLower, eps), 0.05), 0.95);
		p0 = [iLogit(initLower); iLogit(upperFrac); log(0.8); initMidpoint];
		obj = @(p) sum((yObs - iSigmoidFromParams(p, xObs)).^2, 'omitnan');
	end
	opt = optimset('Display', 'off', 'MaxFunEvals', 10000, 'MaxIter', 10000);
	p = fminsearch(obj, p0, opt);
	if upperMode == "fixed1"
		yHat = iSigmoidFixedUpperFromParams(p, xObs);
		[lower, upper, slope, midpoint] = iDecodeSigmoidFixedUpperParams(p);
	else
		yHat = iSigmoidFromParams(p, xObs);
		[lower, upper, slope, midpoint] = iDecodeSigmoidParams(p);
	end
	SSE = sum((yObs - yHat).^2, 'omitnan');
	SST = sum((yObs - mean(yObs, 'omitnan')).^2, 'omitnan');
	if SST == 0
		rSquared = NaN;
	else
		rSquared = 1 - SSE / SST;
	end
	fitOut = struct;
	fitOut.Group = string(groupName);
	fitOut.UpperMode = upperMode;
	fitOut.ParamRaw = p;
	fitOut.Lower = lower;
	fitOut.Upper = upper;
	fitOut.Slope = slope;
	fitOut.Midpoint = midpoint;
	fitOut.SSE = SSE;
	fitOut.RSquared = rSquared;
	fitOut.XObserved = xObs;
	fitOut.YObserved = yObs;
end

function permOut = iPermutationTestSigmoidDifference(TCtrl, TTH, nPermutation, rngSeed)
	if nargin < 3 || isempty(nPermutation)
		nPermutation = 2000;
	end
	if nargin >= 4 && ~isempty(rngSeed)
		rng(rngSeed);
	end
	TCtrl = sortrows(TCtrl, {'Mouse', 'DateTime'});
	TTH = sortrows(TTH, {'Mouse', 'DateTime'});
	ctrlMice = unique(string(TCtrl.Mouse), 'stable');
	thMice = unique(string(TTH.Mouse), 'stable');
	allMouseTables = cell(numel(ctrlMice) + numel(thMice), 1);
	for iMouse = 1:numel(ctrlMice)
		allMouseTables{iMouse} = TCtrl(string(TCtrl.Mouse) == ctrlMice(iMouse), :);
	end
	for iMouse = 1:numel(thMice)
		allMouseTables{numel(ctrlMice) + iMouse} = TTH(string(TTH.Mouse) == thMice(iMouse), :);
	end
	fitCtrl = iFitSigmoidCurve(TCtrl, "Ctrl", "fixed1");
	fitTH = iFitSigmoidCurve(TTH, "TH", "free");
	fitPooled = iFitSigmoidCurve([TCtrl; TTH], "Pooled", "free");
	observedDeltaSSE = fitPooled.SSE - (fitCtrl.SSE + fitTH.SSE);
	permDeltaSSE = nan(nPermutation, 1);
	nCtrl = numel(ctrlMice);
	for iPerm = 1:nPermutation
		ord = randperm(numel(allMouseTables));
		idxCtrl = ord(1:nCtrl);
		idxTH = ord(nCtrl + 1:end);
		permCtrl = vertcat(allMouseTables{idxCtrl});
		permTH = vertcat(allMouseTables{idxTH});
		fitPermCtrl = iFitSigmoidCurve(permCtrl, "CtrlPerm", "fixed1");
		fitPermTH = iFitSigmoidCurve(permTH, "THPerm", "free");
		fitPermPooled = iFitSigmoidCurve([permCtrl; permTH], "PooledPerm", "free");
		permDeltaSSE(iPerm) = fitPermPooled.SSE - (fitPermCtrl.SSE + fitPermTH.SSE);
	end
	pValue = mean(permDeltaSSE >= observedDeltaSSE);
	permOut = struct;
	permOut.ObservedPooledSSE = fitPooled.SSE;
	permOut.ObservedSplitSSE = fitCtrl.SSE + fitTH.SSE;
	permOut.ObservedDeltaSSE = observedDeltaSSE;
	permOut.PermutedDeltaSSE = permDeltaSSE;
	permOut.PValue = pValue;
	permOut.NPermutation = nPermutation;
end

function y = iSigmoidFromParams(p, x)
	[lower, upper, slope, midpoint] = iDecodeSigmoidParams(p);
	y = lower + (upper - lower) ./ (1 + exp(-slope .* (x - midpoint)));
end

function y = iSigmoidFromFit(fitStruct, x)
	if isfield(fitStruct, 'UpperMode') && string(fitStruct.UpperMode) == "fixed1"
		y = iSigmoidFixedUpperFromParams(fitStruct.ParamRaw, x);
	else
		y = iSigmoidFromParams(fitStruct.ParamRaw, x);
	end
end

function y = iSigmoidFixedUpperFromParams(p, x)
	[lower, upper, slope, midpoint] = iDecodeSigmoidFixedUpperParams(p);
	y = lower + (upper - lower) ./ (1 + exp(-slope .* (x - midpoint)));
end

function [lower, upper, slope, midpoint] = iDecodeSigmoidParams(p)
	lower = 1 ./ (1 + exp(-p(1)));
	upper = lower + (1 - lower) .* (1 ./ (1 + exp(-p(2))));
	slope = exp(p(3));
	midpoint = exp(p(4));
end

function [lower, upper, slope, midpoint] = iDecodeSigmoidFixedUpperParams(p)
	lower = 1 ./ (1 + exp(-p(1)));
	upper = 1;
	slope = exp(p(2));
	midpoint = exp(p(3));
end

function y = iLogit(x)
	x = min(max(x, 1e-6), 1 - 1e-6);
	y = log(x ./ (1 - x));
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
		error('THInhibitVsCtrl_Sigmoid:DuplicateMouseAcrossSources', 'Group %s has duplicated mice across sources.\n%s', char(groupName), char(strjoin(msgLines, newline)));
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
		error('THInhibitVsCtrl_Sigmoid:MouseInMultipleGroups', 'Some mice appear in multiple groups.\n%s', char(strjoin(msgLines, newline)));
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
