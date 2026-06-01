% Fig55B model before-formal connection-type weight SD bars.

svgName = '中文图Fig55B_PreFormalConnectionWeightStdBars.svg';
if ~exist('TransferLearning', 'class')
	thisFile = mfilename('fullpath');
	thisDir = fileparts(thisFile);
	projectFile = fullfile(thisDir, '..', 'Transferlearning.prj');
	if exist(projectFile, 'file')
		matlab.project.loadProject(projectFile);
	end
end

run(fullfile(fileparts(mfilename('fullpath')), 'Fig5556_LoadSharedModelData.m'));
WeightValues = Fig5556Data.PreFormalWeightValues;
RunInfo = Fig5556Data.RunInfo;
%%

[fig, SummaryTable] = TransferLearning.PlotPreFormalConnectionWeightStdBars(WeightValues);
svgPath = TransferLearning.ExportStandardFigure(fig, 2, svgName);
fprintf('Wrote: %s\n', svgPath);

assignin('base', 'Fig55B_PreFormalWeightValues', WeightValues);
assignin('base', 'Fig55B_PreFormalWeightRunInfo', RunInfo);
assignin('base', 'Fig55B_PreFormalWeightSummary', SummaryTable);
assignin('base', 'Fig55B_PreFormalWeightSvgPath', svgPath);