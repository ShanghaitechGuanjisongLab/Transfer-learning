% 英文图3K：重制中文Fig54B，使用相同权重与异质性结果及默认组间统计（原英文图2N）。
ThisDir = fileparts(mfilename('fullpath'));
if ~exist('TransferLearning', 'class')
	matlab.project.loadProject(fullfile(ThisDir, '..', 'Transferlearning.prj'));
end
ModelData = TransferLearning.LoadRnnFigureData();
[Figure, SummaryTable] = TransferLearning.PlotPreFormalConnectionWeightStdBars(ModelData.PreFormalWeightValues);
Figure.Name = 'English Fig3K weight SD and response heterogeneity';
SvgPath = TransferLearning.ExportStandardFigure(Figure, 2, 'English_Fig3K_ModelWeightStdAndHeterogeneity.svg');
Fig3K_ModelStats = struct('Summary', SummaryTable, 'Weights', ModelData.PreFormalWeightValues, 'Figure', Figure, 'SvgPath', SvgPath);
assignin('base', 'Fig3K_ModelStats', Fig3K_ModelStats);
fprintf('已导出：%s\n', SvgPath);