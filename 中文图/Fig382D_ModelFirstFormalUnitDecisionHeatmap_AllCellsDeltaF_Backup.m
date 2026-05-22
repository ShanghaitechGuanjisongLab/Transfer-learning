% Fig382D backup: all-cell DeltaF heatmap before L5 response filtering.

svgName = '中文图Fig382D_ModelFirstFormalUnitDecisionHeatmap_AllCellsDeltaF_Backup.svg';
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

assignin('base', 'Fig382D_ModelDecisionHeatmapBackupData', HeatmapData);
assignin('base', 'Fig382D_ModelDecisionHeatmapBackupRunInfo', RunInfo);
assignin('base', 'Fig382D_ModelDecisionHeatmapBackupPlotData', PlotData);
assignin('base', 'Fig382D_ModelDecisionHeatmapBackupSvgPath', svgPath);
