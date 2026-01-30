function pairs = iBuildAdjPairs_DeltaHit_vs_PrevRelDiv1p5s_ByLayer()
% Build adjacent-session-pair table, split by layer (MOp2/3 vs MOp5).
%
% Same logic as iBuildAdjPairs_DeltaHit_vs_PrevRelDiv1p5s, except each
% adjacent session pair contributes up to 2 rows (one per layer), with:
%   ZKey = "MOp23" or "MOp5"
%   RelDiv1p5Prev = relative divergence at 1.5s for the previous session,
%                  computed using only cells in that layer.
%
% Returns table variables:
%   Mouse, Source, Stage, ZKey, DateTime1, DateTime2, Hit1, Hit2, DeltaHit,
%   RelDiv1p5Prev, NCellsPrev, NTrials1, NTrials2
%
% Execution:
%   pairs = TransferLearning.Fig37.iBuildAdjPairs_DeltaHit_vs_PrevRelDiv1p5s_ByLayer

pairs = table(string.empty(0,1), string.empty(0,1), string.empty(0,1), string.empty(0,1), NaT(0,1), NaT(0,1), ...
	nan(0,1), nan(0,1), nan(0,1), nan(0,1), nan(0,1), nan(0,1), nan(0,1), ...
	'VariableNames', {'Mouse','Source','Stage','ZKey','DateTime1','DateTime2','Hit1','Hit2','DeltaHit', ...
	'RelDiv1p5Prev','NCellsPrev','NTrials1','NTrials2'});

xsSec = seconds(TransferLearning.Xs);
[dtMin, idx15_ref] = min(abs(xsSec - 1.5));
if isempty(idx15_ref) || ~isfinite(dtMin) || dtMin > 0.25
	error('Fig37:iBuildAdjPairsRelDivByLayer:No1p5sSample', 'Cannot find a sample close to 1.5s in TransferLearning.Xs.');
end
nT_ref = numel(xsSec);

minTrials = 2;
minCellsPerLayer = 5;

spec = [ ...
	struct('Stage',"LightNaive",   'DataSet',@() TransferLearning.LightAudioBaseline(),  'Source',"LightAudioBaseline"), ...
	struct('Stage',"LightNaive",   'DataSet',@() TransferLearning.LAInterspersed(),     'Source',"LAInterspersed"), ...
	struct('Stage',"AudioToLight", 'DataSet',@() TransferLearning.AudioLightBaseline(), 'Source',"AudioLightBaseline") ...
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
	requirePureLightWater = (string(S.Stage) == "AudioToLight");
	rows = iOneDataSet(DS, string(S.Source), string(S.Stage), idx15_ref, nT_ref, minTrials, minCellsPerLayer, requirePureLightWater);
	if ~isempty(rows)
		pairs = [pairs; rows]; %#ok<AGROW>
	end
end

if ~isempty(pairs)
	pairs.Mouse = string(pairs.Mouse);
	pairs.Source = string(pairs.Source);
	pairs.Stage = string(pairs.Stage);
	pairs.ZKey = string(pairs.ZKey);
	pairs = sortrows(pairs, {'Stage','Source','ZKey','Mouse','DateTime1'});
end

end

%% --- local helpers

function rows = iOneDataSet(DS, sourceName, stageName, idx15_ref, nT_ref, minTrials, minCellsPerLayer, requirePureLightWater)
rows = table(string.empty(0,1), string.empty(0,1), string.empty(0,1), string.empty(0,1), NaT(0,1), NaT(0,1), ...
	nan(0,1), nan(0,1), nan(0,1), nan(0,1), nan(0,1), nan(0,1), nan(0,1), ...
	'VariableNames', {'Mouse','Source','Stage','ZKey','DateTime1','DateTime2','Hit1','Hit2','DeltaHit', ...
	'RelDiv1p5Prev','NCellsPrev','NTrials1','NTrials2'});

% --- prefetch block/trial index for LightWater sessions
try
	T = DS.TableQuery(["Mouse","DateTime","TrialUID"], Stimulus="LightWater");
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

	% cache per-mouse NTS for speed
	try
		ntsCell = DS.QueryNTS(struct('Stimulus', "LightWater", 'Mouse', string(m)), UniExp.Flags.ZScore, 1:24);
		nts = ntsCell{1};
	catch
		continue;
	end
	if isempty(nts)
		continue;
	end

	dts = unique(Ti.DateTime, 'stable');
	n = numel(dts);
	if n < 2
		continue;
	end

	% Build per-session arrays, keeping only sessions with usable RelDiv at 1.5s (either layer)
	S = struct('DateTime', {}, 'Hit', {}, 'Div23', {}, 'Div5', {}, 'N23', {}, 'N5', {}, 'NTrials', {});
	for k = 1:n
		dt = dts(k);
		if requirePureLightWater && ~iIsPureLightWaterSession(DS, m, dt)
			continue;
		end
		uid = unique(uint64(Ti.TrialUID(Ti.DateTime == dt)));
		uid = uid(:);
		if numel(uid) < minTrials
			continue;
		end

		mask = ismember(uint64(Tr.TrialUID), uid) & (string(Tr.Stimulus) == "LightWater");
		if nnz(mask) < minTrials
			continue;
		end
		hit = mean(double(Tr.Behavior(mask)), 'omitnan');
		if ~isfinite(hit)
			continue;
		end

		[div23, div5, n23, n5] = iRelDivFromNTS_ByLayer(nts, uid, cellAll, Cm, idx15_ref, nT_ref, minTrials, minCellsPerLayer);
		if ~isfinite(div23) && ~isfinite(div5)
			continue;
		end

		S(end+1) = struct('DateTime', dt, 'Hit', hit, 'Div23', div23, 'Div5', div5, ...
			'N23', n23, 'N5', n5, 'NTrials', double(numel(uid))); %#ok<AGROW>
	end

	if numel(S) < 2
		continue;
	end

	% Trim at first 100% within the usable sessions.
	h = [S.Hit];
	idx100 = find(isfinite(h) & (h >= (1 - 1e-12)), 1, 'first');
	if ~isempty(idx100)
		S = S(1:max(0, idx100-1));
	end
	if numel(S) < 2
		continue;
	end

	% Adjacent pairs (add up to 2 rows, one per layer)
	for k = 1:(numel(S)-1)
		A = S(k);
		B = S(k+1);
		dHit = B.Hit - A.Hit;

		if isfinite(A.Div23)
			rows = [rows; table(m, sourceName, stageName, "MOp23", A.DateTime, B.DateTime, A.Hit, B.Hit, dHit, ...
				A.Div23, double(A.N23), double(A.NTrials), double(B.NTrials), 'VariableNames', rows.Properties.VariableNames)]; %#ok<AGROW>
		end
		if isfinite(A.Div5)
			rows = [rows; table(m, sourceName, stageName, "MOp5", A.DateTime, B.DateTime, A.Hit, B.Hit, dHit, ...
				A.Div5, double(A.N5), double(A.NTrials), double(B.NTrials), 'VariableNames', rows.Properties.VariableNames)]; %#ok<AGROW>
		end
	end
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

function [div23, div5, n23, n5] = iRelDivFromNTS_ByLayer(nts, trialUID, cellUIDKeep, Cm, idx15_ref, nT_ref, minTrials, minCellsPerLayer)
	div23 = NaN; div5 = NaN;
	n23 = NaN; n5 = NaN;
	trialUID = uint64(trialUID(:));
	cellUIDKeep = uint64(cellUIDKeep(:));
	if isempty(trialUID) || isempty(cellUIDKeep)
		return;
	end

	try
		inTrial = ismember(uint64(nts.TrialUID), trialUID);
		inCell  = ismember(uint64(nts.CellUID), cellUIDKeep);
		nt = nts(inTrial & inCell, :);
	catch
		return;
	end
	if isempty(nt)
		return;
	end

	try
		nT = size(nt.TrialSignal, 2);
		if nT == nT_ref
			idx15 = idx15_ref;
		else
			xs2 = linspace(-3, 3, nT);
			[dtMin, idx15] = min(abs(xs2 - 1.5));
			if isempty(idx15) || ~isfinite(dtMin) || dtMin > 0.25
				return;
			end
		end
		v1 = double(nt.TrialSignal(:, idx15));
	catch
		return;
	end

	cellU = unique(uint64(nt.CellUID));
	trialU = unique(uint64(nt.TrialUID));
	if numel(trialU) < minTrials
		return;
	end

	[~, cellIdx] = ismember(uint64(nt.CellUID), cellU);
	[~, trialIdx] = ismember(uint64(nt.TrialUID), trialU);
	Z = nan(numel(cellU), numel(trialU));
	lin = sub2ind(size(Z), cellIdx, trialIdx);
	Z = iAccumMean(Z, lin, v1);

	% keep cells with at least 2 finite trials
	goodCell = sum(isfinite(Z), 2) >= 2;
	Z = Z(goodCell, :);
	cellU = cellU(goodCell);
	if numel(cellU) < 2
		return;
	end

	% layer map (MOp23 vs MOp5)
	zKey = iCellZKey(Cm, cellU);
	m23 = (zKey == "MOp23");
	m5  = (zKey == "MOp5");
	n23 = nnz(m23);
	n5 = nnz(m5);

	if n23 >= minCellsPerLayer
		div23 = iRelDivFromMatrix(Z(m23, :));
	end
	if n5 >= minCellsPerLayer
		div5 = iRelDivFromMatrix(Z(m5, :));
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

function Z = iAccumMean(Z, linIdx, values)
	[linU, ~, g] = unique(linIdx);
	mu = splitapply(@(x) mean(x, 'omitnan'), values, g);
	Z(linU) = mu;
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
