% 英文图3L：重制中文Fig63D，沿用Transfer和THOff模型表现及原统计（原英文图2V）。
ThisDir = fileparts(mfilename('fullpath'));
if ~exist('TransferLearning', 'class')
	matlab.project.loadProject(fullfile(ThisDir, '..', 'Transferlearning.prj'));
end
ModelData = TransferLearning.LoadRnnFigureData();
Colors = [TransferLearning.Color12h; TransferLearning.ColorTH] / 255;
[Figure, Stats] = TransferLearning.PlotRnnLearningCurve(ModelData.Performance.Transfer, ModelData.Performance.THOff, ModelData.Sigmoid.Fig383D, ["Transfer", "TH inhibited"], Colors);
Figure.Name = 'English Fig3L model TH inhibited learning';
SvgPath = TransferLearning.ExportStandardFigure(Figure, 2, 'English_Fig3L_ModelTHInhibitedLearningCurve.svg');
assignin('base', 'Fig3L_ModelStats', Stats);
fprintf('已导出：%s\n', SvgPath);