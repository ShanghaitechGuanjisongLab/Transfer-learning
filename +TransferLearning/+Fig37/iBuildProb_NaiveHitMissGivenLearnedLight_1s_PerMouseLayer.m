function [rows, diag] = iBuildProb_NaiveHitMissGivenLearnedLight_1s_PerMouseLayer()
% Build per-mouse table for Fig3.7 panels involving P(N|L) and Hit/Miss variants.
%
% Definitions (per mouse, per layer):
%   L = Learned LightWater (last pure session; forbidden stimulus=AudioWater)
%   N = Naive  LightWater (first pure session; forbidden stimulus=AudioWater)
%
% Active definition (1 s):
%   Median NTATS ZScore at t≈1s > mean(-3~0s) + 3*std(-3~0s)
%
% P(N|L) computed over common cells between chosen sessions.
% Also computes within the chosen Naive session:
%   P(N_hit|L), P(N_miss|L)
%
% Returns variables:
%   Mouse, Source,
%   DateTimeNaive, DateTimeLearned,
%   NaiveHitRate,
%   NCommonCells,
%   NLearnedActive23, NLearnedActive5,
%   Prob23, Prob5,
%   ProbHit23, ProbMiss23, ProbHit5, ProbMiss5
%
% Execution:
%   TransferLearning.Fig37.iBuildProb_NaiveHitMissGivenLearnedLight_1s_PerMouseLayer

LAB = TransferLearning.LightAudioBaseline();
LAI = TransferLearning.LAInterspersed();

xsSec = seconds(TransferLearning.Xs);
baseMask = (xsSec >= -3) & (xsSec < 0);
if ~any(baseMask)
	error('Fig37:iBuildPNgivenL:BadTimeMask', 'Baseline(-3~0) has no samples.');
end
idx1 = find(xsSec == 1, 1, 'first');
if isempty(idx1)
	[dtMin, idx1] = min(abs(xsSec - 1));
	if isempty(idx1) || ~isfinite(dtMin) || dtMin > 0.25
		error('Fig37:iBuildPNgivenL:No1sSample', 'Cannot find a sample close to 1s in TransferLearning.Xs.');
	end
end

kSigma = 3;
minTrials = 1;
minCommonCells = 10;

rows = table;
[rowsA, diagA] = iOneDataSet(LAB, "LightAudioBaseline", baseMask, idx1, kSigma, minTrials, minCommonCells);
[rowsB, diagB] = iOneDataSet(LAI, "LAInterspersed",     baseMask, idx1, kSigma, minTrials, minCommonCells);
rows = [rows; rowsA; rowsB];

diag = iDiagInit();
diag = iDiagAdd(diag, diagA);
diag = iDiagAdd(diag, diagB);
diag.NRowsAfterMerge = NaN;

if isempty(rows)
	return;
end
rows.Mouse = string(rows.Mouse);
rows.Source = string(rows.Source);
rows = iRemoveDuplicateMice(rows);
rows = sortrows(rows, {'Mouse','Source'});

diag.NRowsAfterMerge = height(rows);

end

function d = iDiagInit()
	d = struct();
	d.Candidates = 0;
	d.Added = 0;
	d.Skip_NoNaivePureSession = 0;
	d.Skip_NoLearnedPureSession = 0;
	d.Skip_NoLearnedAndNoTransferAnchor = 0;
	d.Skip_NoLearnedAndNoPreTransferPureSession = 0;
	d.Skip_TooFewTrials = 0;
	d.Skip_NoCellUID = 0;
	d.Skip_NoCalciumTrace = 0;
	d.Skip_TooFewCommonCells = 0;
	d.NRowsAfterMerge = NaN;
end

function d = iDiagAdd(d, x)
	if isempty(x)
		return;
	end
	fn = fieldnames(d);
	for iF = 1:numel(fn)
		k = fn{iF};
		if isfield(x, k) && isnumeric(d.(k)) && isnumeric(x.(k))
			d.(k) = d.(k) + x.(k);
		end
	end
end

function rows = iRemoveDuplicateMice(rows)
	if isempty(rows)
		return;
	end
	m = string(rows.Mouse);
	[um, ia] = unique(m, 'stable');
	if numel(um) ~= numel(m)
		fprintf('[Fig3.7] removing duplicate mice across sources: kept %d/%d\n', numel(ia), numel(m));
		rows = rows(ia, :);
	end
end

%% --- local helpers

function [out, diag] = iOneDataSet(DS, sourceName, baseMask, idx1, kSigma, minTrials, minCommonCells)
	out = table(string.empty(0,1), string.empty(0,1), NaT(0,1), NaT(0,1), false(0,1), NaT(0,1), ...
		nan(0,1), nan(0,1), nan(0,1), nan(0,1), nan(0,1), nan(0,1), nan(0,1), nan(0,1), nan(0,1), nan(0,1), ...
		'VariableNames', {'Mouse','Source','DateTimeNaive','DateTimeLearned','UsedFallbackLearned','DateTimeTransferAnchor', ...
		'NaiveHitRate','NCommonCells','NLearnedActive23','NLearnedActive5', ...
		'Prob23','Prob5','ProbHit23','ProbMiss23','ProbHit5','ProbMiss5'});
	diag = iDiagInit();

	mice = iMiceInPhaseStimulus(DS, "Naive", "LightWater");
	mice = mice(~ismissing(mice));
	if isempty(mice)
		return;
	end
	diag.Candidates = numel(mice);

	for iM = 1:numel(mice)
		m = mice(iM);
		[Tn, dtN] = iTrialsByMousePureSession(DS, m, "Naive",   "LightWater", "first", forbiddenStimulus="AudioWater");
		[Tl, dtL] = iTrialsByMousePureSession(DS, m, "Learned", "LightWater", "last",  forbiddenStimulus="AudioWater");
		usedFallback = false;
		dtT = NaT;
		learnedMissingInitially = isempty(Tl);
		if learnedMissingInitially
			% Fallback rule: if no Learned phase, use the last LightWater pure session before Transfer
			[~, dtT] = iTrialsByMousePureSessionAnyStimulus(DS, m, "Transfer", "first");
			usedFallback = true;
			if ~ismissing(dtT)
				[Tl, dtL] = iTrialsByMousePureSessionBefore(DS, m, dtT, "LightWater", "last", forbiddenStimulus="AudioWater");
			end
		end
		if isempty(Tn)
			diag.Skip_NoNaivePureSession = diag.Skip_NoNaivePureSession + 1;
			continue;
		end
		if isempty(Tl)
			% Learned still empty after fallback attempts (or missing without fallback)
			if learnedMissingInitially
				if ismissing(dtT)
					diag.Skip_NoLearnedAndNoTransferAnchor = diag.Skip_NoLearnedAndNoTransferAnchor + 1;
				else
					diag.Skip_NoLearnedAndNoPreTransferPureSession = diag.Skip_NoLearnedAndNoPreTransferPureSession + 1;
				end
			else
				diag.Skip_NoLearnedPureSession = diag.Skip_NoLearnedPureSession + 1;
			end
			continue;
		end
		if numel(Tn) < minTrials || numel(Tl) < minTrials
			diag.Skip_TooFewTrials = diag.Skip_TooFewTrials + 1;
			continue;
		end

		cellUID = iMouseCellUID(DS, m);
		if isempty(cellUID)
			diag.Skip_NoCellUID = diag.Skip_NoCellUID + 1;
			continue;
		end

		Zn = iMedianTraceZScore(DS, cellUID, Tn);
		Zl = iMedianTraceZScore(DS, cellUID, Tl);
		if isempty(Zn) || isempty(Zl)
			diag.Skip_NoCalciumTrace = diag.Skip_NoCalciumTrace + 1;
			continue;
		end

		uidCommon = intersect(uint64(Zn.CellUID), uint64(Zl.CellUID));
		if numel(uidCommon) < minCommonCells
			diag.Skip_TooFewCommonCells = diag.Skip_TooFewCommonCells + 1;
			continue;
		end

		ZnC = sortrows(Zn(ismember(uint64(Zn.CellUID), uidCommon), :), 'CellUID');
		ZlC = sortrows(Zl(ismember(uint64(Zl.CellUID), uidCommon), :), 'CellUID');
		uidCommon = uint64(ZnC.CellUID);

		actN = iIsActive(ZnC.Trace, baseMask, idx1, kSigma);
		actL = iIsActive(ZlC.Trace, baseMask, idx1, kSigma);

		zl = iCellZLayer(DS, uidCommon);
		m23 = (zl == "MOp2/3");
		m5  = (zl == "MOp5");

		[nL23, p23] = iProbAlsoActive(actN, actL, m23);
		[nL5,  p5]  = iProbAlsoActive(actN, actL, m5);

		perfN = iHitRateFromTrialUID(DS, Tn);

		[Nh, Nm] = iSplitHitMissWithinTrialUID(DS, Tn, "LightWater");
		probHit23 = NaN; probMiss23 = NaN; probHit5 = NaN; probMiss5 = NaN;
		if ~isempty(Nh)
			Zh = iMedianTraceZScore(DS, uidCommon, Nh);
			if ~isempty(Zh)
				Zh = sortrows(Zh, 'CellUID');
				actH = iIsActive(Zh.Trace, baseMask, idx1, kSigma);
				[~, probHit23] = iProbAlsoActive(actH, actL, m23);
				[~, probHit5]  = iProbAlsoActive(actH, actL, m5);
			end
		end
		if ~isempty(Nm)
			Zm = iMedianTraceZScore(DS, uidCommon, Nm);
			if ~isempty(Zm)
				Zm = sortrows(Zm, 'CellUID');
				actM = iIsActive(Zm.Trace, baseMask, idx1, kSigma);
				[~, probMiss23] = iProbAlsoActive(actM, actL, m23);
				[~, probMiss5]  = iProbAlsoActive(actM, actL, m5);
			end
		end

		% NOTE: if fallback-learned session has no calcium, iMedianTraceZScore returns empty and we skip this mouse.

		out = [out; table(m, string(sourceName), dtN, dtL, usedFallback, dtT, perfN, numel(uidCommon), nL23, nL5, p23, p5, ...
			probHit23, probMiss23, probHit5, probMiss5, 'VariableNames', out.Properties.VariableNames)]; %#ok<AGROW>
		diag.Added = diag.Added + 1;
	end
end

function [trialUID, dt] = iTrialsByMousePureSessionBefore(DS, mouseName, dtUpper, stimulusName, whichOne, opts)
	arguments
		DS
		mouseName
		dtUpper
		stimulusName
		whichOne
		opts.forbiddenStimulus string = string([])
	end
	trialUID = uint64([]);
	dt = NaT;
	forbidden = string(opts.forbiddenStimulus);
	try
		T = iTableQueryOrEmpty(DS, ["TrialUID","Mouse","DateTime","Stimulus"], Mouse=mouseName);
		if isempty(T)
			return;
		end
		T.Mouse = string(T.Mouse);
		T.Stimulus = string(T.Stimulus);
		T = iNormalizeDateTime(T);
		T = T(~ismissing(T.DateTime) & (T.DateTime < dtUpper), :);
		if isempty(T)
			return;
		end
		T = sortrows(T, 'DateTime');
		allDT = unique(T.DateTime, 'stable');
		if isempty(allDT)
			return;
		end
		if strcmpi(whichOne, 'last')
			allDT = flipud(allDT);
		end
		for iD = 1:numel(allDT)
			dtTry = allDT(iD);
			Ti = T(T.DateTime==dtTry, :);
			stims = unique(string(Ti.Stimulus));
			stims = stims(~ismissing(stims));
			if isempty(stims)
				continue;
			end
			if ~any(stims == string(stimulusName))
				continue;
			end
			if ~isempty(forbidden)
				stimsAll = iStimuliAtDateTimeAllPhases(DS, mouseName, dtTry);
				if any(stimsAll == forbidden)
					continue;
				end
			end
			Tu = unique(uint64(Ti.TrialUID(string(Ti.Stimulus)==string(stimulusName))));
			if isempty(Tu)
				continue;
			end
			dt = dtTry;
			trialUID = Tu;
			return;
		end
	catch
		trialUID = uint64([]);
		dt = NaT;
	end
end

function [nDen, prob] = iProbAlsoActive(actNum, actDen, layerMask)
	try
		use = logical(layerMask(:)) & isfinite(actNum(:)) & isfinite(actDen(:));
		if ~any(use)
			nDen = 0;
			prob = NaN;
			return;
		end
		aNum = logical(actNum(use));
		aDen = logical(actDen(use));
		nDen = nnz(aDen);
		if nDen == 0
			prob = NaN;
			return;
		end
		prob = nnz(aNum & aDen) / nDen;
	catch
		nDen = NaN;
		prob = NaN;
	end
end

function a = iIsActive(trace, baseMask, idx1, kSigma)
	if isempty(trace)
		a = false(0,1);
		return;
	end
	mu = mean(trace(:, baseMask), 2, 'omitnan');
	sd = std(trace(:, baseMask), 0, 2, 'omitnan');
	thr = mu + kSigma .* sd;
	a = trace(:, idx1) > thr;
end

function mice = iMiceInPhaseStimulus(DS, phaseName, stimulusName)
	mice = string([]);
	try
		T = DS.TableQuery(["Mouse"], Phase=phaseName, Stimulus=stimulusName);
		if isempty(T)
			return;
		end
		mice = unique(string(T.Mouse));
		mice = mice(~ismissing(mice));
	catch
		mice = string([]);
	end
end

function [trialUID, dt] = iTrialsByMousePureSession(DS, mouseName, phaseName, stimulusName, whichOne, opts)
	arguments
		DS
		mouseName
		phaseName
		stimulusName
		whichOne
		opts.forbiddenStimulus string = string([])
	end
	trialUID = uint64([]);
	dt = NaT;
	forbidden = string(opts.forbiddenStimulus);
	try
		T = iTableQueryOrEmpty(DS, ["TrialUID","Mouse","DateTime","Phase","Stimulus"], Mouse=mouseName, Phase=phaseName);
		if isempty(T)
			return;
		end
		T.Mouse = string(T.Mouse);
		T.Phase = string(T.Phase);
		T.Stimulus = string(T.Stimulus);
		T = iNormalizeDateTime(T);
		T = T(~ismissing(T.DateTime), :);
		if isempty(T)
			return;
		end
		T = sortrows(T, 'DateTime');
		allDT = unique(T.DateTime, 'stable');
		if isempty(allDT)
			return;
		end
		if strcmpi(whichOne, 'last')
			allDT = flipud(allDT);
		end
		for iD = 1:numel(allDT)
			dtTry = allDT(iD);
			Ti = T(T.DateTime==dtTry, :);
			stims = unique(string(Ti.Stimulus));
			stims = stims(~ismissing(stims));
			if isempty(stims)
				continue;
			end
			if ~any(stims == string(stimulusName))
				continue;
			end
			if ~isempty(forbidden)
				stimsAll = iStimuliAtDateTimeAllPhases(DS, mouseName, dtTry);
				if any(stimsAll == forbidden)
					continue;
				end
			end
			Tu = unique(uint64(Ti.TrialUID(string(Ti.Stimulus)==string(stimulusName))));
			if isempty(Tu)
				continue;
			end
			dt = dtTry;
			trialUID = Tu;
			return;
		end
	catch
		trialUID = uint64([]);
		dt = NaT;
	end
end

function [trialUID, dt] = iTrialsByMousePureSessionAnyStimulus(DS, mouseName, phaseName, whichOne, opts)
	arguments
		DS
		mouseName
		phaseName
		whichOne
		opts.forbiddenStimulus string = string([])
	end
	trialUID = uint64([]);
	dt = NaT;
	forbidden = string(opts.forbiddenStimulus);
	try
		T = iTableQueryOrEmpty(DS, ["TrialUID","Mouse","DateTime","Phase","Stimulus"], Mouse=mouseName, Phase=phaseName);
		if isempty(T)
			return;
		end
		T.Mouse = string(T.Mouse);
		T.Phase = string(T.Phase);
		T.Stimulus = string(T.Stimulus);
		T = iNormalizeDateTime(T);
		T = T(~ismissing(T.DateTime), :);
		if isempty(T)
			return;
		end
		T = sortrows(T, 'DateTime');
		allDT = unique(T.DateTime, 'stable');
		if isempty(allDT)
			return;
		end
		if strcmpi(whichOne, 'last')
			allDT = flipud(allDT);
		end
		for iD = 1:numel(allDT)
			dtTry = allDT(iD);
			Ti = T(T.DateTime==dtTry, :);
			stims = unique(string(Ti.Stimulus));
			stims = stims(~ismissing(stims));
			if isempty(stims)
				continue;
			end
			if ~isempty(forbidden)
				stimsAll = iStimuliAtDateTimeAllPhases(DS, mouseName, dtTry);
				if any(stimsAll == forbidden)
					continue;
				end
			end
			Tu = unique(uint64(Ti.TrialUID));
			Tu = Tu(isfinite(double(Tu)));
			if isempty(Tu)
				continue;
			end
			dt = dtTry;
			trialUID = Tu;
			return;
		end
	catch
		trialUID = uint64([]);
		dt = NaT;
	end
end

function stims = iStimuliAtDateTimeAllPhases(DS, mouseName, dt)
	stims = string([]);
	try
		T = DS.TableQuery(["Stimulus"], Mouse=mouseName, DateTime=dt);
	catch
		T = [];
	end
	if isempty(T) || ~ismember('Stimulus', T.Properties.VariableNames)
		return;
	end
	try
		stims = unique(string(T.Stimulus));
		stims = stims(~ismissing(stims));
	catch
		stims = string([]);
	end
end

function T = iTableQueryOrEmpty(DS, vars, varargin)
	try
		T = DS.TableQuery(vars, varargin{:});
	catch
		T = [];
	end
	if isempty(T)
		return;
	end
	T = iNormalizeDateTime(T);
end

function T = iNormalizeDateTime(T)
	if isempty(T) || ~ismember('DateTime', T.Properties.VariableNames)
		return;
	end
	try
		T.DateTime = datetime(T.DateTime);
		T.DateTime.TimeZone = '';
	catch
	end
end

function Z = iMedianTraceZScore(DS, cellUID, trialUID)
	Z = [];
	if isempty(cellUID) || isempty(trialUID)
		return;
	end
	try
		q = struct('CellUID', uint64(cellUID), 'TrialUID', uint64(trialUID));
		G = DS.QueryNTATS(q, UniExp.Flags.ZScore, 1:24, UniExp.Flags.Median);
	catch
		G = [];
	end
	if isempty(G) || ~all(ismember({'CellUID','NTATS'}, G.Properties.VariableNames))
		return;
	end
	X = iNtatsData(G.NTATS);
	if isempty(X)
		return;
	end
	Z = table(uint64(G.CellUID), X, 'VariableNames', {'CellUID','Trace'});
end

function X = iNtatsData(NT)
	if isa(NT, 'MATLAB.DataTypes.NDTable')
		X = NT.Data;
	else
		X = NT;
	end
	X = squeeze(X);
end

function cellUID = iMouseCellUID(DS, mouseName)
	cellUID = uint64([]);
	try
		C = DS.Cells;
		if isempty(C) || ~all(ismember({'Mouse','CellUID'}, C.Properties.VariableNames))
			return;
		end
		m = string(mouseName);
		C.Mouse = string(C.Mouse);
		cellUID = unique(uint64(C.CellUID(C.Mouse == m)));
	catch
		cellUID = uint64([]);
	end
end

function zl = iCellZLayer(DS, cellUID)
	zl = strings(numel(cellUID),1);
	try
		C = DS.Cells;
		if isempty(C) || ~all(ismember({'CellUID','ZLayer'}, C.Properties.VariableNames))
			return;
		end
		uid = uint64(cellUID(:));
		Cu = C;
		Cu.CellUID = uint64(Cu.CellUID);
		[tf, loc] = ismember(uid, Cu.CellUID);
		zl(tf) = string(Cu.ZLayer(loc(tf)));
	catch
		zl = strings(numel(cellUID),1);
	end
end

function hit = iHitRateFromTrialUID(DS, trialUID)
	hit = NaN;
	trialUID = uint64(trialUID(:));
	if isempty(trialUID) || ~isprop(DS, 'Trials')
		return;
	end
	Tr = DS.Trials;
	need = {'TrialUID','Stimulus','Behavior'};
	if isempty(Tr) || ~all(ismember(need, Tr.Properties.VariableNames))
		return;
	end
	try
		Tr.TrialUID = uint64(Tr.TrialUID);
		Tr.Stimulus = string(Tr.Stimulus);
	catch
	end
	mask = ismember(uint64(Tr.TrialUID), trialUID) & (string(Tr.Stimulus) == "LightWater");
	if ~any(mask)
		return;
	end
	b = double(Tr.Behavior(mask));
	hit = mean(b(isfinite(b)), 'omitnan');
end

function [Thit, Tmiss] = iSplitHitMissWithinTrialUID(DS, trialUID, stimulusName)
	Thit = uint64([]);
	Tmiss = uint64([]);
	trialUID = uint64(trialUID(:));
	if isempty(trialUID) || ~isprop(DS, 'Trials')
		return;
	end
	Tr = DS.Trials;
	need = {'TrialUID','Stimulus','Behavior'};
	if isempty(Tr) || ~all(ismember(need, Tr.Properties.VariableNames))
		return;
	end
	try
		Tr.TrialUID = uint64(Tr.TrialUID);
		Tr.Stimulus = string(Tr.Stimulus);
	catch
		return;
	end
	mask = ismember(uint64(Tr.TrialUID), trialUID) & (Tr.Stimulus == string(stimulusName));
	if ~any(mask)
		return;
	end
	b = double(Tr.Behavior(mask));
	uid = uint64(Tr.TrialUID(mask));
	Thit = unique(uid(isfinite(b) & (b > 0.5)));
	Tmiss = unique(uid(isfinite(b) & (b <= 0.5)));
end
