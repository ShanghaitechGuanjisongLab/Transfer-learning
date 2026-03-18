function Sess = BuildStartSessionBlockTagMetrics()
Specs = [ ...
	builtin('struct', 'Group', "Naive", 'Source', "LAB", 'DS', TransferLearning.LightAudioBaseline(), 'StartPhase', "Naive", 'EndPhase', "Learned")
	builtin('struct', 'Group', "Naive", 'Source', "LAI", 'DS', TransferLearning.LAInterspersed(), 'StartPhase', "Naive", 'EndPhase', "Learned")
	builtin('struct', 'Group', "Transfer", 'Source', "ALB", 'DS', TransferLearning.AudioLightBaseline(), 'StartPhase', "Transfer", 'EndPhase', "Final")
	builtin('struct', 'Group', "Transfer", 'Source', "ALI", 'DS', TransferLearning.ALInterspersed(), 'StartPhase', "Transfer", 'EndPhase', "Final")
];

SessRows = repmat(iEmptySessionRow(), 0, 1);
for iSpec = 1:numel(Specs)
	S = iBuildSessionsForSource(Specs(iSpec));
	for iRow = 1:height(S)
		M = iBuildOneSessionMetrics(Specs(iSpec).DS, Specs(iSpec).Group, Specs(iSpec).Source, S(iRow, :));
		if ~isempty(M)
			SessRows(end + 1) = M; %#ok<AGROW>
		end
	end
end

if isempty(SessRows)
	error('Fig351:NoSessions', 'No valid start-session BlockTags metrics were built.');
end

Sess = struct2table(SessRows);
Sess = sortrows(Sess, {'Group', 'Mouse', 'DateTime'});
end

function Sess = iBuildSessionsForSource(spec)
T = spec.DS.TableQuery(["Mouse", "DateTime", "Stimulus", "Phase", "Behavior", "BlockUID"]);
if isempty(T)
	Sess = iEmptySessionTable();
	return;
end

T.Mouse = string(T.Mouse);
T.DateTime = iNormalizeDateTime(T.DateTime);
T.Stimulus = string(T.Stimulus);
T.Phase = string(T.Phase);
T.BlockUID = uint64(T.BlockUID);

[G, mouseKeys, dtKeys] = findgroups(T.Mouse, T.DateTime);
nSess = max(G);
	rows = repmat(iEmptySessionStruct(), nSess, 1);
for gi = 1:nSess
	R = T(G == gi, :);
	rows(gi).Mouse = mouseKeys(gi);
	rows(gi).DateTime = dtKeys(gi);
	rows(gi).Phase = iPickSessionPhase(R.Phase);
	rows(gi).HasLight = any(R.Stimulus == "LightWater");
	rows(gi).IsMixedAudio = any(R.Stimulus == "AudioWater") && any(R.Stimulus == "LightWater");
	rows(gi).IsPureLight = all(R.Stimulus == "LightWater");
	rows(gi).Performance = mean(double(R.Behavior(R.Stimulus == "LightWater")), 'omitnan');
	rows(gi).BlockUID = {unique(R.BlockUID, 'stable')};
end

Sess = struct2table(rows);
Sess = Sess(Sess.HasLight & Sess.IsPureLight & isfinite(Sess.Performance), :);
Sess = sortrows(Sess, {'Mouse', 'DateTime'});
Sess = iSelectSessionsBetweenPhases(Sess, spec.StartPhase, spec.EndPhase);
Sess = iTrimAfterCeilingKeepFirst(Sess);

mice = unique(Sess.Mouse);
keep = false(height(Sess), 1);
for iMouse = 1:numel(mice)
	idx = find(Sess.Mouse == mice(iMouse), 1, 'first');
	if ~isempty(idx)
		keep(idx) = true;
	end
end
Sess = Sess(keep, :);
end

function row = iBuildOneSessionMetrics(DS, groupName, sourceName, S)
row = [];

B = DS.Blocks;
B.BlockUID = uint64(B.BlockUID);
B.DateTime = iNormalizeDateTime(B.DateTime);
	if ~ismember('BlockTags', B.Properties.VariableNames)
	return;
	end
	if ~ismember('BlockIndex', B.Properties.VariableNames)
	return;
	end

idxB = ismember(B.BlockUID, S.BlockUID{1}) & B.DateTime == S.DateTime;
	if ~any(idxB)
	return;
	end
	B = sortrows(B(idxB, :), 'BlockIndex');
	validTags = cellfun(@(x) istable(x) && all(ismember({'CD1', 'CD2'}, x.Properties.VariableNames)), B.BlockTags);
	if ~all(validTags)
	return;
	end

	DT = DS.DateTimes;
	DT.DateTime = iNormalizeDateTime(DT.DateTime);
	DT.Mouse = string(DT.Mouse);
	idxDT = find(DT.DateTime == S.DateTime & DT.Mouse == S.Mouse, 1, 'first');
	if isempty(idxDT)
		return;
	end
	siSec = seconds(DT.SeriesInterval(idxDT));
	if ~(isfinite(siSec) && siSec > 0)
		return;
	end

	cd1Cell = cellfun(@(x) double(x.CD1(:)), B.BlockTags, 'UniformOutput', false);
	cd2Cell = cellfun(@(x) double(x.CD2(:)), B.BlockTags, 'UniformOutput', false);
	cd1 = vertcat(cd1Cell{:});
	cd2 = vertcat(cd2Cell{:});
	if isempty(cd1) || isempty(cd2) || numel(cd1) ~= numel(cd2)
		return;
	end

	thr1 = mean(cd1, 'omitnan') + std(cd1, 0, 'omitnan');
	thr2 = mean(cd2, 'omitnan') + std(cd2, 0, 'omitnan');
	st1 = cd1 > thr1;
	st2 = cd2 > thr2;
	peaks = iSegmentPeaks(st1, cd1);
	if numel(peaks) < 2
		return;
	end

	firstPeak = peaks(1);
	lastPeak = peaks(end);
	sessRange = firstPeak:lastPeak;
	sessDurSec = (lastPeak - firstPeak) * siSec;
	lickFrac = mean(double(st2(sessRange)), 'omitnan');
	lickSec = sum(st2(sessRange), 'omitnan') * siSec;

	gapSamples = diff(peaks);
	nPairs = numel(gapSamples);
	winPad = max(1, round(1 / siSec));
	gapSec = gapSamples * siSec;
	lickGapSec = nan(nPairs, 1);
	for iPair = 1:nPairs
		w1 = max(1, peaks(iPair) - winPad);
		w2 = min(numel(st2), peaks(iPair + 1) + winPad);
		lickGapSec(iPair) = sum(st2(w1:w2), 'omitnan') * siSec;
	end
	best = find(gapSec == max(gapSec), 1, 'first');
	bestTie = find(gapSec == gapSec(best));
	if numel(bestTie) > 1
		[~, tieIdx] = max(lickGapSec(bestTie));
		best = bestTie(tieIdx);
	end

	row = iEmptySessionRow();
	row.Mouse = S.Mouse;
	row.Group = groupName;
	row.Source = sourceName;
	row.DateTime = S.DateTime;
	row.Performance = S.Performance;
	row.SeriesIntervalSec = siSec;
	row.CD1Raw = {cd1};
	row.CD2Raw = {cd2};
	row.CD1State = {st1};
	row.CD2State = {st2};
	row.CD1Threshold = thr1;
	row.CD2Threshold = thr2;
	row.PeakIndex = {peaks(:)};
	row.FirstPeakIndex = firstPeak;
	row.LastPeakIndex = lastPeak;
	row.SessionDurationSec = sessDurSec;
	row.SessionLickFraction = lickFrac;
	row.SessionLickSec = lickSec;
	row.RepPairIndex = best;
	row.RepPeak1Index = peaks(best);
	row.RepPeak2Index = peaks(best + 1);
	row.RepGapSec = gapSec(best);
	row.RepIntervalLickSec = lickGapSec(best);
end

function peaks = iSegmentPeaks(state, signal)
state = logical(state(:));
signal = double(signal(:));
d = diff([false; state; false]);
segStart = find(d == 1);
segEnd = find(d == -1) - 1;
peaks = nan(numel(segStart), 1);
for iSeg = 1:numel(segStart)
	seg = segStart(iSeg):segEnd(iSeg);
	[~, loc] = max(signal(seg));
	peaks(iSeg) = seg(loc);
end
peaks = peaks(isfinite(peaks));
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

function T = iEmptySessionTable()
T = struct2table(repmat(iEmptySessionStruct(), 0, 1));
end

function S = iEmptySessionStruct()
S = struct(...
	'Mouse', "", ...
	'DateTime', NaT, ...
	'Phase', "", ...
	'HasLight', false, ...
	'IsMixedAudio', false, ...
	'IsPureLight', false, ...
	'Performance', NaN, ...
	'BlockUID', {uint64.empty(0, 1)});
end

function row = iEmptySessionRow()
row = struct(...
	'Mouse', "", ...
	'Group', "", ...
	'Source', "", ...
	'DateTime', NaT, ...
	'Performance', NaN, ...
	'SeriesIntervalSec', NaN, ...
	'CD1Raw', {{}}, ...
	'CD2Raw', {{}}, ...
	'CD1State', {{}}, ...
	'CD2State', {{}}, ...
	'CD1Threshold', NaN, ...
	'CD2Threshold', NaN, ...
	'PeakIndex', {{}}, ...
	'FirstPeakIndex', NaN, ...
	'LastPeakIndex', NaN, ...
	'SessionDurationSec', NaN, ...
	'SessionLickFraction', NaN, ...
	'SessionLickSec', NaN, ...
	'RepPairIndex', NaN, ...
	'RepPeak1Index', NaN, ...
	'RepPeak2Index', NaN, ...
	'RepGapSec', NaN, ...
	'RepIntervalLickSec', NaN);
end