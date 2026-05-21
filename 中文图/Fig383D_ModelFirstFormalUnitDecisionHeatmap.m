% Fig383D model first formal training unit decision-iteration heatmap.

svgName = '中文图Fig383D_ModelFirstFormalUnitDecisionHeatmap.svg';
if ~exist('TransferLearning', 'class')
	thisFile = mfilename('fullpath');
	thisDir = fileparts(thisFile);
	projectFile = fullfile(thisDir, '..', 'Transferlearning.prj');
	if exist(projectFile, 'file')
		matlab.project.loadProject(projectFile);
	end
end

if evalin('base', 'exist(''Fig383D_ModelDecisionHeatmapSeeds'', ''var'')')
	seedValues = evalin('base', 'Fig383D_ModelDecisionHeatmapSeeds');
else
	seedValues = [38304101, 38304102];
end

Params = TransferLearning.THModel.DefaultParams();
Params = TransferLearning.THModel.ApplyBaseParameterOverrides(Params);
Cond = TransferLearning.THModel.ConditionTable();
[HeatmapData, RunInfo] = TransferLearning.THModel.FirstFormalUnitDecisionHeatmapData(Params, Cond, seedValues, ["Transfer", "THOff"], ["Continual", "TH inhibited"]);

[fig, PlotData] = TransferLearning.PlotModelFirstFormalUnitDecisionHeatmap(HeatmapData);
svgPath = TransferLearning.ExportStandardFigure(fig, 2, svgName);
fprintf('Wrote: %s\n', svgPath);

assignin('base', 'Fig383D_ModelDecisionHeatmapData', HeatmapData);
assignin('base', 'Fig383D_ModelDecisionHeatmapRunInfo', RunInfo);
assignin('base', 'Fig383D_ModelDecisionHeatmapPlotData', PlotData);
assignin('base', 'Fig383D_ModelDecisionHeatmapSvgPath', svgPath);
