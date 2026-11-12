function S = LoadLocalWindowCueTransferResults(trainPhase, trainStimulus, PostDuration)
% 加载或生成逐鼠局部均值cue前后解码结果；测试始终为Transfer LightWater，合并hit/miss。
% 复用旧Learned AudioWater与Naive AudioOnly缓存，保持原3B/3C结果不变；Naive AudioWater另存新缓存。
arguments
	trainPhase (1,1) string
	trainStimulus (1,1) string
	PostDuration (1,1) double {mustBeMember(PostDuration, [0.3, 1])} = 1
end
halfWindow = 0.250;
nPermutation = 200;
if trainPhase == "Learned" && trainStimulus == "AudioWater"
	cacheName = 'CueModel_LocalWindow250ms_TransferAudioToLight_Results.mat';
elseif trainPhase == "Naive" && trainStimulus == "AudioOnly"
	cacheName = 'CueModel_LocalWindow250ms_NaiveAudioOnlyToTransferLightWater_12h7d_Results.mat';
elseif trainPhase == "Naive" && trainStimulus == "AudioWater"
	cacheName = 'CueModel_LocalWindow250ms_NaiveAudioWaterToTransferLightWater_12h7d_Results.mat';
else
	error('LocalWindowCueTransfer:UnsupportedContext', '不支持的训练情境：%s %s。', trainPhase, trainStimulus);
end
if PostDuration ~= 1
	cacheName = strrep(cacheName, '_Results.mat', '_Post300ms_Results.mat');
end
matPath = TransferLearning.CachePath(cacheName);
if isfile(matPath)
	S = load(matPath);
	if S.halfWindow ~= halfWindow || S.nPermutation ~= nPermutation
		error('LocalWindowCueTransfer:CacheSettings', '缓存参数与±250 ms、200次置换不一致：%s。', matPath);
	end
	if (PostDuration ~= 1 && ~isfield(S, 'PostDuration')) || (isfield(S, 'PostDuration') && S.PostDuration ~= PostDuration)
		error('LocalWindowCueTransfer:CacheSettings', '缓存的线索后时间窗不一致：%s。', matPath);
	end
	return;
end

datasets = {TransferLearning.AudioLightBaseline(), TransferLearning.Vacation7()};
xs = seconds(TransferLearning.Xs);
tIdx = find(xs >= -1.5 & xs <= 1.5);
if PostDuration ~= 1
	tIdx = find(xs >= -1.5 & xs <= PostDuration);
end
tVec = xs(tIdx);
radius = round(halfWindow / median(diff(xs)));
tPre = xs >= -1 - halfWindow & xs <= halfWindow;
tPost = xs >= -halfWindow & xs <= PostDuration + halfWindow;
excludeMice = "vtf0353";
tasks = {};
for datasetIndex = 1:numel(datasets)
	DS = datasets{datasetIndex};
	trainMetadata = DS.TableQuery(["Mouse", "BlockUID"], Phase=trainPhase, Stimulus=trainStimulus);
	testMetadata = DS.TableQuery(["Mouse", "BlockUID"], Phase="Transfer", Stimulus="LightWater");
	trainMetadata.Mouse = string(trainMetadata.Mouse); testMetadata.Mouse = string(testMetadata.Mouse);
	trainMetadata.BlockUID = uint64(trainMetadata.BlockUID); testMetadata.BlockUID = uint64(testMetadata.BlockUID);
	mice = setdiff(intersect(unique(trainMetadata.Mouse), unique(testMetadata.Mouse)), excludeMice)';
	for mouse = mice
		trainBlocks = unique(trainMetadata.BlockUID(trainMetadata.Mouse == mouse));
		testBlocks = unique(testMetadata.BlockUID(testMetadata.Mouse == mouse));
		trainTable = TransferLearning.QueryZScoreNts(DS, mouse, trainStimulus);
		testTable = TransferLearning.QueryZScoreNts(DS, mouse, "LightWater");
		if isempty(trainTable) || isempty(testTable), continue; end
		trainTable = trainTable(ismember(uint64(trainTable.BlockUID), trainBlocks), :);
		testTable = testTable(ismember(uint64(testTable.BlockUID), testBlocks), :);
		if trainStimulus == "AudioWater", trainTable = trainTable(~isnan(trainTable.Behavior), :); end
		if isempty(trainTable) || isempty(testTable), continue; end
		cellUIDs = intersect(unique(uint64(trainTable.CellUID)), unique(uint64(testTable.CellUID)));
		if numel(cellUIDs) < 5, continue; end
		XTrain = TransferLearning.BuildTrialMatrix(trainTable, cellUIDs);
		XTest = TransferLearning.BuildTrialMatrix(testTable, cellUIDs);
		if isempty(XTrain) || isempty(XTest) || size(XTrain, 1) < 5, continue; end
		if PostDuration == 1
			SmoothedTrain = iLocalMean(XTrain(:, :, tIdx), radius);
			SmoothedTest = iLocalMean(XTest(:, :, tIdx), radius);
		else
			SmoothedTrain = iLocalMean(XTrain, radius);
			SmoothedTest = iLocalMean(XTest, radius);
			SmoothedTrain = SmoothedTrain(:, :, tIdx);
			SmoothedTest = SmoothedTest(:, :, tIdx);
		end
		tasks{end+1} = struct('DS', datasetIndex, 'Mouse', char(mouse), 'NCells', numel(cellUIDs), 'CellUIDs', cellUIDs, 'preTr', mean(XTrain(:, :, tPre), 3), 'postTr', mean(XTrain(:, :, tPost), 3), 'preTe', mean(XTest(:, :, tPre), 3), 'postTe', mean(XTest(:, :, tPost), 3), 'XTrT', SmoothedTrain, 'XTeT', SmoothedTest, 'TrainTrialUIDs', unique(trainTable.TrialUID), 'TestTrialUIDs', unique(testTable.TrialUID), 'TrainBlockUIDs', trainBlocks, 'TestBlockUIDs', testBlocks);
	end
end
if isempty(tasks), error('LocalWindowCueTransfer:NoTasks', '%s %s没有可解码的配对鼠。', trainPhase, trainStimulus); end
res = cell(numel(tasks), 1);
WorkerLimit = 0;
Pool = gcp('nocreate');
if ~isempty(Pool)
	WorkerLimit = min(Pool.NumWorkers, 8);
end
parfor (taskIndex = 1:numel(tasks), WorkerLimit)
	fprintf('%s %s解码 %d/%d：%s\n', trainPhase, trainStimulus, taskIndex, numel(tasks), tasks{taskIndex}.Mouse);
	rng(42 + taskIndex, 'twister');
	res{taskIndex} = TransferLearning.DecodeCuePrePostTransfer(tasks{taskIndex}, tVec, nPermutation);
end
S = struct('res', {res}, 'tasks', {tasks}, 'tVec', tVec, 'halfWindow', halfWindow, 'nPermutation', nPermutation, 'excludeMice', excludeMice, 'trainPhase', trainPhase, 'trainStimulus', trainStimulus, 'testPhase', "Transfer", 'testStimulus', "LightWater", 'datasets', ["AudioLightBaseline", "Vacation7"]);
S.PostDuration = PostDuration;
S.PreDuration = 1;
S.FeaturePreTimes = xs(tPre);
S.FeaturePostTimes = xs(tPost);
save(matPath, '-struct', 'S');
fprintf('Saved: %s\n', matPath);
end

function Y = iLocalMean(X, radius)
Y = zeros(size(X));
for timeIndex = 1:size(X, 3)
	indices = max(1, timeIndex - radius):min(size(X, 3), timeIndex + radius);
	Y(:, :, timeIndex) = mean(X(:, :, indices), 3);
end
end