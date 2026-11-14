% 英文图2L：重制中文Fig53D，复用相同预训练种子和阶段权重计算。
ThisDir = fileparts(mfilename('fullpath'));
if ~exist('TransferLearning', 'class')
	matlab.project.loadProject(fullfile(ThisDir, '..', 'Transferlearning.prj'));
end
ModelData = TransferLearning.LoadRnnFigureData();
CacheFile = TransferLearning.CachePath('Fig2L_ModelStageWeights.mat');
if isfile(CacheFile)
	Cached = load(CacheFile, 'StageWeightValues', 'StageRunInfo', 'Params');
	assert(isequaln(Cached.Params, ModelData.Params), '阶段权重缓存的模型参数不一致。');
	StageWeightValues = Cached.StageWeightValues;
	StageRunInfo = Cached.StageRunInfo;
else
	[StageWeightValues, StageRunInfo] = TransferLearning.THModel.PretrainStageAllConnectionWeights(ModelData.Params, ModelData.Cond, ModelData.RunInfo);
	Params = ModelData.Params;
	save(CacheFile, 'StageWeightValues', 'StageRunInfo', 'Params', '-v7.3');
end
Figure = TransferLearning.PlotAllConnectionWeightDistributionsByStage(StageWeightValues);
Figure.Name = 'English Fig2L stage weight distributions';
SvgPath = TransferLearning.ExportStandardFigure(Figure, 1, 'English_Fig2L_ModelStageWeightDistributions.svg');
assignin('base', 'Fig2L_ModelStats', struct('Weights', StageWeightValues, 'RunInfo', StageRunInfo, 'Figure', Figure, 'SvgPath', SvgPath));