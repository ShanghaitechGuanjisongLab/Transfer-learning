% Fig383B model-simulated Continual/TH inhibited learning curve with sigmoid fits.

svgName = '中文图Fig383B_ModelContinualTHInhibitedLearningCurve.svg';
iEnsureTransferLearningProject();

run(fullfile(fileparts(mfilename('fullpath')), 'Fig382383_LoadSharedModelData.m'));
RunInfo = Fig382383Data.RunInfo;
continualPerformance = Fig382383Data.Performance.Transfer;
thInhibitedPerformance = Fig382383Data.Performance.THOff;
%% 

[fig, ~] = TransferLearning.PlotSigmoidLearningCurvePanels( ...
	continualPerformance, thInhibitedPerformance, ...
	"Transfer", "THOff", "Continual", "TH inhibited", ...
	FigureName="Fig383B model Continual TH inhibited sigmoid", ...
	FigureSizeCm=[9, 8], ...
	Scale=2, ...
	LegendPanel="A", ...
	NPermutation=0);
SigmoidStats = Fig382383Data.Sigmoid.Fig383B;
iPrintPermutationResult('Fig383B', SigmoidStats);

svgPath = TransferLearning.StandardFigureSvgPath(svgName);
print(fig, svgPath, '-dsvg');
fprintf('Wrote: %s\n', svgPath);

assignin('base', 'Fig383B_ModelContinualTHInhibitedPerformance', struct('Continual', continualPerformance, 'THInhibited', thInhibitedPerformance));
assignin('base', 'Fig383B_ModelContinualTHInhibitedRunInfo', RunInfo);
assignin('base', 'Fig383B_ModelContinualTHInhibitedSigmoidStats', SigmoidStats);
assignin('base', 'Fig383B_ModelContinualTHInhibitedSvgPath', svgPath);

function iPrintPermutationResult(figureLabel, SigmoidStats)
comparison = SigmoidStats.ComparisonTable;
fprintf('%s permutation slope difference (%s): %.4f\n', figureLabel, comparison.Comparison(1), comparison.ObservedSlopeDifference(1));
fprintf('%s permutation two-sided p = %.4g (%d permutations)\n', figureLabel, comparison.PValueTwoSided(1), comparison.NPermutation(1));
end

function iEnsureTransferLearningProject()
if ~exist('TransferLearning', 'class')
	thisFile = mfilename('fullpath');
	thisDir = fileparts(thisFile);
	projectFile = fullfile(thisDir, '..', 'Transferlearning.prj');
	if exist(projectFile, 'file')
		matlab.project.loadProject(projectFile);
	end
end
end
