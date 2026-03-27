function Data = Fig362_GlobalInformationCache(queryXlsx, linePhases, barPhases)
queryXlsx = string(queryXlsx);
linePhases = reshape(string(linePhases), 1, []);
barPhases = reshape(string(barPhases), 1, []);
requestedPhases = unique([linePhases, barPhases], 'stable');

persistent Cache

if isempty(Cache) || ~isfield(Cache, 'QueryXlsx') || Cache.QueryXlsx ~= queryXlsx
	Cache = iBuildEmptyCache(queryXlsx);
end

for iPhase = 1:numel(requestedPhases)
	phaseName = requestedPhases(iPhase);
	if ~isfield(Cache.GroupNts, phaseName)
		error('Fig362:MissingPhase', 'Phase %s is missing from QueryNTS result.', phaseName);
	end
	if ~isfield(Cache.Phase, phaseName)
		Cache = iEnsurePhase(Cache, phaseName);
	end
end

Data = struct();
Data.QueryXlsx = Cache.QueryXlsx;
Data.XData = Cache.XData;
Data.LinePhases = linePhases;
Data.BarPhases = barPhases;
Data.Phase = Cache.Phase;
Data.GroupNts = Cache.GroupNts;
Data.BlockCache = Cache.BlockCache;
Data.CacheInfo = struct( ...
	'NumCachedBlock', height(Cache.BlockCache), ...
	'NumCachedPhase', numel(string(fieldnames(Cache.Phase))), ...
	'CachedPhases', string(fieldnames(Cache.Phase)).');
end

function Cache = iBuildEmptyCache(queryXlsx)
	MB = TransferLearning.MOpBaseline();
	infoQuery = UniExp.ReadQueryTable(queryXlsx, '信息熵');
	Cache = struct();
	Cache.QueryXlsx = queryXlsx;
	Cache.MB = MB;
	Cache.GroupNts = MB.QueryNTS(infoQuery, ExtraColumns=["Mouse", "BlockUID", "TrialRI"]);
	Cache.BlockCache = table('Size', [0, 3], ...
		'VariableTypes', {'uint64', 'cell', 'cell'}, ...
		'VariableNames', {'BlockUID', 'Cells', 'BlockEntropy'});
	Cache.Phase = struct();
	Cache.XData = linspace(0, 3, 25).';
end

function Cache = iEnsurePhase(Cache, phaseName)
	phaseRows = Cache.GroupNts.(phaseName);
	phaseBlockUID = unique(uint64(phaseRows.BlockUID));
	Cache = iEnsureBlocks(Cache, phaseBlockUID);

	phaseTrials = groupsummary( ...
		sortrows(phaseRows, ["TrialRI", "CellUID"]), ...
		"BlockUID", ...
		@(data) {data}, ...
		["CellUID", "TrialSignal", "TrialRI"]);
	phaseTs = innerjoin( ...
		phaseTrials, ...
		Cache.BlockCache, ...
		Keys="BlockUID", ...
		LeftVariables=["fun1_TrialSignal", "fun1_TrialRI"], ...
		RightVariables=["Cells", "BlockEntropy"]);

	infoCell = cell(height(phaseTs), 1);
	for iBlock = 1:height(phaseTs)
		blockTable = phaseTs.Cells{iBlock};
		blockTable.Samples = reshape(phaseTs.fun1_TrialSignal{iBlock}, height(blockTable), [], 48);
		blockTable = MATLAB.DataFun.MultivariateNormalInformation(blockTable);
		infoCell{iBlock} = reshape(blockTable.Information, [], 48);
	end

	trialInfo = vertcat(infoCell{:});
	[meanRow, semRow] = MATLAB.DataFun.MeanSem(trialInfo, 1);
	meanRow = meanRow(24:48);
	semRow = semRow(24:48);

	phaseData = struct();
	phaseData.Mean = meanRow - meanRow(1);
	phaseData.Sem = semRow;
	phaseData.BlockEntropy = [phaseTs.BlockEntropy{:}].';
	phaseData.NumBlock = height(phaseTs);
	Cache.Phase.(phaseName) = phaseData;
end

function Cache = iEnsureBlocks(Cache, blockUID)
	blockUID = unique(uint64(blockUID(:)));
	if isempty(blockUID)
		return;
	end

	if isempty(Cache.BlockCache)
		missingBlockUID = blockUID;
	else
		missingBlockUID = blockUID(~ismember(blockUID, Cache.BlockCache.BlockUID));
	end
	if isempty(missingBlockUID)
		return;
	end

	blockSignals = Cache.MB.BlockSignals(ismember(uint64(Cache.MB.BlockSignals.BlockUID), missingBlockUID), :);
	blockGroup = groupsummary(blockSignals, "BlockUID", @(data) {data}, ["CellUID", "BlockSignal"]);
	newCache = table('Size', [height(blockGroup), 3], ...
		'VariableTypes', {'uint64', 'cell', 'cell'}, ...
		'VariableNames', {'BlockUID', 'Cells', 'BlockEntropy'});
	for iBlock = 1:height(blockGroup)
		blockTable = table;
		blockTable.CellUID = blockGroup.fun1_CellUID{iBlock};
		blockTable.BlockSignal = vertcat(blockGroup.fun1_BlockSignal{iBlock}{:});
		blockTable.Mean = mean(blockTable.BlockSignal, 2);
		blockTable.Covariance = MATLAB.DataFun.ShrinkageCov(gpuArray(blockTable.BlockSignal), 1, 2);
		[~, blockEntropy] = MATLAB.DataFun.CovarianceToEntropy(blockTable.Covariance);
		newCache.BlockUID(iBlock) = uint64(blockGroup.BlockUID(iBlock));
		newCache.Cells{iBlock} = blockTable;
		newCache.BlockEntropy{iBlock} = gather(double(blockEntropy(:).'));
	end

	Cache.BlockCache = sortrows([Cache.BlockCache; newCache], 'BlockUID');
end