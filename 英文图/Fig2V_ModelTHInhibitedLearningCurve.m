% 英文图2V：重制中文Fig63D，沿用Transfer和THOff模型表现及原统计。
ThisDir = fileparts(mfilename('fullpath'));
if ~exist('TransferLearning', 'class')
	matlab.project.loadProject(fullfile(ThisDir, '..', 'Transferlearning.prj'));
end
ModelData = TransferLearning.LoadRnnFigureData();
Colors = [TransferLearning.Curve12h; TransferLearning.CurveTH] / 255;
[Figure, Stats] = TransferLearning.PlotRnnLearningCurve(ModelData.Performance.Transfer, ModelData.Performance.THOff, ModelData.Sigmoid.Fig383D, ["Transfer", "TH inhibited"], Colors);
Figure.Name = 'English Fig2V model TH inhibited learning';
SvgPath = TransferLearning.ExportStandardFigure(Figure, 2, 'English_Fig2V_ModelTHInhibitedLearningCurve.svg');
assignin('base', 'Fig2V_ModelStats', Stats);
fprintf('已导出：%s\n', SvgPath);