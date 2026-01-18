% Fig3.2e: Reuse vs Performance and Learning rate (4 subplots)
%
% Per outline (论文大纲.md):
% - Each point is ONE session (not one mouse).
% - Transfer->Final reuse (denominator=Final actives):
%     For each session from first Transfer up to BEFORE first Final (incl Transfer, excl Final),
%     Reuse(session) = |Active(session) ∩ Active(Final endpoint)| / |Active(Final endpoint)|
% - Naive->Learned reuse (denominator=Learned actives):
%     For each session from first Naive up to BEFORE first Learned (incl Naive, excl Learned),
%     Reuse(session) = |Active(session) ∩ Active(Learned endpoint)| / |Active(Learned endpoint)|
% - Active definition (updated):
%     Z(1s) > mean(Z(-3~0s)) + 3*std(Z(-3~0s))
%   where Z is per-cell NTATS Median ZScore from QueryNTATS.
% - Learning rate computation (within a trajectory):
%     * Exclude sessions with Performance==0% or 100%
%     * Exclude ALL sessions after the first 100% session (including that 100% session)
%     * Remove the effect of current Performance when defining speed
%       (implemented by regressing DeltaPerf on current Perf pooled across mice and using residual DeltaPerf).
%
% Output:
% - SVG only to \\Data-Server-2\个人数据\张天夫\202601
%
% Execution:
% - This file MUST remain a SCRIPT.
% - Call via package name (do NOT use run):
%     TransferLearning.Fig32.E_ReuseVsLearningRate

outDirUNC = "\\Data-Server-2\个人数据\张天夫\202601";
svgName = "Fig3_2e_ReuseVsPerformanceAndLearningRate.svg";

excludeMice = string([]);
minDenActive = 10;     % minimum #denominator-active cells to define reuse
minCommonCells = 20;   % minimum #common cells for reuse computation
minDeltaSteps = 2;     % minimum #deltaPerf steps to define learning rate
kSigma = 3;
perfEps = 1e-6;

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

xs = TransferLearning.Xs;
xsSec = seconds(xs);
baseMask = (xsSec >= -3) & (xsSec < 0);
if ~any(baseMask)
	error('Fig3_2e:BadTimeMask', 'Baseline window (-3~0s) has no samples.');
end
[~, idx1s] = min(abs(xsSec - 1));

% -----------------------------
% A) Transfer cohort (ALB): Final reuse vs (Transfer perf, Transfer learning rate)
% -----------------------------
DS_T = TransferLearning.AudioLightBaseline();
FinalPts = table;
SkipFinal = strings(0,2);

Ttran = iTableQueryOrEmpty(DS_T, ["Mouse"], Phase="Transfer", Stimulus="LightWater");
Tfin  = iTableQueryOrEmpty(DS_T, ["Mouse"], Phase="Final",    Stimulus="LightWater");
if isempty(Ttran) || isempty(Tfin)
	error('Fig3_2e:MissingTransferFinal', 'Missing Transfer/Final LightWater trials in AudioLightBaseline.');
end
Ttran.Mouse = string(Ttran.Mouse);
Tfin.Mouse  = string(Tfin.Mouse);
Ttran = Ttran(~ismember(Ttran.Mouse, excludeMice), :);
Tfin  = Tfin(~ismember(Tfin.Mouse,  excludeMice), :);
miceT = intersect(unique(Ttran.Mouse), unique(Tfin.Mouse));

[FinalPts, SkipFinal] = iComputeReusePoints(DS_T, miceT, "Transfer", "Final", "ALB", false, ...
	minDenActive, minCommonCells, baseMask, idx1s, kSigma);

[SpeedT, StepsT, SkipSpeedT, mdlT] = iComputeLearningRate(DS_T, miceT, "Transfer", "Final", minDeltaSteps, perfEps, false);
StepsT.Source = repmat("ALB", height(StepsT), 1);

% -----------------------------
% B) Naive cohort (LAB+LAI): Learned reuse vs (Naive perf, Naive learning rate)
% -----------------------------
LearnedPts = table;
SkipLearned = strings(0,2);

srcNames = ["LightAudioBaseline","LAInterspersed"];
srcDS = {TransferLearning.LightAudioBaseline(), TransferLearning.LAInterspersed()};

for s = 1:numel(srcNames)
	src = srcNames(s);
	DS_N = srcDS{s};
	Tn = iTableQueryOrEmpty(DS_N, ["Mouse"], Phase="Naive",  Stimulus="LightWater");
	Tl = iTableQueryOrEmpty(DS_N, ["Mouse"], Phase="Learned", Stimulus="LightWater");
	if isempty(Tn) || isempty(Tl)
		continue;
	end
	Tn.Mouse = string(Tn.Mouse);
	Tl.Mouse = string(Tl.Mouse);
	Tn = Tn(~ismember(Tn.Mouse, excludeMice), :);
	Tl = Tl(~ismember(Tl.Mouse, excludeMice), :);
	miceSrc = intersect(unique(Tn.Mouse), unique(Tl.Mouse));
	if isempty(miceSrc)
		continue;
	end

	[ptsTmp, skipTmp] = iComputeReusePoints(DS_N, miceSrc, "Naive", "Learned", src, true, ...
		minDenActive, minCommonCells, baseMask, idx1s, kSigma);
	LearnedPts = [LearnedPts; ptsTmp]; %#ok<AGROW>
	SkipLearned = [SkipLearned; skipTmp]; %#ok<AGROW>
end

if isempty(LearnedPts)
	error('Fig3_2e:NoLearnedPts', 'No sessions passed Learned reuse computation requirements.');
end

% Compute learning rate within Naive->Learned trajectory, per DS source separately (no cross-DS pooling).
SpeedN_all = table;
StepsN_all = table;
SkipSpeedN_all = table(string.empty(0,1), string.empty(0,1), 'VariableNames', {'Mouse','Reason'});
mdlN = [];

for s = 1:numel(srcNames)
	src = srcNames(s);
	DS_N = srcDS{s};
	miceSrc = unique(LearnedRows.Mouse(LearnedRows.Source==src));
	if isempty(miceSrc)
		continue;
	end
	[SpeedN, StepsN, SkipSpeedN, mdlTmp] = iComputeLearningRate(DS_N, miceSrc, "Naive", "Learned", minDeltaSteps, perfEps, true);
	if ~isempty(SpeedN)
		SpeedN.Source = repmat(src, height(SpeedN), 1);
		SpeedN_all = [SpeedN_all; SpeedN]; %#ok<AGROW>
	end
	if ~isempty(StepsN)
		StepsN.Source = repmat(src, height(StepsN), 1);
		StepsN_all = [StepsN_all; StepsN]; %#ok<AGROW>
	end
	if ~isempty(SkipSpeedN)
		SkipSpeedN_all = [SkipSpeedN_all; SkipSpeedN]; %#ok<AGROW>
	end
	if isempty(mdlN) && ~isempty(mdlTmp)
		mdlN = mdlTmp;
	end
end

% -----------------------------
% Plot 2x2 correlations
% -----------------------------
f = figure('Color','w', 'Name','Reuse vs Performance & Learning rate');
MATLAB.Graphics.FigureAspectRatio(8,6,1/2);
TL = tiledlayout(2,2,'TileSpacing','compact','Padding','compact');

ax11 = nexttile(TL,1);
iScatterCorr(ax11, FinalPts.Reuse, FinalPts.PerfCurr, 'Final reuse', 'Performance');

ax12 = nexttile(TL,2);
T12 = innerjoin(FinalPts(:,{'Mouse','DateTime','Reuse'}), StepsT(:,{'Mouse','DateTimeCurr','ResidDelta'}), ...
	'LeftKeys', {'Mouse','DateTime'}, 'RightKeys', {'Mouse','DateTimeCurr'});
iScatterCorr(ax12, T12.Reuse, T12.ResidDelta, 'Final reuse', 'Learn rate (resid \DeltaPerf)');

ax21 = nexttile(TL,3);
iScatterCorr(ax21, LearnedPts.Reuse, LearnedPts.PerfCurr, 'Learned reuse', 'Performance');

ax22 = nexttile(TL,4);
T22 = innerjoin(LearnedPts(:,{'Mouse','DateTime','Reuse','Source'}), StepsN_all(:,{'Mouse','DateTimeCurr','ResidDelta','Source'}), ...
	'LeftKeys', {'Mouse','DateTime','Source'}, 'RightKeys', {'Mouse','DateTimeCurr','Source'});
iScatterCorr(ax22, T22.Reuse, T22.ResidDelta, 'Learned reuse', 'Learn rate (resid \DeltaPerf)');

sgtitle(TL, 'Reuse vs performance and learning rate', 'Interpreter','none');

% Export (SVG only)
try
	if ~isfolder(outDirUNC)
		mkdir(outDirUNC);
	end
catch
end
svgPath = fullfile(outDirUNC, svgName);
try
	exportgraphics(f, svgPath, 'ContentType','vector');
	fprintf('Wrote: %s\n', svgPath);
catch ME
	warning(ME.identifier, 'Export failed: %s', ME.message);
end

% -----------------------------
% Expose debug tables
% -----------------------------
assignin('base','Fig3_2e_FinalPts', FinalPts);
assignin('base','Fig3_2e_LearnedPts', LearnedPts);
assignin('base','Fig3_2e_Steps_Transfer', StepsT);
assignin('base','Fig3_2e_Steps_Naive', StepsN_all);
if ~isempty(mdlT)
	assignin('base','Fig3_2e_DeltaPerfModel_Transfer', mdlT);
end
if ~isempty(mdlN)
	assignin('base','Fig3_2e_DeltaPerfModel_Naive', mdlN);
end
if ~isempty(SkipFinal)
	assignin('base','Fig3_2e_Skipped_FinalReuse', array2table(SkipFinal, 'VariableNames', {'Mouse','Reason'}));
end
if ~isempty(SkipLearned)
	assignin('base','Fig3_2e_Skipped_LearnedReuse', array2table(SkipLearned, 'VariableNames', {'Mouse','Reason'}));
end
if ~isempty(SkipSpeedT)
	assignin('base','Fig3_2e_Skipped_Speed_Transfer', SkipSpeedT);
end
if ~isempty(SkipSpeedN_all)
	assignin('base','Fig3_2e_Skipped_Speed_Naive', SkipSpeedN_all);
end

%% --- local functions
function T = iTableQueryOrEmpty(DS, vars, varargin)
	try
		T = DS.TableQuery(vars, varargin{:});
	catch
		T = [];
	end
	if isempty(T)
		return;
	end
	if ismember('DateTime', T.Properties.VariableNames)
		try
			T.DateTime = datetime(T.DateTime);
			T.DateTime.TimeZone = '';
		catch
		end
	end
end

function cellUID = iMouseCellUID(DS, mouseName)
	cellUID = uint64([]);
	try
		C = DS.Cells;
		if isempty(C) || ~all(ismember({'Mouse','CellUID'}, C.Properties.VariableNames))
			return;
		end
		C.Mouse = string(C.Mouse);
		m = string(mouseName);
		cellUID = unique(uint64(C.CellUID(C.Mouse == m)));
	catch
		cellUID = uint64([]);
	end
end

function Z = iMedianTraceZScore(DS, cellUID, trialUID)
	Z = [];
	if isempty(cellUID) || isempty(trialUID)
		return;
	end
	q = struct('CellUID', uint64(cellUID), 'TrialUID', uint64(trialUID));
	G = iQueryNTATSOrEmpty(DS, q);
	if isempty(G) || ~all(ismember({'CellUID','NTATS'}, G.Properties.VariableNames))
		return;
	end
	X = iNtatsData(G.NTATS);
	if isempty(X)
		return;
	end
	Z = table(uint64(G.CellUID), X, 'VariableNames', {'CellUID','Trace'});
end

function G = iQueryNTATSOrEmpty(DS, query)
	try
		G = DS.QueryNTATS(query, UniExp.Flags.ZScore, 1:24, UniExp.Flags.Median);
	catch
		G = [];
	end
end

function X = iNtatsData(NT)
	if isa(NT, 'MATLAB.DataTypes.NDTable')
		X = NT.Data;
	else
		X = NT;
	end
	X = squeeze(X);
end

function act = iActiveAt1s(X, baseMask, idx1s, kSigma)
	% X: [nCells x nTime]
	baseMu = mean(X(:, baseMask), 2, 'omitnan');
	baseSd = std(X(:, baseMask), 0, 2, 'omitnan');
	z1 = X(:, idx1s);
	act = z1 > (baseMu + kSigma .* baseSd);
	act(~isfinite(z1) | ~isfinite(baseMu) | ~isfinite(baseSd)) = false;
end

function Sess = iSessionizeByDateTime(T)
	% Input must contain Mouse, DateTime, Performance, Phase
	if isempty(T)
		Sess = T;
		return;
	end
	T.Mouse = string(T.Mouse);
	if ~isdatetime(T.DateTime)
		try
			T.DateTime = datetime(T.DateTime);
			T.DateTime.TimeZone = '';
		catch
		end
	end
	T.Phase = string(T.Phase);

	[G, mouse, dt] = findgroups(T.Mouse, T.DateTime);
	perf = splitapply(@(x) mean(double(x), 'omitnan'), T.Performance, G);
	phase = splitapply(@(x) iPickPhase(string(x)), T.Phase, G);
	Sess = table(mouse, dt, perf, phase, 'VariableNames', {'Mouse','DateTime','Performance','Phase'});
	Sess = sortrows(Sess, {'Mouse','DateTime'});
	% add session index per mouse
	[Gm, ~] = findgroups(Sess.Mouse);
	sessIdxCell = splitapply(@(x) {(1:numel(x))'}, Sess.DateTime, Gm);
	Sess.Session = vertcat(sessIdxCell{:});
end

function SessT = iSessionizeTrialsByDateTime(T)
	% Input must contain Mouse, DateTime, Performance, Phase, TrialUID
	SessT = table;
	if isempty(T)
		return;
	end
	T.Mouse = string(T.Mouse);
	if ~isdatetime(T.DateTime)
		try
			T.DateTime = datetime(T.DateTime);
			T.DateTime.TimeZone = '';
		catch
		end
	end
	T.Phase = string(T.Phase);

	[G, mouse, dt] = findgroups(T.Mouse, T.DateTime);
	perf = splitapply(@(x) mean(double(x), 'omitnan'), T.Performance, G);
	phase = splitapply(@(x) iPickPhase(string(x)), T.Phase, G);
	trialUIDs = splitapply(@(x) {unique(uint64(x(:)))}, T.TrialUID, G);
	SessT = table(mouse, dt, perf, phase, trialUIDs, 'VariableNames', {'Mouse','DateTime','Performance','Phase','TrialUIDs'});
	SessT = sortrows(SessT, {'Mouse','DateTime'});
	% add session index per mouse
	[Gm, ~] = findgroups(SessT.Mouse);
	sessIdxCell = splitapply(@(x) {(1:numel(x))'}, SessT.DateTime, Gm);
	SessT.Session = vertcat(sessIdxCell{:});
end

function p = iPickPhase(ph)
	% choose first non-empty/non-missing phase label
	ph = string(ph);
	ph = ph(ph ~= "" & ph ~= "<undefined>" & ~ismissing(ph));
	if isempty(ph)
		p = "";
	else
		p = ph(1);
	end
end

function Seg = iSelectSessionsBetweenPhases(Sess, mouseName, startPhase, endPhase)
	Seg = Sess([],:);
	if isempty(Sess)
		return;
	end
	m = string(mouseName);
	S = Sess(Sess.Mouse == m, :);
	if isempty(S)
		return;
	end
	S.Phase = string(S.Phase);
	idxStart = find(S.Phase == string(startPhase), 1, 'first');
	idxEnd   = find(S.Phase == string(endPhase),   1, 'last');
	if isempty(idxStart)
		return;
	end
	if isempty(idxEnd)
		idxEnd = height(S);
	end
	if idxEnd < idxStart
		return;
	end
	Seg = S(idxStart:idxEnd, :);
end

function p0 = iFirstPerfOfPhase(Sess, mouseName, phaseName)
	p0 = NaN;
	if isempty(Sess)
		return;
	end
	m = string(mouseName);
	S = Sess(Sess.Mouse == m, :);
	if isempty(S)
		return;
	end
	idx = find(string(S.Phase) == string(phaseName), 1, 'first');
	if isempty(idx)
		return;
	end
	p0 = double(S.Performance(idx));
end

function [speedRows, stepRows, skipSpeed, mdl] = iComputeLearningRate(DS, mice, startPhase, endPhase, minDeltaSteps, perfEps, excludeMixedSessions)
	% Returns per-mouse LearnRateResidual computed from residual DeltaPerf after regressing out PerfCurr.
	% If excludeMixedSessions=true: remove LightWater rows whose session (Mouse+DateTime) contains any AudioWater.
	skipSpeed = table(string.empty(0,1), string.empty(0,1), 'VariableNames', {'Mouse','Reason'});
	stepRows = table;
	for iM = 1:numel(mice)
		m = string(mice(iM));
		Tall = iTableQueryOrEmpty(DS, ["Mouse","DateTime","Phase","Stimulus","Performance"], Mouse=m, Stimulus="LightWater");
		if isempty(Tall)
			skipSpeed = [skipSpeed; table(m, "No LightWater rows", 'VariableNames', skipSpeed.Properties.VariableNames)]; %#ok<AGROW>
			continue;
		end

		if excludeMixedSessions
			Ta = iTableQueryOrEmpty(DS, ["Mouse","DateTime","Stimulus"], Mouse=m, Stimulus="AudioWater");
			if ~isempty(Ta)
				Ta.Mouse = string(Ta.Mouse);
				badKey = unique(Ta.Mouse + "|" + string(Ta.DateTime,'yyyy-MM-dd HH:mm:ss'));
				keyLW = string(Tall.Mouse) + "|" + string(Tall.DateTime,'yyyy-MM-dd HH:mm:ss');
				Tall = Tall(~ismember(keyLW, badKey), :);
			end
		end

		if isempty(Tall)
			skipSpeed = [skipSpeed; table(m, "No LightWater rows after mixed-session exclusion", 'VariableNames', skipSpeed.Properties.VariableNames)]; %#ok<AGROW>
			continue;
		end
		Tall.Mouse = string(Tall.Mouse);
		Tall.Phase = string(Tall.Phase);
		Tall = sortrows(Tall, 'DateTime');

		Sess = iSessionizeByDateTime(Tall(:, {'Mouse','DateTime','Performance','Phase'}));
		if isempty(Sess)
			skipSpeed = [skipSpeed; table(m, "No sessions after sessionize", 'VariableNames', skipSpeed.Properties.VariableNames)]; %#ok<AGROW>
			continue;
		end

		Seg = iSelectSessionsBetweenPhases(Sess, m, startPhase, endPhase);
		if isempty(Seg)
			skipSpeed = [skipSpeed; table(m, "Missing phase anchors", 'VariableNames', skipSpeed.Properties.VariableNames)]; %#ok<AGROW>
			continue;
		end

		perf = double(Seg.Performance(:));
		% Cut at first 100% (exclude that and after)
		idx100 = find(perf >= 1 - perfEps, 1, 'first');
		if ~isempty(idx100)
			Seg = Seg(1:idx100-1, :);
			perf = double(Seg.Performance(:));
		end

		% Exclude sessions with perf==0 or perf==1 (within kept prefix)
		keepSess = (perf > 0 + perfEps) & (perf < 1 - perfEps) & isfinite(perf);
		Seg = Seg(keepSess, :);
		perf = double(Seg.Performance(:));
		if numel(perf) < (minDeltaSteps + 1)
			skipSpeed = [skipSpeed; table(m, "Too few sessions after filters", 'VariableNames', skipSpeed.Properties.VariableNames)]; %#ok<AGROW>
			continue;
		end

		dPerf = diff(perf);
		pCurr = perf(1:end-1);
		if numel(dPerf) < minDeltaSteps
			skipSpeed = [skipSpeed; table(m, "Too few delta steps", 'VariableNames', skipSpeed.Properties.VariableNames)]; %#ok<AGROW>
			continue;
		end

		baselinePerf = double(iFirstPerfOfPhase(Sess, m, startPhase));
		dtCurr = Seg.DateTime(1:end-1);
		sessCurr = Seg.Session(1:end-1);
		stepRows = [stepRows; table(repmat(m, numel(dPerf), 1), dtCurr(:), sessCurr(:), pCurr(:), dPerf(:), repmat(baselinePerf, numel(dPerf), 1), ...
			'VariableNames', {'Mouse','DateTimeCurr','SessionCurr','PerfCurr','DeltaPerf','BaselinePerf'})]; %#ok<AGROW>
	end

	mdl = [];
	if isempty(stepRows)
		speedRows = table;
		return;
	end

	use = isfinite(stepRows.PerfCurr) & isfinite(stepRows.DeltaPerf);
	try
		mdl = fitlm(stepRows.PerfCurr(use), stepRows.DeltaPerf(use));
	catch
		mdl = [];
	end

	pred = nan(height(stepRows),1);
	if ~isempty(mdl)
		try
			pred = predict(mdl, stepRows.PerfCurr);
		catch
		end
	end
	stepRows.ResidDelta = stepRows.DeltaPerf - pred;

	[grp, mouseID] = findgroups(stepRows.Mouse);
	meanResid = splitapply(@(x) mean(x,'omitnan'), stepRows.ResidDelta, grp);
	nSteps    = splitapply(@(x) sum(isfinite(x)), stepRows.ResidDelta, grp);
	meanBase  = splitapply(@(x) mean(x,'omitnan'), stepRows.BaselinePerf, grp);
	speedRows = table(mouseID, meanResid, nSteps, meanBase, ...
		'VariableNames', {'Mouse','LearnRateResidual','NSteps','BaselinePerf'});
end


function [pts, skipped] = iComputeReusePoints(DS, mice, startPhase, endPhase, sourceName, excludeMixedSessions, minDenActive, minCommonCells, baseMask, idx1s, kSigma)
	% Returns per-session points between phases (incl start, excl first end),
	% with Reuse computed against the endpoint (last endPhase) denominator.
	pts = table;
	skipped = strings(0,2);
	for iM = 1:numel(mice)
		m = string(mice(iM));
		Tall = iTableQueryOrEmpty(DS, ["TrialUID","Mouse","DateTime","Phase","Stimulus","Performance"], Mouse=m, Stimulus="LightWater");
		if isempty(Tall)
			skipped(end+1,:) = [m, "No LightWater rows"]; %#ok<AGROW>
			continue;
		end
		Tall.Mouse = string(Tall.Mouse);
		Tall.Phase = string(Tall.Phase);

		if excludeMixedSessions
			Ta = iTableQueryOrEmpty(DS, ["Mouse","DateTime","Stimulus"], Mouse=m, Stimulus="AudioWater");
			if ~isempty(Ta)
				Ta.Mouse = string(Ta.Mouse);
				badKey = unique(Ta.Mouse + "|" + string(Ta.DateTime,'yyyy-MM-dd HH:mm:ss'));
				keyLW = string(Tall.Mouse) + "|" + string(Tall.DateTime,'yyyy-MM-dd HH:mm:ss');
				Tall = Tall(~ismember(keyLW, badKey), :);
			end
		end
		if isempty(Tall)
			skipped(end+1,:) = [m, "No LightWater rows after mixed-session exclusion"]; %#ok<AGROW>
			continue;
		end
		Tall = sortrows(Tall, 'DateTime');
		SessT = iSessionizeTrialsByDateTime(Tall(:,{'Mouse','DateTime','Performance','Phase','TrialUID'}));
		if isempty(SessT)
			skipped(end+1,:) = [m, "No sessions after sessionize"]; %#ok<AGROW>
			continue;
		end

		S = SessT(SessT.Mouse==m, :);
		S.Phase = string(S.Phase);
		idxStart = find(S.Phase==string(startPhase), 1, 'first');
		idxEndFirst = find(S.Phase==string(endPhase), 1, 'first');
		idxEndLast  = find(S.Phase==string(endPhase), 1, 'last');
		if isempty(idxStart) || isempty(idxEndFirst) || isempty(idxEndLast)
			skipped(end+1,:) = [m, "Missing phase anchors"]; %#ok<AGROW>
			continue;
		end
		if idxEndFirst <= idxStart
			skipped(end+1,:) = [m, "End phase occurs before start phase"]; %#ok<AGROW>
			continue;
		end
		segIdx = idxStart:(idxEndFirst-1);
		denIdx = idxEndLast;
		if isempty(segIdx)
			skipped(end+1,:) = [m, "Empty segment before end phase"]; %#ok<AGROW>
			continue;
		end

		cellUID = iMouseCellUID(DS, m);
		if numel(cellUID) < minCommonCells
			skipped(end+1,:) = [m, "Too few cells for mouse"]; %#ok<AGROW>
			continue;
		end

		tuDen = S.TrialUIDs{denIdx};
		Zd = iMedianTraceZScore(DS, cellUID, tuDen);
		if isempty(Zd)
			skipped(end+1,:) = [m, "MedianTraceZScore empty (den)"]; %#ok<AGROW>
			continue;
		end
		Zd = sortrows(Zd, 'CellUID');

		for ii = segIdx
			tuCurr = S.TrialUIDs{ii};
			Zc = iMedianTraceZScore(DS, cellUID, tuCurr);
			if isempty(Zc)
				continue;
			end
			common = intersect(uint64(Zc.CellUID), uint64(Zd.CellUID));
			if numel(common) < minCommonCells
				continue;
			end
			Zc2 = sortrows(Zc(ismember(uint64(Zc.CellUID), common), :), 'CellUID');
			Zd2 = sortrows(Zd(ismember(uint64(Zd.CellUID), common), :), 'CellUID');
			currAct = iActiveAt1s(Zc2.Trace, baseMask, idx1s, kSigma);
			denAct  = iActiveAt1s(Zd2.Trace, baseMask, idx1s, kSigma);
			if nnz(denAct) < minDenActive
				continue;
			end
			reuse = mean(double(currAct(denAct)), 'omitnan');
			pts = [pts; table(m, string(sourceName), S.DateTime(ii), S.Session(ii), double(S.Performance(ii)), ...
				numel(common), nnz(currAct), nnz(denAct), reuse, ...
				'VariableNames', {'Mouse','Source','DateTime','Session','PerfCurr','NCellsCommon','NCurrActive','NDenActive','Reuse'})]; %#ok<AGROW>
		end
	end
end

function iScatterCorr(ax, x, y, xlab, ylab)
	mask = isfinite(x) & isfinite(y);
	if nnz(mask) == 0
		cla(ax);
		axis(ax,'off');
		text(ax, 0.5, 0.5, 'No data', 'HorizontalAlignment','center');
		return;
	end
	hold(ax,'on');
	try
		if isprop(ax, 'Toolbar') && ~isempty(ax.Toolbar)
			ax.Toolbar.Visible = 'off';
		end
	catch
	end

	scatter(ax, x(mask), y(mask), 25, 'filled');
	if nnz(mask) >= 2 && std(x(mask),'omitnan') > 0
		pFit = polyfit(double(x(mask)), double(y(mask)), 1);
		xFit = [min(x(mask)) max(x(mask))];
		yFit = polyval(pFit, xFit);
		plot(ax, xFit, yFit, '-', 'LineWidth', 1.5);
	end
	grid(ax,'on');
	box(ax,'off');
	xlabel(ax, xlab);
	ylabel(ax, ylab);

	rho = NaN; p = NaN;
	if nnz(mask) >= 4 && std(x(mask),'omitnan') > 0 && std(y(mask),'omitnan') > 0
		try
			[rho, p] = corr(double(x(mask)), double(y(mask)), 'type','Spearman');
		catch
			% ignore
		end
	end
	if isfinite(p)
		title(ax, sprintf('rho=%.2f  p=%.3g  n=%d', rho, p, nnz(mask)), 'Interpreter','none');
	else
		title(ax, sprintf('n=%d', nnz(mask)), 'Interpreter','none');
	end
end
