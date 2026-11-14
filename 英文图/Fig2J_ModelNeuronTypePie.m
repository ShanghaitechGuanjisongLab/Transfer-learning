% 英文图2J：重制中文Fig381B，模型细胞数不变，使用当前Mocha蓝/红区分兴奋性和抑制性。
ThisDir = fileparts(mfilename('fullpath'));
if ~exist('TransferLearning', 'class')
	matlab.project.loadProject(fullfile(ThisDir, '..', 'Transferlearning.prj'));
end
Params = TransferLearning.THModel.DefaultParams();
ExcitatoryCount = Params.NL23 + Params.NL5RewardRecv + Params.NL5Read;
InhibitoryCount = Params.NIL23 + Params.NIL5RewardRecv + Params.NIL5Read;
CellCounts = [ExcitatoryCount, InhibitoryCount];
SliceColors = [TransferLearning.ColorMiss; TransferLearning.ColorNaive] / 255;
Labels = {sprintf('Exc.\n%d cells', ExcitatoryCount), sprintf('Inh.\n%d cells', InhibitoryCount)};

Figure = figure(Color='w', Name='English Fig2J model neuron types', Units='centimeters');
Figure.Position(3:4) = [4 4];
PieHandles = pie(CellCounts, Labels);
PieAxes = gca;
axis(PieAxes, 'equal');
axis(PieAxes, 'off');
Patches = PieHandles(1:2:end);
for SliceIndex = 1:numel(Patches)
	Patches(SliceIndex).FaceColor = SliceColors(SliceIndex, :);
	Patches(SliceIndex).EdgeColor = 'w';
end
title(PieAxes, 'E/I cells');
SvgPath = TransferLearning.ExportStandardFigure(Figure, 1, 'English_Fig2J_ModelNeuronTypePie.svg');
Fig2J_ModelNeuronTypeStats = struct('CellCounts', CellCounts, 'Colors', SliceColors, 'Figure', Figure, 'SvgPath', SvgPath);
assignin('base', 'Fig2J_ModelNeuronTypeStats', Fig2J_ModelNeuronTypeStats);
fprintf('模型兴奋/抑制细胞数：%d/%d。\n已导出：%s\n', ExcitatoryCount, InhibitoryCount, SvgPath);