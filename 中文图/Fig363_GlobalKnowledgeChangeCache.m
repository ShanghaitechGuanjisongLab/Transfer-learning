function Data = Fig363_GlobalKnowledgeChangeCache(queryXlsx)
queryXlsx = string(queryXlsx);

persistent Cache
if ~isempty(Cache) && isfield(Cache, 'QueryXlsx') && Cache.QueryXlsx == queryXlsx
	Data = Cache;
	return;
end

phaseNames = ["NaiveLight", "LearnedLight", "LearnedAudio", "TransferLight", "FinalLight"];
baseData = Fig362_GlobalInformationCache(queryXlsx, string.empty(1, 0), phaseNames);

pairs = table( ...
	["NaiveLight"; "LearnedAudio"; "TransferLight"; "LearnedAudio"], ...
	["LearnedLight"; "TransferLight"; "FinalLight"; "FinalLight"], ...
	["Naive 💡💧"; "Learned 🔊💧"; "Continual 💡💧"; "Learned 🔊💧"], ...
	["Learned 💡💧"; "Continual 💡💧"; "Final 💡💧"; "Final 💡💧"], ...
	["Naive→Learned"; "Learned→Continual"; "Continual→Final"; "Learned→Final"], ...
	["NaiveToLearned"; "LearnedToTransfer"; "TransferToFinal"; "LearnedToFinal"], ...
	'VariableNames', {'LeftPhase', 'RightPhase', 'LeftLegend', 'RightLegend', 'Transition', 'TransitionKey'});

usageRowNames = {'Unused old', 'Newly learned'};
transitionNames = cellstr(pairs.TransitionKey.');
unCompare = table('Size', [2, numel(transitionNames)], ...
	'VariableTypes', repmat({'cell'}, 1, numel(transitionNames)), ...
	'VariableNames', transitionNames, ...
	'RowNames', usageRowNames);
unCompare.Properties.DimensionNames = {'Usage', 'Pair'};

pairStats = table('Size', [height(pairs), 9], ...
	'VariableTypes', {'string', 'string', 'string', 'string', 'string', 'string', 'cell', 'cell', 'cell'}, ...
	'VariableNames', {'LeftPhase', 'RightPhase', 'LeftLegend', 'RightLegend', 'Transition', 'TransitionKey', 'MousePairs', 'UNS', 'Knowledge'});
	pairStats{:, {'LeftPhase', 'RightPhase', 'LeftLegend', 'RightLegend', 'Transition', 'TransitionKey'}} = pairs{:, {'LeftPhase', 'RightPhase', 'LeftLegend', 'RightLegend', 'Transition', 'TransitionKey'}};
pairStats.UnusedOld = nan(height(pairs), 1);
pairStats.NewlyLearned = nan(height(pairs), 1);
pairStats.SharedEntropy = nan(height(pairs), 1);

for iPair = 1:height(pairs)
	leftRows = unique(baseData.GroupNts.(pairs.LeftPhase(iPair))(:, ["Mouse", "BlockUID"]));
	rightRows = unique(baseData.GroupNts.(pairs.RightPhase(iPair))(:, ["Mouse", "BlockUID"]));
	leftRows.Properties.VariableNames{'BlockUID'} = 'BlockUIDLeft';
	rightRows.Properties.VariableNames{'BlockUID'} = 'BlockUIDRight';
	groupPair = innerjoin(leftRows, rightRows, Keys="Mouse");
	groupPair.Blocks = cell(height(groupPair), 1);
	groupPair.UNS = cell(height(groupPair), 1);

	for iMouse = 1:height(groupPair)
		leftBlock = baseData.BlockCache.Cells{baseData.BlockCache.BlockUID == uint64(groupPair.BlockUIDLeft(iMouse))};
		rightBlock = baseData.BlockCache.Cells{baseData.BlockCache.BlockUID == uint64(groupPair.BlockUIDRight(iMouse))};
		leftBlock = renamevars(leftBlock, 'BlockSignal', 'BlockSignalLeft');
		rightBlock = renamevars(rightBlock, 'BlockSignal', 'BlockSignalRight');
		blockPair = innerjoin(leftBlock, rightBlock, Keys="CellUID", LeftVariables=["CellUID", "BlockSignalLeft"], RightVariables="BlockSignalRight");

		logicalMask = ismember(leftBlock.CellUID, blockPair.CellUID);
		blockPair.Covariance_PairLeft = leftBlock.Covariance(logicalMask, logicalMask);
		logicalMask = ismember(rightBlock.CellUID, blockPair.CellUID);
		blockPair.Covariance_PairRight = rightBlock.Covariance(logicalMask, logicalMask);
		blockPair.Samples = blockPair{:, ["BlockSignalLeft", "BlockSignalRight"]};
		blockPair.Covariance = MATLAB.DataFun.ShrinkageCov(blockPair.Samples, 1, 2);
		[~, blockPair.JointEntropy] = MATLAB.DataFun.CovarianceToEntropy(blockPair.Covariance, 2, 1);
		[~, blockPair.LeftEntropy] = MATLAB.DataFun.CovarianceToEntropy(blockPair.Covariance_PairLeft, 2, 1);
		[~, blockPair.RightEntropy] = MATLAB.DataFun.CovarianceToEntropy(blockPair.Covariance_PairRight, 2, 1);
		blockPair.SharedEntropy = blockPair.LeftEntropy + blockPair.RightEntropy - blockPair.JointEntropy;
		blockPair.UnusedOld = blockPair.JointEntropy - blockPair.RightEntropy;
		blockPair.NewlyLearned = blockPair.JointEntropy - blockPair.LeftEntropy;

		groupPair.Blocks{iMouse} = blockPair;
		groupPair.UNS{iMouse} = blockPair(:, ["UnusedOld", "NewlyLearned", "SharedEntropy"]);
	end

	uns = vertcat(groupPair.UNS{:});
	unCompare{usageRowNames{1}, transitionNames{iPair}} = {double(uns.UnusedOld)};
	unCompare{usageRowNames{2}, transitionNames{iPair}} = {double(uns.NewlyLearned)};
	pairStats.MousePairs{iPair} = groupPair;
	pairStats.UNS{iPair} = uns;
	pairStats{iPair, ["UnusedOld", "NewlyLearned", "SharedEntropy"]} = mean(uns{:, ["UnusedOld", "NewlyLearned", "SharedEntropy"]}, 1);
	pairStats.Knowledge{iPair} = reshape([0, pairStats{iPair, ["UnusedOld", "NewlyLearned", "SharedEntropy"]}], 2, 2);
end

Data = struct();
Data.QueryXlsx = queryXlsx;
Data.PairStats = pairStats;
Data.UNCompare = unCompare;
Data.CacheInfo = struct('NumPair', height(pairStats), 'Transitions', pairStats.Transition.');
Cache = Data;
end