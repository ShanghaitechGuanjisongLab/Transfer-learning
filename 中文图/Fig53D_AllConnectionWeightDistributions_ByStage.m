% Fig54 model all-connection weight distributions by stage.

if ~exist('TransferLearning', 'class')
	thisFile = mfilename('fullpath');
	thisDir = fileparts(thisFile);
	projectFile = fullfile(thisDir, '..', 'Transferlearning.prj');
	if exist(projectFile, 'file')
		matlab.project.loadProject(projectFile);
	end
end

run(fullfile(fileparts(mfilename('fullpath')), 'Fig5556_LoadSharedModelData.m'));

[StageWeightValues, StageRunInfo] = TransferLearning.THModel.PretrainStageAllConnectionWeights(Fig5556Data.Params, Fig5556Data.Cond, Fig5556Data.RunInfo);
%% 
fig = TransferLearning.PlotAllConnectionWeightDistributionsByStage(StageWeightValues);
%% 
svgName = '中文图Fig53D_AllConnectionWeightDistributions_ByStage.svg';
svgPath = TransferLearning.ExportStandardFigure(fig, 1, svgName);
fprintf('Wrote: %s\n', svgPath);