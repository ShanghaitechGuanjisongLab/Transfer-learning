% 中文图351B：初始/迁移光水首会话的会话时长与舔水时间占比

if ~exist('UniExp.DataSet', 'class')
	thisFile = mfilename('fullpath');
	thisDir = fileparts(thisFile);
	prjFile = fullfile(thisDir, '..', 'Transferlearning.prj');
	if exist(prjFile, 'file')
		matlab.project.loadProject(prjFile);
	end
end

outDirUNC = fullfile('\\Data-Server-2\个人数据\张天夫', char(datetime('now', 'Format', 'yyyyMM')));
svgName = "中文图Fig351B_InterTrialIntervalMetrics_BarScatter_v2.svg";

Sess = TransferLearning.Fig351.BuildStartSessionBlockTagMetrics();
naiveDurMin = Sess.SessionDurationSec(Sess.Group == "Naive") / 60;
tranDurMin = Sess.SessionDurationSec(Sess.Group == "Transfer") / 60;
naiveFrac = Sess.SessionLickFraction(Sess.Group == "Naive");
tranFrac = Sess.SessionLickFraction(Sess.Group == "Transfer");

palette2 = TransferLearning.FigurePalette(2);
colorNaive = palette2(1, :);
colorTransfer = palette2(2, :);

f = figure('Color', 'w', 'Name', '中文图351B session duration and licking fraction');
f.Units = 'centimeters';
f.Position(3:4) = [4.5, 8.0];
f.PaperUnits = 'centimeters';
f.PaperPositionMode = 'manual';
f.PaperPosition = [0, 0, 4.5, 8.0];
f.PaperSize = [4.5, 8.0];

tl = tiledlayout(f, 2, 1, 'TileSpacing', 'compact', 'Padding', 'compact');

ax1 = nexttile(tl, 1);
[~, optional1, bars1, eb1] = UniExp.BarScatterCompare({double(naiveDurMin(:)), double(tranDurMin(:))}, false, table([1 2], 'VariableNames', {'GroupPair'}));
iStyleOneAxis(ax1, bars1, eb1, optional1, colorNaive, colorTransfer, 'Session duration (min)', true);

ax2 = nexttile(tl, 2);
[~, optional2, bars2, eb2] = UniExp.BarScatterCompare({double(naiveFrac(:)), double(tranFrac(:))}, false, table([1 2], 'VariableNames', {'GroupPair'}));
iStyleOneAxis(ax2, bars2, eb2, optional2, colorNaive, colorTransfer, 'Licking fraction', false);

if ~isfolder(outDirUNC)
	mkdir(outDirUNC);
end
svgPath = svgName;
svgPath = TransferLearning.ExportStandardFigure(f, 1, svgPath);
fprintf('Wrote: %s\n', svgPath);

Stats = table([mean(naiveDurMin,'omitnan'); mean(naiveFrac,'omitnan')], [mean(tranDurMin,'omitnan'); mean(tranFrac,'omitnan')], ...
	[numel(naiveDurMin); numel(naiveFrac)], [numel(tranDurMin); numel(tranFrac)], ...
	'VariableNames', {'NaiveMean', 'TransferMean', 'NaiveN', 'TransferN'}, 'RowNames', {'DurationMin', 'LickFraction'});
assignin('base', 'Fig351B_StartSessionMetrics', Sess(:, {'Mouse', 'Group', 'Source', 'DateTime', 'SessionDurationSec', 'SessionLickFraction', 'SessionLickSec'}));
assignin('base', 'Fig351B_Stats', Stats);

function iStyleOneAxis(ax, Bars, ErrorBars, optional, colorNaive, colorTransfer, yLabelText, hideX)
	ax.FontSize = 6;
	ax.LineWidth = 1;
	if isprop(ax.XAxis, 'LineWidth')
		ax.XAxis.LineWidth = 1;
		ax.YAxis.LineWidth = 1;
	end
	ax.TickDir = 'out';
	box(ax, 'off');
	grid(ax, 'off');
	if isprop(ax, 'Toolbar') && ~isempty(ax.Toolbar)
		ax.Toolbar.Visible = 'off';
	end
	ax.XTick = [1 2];
	if hideX
		ax.XTickLabel = {'', ''};
	else
		ax.XTickLabel = {'Naive', 'Transfer'};
	end
	ylabel(ax, yLabelText, 'FontSize', 6);
	for pt = iFindPText(optional)'
		pt.FontSize = 6;
	end
	if isstruct(optional) && isfield(optional, 'MultiCompare') && istable(optional.MultiCompare) && ismember('PLine', optional.MultiCompare.Properties.VariableNames)
		for pl = optional.MultiCompare.PLine(:)'
			pl.LineWidth = 1;
		end
	end
	iStyleBars(Bars, colorNaive, colorTransfer);
	iKeepUpperErrorBarOnly(ErrorBars, Bars, colorNaive, colorTransfer);
end

function pText = iFindPText(optional)
	pText = gobjects(0, 1);
	if isstruct(optional) && isfield(optional, 'MultiCompare') && istable(optional.MultiCompare) && ismember('PText', optional.MultiCompare.Properties.VariableNames)
		pText = optional.MultiCompare.PText;
	end
end

function iStyleBars(Bars, colorNaive, colorTransfer)
	if isscalar(Bars)
		Bars.FaceColor = 'flat';
		nBar = numel(Bars.YData);
		Bars.CData = repmat([colorNaive; colorTransfer], ceil(nBar / 2), 1);
		Bars.CData = Bars.CData(1:nBar, :);
		Bars.BarWidth = 0.5;
		Bars.LineWidth = 1;
		Bars.BaseLine.LineWidth = 1;
		Bars.EdgeColor = 'none';
		Bars.FaceAlpha = 1/3;
	else
		Bars(1).FaceColor = colorNaive;
		Bars(2).FaceColor = colorTransfer;
		Bars(1).LineWidth = 1;
		Bars(1).BaseLine.LineWidth = 1;
		Bars(2).LineWidth = 1;
		Bars(2).BaseLine.LineWidth = 1;
		Bars(1).EdgeColor = 'none';
		Bars(2).EdgeColor = 'none';
		Bars(1).FaceAlpha = 1/3;
		Bars(2).FaceAlpha = 1/3;
	end
end

function iKeepUpperErrorBarOnly(errorBars, barsObj, colorNaive, colorTransfer)
	barSpec = iBarSpecs(barsObj, colorNaive, colorTransfer);
	for eb = errorBars.Object(:)'
		if ~isgraphics(eb)
			continue;
		end
		eb.YNegativeDelta(:) = 0;
		eb.LineWidth = 1;
		eb.LineStyle = 'none';
		eb.HandleVisibility = 'off';
		x = eb.XData(:);
		if ~isempty(x)
			eb.Color = iColorForBarX(x(1), barSpec, colorNaive);
		end
	end
end

function spec = iBarSpecs(barsObj, colorNaive, colorTransfer)
	if isscalar(barsObj)
		x = barsObj.XEndPoints(:);
		nBar = numel(x);
		colors = repmat([colorNaive; colorTransfer], ceil(nBar / 2), 1);
		colors = colors(1:nBar, :);
	else
		x = [barsObj.XEndPoints]';
		colors = [colorNaive; colorTransfer];
	end
	spec = table(x, colors, 'VariableNames', {'X', 'Color'});
end

function color = iColorForBarX(x, spec, fallback)
	[~, idx] = min(abs(spec.X - x));
	if isempty(idx)
		color = fallback;
	else
		color = spec.Color(idx, :);
	end
end

