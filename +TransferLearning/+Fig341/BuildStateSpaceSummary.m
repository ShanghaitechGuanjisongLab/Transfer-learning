function Data = BuildStateSpaceSummary(normFlag)
arguments
	normFlag = UniExp.Flags.No_special_operation
end

persistent CachedBuilder
if isempty(CachedBuilder)
	CachedBuilder = memoize(@iBuildStateSpaceSummaryCore);
end

Data = CachedBuilder(normFlag);
end

function Data = iBuildStateSpaceSummaryCore(normFlag)

xs = TransferLearning.Xs;
if isduration(xs)
	xsSec = seconds(xs);
else
	xsSec = double(xs);
end
[idx0s, ok0s] = iFindTimeIndex(xsSec, 0, 0.25);
if ~ok0s
	error('Fig341:Bad0sIndex', 'Cannot find sample close to 0 s.');
end
[idx1s, ok1s] = iFindTimeIndex(xsSec, 1, 0.25);
if ~ok1s
	error('Fig341:Bad1sIndex', 'Cannot find sample close to 1 s.');
end

Specs = [ ...
	builtin('struct', 'Group', "Naive", 'Source', "LAB", 'DS', TransferLearning.LightAudioBaseline(), 'StartPhase', "Naive", 'EndPhase', "Learned")
	builtin('struct', 'Group', "Naive", 'Source', "LAI", 'DS', TransferLearning.LAInterspersed(), 'StartPhase', "Naive", 'EndPhase', "Learned")
	builtin('struct', 'Group', "Transfer", 'Source', "ALB", 'DS', TransferLearning.AudioLightBaseline(), 'StartPhase', "Transfer", 'EndPhase', "Final")
	builtin('struct', 'Group', "Transfer", 'Source', "ALI", 'DS', TransferLearning.ALInterspersed(), 'StartPhase', "Transfer", 'EndPhase', "Final")
];

sessionParts = cell(numel(Specs), 1);
for iSpec = 1:numel(Specs)
	sessionParts{iSpec} = iBuildLearningSessionsForSource(Specs(iSpec));
end
allSessions = vertcat(sessionParts{:});
allSessions = sortrows(allSessions, {'Group', 'Mouse', 'DateTime'});

iAssertNoCrossSourceDuplicateMice(allSessions(allSessions.Group == "Naive", :), "Naive");
iAssertNoCrossSourceDuplicateMice(allSessions(allSessions.Group == "Transfer", :), "Transfer");
iAssertNoMouseAppearsInMultipleGroups(allSessions);

stateRows = repmat(iEmptyMouseState(), 0, 1);
metricRows = repmat(iEmptyMetricRow(), 0, 1);
for iSpec = 1:numel(Specs)
	Ssrc = allSessions(allSessions.Source == Specs(iSpec).Source, :);
	mice = unique(Ssrc.Mouse);
	for iMouse = 1:numel(mice)
		mouseId = mice(iMouse);
		Sm = Ssrc(Ssrc.Mouse == mouseId, :);
		if height(Sm) < 2
			continue;
		end
		[R, Sm] = iQueryMouseNtats(Specs(iSpec).DS, Sm, normFlag);
		if height(Sm) < 2 || isempty(R) || height(R) < 2
			continue;
		end
		X = iNtatsTo3D(R.NTATS);
		if isempty(X) || size(X, 3) ~= height(Sm)
			continue;
		end
		cellUID = uint64(R.CellUID);
		layers = iLookupLayers(Specs(iSpec).DS, cellUID);
		[pointsAll, explainedAll] = iSessionPointsFromNtats(X, idx1s);
		if size(pointsAll, 1) ~= height(Sm)
			continue;
		end

		st = iEmptyMouseState();
		st.Mouse = mouseId;
		st.Group = Specs(iSpec).Group;
		st.Source = Specs(iSpec).Source;
		st.SessionTable = Sm;
		st.CellUID = cellUID;
		st.Layers = layers;
		st.NTATS = X;
		st.Points = pointsAll;
		st.Explained = explainedAll;
		stateRows(end + 1) = st; %#ok<AGROW>

		for zLayer = ["MOp2/3", "MOp5"]
			mask = layers == zLayer;
			if nnz(mask) < 2
				continue;
			end
			[pointsLayer, explainedLayer] = iSessionPointsFromNtats(X(mask, :, :), idx1s);
			if size(pointsLayer, 1) ~= height(Sm)
				continue;
			end
			[pathLen, directLen, ratioVal, avgStep, effStep] = iMetricsFromPoints(pointsLayer);
			row = iEmptyMetricRow();
			row.Mouse = mouseId;
			row.Group = Specs(iSpec).Group;
			row.Source = Specs(iSpec).Source;
			row.ZLayer = zLayer;
			row.NSession = height(Sm);
			row.PathLength = pathLen;
			row.DirectLength = directLen;
			row.PathOverDirect = ratioVal;
			row.AverageStep = avgStep;
			row.EffectiveStep = effStep;
			row.Points = {pointsLayer};
			row.Explained = {explainedLayer};
			metricRows(end + 1) = row; %#ok<AGROW>
		end
	end
end

if isempty(stateRows)
	error('Fig341:NoMouseState', 'No mouse-level NTATS state-space data were built.');
end
if isempty(metricRows)
	error('Fig341:NoMetrics', 'No layer metrics were built.');
end

Metrics = struct2table(metricRows);
MouseStates = stateRows;
Rep = iSelectRepresentatives(MouseStates, idx0s, idx1s, xsSec);

Data = struct();
Data.XsSec = xsSec;
Data.Index0s = idx0s;
Data.Index1s = idx1s;
Data.Sessions = allSessions;
Data.MouseStates = MouseStates;
Data.Metrics = Metrics;
Data.Representative = Rep;
Data.NormFlag = normFlag;
end

function Sess = iBuildLearningSessionsForSource(spec)
T = spec.DS.TableQuery(["Mouse", "DateTime", "Stimulus", "Phase", "Behavior", "Performance"]);
if isempty(T)
	Sess = table(string.empty(0,1), NaT(0,1), nan(0,1), strings(0,1), strings(0,1), strings(0,1), false(0,1), ...
		'VariableNames', {'Mouse','DateTime','Performance','Phase','Group','Source','IsMixedAudio'});
	return;
end

T.Mouse = string(T.Mouse);
T.DateTime = iNormalizeDateTime(T.DateTime);
T.Stimulus = string(T.Stimulus);
T.Phase = string(T.Phase);

[G, mouseKeys, dtKeys] = findgroups(T.Mouse, T.DateTime);
phaseCell = splitapply(@(x) {iPickSessionPhase(x)}, T.Phase, G);
phaseVals = string(vertcat(phaseCell{:}));
nSess = max(G);
perf = nan(nSess, 1);
isMixed = false(nSess, 1);

for gi = 1:nSess
	R = T(G == gi, :);
	if ~any(R.Stimulus == "LightWater")
		continue;
	end
	isMixed(gi) = any(R.Stimulus == "AudioWater");
	lightRows = R(R.Stimulus == "LightWater", :);
	if all(R.Stimulus == "LightWater") && any(isfinite(double(R.Performance)))
		perf(gi) = mean(double(R.Performance), 'omitnan');
	else
		perf(gi) = mean(double(lightRows.Behavior), 'omitnan');
	end
end

Sess = table(mouseKeys, dtKeys, perf, phaseVals, repmat(spec.Group, nSess, 1), repmat(spec.Source, nSess, 1), isMixed, ...
	'VariableNames', {'Mouse','DateTime','Performance','Phase','Group','Source','IsMixedAudio'});
Sess = Sess(isfinite(Sess.Performance), :);
Sess = sortrows(Sess, {'Mouse', 'DateTime'});
Sess = iSelectSessionsBetweenPhases(Sess, spec.StartPhase, spec.EndPhase);
Sess = Sess(~Sess.IsMixedAudio, :);
Sess = iTrimAfterCeilingKeepFirst(Sess);
end

function Sess = iSelectSessionsBetweenPhases(Sess, startPhase, endPhase)
if isempty(Sess)
	return;
end
Sess = sortrows(Sess, {'Mouse', 'DateTime'});
mice = unique(Sess.Mouse);
keep = false(height(Sess), 1);
for iMouse = 1:numel(mice)
	idx = find(Sess.Mouse == mice(iMouse));
	ph = Sess.Phase(idx);
	st = find(ph == string(startPhase), 1, 'first');
	if isempty(st)
		continue;
	end
	ed = find(ph == string(endPhase) & (1:numel(ph))' >= st, 1, 'first');
	if isempty(ed)
		ed = numel(ph);
	end
	keep(idx(st:ed)) = true;
end
Sess = Sess(keep, :);
end

function Sess = iTrimAfterCeilingKeepFirst(Sess)
if isempty(Sess)
	return;
end
Sess = sortrows(Sess, {'Mouse', 'DateTime'});
mice = unique(Sess.Mouse);
keep = false(height(Sess), 1);
for iMouse = 1:numel(mice)
	idx = find(Sess.Mouse == mice(iMouse));
	p = double(Sess.Performance(idx));
	k = find(isfinite(p) & p >= 1 - 1e-12, 1, 'first');
	if isempty(k)
		keep(idx) = true;
	else
		keep(idx(1:k)) = true;
	end
end
Sess = Sess(keep, :);
end

function [R, SessKeep] = iQueryMouseNtats(DS, Sess, normFlag)
Q = Sess(:, {'Mouse', 'DateTime'});
Q.Stimulus = repmat("LightWater", height(Q), 1);
Q = Q(:, {'Mouse', 'DateTime', 'Stimulus'});
SessKeep = Sess;
try
	raw = DS.QueryNTATS(Q, normFlag, 1:24, UniExp.Flags.Median);
catch ME
	if ME.identifier ~= "UniExp:Exception:Empty_group"
		rethrow(ME);
	end
	[keepMask, parts] = iQueryNtatsIgnoringEmptyGroups(DS, Q, normFlag);
	SessKeep = Sess(keepMask, :);
	if height(SessKeep) < 2
		R = table();
		return;
	end
	raw = parts;
end

R = iNtatsResultToTable(raw);
if isempty(R) || ~ismember('NTATS', string(R.Properties.VariableNames)) || ~ismember('CellUID', string(R.Properties.VariableNames))
	R = table();
	SessKeep = SessKeep([], :);
	return;
end
X = iNtatsTo3D(R.NTATS);
if isempty(X) || size(X, 3) ~= height(SessKeep)
	R = table();
	SessKeep = SessKeep([], :);
end
end

function [keepMask, parts] = iQueryNtatsIgnoringEmptyGroups(DS, Q, normFlag)
nGroup = height(Q);
parts = cell(nGroup, 1);
keepMask = false(nGroup, 1);
for iGroup = 1:nGroup
	try
		parts{iGroup} = DS.QueryNTATS(Q(iGroup, :), normFlag, 1:24, UniExp.Flags.Median);
		keepMask(iGroup) = true;
	catch ME
		if ME.identifier ~= "UniExp:Exception:Empty_group"
			rethrow(ME);
		end
	end
end
parts = parts(keepMask);
end

function R = iNtatsResultToTable(raw)
R = table();
if isempty(raw)
	return;
end
S = UniExp.NtatsCellStrip(raw);
if isempty(S) || ~istable(S) || ~all(ismember({'CellUID','NTATS'}, string(S.Properties.VariableNames)))
	return;
end
X = iNtatsTo3D(S.NTATS);
if isempty(X)
	return;
end
R = table(uint64(S.CellUID), MATLAB.DataTypes.NDTable(X), 'VariableNames', {'CellUID','NTATS'});
end

function X = iNtatsTo3D(nt)
X = [];
if isa(nt, 'MATLAB.DataTypes.NDTable')
	X = nt{:,:,:};
	if ismatrix(X)
		X = reshape(X, size(X, 1), size(X, 2), 1);
	end
	return;
end
if isnumeric(nt)
	X = double(nt);
	if ismatrix(X)
		X = reshape(X, size(X, 1), size(X, 2), 1);
	end
	return;
end
if istable(nt) && ismember('NTATS', nt.Properties.VariableNames)
	X = iNtatsTo3D(nt.NTATS);
	return;
end
if iscell(nt)
	if isempty(nt)
		return;
	end
	parts = cellfun(@iNtatsCellToMatrix, nt, 'UniformOutput', false);
	if any(cellfun(@isempty, parts))
		return;
	end
	nCell = size(parts{1}, 1);
	nTime = size(parts{1}, 2);
	X = nan(nCell, nTime, numel(parts));
	for i = 1:numel(parts)
		if ~isequal(size(parts{i}), [nCell, nTime])
			X = [];
			return;
		end
		X(:, :, i) = parts{i};
	end
end
end

function X = iNtatsCellToMatrix(nt)
X = [];
if isa(nt, 'MATLAB.DataTypes.NDTable')
	X = nt{:,:};
	return;
end
if isnumeric(nt)
	X = double(nt);
	return;
end
if istable(nt) && ismember('NTATS', nt.Properties.VariableNames)
	X = iNtatsCellToMatrix(nt.NTATS);
	return;
end
if iscell(nt)
	if isempty(nt)
		return;
	end
	rows = cellfun(@iOneNtatsRow, nt, 'UniformOutput', false);
	if any(cellfun(@isempty, rows))
		return;
	end
	X = vertcat(rows{:});
end
end

function row = iOneNtatsRow(one)
row = [];
if isa(one, 'MATLAB.DataTypes.NDTable')
	row = one{:,:};
	return;
end
if isnumeric(one)
	row = double(one);
end
end

function layers = iLookupLayers(DS, cellUID)
C = DS.Cells(:, intersect(["CellUID", "ZLayer"], string(DS.Cells.Properties.VariableNames), 'stable'));
if ~all(ismember(["CellUID", "ZLayer"], string(C.Properties.VariableNames)))
	error('Fig341:MissingLayerMeta', 'Cells table for %s lacks CellUID/ZLayer.', class(DS));
end
C.CellUID = uint64(C.CellUID);
C.ZLayer = string(C.ZLayer);
[tf, loc] = ismember(cellUID, C.CellUID);
layers = strings(size(cellUID));
layers(tf) = C.ZLayer(loc(tf));
end

function [points, explained] = iSessionPointsFromNtats(X, idx1s)
if isempty(X)
	points = nan(0, 2);
	explained = [NaN NaN];
	return;
end
if ismatrix(X)
	X = reshape(X, size(X, 1), size(X, 2), 1);
end
if idx1s > size(X, 2)
	points = nan(size(X, 3), 2);
	explained = [NaN NaN];
	return;
end
vals = squeeze(X(:, idx1s, :));
if isa(vals, 'MATLAB.DataTypes.NDTable')
	vals = double(vals.Data);
end
if isvector(vals)
	vals = reshape(vals, size(X, 1), size(X, 3));
end
sessionByCell = vals';
validCols = all(isfinite(sessionByCell), 1);
sessionByCell = sessionByCell(:, validCols);
if size(sessionByCell, 2) < 1 || size(sessionByCell, 1) < 2
	points = nan(size(X, 3), 2);
	explained = [NaN NaN];
	return;
end
sessionByCell = sessionByCell - mean(sessionByCell, 1, 'omitnan');
[u, s, ~] = svd(sessionByCell, 'econ');
score = u * s;
latent = diag(s).^2;
if numel(latent) >= 1 && sum(latent) > 0
	explAll = latent ./ sum(latent) * 100;
else
	explAll = NaN(size(latent));
end
points = zeros(size(sessionByCell, 1), 2);
points(:, 1:min(2, size(score, 2))) = score(:, 1:min(2, size(score, 2)));
explained = nan(1, 2);
explained(1:min(2, numel(explAll))) = explAll(1:min(2, numel(explAll)));
end

function [pathLen, directLen, ratioVal, avgStep, effStep] = iMetricsFromPoints(points)
dp = diff(points, 1, 1);
stepLens = sqrt(sum(dp.^2, 2));
pathLen = sum(stepLens, 'omitnan');
directLen = sqrt(sum((points(end, :) - points(1, :)).^2, 2));
if isfinite(pathLen) && isfinite(directLen) && directLen > 0
	ratioVal = pathLen / directLen;
else
	ratioVal = NaN;
end
nStep = size(points, 1) - 1;
if nStep >= 1
	avgStep = pathLen / nStep;
	effStep = directLen / nStep;
else
	avgStep = NaN;
	effStep = NaN;
end
end

function Rep = iSelectRepresentatives(MouseStates, idx0s, idx1s, xsSec)
naiveRows = MouseStates(string({MouseStates.Group})' == "Naive");
transferRows = MouseStates(string({MouseStates.Group})' == "Transfer");

naiveHasSetback = arrayfun(@(s) height(s.SessionTable) >= 6 && iHasBehaviorSetback(s.SessionTable.Performance), naiveRows);
naiveN = arrayfun(@(s) height(s.SessionTable), naiveRows);
minNaiveN = min(naiveN(naiveHasSetback), [], 'omitnan');
if ~isfinite(minNaiveN)
	error('Fig341:NoNaiveMouseSetback', 'No Naive mouse reaches criterion with at least 6 sessions and a behavioral setback.');
end

bestNaiveScore = -inf;
bestNaiveMouse = iEmptyMouseState();
bestNaiveCellUID = uint64(0);
bestNaiveSignals = [];
for i = 1:numel(naiveRows)
	st = naiveRows(i);
	if ~naiveHasSetback(i) || height(st.SessionTable) ~= minNaiveN
		continue;
	end
	shiftedNtats = iShiftNtatsToZeroAtTime(st.NTATS, idx0s);
	vals = squeeze(shiftedNtats(:, idx1s, :));
	if isvector(vals)
		vals = reshape(vals, size(shiftedNtats, 1), size(shiftedNtats, 3));
	end
	minVals = min(vals, [], 2);
	peakMask = max(vals, [], 2) > 1;
	minNotAtFirstMask = ~iMinOccursAtSession(vals, 1);
	minNotAtSixMask = ~iMinOccursAtSession(vals, 6);
	candidateMask = peakMask & minNotAtFirstMask & minNotAtSixMask;
	if ~any(candidateMask)
		continue;
	end
	minVals(~candidateMask) = inf;
	[cScore, cIdx] = min(minVals);
	if isfinite(cScore) && (bestNaiveCellUID == 0 || cScore < bestNaiveScore)
		bestNaiveScore = cScore;
		bestNaiveMouse = st;
		bestNaiveCellUID = st.CellUID(cIdx);
		bestNaiveSignals = squeeze(shiftedNtats(cIdx, :, :))';
	end
end

transferIsIncreasing = arrayfun(@(s) height(s.SessionTable) >= 3 && iIsStrictlyIncreasing(s.SessionTable.Performance), transferRows);
transferN = arrayfun(@(s) height(s.SessionTable), transferRows);
minTransferN = min(transferN(transferIsIncreasing), [], 'omitnan');
if ~isfinite(minTransferN)
	error('Fig341:NoTransferMouseIncreasing', 'No Transfer mouse reaches criterion with at least 3 sessions and strictly increasing behavior.');
end

bestTransferScore = -inf;
bestTransferMouse = iEmptyMouseState();
bestTransferCellUID = uint64(0);
bestTransferSignals = [];
for i = 1:numel(transferRows)
	st = transferRows(i);
	if ~transferIsIncreasing(i) || height(st.SessionTable) ~= minTransferN
		continue;
	end
	shiftedNtats = iShiftNtatsToZeroAtTime(st.NTATS, idx0s);
	vals = squeeze(shiftedNtats(:, idx1s, :));
	if isvector(vals)
		vals = reshape(vals, size(shiftedNtats, 1), size(shiftedNtats, 3));
	end
	monoMask = all(diff(vals, 1, 2) > 0, 2);
	if ~any(monoMask)
		continue;
	end
	inc = vals(:, end) - vals(:, 1);
	inc(~monoMask) = -inf;
	[cScore, cIdx] = max(inc);
	if isfinite(cScore) && cScore > bestTransferScore
		bestTransferScore = cScore;
		bestTransferMouse = st;
		bestTransferCellUID = st.CellUID(cIdx);
		bestTransferSignals = squeeze(shiftedNtats(cIdx, :, :))';
	end
end

if bestNaiveCellUID == 0 || bestTransferCellUID == 0
	error('Fig341:NoRepresentative', 'Cannot find representative Naive/Transfer cell pair for panel A.');
end

Rep = struct();
Rep.NaiveCell = struct('Mouse', bestNaiveMouse.Mouse, 'Source', bestNaiveMouse.Source, 'CellUID', bestNaiveCellUID, ...
	'SessionTable', bestNaiveMouse.SessionTable, 'Signals', bestNaiveSignals, 'Points', bestNaiveMouse.Points, 'Explained', bestNaiveMouse.Explained);
Rep.TransferCell = struct('Mouse', bestTransferMouse.Mouse, 'Source', bestTransferMouse.Source, 'CellUID', bestTransferCellUID, ...
	'SessionTable', bestTransferMouse.SessionTable, 'Signals', bestTransferSignals, 'Points', bestTransferMouse.Points, 'Explained', bestTransferMouse.Explained);
Rep.XsSec = xsSec;
end

function ph = iPickSessionPhase(phases)
phases = string(phases);
phases = phases(~ismissing(phases) & phases ~= "");
if isempty(phases)
	ph = "";
	return;
end
[u, ~, ic] = unique(phases);
counts = accumarray(ic, 1);
[~, ix] = max(counts);
ph = u(ix);
end

function dt = iNormalizeDateTime(dt)
dt = datetime(dt);
if isdatetime(dt) && ~isempty(dt.TimeZone)
	dt.TimeZone = '';
end
end

function [idx, ok] = iFindTimeIndex(xsSec, targetSec, tolSec)
[d, idx] = min(abs(xsSec - targetSec));
ok = isfinite(d) && d <= tolSec;
end

function tf = iHasBehaviorSetback(performance)
perf = double(performance(:));
perf = perf(isfinite(perf));
tf = numel(perf) >= 2 && any(diff(perf) < 0);
end

function XShift = iShiftNtatsToZeroAtTime(X, idx0s)
XShift = X;
if isempty(X) || idx0s < 1 || idx0s > size(X, 2)
	return;
end
baseline = X(:, idx0s, :);
XShift = X - baseline;
end

function tf = iMinOccursAtSession(vals, sessionIndex)
if isempty(vals) || size(vals, 2) < sessionIndex
	tf = false(size(vals, 1), 1);
	return;
end
minVals = min(vals, [], 2);
tol = 1e-9;
tf = abs(vals(:, sessionIndex) - minVals) <= tol;
end

function tf = iIsStrictlyIncreasing(values)
vals = double(values(:));
if numel(vals) < 2 || any(~isfinite(vals))
	tf = false;
	return;
end
tf = all(diff(vals) > 0);
end

function row = iEmptyMetricRow()
row = builtin('struct', 'Mouse', "", 'Group', "", 'Source', "", 'ZLayer', "", 'NSession', NaN, ...
	'PathLength', NaN, 'DirectLength', NaN, 'PathOverDirect', NaN, 'AverageStep', NaN, 'EffectiveStep', NaN, ...
	'Points', {zeros(0, 2)}, 'Explained', {nan(1, 2)});
end

function st = iEmptyMouseState()
st = builtin('struct', 'Mouse', "", 'Group', "", 'Source', "", 'SessionTable', table(), 'CellUID', uint64([]), ...
	'Layers', strings(0,1), 'NTATS', zeros(0, 0, 0), 'Points', zeros(0, 2), 'Explained', nan(1, 2));
end

function iAssertNoCrossSourceDuplicateMice(T, groupName)
if isempty(T)
	return;
end
U = unique(T(:, {'Mouse', 'Source'}));
[~, ~, g] = unique(U.Mouse);
nSrc = splitapply(@(x) numel(unique(x)), U.Source, g);
if any(nSrc > 1)
	error('Fig341:DuplicateMouseAcrossSources', 'Group %s has duplicated mice across sources.', char(string(groupName)));
end
end

function iAssertNoMouseAppearsInMultipleGroups(T)
if isempty(T)
	return;
end
[~, ~, g] = unique(T.Mouse);
nGrp = splitapply(@(x) numel(unique(x)), T.Group, g);
if any(nGrp > 1)
	error('Fig341:MouseInMultipleGroups', 'Some mice appear in multiple groups.');
end
end