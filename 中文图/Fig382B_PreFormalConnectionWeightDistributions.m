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

if evalin('base', 'exist(''THRandomSeed'', ''var'')')
	rng(evalin('base', 'THRandomSeed'));
else
	rng('shuffle');
end

Params = TransferLearning.THModel.DefaultParams();
Params = TransferLearning.THModel.ApplyBaseParameterOverrides(Params);
Cond = TransferLearning.THModel.ConditionTable();
seedValues = randi(2^31 - 1, Params.NumMice, 2);
[WeightValues, RunInfo] = TransferLearning.THModel.PreFormalConnectionTypeWeightDistributions(Params, Params.NumMice, seedValues);

fig = TransferLearning.PlotPreFormalConnectionWeightDistributions(WeightValues, Cond);
svgPath = TransferLearning.ExportStandardFigure(fig, 2, svgName);
fprintf('Wrote: %s\n', svgPath);

assignin('base', 'Fig382A_PreFormalWeightValues', WeightValues);
assignin('base', 'Fig382A_PreFormalWeightRunInfo', RunInfo);
assignin('base', 'Fig382A_PreFormalWeightSvgPath', svgPath);
