% Fig381B schematic excitatory/inhibitory neuron fraction pie.

iEnsureTransferLearningProject();

fractions = [80, 20];
labels = {'Exc. 80%', 'Inh. 20%'};
sliceColors = [47, 93, 168; 176, 65, 74] ./ 255;

fig = figure('Color', 'w', 'Units', 'centimeters', 'Position', [3, 3, 3, 4]);
chartAxes = axes(fig);
pieHandles = pie(chartAxes, fractions);
axis(chartAxes, 'equal');
axis(chartAxes, 'off');

patchHandles = pieHandles(1:2:end);
for patchIndex = 1:numel(patchHandles)
	patchHandles(patchIndex).FaceColor = sliceColors(patchIndex, :);
	patchHandles(patchIndex).EdgeColor = 'w';
	patchHandles(patchIndex).LineWidth = 1;
end

textHandles = pieHandles(2:2:end);
for textIndex = 1:numel(textHandles)
	textHandles(textIndex).FontName = 'Arial';
	textHandles(textIndex).FontWeight = 'bold';
	textHandles(textIndex).Color = [0.12, 0.14, 0.17];
end

legend(chartAxes, patchHandles, labels, 'Location', 'southoutside', 'Orientation', 'vertical', 'Box', 'off');
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