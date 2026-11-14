% 英文图2M：重制中文Fig54A，连接权重和分箱计算保持不变。
ThisDir = fileparts(mfilename('fullpath'));
if ~exist('TransferLearning', 'class')
	matlab.project.loadProject(fullfile(ThisDir, '..', 'Transferlearning.prj'));
end
ModelData = TransferLearning.LoadRnnFigureData();
Figure = TransferLearning.PlotPreFormalConnectionWeightDistributions(ModelData.PreFormalWeightValues);
Figure.Name = 'English Fig2M connection weight distributions';
SvgPath = TransferLearning.ExportStandardFigure(Figure, 2, 'English_Fig2M_ModelConnectionWeightDistributions.svg');
assignin('base', 'Fig2M_ModelStats', struct('Weights', ModelData.PreFormalWeightValues, 'Figure', Figure, 'SvgPath', SvgPath));