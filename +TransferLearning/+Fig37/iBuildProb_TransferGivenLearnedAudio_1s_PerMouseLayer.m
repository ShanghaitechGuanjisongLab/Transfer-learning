function rows = iBuildProb_TransferGivenLearnedAudio_1s_PerMouseLayer(varargin)
% Build per-mouse table for Fig3.7 panels involving P(T|L).
%
% Definitions (per mouse, per layer):
%   L = Learned AudioWater (last pure session; forbidden stimulus=LightWater)
%   T = Transfer LightWater (first pure session; forbidden stimulus=AudioWater)
%
% Active definition (1 s):
%   Median NTATS ZScore at t≈1s > mean(-3~0s) + 3*std(-3~0s)
% computed from DS.QueryNTATS(..., ZScore, 1:24, Median).
%
% P(T|L) is computed over common cells between the two chosen sessions.
% Also computes session-specific Hit/Miss variants for Transfer:
%   P(T_hit|L), P(T_miss|L)
% where T_hit/T_miss activity is computed within the chosen Transfer session.
%
% Returns variables:
%   Mouse, Source,
%   DateTimeLearned, DateTimeTransfer,
%   TransferHitRate,
%   NCommonCells,
%   NLearnedActive23, NLearnedActive5,
%   Prob23, Prob5,
%   ProbHit23, ProbMiss23, ProbHit5, ProbMiss5
%
% Execution:
%   TransferLearning.Fig37.iBuildProb_TransferGivenLearnedAudio_1s_PerMouseLayer
%
% Optional:
%   rows = TransferLearning.Fig37.iBuildProb_TransferGivenLearnedAudio_1s_PerMouseLayer('DataSet', DS, 'Source', "MySource")

ip = inputParser;
ip.FunctionName = 'TransferLearning.Fig37.iBuildProb_TransferGivenLearnedAudio_1s_PerMouseLayer';
addParameter(ip, 'DataSet', [], @(x) true);
addParameter(ip, 'Source', "AudioLightBaseline", @(s) isstring(s) || ischar(s));
parse(ip, varargin{:});

DS = ip.Results.DataSet;
sourceName = string(ip.Results.Source);
if isempty(DS)
	DS = TransferLearning.AudioLightBaseline();
	if strlength(sourceName) == 0
		sourceName = "AudioLightBaseline";
	end
end

xsSec = seconds(TransferLearning.Xs);
baseMask = (xsSec >= -3) & (xsSec < 0);
if ~any(baseMask)
	error('Fig37:iBuildPTgivenL:BadTimeMask', 'Baseline(-3~0) has no samples.');
end
idx1 = find(xsSec == 1, 1, 'first');
if isempty(idx1)
	[dtMin, idx1] = min(abs(xsSec - 1));
	if isempty(idx1) || ~isfinite(dtMin) || dtMin > 0.25
		error('Fig37:iBuildPTgivenL:No1sSample', 'Cannot find a sample close to 1s in TransferLearning.Xs.');
	end
end

kSigma = 3;
minTrials = 1;
minCommonCells = 10;

rows = iOneDataSet(DS, sourceName, baseMask, idx1, kSigma, minTrials, minCommonCells);
if isempty(rows)
	return;
end
rows.Mouse = string(rows.Mouse);
rows.Source = string(rows.Source);
rows = sortrows(rows, {'Mouse','Source'});

end

%% --- local helpers

function out = iOneDataSet(DS, sourceName, baseMask, idx1, kSigma, minTrials, minCommonCells)
	out = table(string.empty(0,1), string.empty(0,1), NaT(0,1), NaT(0,1), ...
		nan(0,1), nan(0,1), nan(0,1), nan(0,1), nan(0,1), nan(0,1), nan(0,1), nan(0,1), nan(0,1), nan(0,1), ...
		'VariableNames', {'Mouse','Source','DateTimeLearned','DateTimeTransfer', ...
		'TransferHitRate','NCommonCells','NLearnedActive23','NLearnedActive5', ...
		'Prob23','Prob5','ProbHit23','ProbMiss23','ProbHit5','ProbMiss5'});

	miceL = iMiceInPhaseStimulus(DS, "Learned", "AudioWater");
	miceT = iMiceInPhaseStimulus(DS, "Transfer", "LightWater");
	mice = intersect(miceL, miceT);
	mice = mice(~ismissing(mice));
	if isempty(mice)
		return;
	end

	for iM = 1:numel(mice)
		m = mice(iM);
		[Tl, dtL] = iTrialsByMousePureSession(DS, m, "Learned",  "AudioWater",  "last", forbiddenStimulus="LightWater");
		[Tt, dtT] = iTrialsByMousePureSession(DS, m, "Transfer", "LightWater",  "first", forbiddenStimulus="AudioWater");
		if isempty(Tl) || isempty(Tt) || numel(Tl) < minTrials || numel(Tt) < minTrials
			continue;
		end

		cellUID = iMouseCellUID(DS, m);
		if isempty(cellUID)
			continue;
		end

		Zl = iMedianTraceZScore(DS, cellUID, Tl);
		Zt = iMedianTraceZScore(DS, cellUID, Tt);
		if isempty(Zl) || isempty(Zt)
			continue;
		end

		uidCommon = intersect(uint64(Zl.CellUID), uint64(Zt.CellUID));
		if numel(uidCommon) < minCommonCells
			continue;
		end

		ZlC = sortrows(Zl(ismember(uint64(Zl.CellUID), uidCommon), :), 'CellUID');
		ZtC = sortrows(Zt(ismember(uint64(Zt.CellUID), uidCommon), :), 'CellUID');
		uidCommon = uint64(ZlC.CellUID);

		actL = iIsActive(ZlC.Trace, baseMask, idx1, kSigma);
		actT = iIsActive(ZtC.Trace, baseMask, idx1, kSigma);

		zl = iCellZLayer(DS, uidCommon);
		m23 = (zl == "MOp2/3");
		m5  = (zl == "MOp5");

		[nL23, p23] = iProbAlsoActive(actT, actL, m23);
		[nL5,  p5]  = iProbAlsoActive(actT, actL, m5);

		% Transfer hit rate (within chosen Transfer session)
		perfT = iHitRateFromTrialUID(DS, Tt);

		% Hit/Miss within Transfer session (split within chosen session trialUID)
		[Thit, Tmiss] = iSplitHitMissWithinTrialUID(DS, Tt, "LightWater");
		probHit23 = NaN; probMiss23 = NaN; probHit5 = NaN; probMiss5 = NaN;
		if ~isempty(Thit)
			Zh = iMedianTraceZScore(DS, uidCommon, Thit);
			if ~isempty(Zh)
				Zh = sortrows(Zh, 'CellUID');
				actH = iIsActive(Zh.Trace, baseMask, idx1, kSigma);
				[~, probHit23] = iProbAlsoActive(actH, actL, m23);
				[~, probHit5]  = iProbAlsoActive(actH, actL, m5);
			end
		end
		if ~isempty(Tmiss)
			Zm = iMedianTraceZScore(DS, uidCommon, Tmiss);
			if ~isempty(Zm)
				Zm = sortrows(Zm, 'CellUID');
				actM = iIsActive(Zm.Trace, baseMask, idx1, kSigma);
				[~, probMiss23] = iProbAlsoActive(actM, actL, m23);
				[~, probMiss5]  = iProbAlsoActive(actM, actL, m5);
			end
		end

		out = [out; table(m, string(sourceName), dtL, dtT, perfT, numel(uidCommon), nL23, nL5, p23, p5, ...
			probHit23, probMiss23, probHit5, probMiss5, 'VariableNames', out.Properties.VariableNames)]; %#ok<AGROW>
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
