% 中文图341A：初始/迁移 💡💧 代表性细胞跨会话 NTATS

if ~exist('UniExp.DataSet', 'class')
	thisFile = mfilename('fullpath');
	thisDir = fileparts(thisFile);
	prjFile = fullfile(thisDir, '..', 'Transferlearning.prj');
	if exist(prjFile, 'file')
		matlab.project.loadProject(prjFile);
	end
end

Data = TransferLearning.Fig341.BuildStateSpaceSummary(true, UniExp.Flags.ZScore);
Naive = Data.Representative.NaiveCell;
Transfer = Data.Representative.TransferCell;
xsSec = Data.XsSec;
plotMask = xsSec >= 0 & xsSec <= 2;
xsPlot = xsSec(plotMask);
nCol = max(size(Naive.Signals, 1), size(Transfer.Signals, 1));
figWidthCm = 12;
figHeightCm = 8;

f = figure('Color', 'w', 'Name', '中文图341A LightWater representative cells across sessions');
f.Units = 'centimeters';
f.Position(3:4) = [figWidthCm, figHeightCm];
f.PaperUnits = 'centimeters';
f.PaperPositionMode = 'manual';
f.PaperPosition = [0, 0, figWidthCm, figHeightCm];
f.PaperSize = [figWidthCm, figHeightCm];

tlo = tiledlayout(f, 2, nCol, 'TileSpacing', 'compact', 'Padding', 'compact');
palette2 = TransferLearning.FigurePalette(2);
naiveSignals = Naive.Signals(:, plotMask);
transferSignals = Transfer.Signals(:, plotMask);
yLimNaive = [min(naiveSignals, [], 'all'), max(naiveSignals, [], 'all')];
yLimTransfer = [min(transferSignals, [], 'all'), max(transferSignals, [], 'all')];

for iSess = 1:nCol
	ax = nexttile(tlo, iSess);
	if iSess <= size(Naive.Signals, 1)
		if iSess == 1
			headerText = sprintf('Naive  %s\nCell %u', Naive.Mouse, Naive.CellUID);
		else
			headerText = '';
		end
		iPlotSessionTile(ax, xsPlot, Naive.Signals(iSess, plotMask), double(Naive.SessionTable.Performance(iSess)), palette2(1, :), ...
			headerText, iSess, yLimNaive);
	else
		axis(ax, 'off');
	end
	if iSess == 1
		ylabel(ax, 'z-score', 'FontSize', 6);
	end
end

for iSess = 1:nCol
	ax = nexttile(tlo, nCol + iSess);
	if iSess <= size(Transfer.Signals, 1)
		if iSess == 1
			headerText = sprintf('Transfer  %s\nCell %u', Transfer.Mouse, Transfer.CellUID);
		else
			headerText = '';
		end
		iPlotSessionTile(ax, xsPlot, Transfer.Signals(iSess, plotMask), double(Transfer.SessionTable.Performance(iSess)), palette2(2, :), ...
			headerText, iSess, yLimTransfer);
	else
		axis(ax, 'off');
	end
	if iSess == 1
		ylabel(ax, 'z-score', 'FontSize', 6);
	end
end

xlabel(tlo, 'Time (s)', 'FontSize', 6);

outDirUNC = "\\Data-Server-2\个人数据\张天夫\202602";
if ~isfolder(outDirUNC)
	mkdir(outDirUNC);
end
svgPath = fullfile(outDirUNC, '中文图Fig341A_LightWaterRepresentativeCells_AcrossSessions.svg');
TransferLearning.PrintFigure(f, svgPath);
fprintf('Wrote: %s\n', svgPath);

assignin('base', 'Fig341A_NaiveRepresentativeCell', Naive);
assignin('base', 'Fig341A_TransferRepresentativeCell', Transfer);

function iPlotSessionTile(ax, xsPlot, y, perf, baseColor, headerText, sessionIndex, yLim)
hold(ax, 'on');
	h = plot(ax, xsPlot, y, 'Color', baseColor, 'LineWidth', 1, 'HandleVisibility', 'off');
	setappdata(h, 'TransferLearningPreserveLineWidth', true);
	v = xline(ax, 1, '-', 'Color', [0 0 0], 'LineWidth', 1, 'HandleVisibility', 'off');
	setappdata(v, 'TransferLearningPreserveLineWidth', true);
	xlim(ax, [0 2]);
	ylim(ax, yLim);
	ax.FontSize = 6;
	ax.LineWidth = 1;
	ax.TickDir = 'out';
	ax.FontName = 'Segoe UI Emoji';
	ax.XTick = [0 1 2];
	ax.XTickLabel = {'0', '💧', '2'};
	box(ax, 'off');
	grid(ax, 'off');
	if strlength(headerText) > 0
		titleText = sprintf('%s\nS%d  %.0f%%', headerText, sessionIndex, perf * 100);
	else
		titleText = sprintf('S%d  %.0f%%', sessionIndex, perf * 100);
	end
	title(ax, titleText, 'FontSize', 6, 'FontWeight', 'normal');
	if isprop(ax, 'Toolbar') && ~isempty(ax.Toolbar)
		ax.Toolbar.Visible = 'off';
	end
end