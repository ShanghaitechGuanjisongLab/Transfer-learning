function [pairs, dbg] = iBuildAdjPairs_DeltaHit_vs_TrainSignalMatchMetrics_ByLayer(varargin)
% Build adjacent-session-pair table (split by layer) for training-signal matching.
%
% Definitions:
% - Correct training signal:
%     Initial learning: Phase=Learned, Stimulus=LightWater, NTATS@TargetAtSec (default 1.5s)
%     Transfer learning: Phase=Final,  Stimulus=LightWater, NTATS@TargetAtSec (default 1.5s)
% - Actual training signal for an adjacent session pair (A,B):
%     (default) Avg NTATS trace across the 2 sessions, then take @TargetAtSec.
%     Alternatively can use only the previous session A's NTATS (@TargetAtSec).
% - Active cell (for overlap/Jaccard):
%     NTATS ZScore median @TargetAtSec > mean(-3~0s) + kSigma*std(-3~0s)
%
% Returns table variables:
%   Mouse, Source, Stage, ZKey, DateTime1, DateTime2, Hit1, Hit2, DeltaHit,
%   NCellsCommon, SignalCorr, SignalMSE, ActiveOverlapFrac, ActiveJaccard,
%   NActiveCorrect, NActiveActual, NTrials1, NTrials2
%
% Execution:
%   pairs = TransferLearning.Fig37.iBuildAdjPairs_DeltaHit_vs_TrainSignalMatchMetrics_ByLayer

ip = inputParser;
ip.FunctionName = 'TransferLearning.Fig37.iBuildAdjPairs_DeltaHit_vs_TrainSignalMatchMetrics_ByLayer';
addParameter(ip, 'TargetAtSec', 1.5, @(x) isempty(x) || (isnumeric(x) && isscalar(x)));
addParameter(ip, 'ActualSignalMode', "MeanAB", @(s) isstring(s) || ischar(s));
addParameter(ip, 'ExcludeZeroHit', false, @(x) (islogical(x) && isscalar(x)) || (isnumeric(x) && isscalar(x)));
addParameter(ip, 'SubtractAtSec', NaN, @(x) isempty(x) || (isnumeric(x) && isscalar(x)));
parse(ip, varargin{:});

targetAtSec = double(ip.Results.TargetAtSec);
actualSignalMode = string(ip.Results.ActualSignalMode);
excludeZeroHit = logical(ip.Results.ExcludeZeroHit);
subtractAtSec = double(ip.Results.SubtractAtSec);
if actualSignalMode == "Mean"
	actualSignalMode = "MeanAB";
end
if actualSignalMode == "Prev" || actualSignalMode == "PrevSession"
	actualSignalMode = "PrevA";
end
okModes = ["MeanAB","PrevA"];
if ~any(actualSignalMode == okModes)
	error('Fig37:TrainSigMatch:BadActualSignalMode', 'ActualSignalMode must be one of: %s', strjoin(okModes, ', '));
end

pairs = table(string.empty(0,1), string.empty(0,1), string.empty(0,1), string.empty(0,1), NaT(0,1), NaT(0,1), ...
	nan(0,1), nan(0,1), nan(0,1), nan(0,1), nan(0,1), nan(0,1), nan(0,1), nan(0,1), ...
	nan(0,1), nan(0,1), nan(0,1), nan(0,1), ...
	'VariableNames', {'Mouse','Source','Stage','ZKey','DateTime1','DateTime2','Hit1','Hit2','DeltaHit', ...
	'NCellsCommon','SignalCorr','SignalMSE','ActiveOverlapFrac','ActiveJaccard', ...
	'NActiveCorrect','NActiveActual','NTrials1','NTrials2'});

dbg = struct();
dbg.Sessions = table(string.empty(0,1), string.empty(0,1), string.empty(0,1), NaT(0,1), string.empty(0,1), ...
	nan(0,1), nan(0,1), false(0,1), false(0,1), false(0,1), string.empty(0,1), ...
	'VariableNames', {'Source','Stage','Mouse','DateTime','Phase','Hit','NTrials','HasAudioWater','Excluded','Included','ExclReason'});
dbg.CorrectSession = table(string.empty(0,1), string.empty(0,1), string.empty(0,1), NaT(0,1), string.empty(0,1), ...
	nan(0,1), nan(0,1), false(0,1), ...
	'VariableNames', {'Source','Stage','Mouse','DateTime','Phase','Hit','NTrials','HasAudioWater'});

xsSec = seconds(TransferLearning.Xs);
baseMask = (xsSec >= -3) & (xsSec < 0);
if ~any(baseMask)
	error('Fig37:TrainSigMatch:BadTimeMask', 'Baseline(-3~0) has no samples.');
end
[dtMin, idxT] = min(abs(xsSec - targetAtSec));
if isempty(idxT) || ~isfinite(dtMin) || dtMin > 0.25
	error('Fig37:TrainSigMatch:NoTargetSample', 'Cannot find a sample close to %.3gs in TransferLearning.Xs.', targetAtSec);
end

idxRef = [];
if ~isempty(subtractAtSec) && isfinite(subtractAtSec)
	[dtMinRef, idxRef] = min(abs(xsSec - subtractAtSec));
	if isempty(idxRef) || ~isfinite(dtMinRef) || dtMinRef > 0.25
		error('Fig37:TrainSigMatch:NoRefSample', 'Cannot find a sample close to %.3gs in TransferLearning.Xs.', subtractAtSec);
	end
end

kSigma = 3;
minCommonCells = 5;

spec = [ ...
	struct('Stage',"Initial", 'StartPhase',"Naive",   'EndPhase',"Learned", 'CorrectPhase',"Learned", 'DataSet',@() TransferLearning.LightAudioBaseline(),  'Source',"LightAudioBaseline"), ...
	struct('Stage',"Initial", 'StartPhase',"Naive",   'EndPhase',"Learned", 'CorrectPhase',"Learned", 'DataSet',@() TransferLearning.LAInterspersed(),     'Source',"LAInterspersed"), ...
	struct('Stage',"Transfer",'StartPhase',"Transfer", 'EndPhase',"Final",   'CorrectPhase',"Final",   'DataSet',@() TransferLearning.AudioLightBaseline(), 'Source',"AudioLightBaseline") ...
];

for iS = 1:numel(spec)
	S = spec(iS);
	try
		DS = S.DataSet();
	catch
		continue;
	end
	if isempty(DS)
		continue;
	end
	[rows, dbgOne] = iOneDataSet(DS, string(S.Source), string(S.Stage), string(S.StartPhase), string(S.EndPhase), string(S.CorrectPhase), ...
		idxT, idxRef, baseMask, kSigma, minCommonCells, actualSignalMode, excludeZeroHit);
	if ~isempty(rows)
		pairs = [pairs; rows]; %#ok<AGROW>
	end
	if ~isempty(dbgOne)
		if isfield(dbgOne,'Sessions') && ~isempty(dbgOne.Sessions)
			dbg.Sessions = [dbg.Sessions; dbgOne.Sessions]; %#ok<AGROW>
		end
		if isfield(dbgOne,'CorrectSession') && ~isempty(dbgOne.CorrectSession)
			dbg.CorrectSession = [dbg.CorrectSession; dbgOne.CorrectSession]; %#ok<AGROW>
		end
	end
end

if ~isempty(pairs)
	pairs.Mouse = string(pairs.Mouse);
	pairs.Source = string(pairs.Source);
	pairs.Stage = string(pairs.Stage);
	pairs.ZKey = string(pairs.ZKey);
	pairs = sortrows(pairs, {'Stage','ZKey','Mouse','DateTime1'});
end

end

%% --- local helpers

function [rows, dbgOne] = iOneDataSet(DS, sourceName, stageName, startPhase, endPhase, correctPhase, idxT, idxRef, baseMask, kSigma, minCommonCells, actualSignalMode, excludeZeroHit)

rows = table(string.empty(0,1), string.empty(0,1), string.empty(0,1), string.empty(0,1), NaT(0,1), NaT(0,1), ...
	nan(0,1), nan(0,1), nan(0,1), nan(0,1), nan(0,1), nan(0,1), nan(0,1), nan(0,1), ...
	nan(0,1), nan(0,1), nan(0,1), nan(0,1), ...
	'VariableNames', {'Mouse','Source','Stage','ZKey','DateTime1','DateTime2','Hit1','Hit2','DeltaHit', ...
	'NCellsCommon','SignalCorr','SignalMSE','ActiveOverlapFrac','ActiveJaccard', ...
	'NActiveCorrect','NActiveActual','NTrials1','NTrials2'});

dbgOne = struct();
dbgOne.Sessions = table(string.empty(0,1), string.empty(0,1), string.empty(0,1), NaT(0,1), string.empty(0,1), ...
	nan(0,1), nan(0,1), false(0,1), false(0,1), false(0,1), string.empty(0,1), ...
	'VariableNames', {'Source','Stage','Mouse','DateTime','Phase','Hit','NTrials','HasAudioWater','Excluded','Included','ExclReason'});
dbgOne.CorrectSession = table(string.empty(0,1), string.empty(0,1), string.empty(0,1), NaT(0,1), string.empty(0,1), ...
	nan(0,1), nan(0,1), false(0,1), ...
	'VariableNames', {'Source','Stage','Mouse','DateTime','Phase','Hit','NTrials','HasAudioWater'});

% --- prefetch session index (include Phase)
try
	T = DS.TableQuery(["Mouse","DateTime","TrialUID","Phase"], Stimulus="LightWater");
catch
	T = [];
end
if isempty(T)
	return;
end
try
	T.Mouse = string(T.Mouse);
	T.DateTime = datetime(T.DateTime);
	T.DateTime.TimeZone = '';
	if ismember('Phase', T.Properties.VariableNames)
		T.Phase = string(T.Phase);
	end
catch
end

T = sortrows(T, {'Mouse','DateTime'});

% behavior table
if ~isprop(DS, 'Trials')
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

% cells table
if ~isprop(DS, 'Cells')
	return;
end
C = DS.Cells;
needC = {'Mouse','CellUID','ZLayer'};
if isempty(C) || ~all(ismember(needC, C.Properties.VariableNames))
	return;
end
try
	C.Mouse = string(C.Mouse);
	C.CellUID = uint64(C.CellUID);
	C.ZLayer = string(C.ZLayer);
catch
end

mice = unique(T.Mouse);
mice = mice(~ismissing(mice));

for iM = 1:numel(mice)
	m = mice(iM);
	Ti = T(T.Mouse == m, :);
	if isempty(Ti)
		continue;
	end

	cellAll = unique(C.CellUID(C.Mouse == m));
	if isempty(cellAll)
		continue;
	end
	Cm = C(C.Mouse == m, {'CellUID','ZLayer'});

	% --- correct training signal (Learned/Final LightWater)
		[correct, correctInfo] = iCorrectSignal(DS, m, cellAll, Cm, correctPhase, idxT, idxRef, baseMask, kSigma);
	if isempty(correct)
		continue;
	end
	if ~isempty(correctInfo)
		correctInfo.Source = repmat(sourceName, height(correctInfo), 1);
		correctInfo.Stage = repmat(stageName, height(correctInfo), 1);
		dbgOne.CorrectSession = [dbgOne.CorrectSession; correctInfo]; %#ok<AGROW>
	end

	% --- build per-session arrays (LightWater behavior + NTATS)
	% Phase range: from first startPhase to last endPhase (inclusive), per mouse.
	Ti = sortrows(Ti, {'DateTime'});
	phaseByTrial = string(Ti.Phase);
	if any(strlength(phaseByTrial) == 0)
		phaseByTrial = fillmissing(phaseByTrial, 'constant', "");
	end

	sessDT = unique(Ti.DateTime, 'stable');
	if numel(sessDT) < 1
		continue;
	end
	
	% session-level phase (mode across trials)
	sessPhase = strings(numel(sessDT),1);
	sessTrialUIDs = cell(numel(sessDT),1);
	for ii = 1:numel(sessDT)
		dt = sessDT(ii);
		maskDt = (Ti.DateTime == dt);
		ph = phaseByTrial(maskDt);
		ph = ph(ph ~= "");
		if isempty(ph)
			sessPhase(ii) = "";
		else
			[uPh,~,ic] = unique(ph);
			counts = accumarray(ic, 1);
			[~,mx] = max(counts);
			sessPhase(ii) = uPh(mx);
		end
		sessTrialUIDs{ii} = unique(uint64(Ti.TrialUID(maskDt)));
	end

	% determine phase range indices
	idxStart = find(sessPhase == startPhase, 1, 'first');
	idxEnd = find(sessPhase == endPhase, 1, 'last');
	if isempty(idxStart) || isempty(idxEnd) || idxEnd < idxStart
		continue;
	end
	keepPhaseRange = false(numel(sessDT),1);
	keepPhaseRange(idxStart:idxEnd) = true;

	S = struct('DateTime', {}, 'Phase', {}, 'Hit', {}, 'Trace', {}, 'CellUID', {}, 'NTrials', {}, 'HasAudioWater', {});

	for k = 1:numel(sessDT)
		dt = sessDT(k);
		ph = sessPhase(k);
		uid = uint64(sessTrialUIDs{k});
		uid = uid(:);
		if isempty(uid)
			continue;
		end

		hasAudioWater = iHasStimulus(DS, m, dt, "AudioWater");
		% exclude if outside phase range, or contaminated with AudioWater
		excluded = (~keepPhaseRange(k)) || hasAudioWater;
		exclReason = "";
		if ~keepPhaseRange(k)
			exclReason = iAppendReason(exclReason, "OutsidePhaseRange");
		end
		if hasAudioWater
			exclReason = iAppendReason(exclReason, "HasAudioWater");
		end

		% compute behavior (LightWater only)
		mask = ismember(uint64(Tr.TrialUID), uid) & (string(Tr.Stimulus) == "LightWater");
		if ~any(mask)
			continue;
		end
		hit = mean(double(Tr.Behavior(mask)), 'omitnan');
		if ~isfinite(hit)
			continue;
		end

		% Optionally exclude 0% hit sessions.
		if logical(excludeZeroHit) && isfinite(hit) && (hit <= 1e-12)
			excluded = true;
			exclReason = iAppendReason(exclReason, "ZeroHit");
		end

		% record session debug row
		dbgOne.Sessions = [dbgOne.Sessions; table(sourceName, stageName, m, dt, ph, double(hit), double(numel(uid)), logical(hasAudioWater), logical(excluded), ~logical(excluded), string(exclReason), ...
			'VariableNames', dbgOne.Sessions.Properties.VariableNames)]; %#ok<AGROW>
		dbgRowIdx = height(dbgOne.Sessions);
		if excluded
			continue;
		end

		[trace, cellUID] = iQueryNTATSTrace(DS, cellAll, uid);
		if isempty(trace) || isempty(cellUID)
			% Exclude: no usable NTATS trace for this session.
			try
				dbgOne.Sessions.Excluded(dbgRowIdx) = true;
				dbgOne.Sessions.Included(dbgRowIdx) = false;
				dbgOne.Sessions.ExclReason(dbgRowIdx) = iAppendReason(string(dbgOne.Sessions.ExclReason(dbgRowIdx)), "NoTrace");
			catch
			end
			continue;
		end
			needIdx = idxT;
		if ~isempty(idxRef)
			needIdx = max(needIdx, idxRef);
		end
		if size(trace,2) < needIdx
				% Exclude: trace too short to read at the target/reference time.
			try
				dbgOne.Sessions.Excluded(dbgRowIdx) = true;
				dbgOne.Sessions.Included(dbgRowIdx) = false;
				dbgOne.Sessions.ExclReason(dbgRowIdx) = iAppendReason(string(dbgOne.Sessions.ExclReason(dbgRowIdx)), "TraceTooShort");
			catch
			end
			continue;
		end

		S(end+1) = struct('DateTime', dt, 'Phase', ph, 'Hit', hit, 'Trace', trace, 'CellUID', cellUID, 'NTrials', double(numel(uid)), 'HasAudioWater', hasAudioWater); %#ok<AGROW>
	end
	if numel(S) < 2
		continue;
	end

	% Exclude 100% session and later (within usable sessions).
	h = [S.Hit];
	idx100 = find(isfinite(h) & (h >= (1 - 1e-12)), 1, 'first');
	if ~isempty(idx100)
		% mark excluded-by-100 in debug table
		try
			usableDT = [S.DateTime];
			keptDT = [S(1:max(0, idx100-1)).DateTime];
			Skeep = dbgOne.Sessions;
			maskPre = (Skeep.Mouse == m) & (Skeep.Source == sourceName) & (Skeep.Stage == stageName) & (Skeep.Included == true) & (Skeep.Excluded == false);
			% Only apply After100 to sessions that are usable (i.e. actually entered S)
			maskUsable = maskPre & ismember(Skeep.DateTime, usableDT(:));
			maskAfter = maskUsable & ~ismember(Skeep.DateTime, keptDT(:));
			if any(maskAfter)
				for ii = find(maskAfter)'
					Skeep.Excluded(ii) = true;
					Skeep.Included(ii) = false;
					Skeep.ExclReason(ii) = iAppendReason(string(Skeep.ExclReason(ii)), "After100");
				end
				dbgOne.Sessions = Skeep;
			end
		catch
		end
		S = S(1:max(0, idx100-1));
	end
	if numel(S) < 2
		continue;
	end

	% Adjacent pairs
	for k = 1:(numel(S)-1)
		A = S(k);
		B = S(k+1);
		dHit = B.Hit - A.Hit;

		[act, zAct] = iAvgActualSignalByLayer(A, B, Cm, idxT, idxRef, baseMask, kSigma, actualSignalMode);
		if isempty(act)
			continue;
		end

		for z = ["MOp23","MOp5"]
			zName = string(z);
			cZ = correct(correct.ZKey == zName, :);
			aZ = act(zAct == zName, :);
			if isempty(cZ) || isempty(aZ)
				continue;
			end

			[corr15, mse15, nCommon] = iSignalCorrMse(cZ.CellUID, cZ.Val15, aZ.CellUID, aZ.Val15, minCommonCells);
			[frac, jac, nActC, nActA] = iActiveOverlap(cZ.CellUID, logical(cZ.Active15), aZ.CellUID, logical(aZ.Active15));

			rows = [rows; table(m, sourceName, stageName, zName, A.DateTime, B.DateTime, A.Hit, B.Hit, dHit, ...
				double(nCommon), double(corr15), double(mse15), double(frac), double(jac), ...
				double(nActC), double(nActA), A.NTrials, B.NTrials, 'VariableNames', rows.Properties.VariableNames)]; %#ok<AGROW>
		end
	end
end

end

function [correct, info] = iCorrectSignal(DS, mouseName, cellAll, Cm, correctPhase, idxT, idxRef, baseMask, kSigma)
correct = table(uint64.empty(0,1), string.empty(0,1), nan(0,1), false(0,1), ...
	'VariableNames', {'CellUID','ZKey','Val15','Active15'});
	info = table(string.empty(0,1), string.empty(0,1), string.empty(0,1), NaT(0,1), string.empty(0,1), nan(0,1), nan(0,1), false(0,1), ...
		'VariableNames', {'Source','Stage','Mouse','DateTime','Phase','Hit','NTrials','HasAudioWater'});

% Find a pure LightWater session in the correct phase; choose the last DateTime.
try
	Tc = DS.TableQuery(["DateTime","TrialUID"], Mouse=string(mouseName), Stimulus="LightWater", Phase=correctPhase);
catch
	Tc = [];
end
if isempty(Tc)
	return;
end
try
	Tc.DateTime = datetime(Tc.DateTime);
	Tc.DateTime.TimeZone = '';
catch
end
Tc = sortrows(Tc, {'DateTime'});
	dt = Tc.DateTime(end);
	hasAudioWater = iHasStimulus(DS, mouseName, dt, "AudioWater");
if hasAudioWater
	return;
end
uid = unique(uint64(Tc.TrialUID(Tc.DateTime == dt)));
uid = uid(:);
if isempty(uid)
	return;
end

% behavior (LightWater only)
hit = NaN;
try
	Tr = DS.Trials;
	mask = ismember(uint64(Tr.TrialUID), uid) & (string(Tr.Stimulus) == "LightWater");
	if any(mask)
		hit = mean(double(Tr.Behavior(mask)), 'omitnan');
	end
catch
end

[trace, cellUID] = iQueryNTATSTrace(DS, cellAll, uid);

needIdx = idxT;
if nargin >= 7 && ~isempty(idxRef)
	needIdx = max(needIdx, idxRef);
end
if isempty(trace) || isempty(cellUID) || size(trace,2) < needIdx
	return;
end

if nargin >= 7 && ~isempty(idxRef)
	traceAdj = trace - trace(:, idxRef);
	val15 = double(traceAdj(:, idxT));
	act15 = iIsActiveAtIdx(traceAdj, baseMask, idxT, kSigma);
else
	val15 = double(trace(:, idxT));
	act15 = iIsActiveAtIdx(trace, baseMask, idxT, kSigma);
end

zKey = iCellZKey(Cm, cellUID);
keep = (zKey == "MOp23") | (zKey == "MOp5");
correct = table(uint64(cellUID(keep)), string(zKey(keep)), double(val15(keep)), logical(act15(keep)), ...
	'VariableNames', {'CellUID','ZKey','Val15','Active15'});

	info = table(string(missing), string(missing), string(mouseName), dt, string(correctPhase), double(hit), double(numel(uid)), logical(hasAudioWater), ...
		'VariableNames', {'Source','Stage','Mouse','DateTime','Phase','Hit','NTrials','HasAudioWater'});

end

function [act, zKey] = iAvgActualSignalByLayer(A, B, Cm, idxT, idxRef, baseMask, kSigma, actualSignalMode)
act = table(uint64.empty(0,1), nan(0,1), false(0,1), 'VariableNames', {'CellUID','Val15','Active15'});
zKey = string.empty(0,1);

if nargin < 7 || strlength(string(actualSignalMode)) == 0
	actualSignalMode = "MeanAB";
end
actualSignalMode = string(actualSignalMode);

if actualSignalMode == "PrevA"
	uid = uint64(A.CellUID(:));
	if isempty(uid)
		return;
	end
	traceAvg = A.Trace;
	if size(traceAvg,1) ~= numel(uid)
		return;
	end
else
	try
		uid = union(uint64(A.CellUID(:)), uint64(B.CellUID(:)));
	catch
		return;
	end
	if isempty(uid)
		return;
	end
	uid = uid(:);

	nTime = size(A.Trace,2);
	M1 = nan(numel(uid), nTime);
	M2 = nan(numel(uid), nTime);

	[tfA, locA] = ismember(uint64(uid), uint64(A.CellUID(:)));
	if any(tfA)
		M1(tfA,:) = A.Trace(locA(tfA),:);
	end
	[tfB, locB] = ismember(uint64(uid), uint64(B.CellUID(:)));
	if any(tfB)
		M2(tfB,:) = B.Trace(locB(tfB),:);
	end

	traceAvg = mean(cat(3, M1, M2), 3, 'omitnan');
end

if nargin >= 5 && ~isempty(idxRef)
	traceAdj = traceAvg - traceAvg(:, idxRef);
	val15 = double(traceAdj(:, idxT));
	act15 = iIsActiveAtIdx(traceAdj, baseMask, idxT, kSigma);
else
	val15 = double(traceAvg(:, idxT));
	act15 = iIsActiveAtIdx(traceAvg, baseMask, idxT, kSigma);
end

zKey = iCellZKey(Cm, uid);
act = table(uint64(uid), double(val15), logical(act15), 'VariableNames', {'CellUID','Val15','Active15'});

% Keep only MOp23/MOp5 to reduce downstream noise.
keep = (zKey == "MOp23") | (zKey == "MOp5");
zKey = string(zKey(keep));
act = act(keep, :);

end

function [trace, cellUID] = iQueryNTATSTrace(DS, cellAll, trialUID)
trace = [];
cellUID = uint64([]);
try
	q = struct('CellUID', uint64(cellAll(:)), 'TrialUID', uint64(trialUID(:)));
	G = DS.QueryNTATS(q, UniExp.Flags.ZScore, 1:24, UniExp.Flags.Median);
catch
	G = [];
end
if isempty(G) || ~all(ismember({'CellUID','NTATS'}, G.Properties.VariableNames))
	return;
end
X = G.NTATS;
if isa(X, 'MATLAB.DataTypes.NDTable')
	X = X.Data;
end
X = squeeze(X);
if isempty(X)
	return;
end
if isvector(X)
	X = X(:);
end
if size(X,1) ~= height(G)
	% unexpected shape
	return;
end

trace = double(X);
cellUID = uint64(G.CellUID);

% drop all-NaN rows
try
	good = any(isfinite(trace), 2);
	trace = trace(good,:);
	cellUID = cellUID(good);
catch
end

end

function a = iIsActiveAtIdx(trace, baseMask, idx, kSigma)
	a = false(size(trace,1),1);
	if isempty(trace) || size(trace,2) < idx
		return;
	end
	baseMu = mean(trace(:, baseMask), 2, 'omitnan');
	baseSd = std(trace(:, baseMask), 0, 2, 'omitnan');
	v = trace(:, idx);
	a = isfinite(v) & isfinite(baseMu) & isfinite(baseSd) & (v > (baseMu + kSigma .* baseSd));
end

function [corr15, mse15, nCommon] = iSignalCorrMse(uidC, valC, uidA, valA, minCommonCells)
	corr15 = NaN;
	mse15 = NaN;
	try
		uid = intersect(uint64(uidC), uint64(uidA));
	catch
		nCommon = NaN;
		return;
	end
	if isempty(uid)
		nCommon = 0;
		return;
	end
	uid = uid(:);
	[tfC, locC] = ismember(uint64(uid), uint64(uidC));
	[tfA, locA] = ismember(uint64(uid), uint64(uidA));
	use = tfC & tfA;
	if ~any(use)
		nCommon = 0;
		return;
	end
	x = double(valC(locC(use)));
	y = double(valA(locA(use)));
	use2 = isfinite(x) & isfinite(y);
	nCommon = nnz(use2);
	if nCommon < minCommonCells
		return;
	end
	mse15 = mean((x(use2) - y(use2)).^2, 'omitnan');
	if std(x(use2)) == 0 || std(y(use2)) == 0
		corr15 = NaN;
		return;
	end
	corr15 = corr(x(use2), y(use2), 'Type','Pearson');
end

function [frac, jac, nActC, nActA] = iActiveOverlap(uidC, actC, uidA, actA)
	frac = NaN;
	jac = NaN;
	uidC = uint64(uidC(:));
	uidA = uint64(uidA(:));
	actC = logical(actC(:));
	actA = logical(actA(:));
	try
		Ac = uidC(actC);
		Aa = uidA(actA);
	catch
		return;
	end
	nActC = numel(Ac);
	nActA = numel(Aa);
	if isempty(Ac) && isempty(Aa)
		return;
	end
	try
		inter = intersect(Ac, Aa);
		uni = union(Ac, Aa);
	catch
		return;
	end
	if ~isempty(Ac)
		frac = numel(inter) ./ numel(Ac);
	end
	if ~isempty(uni)
		jac = numel(inter) ./ numel(uni);
	end
end

function tf = iIsPureLightWaterSession(DS, mouseName, dt)
	tf = false;
	try
		Tdt = DS.TableQuery("Stimulus", Mouse=string(mouseName), DateTime=dt);
	catch
		Tdt = [];
	end
	if isempty(Tdt) || ~ismember('Stimulus', Tdt.Properties.VariableNames)
		return;
	end
	try
		st = unique(string(Tdt.Stimulus));
		st = st(~ismissing(st));
	catch
		st = string([]);
	end
	if isempty(st)
		return;
	end
	tf = all(st == "LightWater");
end

function tf = iHasStimulus(DS, mouseName, dt, stim)
	tf = false;
	try
		Tdt = DS.TableQuery("Stimulus", Mouse=string(mouseName), DateTime=dt);
	catch
		Tdt = [];
	end
	if isempty(Tdt) || ~ismember('Stimulus', Tdt.Properties.VariableNames)
		return;
	end
	try
		st = unique(string(Tdt.Stimulus));
		st = st(~ismissing(st));
	catch
		st = string([]);
	end
	if isempty(st)
		return;
	end
	tf = any(st == string(stim));
end

function s = iAppendReason(s, add)
	s = string(s);
	add = string(add);
	if strlength(add) == 0
		return;
	end
	if strlength(s) == 0
		s = add;
	else
		s = s + ";" + add;
	end
end

function zKey = iCellZKey(Cm, cellUID)
	zKey = repmat("Unknown", numel(cellUID), 1);
	try
		CZ = innerjoin(table(uint64(cellUID(:)), 'VariableNames', {'CellUID'}), Cm(:,{'CellUID','ZLayer'}), 'Keys', 'CellUID');
		[tf, loc] = ismember(uint64(cellUID(:)), uint64(CZ.CellUID));
		if any(tf)
			zKey(tf) = iZKey(string(CZ.ZLayer(loc(tf))));
		end
	catch
	end
end

function zKey = iZKey(zLayer)
	zl = string(zLayer);
	zKey = strings(size(zl));
	m23 = contains(zl, "2/3") | contains(zl, "2") & contains(zl, "3") | contains(zl, "23");
	m5  = contains(zl, "MOp5") | (contains(zl, "5") & ~m23);
	zKey(m23) = "MOp23";
	zKey(m5) = "MOp5";
	zKey(zKey == "") = "Other";
end
