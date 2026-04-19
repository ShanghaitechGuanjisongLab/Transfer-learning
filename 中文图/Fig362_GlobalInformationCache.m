function Data = Fig362_GlobalInformationCache(varargin)
[linePhases, barPhases] = iParseInputs(varargin{:});
requestedPhases = unique([linePhases, barPhases], 'stable');

persistent Cache

if isempty(Cache)
	Cache = iBuildEmptyCache();
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
Data.QuerySource = Cache.QuerySource;
Data.XData = Cache.XData;
Data.LinePhases = linePhases;
Data.BarPhases = barPhases;
Data.Phase = Cache.Phase;
Data.GroupNts = Cache.GroupNts;
Data.BlockCache = Cache.BlockCache;
Data.CacheInfo = struct( ...
	'QuerySource', Cache.QuerySource, ...
	'NumCachedBlock', height(Cache.BlockCache), ...
	'NumCachedPhase', numel(string(fieldnames(Cache.Phase))), ...
	'CachedPhases', string(fieldnames(Cache.Phase)).');
end

function [linePhases, barPhases] = iParseInputs(varargin)
	if nargin == 2
		linePhases = varargin{1};
		barPhases = varargin{2};
	elseif nargin == 3
		linePhases = varargin{2};
		barPhases = varargin{3};
	else
		error('Fig362:BadInput', 'Expected 2 or 3 inputs.');
	end
	linePhases = reshape(string(linePhases), 1, []);
	barPhases = reshape(string(barPhases), 1, []);
end

function Cache = iBuildEmptyCache()
	MB = TransferLearning.MOpBaseline();
	infoQuery = iBuildInternalInfoQuery();
	Cache = struct();
	Cache.QuerySource = "internal";
	Cache.MB = MB;
	Cache.GroupNts = MB.QueryNTS(infoQuery, ExtraColumns=["Mouse", "BlockUID", "TrialRI"]);
	Cache.BlockCache = table('Size', [0, 3], ...
		'VariableTypes', {'uint64', 'cell', 'cell'}, ...
		'VariableNames', {'BlockUID', 'Cells', 'BlockEntropy'});
	Cache.Phase = struct();
	Cache.XData = linspace(0, 3, 25).';
end

function infoQuery = iBuildInternalInfoQuery()
	groupName = ["NaiveLight"; "LearnedLight"; "TransferLight"; "TransferLightHit"; "TransferLightMiss"; "FinalLight"; ...
		"NaiveAudio"; "LearnedAudio"; "TransferAudio"; "TransferAudioHit"; "TransferAudioMiss"; "FinalAudio"];
	stimulus = ["LightWater"; "LightWater"; "LightWater"; "LightWater"; "LightWater"; "LightWater"; ...
		"AudioWater"; "AudioWater"; "AudioWater"; "AudioWater"; "AudioWater"; "AudioWater"];
	phase = ["Naive"; "Learned"; "Transfer"; "Transfer"; "Transfer"; "Final"; ...
		"Naive"; "Learned"; "Transfer"; "Transfer"; "Transfer"; "Final"];
	paradigm = ["光声无穿插"; "光声无穿插"; "声光无穿插"; "声光无穿插"; "声光无穿插"; "声光无穿插"; ...
		"声光无穿插"; "声光无穿插"; "光声无穿插"; "光声无穿插"; "光声无穿插"; "光声无穿插"];
	behavior = {[]; []; []; 1; 0; []; []; []; []; 1; 0; []};
	infoQuery = table(groupName, stimulus, phase, paradigm, behavior, ...
		'VariableNames', {'GroupName', 'Stimulus', 'Phase', 'Paradigm', 'Behavior'});
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