% Chinese Fig3.1B: naive AudioWater vs naive LightWater learning curves.
% The panel compares initial learning of the auditory and blue-light cue tasks.

if ~exist('UniExp.DataSet', 'class')
	thisFile = mfilename('fullpath');
	thisDir = fileparts(thisFile);
	prjFile = fullfile(thisDir, '..', 'Transferlearning.prj');
	if exist(prjFile, 'file')
		matlab.project.loadProject(prjFile);
	end
end

ALB = TransferLearning.AudioLightBaseline();
ALPB = TransferLearning.ALPureBehavior();
LAB = TransferLearning.LightAudioBaseline();
LAI = TransferLearning.LAInterspersed();
LAPB = TransferLearning.LAPureBehavior();

naiveAudioA = iCueWaterSessionsByMouse(ALB, "AudioLightBaseline", true, "AudioWater", "Naive", "Learned");
naiveAudioB = iCueWaterSessionsByMouse(ALPB, "ALPureBehavior", false, "AudioWater", "Naive", "Learned");
naiveLightA = iCueWaterSessionsByMouse(LAB, "LightAudioBaseline", true, "LightWater", "Naive", "Learned");
naiveLightB = iCueWaterSessionsByMouse_LAInterspersed(LAI, "LAInterspersed", true, "LightWater", "Naive", "Learned");
naiveLightC = iCueWaterSessionsByMouse(LAPB, "LAPureBehavior", false, "LightWater", "Naive", "Learned");

naiveAudio = [naiveAudioA; naiveAudioB];
naiveLight = [naiveLightA; naiveLightB; naiveLightC];
naiveAudio.Group(:) = "Audio";
naiveLight.Group(:) = "Light";

iAssertNoCrossSourceDuplicateMice(naiveAudio, "Audio");
iAssertNoCrossSourceDuplicateMice(naiveLight, "Light");

allSessions = [naiveAudio; naiveLight];
iAssertNoMouseAppearsInMultipleGroups(allSessions);
if isempty(allSessions)
	error('Fig31B:EmptyData', 'No initial AudioWater or LightWater sessions found.');
end

allSessions = sortrows(allSessions, ["Group", "Mouse", "DateTime"]);
allSessions = iAddSessionIndex(allSessions);
summaryCurve = iSummarizeBySession(allSessions, ["Audio", "Light"]);

audioSessions = allSessions(allSessions.Group == "Audio", :);
lightSessions = allSessions(allSessions.Group == "Light", :);
fitAudio = iFitSigmoidCurve(audioSessions, "Audio");
fitLight = iFitSigmoidCurve(lightSessions, "Light");
permResult = iPermutationTestSigmoidSlope(audioSessions, lightSessions, 10000, 1);
%% 

audioColor = TransferLearning.ColorA;
lightColor = TransferLearning.ColorB;

f = figure('Color', 'w', 'Name', 'Chinese Fig31B naive Audio vs Light learning curve');
f.Units = 'centimeters';
f.Position(3:4) = [12, 8];
f.PaperUnits = 'centimeters';
f.PaperSize = [12, 8];
f.PaperPositionMode = 'auto';
ax = axes(f);
hold(ax, 'on');

audioRows = summaryCurve.Group == "Audio";
lightRows = summaryCurve.Group == "Light";
hAudioMean = errorbar(ax, summaryCurve.Session(audioRows), summaryCurve.Mean(audioRows), summaryCurve.Sem(audioRows), ...
	'o', 'Color', audioColor, 'MarkerFaceColor', 'w', 'MarkerEdgeColor', audioColor, ...
	'MarkerSize', 4.5, 'LineWidth', 1.5, 'CapSize', 4, 'LineStyle', 'none');
hLightMean = errorbar(ax, summaryCurve.Session(lightRows), summaryCurve.Mean(lightRows), summaryCurve.Sem(lightRows), ...
	'o', 'Color', lightColor, 'MarkerFaceColor', 'w', 'MarkerEdgeColor', lightColor, ...
	'MarkerSize', 4.5, 'LineWidth', 1.5, 'CapSize', 4, 'LineStyle', 'none');

xMax = max(summaryCurve.Session, [], 'omitnan');
xFit = linspace(1, xMax, 200).';
hAudioFit = plot(ax, xFit, iSigmoidFromParams(fitAudio.ParamRaw, xFit), '-', 'Color', audioColor, 'LineWidth', 2.2);
hLightFit = plot(ax, xFit, iSigmoidFromParams(fitLight.ParamRaw, xFit), '-', 'Color', lightColor, 'LineWidth', 2.2);

xlabel(ax, 'Block', 'FontSize', 12);
ylabel(ax, 'Hit rate', 'FontSize', 12);
xlim(ax, [0.5, xMax + 0.5]);
ylim(ax, [0, 1.02]);
ax.FontSize = 12;
ax.LineWidth = 2;
ax.Color = 'none';
ax.YTick = 0:0.5:1;
ax.XTick = unique([1, 5:5:ceil(xMax)]);
box(ax, 'off');
grid(ax, 'off');
title(ax, '');

lg = legend(ax, [hAudioMean, hAudioFit, hLightMean, hLightFit], ...
	{'🔊 Mean ± SEM', '🔊 Sigmoid', '💡 Mean ± SEM', '💡 Sigmoid'}, ...
	'Location', 'southoutside', 'NumColumns', 2);
lg.Box = 'off';
lg.FontSize = 10;

if isprop(ax, 'Toolbar') && ~isempty(ax.Toolbar)
	ax.Toolbar.Visible = 'off';
end

svgPath = TransferLearning.ExportStandardFigure(f, 2, '中文图Fig31B_NaiveAudioVsLight_LearningCurve.svg');

fitTable = table(["Audio"; "Light"], [fitAudio.Slope; fitLight.Slope], [fitAudio.Midpoint; fitLight.Midpoint], ...
	[fitAudio.RSquared; fitLight.RSquared], 'VariableNames', {'Group', 'Slope', 'Midpoint', 'RSquared'});
statTable = table(numel(unique(audioSessions.Mouse)), numel(unique(lightSessions.Mouse)), fitAudio.Slope, fitLight.Slope, ...
	permResult.ObservedDifference, permResult.PValue, permResult.NPermutation, ...
	'VariableNames', {'AudioMiceN', 'LightMiceN', 'AudioSlope', 'LightSlope', 'AudioMinusLightSlope', 'PermutationPValue', 'NPermutation'});

assignin('base', 'Fig31B_NaiveAudioVsLight_Raw', allSessions);
assignin('base', 'Fig31B_NaiveAudioVsLight_Summary', summaryCurve);
assignin('base', 'Fig31B_NaiveAudioVsLight_Fit', fitTable);
assignin('base', 'Fig31B_NaiveAudioVsLight_Stats', statTable);

fprintf('Wrote: %s\n', svgPath);
fprintf('Fig31B compares initial AudioWater vs initial LightWater learning.\n');
fprintf('Audio mice n = %d\n', statTable.AudioMiceN);
fprintf('Light mice n = %d\n', statTable.LightMiceN);
fprintf('Audio sigmoid slope = %.6f\n', fitAudio.Slope);
fprintf('Light sigmoid slope = %.6f\n', fitLight.Slope);
fprintf('Audio - Light slope difference = %.6f\n', permResult.ObservedDifference);
fprintf('Permutation two-sided p = %.6g (%d permutations)\n', permResult.PValue, permResult.NPermutation);

function out = iCueWaterSessionsByMouse(DS, sourceName, imagingCohort, stimulusName, startPhase, endPhase)
	T = iQueryCueWaterBehaviorAll(DS, stimulusName);
	if isempty(T)
		out = iEmptySessionTable();
		return;
	end

	T.Mouse = string(T.Mouse);
	T.DateTime = iNormalizeDateTime(T.DateTime);
	S = iSessionizeByDateTime(T);
	S = iSelectSessionsBetweenPhases(S, startPhase, endPhase);
	S.Source = repmat(string(sourceName), height(S), 1);
	S.ImagingCohort = repmat(logical(imagingCohort), height(S), 1);
	out = S(:, {'Mouse', 'DateTime', 'Performance', 'Source', 'ImagingCohort', 'NBlocksInSession', 'Phase'});
end

function out = iCueWaterSessionsByMouse_LAInterspersed(DS, sourceName, imagingCohort, stimulusName, startPhase, endPhase)
	badMice = iFindMiceWithAudioWaterInPhase(DS, "Naive");
	T = iQueryCueWaterBehaviorAll(DS, stimulusName);
	if isempty(T)
		out = iEmptySessionTable();
		return;
	end

	T.Mouse = string(T.Mouse);
	if ~isempty(badMice)
		T = T(~ismember(T.Mouse, badMice), :);
	end
	if isempty(T)
		out = iEmptySessionTable();
		return;
	end

	T.DateTime = iNormalizeDateTime(T.DateTime);
	S = iSessionizeByDateTime(T);
	S = iSelectSessionsBetweenPhases(S, startPhase, endPhase);
	S.Source = repmat(string(sourceName), height(S), 1);
	S.ImagingCohort = repmat(logical(imagingCohort), height(S), 1);
	out = S(:, {'Mouse', 'DateTime', 'Performance', 'Source', 'ImagingCohort', 'NBlocksInSession', 'Phase'});
end

function T = iQueryCueWaterBehaviorAll(DS, stimulusName)
	varsTry = ["Mouse", "DateTime", "Stimulus", "Phase", "Behavior"];
	varsFallback = ["Mouse", "DateTime", "Stimulus", "Phase", "Performance"];
	try
		T = DS.TableQuery(varsTry, Stimulus=stimulusName);
	catch
		T = DS.TableQuery(varsFallback, Stimulus=stimulusName);
	end
	if isempty(T)
		return;
	end
	T.Stimulus = string(T.Stimulus);
	T = T(T.Stimulus == string(stimulusName), :);
end

function badMice = iFindMiceWithAudioWaterInPhase(DS, phaseName)
	Ta = DS.TableQuery("Mouse", Stimulus="AudioWater", Phase=phaseName);
	if isempty(Ta) || ~ismember("Mouse", string(Ta.Properties.VariableNames))
		badMice = string.empty(0, 1);
	else
		badMice = unique(string(Ta.Mouse));
	end
end

function dt = iNormalizeDateTime(dt)
	dt = datetime(dt);
	if isdatetime(dt) && ~isempty(dt.TimeZone)
		dt.TimeZone = '';
	end
end

function S = iSessionizeByDateTime(T)
	useBehavior = ismember('Behavior', string(T.Properties.VariableNames));
	if ~ismember('Phase', T.Properties.VariableNames)
		T.Phase = repmat(missing, height(T), 1);
	end
	if useBehavior
		T = T(:, {'Mouse', 'DateTime', 'Behavior', 'Phase'});
	else
		T = T(:, {'Mouse', 'DateTime', 'Performance', 'Phase'});
	end
	T.Mouse = string(T.Mouse);
	T = sortrows(T, {'Mouse', 'DateTime'});
	if useBehavior
		values = double(T.Behavior);
	else
		values = double(T.Performance);
	end

	[groupId, mouseVals, dateTimeVals] = findgroups(T.Mouse, T.DateTime);
	performance = splitapply(@(x) mean(x, 'omitnan'), values, groupId);
	nBlocks = splitapply(@(x) sum(isfinite(x)), values, groupId);
	phaseSession = splitapply(@(x) iPickSessionPhase(x), string(T.Phase), groupId);
	S = table(mouseVals, dateTimeVals, performance, nBlocks, phaseSession, ...
		'VariableNames', {'Mouse', 'DateTime', 'Performance', 'NBlocksInSession', 'Phase'});
end

function phase = iPickSessionPhase(phases)
	phases = string(phases);
	phases = phases(~ismissing(phases) & phases ~= "");
	if isempty(phases)
		phase = "";
		return;
	end
	[uniquePhases, ~, phaseId] = unique(phases);
	phaseCounts = accumarray(phaseId, 1);
	[~, maxIdx] = max(phaseCounts);
	phase = uniquePhases(maxIdx);
end

function S = iSelectSessionsBetweenPhases(S, startPhase, endPhase)
	if isempty(S)
		return;
	end
	startPhase = string(startPhase);
	endPhase = string(endPhase);
	S.Mouse = string(S.Mouse);
	S.Phase = string(S.Phase);
	S = sortrows(S, {'Mouse', 'DateTime'});
	mice = unique(S.Mouse);
	keepRows = false(height(S), 1);
	for iMouse = 1:numel(mice)
		rowIdx = find(S.Mouse == mice(iMouse));
		phases = S.Phase(rowIdx);
		startIdx = find(phases == startPhase, 1, 'first');
		if isempty(startIdx)
			continue;
		end
		endIdx = find(phases == endPhase & (1:numel(phases))' >= startIdx, 1, 'first');
		if isempty(endIdx)
			endIdx = numel(phases);
		end
		keepRows(rowIdx(startIdx:endIdx)) = true;
	end
	S = S(keepRows, :);
end

function iAssertNoCrossSourceDuplicateMice(T, groupName)
	if isempty(T)
		return;
	end
	T.Mouse = string(T.Mouse);
	T.Source = string(T.Source);
	[groupId, mouseVals] = findgroups(T.Mouse);
	nSources = splitapply(@(x) numel(unique(string(x))), T.Source, groupId);
	duplicatedMice = mouseVals(nSources > 1);
	if isempty(duplicatedMice)
		return;
	end
	msgLines = strings(numel(duplicatedMice), 1);
	for iMouse = 1:numel(duplicatedMice)
		mouseName = duplicatedMice(iMouse);
		sources = unique(T.Source(T.Mouse == mouseName));
		msgLines(iMouse) = mouseName + ": " + strjoin(sources, ", ");
	end
	error('Fig31B:DuplicateMouseAcrossSources', ...
		'Group %s has duplicated mice across sources.\n%s', char(string(groupName)), char(strjoin(msgLines, newline)));
end

function iAssertNoMouseAppearsInMultipleGroups(T)
	if isempty(T)
		return;
	end
	T.Mouse = string(T.Mouse);
	T.Group = string(T.Group);
	[groupId, mouseVals] = findgroups(T.Mouse);
	nGroups = splitapply(@(x) numel(unique(string(x))), T.Group, groupId);
	duplicatedMice = mouseVals(nGroups > 1);
	if isempty(duplicatedMice)
		return;
	end
	msgLines = strings(numel(duplicatedMice), 1);
	for iMouse = 1:numel(duplicatedMice)
		mouseName = duplicatedMice(iMouse);
		groups = unique(T.Group(T.Mouse == mouseName));
		msgLines(iMouse) = mouseName + ": " + strjoin(groups, ", ");
	end
	error('Fig31B:MouseInMultipleGroups', 'Some mice appear in both Audio and Light groups.\n%s', char(strjoin(msgLines, newline)));
end

function T = iAddSessionIndex(T)
	T.Mouse = string(T.Mouse);
	T.Group = string(T.Group);
	T = sortrows(T, {'Group', 'Mouse', 'DateTime'});
	[groupId, ~] = findgroups(T.Group, T.Mouse);
	sessionCell = splitapply(@(x) {(1:numel(x))'}, T.DateTime, groupId);
	T.Session = vertcat(sessionCell{:});
end

function summary = iSummarizeBySession(T, groupOrder)
	groupOrder = string(groupOrder);
	maxSession = max(double(T.Session), [], 'omitnan');
	rows = cell(numel(groupOrder), 1);
	for iGroup = 1:numel(groupOrder)
		groupName = groupOrder(iGroup);
		sessions = (1:maxSession).';
		meanValue = nan(numel(sessions), 1);
		semValue = nan(numel(sessions), 1);
		nMice = zeros(numel(sessions), 1);
		for iSession = 1:numel(sessions)
			use = T.Group == groupName & T.Session == sessions(iSession) & isfinite(double(T.Performance));
			values = double(T.Performance(use));
			nMice(iSession) = numel(unique(string(T.Mouse(use))));
			if isempty(values)
				continue;
			end
			meanValue(iSession) = mean(values, 'omitnan');
			if isscalar(values)
				semValue(iSession) = 0;
			else
				semValue(iSession) = std(values, 'omitnan') ./ sqrt(numel(values));
			end
		end
		rows{iGroup} = table(repmat(groupName, numel(sessions), 1), sessions, meanValue, semValue, nMice, ...
			'VariableNames', {'Group', 'Session', 'Mean', 'Sem', 'NMice'});
	end
	summary = vertcat(rows{:});
	summary = summary(isfinite(summary.Mean), :);
end

function fitOut = iFitSigmoidCurve(T, groupName)
	T = sortrows(T, {'Mouse', 'DateTime'});
	xObs = double(T.Session(:));
	yObs = double(T.Performance(:));
	use = isfinite(xObs) & isfinite(yObs);
	xObs = xObs(use);
	yObs = yObs(use);
	if isempty(xObs)
		error('Fig31B:NoDataForGroup', 'No valid session data for group %s.', char(groupName));
	end

	p0 = [log(1); median(xObs, 'omitnan')];
	obj = @(p) sum((yObs - iSigmoidFromParams(p, xObs)).^2, 'omitnan');
	opt = optimset('Display', 'off', 'MaxFunEvals', 10000, 'MaxIter', 10000);
	p = fminsearch(obj, p0, opt);
	yHat = iSigmoidFromParams(p, xObs);
	sse = sum((yObs - yHat).^2, 'omitnan');
	sst = sum((yObs - mean(yObs, 'omitnan')).^2, 'omitnan');
	if sst == 0
		rSquared = NaN;
	else
		rSquared = 1 - sse ./ sst;
	end
	[lower, upper, slope, midpoint] = iDecodeSigmoidParams(p);
	fitOut = struct;
	fitOut.Group = string(groupName);
	fitOut.ParamRaw = p;
	fitOut.Lower = lower;
	fitOut.Upper = upper;
	fitOut.Slope = slope;
	fitOut.Midpoint = midpoint;
	fitOut.SSE = sse;
	fitOut.RSquared = rSquared;
end

function permOut = iPermutationTestSigmoidSlope(TAudio, TLight, nPermutation, rngSeed)
	if nargin >= 4 && ~isempty(rngSeed)
		rng(rngSeed);
	end
	TAudio = sortrows(TAudio, {'Mouse', 'DateTime'});
	TLight = sortrows(TLight, {'Mouse', 'DateTime'});
	audioMice = unique(string(TAudio.Mouse), 'stable');
	lightMice = unique(string(TLight.Mouse), 'stable');
	allMouseTables = cell(numel(audioMice) + numel(lightMice), 1);
	for iMouse = 1:numel(audioMice)
		allMouseTables{iMouse} = TAudio(TAudio.Mouse == audioMice(iMouse), :);
	end
	for iMouse = 1:numel(lightMice)
		allMouseTables{numel(audioMice) + iMouse} = TLight(TLight.Mouse == lightMice(iMouse), :);
	end

	fitAudio = iFitSigmoidCurve(TAudio, "Audio");
	fitLight = iFitSigmoidCurve(TLight, "Light");
	observedDiff = fitAudio.Slope - fitLight.Slope;
	permDiff = nan(nPermutation, 1);
	nAudio = numel(audioMice);
	for iPerm = 1:nPermutation
		order = randperm(numel(allMouseTables));
		permAudio = vertcat(allMouseTables{order(1:nAudio)});
		permLight = vertcat(allMouseTables{order(nAudio + 1:end)});
		fitPermAudio = iFitSigmoidCurve(permAudio, "AudioPerm");
		fitPermLight = iFitSigmoidCurve(permLight, "LightPerm");
		permDiff(iPerm) = fitPermAudio.Slope - fitPermLight.Slope;
	end
	permOut = struct;
	permOut.ObservedAudioSlope = fitAudio.Slope;
	permOut.ObservedLightSlope = fitLight.Slope;
	permOut.ObservedDifference = observedDiff;
	permOut.PermutedDifference = permDiff;
	permOut.PValue = mean(abs(permDiff) >= abs(observedDiff), 'omitnan');
	permOut.NPermutation = nPermutation;
end

function y = iSigmoidFromParams(p, x)
	[~, ~, slope, midpoint] = iDecodeSigmoidParams(p);
	z = -slope .* (double(x) - midpoint);
	z = max(min(z, 60), -60);
	y = 1 ./ (1 + exp(z));
end

function [lower, upper, slope, midpoint] = iDecodeSigmoidParams(p)
	lower = 0;
	upper = 1;
	slope = exp(p(1));
	midpoint = p(2);
end

function T = iEmptySessionTable()
	T = table(string.empty(0, 1), NaT(0, 1), nan(0, 1), strings(0, 1), false(0, 1), nan(0, 1), strings(0, 1), ...
		'VariableNames', {'Mouse', 'DateTime', 'Performance', 'Source', 'ImagingCohort', 'NBlocksInSession', 'Phase'});
end
