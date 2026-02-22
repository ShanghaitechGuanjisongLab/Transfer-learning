% English Fig4D: RSPd reuse rate vs transfer performance (per mouse × layer)
%
% Scatter plot with Spearman correlation, following Fig1K style (3×4 cm).
%
% Execution:
%   TransferLearning.英文图4.C_ReuseVsPerformance_RSPd

outDirUNC = "\\Data-Server-2\个人数据\张天夫\202601";

RSP = TransferLearning.RSPd();
xsSec = seconds(TransferLearning.Xs);
baseMask = (xsSec >= -3) & (xsSec < 0);
winMask01 = (xsSec >= 0) & (xsSec <= 1);

GLearn = RSP.QueryNTATS(struct('Phase','Learned','Stimulus','AudioWater','Design','AudioWater'), UniExp.Flags.ZScore, 1:24, UniExp.Flags.Median);
GTran  = RSP.QueryNTATS(struct('Phase','Transfer','Stimulus','LightWater','Design','LightWater'), UniExp.Flags.ZScore, 1:24, UniExp.Flags.Median);

XLearn = TransferLearning.Fig36.iNtatsData(GLearn.NTATS);
XTran  = TransferLearning.Fig36.iNtatsData(GTran.NTATS);

Summary = TransferLearning.Fig36.iRSPdReuseSummary(RSP, GLearn, GTran, XLearn, XTran, xsSec, baseMask, winMask01);
Summary.ZLayer = string(Summary.ZLayer);

% --- Merge layers: pool all mouse×layer points
x = double(Summary.ReuseRate);
y = double(Summary.TransferPerformance);
use = isfinite(x) & isfinite(y);

% --- Plot
svgName = "English_Fig4D_RSPd_Reuse_vs_Performance.svg";
f = figure('Color','w', 'Name','English Fig4D Reuse vs Perf');
f.Units = 'centimeters';
f.Position(3:4) = [3.0, 4.0];

ax = axes(f);
hold(ax,'on');
ax.FontSize = 6;
ax.Toolbar.Visible = 'off';

scatter(ax, x(use), y(use), 5, [0 0.4470 0.7410], 'LineWidth', 0.2);

% Fit line
if nnz(use) >= 2 && std(x(use),'omitnan') > 0
	b = polyfit(x(use), y(use), 1);
	xFit = [min(x(use)), max(x(use))];
	yFit = polyval(b, xFit);
	plot(ax, xFit, yFit, '-', 'Color', [0.85 0.325 0.098], 'LineWidth', 1, 'HandleVisibility','off');
end

[rho, p] = TransferLearning.Fig36.iSpearman(x(use), y(use));
if isfinite(p)
	if p < 0.001, pText = "***";
	elseif p < 0.01, pText = "**";
	elseif p < 0.05, pText = "*";
	else, pText = "n.s.";
	end
	text(ax, 0.02, 0.98, sprintf('r=%.2f%s n=%d', rho, pText, nnz(use)), ...
		'Units','normalized', 'HorizontalAlignment','left', 'VerticalAlignment','top', 'FontSize', 6);
end

box(ax,'off');
grid(ax,'off');
xlabel(ax, 'Reuse rate', 'FontSize', 6);
ylabel(ax, 'Transfer perf.', 'FontSize', 6);

% --- Export
if ~isfolder(outDirUNC), mkdir(outDirUNC); end
svgPath = fullfile(outDirUNC, svgName);
TransferLearning.PrintFigure(f, svgPath);
fprintf('Wrote: %s\n', svgPath);
