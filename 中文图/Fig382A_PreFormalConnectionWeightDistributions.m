% Fig382A model pre-formal connection weight distributions.

svgName = '中文图Fig382A_PreFormalConnectionWeightDistributions.svg';
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

fig = TransferLearning.PlotPreFormalConnectionWeightDistributions(WeightValues, Cond);
svgPath = TransferLearning.ExportStandardFigure(fig, 2, svgName);
fprintf('Wrote: %s\n', svgPath);

assignin('base', 'Fig382A_PreFormalWeightValues', WeightValues);
assignin('base', 'Fig382A_PreFormalWeightRunInfo', RunInfo);
assignin('base', 'Fig382A_PreFormalWeightSvgPath', svgPath);
