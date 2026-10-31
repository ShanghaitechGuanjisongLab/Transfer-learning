% Visualize interval-dependent learning curves and per-mouse Firth slopes.
% Permutation p values compare whole-mouse labels, not individual trials.
if ~evalin('base',"exist('IntervalSlopeResult','var')")
	IntervalSlopeResult = TransferLearning.CompareIntervalLearningSlopes(50000);
else
	IntervalSlopeResult = evalin('base','IntervalSlopeResult');
end
R = IntervalSlopeResult;
groupNames = ["Naive","Interspersed","12h","7d"];
labels = ["Naive","Interspersed","12 h","7 d"];
colors = [TransferLearning.NaiveColor; 0.20 0.62 0.32; TransferLearning.TransferColor; 0.18 0.28 0.62];
f = figure('Color','w','Name','Interval learning slope comparison');
f.Units = 'centimeters';
f.Position(3:4) = [15,8];
f.PaperUnits = 'centimeters';
f.PaperSize = [15,8];
f.PaperPositionMode = 'auto';
layout = tiledlayout(f,1,2,'TileSpacing','compact','Padding','compact');

ax1 = nexttile(layout);
hold(ax1,'on');
legendHandles = gobjects(numel(groupNames),1);
for i = 1:numel(groupNames)
	g = groupNames(i);
	mu = nan(1,7);
	se = nan(1,7);
	for b = 1:7
		y = R.Curves.Performance(R.Curves.Group == g & R.Curves.Block == b);
		mu(b) = mean(y,'omitnan');
		se(b) = std(y,'omitnan') / sqrt(max(nnz(isfinite(y)),1));
	end
	legendHandles(i) = errorbar(ax1,1:7,mu,se,'-o','Color',colors(i,:), ...
		'MarkerFaceColor','w','MarkerSize',4,'LineWidth',1.4,'CapSize',3);
end
xlabel(ax1,'Training block');
ylabel(ax1,'Hit rate');
ylim(ax1,[0,1.05]);
box(ax1,'off');
legend(ax1,legendHandles,labels,'Location','southeast','Box','off');
title(ax1,'Observed learning curves (mean +/- SEM)','FontWeight','normal');

ax2 = nexttile(layout);
hold(ax2,'on');
for i = 1:numel(groupNames)
	g = groupNames(i);
	x = R.PerMouse.TrialLogitSlope(R.PerMouse.Group == g);
	x = x(isfinite(x));
	xJitter = i + 0.12*linspace(-1,1,numel(x));
	scatter(ax2,xJitter,x,14,colors(i,:),'filled','MarkerFaceAlpha',0.55,'MarkerEdgeAlpha',0.65);
	if ~isempty(x)
		q = prctile(x,[25,50,75]);
		plot(ax2,[i-0.22,i+0.22],[q(2),q(2)],'k-','LineWidth',1.7);
		plot(ax2,[i,i],[q(1),q(3)],'k-','LineWidth',1.3);
	end
end
xlim(ax2,[0.5,4.5]);
ax2.XTick = 1:4;
ax2.XTickLabel = labels;
ylabel(ax2,'Firth logistic slope (log-odds / block)');
title(ax2,'One point per mouse; median and IQR','FontWeight','normal');
box(ax2,'off');
text(ax2,0.03,0.97,'Two-sided mouse-label permutation; six Holm-adjusted contrasts', ...
	'Units','normalized','VerticalAlignment','top','FontSize',8);

p1 = R.TrialLogitStats.PValue(R.TrialLogitStats.Comparison == "12h - Naive");
p1h = R.TrialLogitStats.PValueHolm(R.TrialLogitStats.Comparison == "12h - Naive");
p2 = R.TrialLogitStats.PValue(R.TrialLogitStats.Comparison == "7d - 12h");
yText = max(R.PerMouse.TrialLogitSlope,[],'omitnan') * 1.07;
text(ax2,2.5,yText,sprintf('12 h vs Naive: raw p = %.3g; Holm p = %.3g',p1,p1h), ...
	'HorizontalAlignment','center','FontSize',8);
text(ax2,3.5,yText*0.92,sprintf('7 d vs 12 h: p = %.3g',p2), ...
	'HorizontalAlignment','center','FontSize',8);

if isprop(ax1,'Toolbar'), ax1.Toolbar.Visible = 'off'; end
if isprop(ax2,'Toolbar'), ax2.Toolbar.Visible = 'off'; end
svgPath = TransferLearning.ExportStandardFigure(f,2,'IntervalLearningSlopeComparison.svg');
fprintf('Wrote: %s\n',svgPath);
disp(R.TrialLogitStats);
fprintf('Random-intercept-and-slope GLME, Group x Block: p = %.6g\n',R.GroupByBlockInteractionP);
