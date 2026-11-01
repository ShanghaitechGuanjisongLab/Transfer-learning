% English Fig4E: 12-h control versus combined TH-inhibition cohort.
% Single-panel, per-mouse penalized-sigmoid slope histograms, following Fig1C.
%
% 12 h: all audio-to-light 12-h behavior cohorts used by Fig1C.
% TH inhibited: TransferLearning.THInhibit imaging mice plus PO behavior-only
% mice (Design="LightWater", Expression="溢出", Recall excluded).
%
% Trial-level model per mouse:
%   p(hit|block) = 1/(1+exp(-k*(block-midpoint)))
% The lower asymptote is fixed to zero. The objective includes the
% Jeffreys/Fisher-information penalty and weak log(k)~N(0,2^2) penalty.
% Welch's unequal-variance t-test is performed on log(k). For display,
% normalized slope is k/4, the maximum hit-rate increase per block.
%
% Run as a script in MATLAB Editor.

[IntervalCurves,IntervalTrials] = TransferLearning.BuildIntervalBehaviorCurves();
controlTrials = IntervalTrials(IntervalTrials.Group == "12h",:);
controlCurves = IntervalCurves(IntervalCurves.Group == "12h",:);
controlTrials = innerjoin(controlTrials, ...
	controlCurves(:,{'Group','Mouse','DateTime','Block'}), ...
	'Keys',{'Group','Mouse','DateTime'});
thImagingTrials = TransferLearning.BuildTHInhibitTrialTable();
thBehaviorTrials = TransferLearning.BuildPOBehaviorTrialTable();
commonVariables = {'Group','Mouse','DateTime','Block','Behavior','Source'};
trialTable = [controlTrials(:,commonVariables); ...
	thImagingTrials(:,commonVariables); thBehaviorTrials(:,commonVariables)];

Fig4E_PenalizedSlopeResult = TransferLearning.ComparePenalizedSigmoidSlopes( ...
	50000,trialTable,FixLowerZero=true);
R = Fig4E_PenalizedSlopeResult;
R.PerMouse.ProbSlope = R.PerMouse.Slope/4;

xControl = R.PerMouse.ProbSlope( ...
	R.PerMouse.Group == "12h" & R.PerMouse.FitEligible);
xTH = R.PerMouse.ProbSlope( ...
	R.PerMouse.Group == "THInhibit" & R.PerMouse.FitEligible);
assert(~isempty(xControl) && ~isempty(xTH), ...
	'English_Fig4E:EmptyEligibleGroup', ...
	'Both groups must contain eligible per-mouse sigmoid fits.');
xPool = [xControl;xTH];
nBins = min(8,max(4,ceil(sqrt(numel(xPool)))));
edges = linspace(min(xPool)-0.05*range(xPool), ...
	max(xPool)+0.05*range(xPool),nBins+1);
statsRow = R.Pairwise(R.Pairwise.Comparison == "THInhibit - 12h",:);
assert(height(statsRow) == 1,'English_Fig4E:MissingComparison', ...
	'The THInhibit versus 12-h comparison was not found.');

f = figure('Color','w','Name','English Fig4E TH inhibition versus 12 h');
f.Units = 'centimeters';
f.Position(3:4) = [6,8];
ax = axes(f);
hold(ax,'on');
controlColor = TransferLearning.TransferColor;
thColor = TransferLearning.ColorB;
hControl = histogram(ax,xControl,edges,'Normalization','probability', ...
	'FaceColor',controlColor,'FaceAlpha',1/3,'EdgeColor','none');
hTH = histogram(ax,xTH,edges,'Normalization','probability', ...
	'FaceColor',thColor,'FaceAlpha',1/3,'EdgeColor','none');
xline(ax,median(xControl),'--','Color',controlColor,'HandleVisibility','off');
xline(ax,median(xTH),'--','Color',thColor,'HandleVisibility','off');
xlabel(ax,'Normalized slope');
ylabel(ax,'Mice (proportion)');
title(ax,sprintf('p = %.3g',statsRow.WelchPValue));
legend(ax,[hControl,hTH],{'12 h','TH inhibited'}, ...
	'Location','northoutside','Box','off','Orientation','vertical');
box(ax,'off');

svgPath = TransferLearning.ExportStandardFigure(f,2, ...
	'English_Fig4E_THInhibitVs12h_PenalizedSigmoidSlopeHistogram.svg');
fprintf('Wrote: %s\n',svgPath);
fprintf('12 h: n=%d eligible mice, median k=%.4g, median k/4=%.4g\n', ...
	numel(xControl),statsRow.MedianSlope1,median(xControl));
fprintf('TH inhibited (imaging + PO behavior): n=%d eligible mice, median k=%.4g, median k/4=%.4g\n', ...
	numel(xTH),statsRow.MedianSlope2,median(xTH));
fprintf('Welch unequal-variance t-test on log(k): p=%.6g, df=%.4g\n', ...
	statsRow.WelchPValue,statsRow.WelchDF);
fprintf('Mouse-label median-permutation test: raw p=%.6g\n',statsRow.PValue);

assignin('base','Fig4E_PenalizedSlopeResult',R);
assignin('base','Fig4E_TrialTable',trialTable);
assignin('base','Fig4E_SvgPath',svgPath);
