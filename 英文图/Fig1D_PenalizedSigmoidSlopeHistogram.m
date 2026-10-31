% English Fig1D: per-mouse penalized-sigmoid learning-slope histograms.
%
% Model per mouse, using individual trial outcomes:
%   p(hit|block) = L + (1-L)/(1+exp(-k*(block-midpoint)))
% Lower asymptote is fixed to L=0 for every mouse; slope k and midpoint m
% are free. Penalized binomial likelihood: Jeffreys/Fisher-information term
% plus weak log(k)~N(0,2^2) penalty. Between-group Welch t-tests on log(k);
% raw p values only are displayed in the three pairwise histograms.
%
% Algorithm references:
%   Firth (1993), penalized likelihood for finite parameter estimates.
%   Deliano et al. (2016), trial-level logistic learning-curve estimation.
%   Levi et al. (2024), Fig. 2C, slope summary display; adapted here from
%   slope-versus-zero summaries to two-cohort overlapped count histograms.
%
% Run as a script in MATLAB Editor.

PenalizedSlopeResult_AllZeroLower = TransferLearning.ComparePenalizedSigmoidSlopes(50000,table(),FixLowerZero=true);
R = PenalizedSlopeResult_AllZeroLower;
PenalizedSlopeResult = R;
colors = containers.Map(["Naive","Interspersed","12h","7d"], ...
	{TransferLearning.NaiveColor,TransferLearning.TransferColor, ...
	TransferLearning.TransferColor,TransferLearning.TransferColor});
labels = containers.Map(["Naive","Interspersed","12h","7d"], ...
	{"Naive","Interspersed","12 h","7 d"});
comparisons = ["Interspersed - Naive","12h - Naive","7d - Naive"];

f = figure('Color','w','Name','English Fig1D penalized sigmoid slope histograms');
f.Units = 'centimeters';
f.Position(3:4) = [18,10];
f.PaperUnits = 'centimeters';
f.PaperSize = [18,10];
f.PaperPositionMode = 'auto';
layout = tiledlayout(f,1,3,'TileSpacing','compact','Padding','loose');
xlabel(layout,'Sigmoid slope');
ylabel(layout,'Mice (count)');
axesList = gobjects(numel(comparisons),1);
for i = 1:numel(comparisons)
	comparison = comparisons(i);
	g2 = extractBefore(comparison," - ");
	xNaive = R.PerMouse.Slope(R.PerMouse.Group == "Naive" & R.PerMouse.FitEligible);
	xOther = R.PerMouse.Slope(R.PerMouse.Group == g2 & R.PerMouse.FitEligible);
	xAll = [xNaive;xOther];
	nBins = min(8,max(4,ceil(sqrt(numel(xAll)))));
	edges = linspace(min(xAll)-0.05*range(xAll),max(xAll)+0.05*range(xAll),nBins+1);
	ax = nexttile(layout);
	hold(ax,'on');
	h1 = histogram(ax,xNaive,edges,'Normalization','count', ...
		'FaceColor',colors("Naive"),'FaceAlpha',1/3, ...
		'EdgeColor','none');
	h2 = histogram(ax,xOther,edges,'Normalization','count', ...
		'FaceColor',colors(g2),'FaceAlpha',1/3, ...
		'EdgeColor','none');
	xline(ax,median(xNaive),'--','Color',colors("Naive"),'LineWidth',1.6, ...
		'HandleVisibility','off');
	xline(ax,median(xOther),'--','Color',colors(g2),'LineWidth',1.6, ...
		'HandleVisibility','off');
	statsRow = R.Pairwise(R.Pairwise.Comparison == comparison,:);
	assert(height(statsRow) == 1);
	title(ax,sprintf('Welch p = %.3g',statsRow.WelchPValue),'FontWeight','normal');
	legend(ax,[h1,h2],{sprintf('Naive (n = %d)',numel(xNaive)), ...
		sprintf('%s (n = %d)',labels(g2),numel(xOther))}, ...
		'Location','northoutside','Box','off','Orientation','vertical');
	% No axis box or bar outlines; a figure-level bottom axis is added below.
	box(ax,'off');
	ax.XColor = [0 0 0];
	ax.YColor = [0 0 0];
	ax.LineWidth = 1;
	ax.Layer = 'top';
	ax.XAxis.Axle.Visible = 'off';
	axesList(i) = ax;
	if isprop(ax,'Toolbar'),ax.Toolbar.Visible = 'off';end
end
drawnow;
for ax = axesList'
	pos = ax.Position;
	annotation(f,'line',pos(1)+[0 pos(3)],pos(2)*[1 1], ...
		'Color',[0 0 0],'LineWidth',1);
end
svgPath = TransferLearning.ExportStandardFigure(f,2, ...
	'English_Fig1D_PenalizedSigmoidSlopeHistogram.svg');
fprintf('Wrote: %s\n',svgPath);

matPath = TransferLearning.CachePath('English_Fig1D_PenalizedSigmoidSlope.mat');
save(matPath,'PenalizedSlopeResult_AllZeroLower','PenalizedSlopeResult');
outDir = fileparts(matPath);
writetable(R.PerMouse,fullfile(outDir,'English_Fig1D_PenalizedSigmoidSlope_PerMouse.csv'));
writetable(R.Pairwise,fullfile(outDir,'English_Fig1D_PenalizedSigmoidSlope_Stats.csv'));
fprintf('Saved: %s\n',matPath);
disp(R.Pairwise);
