% 图3.1d：增长斜率差异
%
% Plot: per-mouse growth slope (one dot per mouse), baseline-adjusted via
% residualization against baseline performance.
% P-value annotation on figure uses a simplified per-mouse model (via MATLAB.Graphics.PLine).
% (LME and ranksum p-values are still computed and saved to statsOut for reference.)
% LME:
%   Perf ~ 1 + Session + Group + Session:Group + BaselinePerf + Session:BaselinePerf + (1+Session|Mouse)
%
% Cohorts (consistent with Fig3.1a/3.1b/3.1c):
% - Naive 组：LightAudioBaseline + LAInterspersed + LAPureBehavior
% - Transfer 组：AudioLightBaseline + ALPureBehavior
%
% Hard constraints:
% - Session performance must be computed from Trials where Stimulus=="LightWater"
%   (robust to mixed-stimulus sessions; do NOT trust block-level Performance).
% - For trajectories:
%   - Naive cohort uses Phase in {"Naive","Learned"}
%   - Transfer cohort uses Phase in {"Transfer","Final"}
% - Exclude mice in LAInterspersed whose Naive blocks mix AudioWater trials.
% - No duplicate mouse IDs across sources; no mouse appears in both groups.
% - Export SVG only to \\Data-Server-2\个人数据\张天夫\202601
%
% Execution (hard requirements):
% - This file MUST remain a SCRIPT (do not convert to function).
% - Do NOT use run.
% - Open in MATLAB Editor and Run/F5.

outDirUNC = "\\Data-Server-2\个人数据\张天夫\202601";

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

if ~exist('fitlme','file')
	error('Fig3_1d:MissingFitLME', 'fitlme is not available (Statistics and Machine Learning Toolbox required).');
end

% --- 1) Load datasets
LAB  = TransferLearning.LightAudioBaseline();   % 成像：光→声（LightWater 是 Naive）
LAI  = TransferLearning.LAInterspersed();       % 成像：交错（含 Naive LightWater；需剔除混掺 AudioWater 的鼠）
ALB  = TransferLearning.AudioLightBaseline();   % 成像：声→光（LightWater 是 Transfer）
LAPB = TransferLearning.LAPureBehavior();       % 纯行为：光→声（LightWater 是 Naive）
ALPB = TransferLearning.ALPureBehavior();       % 纯行为：声→光（LightWater 是 Transfer）

% --- 2) Query and sessionize (one row per mouse per session)
% IMPORTANT: slope needs the full learning curve, not just two tagged sessions.
% For each mouse:
%   - Find start session time (Phase==Naive/Transfer)
%   - Find end session time   (Phase==Learned/Final)
%   - Include ALL sessions between (inclusive), sorted by DateTime
% Session performance is computed from Trials where Stimulus=="LightWater".

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
	warning('Fig3_1d:EmptyData', '%s', 'No LightWater sessions found.');
	perMouse = table();
	statsOut = struct('Formula', "", 'Coefficient', "", 'Estimate', nan, 'CI', [nan nan], 'PValue', nan, 'NRows', 0, 'NMouse', 0, 'SlopeP', nan, 'SlopeAdjP', nan);
	lme = [];
	return;
end

allSessions = sortrows(allSessions, {'Group','Mouse','DateTime'});
allSessions = iAddSessionIndex(allSessions);
allSessions = iAddBaselinePerf(allSessions);

% Build model table
mdlT = allSessions(:, {'Mouse','Group','Session','Performance','BaselinePerf'});
mdlT.Mouse = categorical(string(mdlT.Mouse));
mdlT.Group = categorical(string(mdlT.Group));
mdlT.Session = double(mdlT.Session);
mdlT.Performance = double(mdlT.Performance);
mdlT.BaselinePerf = double(mdlT.BaselinePerf);

keep = isfinite(mdlT.Session) & isfinite(mdlT.Performance) & isfinite(mdlT.BaselinePerf);
mdlT = mdlT(keep, :);

% --- 3) Fit mixed-effects model
% Add Session:BaselinePerf to explicitly control ceiling/baseline-dependent slopes.
formula = 'Performance ~ 1 + Session + Group + Session:Group + BaselinePerf + Session:BaselinePerf + (1+Session|Mouse)';
lme = fitlme(mdlT, formula);

[beta, ci, pLME, coefName] = iGetInteractionEffect(lme);

statsOut = struct( ...
	'Formula', string(formula), ...
	'Coefficient', string(coefName), ...
	'Estimate', beta, ...
	'CI', ci, ...
	'PValue', pLME, ...
	'NRows', height(mdlT), ...
	'NMouse', numel(categories(mdlT.Mouse)));

% --- 4) Per-mouse slope (for visualization)
perMouse = iPerMouseSlope(allSessions);

% Baseline/ceiling effect is strong: raw slopes are largely driven by starting
% performance. Remove baseline effect for the swarmchart comparison.
% Note: With current cohort definitions, each mouse has exactly 2 sessions, so
% Slope is estimated from all sessions between start/end tags. Use robust
% regression to avoid single-mouse leverage creating extreme residuals.
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

xNaive = perMouse.Slope(string(perMouse.Group) == "Naive");
xTran  = perMouse.Slope(string(perMouse.Group) == "Transfer");
xNaive = xNaive(isfinite(xNaive));
xTran  = xTran(isfinite(xTran));

if isempty(xNaive) || isempty(xTran)
	pSwarm = nan;
else
	pSwarm = ranksum(xNaive, xTran);
end

xNaiveAdj = perMouse.SlopeAdj(string(perMouse.Group) == "Naive");
xTranAdj  = perMouse.SlopeAdj(string(perMouse.Group) == "Transfer");
xNaiveAdj = xNaiveAdj(isfinite(xNaiveAdj));
xTranAdj  = xTranAdj(isfinite(xTranAdj));

if isempty(xNaiveAdj) || isempty(xTranAdj)
	pSwarmAdj = nan;
else
	pSwarmAdj = ranksum(xNaiveAdj, xTranAdj);
end

statsOut.SlopeP = pSwarm;
statsOut.SlopeAdjP = pSwarmAdj;

% --- 4.5) Simplified per-mouse model (requested): Slope ~ 1 + Group + BaselinePerf
% This tests group difference while controlling for first-session performance.
statsOut.SimpleModel = struct('Formula', "", 'Coefficient', "", 'Estimate', nan, 'CI', [nan nan], 'PValue', nan, 'NMouse', 0);
try
	Tm = perMouse(:, {'Mouse','Group','Slope','BaselinePerf'});
	Tm.Mouse = categorical(string(Tm.Mouse));
	Tm.Group = categorical(string(Tm.Group));
	Tm.Slope = double(Tm.Slope);
	Tm.BaselinePerf = double(Tm.BaselinePerf);
	okM = isfinite(Tm.Slope) & isfinite(Tm.BaselinePerf) & ~isundefined(Tm.Group);
	Tm = Tm(okM, :);
	if ~isempty(Tm)
		simpleFormula = 'Slope ~ 1 + Group + BaselinePerf';
		lmSimple = fitlm(Tm, simpleFormula);
		ciSimple = coefCI(lmSimple);
		C = lmSimple.Coefficients;
		idx = find(strcmp(string(C.Properties.RowNames), 'Group_Transfer'), 1);
		if isempty(idx)
			idx = find(startsWith(string(C.Properties.RowNames), 'Group_'), 1);
		end
		if ~isempty(idx)
			statsOut.SimpleModel.Formula = string(simpleFormula);
			statsOut.SimpleModel.Coefficient = string(C.Properties.RowNames{idx});
			statsOut.SimpleModel.Estimate = C.Estimate(idx);
			statsOut.SimpleModel.CI = ciSimple(idx, :);
			statsOut.SimpleModel.PValue = C.pValue(idx);
			statsOut.SimpleModel.NMouse = height(Tm);
		end
	end
catch
end
%% 

% --- 5) Plot using UniExp.BarScatterCompare (1D syntax: struct, no legend)
% Use descriptive group fields and label as Naive / Trans.
Groups = struct('Naive', {xNaiveAdj(:)}, 'Trans', {xTranAdj(:)});

f = figure('Color','none', 'Name', 'Fig3.1d Growth slope');
set(f, 'InvertHardcopy', 'off');
set(f, 'Units', 'centimeters', 'Position', [5 5 4 4]); % 20mm x 15mm

t = tiledlayout(1,1,'TileSpacing','compact','Padding','compact');
try
	set(t, 'BackgroundColor', 'none');
catch
end
ax = nexttile;
try
	set(ax, 'Color', 'none');
catch
end

% BarScatterCompare: struct input = 1D comparison, no legend
[~, ~, Bars, ErrorBars] = UniExp.BarScatterCompare(Groups, false);

ax.FontSize = 12;
% Use explicit XTick labels instead of single-letter abbreviations
try
	ax.XTick = 1:2;
	ax.XTickLabel = {'Nai.', 'Tra.'};
catch
end

% 设置条形和误差条边框粗细
for b = Bars(:)'
	b.LineWidth = 0.5;
end
for eb = ErrorBars.Object(:)'
	eb.LineWidth = 0.5;
end

title(ax, 'Norm. slope');
% remove main title (user requested)
% title removed
% Match bar colors to Fig1B lines (red/blue)
colorNaive = [1, 0, 0];  % red
colorTrans = [0, 0, 1];  % blue
try
	if numel(Bars) == 1
		Bars.FaceColor = 'flat';
		Bars.CData = [colorNaive; colorTrans];
		Bars.BarWidth = 0.5; % narrower bars for larger gap
		Bars.FaceAlpha = 1/3; % 透明度
	end
	ax.XLim = [0.5, 2.5];
catch
end
box(ax,'on');

% p-value line (via MATLAB.Graphics.PLine) — use ErrorBars as descriptor object
pAnnot = statsOut.SimpleModel.PValue;
if isfinite(pAnnot) && height(ErrorBars) >= 2
	pText = "";
	if pAnnot < 0.05
		pText = "*";
	end
	if strlength(pText) > 0
		% Use ErrorBars table: two different Objects, each with Index=1
		Descriptors = table(ErrorBars.Object(1), ErrorBars.Object(2), 1, 1, pText, 0, ...
			'VariableNames', {'ObjectA','ObjectB','IndexA','IndexB','Text','ExtraOffset'});
		try
			[~, pTexts] = MATLAB.Graphics.PLine(Descriptors);
		catch
		end
	end
end



% --- 5) Export (SVG only)
try
	if ~isfolder(outDirUNC)
		mkdir(outDirUNC);
	end
catch
end

svgPath = fullfile(outDirUNC, 'English_Fig1D_GrowthSlope.svg');
box off
try
	TransferLearning.PrintFigure(f, svgPath);
	fprintf('Wrote: %s\n', svgPath);
catch ME
	warning(ME.identifier, 'Export failed: %s', ME.message);
end

% Script outputs (in caller workspace): perMouse, statsOut, lme, allSessions

%% --- local functions
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
		fprintf('Fig3.1d: LAInterspersed excluded %d mice with AudioWater mixed into %s phase.\n', numel(badMice), char(string(startPhase)));
		fprintf('  Excluded mice: %s\n', char(strjoin(string(badMice), ', ')));
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
		error('Fig3_1d:BlockQueryFailed', 'Block query failed for %s: %s', class(DS), ME.message);
	end

	if isempty(Tblk)
		Tblk = table();
		return;
	end

	if ~isprop(DS, 'Trials')
		error('Fig3_1d:MissingTrials', 'DataSet %s has no Trials; cannot compute LightWater-only performance.', class(DS));
	end
	Tr = DS.Trials;
	need = {'BlockUID','Stimulus','Behavior'};
	if ~all(ismember(need, Tr.Properties.VariableNames))
		error('Fig3_1d:TrialsMissingFields', 'Trials table for %s lacks required fields: %s', class(DS), strjoin(setdiff(need, Tr.Properties.VariableNames), ','));
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
	% Input must contain Mouse, DateTime, Performance, BlockUID (block-level rows)
	T.DateTime = datetime(T.DateTime);
	T.DateTime.TimeZone = '';
	[G, mouse, dt] = findgroups(string(T.Mouse), T.DateTime);
	perf = splitapply(@(x) mean(x,'omitnan'), double(T.Performance), G);
	nBlocks = splitapply(@numel, double(T.Performance), G);
	T = table(mouse, dt, perf, nBlocks, 'VariableNames', {'Mouse','DateTime','Performance','NBlocksInSession'});
end

function badMice = iFindMiceWithAudioWaterInPhase(DS, phaseName)
	% A mouse is considered "mixed" if any block in the given phase contains AudioWater trials.
	try
		T = DS.TableQuery(["Mouse","BlockUID"], Phase=phaseName);
	catch ME
		error('Fig3_1d:PureNaiveQueryFailed', 'Pure-Naive query failed for %s: %s', class(DS), ME.message);
	end
	if isempty(T)
		badMice = strings(0,1);
		return;
	end
	if ~isprop(DS, 'Trials')
		error('Fig3_1d:MissingTrials', 'DataSet %s has no Trials; cannot detect AudioWater mixing.', class(DS));
	end
	Tr = DS.Trials;
	if ~ismember('Stimulus', Tr.Properties.VariableNames) || ~ismember('BlockUID', Tr.Properties.VariableNames)
		error('Fig3_1d:TrialsMissingFields', 'Trials table for %s lacks Stimulus/BlockUID.', class(DS));
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
			% Only consider blocks that actually contain LightWater trials
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
	% Adds Session (1..N per mouse) after sorting by Mouse, DateTime
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

	error('Fig3_1d:DuplicateMouseAcrossSources', ...
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
	error('Fig3_1d:MouseInMultipleGroups', 'Some mice appear in multiple groups (Naive/Transfer):\n%s', char(strjoin(msgLines, newline)));
end

function [beta, ci, pval, coefName] = iGetInteractionEffect(lme)
	C = lme.Coefficients;
	idx = find(contains(string(C.Name), "Session:Group_Transfer"), 1);
	if isempty(idx)
		idx = find(contains(string(C.Name), "Group_Transfer:Session"), 1);
	end
	if isempty(idx)
		error('Fig3_1d:MissingInteraction', 'Could not find Session×Group(Transfer) coefficient in lme.Coefficients.Name.');
	end
	coefName = string(C.Name(idx));
	beta = C.Estimate(idx);
	pval = C.pValue(idx);
	CI = coefCI(lme);
	ci = CI(idx, :);
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
