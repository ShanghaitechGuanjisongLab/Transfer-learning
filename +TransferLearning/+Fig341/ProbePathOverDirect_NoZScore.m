function Result = ProbePathOverDirect_NoZScore()
xs = TransferLearning.Xs;
if isduration(xs)
	xsSec = seconds(xs);
else
	xsSec = double(xs);
end
[~, idx1s] = min(abs(xsSec - 1));

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

metricRows = repmat(struct('Mouse', "", 'Group', "", 'Source', "", 'ZLayer', "", 'NSession', 0, 'PathOverDirect', NaN), 0, 1);
for iSpec = 1:numel(Specs)
	DS = Specs(iSpec).DS;
	Ssrc = allSessions(allSessions.Source == Specs(iSpec).Source, :);
	mice = unique(Ssrc.Mouse);
	for iMouse = 1:numel(mice)
		Sm = Ssrc(Ssrc.Mouse == mice(iMouse), :);
		if height(Sm) < 2
			continue;
		end
		[R, SmKeep] = iQueryMouseNtats(DS, Sm, UniExp.Flags.No_special_operation);
		if height(SmKeep) < 2 || isempty(R) || height(R) < 2
			continue;
		end
		X = iNtatsTo3D(R.NTATS);
		if isempty(X) || size(X, 3) ~= height(SmKeep)
			continue;
		end
		layers = iLookupLayers(DS, uint64(R.CellUID));
		for zLayer = ["MOp2/3", "MOp5"]
			mask = layers == zLayer;
			if nnz(mask) < 2
				continue;
			end
			points = iSessionPointsFromNtats(X(mask, :, :), idx1s);
			if size(points, 1) ~= height(SmKeep)
				continue;
			end
			dp = diff(points, 1, 1);
			pathLen = sum(sqrt(sum(dp.^2, 2)), 'omitnan');
			directLen = sqrt(sum((points(end, :) - points(1, :)).^2, 2));
			if ~(isfinite(pathLen) && isfinite(directLen) && directLen > 0)
				continue;
			end
			row = struct('Mouse', string(mice(iMouse)), 'Group', Specs(iSpec).Group, 'Source', Specs(iSpec).Source, ...
				'ZLayer', zLayer, 'NSession', height(SmKeep), 'PathOverDirect', pathLen / directLen);
			metricRows(end + 1) = row; %#ok<AGROW>
		end
	end
	end

Metrics = struct2table(metricRows);
Summary = table();
for zLayer = ["MOp2/3", "MOp5"]
	Tz = Metrics(Metrics.ZLayer == zLayer, :);
	naiveVals = double(Tz.PathOverDirect(Tz.Group == "Naive"));
	tranVals = double(Tz.PathOverDirect(Tz.Group == "Transfer"));
	row = table(zLayer, numel(naiveVals), mean(naiveVals), numel(tranVals), mean(tranVals), ranksum(naiveVals, tranVals), ...
		'VariableNames', {'ZLayer','NaiveN','NaiveMean','TransferN','TransferMean','PValue'});
	Summary = [Summary; row]; %#ok<AGROW>
end

Result = struct();
Result.Sessions = allSessions;
Result.Metrics = Metrics;
Result.Summary = Summary;
end

function Sess = iBuildLearningSessionsForSource(spec)
T = spec.DS.TableQuery(["Mouse", "DateTime", "Stimulus", "Phase", "Behavior", "Performance"]);
if isempty(T)
	Sess = table(string.empty(0,1), NaT(0,1), nan(0,1), strings(0,1), strings(0,1), strings(0,1), false(0,1), false(0,1), ...
		'VariableNames', {'Mouse','DateTime','Performance','Phase','Group','Source','IsMixedAudio','HasLight'});
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
hasLight = false(nSess, 1);
for gi = 1:nSess
	R = T(G == gi, :);
	hasLight(gi) = any(R.Stimulus == "LightWater");
	if ~hasLight(gi)
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
Sess = table(mouseKeys, dtKeys, perf, phaseVals, repmat(spec.Group, nSess, 1), repmat(spec.Source, nSess, 1), isMixed, hasLight, ...
	'VariableNames', {'Mouse','DateTime','Performance','Phase','Group','Source','IsMixedAudio','HasLight'});
Sess = Sess(Sess.HasLight & isfinite(Sess.Performance), :);
Sess = sortrows(Sess, {'Mouse', 'DateTime'});
Sess = iSelectSessionsBetweenPhases(Sess, spec.StartPhase, spec.EndPhase);
Sess = Sess(~Sess.IsMixedAudio, :);
Sess = iTrimAfterCeilingKeepFirst(Sess);
end

function Sess = iSelectSessionsBetweenPhases(Sess, startPhase, endPhase)
if isempty(Sess)
	return;
end
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
		R = table();
		SessKeep = Sess([],:);
		return;
	end
	parts = cell(height(Q), 1);
	keepMask = false(height(Q), 1);
	for i = 1:height(Q)
		try
			parts{i} = DS.QueryNTATS(Q(i, :), normFlag, 1:24, UniExp.Flags.Median);
			keepMask(i) = true;
		catch MEi
			if MEi.identifier ~= "UniExp:Exception:Empty_group"
				rethrow(MEi);
			end
		end
		end
	raw = parts(keepMask);
	SessKeep = Sess(keepMask, :);
	end
if height(SessKeep) < 2
	R = table();
	return;
end
S = UniExp.NtatsCellStrip(raw);
if isempty(S) || ~istable(S) || ~all(ismember({'CellUID','NTATS'}, string(S.Properties.VariableNames)))
	R = table();
	SessKeep = SessKeep([],:);
	return;
end
X = iNtatsTo3D(S.NTATS);
if isempty(X) || size(X, 3) ~= height(SessKeep)
	R = table();
	SessKeep = SessKeep([],:);
	return;
end
R = table(uint64(S.CellUID), MATLAB.DataTypes.NDTable(X), 'VariableNames', {'CellUID','NTATS'});
end

function X = iNtatsTo3D(nt)
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
X = [];
end

function layers = iLookupLayers(DS, cellUID)
C = DS.Cells(:, intersect(["CellUID", "ZLayer"], string(DS.Cells.Properties.VariableNames), 'stable'));
C.CellUID = uint64(C.CellUID);
C.ZLayer = string(C.ZLayer);
[tf, loc] = ismember(cellUID, C.CellUID);
layers = strings(size(cellUID));
layers(tf) = C.ZLayer(loc(tf));
end

function points = iSessionPointsFromNtats(X, idx1s)
if ndims(X) == 2
	X = reshape(X, size(X, 1), size(X, 2), 1);
end
vals = squeeze(X(:, idx1s, :));
if isa(vals, 'MATLAB.DataTypes.NDTable')
	vals = vals{:,:};
end
if isvector(vals)
	vals = reshape(vals, size(X, 1), size(X, 3));
end
sessionByCell = vals';
validCols = all(isfinite(sessionByCell), 1);
sessionByCell = sessionByCell(:, validCols);
if size(sessionByCell, 2) < 1 || size(sessionByCell, 1) < 2
	points = nan(size(X, 3), 2);
	return;
end
sessionByCell = sessionByCell - mean(sessionByCell, 1, 'omitnan');
[u, s, ~] = svd(sessionByCell, 'econ');
score = u * s;
points = zeros(size(sessionByCell, 1), 2);
points(:, 1:min(2, size(score, 2))) = score(:, 1:min(2, size(score, 2)));
end

function dt = iNormalizeDateTime(dt)
dt = datetime(dt);
if ~isempty(dt.TimeZone)
	dt.TimeZone = '';
end
end

function ph = iPickSessionPhase(phases)
phases = string(phases);
phases = phases(~ismissing(phases) & phases ~= "");
if isempty(phases)
	ph = "";
else
	ph = phases(1);
end
end