% Sensitivity analysis: Fig1C histograms using Fig1H learning-speed fits.
% Keep Fig1C cohorts, block definitions, k/4 display, and Welch tests on
% log(k); replace only the per-mouse learning-speed algorithm.
%
% Fig1H algorithm: fit session/block mean hit rates by unpenalized least
% squares with free lower asymptote and slope, upper asymptote fixed to 1,
% and free midpoint. Mice with fewer than two blocks or constant block
% performance are excluded. This script does not overwrite the main Fig1C.

[Curves,~] = TransferLearning.BuildIntervalBehaviorCurves();
Fig1C_Fig1HFit = iFitFig1HSlopes(Curves);
Fig1C_Fig1HFit.ProbSlope = Fig1C_Fig1HFit.Slope/4;
Fig1C_Fig1HStats = iCompareSlopes(Fig1C_Fig1HFit);

Fig1C_OriginalResult = TransferLearning.ComparePenalizedSigmoidSlopes( ...
	50000,table(),FixLowerZero=true);
Original = Fig1C_OriginalResult.Pairwise(:, ...
	{'Comparison','N1','N2','MedianSlope1','MedianSlope2','WelchPValue','WelchDF'});
Fig1C_SlopeAlgorithmComparison = outerjoin(Original,Fig1C_Fig1HStats, ...
	'Keys','Comparison','MergeKeys',true, ...
	'LeftVariables',{'Comparison','N1','N2','MedianSlope1','MedianSlope2','WelchPValue','WelchDF'}, ...
	'RightVariables',{'Comparison','N1','N2','MedianSlope1','MedianSlope2','WelchPValue','WelchDF'});
Fig1C_SlopeAlgorithmComparison.Properties.VariableNames = ...
	{'Comparison','OriginalN1','OriginalN2','OriginalMedianSlope1', ...
	'OriginalMedianSlope2','OriginalWelchP','OriginalWelchDF', ...
	'Fig1HN1','Fig1HN2','Fig1HMedianSlope1','Fig1HMedianSlope2', ...
	'Fig1HWelchP','Fig1HWelchDF'};

disp('=== Fig1C using Fig1H learning-speed algorithm ===');
disp(Fig1C_Fig1HStats);
disp('=== Original penalized-trial algorithm versus Fig1H algorithm ===');
disp(Fig1C_SlopeAlgorithmComparison);

colors = containers.Map(["Naive","Interspersed","12h","7d"], ...
	{TransferLearning.NaiveColor,TransferLearning.TransferColor, ...
	TransferLearning.TransferColor,TransferLearning.TransferColor});
labels = containers.Map(["Naive","Interspersed","12h","7d"], ...
	{"Naive","Interspersed","12 h","7 d"});
comparisons = ["Interspersed - Naive","12h - Naive","7d - Naive"];

f = figure('Color','w','Name','Fig1C using Fig1H learning-speed algorithm');
f.Units = 'centimeters';
f.Position(3:4) = [12,8];
layout = tiledlayout(f,1,3,'TileSpacing','tight','Padding','tight');
xlabel(layout,'Normalized slope');
ylabel(layout,'Mice (proportion)');
xPool = Fig1C_Fig1HFit.ProbSlope;
nBins = min(8,max(4,ceil(sqrt(numel(xPool)))));
edges = linspace(min(xPool)-0.05*range(xPool), ...
	max(xPool)+0.05*range(xPool),nBins+1);
Axes = gobjects(1,numel(comparisons));
for i = 1:numel(comparisons)
	comparison = comparisons(i);
	g2 = extractBefore(comparison," - ");
	xNaive = Fig1C_Fig1HFit.ProbSlope(Fig1C_Fig1HFit.Group == "Naive");
	xOther = Fig1C_Fig1HFit.ProbSlope(Fig1C_Fig1HFit.Group == g2);
	ax = nexttile(layout);
	hold(ax,'on');
	h1 = histogram(ax,xNaive,edges,'Normalization','probability', ...
		'FaceColor',colors("Naive"),'FaceAlpha',1/3,'EdgeColor','none');
	h2 = histogram(ax,xOther,edges,'Normalization','probability', ...
		'FaceColor',colors(g2),'FaceAlpha',1/3,'EdgeColor','none');
	xline(ax,median(xNaive),'--','Color',colors("Naive"),'HandleVisibility','off');
	xline(ax,median(xOther),'--','Color',colors(g2),'HandleVisibility','off');
	statsRow = Fig1C_Fig1HStats(Fig1C_Fig1HStats.Comparison == comparison,:);
	title(ax,sprintf('p = %.3g',statsRow.WelchPValue));
	legend(ax,[h1,h2],{'Naive',labels(g2)}, ...
		'Location','northoutside','Box','off','Orientation','vertical');
	Axes(i) = ax;
	if i > 1
		ax.YAxis.Visible = false;
	end
	xticks([0,0.3,0.6,0.9]);
end
MATLAB.Graphics.UnifyAxesLims(Axes,@ylim);
svgPath = TransferLearning.ExportStandardFigure(f,2, ...
	'English_Fig1C_Fig1HSlopeAlgorithm_SlopeHistogram.svg');
fprintf('Wrote: %s\n',svgPath);

function Fit = iFitFig1HSlopes(Curves)
Curves.Group = string(Curves.Group);
Curves.Mouse = string(Curves.Mouse);
Curves = sortrows(Curves,{'Group','Mouse','DateTime'});
[G,group,mouse] = findgroups(Curves.Group,Curves.Mouse);
nMice = max(G);
Group = strings(nMice,1);
Mouse = strings(nMice,1);
Lower = nan(nMice,1);
Slope = nan(nMice,1);
Midpoint = nan(nMice,1);
RSquared = nan(nMice,1);
NBlocks = zeros(nMice,1);
keep = false(nMice,1);
for i = 1:nMice
	Q = sortrows(Curves(G == i,:),'DateTime');
	x = double(Q.Block(:));
	y = double(Q.Performance(:));
	valid = isfinite(x) & isfinite(y);
	x = x(valid);
	y = y(valid);
	Group(i) = group(i);
	Mouse(i) = mouse(i);
	NBlocks(i) = numel(x);
	if numel(x) < 2 || numel(unique(y)) < 2
		continue;
	end
	p0 = [iLogit(max(min(min(y),0.45),0.01));log(0.8);max(median(x),1)];
	objective = @(p) sum((y-iSigmoid(p,x)).^2,'omitnan');
	options = optimset('Display','off','MaxFunEvals',10000,'MaxIter',10000);
	p = fminsearch(objective,p0,options);
	yHat = iSigmoid(p,x);
	sse = sum((y-yHat).^2,'omitnan');
	sst = sum((y-mean(y,'omitnan')).^2,'omitnan');
	Lower(i) = 1/(1+exp(-p(1)));
	Slope(i) = exp(p(2));
	Midpoint(i) = p(3);
	if sst > 0
		RSquared(i) = 1-sse/sst;
	end
	keep(i) = true;
end
Fit = table(Group(keep),Mouse(keep),NBlocks(keep),Lower(keep),Slope(keep), ...
	Midpoint(keep),RSquared(keep),'VariableNames', ...
	{'Group','Mouse','NBlocks','Lower','Slope','Midpoint','RSquared'});
Fit = sortrows(Fit,{'Group','Mouse'});
end

function Stats = iCompareSlopes(Fit)
comparisons = ["Interspersed - Naive";"12h - Naive";"7d - Naive"];
Stats = table();
for comparison = comparisons.'
	g2 = extractBefore(comparison," - ");
	x1 = log(Fit.Slope(Fit.Group == "Naive"));
	x2 = log(Fit.Slope(Fit.Group == g2));
	[~,p,~,test] = ttest2(x2,x1,'Vartype','unequal');
	Stats = [Stats;table(comparison,numel(x1),numel(x2),median(exp(x1)), ...
		median(exp(x2)),mean(x2)-mean(x1),p,test.df,'VariableNames', ...
		{'Comparison','N1','N2','MedianSlope1','MedianSlope2', ...
		'MeanLogSlopeDifference','WelchPValue','WelchDF'})]; %#ok<AGROW>
end
Stats.WelchPValueHolm = iHolm(Stats.WelchPValue);
end

function adjusted = iHolm(p)
[sorted,order] = sort(p);
n = numel(p);
sortedAdjusted = min(cummax((n:-1:1).'.*sorted),1);
adjusted = nan(size(p));
adjusted(order) = sortedAdjusted;
end

function y = iSigmoid(p,x)
lower = 1/(1+exp(-p(1)));
slope = exp(p(2));
midpoint = p(3);
y = lower+(1-lower)./(1+exp(-slope.*(x-midpoint)));
end

function y = iLogit(x)
x = min(max(x,1e-6),1-1e-6);
y = log(x./(1-x));
end
