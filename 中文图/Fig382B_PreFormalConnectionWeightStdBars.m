% Fig382B model before-formal connection-type weight SD bars.

svgName = '中文图Fig382B_PreFormalConnectionWeightStdBars.svg';
if ~exist('TransferLearning', 'class')
	thisFile = mfilename('fullpath');
	thisDir = fileparts(thisFile);
	projectFile = fullfile(thisDir, '..', 'Transferlearning.prj');
	if exist(projectFile, 'file')
		matlab.project.loadProject(projectFile);
	end
end

run(fullfile(fileparts(mfilename('fullpath')), 'Fig382383_LoadSharedModelData.m'));
WeightValues = Fig382383Data.PreFormalWeightValues;
RunInfo = Fig382383Data.RunInfo;
Cond = Fig382383Data.Cond;
%%

[fig, SummaryTable] = TransferLearning.PlotPreFormalConnectionWeightStdBars(WeightValues, Cond);
svgPath = TransferLearning.ExportStandardFigure(fig, 2, svgName);
fprintf('Wrote: %s\n', svgPath);

assignin('base', 'Fig382B_PreFormalWeightValues', WeightValues);
assignin('base', 'Fig382B_PreFormalWeightRunInfo', RunInfo);
assignin('base', 'Fig382B_PreFormalWeightSummary', SummaryTable);
assignin('base', 'Fig382B_PreFormalWeightSvgPath', svgPath);