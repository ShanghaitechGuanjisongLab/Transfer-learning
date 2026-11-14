% 英文图2P：重制中文Fig54C，沿用固定种子的模型表现、拟合与统计。
ThisDir = fileparts(mfilename('fullpath'));
if ~exist('TransferLearning', 'class')
	matlab.project.loadProject(fullfile(ThisDir, '..', 'Transferlearning.prj'));
end
ModelData = TransferLearning.LoadRnnFigureData();
Colors = [TransferLearning.CurveNaive; TransferLearning.Curve12h] / 255;
[Figure, Stats] = TransferLearning.PlotRnnLearningCurve(ModelData.Performance.Naive, ModelData.Performance.Transfer, ModelData.Sigmoid.Fig54C, ["Naive", "Transfer"], Colors);
Figure.Name = 'English Fig2P model Naive Transfer learning';
SvgPath = TransferLearning.ExportStandardFigure(Figure, 2, 'English_Fig2P_ModelNaiveTransferLearningCurve.svg');
assignin('base', 'Fig2P_ModelStats', Stats);
fprintf('已导出：%s\n', SvgPath);