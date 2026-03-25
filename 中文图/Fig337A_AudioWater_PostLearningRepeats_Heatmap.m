% 中文图337A：声转光鼠中，声水 Naive、首个100%、24h、36h 的四列热图

Data = Fig337_BuildAudioLearnedRepeatSummary();
laneData = Data.LaneData(:, Data.XMask, :);
xsPlot = Data.XsPlot;

negV = min(laneData, [], 'all', 'omitnan');
posV = max(laneData, [], 'all', 'omitnan');
if ~isfinite(negV), negV = -1; end
if ~isfinite(posV), posV = 1; end
climLowAbs = sqrt(abs(min(negV, 0)));
climHighAbs = sqrt(abs(max(posV, 0)));
CLim = [-climLowAbs, climHighAbs];

f = figure('Color', 'w', 'Name', '中文图337A AudioWater post-learning repeats heatmap');
f.Units = 'centimeters';
f.Position(3:4) = [12, 8];
f.PaperUnits = 'centimeters';
f.PaperPositionMode = 'manual';
f.PaperPosition = [0, 0, 12, 8];
f.PaperSize = [12, 8];

Layout = tiledlayout(f, 1, 4, 'TileSpacing', 'none', 'Padding', 'tight');
[~, Axes] = UniExp.LanearHeatmap( ...
	laneData, ...
	SubTitles=Data.SessionLabels, ...
	Flags=[UniExp.Flags.HideYAxis, UniExp.Flags.SymmetricColormap], ...
	CLim=CLim, ...
	Layout=Layout, ...
	ImagescStyle={'XData', [xsPlot(1), xsPlot(end)]}, ...
	LMHColor=[0,0,1; 1,1,1; 1,0,0]);

xlabel(Layout, 'Time', 'FontSize', 12);
ylabel(Layout, sprintf('%d cells', size(laneData, 1)), 'FontSize', 12);

CB = colorbar;
CB.Layout.Tile = 'east';
CB.Label.String = 'z-score';
CB.FontSize = 12;
CB.Label.FontSize = 12;

for iA = 1:numel(Axes)
	A = Axes(iA);
	if ~isgraphics(A)
		continue;
	end
	A.FontSize = 12;
	A.FontName = 'Segoe UI Emoji';
	A.TickDir = 'in';
	A.LineWidth = 2;
	box(A, 'on');
	xline(A, 0, '--k', 'LineWidth', 2);
	xline(A, 1, '-k', 'LineWidth', 2);
	A.XTick = [0 1];
	A.XTickLabel = {"🔊", "💧"};
	if isprop(A, 'Title') && isgraphics(A.Title)
		A.Title.FontName = 'Segoe UI Emoji';
		A.Title.FontSize = 12;
	end
	if isprop(A, 'Toolbar') && ~isempty(A.Toolbar)
		A.Toolbar.Visible = 'off';
	end
end

outDirUNC = fullfile('\\Data-Server-2\个人数据\张天夫', char(datetime('now', 'Format', 'yyyyMM')));
if ~isfolder(outDirUNC)
	mkdir(outDirUNC);
end
svgPath = fullfile(outDirUNC, '中文图Fig337A_AudioWater_PostLearningRepeats_Heatmap.svg');
TransferLearning.PrintFigure(f, svgPath, ForceLegendOrColorbar=true);
fprintf('Wrote: %s\n', svgPath);

assignin('base', 'Fig337A_Data', Data);

function y = iNiceLimit(x)
if ~isfinite(x) || x <= 0
	y = 1;
	return;
end
e = floor(log10(x));
f = x / 10^e;
if f <= 1
	f2 = 1;
elseif f <= 2
	f2 = 2;
elseif f <= 5
	f2 = 5;
else
	f2 = 10;
end
y = f2 * 10^e;
end