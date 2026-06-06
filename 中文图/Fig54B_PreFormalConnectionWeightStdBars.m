% Fig54B model before-formal connection-type weight SD bars.

svgName = '中文图Fig54B_PreFormalConnectionWeightStdBars.svg';
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

assignin('base', 'Fig54B_PreFormalWeightValues', WeightValues);
assignin('base', 'Fig54B_PreFormalWeightRunInfo', RunInfo);
assignin('base', 'Fig54B_PreFormalWeightSummary', SummaryTable);
assignin('base', 'Fig54B_PreFormalWeightSvgPath', svgPath);