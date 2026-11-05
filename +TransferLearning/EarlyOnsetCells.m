function R = EarlyOnsetCells(DS, Options)
% EarlyOnsetCells  按文献定义在指定刺激条件下标定运动相关细胞并估计其活动起始时刻。
%
% 文献定义(Peters et al. 2014 / Chen et al. 2026)：
%   1. 运动相关细胞：把二值化运动序列与细胞信号逐点相乘求和，与打乱运动时段
%      得到的零分布比较，高于95百分位为 movement-active，低于5百分位为
%      movement-suppressed，其余为 non-movement-related。
%   2. 活动起始时刻：以运动起始为0，取[-0.2 s, 运动结束]内首个高于基线
%      (运动起始前1~0.5 s均值)超过1个标准差并维持200 ms的帧。
%   3. onset<0为 early-onset，onset>0为 late-onset。
%
% 本函数与文献的对应改动(本实验室任务为线索触发舔舐，无杠杆轨迹)：
%   - 二值化运动序列取自CD2标通道(LickTrace)，运动起始取线索后首次超阈值时刻；
%   - 无"高刻板性"筛选(需连续位移轨迹)，改用"已学会阶段的命中试次"作为学会运动；
%   - 神经信号为8 Hz(125 ms)，文献为10 Hz，故onset分辨率为1帧量级。
%   - 只保留RT在[MinRT, MaxRT]内的试次，使基线窗[-1 -0.5] s完全落在线索之前。
%
% 输出R为struct：
%   Cells   每个细胞一行的table，含Class/Score/Percentile/Onset/IsEarlyOnset等
%   Traces  运动起始对齐的平均z分数轨迹(nCell x nGrid)
%   Grid    轨迹时间轴(秒，相对运动起始)
%   TagTime 标通道时间轴(秒，相对线索onset)
%   CueTraces 线索锁定的平均z分数轨迹(nCell x nNeuro)

arguments
	DS
	Options.Stimulus (1,1) string
	Options.Designs (1,:) string = strings(1, 0)
	Options.Sessions (:,1) datetime = NaT(0, 1)
	Options.ExcludePhases (1,:) string = "Naive"
	Options.MinRT (1,1) double = 0.10
	Options.MaxRT (1,1) double = 0.50
	Options.MovementOnset (1,1) string {mustBeMember(Options.MovementOnset, ["lick", "outcome"])} = "lick"
	Options.NShuffle (1,1) double = 1000
	Options.Seed (1,1) double = 42
	Options.ActivePercentile (1,1) double = 95
	Options.SuppressedPercentile (1,1) double = 5
	Options.BaselineWindow (1,2) double = [-1, -0.5]
	Options.OnsetSearchWindow (1,2) double = [-0.2, 1.0]
	Options.SustainDuration (1,1) double = 0.2
	Options.GridStep (1,1) double = 0.025
	Options.MinTrialsPerSession (1,1) double = 8
	Options.TrialFraction (1,1) double = 1
	Options.TrialSeed (1,1) double = 1
end

Timing = TransferLearning.BuildTrialTiming(DS);

hasTags = cellfun(@(t) isa(t, 'table') && height(t) == numel(TransferLearning.Xs), DS.Trials.ResampledTags);
selected = Timing.Stimulus == Options.Stimulus & ~ismember(Timing.Phase, Options.ExcludePhases) & hasTags;
if ~isempty(Options.Designs)
	selected = selected & ismember(Timing.Design, Options.Designs);
end
if ~isempty(Options.Sessions)
	selected = selected & ismember(Timing.DateTime, Options.Sessions);
end
selectedTrials = find(selected);

% 按会话随机抽取一部分试次，用于估计同条件下的重测一致性上界
if Options.TrialFraction < 1
	subsampleStream = RandStream('Threefry', 'Seed', Options.TrialSeed);
	[~, ~, sessionIndex] = unique(Timing.DateTime(selectedTrials));
	keepMask = false(size(selectedTrials));
	for iSession = 1:max(sessionIndex)
		idx = find(sessionIndex == iSession);
		nKeep = max(ceil(numel(idx) * Options.TrialFraction), 1);
		keepMask(idx(randperm(subsampleStream, numel(idx), nKeep))) = true;
	end
	selectedTrials = selectedTrials(keepMask);
end

[Lick, OnsetTime, TagTime] = TransferLearning.LickTrace(DS.Trials.ResampledTags(selectedTrials));

% 延迟范式里线索后最先出现的是等待期的预期性舔舐，不是学会的定时反应。
% 此时改用EventLog的"命中"时刻作为运动起始，并把运动序列截断到该时刻之后。
if Options.MovementOnset == "outcome"
	outcomeOnset = Timing.RT(selectedTrials);
	outcomeOnset(Timing.Outcome(selectedTrials) ~= "命中") = NaN;
	OnsetTime = outcomeOnset;
	for iTrial = 1:numel(selectedTrials)
		if isnan(OnsetTime(iTrial))
			Lick(iTrial, :) = false;
		else
			Lick(iTrial, TagTime < OnsetTime(iTrial) - 0.1) = false;
		end
	end
end

% 只保留确有舔舐、且基线窗能落在线索之前的试次
keep = ~isnan(OnsetTime) & OnsetTime >= Options.MinRT & OnsetTime <= Options.MaxRT;
selectedTrials = selectedTrials(keep);
Lick = Lick(keep, :);
OnsetTime = OnsetTime(keep);

neuroTime = double(seconds(TransferLearning.Xs(:).'));
nNeuro = numel(neuroTime);
nTag = numel(TagTime);
preCue = neuroTime < 0;

grid = Options.BaselineWindow(1):Options.GridStep:Options.OnsetSearchWindow(2);
nGrid = numel(grid);
baseIndex = grid >= Options.BaselineWindow(1) & grid <= Options.BaselineWindow(2);
searchIndex = find(grid >= Options.OnsetSearchWindow(1));

sessions = unique(Timing.DateTime(selectedTrials));

CellUID = uint64.empty(0, 1);
Mouse = strings(0, 1);
Session = NaT(0, 1);
CellIndex = zeros(0, 1);
Class = strings(0, 1);
Score = zeros(0, 1);
Percentile = zeros(0, 1);
Onset = nan(0, 1);
Traces = zeros(0, nGrid);
CueTraces = zeros(0, nNeuro);

stream = RandStream('Threefry', 'Seed', Options.Seed);

trialUIDs = Timing.TrialUID(selectedTrials);
signal = DS.TrialSignals;
signalInSession = ismember(signal.TrialUID, trialUIDs);

for iSession = 1:numel(sessions)
	sessionTrials = find(Timing.DateTime(selectedTrials) == sessions(iSession));
	uids = trialUIDs(sessionTrials);
	nTrial = numel(uids);
	if nTrial < Options.MinTrialsPerSession
		continue;
	end

	rows = signalInSession & ismember(signal.TrialUID, uids);
	if ~any(rows)
		continue;
	end
	cells = unique(signal.CellUID(rows));
	nCell = numel(cells);
	if nCell == 0
		continue;
	end

	[~, trialPos] = ismember(signal.TrialUID(rows), uids);
	[~, cellPos] = ismember(signal.CellUID(rows), cells);
	values = double(signal.ResampledSignal(rows, :));
	linear = sub2ind([nTrial, nCell, nNeuro], ...
		repmat(trialPos, 1, nNeuro), repmat(cellPos, 1, nNeuro), repmat(1:nNeuro, numel(trialPos), 1));
	X = nan(nTrial * nCell * nNeuro, 1);
	X(linear) = values(:);
	X = reshape(X, nTrial, nCell, nNeuro);

	% 以线索前样本做z分数，使不同细胞的量纲可比
	baseline = reshape(X(:, :, preCue), nTrial * nCell, []);
	mu = mean(baseline, 2, 'omitnan');
	sd = std(baseline, 0, 2, 'omitnan');
	sd(sd <= 0 | ~isfinite(sd)) = NaN;
	Z = (X - reshape(mu, nTrial, nCell)) ./ reshape(sd, nTrial, nCell);

	% 把神经信号插值到标通道时间轴，便于与二值化运动序列逐点相乘
	flat = reshape(Z, nTrial * nCell, nNeuro);
	interp = interp1(neuroTime, flat.', TagTime).';
	interp = reshape(interp, nTrial, nCell, nTag);

	% 逐试次计算49个循环偏移lag下的互相关，供打乱检验抽样
	lagCrossCorrelation = zeros(nTag, nCell, nTrial);
	for iTrial = 1:nTrial
		lickMatrix = false(nTag, nTag);
		for iLag = 1:nTag
			lickMatrix(iLag, :) = circshift(Lick(sessionTrials(iTrial), :), iLag - 1);
		end
		trialSignal = reshape(interp(iTrial, :, :), nCell, nTag).';
		trialSignal(~isfinite(trialSignal)) = 0;
		lagCrossCorrelation(:, :, iTrial) = lickMatrix * trialSignal;
	end

	actual = reshape(sum(lagCrossCorrelation(1, :, :), 3), 1, nCell);

	lags = randi(stream, nTag, Options.NShuffle, nTrial);
	null = zeros(Options.NShuffle, nCell);
	for iTrial = 1:nTrial
		null = null + lagCrossCorrelation(lags(:, iTrial), :, iTrial);
	end
	if any(~isfinite(actual))
		actual(~isfinite(actual)) = 0;
	end
	null(~isfinite(null)) = 0;
	percentile = mean(null < actual, 1).' * 100;

	% 运动起始对齐：每个试次把z分数轨迹插值到相对运动起始的时间轴
	aligned = zeros(nGrid, nCell);
	baselinePerTrial = zeros(nTrial, nCell);
	for iTrial = 1:nTrial
		query = grid + OnsetTime(sessionTrials(iTrial));
		trialSignal = reshape(Z(iTrial, :, :), nCell, nNeuro).';
		trialSignal(~isfinite(trialSignal)) = 0;
		projected = interp1(neuroTime, trialSignal, query);
		aligned = aligned + projected;
		baselinePerTrial(iTrial, :) = mean(projected(baseIndex, :), 1);
	end
	aligned = aligned / nTrial;
	threshold = mean(aligned(baseIndex, :), 1) + std(baselinePerTrial, 0, 1);

	onset = nan(nCell, 1);
	for iCell = 1:nCell
		above = aligned(:, iCell) > threshold(iCell);
		if ~isfinite(threshold(iCell))
			continue;
		end
		first = find(above(searchIndex), 1);
		if isempty(first)
			continue;
		end
		first = searchIndex(first);
		holdLength = round(Options.SustainDuration / Options.GridStep);
		lastStart = min(first + holdLength - 1, nGrid);
		if all(above(first:lastStart))
			onset(iCell) = grid(first);
		end
	end

	class = repmat("non-movement-related", nCell, 1);
	class(percentile >= Options.ActivePercentile) = "movement-active";
	class(percentile <= Options.SuppressedPercentile) = "movement-suppressed";

	CellUID = [CellUID; uint64(cells)];
	Mouse = [Mouse; repmat(string(Timing.Mouse(selectedTrials(sessionTrials(1)))), nCell, 1)];
	Session = [Session; repmat(sessions(iSession), nCell, 1)];
	CellIndex = [CellIndex; (1:nCell).'];
	Class = [Class; class];
	Score = [Score; actual(:)];
	Percentile = [Percentile; percentile];
	Onset = [Onset; onset];
	Traces = [Traces; aligned.'];
	CueTraces = [CueTraces; squeeze(mean(Z, 1, 'omitnan'))];
end

IsEarlyOnset = Class == "movement-active" & Onset < 0;

R.Cells = table(CellUID, Mouse, Session, CellIndex, Class, Score, Percentile, Onset, IsEarlyOnset, ...
	'VariableNames', {'CellUID', 'Mouse', 'Session', 'CellIndex', 'Class', 'Score', 'Percentile', 'Onset', 'IsEarlyOnset'});
R.Traces = Traces;
R.CueTraces = CueTraces;
R.Grid = grid;
R.TagTime = TagTime;
R.Options = Options;
R.NTrials = numel(selectedTrials);
end
