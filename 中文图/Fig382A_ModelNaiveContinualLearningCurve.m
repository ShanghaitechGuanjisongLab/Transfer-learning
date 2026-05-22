% Fig382C model-simulated Naive/Continual learning curve with sigmoid fits.

svgName = '中文图Fig382C_ModelNaiveContinualLearningCurve.svg';
iEnsureTransferLearningProject();

run(fullfile(fileparts(mfilename('fullpath')), 'Fig382383_LoadSharedModelData.m'));
Params = Fig382383Data.Params;
RunInfo = Fig382383Data.RunInfo;
naivePerformance = Fig382383Data.Performance.Naive;
continualPerformance = Fig382383Data.Performance.Transfer;

[fig, ~] = TransferLearning.PlotSigmoidLearningCurvePanels( ...
	naivePerformance, continualPerformance, ...
	"Naive", "Transfer", "Naive", "Continual", ...
	FigureName="Fig382C model Naive Continual sigmoid", ...
	FigureSizeCm=[9, 8], ...
	Scale=2, ...
	NPermutation=0);
SigmoidStats = Fig382383Data.Sigmoid.Fig382C;
iPrintPermutationResult('Fig382C', SigmoidStats);
iAssertSigmoidSlopeSignificant('Fig382C', SigmoidStats, Params.TransferHighestAlpha, fig);

svgPath = TransferLearning.StandardFigureSvgPath(svgName);
print(fig, svgPath, '-dsvg');
fprintf('Wrote: %s\n', svgPath);

assignin('base', 'Fig382C_ModelNaiveContinualPerformance', struct('Naive', naivePerformance, 'Continual', continualPerformance));
assignin('base', 'Fig382C_ModelNaiveContinualRunInfo', RunInfo);
assignin('base', 'Fig382C_ModelNaiveContinualSigmoidStats', SigmoidStats);

function iPrintPermutationResult(figureLabel, SigmoidStats)
comparison = SigmoidStats.ComparisonTable;
fprintf('%s permutation slope difference (%s): %.4f\n', figureLabel, comparison.Comparison(1), comparison.ObservedSlopeDifference(1));
fprintf('%s permutation two-sided p = %.4g (%d permutations)\n', figureLabel, comparison.PValueTwoSided(1), comparison.NPermutation(1));
end

function iAssertSigmoidSlopeSignificant(figureLabel, SigmoidStats, alpha, fig)
comparison = SigmoidStats.ComparisonTable;
observedDifference = comparison.ObservedSlopeDifference(1);
pValue = comparison.PValueTwoSided(1);
if observedDifference > 0 && pValue < alpha
	return;
end
if isgraphics(fig)
	close(fig);
end
error('Fig382C:SigmoidSlopeNotSignificant', ...
	'%s requires Transfer sigmoid slope to be significantly greater than Naive (alpha=%.3f). %s observed difference=%.4f, two-sided permutation p=%.4g.', ...
	figureLabel, alpha, char(comparison.Comparison(1)), observedDifference, pValue);
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
