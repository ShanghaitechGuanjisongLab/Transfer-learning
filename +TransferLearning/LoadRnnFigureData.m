function Data = LoadRnnFigureData()
% 复用中文RNN图的固定种子和计算流程，只新增持久缓存供英文重绘使用。
CacheFile = TransferLearning.CachePath('Fig2_RnnSharedModelData.mat');
Params = TransferLearning.THModel.DefaultParams();
if isfile(CacheFile)
	Cached = load(CacheFile, 'Data');
	Data = Cached.Data;
	assert(Data.CacheVersion == 3 && Data.SeedBase == 38238307 && Data.NPermutation == 10000 && Data.PermutationSeed == 1, 'RNN共享缓存的种子或统计规则不一致。');
	assert(isequaln(Data.Params, Params), 'RNN共享缓存参数与当前模型不一致，请明确是否重新计算。');
else
	Data = TransferLearning.THModel.BuildFig382383SharedModelData(SeedBase=38238307, NPermutation=10000, PermutationSeed=1);
	save(CacheFile, 'Data', '-v7.3');
end
if ~isfield(Data.Sigmoid, 'Fig54C')
	Data.Sigmoid.Fig54C = Data.Sigmoid.Fig382C;
end
if ~isfield(Data.Sigmoid, 'Fig55C')
	Data.Sigmoid.Fig55C = Data.Sigmoid.Fig54C;
end
assert(Data.Acceptance.Passed, '共享模型数据没有通过原中文脚本的验收。');
assignin('base', 'Fig5556_ModelData', Data);
fprintf('RNN共享结果：种子%d，%d只模拟鼠，缓存%s。\n', Data.SeedBase, Data.Params.NumMice, CacheFile);
end