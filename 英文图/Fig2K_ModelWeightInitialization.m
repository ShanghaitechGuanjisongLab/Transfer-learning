% 英文图2K：重制中文Fig381C的三角形初始化权重分布示意。
ThisDir = fileparts(mfilename('fullpath'));
if ~exist('TransferLearning', 'class')
	matlab.project.loadProject(fullfile(ThisDir, '..', 'Transferlearning.prj'));
end
Params = TransferLearning.THModel.DefaultParams();
Bounds = [Params.InitWeightMin, Params.WeightMax];
Density = [2/diff(Bounds), 0];
Figure = figure(Color='w', Name='English Fig2K weight initialization', Units='centimeters');
Figure.Position(3:4) = [3 3];
plot(Bounds, Density, Color=TransferLearning.CurveLearned/255, LineWidth=1);
xline(0, ':', Color=[0.4 0.4 0.4]);
xlabel('Weight');
ylabel('Probability density');
title('Weight initialization');
SvgPath = TransferLearning.ExportStandardFigure(Figure, 1, 'English_Fig2K_ModelWeightInitialization.svg');
assignin('base', 'Fig2K_ModelWeightInitialization', struct('Bounds', Bounds, 'Density', Density, 'SvgPath', SvgPath));