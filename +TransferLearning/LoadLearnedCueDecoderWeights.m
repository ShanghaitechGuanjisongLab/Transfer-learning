function Data = LoadLearnedCueDecoderWeights()
% 读取原Learned声水1 s的cue前后LASSO系数；正值支持cued判别，负值支持base判别。
SourcePath = TransferLearning.CachePath('CueModel_LocalWindow250ms_TransferAudioToLight_Results.mat');
assert(isfile(SourcePath), 'LearnedCueWeights:MissingCache', '缺少Learned声水cue前后解码缓存，请先生成原1 s解码结果。');
Source = load(SourcePath, 'res', 'halfWindow', 'nPermutation');
assert(Source.halfWindow == 0.25 && Source.nPermutation == 200, 'LearnedCueWeights:CacheSettings', '原cue解码缓存参数与1 s、±250 ms和200次shuffle不一致。');
DatasetNames = ["AudioLightBaseline", "Vacation7"];
Cohorts = {cell(0, 1); cell(0, 1)};
for ResultIndex = 1:numel(Source.res)
	Result = Source.res{ResultIndex};
	DatasetIndex = double(Result.DS);
	assert(ismember(DatasetIndex, [1, 2]));
	CellUIDs = uint64(Result.cellUIDs(:));
	Weights = double(Result.w(:));
	assert(numel(CellUIDs) == numel(Weights) && numel(unique(CellUIDs)) == numel(CellUIDs) && all(isfinite(Weights)), 'LearnedCueWeights:WeightMapping', '细胞编号和cue解码系数未能一一对应。');
	assert(string(Result.Mouse) ~= "vtf0353", 'LearnedCueWeights:ExcludedMouse', '原缓存不应包含既有排除鼠vtf0353。');
	Model = struct('Mouse', string(Result.Mouse), 'CellUIDs', CellUIDs, 'Weights', Weights, 'NCells', numel(CellUIDs), 'NTrials', double(Result.nTr), 'NBase', nnz(Weights < 0), 'NCued', nnz(Weights > 0), 'NZero', nnz(Weights == 0));
	Cohorts{DatasetIndex}{end + 1, 1} = Model;
end
for DatasetIndex = 1:2
	Models = Cohorts{DatasetIndex};
	assert(~isempty(Models), 'LearnedCueWeights:EmptyCohort', '原缓存缺少%s权重。', DatasetNames(DatasetIndex));
	Mice = cellfun(@(Model) Model.Mouse, Models);
	assert(numel(unique(Mice)) == numel(Mice));
end
Data = struct('Cohorts', {Cohorts}, 'DatasetNames', DatasetNames, 'SourceCache', SourcePath, 'TrainingPhase', "Learned", 'TrainingStimulus', "AudioWater", 'PreDuration', 1, 'PostDuration', 1, 'HalfWindow', 0.25, 'WeightType', "StandardizedLassoBeta", 'NegativeClass', "base", 'PositiveClass', "cued", 'ZeroClass', "unweighted");
end