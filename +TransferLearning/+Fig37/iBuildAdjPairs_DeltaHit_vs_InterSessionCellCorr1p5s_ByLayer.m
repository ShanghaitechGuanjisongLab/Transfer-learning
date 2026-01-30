function pairs = iBuildAdjPairs_DeltaHit_vs_InterSessionCellCorr1p5s_ByLayer()
% Build adjacent-session-pair table, split by layer (MOp2/3 vs MOp5).
%
% Same logic as iBuildAdjPairs_DeltaHit_vs_InterSessionCellCorr1p5s, except
% each adjacent session pair contributes up to 2 rows (one per layer), with:
%   ZKey = "MOp23" or "MOp5"
%   CellCorr1p5 = corr(NTATS@1.5s vectors across common cells in that layer)
%
% Returns table variables:
%   Mouse, Source, Stage, ZKey, DateTime1, DateTime2, Hit1, Hit2, DeltaHit,
%   NCommonCells, CellCorr1p5, NTrials1, NTrials2
%
% Execution:
%   pairs = TransferLearning.Fig37.iBuildAdjPairs_DeltaHit_vs_InterSessionCellCorr1p5s_ByLayer

pairs = table(string.empty(0,1), string.empty(0,1), string.empty(0,1), string.empty(0,1), NaT(0,1), NaT(0,1), ...
	nan(0,1), nan(0,1), nan(0,1), nan(0,1), nan(0,1), nan(0,1), nan(0,1), ...
	'VariableNames', {'Mouse','Source','Stage','ZKey','DateTime1','DateTime2','Hit1','Hit2','DeltaHit', ...
	'NCommonCells','CellCorr1p5','NTrials1','NTrials2'});

xsSec = seconds(TransferLearning.Xs);
[dtMin, idx15] = min(abs(xsSec - 1.5));
if isempty(idx15) || ~isfinite(dtMin) || dtMin > 0.25
	error('Fig37:iBuildAdjPairsCellCorrByLayer:No1p5sSample', 'Cannot find a sample close to 1.5s in TransferLearning.Xs.');
end

minCommonCellsPerLayer = 5;

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
	rows = iOneDataSet(DS, string(S.Source), string(S.Stage), idx15, minCommonCellsPerLayer, requirePureLightWater);
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

function rows = iOneDataSet(DS, sourceName, stageName, idx15, minCommonCellsPerLayer, requirePureLightWater)
rows = table(string.empty(0,1), string.empty(0,1), string.empty(0,1), string.empty(0,1), NaT(0,1), NaT(0,1), ...
	nan(0,1), nan(0,1), nan(0,1), nan(0,1), nan(0,1), nan(0,1), nan(0,1), ...
	'VariableNames', {'Mouse','Source','Stage','ZKey','DateTime1','DateTime2','Hit1','Hit2','DeltaHit', ...
	'NCommonCells','CellCorr1p5','NTrials1','NTrials2'});

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

	dts = unique(Ti.DateTime, 'stable');
	n = numel(dts);
	if n < 2
		continue;
	end

	% Build per-session arrays, keeping only sessions with usable calcium at 1.5s
	S = struct('DateTime', {}, 'Hit', {}, 'Vec', {}, 'NTrials', {});
	for k = 1:n
		dt = dts(k);
		if requirePureLightWater && ~iIsPureLightWaterSession(DS, m, dt)
			continue;
		end
		uid = unique(uint64(Ti.TrialUID(Ti.DateTime == dt)));
		uid = uid(:);
		if isempty(uid)
			continue;
		end

		mask = ismember(uint64(Tr.TrialUID), uid) & (string(Tr.Stimulus) == "LightWater");
		if ~any(mask)
			continue;
		end
		hit = mean(double(Tr.Behavior(mask)), 'omitnan');
		if ~isfinite(hit)
			continue;
		end

		% QueryNTATS may fail for behavior-only sessions; skip those.
		try
			q = struct('CellUID', uint64(cellAll), 'TrialUID', uint64(uid));
			G = DS.QueryNTATS(q, UniExp.Flags.ZScore, 1:24, UniExp.Flags.Median);
		catch
			G = [];
		end
		if isempty(G) || ~all(ismember({'CellUID','NTATS'}, G.Properties.VariableNames))
			continue;
		end
		X = G.NTATS;
		if isa(X, 'MATLAB.DataTypes.NDTable')
			X = X.Data;
		end
		X = squeeze(X);
		if isempty(X) || size(X,2) < idx15
			continue;
		end
		v = double(X(:, idx15));
		vec = table(uint64(G.CellUID), v, 'VariableNames', {'CellUID','Val'});
		vec = vec(isfinite(vec.Val), :);
		if isempty(vec)
			continue;
		end

		S(end+1) = struct('DateTime', dt, 'Hit', hit, 'Vec', vec, 'NTrials', double(numel(uid))); %#ok<AGROW>
	end

	if numel(S) < 2
		continue;
	end

	% Trim at first 100% within the usable-calcium sessions.
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
		[r23, n23, r5, n5] = iInterSessionCorrByLayer(A.Vec, B.Vec, Cm, minCommonCellsPerLayer);
		dHit = B.Hit - A.Hit;

		if isfinite(r23)
			rows = [rows; table(m, sourceName, stageName, "MOp23", A.DateTime, B.DateTime, A.Hit, B.Hit, dHit, ...
				double(n23), double(r23), A.NTrials, B.NTrials, 'VariableNames', rows.Properties.VariableNames)]; %#ok<AGROW>
		end
		if isfinite(r5)
			rows = [rows; table(m, sourceName, stageName, "MOp5", A.DateTime, B.DateTime, A.Hit, B.Hit, dHit, ...
				double(n5), double(r5), A.NTrials, B.NTrials, 'VariableNames', rows.Properties.VariableNames)]; %#ok<AGROW>
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

function [r23, n23, r5, n5] = iInterSessionCorrByLayer(A, B, Cm, minCommonCells)
	r23 = NaN; r5 = NaN;
	n23 = NaN; n5 = NaN;
	if isempty(A) || isempty(B)
		return;
	end
	try
		uid = intersect(uint64(A.CellUID), uint64(B.CellUID));
	catch
		return;
	end
	if isempty(uid)
		n23 = 0;
		n5 = 0;
		return;
	end

	zKey = iCellZKey(Cm, uid);
	uid23 = uid(zKey == "MOp23");
	uid5 = uid(zKey == "MOp5");

	[r23, n23] = iInterSessionCorr(A, B, uid23, minCommonCells);
	[r5, n5] = iInterSessionCorr(A, B, uid5, minCommonCells);
end

function [r, nCommon] = iInterSessionCorr(A, B, uid, minCommonCells)
	r = NaN;
	if isempty(uid)
		nCommon = 0;
		return;
	end
	try
		Au = sortrows(A(ismember(uint64(A.CellUID), uid), :), 'CellUID');
		Bu = sortrows(B(ismember(uint64(B.CellUID), uid), :), 'CellUID');
		% ensure alignment
		uid2 = intersect(uint64(Au.CellUID), uint64(Bu.CellUID));
		Au = sortrows(Au(ismember(uint64(Au.CellUID), uid2), :), 'CellUID');
		Bu = sortrows(Bu(ismember(uint64(Bu.CellUID), uid2), :), 'CellUID');
		v1 = double(Au.Val);
		v2 = double(Bu.Val);
		use = isfinite(v1) & isfinite(v2);
		nCommon = nnz(use);
		if nCommon < minCommonCells || std(v1(use)) == 0 || std(v2(use)) == 0
			r = NaN;
			return;
		end
		r = corr(v1(use), v2(use), 'Type','Pearson');
	catch
		r = NaN;
		nCommon = NaN;
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
