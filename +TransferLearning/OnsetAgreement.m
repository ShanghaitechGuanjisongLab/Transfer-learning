function R = OnsetAgreement(RA, RB, Options)
% OnsetAgreement  比较两个EarlyOnsetCells结果中细胞的early-onset判定是否一致。
%
% 用于两类比较：
%   1. 训练模态 vs 转移模态（由TransferOnsetCells调用）；
%   2. 同一模态的会话对半拆分后的自身一致性（作为"内在潜伏期稳定性"的上界对照）。
%
% 对齐方式(Options.AlignBy)：
%   "session" — 按(Mouse, Session, CellUID)对齐；
%   "cell"    — 按(Mouse, CellUID)跨会话聚合：movement-active比例>=0.5记为活跃，
%               onset取各会话中位数，early判定要求过半会话为early且中位onset<0。
%
% 输出R.Stats含列联表计数、超几何p、onset差与Spearman相关、cue锁定轨迹相关。

arguments
	RA
	RB
	Options.AlignBy (1,1) string {mustBeMember(Options.AlignBy, ["session", "cell"])} = "session"
end

SA = iSummarize(RA, Options.AlignBy);
SB = iSummarize(RB, Options.AlignBy);

[matched, locB] = ismember(SA.Key, SB.Key);
A = SA(matched, :);
B = SB(locB(matched), :);

earlyA = A.Early;
activeA = A.Active;
earlyB = B.Early;
activeB = B.Active;
bothActive = activeA & activeB;

nBothActive = sum(bothActive);
nTrainedEarly = sum(earlyA & bothActive);
nTrainedEarlyAndTransferEarly = sum(earlyA & bothActive & earlyB);
nTrainedNotEarly = sum(bothActive & ~earlyA);
nTrainedNotEarlyAndTransferEarly = sum(bothActive & ~earlyA & earlyB);

if nTrainedEarly > 0 && nTrainedNotEarly > 0
	pOverlap = 1 - hygecdf(nTrainedEarlyAndTransferEarly - 1, nBothActive, sum(earlyB & bothActive), nTrainedEarly);
else
	pOverlap = NaN;
end

Stats = struct();
Stats.AlignBy = Options.AlignBy;
Stats.NMatched = height(A);
Stats.NActiveBoth = nBothActive;
Stats.NActiveTrained = sum(activeA);
Stats.NActiveTransfer = sum(activeB);
Stats.NEarlyTrained = sum(earlyA);
Stats.NEarlyTransfer = sum(earlyB);
Stats.EarlyAgreement = sum(earlyA & earlyB);
Stats.NTrainedEarly = nTrainedEarly;
Stats.NTrainedEarlyTransferEarly = nTrainedEarlyAndTransferEarly;
Stats.NTrainedNotEarly = nTrainedNotEarly;
Stats.NTrainedNotEarlyTransferEarly = nTrainedNotEarlyAndTransferEarly;
Stats.POverlap = pOverlap;
Stats.FracTransferEarlyGivenTrainedEarly = nTrainedEarlyAndTransferEarly / max(nTrainedEarly, 1);
Stats.FracTransferEarlyGivenTrainedNotEarly = nTrainedNotEarlyAndTransferEarly / max(nTrainedNotEarly, 1);
Stats.BaseRateTransferEarly = sum(earlyB & bothActive) / max(nBothActive, 1);

hasBoth = ~isnan(A.Onset) & ~isnan(B.Onset) & bothActive;
Stats.NOnsetPaired = sum(hasBoth);
Stats.MedianOnsetTrained = median(A.Onset(hasBoth));
Stats.MedianOnsetTransfer = median(B.Onset(hasBoth));
Stats.MedianOnsetShift = median(B.Onset(hasBoth) - A.Onset(hasBoth));
Stats.OnsetSpearman = corr(A.Onset(hasBoth), B.Onset(hasBoth), 'Type', 'Spearman');

traceA = A.CueTrace;
traceB = B.CueTrace;
perCellR = nan(height(traceA), 1);
validTrace = all(isfinite(traceA), 2) & all(isfinite(traceB), 2);
for iCell = 1:height(traceA)
	if validTrace(iCell)
		c = corrcoef(traceA(iCell, :), traceB(iCell, :));
		perCellR(iCell) = c(1, 2);
	end
end
Stats.MedianCueTraceR = median(perCellR(validTrace & bothActive));
Stats.PopulationCueTraceR = corr(mean(traceA(bothActive, :), 1).', mean(traceB(bothActive, :), 1).');

% 文献口径的群体模式相关：每个细胞取线索后0~1 s的平均响应，再跨细胞求相关
neuroTime = double(seconds(TransferLearning.Xs(:).'));
responseWindow = neuroTime >= 0 & neuroTime <= 1;
responseA = mean(traceA(:, responseWindow), 2);
responseB = mean(traceB(:, responseWindow), 2);
responseValid = bothActive & isfinite(responseA) & isfinite(responseB);
Stats.NResponsePaired = sum(responseValid);
Stats.MeanResponseCorrelation = corr(responseA(responseValid), responseB(responseValid));
Stats.MeanResponseCorrelationPerCell = perCellR;

% 细胞身份打乱后的零分布（floor）
shuffleStream = RandStream('Threefry', 'Seed', 42);
shuffleR = zeros(1000, 1);
for iShuffle = 1:1000
	permuted = responseB(responseValid);
	permuted = permuted(randperm(shuffleStream, numel(permuted)));
	shuffleR(iShuffle) = corr(responseA(responseValid), permuted);
end
Stats.MeanResponseCorrelationNull = median(shuffleR);

% 鼠内分层置换检验：在每只鼠内部打乱"第一条件early"标签，保持每鼠数量不变
earlyAFiltered = earlyA(bothActive);
earlyBFiltered = earlyB(bothActive);
mouseFiltered = A.Mouse(bothActive);
[mouseGroup, mouseNames] = findgroups(string(mouseFiltered));
nPermutation = 5000;
permutationNull = zeros(1, nPermutation);
for iMouse = 1:numel(mouseNames)
	idx = find(mouseGroup == iMouse);
	labels = earlyAFiltered(idx);
	targets = earlyBFiltered(idx);
	randomMatrix = rand(shuffleStream, numel(idx), nPermutation);
	[~, order] = sort(randomMatrix, 1);
	permutationNull = permutationNull + sum(labels(order) & targets, 1);
end
observedOverlap = sum(earlyAFiltered & earlyBFiltered);
Stats.MousePermP = (sum(permutationNull >= observedOverlap) + 1) / (nPermutation + 1);
Stats.MousePermExpected = mean(permutationNull);
Stats.NMouse = numel(mouseNames);
Stats.NMouseWithEarly = sum(splitapply(@sum, double(earlyAFiltered), mouseGroup) > 0);
Stats.EnrichmentRatio = Stats.FracTransferEarlyGivenTrainedEarly / Stats.FracTransferEarlyGivenTrainedNotEarly;

Cells = table(A.Mouse, A.Session, A.CellUID, A.CellIndex, A.NSession, A.Active, A.Onset, A.Early, ...
	B.NSession, B.Active, B.Onset, B.Early, bothActive, perCellR, ...
	'VariableNames', {'Mouse', 'Session', 'CellUID', 'CellIndex', ...
	'NSessionFirst', 'ActiveFirst', 'FirstOnset', 'FirstEarly', ...
	'NSessionSecond', 'ActiveSecond', 'SecondOnset', 'SecondEarly', 'ActiveBoth', 'CueTraceR'});

R.Cells = Cells;
R.Stats = Stats;
end

function S = iSummarize(R, alignBy)
C = R.Cells;
active = C.Class == "movement-active";
switch alignBy
	case "session"
		S = table(string(C.Mouse) + "|" + string(C.Session) + "|" + string(C.CellUID), ...
			C.Mouse, C.Session, C.CellUID, C.CellIndex, ones(height(C), 1), ...
			active, C.Onset, C.IsEarlyOnset, R.CueTraces, ...
			'VariableNames', {'Key', 'Mouse', 'Session', 'CellUID', 'CellIndex', 'NSession', ...
			'Active', 'Onset', 'Early', 'CueTrace'});
	case "cell"
		[key, ~, group] = unique(string(C.Mouse) + "|" + string(C.CellUID));
		nGroup = numel(key);
		mouse = strings(nGroup, 1);
		cellUID = zeros(nGroup, 1, 'uint64');
		activeFlag = false(nGroup, 1);
		onset = nan(nGroup, 1);
		earlyFlag = false(nGroup, 1);
		nSession = zeros(nGroup, 1);
		trace = zeros(nGroup, size(R.CueTraces, 2));
		for iGroup = 1:nGroup
			rows = group == iGroup;
			first = find(rows, 1);
			mouse(iGroup) = C.Mouse(first);
			cellUID(iGroup) = C.CellUID(first);
			nSession(iGroup) = sum(rows);
			activeFlag(iGroup) = mean(active(rows)) >= 0.5;
			onset(iGroup) = median(C.Onset(rows), 'omitnan');
			earlyFlag(iGroup) = mean(C.IsEarlyOnset(rows)) >= 0.5 && onset(iGroup) < 0;
			trace(iGroup, :) = mean(R.CueTraces(rows, :), 1, 'omitnan');
		end
		S = table(key, mouse, NaT(nGroup, 1), cellUID, ones(nGroup, 1), nSession, ...
			activeFlag, onset, earlyFlag, trace, ...
			'VariableNames', {'Key', 'Mouse', 'Session', 'CellUID', 'CellIndex', 'NSession', ...
			'Active', 'Onset', 'Early', 'CueTrace'});
end
S = S(:, ["Key", "Mouse", "Session", "CellUID", "CellIndex", "NSession", "Active", "Onset", "Early", "CueTrace"]);
end
