% Fig54A model pre-formal connection weight distributions.

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

fig = TransferLearning.PlotPreFormalConnectionWeightDistributions(WeightValues);
svgName = '中文图Fig54A_PreFormalConnectionWeightDistributions.svg';
svgPath = TransferLearning.ExportStandardFigure(fig, 2, svgName);
fprintf('Wrote: %s\n', svgPath);