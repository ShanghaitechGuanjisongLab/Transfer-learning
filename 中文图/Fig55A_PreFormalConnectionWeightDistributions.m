% Fig55A model pre-formal connection weight distributions.

svgName = '中文图Fig55A_PreFormalConnectionWeightDistributions.svg';
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

fig = TransferLearning.PlotPreFormalConnectionWeightDistributions(WeightValues);
svgPath = TransferLearning.ExportStandardFigure(fig, 2, svgName);
fprintf('Wrote: %s\n', svgPath);

assignin('base', 'Fig55A_PreFormalWeightValues', WeightValues);
assignin('base', 'Fig55A_PreFormalWeightRunInfo', RunInfo);
assignin('base', 'Fig55A_PreFormalWeightSvgPath', svgPath);
