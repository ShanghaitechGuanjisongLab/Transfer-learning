function Data = Fig372_ConvergenceInheritanceCache(queryXlsx)
queryXlsx = string(queryXlsx);

persistent Cache
if ~isempty(Cache) && isfield(Cache, 'QueryXlsx') && Cache.QueryXlsx == queryXlsx
	Data = Cache;
	return;
end

MB = TransferLearning.MOpBaseline();
InfoEntro = MB.QueryNTS(UniExp.ReadQueryTable(queryXlsx, '信息熵'), ExtraColumns="TrialRI");

phaseNames = ["LearnedAudio", "TransferLightHit"];
CellStdMedian = struct();
for iP = 1:numel(phaseNames)
	phaseName = phaseNames(iP);
	Table = InfoEntro.(phaseName);
	CellStdMedian.(phaseName) = groupsummary(Table, "CellUID", ["std", "median"], "TrialSignal");
end

Overlap = table();
Overlap(:, ["CellUID", "LearnedSignal", "LearnedStd"]) = CellStdMedian.LearnedAudio(:, ["CellUID", "median_TrialSignal", "std_TrialSignal"]);
Overlap = innerjoin(Overlap, CellStdMedian.TransferLightHit, Keys="CellUID", RightVariables=["median_TrialSignal", "std_TrialSignal"]);
Overlap(:, ["TransferSignal", "TransferStd"]) = Overlap(:, ["median_TrialSignal", "std_TrialSignal"]);
Overlap(:, ["LearnedMean", "TransferMean"]) = array2table([mean(Overlap.LearnedSignal, 2), mean(Overlap.TransferSignal, 2)], ...
	VariableNames=["LearnedMean", "TransferMean"]);
Overlap(:, ["LearnedTimeStd", "TransferTimeStd"]) = array2table([std(Overlap.LearnedSignal(:, 1:24), 0, 2), std(Overlap.TransferSignal(:, 1:24), 0, 2)], ...
	VariableNames=["LearnedTimeStd", "TransferTimeStd"]);
Overlap = innerjoin(Overlap, MB.Cells, RightVariables="ZLayer");

LearnedMatrix = accumarray([Overlap.LearnedStd(:, 1) > Overlap.LearnedStd(:, 25), Overlap.LearnedSignal(:, 1) < Overlap.LearnedSignal(:, 25)] + 1, 1, [2, 2]);
TransferMatrix = accumarray([Overlap.TransferStd(:, 1) > Overlap.TransferStd(:, 25), Overlap.TransferSignal(:, 1) < Overlap.TransferSignal(:, 25)] + 1, 1, [2, 2]);
ConvergentOverlap = [min(Overlap.LearnedStd(:, 1:8), [], 2) > max(Overlap.LearnedStd(:, 16:24), [], 2), ...
	min(Overlap.TransferStd(:, 1:8), [], 2) > max(Overlap.TransferStd(:, 16:24), [], 2)];
LTMatrix = accumarray(ConvergentOverlap + 1, 1, [2, 2]);
ChanceOverlap = prod(mean(ConvergentOverlap, 1), 2);
[~, ConvergentP] = fishertest([sum(ConvergentOverlap(:, 1) & ConvergentOverlap(:, 2)), sum(ConvergentOverlap(:, 1) & ~ConvergentOverlap(:, 2)); ...
	sum(~ConvergentOverlap(:, 1) & ConvergentOverlap(:, 2)), sum(~ConvergentOverlap(:, 1) & ~ConvergentOverlap(:, 2))], Tail='right');

LearnedTags = MATLAB.SignificantFixedpoint(LearnedMatrix ./ height(Overlap) * 100, 2) + "%";
TransferTags = MATLAB.SignificantFixedpoint(TransferMatrix ./ height(Overlap) * 100, 2) + "%";
LTTags = MATLAB.SignificantFixedpoint(LTMatrix ./ height(Overlap) * 100, 2) + "%";
if ConvergentP < 0.05
	LTTags(end) = LTTags(end) + "*";
end

BlockTagSignals = MB.TableQuery(["BlockUID", "BlockTags"], Paradigm="声光无穿插", Phase=["Learned", "Transfer"]);
BlockSignalRows = MB.BlockSignals(ismember(MB.BlockSignals.BlockUID, BlockTagSignals.BlockUID), :);
BlockSignalRows = groupsummary(BlockSignalRows, 'BlockUID', @(blockSignal) {vertcat(blockSignal{:})}, 'BlockSignal');
BlockTagSignals = innerjoin(BlockTagSignals, BlockSignalRows, RightVariables="fun1_BlockSignal");

BlockTagSignals.BeforeLickStarts = cell(height(BlockTagSignals), 1);
BlockTagSignals.AfterLickStarts = cell(height(BlockTagSignals), 1);
BlockTagSignals.Licking = cell(height(BlockTagSignals), 1);
for iB = 1:height(BlockTagSignals)
	CD1 = BlockTagSignals.BlockTags{iB}.CD1;
	CD2 = BlockTagSignals.BlockTags{iB}.CD2;
	CD2 = CD2 > mean(CD2) + std(CD2);
	LickStarts = find(CD2 & movsum(CD2, [24, 0]) <= 1 & ~movsum(CD1 > mean(CD1) + std(CD1), [24, 0]));
	BeforeLickStarts = LickStarts(LickStarts > 24) + (-24:0);
	AfterLickStarts = LickStarts(LickStarts + 24 < numel(CD2)) + (0:24);
	if isempty(BeforeLickStarts) || isempty(AfterLickStarts)
		continue;
	end
	BlockSignal = BlockTagSignals.fun1_BlockSignal{iB};
	BlockTagSignals.BeforeLickStarts{iB} = std(reshape(BlockSignal(:, BeforeLickStarts(:)), [], size(BeforeLickStarts, 1), 25), 0, 2);
	BlockTagSignals.AfterLickStarts{iB} = std(reshape(BlockSignal(:, AfterLickStarts(:)), [], size(AfterLickStarts, 1), 25), 0, 2);
	BlockTagSignals.Licking{iB} = CD2(AfterLickStarts);
end

keepBlocks = ~cellfun(@isempty, BlockTagSignals.BeforeLickStarts) & ~cellfun(@isempty, BlockTagSignals.AfterLickStarts) & ~cellfun(@isempty, BlockTagSignals.Licking);
BlockTagSignals = BlockTagSignals(keepBlocks, :);
if isempty(BlockTagSignals)
	error('Fig372:NoLickBlocks', 'No valid spontaneous-lick blocks were built.');
end

BALickStarts = [vertcat(BlockTagSignals.BeforeLickStarts{:}), vertcat(BlockTagSignals.AfterLickStarts{:})];
BALickStarts(:, 1, :) = BALickStarts(:, 1, :) - BALickStarts(:, 1, end);
BALickStarts(:, 2, :) = BALickStarts(:, 2, :) - BALickStarts(:, 2, 1);

[StdMean, StdSem] = MATLAB.DataFun.MeanSem(permute(BALickStarts, [3, 2, 1]), 3);
[BehaviorMean, BehaviorSem] = MATLAB.DataFun.MeanSem(vertcat(BlockTagSignals.Licking{:}).', 2);

xs = TransferLearning.Xs(24:end);
if isduration(xs)
	xs = seconds(xs);
end
xs = double(xs(:));

Data = struct();
Data.QueryXlsx = queryXlsx;
Data.Overlap = Overlap;
Data.LearnedMatrix = LearnedMatrix;
Data.TransferMatrix = TransferMatrix;
Data.LTMatrix = LTMatrix;
Data.LearnedTags = LearnedTags;
Data.TransferTags = TransferTags;
Data.LTTags = LTTags;
Data.ChanceOverlap = ChanceOverlap;
Data.ConvergentP = ConvergentP;
Data.StdMean = StdMean;
Data.StdSem = StdSem;
Data.BehaviorMean = BehaviorMean;
Data.BehaviorSem = BehaviorSem;
Data.X = xs;
Data.CacheInfo = struct('NOverlapCells', height(Overlap), 'NBlocks', height(BlockTagSignals));
Cache = Data;
end