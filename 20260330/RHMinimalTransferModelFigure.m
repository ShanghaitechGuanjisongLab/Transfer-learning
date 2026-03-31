function Output = RHMinimalTransferModelFigure(Options)
arguments
	Options.LocalDir (1,1) string = string(fileparts(mfilename('fullpath')))
	Options.ServerRoot (1,1) string = "\\Data-Server-2\个人数据\张天夫"
	Options.FileStem (1,1) string = "RHMinimalTransferModelSummary"
end

Result = RHMinimalTransferModel;
T = Result.PerMouseTable;
S = Result.GroupSummary;
C = Result.CorrelationTable;

colors = [1,0,0;0,0,1;0,0,0;0,0.6809,0];
groupOrder = ["Naive", "Transfer", "THInhibit"];

metricNames = ["mean_Day1Performance", "mean_SlopeAdj"];
yLabels = ["Day 1 hit rate (%)", "SlopeAdj"];

fig = figure('Color', 'white', 'Units', 'centimeters', 'Position', [1, 1, 12, 8]);
t = tiledlayout(fig, 2, 2, 'TileSpacing', 'compact', 'Padding', 'compact');

for iMetric = 1:2
	ax = nexttile(t, iMetric);
	hold(ax, 'on');
	y = iReorderSummary(S, metricNames(iMetric), groupOrder);
	b = bar(ax, 1:3, y, 0.72, 'FaceColor', 'flat', 'EdgeColor', 'none', 'LineStyle', 'none');
	b.CData = colors(1:3, :);
	for iGroup = 1:3
		Tk = T(T.Group == groupOrder(iGroup), :);
		vals = iSelectMetric(Tk, metricNames(iMetric));
		xj = iGroup + 0.08 * randn(size(vals));
		s = scatter(ax, xj, vals, 12, 'MarkerFaceColor', colors(iGroup, :), 'MarkerEdgeColor', 'k', 'LineWidth', 0.2, 'MarkerFaceAlpha', 0.75, 'MarkerEdgeAlpha', 0.45);
		s.Marker = 'o';
		sem = std(vals, 'omitnan') ./ sqrt(sum(isfinite(vals)));
		line(ax, [iGroup, iGroup], [y(iGroup), y(iGroup) + sem], 'Color', [0, 0, 0], 'LineWidth', 1);
	end
	set(ax, 'XTick', 1:3, 'XTickLabel', groupOrder, 'FontSize', 6, 'LineWidth', 1, 'Box', 'off', 'Color', 'white');
	ax.Toolbar.Visible = 'off';
	ylabel(ax, yLabels(iMetric), 'FontSize', 6);
	xlim(ax, [0.4, 3.6]);
	axis(ax, 'square');
	if iMetric == 1
		title(ax, 'Model group summary', 'FontSize', 6, 'FontWeight', 'normal');
	end
	if metricNames(iMetric) == "mean_Day1Performance"
		ylim(ax, [0, 100]);
	end
	hold(ax, 'off');
end

for iLayer = 1:2
	ax = nexttile(t, iLayer + 2);
	hold(ax, 'on');
	if iLayer == 1
		x = T.RH23;
		xLabel = 'RH23';
		corrRow = C(C.Metric == "RH23", :);
	else
		x = T.RH5;
		xLabel = 'RH5';
		corrRow = C(C.Metric == "RH5", :);
	end
	y = T.SlopeAdj;
	for iGroup = 1:3
		rows = T.Group == groupOrder(iGroup);
		scatter(ax, x(rows), y(rows), 14, 'MarkerFaceColor', colors(iGroup, :), 'MarkerEdgeColor', 'k', 'LineWidth', 0.2, 'MarkerFaceAlpha', 0.78, 'MarkerEdgeAlpha', 0.45);
	end
	p = polyfit(double(x), double(y), 1);
	xFit = linspace(min(x), max(x), 100);
	yFit = polyval(p, xFit);
	plot(ax, xFit, yFit, 'Color', [0, 0, 0], 'LineWidth', 1);
	text(ax, 0.03, 0.95, sprintf('rho = %.3f\np = %.4g', corrRow.SpearmanRho, corrRow.PValue), 'Units', 'normalized', 'VerticalAlignment', 'top', 'FontSize', 6, 'Interpreter', 'none');
	set(ax, 'FontSize', 6, 'LineWidth', 1, 'Box', 'off', 'Color', 'white');
	ax.Toolbar.Visible = 'off';
	xlabel(ax, xLabel, 'FontSize', 6);
	ylabel(ax, 'SlopeAdj', 'FontSize', 6);
	axis(ax, 'square');
	hold(ax, 'off');
end

t.Title.String = 'Minimal transfer model';
t.Title.FontSize = 6;

localSvg = fullfile(Options.LocalDir, Options.FileStem + ".svg");
localPng = fullfile(Options.LocalDir, Options.FileStem + ".png");
exportgraphics(fig, localSvg, 'ContentType', 'vector', 'BackgroundColor', 'white');
exportgraphics(fig, localPng, 'Resolution', 300, 'BackgroundColor', 'white');

ym = string(datetime('today', 'Format', 'yyyyMM'));
serverDir = fullfile(Options.ServerRoot, ym);
if ~isfolder(serverDir)
	mkdir(serverDir);
end
serverSvg = fullfile(serverDir, Options.FileStem + ".svg");
serverPng = fullfile(serverDir, Options.FileStem + ".png");
copyfile(localSvg, serverSvg);
copyfile(localPng, serverPng);

close(fig);

Output = struct;
Output.Result = Result;
Output.LocalSvg = string(localSvg);
Output.LocalPng = string(localPng);
Output.ServerSvg = string(serverSvg);
Output.ServerPng = string(serverPng);
end

function y = iReorderSummary(S, metricName, groupOrder)
y = nan(1, numel(groupOrder));
for i = 1:numel(groupOrder)
	row = S.Group == groupOrder(i);
	y(i) = S{row, metricName};
end
end

function vals = iSelectMetric(T, metricName)
switch metricName
	case "mean_Day1Performance"
		vals = T.Day1Performance;
	case "mean_SlopeAdj"
		vals = T.SlopeAdj;
	otherwise
		error('Unknown metric: %s', metricName);
end
vals = vals(isfinite(vals));
end