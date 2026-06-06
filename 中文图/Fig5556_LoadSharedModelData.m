% Shared model data cache for Chinese Fig55/Fig56 scripts.

cacheName = 'Fig5556_ModelData';
legacyCacheName = 'Fig382383_ModelData';
cacheVersion = 3;
seedBase = 38238307;
permutationCount = 10000;
permutationSeed = 1;

useCachedData = false;
if evalin('base', sprintf('exist(''%s'', ''var'')', cacheName)) == 1
	Fig5556Data = evalin('base', cacheName);
elseif evalin('base', sprintf('exist(''%s'', ''var'')', legacyCacheName)) == 1
	Fig5556Data = evalin('base', legacyCacheName);
else
	Fig5556Data = [];
end

if ~isempty(Fig5556Data)
	Fig5556Data = iNormalizeFig5556PanelNames(Fig5556Data);
	useCachedData = iIsReusableFig5556Data(Fig5556Data, cacheVersion, seedBase, permutationCount, permutationSeed);
end

if useCachedData
	assignin('base', cacheName, Fig5556Data);
end

if ~useCachedData
	Fig5556Data = TransferLearning.THModel.BuildFig382383SharedModelData( ...
		SeedBase=seedBase, ...
		NPermutation=permutationCount, ...
		PermutationSeed=permutationSeed);
	Fig5556Data = iNormalizeFig5556PanelNames(Fig5556Data);
	assignin('base', cacheName, Fig5556Data);
end

function tf = iIsReusableFig5556Data(data, cacheVersion, seedBase, permutationCount, permutationSeed)
tf = isstruct(data) ...
	&& isfield(data, 'CacheVersion') && isequal(data.CacheVersion, cacheVersion) ...
	&& isfield(data, 'SeedBase') && isequal(data.SeedBase, seedBase) ...
	&& isfield(data, 'NPermutation') && isequal(data.NPermutation, permutationCount) ...
	&& isfield(data, 'PermutationSeed') && isequal(data.PermutationSeed, permutationSeed) ...
	&& isfield(data, 'Acceptance') && isfield(data.Acceptance, 'Passed') && isequal(data.Acceptance.Passed, true) ...
	&& isfield(data, 'Performance') && isfield(data.Performance, 'Naive') && isfield(data.Performance, 'Transfer') && isfield(data.Performance, 'THOff') ...
	&& isfield(data, 'PreFormalWeightValues') ...
	&& isfield(data, 'Heterogeneity') ...
	&& isfield(data, 'Sigmoid') && (isfield(data.Sigmoid, 'Fig55C') || isfield(data.Sigmoid, 'Fig54C')) && isfield(data.Sigmoid, 'Fig383D') ...
	&& isfield(data, 'HeatmapData');
end

function data = iNormalizeFig5556PanelNames(data)
if isstruct(data) && isfield(data, 'Sigmoid') && isfield(data.Sigmoid, 'Fig382C') && ~isfield(data.Sigmoid, 'Fig55C')
	data.Sigmoid.Fig55C = data.Sigmoid.Fig382C;
end
if isstruct(data) && isfield(data, 'Sigmoid') && isfield(data.Sigmoid, 'Fig55C') && ~isfield(data.Sigmoid, 'Fig382C')
	data.Sigmoid.Fig382C = data.Sigmoid.Fig55C;
end
if isstruct(data) && isfield(data, 'Sigmoid') && isfield(data.Sigmoid, 'Fig55C') && ~isfield(data.Sigmoid, 'Fig54C')
	data.Sigmoid.Fig54C = data.Sigmoid.Fig55C;
end
if isstruct(data) && isfield(data, 'Sigmoid') && isfield(data.Sigmoid, 'Fig54C') && ~isfield(data.Sigmoid, 'Fig55C')
	data.Sigmoid.Fig55C = data.Sigmoid.Fig54C;
end
if isstruct(data) && isfield(data, 'Sigmoid') && isfield(data.Sigmoid, 'Fig383B') && ~isfield(data.Sigmoid, 'Fig383D')
	data.Sigmoid.Fig383D = data.Sigmoid.Fig383B;
end
end