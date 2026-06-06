Data = Fig71_BaselineConvergenceCache();
%% 

f = figure('Color', 'w', 'Name', '中文图71B Baseline convergence deviation');
f.Units = 'centimeters';
f.Position(3:4) = [12, 8.0];
f.PaperUnits = 'centimeters';
f.PaperPositionMode = 'manual';
f.PaperPosition = [0, 0, 12, 8.0];
f.PaperSize = [12, 8.0];

ax = axes(f);
hold(ax, 'on');

patches = MATLAB.Graphics.MultiShadowedLines( ...
	Data.DeviationMean, ...
	Data.DeviationSem, ...
	1 / (numel(Data.Phases) + 1), ...
	X=double(Data.XSec(:)), ...
	EdgeColors=Data.PhaseColors, ...
	LineStyles=Data.PhaseLineStyles, ...
	Ax=ax);

legendProxy = gobjects(1, numel(Data.Phases));
for iPhase = 1:numel(Data.Phases)
	legendProxy(iPhase) = plot(ax, nan, nan, Data.PhaseLineStyles(iPhase), 'Color', Data.PhaseColors(iPhase, :), 'LineWidth', 2);
end
lg = legend(ax, legendProxy, cellstr(Data.LegendLabels), 'Location', 'northeast');
lg.Box = 'off';
lg.FontSize = 12;

ax.FontSize = 12;
ax.FontName = 'Segoe UI Emoji';
ax.LineWidth = 2;
if isprop(ax.XAxis, 'LineWidth')
	ax.XAxis.LineWidth = 2;
	ax.YAxis.LineWidth = 2;
end
box(ax, 'off');
grid(ax, 'off');
xlabel(ax, 'Time(s)');
ylabel(ax, 'log_2(Divergence)');
ax.XTick = -3:1:0;

lineObj = findobj(ax, 'Type', 'Line');
for iLine = 1:numel(lineObj)
	lineObj(iLine).LineWidth = 2;
end
patchObj = findobj(ax, 'Type', 'Patch');
for iPatch = 1:numel(patchObj)
	if isprop(patchObj(iPatch), 'LineWidth')
		patchObj(iPatch).LineWidth = 2;
	end
end

if isprop(ax, 'Toolbar') && ~isempty(ax.Toolbar)
	ax.Toolbar.Visible = 'off';
end

outDirUNC = fullfile('\\Data-Server-2\个人数据\张天夫', char(datetime('now', 'Format', 'yyyyMM')));
if ~isfolder(outDirUNC)
	mkdir(outDirUNC);
end
svgPath = '中文图Fig71B_BaselineConvergence_Deviation.svg';
svgPath = TransferLearning.ExportStandardFigure(f, 2, svgPath);
fprintf('Wrote: %s\n', svgPath);

