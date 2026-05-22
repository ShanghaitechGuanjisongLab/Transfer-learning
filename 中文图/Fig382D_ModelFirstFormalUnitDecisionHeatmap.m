% Fig382D model first formal training unit decision-iteration heatmap.

svgName = '中文图Fig382D_ModelFirstFormalUnitDecisionHeatmap.svg';
if ~exist('TransferLearning', 'class')
	thisFile = mfilename('fullpath');
	thisDir = fileparts(thisFile);
	projectFile = fullfile(thisDir, '..', 'Transferlearning.prj');
	if exist(projectFile, 'file')
		matlab.project.loadProject(projectFile);
	end
end

run(fullfile(fileparts(mfilename('fullpath')), 'Fig382383_LoadSharedModelData.m'));
HeatmapData = Fig382383Data.HeatmapData;
RunInfo = Fig382383Data.HeatmapRunInfo;

[fig, PlotData] = TransferLearning.PlotModelFirstFormalUnitDecisionHeatmap(HeatmapData);
svgPath = TransferLearning.ExportStandardFigure(fig, 2, svgName);
fprintf('Wrote: %s\n', svgPath);

assignin('base', 'Fig382D_ModelDecisionHeatmapData', HeatmapData);
assignin('base', 'Fig382D_ModelDecisionHeatmapRunInfo', RunInfo);
assignin('base', 'Fig382D_ModelDecisionHeatmapPlotData', PlotData);
assignin('base', 'Fig382D_ModelDecisionHeatmapSvgPath', svgPath);
