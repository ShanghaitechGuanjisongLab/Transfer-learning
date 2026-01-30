function rows = iBuildRelDiv_TransferGivenLearnedAudio_1s_PerMouseLayer()
% Build per-mouse table for Fig3.8 panels using Transfer relative divergence.
%
% NOTE (naming legacy): earlier drafts used a "|L" suffix to indicate the
% cell-set restriction (cells selected using a Learned session). That made
% sense for probability-like quantities but can be confusing for divergence.
%
% Current definition (per mouse, per layer):
%   RelDiv(T): relative divergence of per-trial ZScore at ~1s in the Transfer
%   LightWater session (first pure session; forbid AudioWater), computed using
%   Transfer data alone.
%
% Layer split uses DS.Cells.ZLayer for the cells included in the matrix.
%
% Relative divergence algorithm:
%   1) QueryNTS -> per-trial DeltaF
%   2) For each cell, var across trials at 1s
%   3) mean over cells, sqrt -> absolute divergence
%   4) trials as points in cell-space at 1s, centroid = mean(point)
%   5) relative divergence = absDiv / norm(centroid)
%
% Returns variables (schema kept compatible with plotting scripts):
%   Mouse, Source,
%   DateTimeTransfer, DateTimeLearned (NaT placeholder),
%   TransferHitRate,
%   NDenActive23, NDenActive5 (here = number of included cells per layer),
%   RelDiv23, RelDiv5,
%   RelDivHit23, RelDivMiss23, RelDivHit5, RelDivMiss5
%
% Execution:
%   TransferLearning.Fig38.iBuildRelDiv_TransferGivenLearnedAudio_1s_PerMouseLayer

ALB = TransferLearning.AudioLightBaseline();

xsSec = seconds(TransferLearning.Xs);
idx1_ref = find(xsSec == 1, 1, 'first');
if isempty(idx1_ref)
	[dtMin, idx1_ref] = min(abs(xsSec - 1));
	if isempty(idx1_ref) || ~isfinite(dtMin) || dtMin > 0.25
		error('Fig38:RelDiv:No1sSample', 'Cannot find a sample close to 1s in TransferLearning.Xs.');
	end
end
nT_ref = numel(xsSec);
minTrials = 2;
minDenCells = 5;

rows = table;
rows = [rows; iOneDataSet(ALB, "AudioLightBaseline", idx1_ref, nT_ref, minTrials, minDenCells)];

if isempty(rows)
	return;
end
rows.Mouse = string(rows.Mouse);
rows.Source = string(rows.Source);
rows = sortrows(rows, {'Mouse','Source'});

end

%% --- locals

function out = iOneDataSet(DS, sourceName, idx1_ref, nT_ref, minTrials, minDenCells)
	out = table(string.empty(0,1), string.empty(0,1), NaT(0,1), NaT(0,1), ...
		nan(0,1), nan(0,1), nan(0,1), nan(0,1), nan(0,1), nan(0,1), nan(0,1), nan(0,1), nan(0,1), ...
		'VariableNames', {'Mouse','Source','DateTimeTransfer','DateTimeLearned', ...
		'TransferHitRate','NDenActive23','NDenActive5', ...
		'RelDiv23','RelDiv5','RelDivHit23','RelDivMiss23','RelDivHit5','RelDivMiss5'});

	mice = iMiceInPhaseStimulus(DS, "Transfer", "LightWater");
	mice = mice(~ismissing(mice));
	if isempty(mice)
		return;
	end

	for iM = 1:numel(mice)
		m = mice(iM);

		[Tt, dtT] = iTrialsByMousePureSession(DS, m, "Transfer", "LightWater", "first", forbiddenStimulus="AudioWater");
		if numel(Tt) < minTrials
			continue;
		end

		cellUID = iMouseCellUID(DS, m);
		if isempty(cellUID)
			continue;
		end

		% --- build trial-by-trial 1s matrix from Transfer session only
		[Zall, cellU, ~] = iTrialZ1Matrix(DS, m, "LightWater", Tt, uint64(cellUID), idx1_ref, nT_ref);
		if isempty(Zall) || isempty(cellU)
			continue;
		end
		zl = iCellZLayer(DS, uint64(cellU));
		m23 = (zl == "MOp2/3");
		m5  = (zl == "MOp5");
		nDen23 = nnz(m23);
		nDen5  = nnz(m5);
		if nDen23 < minDenCells && nDen5 < minDenCells
			continue;
		end

		perfT = iHitRateFromTrialUID(DS, Tt);

		[Th, Tm] = iSplitHitMissWithinTrialUID(DS, Tt, "LightWater");
		[div23, div5] = iRelDivByLayer(Zall, cellU, m23, m5);

		% --- hit/miss
		divH23 = NaN; divM23 = NaN; divH5 = NaN; divM5 = NaN;
		if ~isempty(Th)
			[Zh, cellU2] = iTrialZ1Matrix(DS, m, "LightWater", Th, uint64(cellU), idx1_ref, nT_ref);
			[divH23, divH5] = iRelDivByLayer(Zh, cellU2, m23, m5);
		end
		if ~isempty(Tm)
			[Zm, cellU3] = iTrialZ1Matrix(DS, m, "LightWater", Tm, uint64(cellU), idx1_ref, nT_ref);
			[divM23, divM5] = iRelDivByLayer(Zm, cellU3, m23, m5);
		end

		out = [out; table(m, string(sourceName), dtT, NaT, perfT, nDen23, nDen5, div23, div5, divH23, divM23, divH5, divM5, ...
			'VariableNames', out.Properties.VariableNames)]; %#ok<AGROW>
	end
end

function [div23, div5] = iRelDivByLayer(Z, cellUID, mask23, mask5)
	div23 = NaN; div5 = NaN;
	if isempty(Z)
		return;
	end
	cellUID = uint64(cellUID(:));
	mask23 = logical(mask23(:));
	mask5  = logical(mask5(:));
	if numel(mask23) ~= numel(cellUID) || numel(mask5) ~= numel(cellUID)
		return;
	end
	Z23 = Z(mask23, :);
	Z5  = Z(mask5,  :);
	div23 = iRelDivFromMatrix(Z23);
	div5  = iRelDivFromMatrix(Z5);
end

function div = iRelDivFromMatrix(Z)
	div = NaN;
	if isempty(Z)
		return;
	end
	Z = double(Z);
	Z = Z(:, any(isfinite(Z), 1));
	if size(Z,1) < 2 || size(Z,2) < 2
		return;
	end
	cellVar = var(Z, 0, 2, 'omitnan');
	nPerCell = sum(isfinite(Z), 2);
	cellVar(nPerCell < 2) = NaN;
	absDiv = sqrt(mean(cellVar, 'omitnan'));
	centroid = mean(Z, 2, 'omitnan');
	centroid = centroid(isfinite(centroid));
	d0 = norm(centroid, 2);
	if ~isfinite(absDiv) || ~isfinite(d0) || d0 <= 0
		div = NaN;
	else
		div = absDiv / d0;
	end
end

function [Z, cellU, trialU] = iTrialZ1Matrix(DS, mouseName, stimulusName, trialUID, cellUIDKeep, idx1_ref, nT_ref)
	Z = [];
	cellU = uint64([]);
	trialU = uint64([]);
	trialUID = uint64(trialUID(:));
	cellUIDKeep = uint64(cellUIDKeep(:));
	if isempty(trialUID) || isempty(cellUIDKeep)
		return;
	end
	try
		ntsCell = DS.QueryNTS(struct('Stimulus', string(stimulusName), 'Mouse', string(mouseName)), UniExp.Flags.DeltaF, 1:24);
		nts = ntsCell{1};
	catch
		nts = [];
	end
	if isempty(nts)
		return;
	end
	try
		inTrial = ismember(uint64(nts.TrialUID), trialUID);
		inCell  = ismember(uint64(nts.CellUID), cellUIDKeep);
		nts = nts(inTrial & inCell, :);
	catch
		return;
	end
	if isempty(nts)
		return;
	end

	try
		nT = size(nts.TrialSignal, 2);
		if nT == nT_ref
			idx1 = idx1_ref;
			xsRef = TransferLearning.Xs;
			if isa(xsRef, 'duration')
				xsSec = seconds(xsRef);
			else
				xsSec = xsRef;
			end
			baseIdx = (xsSec >= -3) & (xsSec < 0);
		else
			xs2 = linspace(-3, 3, nT);
			[~, idx1] = min(abs(xs2 - 1));
			baseIdx = (xs2 >= -3) & (xs2 < 0);
		end
		if ~any(baseIdx)
			return;
		end
		v1 = nts.TrialSignal(:, idx1);
		baseVals = nts.TrialSignal(:, baseIdx);
	catch
		return;
	end

	cellU = unique(uint64(nts.CellUID));
	trialU = unique(uint64(nts.TrialUID));
	[~, cellIdx] = ismember(uint64(nts.CellUID), cellU);
	[~, trialIdx] = ismember(uint64(nts.TrialUID), trialU);

	% per-cell global baseline std across all trials (-3~0) for this mouse/session
	sdCell = nan(numel(cellU), 1);
	try
		uidRows = uint64(nts.CellUID);
		for iC = 1:numel(cellU)
			rowsC = (uidRows == cellU(iC));
			if ~any(rowsC)
				continue;
			end
			v = baseVals(rowsC, :);
			s = std(v, 0, 'all', 'omitnan');
			if isfinite(s) && s > 0
				sdCell(iC) = s;
			end
		end
	catch
		sdCell = nan(numel(cellU), 1);
	end
	if ~any(isfinite(sdCell))
		return;
	end
	Z = nan(numel(cellU), numel(trialU));
	lin = sub2ind(size(Z), cellIdx, trialIdx);
	Z = iAccumMean(Z, lin, v1);

	% normalize by per-cell global baseline std
	Z = Z ./ sdCell;

	% keep cells with at least 2 finite trials and finite sd
	goodCell = (sum(isfinite(Z), 2) >= 2) & isfinite(sdCell);
	Z = Z(goodCell, :);
	cellU = cellU(goodCell);
end

function Z = iAccumMean(Z, linIdx, values)
	[linU, ~, g] = unique(linIdx);
	mu = splitapply(@(x) mean(x, 'omitnan'), values, g);
	Z(linU) = mu;
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
