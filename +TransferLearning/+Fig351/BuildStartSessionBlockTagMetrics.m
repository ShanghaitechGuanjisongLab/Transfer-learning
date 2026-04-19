function Sess = BuildStartSessionBlockTagMetrics()
initialLAB = iBuildStartSessionsForDataset(TransferLearning.LightAudioBaseline(), "Naive", "LightWater", "Naive", "LightAudioBaseline", strings(0,1));
badNaive = iFindMiceWithAudioWaterInPhase(TransferLearning.LAInterspersed(), "Naive");
initialLAI = iBuildStartSessionsForDataset(TransferLearning.LAInterspersed(), "Naive", "LightWater", "Naive", "LAInterspersed", badNaive);
transferALB = iBuildStartSessionsForDataset(TransferLearning.AudioLightBaseline(), "Transfer", "LightWater", "Transfer", "AudioLightBaseline", strings(0,1));
Sess = [initialLAB; initialLAI; transferALB];
Sess = sortrows(Sess, {'Group','Mouse','DateTime'});
end

function Sess = iBuildStartSessionsForDataset(DS, PhaseName, StimulusName, GroupName, SourceName, ExcludeMice)
Q = DS.TableQuery(["Mouse","DateTime","BlockUID"], Phase=char(PhaseName), Stimulus=char(StimulusName));
if isempty(Q)
	Sess = table;
	return;
end
Q.Mouse = string(Q.Mouse);
Q.DateTime = TransferLearning.Fig35.iNormalizeDateTime(Q.DateTime);
Q = unique(Q(:, {'Mouse','DateTime','BlockUID'}), 'rows');
if ~isempty(ExcludeMice)
	Q = Q(~ismember(Q.Mouse, ExcludeMice), :);
end
firstRows = splitapply(@(dt) {min(dt)}, Q.DateTime, findgroups(Q.Mouse));
firstDt = vertcat(firstRows{:});
mouseList = unique(Q.Mouse, 'stable');
keep = ismember(Q.DateTime, firstDt) & ismember(Q.Mouse, mouseList);
Q = Q(keep, :);
[G, mice, dts] = findgroups(Q.Mouse, Q.DateTime);
blockCells = splitapply(@(x) {x}, uint64(Q.BlockUID), G);
DT = DS.DateTimes(:, {'DateTime','SeriesInterval'});
DT.DateTime = TransferLearning.Fig35.iNormalizeDateTime(DT.DateTime);
DT = unique(DT, 'rows', 'stable');
seriesCell = arrayfun(@(dt) DT.SeriesInterval(find(DT.DateTime == dt, 1, 'first')), dts, 'UniformOutput', false);
seriesInterval = vertcat(seriesCell{:});
SessionDurationSec = nan(numel(blockCells), 1);
SessionLickSec = nan(numel(blockCells), 1);
SessionLickFraction = nan(numel(blockCells), 1);
RepGapSec = nan(numel(blockCells), 1);
RepIntervalLickSec = nan(numel(blockCells), 1);
CD1State = cell(numel(blockCells), 1);
CD2State = cell(numel(blockCells), 1);
RepPeak1Index = nan(numel(blockCells), 1);
RepPeak2Index = nan(numel(blockCells), 1);
for i = 1:numel(blockCells)
	M = iSessionBlockTagMetrics(DS, blockCells{i}, seconds(seriesInterval(i)));
	SessionDurationSec(i) = M.SessionDurationSec;
	SessionLickSec(i) = M.SessionLickSec;
	SessionLickFraction(i) = M.SessionLickFraction;
	RepGapSec(i) = M.RepGapSec;
	RepIntervalLickSec(i) = M.RepIntervalLickSec;
	CD1State{i} = M.CD1State;
	CD2State{i} = M.CD2State;
	RepPeak1Index(i) = M.RepPeak1Index;
	RepPeak2Index(i) = M.RepPeak2Index;
end
Sess = table(mice, repmat(GroupName, numel(mice), 1), repmat(SourceName, numel(mice), 1), dts, seconds(seriesInterval), SessionDurationSec, SessionLickSec, SessionLickFraction, RepGapSec, RepIntervalLickSec, CD1State, CD2State, RepPeak1Index, RepPeak2Index, ...
	'VariableNames', {'Mouse','Group','Source','DateTime','SeriesIntervalSec','SessionDurationSec','SessionLickSec','SessionLickFraction','RepGapSec','RepIntervalLickSec','CD1State','CD2State','RepPeak1Index','RepPeak2Index'});
end

function M = iSessionBlockTagMetrics(DS, BlockUIDs, SeriesIntervalSec)
blockUIDs = uint64(BlockUIDs(:));
allCd1 = [];
allCd2 = [];
for bu = blockUIDs.'
	ix = find(uint64(DS.Blocks.BlockUID) == bu, 1, 'first');
	if isempty(ix)
		continue;
	end
	bt = DS.Blocks.BlockTags{ix};
	allCd1 = [allCd1; double(bt.CD1(:))]; %#ok<AGROW>
	allCd2 = [allCd2; double(bt.CD2(:))]; %#ok<AGROW>
end
cd1State = iLogicalChannelState(allCd1);
cd2State = iLogicalChannelState(allCd2);
starts = find(diff([false; cd1State]) > 0);
if numel(starts) >= 2
	[gaps, ix] = max(diff(starts) * SeriesIntervalSec);
	p1 = starts(ix);
	p2 = starts(ix + 1);
	repGapSec = gaps;
	repIntervalLickSec = sum(cd2State(p1:p2-1)) * SeriesIntervalSec;
else
	p1 = 1;
	p2 = max(2, numel(cd1State));
	repGapSec = (p2 - p1) * SeriesIntervalSec;
	repIntervalLickSec = sum(cd2State(max(1, p1):max(1, p2-1))) * SeriesIntervalSec;
end
M = builtin('struct', ...
	'SessionDurationSec', numel(cd2State) * SeriesIntervalSec, ...
	'SessionLickSec', sum(cd2State) * SeriesIntervalSec, ...
	'SessionLickFraction', sum(cd2State) / max(numel(cd2State), 1), ...
	'RepGapSec', repGapSec, ...
	'RepIntervalLickSec', repIntervalLickSec, ...
	'CD1State', cd1State, ...
	'CD2State', cd2State, ...
	'RepPeak1Index', p1, ...
	'RepPeak2Index', p2);
end

function state = iLogicalChannelState(x)
x = double(x(:));
if isempty(x)
	state = false(0,1);
	return;
end
lo = quantile(x, 0.1);
hi = quantile(x, 0.9);
thr = (lo + hi) / 2;
state = x > thr;
end

function badMice = iFindMiceWithAudioWaterInPhase(DS, PhaseName)
T = DS.TableQuery(["Mouse","BlockUID"], Phase=char(PhaseName));
if isempty(T)
	badMice = strings(0,1);
	return;
end
Tr = DS.Trials;
TrStim = string(Tr.Stimulus);
TrBU = uint64(Tr.BlockUID);
T.Mouse = string(T.Mouse);
blkBU = uint64(T.BlockUID);
mice = unique(T.Mouse);
bad = false(size(mice));
for i = 1:numel(mice)
	bu = blkBU(T.Mouse == mice(i));
	rows = ismember(TrBU, bu);
	bad(i) = any(TrStim(rows) == "AudioWater");
end
badMice = mice(bad);
end