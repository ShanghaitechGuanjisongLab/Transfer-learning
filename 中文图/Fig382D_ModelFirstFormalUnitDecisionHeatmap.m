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

if evalin('base', 'exist(''Fig382D_ModelDecisionHeatmapSeeds'', ''var'')')
	seedValues = evalin('base', 'Fig382D_ModelDecisionHeatmapSeeds');
else
	seedValues = [38204101, 38204102];
end

Params = TransferLearning.THModel.DefaultParams();
Params = TransferLearning.THModel.ApplyBaseParameterOverrides(Params);
Cond = TransferLearning.THModel.ConditionTable();
[HeatmapData, RunInfo] = TransferLearning.THModel.FirstFormalUnitDecisionHeatmapData(Params, Cond, seedValues);

[fig, PlotData] = TransferLearning.PlotModelFirstFormalUnitDecisionHeatmap(HeatmapData);
svgPath = TransferLearning.ExportStandardFigure(fig, 2, svgName);
fprintf('Wrote: %s\n', svgPath);

assignin('base', 'Fig382D_ModelDecisionHeatmapData', HeatmapData);
assignin('base', 'Fig382D_ModelDecisionHeatmapRunInfo', RunInfo);
assignin('base', 'Fig382D_ModelDecisionHeatmapPlotData', PlotData);
assignin('base', 'Fig382D_ModelDecisionHeatmapSvgPath', svgPath);
