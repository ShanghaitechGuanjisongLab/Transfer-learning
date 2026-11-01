% English Fig1C: per-mouse penalized-sigmoid learning-slope histograms.
%
% Model per mouse, using individual trial outcomes:
%   p(hit|block) = L + (1-L)/(1+exp(-k*(block-midpoint)))
% Lower asymptote is fixed to L=0 for every mouse; slope k and midpoint m
% are free. Penalized binomial likelihood: Jeffreys/Fisher-information term
% plus weak log(k)~N(0,2^2) penalty. Between-group Welch t-tests on log(k);
% raw p values only are displayed in the three pairwise histograms.
%
% 单位与换算：x 轴 Block = 每鼠会话序号（一会话≈一天，~30 trial），故 k 是
% log-odds 斜率/会话，不是概率增量。作图前换算到概率空间：概率瞬时斜率
% dp/dx = k*p*(1-p)，最陡点(p=0.5)即 s = k/4，也就是每会话命中率的最大增量
% （k=2 → 每会话最多 +0.50 = 50 个百分点；10%%→90%% 过渡需 4.39/k 个会话）。
% 组间检验仍用 log(k)：log(k/4) = log(k) - log 4，p 值与排序完全不变。
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
% 作图量换算到概率空间：ProbSlope = k/4（每会话最大命中率增量，见文件头）
R.PerMouse.ProbSlope = R.PerMouse.Slope / 4;
PenalizedSlopeResult = R;
colors = containers.Map(["Naive","Interspersed","12h","7d"], ...
	{TransferLearning.NaiveColor,TransferLearning.TransferColor, ...
	TransferLearning.TransferColor,TransferLearning.TransferColor});
labels = containers.Map(["Naive","Interspersed","12h","7d"], ...
	{"Naive","Interspersed","12 h","7 d"});
comparisons = ["Interspersed - Naive","12h - Naive","7d - Naive"];
%% 

f = figure('Color','w');
f.Units = 'centimeters';
f.Position(3:4) = [12,8];
layout = tiledlayout(f,1,3,'TileSpacing','tight','Padding','tight');
xlabel(layout,'Normalized slope');
ylabel(layout,'Mice (proportion)');
% 三 tile 共用同一分箱：把四个组所有 eligible 鼠的 ProbSlope 池在一起，
% 统一算一次 nBins 与 edges，保证三个直方图 x 轴逐 bin 可直接对比
xPool = [];
for g = ["Naive","Interspersed","12h","7d"]
	xPool = [xPool; R.PerMouse.ProbSlope(R.PerMouse.Group == g & R.PerMouse.FitEligible)]; %#ok<AGROW>
end
nBins = min(8,max(4,ceil(sqrt(numel(xPool)))));
edges = linspace(min(xPool)-0.05*range(xPool),max(xPool)+0.05*range(xPool),nBins+1);
NumComparisons=numel(comparisons);
Axes=gobjects(1,NumComparisons);
for i = 1:NumComparisons
	comparison = comparisons(i);
	g2 = extractBefore(comparison," - ");
	xNaive = R.PerMouse.ProbSlope(R.PerMouse.Group == "Naive" & R.PerMouse.FitEligible);
	xOther = R.PerMouse.ProbSlope(R.PerMouse.Group == g2 & R.PerMouse.FitEligible);
	ax = nexttile(layout);
	hold(ax,'on');
	h1 = histogram(ax,xNaive,edges,'Normalization','probability', ...
		'FaceColor',colors("Naive"),'FaceAlpha',1/3, ...
		'EdgeColor','none');
	h2 = histogram(ax,xOther,edges,'Normalization','probability', ...
		'FaceColor',colors(g2),'FaceAlpha',1/3, ...
		'EdgeColor','none');
	xline(ax,median(xNaive),'--','Color',colors("Naive"), ...
		'HandleVisibility','off');
	xline(ax,median(xOther),'--','Color',colors(g2), ...
		'HandleVisibility','off');
	statsRow = R.Pairwise(R.Pairwise.Comparison == comparison,:);
	assert(height(statsRow) == 1);
	title(ax,sprintf('p = %.3g',statsRow.WelchPValue));
	legend(ax,[h1,h2],{'Naive', ...
		labels(g2)}, ...
		'Location','northoutside','Box','off','Orientation','vertical');
	Axes(i)=ax;
	if i>1
		ax.YAxis.Visible=false;
	end
	xticks([0,0.3,0.6,0.9]);
end
MATLAB.Graphics.UnifyAxesLims(Axes,@ylim);
svgPath = TransferLearning.ExportStandardFigure(f,2, ...
	'English_Fig1C_PenalizedSigmoidSlopeHistogram.svg');
fprintf('Wrote: %s\n',svgPath);