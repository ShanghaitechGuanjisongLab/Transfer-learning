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

[fig, SummaryTable] = TransferLearning.PlotPreFormalConnectionWeightStdBars(WeightValues, Cond);
svgPath = TransferLearning.ExportStandardFigure(fig, 2, svgName);
fprintf('Wrote: %s\n', svgPath);

assignin('base', 'Fig382B_PreFormalWeightValues', WeightValues);
assignin('base', 'Fig382B_PreFormalWeightRunInfo', RunInfo);
assignin('base', 'Fig382B_PreFormalWeightSummary', SummaryTable);
assignin('base', 'Fig382B_PreFormalWeightSvgPath', svgPath);