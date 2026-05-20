% Fig381B schematic excitatory/inhibitory neuron fraction pie.

iEnsureTransferLearningProject();

Params = TransferLearning.THModel.DefaultParams();
excitatoryTotal = Params.NL23 + Params.NL5RewardRecv + Params.NL5Read;
inhibitoryTotal = Params.NIL23 + Params.NIL5RewardRecv + Params.NIL5Read;
cellCounts = [excitatoryTotal, inhibitoryTotal];
sliceColors = [47, 93, 168; 176, 65, 74] ./ 255;

fig = figure('Color', 'w', 'Units', 'centimeters', 'Position', [3, 3, 3, 4]);
fig.PaperUnits = 'centimeters';
fig.PaperPositionMode = 'manual';
fig.PaperPosition = [0, 0, 2.99, 3.99];
fig.PaperSize = [2.99, 3.99];
chartAxes = axes(fig);
pieHandles = pie(chartAxes, cellCounts);
axis(chartAxes, 'equal');
axis(chartAxes, 'off');
xlim(chartAxes, [-1.95, 1.95]);
ylim(chartAxes, [-1.48, 1.34]);

patchHandles = pieHandles(1:2:end);
for patchIndex = 1:numel(patchHandles)
	patchHandles(patchIndex).FaceColor = sliceColors(patchIndex, :);
	patchHandles(patchIndex).EdgeColor = 'w';
	patchHandles(patchIndex).LineWidth = 1;
end

textHandles = pieHandles(2:2:end);
for textIndex = 1:numel(textHandles)
	delete(textHandles(textIndex));
end

text(chartAxes, -1.46, -0.86, sprintf('Exc.\n%d cells', excitatoryTotal), 'HorizontalAlignment', 'center', 'VerticalAlignment', 'middle', 'FontName', 'Arial', 'FontWeight', 'bold', 'Color', [0.12, 0.14, 0.17]);
text(chartAxes, 1.46, 0.70, sprintf('Inh.\n%d cells', inhibitoryTotal), 'HorizontalAlignment', 'center', 'VerticalAlignment', 'middle', 'FontName', 'Arial', 'FontWeight', 'bold', 'Color', [0.12, 0.14, 0.17]);
title(chartAxes, 'E/I cells');
svgPath = TransferLearning.ExportStandardFigure(fig, 1, '中文图Fig381B_NeuronTypePie.svg');
fprintf('Wrote: %s\n', svgPath);
assignin('base', 'Fig381B_NeuronTypePieSvgPath', svgPath);

function iEnsureTransferLearningProject()
if ~exist('TransferLearning', 'class')
	thisFile = mfilename('fullpath');
	thisDir = fileparts(thisFile);
	projectFile = fullfile(thisDir, '..', 'Transferlearning.prj');
	if exist(projectFile, 'file')
		matlab.project.loadProject(projectFile);
	end
end
end