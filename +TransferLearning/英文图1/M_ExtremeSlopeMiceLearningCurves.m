% English Fig1 (derived from Fig1D algorithm): extreme slope mice learning curves
%
% Task:
% - Follow the algorithmic definitions from 英文图1D (D_GrowthSlope.m):
%   build per-mouse LightWater session trajectories between phase tags,
%   compute per-mouse slope, baseline-adjust slope via residualization.
% - Select the mouse with maximum and minimum SlopeAdj (finite only).
% - Plot the two learning curves.
%
% Hard constraints (project):
% - MUST use MATLAB_remote (no batch).
% - Export SVG via TransferLearning.PrintFigure to UNC.
%
% Execution:
% - This file MUST remain a SCRIPT.
% - Do NOT use run.
% - Open in MATLAB Editor and Run/F5.

outDirUNC = "\\Data-Server-2\个人数据\张天夫\202601";
svgName = "English_Fig1M_ExtremeSlopeMiceLearningCurves.svg";

% --- 0) Ensure project loaded (for UniExp)
try
	if ~exist('UniExp.DataSet','class')
		thisFile = mfilename('fullpath');
		thisDir = fileparts(thisFile);
		prjFile = fullfile(thisDir, '..', '..', 'Transferlearning.prj');
		if exist(prjFile,'file')
			try
				matlab.project.loadProject(prjFile);
			catch
			end
		end
	end
catch
end

% --- 1) Load datasets (same cohorts as Fig1D)
LAB  = TransferLearning.LightAudioBaseline();
LAI  = TransferLearning.LAInterspersed();
ALB  = TransferLearning.AudioLightBaseline();
LAPB = TransferLearning.LAPureBehavior();
ALPB = TransferLearning.ALPureBehavior();

% --- 2) Build trajectories between phase tags (LightWater-only perf from Trials)
naiveA = iLightWaterTrajectoryBetweenPhases(LAB,  "LightAudioBaseline", true,  "Naive",    "Learned", strings(0,1));
naiveB = iLightWaterTrajectoryBetweenPhases_LAInterspersed(LAI, "LAInterspersed", true,  "Naive",    "Learned");
naiveC = iLightWaterTrajectoryBetweenPhases(LAPB, "LAPureBehavior",     false, "Naive",    "Learned", strings(0,1));

tranA  = iLightWaterTrajectoryBetweenPhases(ALB,  "AudioLightBaseline", true,  "Transfer", "Final",  strings(0,1));
tranB  = iLightWaterTrajectoryBetweenPhases(ALPB, "ALPureBehavior",     false, "Transfer", "Final",  strings(0,1));

naive = [naiveA; naiveB; naiveC];
tran  = [tranA;  tranB];
naive.Group(:) = "Naive";
tran.Group(:)  = "Transfer";

iAssertNoCrossSourceDuplicateMice(naive, "Naive");
iAssertNoCrossSourceDuplicateMice(tran,  "Transfer");
allSessions = [naive; tran];
iAssertNoMouseAppearsInMultipleGroups(allSessions);

if isempty(allSessions)
	warning('English_Fig1M:EmptyData', '%s', 'No LightWater sessions found.');
	return;
end

% --- 2.5) Build two session tables:
% - For slope: exclude the first 100% session and anything after it.
% - For plotting: keep the first 100% session, but exclude sessions after it.
allSessionsSlope = iTrimAtCeiling_ExcludeFirstCeiling(allSessions);
allSessionsPlot  = iTrimAfterCeiling_KeepFirstCeiling(allSessions);

if isempty(allSessionsSlope)
	warning('English_Fig1M:EmptySlopeAfterCeilingTrim', '%s', 'All sessions removed by slope ceiling-trim.');
	return;
end
if isempty(allSessionsPlot)
	warning('English_Fig1M:EmptyPlotAfterCeilingTrim', '%s', 'All sessions removed by plot ceiling-trim.');
	return;
end

allSessionsSlope = sortrows(allSessionsSlope, {'Group','Mouse','DateTime'});
allSessionsSlope = iAddSessionIndex(allSessionsSlope);
allSessionsSlope = iAddBaselinePerf(allSessionsSlope);

allSessionsPlot = sortrows(allSessionsPlot, {'Group','Mouse','DateTime'});
allSessionsPlot = iAddSessionIndex(allSessionsPlot);

% --- 3) Per-mouse slope and baseline-adjusted slope (Fig1D style)
perMouse = iPerMouseSlope(allSessionsSlope);
perMouse.SlopeAdj = nan(height(perMouse), 1);
okAdj = isfinite(perMouse.Slope) & isfinite(perMouse.BaselinePerf);
if any(okAdj)
	if exist('robustfit','file')
		b = robustfit(double(perMouse.BaselinePerf(okAdj)), double(perMouse.Slope(okAdj)));
		perMouse.SlopeAdj(okAdj) = double(perMouse.Slope(okAdj)) - (b(1) + b(2) * double(perMouse.BaselinePerf(okAdj)));
	else
		adjMdl = fitlm(perMouse(okAdj, :), 'Slope ~ 1 + BaselinePerf');
		perMouse.SlopeAdj(okAdj) = adjMdl.Residuals.Raw;
	end
end

ok = isfinite(perMouse.SlopeAdj);
if ~any(ok)
	warning('English_Fig1M:NoFiniteSlopeAdj', '%s', 'No finite SlopeAdj values.');
	return;
end

% Select extreme mice with baseline (first-session) performance < 0.5 (user requirement)
okBase = isfinite(perMouse.BaselinePerf) & (double(perMouse.BaselinePerf) < 0.5);
okSel = ok & okBase;
if nnz(okSel) < 2
	warning('English_Fig1M:NotEnoughMiceAfterBaselineFilter', 'Need >=2 mice with finite SlopeAdj and BaselinePerf<0.5, got %d.', nnz(okSel));
	return;
end

[~, iMax] = max(perMouse.SlopeAdj(okSel));
[~, iMin] = min(perMouse.SlopeAdj(okSel));
idxOk = find(okSel);
idxMax = idxOk(iMax);
idxMin = idxOk(iMin);

mouseMax = string(perMouse.Mouse(idxMax));
mouseMin = string(perMouse.Mouse(idxMin));

% --- 4) Plot learning curves for the two mice
f = figure('Color','w', 'Name', 'English Fig1M Extreme slope mice learning curves');
try
	MATLAB.Graphics.FigureAspectRatio(90, 80, 1);
catch
end

tiledlayout(f, 1, 1, 'TileSpacing','compact', 'Padding','compact');
ax = nexttile;
hold(ax, 'on');

cols = lines(2);

iPlotMouseCurve(ax, allSessionsPlot, perMouse, mouseMax, cols(1,:));
iPlotMouseCurve(ax, allSessionsPlot, perMouse, mouseMin, cols(2,:));

xlabel(ax, 'Session');
ylabel(ax, 'Performance');
ylim(ax, [0 1]);
box(ax, 'off');
grid(ax, 'off');
ax.FontSize = 6;

legend(ax, 'Location','best');

% --- 5) Export SVG
svgPath = fullfile(outDirUNC, svgName);
try
	if ~isfolder(outDirUNC)
		mkdir(outDirUNC);
	end
catch
end

try
	TransferLearning.PrintFigure(f, svgPath);
	fprintf('Wrote: %s\n', svgPath);
catch ME
	warning(ME.identifier, 'Export failed: %s', ME.message);
end

%% --- local helpers (copied minimally from Fig1D algorithm)
function iPlotMouseCurve(ax, allSessions, perMouse, mouseId, col)
	rows = string(allSessions.Mouse) == string(mouseId);
	Sm = allSessions(rows, :);
	Sm = sortrows(Sm, 'Session');
	grp = string(unique(Sm.Group));
	if numel(grp) ~= 1
		grp = "";
	end
	pm = perMouse(string(perMouse.Mouse) == string(mouseId), :);
	if isempty(pm)
		sAdj = nan;
		s = nan;
	else
		sAdj = pm.SlopeAdj(1);
		s = pm.Slope(1);
	end
	lab = sprintf('%s (%s)  slope=%.3g  adj=%.3g', char(mouseId), char(grp), s, sAdj);
	plot(ax, double(Sm.Session), double(Sm.Performance), '-o', 'Color', col, 'LineWidth', 1, 'MarkerSize', 4, 'DisplayName', lab);
end

function out = iLightWaterTrajectoryBetweenPhases(DS, sourceName, imagingCohort, startPhase, endPhase, excludeMice)
	if nargin < 6 || isempty(excludeMice)
		excludeMice = strings(0,1);
	end
	excludeMice = string(excludeMice);
	startPhase = string(startPhase);
	endPhase = string(endPhase);

	Tblk = iQueryAllBlocksWithLWPerf(DS);
	if isempty(Tblk)
		out = table(string.empty(0,1), NaT(0,1), nan(0,1), strings(0,1), false(0,1), nan(0,1), ...
			'VariableNames', {'Mouse','DateTime','Performance','Source','ImagingCohort','NBlocksInSession'});
		return;
	end

	Tblk.Mouse = string(Tblk.Mouse);
	Tblk.Phase = string(Tblk.Phase);
	Tblk.DateTime = iNormalizeDateTime(Tblk.DateTime);
	Tblk = Tblk(~ismember(Tblk.Mouse, excludeMice), :);
	if isempty(Tblk)
		out = table(string.empty(0,1), NaT(0,1), nan(0,1), strings(0,1), false(0,1), nan(0,1), ...
			'VariableNames', {'Mouse','DateTime','Performance','Source','ImagingCohort','NBlocksInSession'});
		return;
	end

	% sessionize all LightWater blocks
	Sess = iSessionizeByDateTime(Tblk(:, {'Mouse','DateTime','Performance','BlockUID'}));
	Sess.Mouse = string(Sess.Mouse);
	Sess.DateTime = iNormalizeDateTime(Sess.DateTime);

	% determine start/end DateTime per mouse from Phase-tagged blocks
	mice = unique(Tblk.Mouse);
	keepRows = false(height(Sess), 1);
	for i = 1:numel(mice)
		m = mice(i);
		blkM = Tblk(Tblk.Mouse == m, :);
		startDT = min(blkM.DateTime(blkM.Phase == startPhase));
		endDT = max(blkM.DateTime(blkM.Phase == endPhase));
		if isempty(startDT) || isempty(endDT) || any(ismissing([startDT endDT]))
			continue;
		end
		if endDT < startDT
			continue;
		end
		rows = (Sess.Mouse == m) & (Sess.DateTime >= startDT) & (Sess.DateTime <= endDT);
		keepRows = keepRows | rows;
	end

	Sess = Sess(keepRows, :);
	Sess.Source = repmat(string(sourceName), height(Sess), 1);
	Sess.ImagingCohort = repmat(logical(imagingCohort), height(Sess), 1);
	out = Sess(:, {'Mouse','DateTime','Performance','Source','ImagingCohort','NBlocksInSession'});
end

function out = iLightWaterTrajectoryBetweenPhases_LAInterspersed(DS, sourceName, imagingCohort, startPhase, endPhase)
	badMice = iFindMiceWithAudioWaterInPhase(DS, startPhase);
	if ~isempty(badMice)
		fprintf('English Fig1M: LAInterspersed excluded %d mice with AudioWater mixed into %s phase.\n', numel(badMice), char(string(startPhase)));
	end
	out = iLightWaterTrajectoryBetweenPhases(DS, sourceName, imagingCohort, startPhase, endPhase, badMice);
end

function dt = iNormalizeDateTime(dt)
	try
		dt = datetime(dt);
		if isdatetime(dt) && ~isempty(dt.TimeZone)
			dt.TimeZone = '';
		end
	catch
	end
end

function Tblk = iQueryAllBlocksWithLWPerf(DS)
	% Returns block-level rows with fields:
	%   Mouse, DateTime, BlockUID, Phase, Performance
	% Performance is computed from Trials where Stimulus=="LightWater".

	vars = ["Mouse","DateTime","BlockUID","Phase"];
	try
		Tblk = DS.TableQuery(vars);
	catch ME
		error('English_Fig1M:BlockQueryFailed', 'Block query failed for %s: %s', class(DS), ME.message);
	end
	if isempty(Tblk)
		Tblk = table();
		return;
	end

	if ~isprop(DS, 'Trials')
		error('English_Fig1M:MissingTrials', 'DataSet %s has no Trials; cannot compute LightWater-only performance.', class(DS));
	end
	Tr = DS.Trials;
	need = {'BlockUID','Stimulus','Behavior'};
	if ~all(ismember(need, Tr.Properties.VariableNames))
		error('English_Fig1M:TrialsMissingFields', 'Trials table for %s lacks required fields: %s', class(DS), strjoin(setdiff(need, Tr.Properties.VariableNames), ','));
	end

	TrStim = string(Tr.Stimulus);
	TrLW = Tr(TrStim == "LightWater", {'BlockUID','Behavior'});
	if isempty(TrLW)
		Tblk = table();
		return;
	end

	[G, bu] = findgroups(uint64(TrLW.BlockUID));
	lwPerf = splitapply(@(x) mean(double(x),'omitnan'), TrLW.Behavior, G);
	perfByBlock = table(uint64(bu), lwPerf, 'VariableNames', {'BlockUID64','LWPerf'});

	blkUID64 = uint64(Tblk.BlockUID);
	[tf, loc] = ismember(blkUID64, perfByBlock.BlockUID64);
	Tblk = Tblk(tf, :);
	if isempty(Tblk)
		Tblk = table();
		return;
	end
	Tblk.Performance = perfByBlock.LWPerf(loc(tf));
end

function T = iSessionizeByDateTime(T)
	T.DateTime = datetime(T.DateTime);
	T.DateTime.TimeZone = '';
	[G, mouse, dt] = findgroups(string(T.Mouse), T.DateTime);
	perf = splitapply(@(x) mean(x,'omitnan'), double(T.Performance), G);
	nBlocks = splitapply(@numel, double(T.Performance), G);
	T = table(mouse, dt, perf, nBlocks, 'VariableNames', {'Mouse','DateTime','Performance','NBlocksInSession'});
end

function badMice = iFindMiceWithAudioWaterInPhase(DS, phaseName)
	try
		T = DS.TableQuery(["Mouse","BlockUID"], Phase=phaseName);
	catch ME
		error('English_Fig1M:PurePhaseQueryFailed', 'Query failed for %s: %s', class(DS), ME.message);
	end
	if isempty(T)
		badMice = strings(0,1);
		return;
	end
	if ~isprop(DS, 'Trials')
		error('English_Fig1M:MissingTrials', 'DataSet %s has no Trials; cannot detect AudioWater mixing.', class(DS));
	end
	Tr = DS.Trials;
	if ~ismember('Stimulus', Tr.Properties.VariableNames) || ~ismember('BlockUID', Tr.Properties.VariableNames)
		error('English_Fig1M:TrialsMissingFields', 'Trials table for %s lacks Stimulus/BlockUID.', class(DS));
	end
	Tr.Stimulus = string(Tr.Stimulus);

	T.Mouse = string(T.Mouse);
	mice = unique(T.Mouse);
	bad = false(size(mice));

	for i = 1:numel(mice)
		m = mice(i);
		rowsM = (T.Mouse == m);
		bu = unique(uint64(T.BlockUID(rowsM)));
		hasAudio = false;
		for bi = 1:numel(bu)
			b = bu(bi);
			trB = (uint64(Tr.BlockUID) == b);
			stimB = Tr.Stimulus(trB);
			if ~any(stimB == "LightWater")
				continue;
			end
			if any(stimB == "AudioWater")
				hasAudio = true;
				break;
			end
		end
		bad(i) = hasAudio;
	end

	badMice = mice(bad);
end

function T = iAddSessionIndex(T)
	T.Mouse = string(T.Mouse);
	T.Group = string(T.Group);
	T = sortrows(T, {'Group','Mouse','DateTime'});
	[G, ~] = findgroups(T.Group, T.Mouse);
	T.Session = zeros(height(T), 1);
	ug = unique(G);
	for gi = 1:numel(ug)
		rows = (G == ug(gi));
		T.Session(rows) = (1:sum(rows)).';
	end
end

function T = iAddBaselinePerf(T)
	T.Mouse = string(T.Mouse);
	T.Group = string(T.Group);
	T = sortrows(T, {'Group','Mouse','Session'});
	T.BaselinePerf = nan(height(T), 1);
	[G, ~] = findgroups(T.Group, T.Mouse);
	ug = unique(G);
	for gi = 1:numel(ug)
		rows = (G == ug(gi));
		p = double(T.Performance(rows));
		b0 = p(1);
		if ~isfinite(b0)
			b0 = mean(p, 'omitnan');
		end
		T.BaselinePerf(rows) = b0;
	end
end

function perMouse = iPerMouseSlope(allSessions)
	T = allSessions;
	T.Mouse = string(T.Mouse);
	T.Group = string(T.Group);
	T = sortrows(T, {'Group','Mouse','Session'});

	[mice, ~, g] = unique(T.Mouse);
	group = strings(numel(mice), 1);
	slope = nan(numel(mice), 1);
	nSess = nan(numel(mice), 1);
	baselinePerf = nan(numel(mice), 1);

	for i = 1:numel(mice)
		rows = (g == i);
		group(i) = string(T.Group(find(rows, 1, 'first')));
		x = double(T.Session(rows));
		y = double(T.Performance(rows));
		b0 = y(1);
		if ~isfinite(b0)
			b0 = mean(y, 'omitnan');
		end
		baselinePerf(i) = b0;
		ok = isfinite(x) & isfinite(y);
		x = x(ok);
		y = y(ok);
		nSess(i) = numel(x);
		if numel(x) < 2
			continue;
		end
		p = polyfit(x, y, 1);
		slope(i) = p(1);
	end

	perMouse = table(mice, group, slope, nSess, baselinePerf, 'VariableNames', {'Mouse','Group','Slope','NSessions','BaselinePerf'});
end

function iAssertNoCrossSourceDuplicateMice(T, groupName)
	if isempty(T)
		return;
	end
	T.Mouse = string(T.Mouse);
	T.Source = string(T.Source);

	U = unique(T(:, {'Mouse','Source'}));
	[mice, ~, g] = unique(string(U.Mouse));
	nSrc = splitapply(@(x) numel(unique(x)), string(U.Source), g);
	bad = mice(nSrc > 1);
	if isempty(bad)
		return;
	end

	msgLines = strings(numel(bad), 1);
	for idx = 1:numel(bad)
		m = bad(idx);
		src = unique(string(U.Source(string(U.Mouse) == m)));
		msgLines(idx) = m + " -> " + strjoin(src, ", ");
	end

	error('English_Fig1M:DuplicateMouseAcrossSources', ...
		'Duplicate mouse IDs across sources in group %s:\n%s', char(string(groupName)), char(strjoin(msgLines, newline)));
end

function iAssertNoMouseAppearsInMultipleGroups(T)
	if isempty(T)
		return;
	end
	T.Mouse = string(T.Mouse);
	T.Group = string(T.Group);

	[mice, ~, g] = unique(T.Mouse);
	ng = splitapply(@(x) numel(unique(x)), T.Group, g);
	bad = mice(ng > 1);
	if isempty(bad)
		return;
	end

	msgLines = strings(numel(bad), 1);
	for i = 1:numel(bad)
		m = bad(i);
		gs = unique(T.Group(T.Mouse == m));
		msgLines(i) = m + " -> " + strjoin(gs, ", ");
	end
	warning('English_Fig1M:MouseInMultipleGroups', 'Some mice appear in multiple groups:\n%s', char(strjoin(msgLines, newline)));
end

function T = iTrimAtCeiling_ExcludeFirstCeiling(T)
	% For slope calculation:
	% For each mouse, exclude the first Performance==1 session and any later sessions.
	if isempty(T)
		return;
	end

	oneTol = 1 - 1e-12;

	T.Mouse = string(T.Mouse);
	T.Group = string(T.Group);
	T.DateTime = iNormalizeDateTime(T.DateTime);
	T.Performance = double(T.Performance);
	T = sortrows(T, {'Group','Mouse','DateTime'});

	[G, ~] = findgroups(T.Group, T.Mouse);
	ug = unique(G);
	out = cell(numel(ug), 1);

	for gi = 1:numel(ug)
		rows = (G == ug(gi));
		S = T(rows, :);
		S = sortrows(S, 'DateTime');
		p = double(S.Performance);
		if isempty(p)
			continue;
		end
		i100 = find(isfinite(p) & (p >= oneTol), 1, 'first');
		if ~isempty(i100)
			S = S(1:i100-1, :);
		end
		if height(S) < 2
			continue;
		end
		out{gi} = S;
	end

	out = out(~cellfun('isempty', out));
	if isempty(out)
		T = table();
		return;
	end
	T = vertcat(out{:});
	T = sortrows(T, {'Group','Mouse','DateTime'});
end

function T = iTrimAfterCeiling_KeepFirstCeiling(T)
	% For plotting:
	% For each mouse, keep sessions up to and including the first Performance==1 session,
	% but exclude any sessions after it.
	if isempty(T)
		return;
	end

	oneTol = 1 - 1e-12;

	T.Mouse = string(T.Mouse);
	T.Group = string(T.Group);
	T.DateTime = iNormalizeDateTime(T.DateTime);
	T.Performance = double(T.Performance);
	T = sortrows(T, {'Group','Mouse','DateTime'});

	[G, ~] = findgroups(T.Group, T.Mouse);
	ug = unique(G);
	out = cell(numel(ug), 1);

	for gi = 1:numel(ug)
		rows = (G == ug(gi));
		S = T(rows, :);
		S = sortrows(S, 'DateTime');
		p = double(S.Performance);
		if isempty(p)
			continue;
		end
		i100 = find(isfinite(p) & (p >= oneTol), 1, 'first');
		if ~isempty(i100)
			S = S(1:i100, :);
		end
		if height(S) < 1
			continue;
		end
		out{gi} = S;
	end

	out = out(~cellfun('isempty', out));
	if isempty(out)
		T = table();
		return;
	end
	T = vertcat(out{:});
	T = sortrows(T, {'Group','Mouse','DateTime'});
end
