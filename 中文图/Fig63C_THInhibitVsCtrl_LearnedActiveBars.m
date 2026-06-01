% 中文图63C：声水活跃细胞，1~3 s 响应与 TH 下降量

if ~exist('UniExp.DataSet', 'class')
	thisFile = mfilename('fullpath');
	thisDir = fileparts(thisFile);
	prjFile = fullfile(thisDir, '..', 'Transferlearning.prj');
	if exist(prjFile, 'file')
		matlab.project.loadProject(prjFile);
	end
end

Data = Fig63BC_THInhibitCtrlActiveCalciumData();
compareGroup = table([1 2], 'VariableNames', {'GroupPair'});

fprintf('1~3s Ctrl: %.3f ± %.3f (n=%d cells)\n', mean(Data.Ctrl.LateMean, 'omitnan'), iSem(Data.Ctrl.LateMean), numel(Data.Ctrl.LateMean));
fprintf('1~3s TH:   %.3f ± %.3f (n=%d cells)\n', mean(Data.TH.LateMean, 'omitnan'), iSem(Data.TH.LateMean), numel(Data.TH.LateMean));
fprintf('1~3s ranksum p = %.4g\n', Data.LatePValue);
fprintf('TH decrease 0~1s: %.3f; 1~3s: %.3f; interaction p = %.4g\n', ...
	Data.DecreaseEarlyMean, Data.DecreaseLateMean, Data.InteractionPValue);

f = figure('Color', 'w', 'Name', '中文图63C learned-active calcium bars');
f.Units = 'centimeters';
f.Position(3:4) = [3, 4];
f.PaperUnits = 'centimeters';
f.PaperPositionMode = 'manual';
f.PaperPosition = [0, 0, 3, 4];
f.PaperSize = [3, 4];

layout = tiledlayout(f, 2, 1, 'TileSpacing', 'tight', 'Padding', 'tight');
layoutTitle = title(layout, 'Naive 🔊💧 active cells', 'FontSize', 6, 'FontWeight', 'normal');
layoutTitle.FontName = 'Segoe UI Emoji';

axTop = nexttile(layout, 1);
[~, optLate, barsLate, ebLate] = UniExp.BarScatterCompare({Data.Ctrl.LateMean(:), Data.TH.LateMean(:)}, compareGroup, AsteriskThreshold=0.05, CapSize=0.5);
iStyleTile(axTop, barsLate, ebLate, {'', ''}, '1~3 s', 'z-score');
iApplyPText(optLate, Data.LatePValue);
iRetunePValues(optLate);

axBottom = nexttile(layout, 2);
[~, optDecrease, barsDecrease, ebDecrease] = UniExp.BarScatterCompare({Data.DecreaseEarlyBootstrap(:), Data.DecreaseLateBootstrap(:)}, compareGroup, AsteriskThreshold=0.05, CapSize=0.5);
iStyleTile(axBottom, barsDecrease, ebDecrease, {'0~1', '1~3'}, 'TH decrease', 'Ctrl~TH');
iApplyPText(optDecrease, Data.InteractionPValue);
iRetunePValues(optDecrease);

svgPath = '中文图Fig63C_THInhibitVsCtrl_LearnedActiveBars.svg';
svgPath = TransferLearning.ExportStandardFigure(f, 1, svgPath);
fprintf('Wrote: %s\n', svgPath);

assignin('base', 'Fig63C_Data', Data);

function iStyleTile(ax, bars, errorBars, xTickLabels, titleText, yLabelText)
ax.FontSize = 6;
ax.LineWidth = 1;
ax.Color = 'none';
if isprop(ax.XAxis, 'LineWidth')
	ax.XAxis.LineWidth = 1;
	ax.YAxis.LineWidth = 1;
end
ax.XAxis.Visible = 'on';
ax.XTick = [1 2];
ax.XTickLabel = xTickLabels;
ax.XTickLabelRotation = 0;
box(ax, 'off');
grid(ax, 'off');
legend(ax, 'off');
ylabel(ax, yLabelText, 'FontSize', 6);
title(ax, titleText, 'FontSize', 6, 'FontWeight', 'normal');
if isprop(ax, 'Toolbar') && ~isempty(ax.Toolbar)
	ax.Toolbar.Visible = 'off';
end

barColors = [TransferLearning.ContinualColor; TransferLearning.ColorB];
iStyleBars(bars, barColors(1:2, :));
for iE = 1:height(errorBars)
	eb = errorBars.Object(iE);
	if ~isgraphics(eb)
		continue;
	end
	eb.LineWidth = 1;
	xData = double(eb.XData(:));
	[~, colorIndex] = min(abs((1:size(barColors, 1)).' - xData(1)));
	eb.Color = barColors(colorIndex, :);
end
end

function iStyleBars(bars, barColors)
if isscalar(bars)
	bars.FaceColor = 'flat';
	nBars = numel(bars.YData);
	colors = repmat(barColors, ceil(nBars / size(barColors, 1)), 1);
	bars.CData = colors(1:nBars, :);
	bars.BarWidth = 0.5;
	bars.LineWidth = 1;
	bars.BaseLine.Visible = 'off';
	if isprop(bars, 'FaceAlpha')
		bars.FaceAlpha = 1;
	end
	if isprop(bars, 'EdgeColor')
		bars.EdgeColor = 'none';
	end
	return;
end
for iBar = 1:min(numel(bars), size(barColors, 1))
	bars(iBar).FaceColor = barColors(iBar, :);
	bars(iBar).BarWidth = 0.5;
	bars(iBar).LineWidth = 1;
	bars(iBar).BaseLine.Visible = 'off';
	if isprop(bars(iBar), 'FaceAlpha')
		bars(iBar).FaceAlpha = 1;
	end
	if isprop(bars(iBar), 'EdgeColor')
		bars(iBar).EdgeColor = 'none';
	end
end
end

function iApplyPText(options, pValue)
if isfield(options, 'MultiCompare') && istable(options.MultiCompare) && ismember('PText', options.MultiCompare.Properties.VariableNames)
	for pt = options.MultiCompare.PText(:)'
		pt.FontSize = 6;
		pt.String = iFormatPValue(pValue);
		pt.Tag = 'PText';
	end
end
if isfield(options, 'MultiCompare') && istable(options.MultiCompare) && ismember('PLine', options.MultiCompare.Properties.VariableNames)
	for pl = options.MultiCompare.PLine(:)'
		pl.LineWidth = 0.5;
		pl.Tag = 'PLine';
	end
end
end

function iRetunePValues(options)
if ~isfield(options, 'MultiCompare') || ~istable(options.MultiCompare)
	return;
end
if ~all(ismember({'PLine','PText'}, options.MultiCompare.Properties.VariableNames))
	return;
end
MATLAB.Graphics.PLineRetune(options.MultiCompare.PLine, options.MultiCompare.PText);
for pl = options.MultiCompare.PLine(:)'
	if isgraphics(pl)
		pl.LineWidth = 0.5;
		pl.Tag = 'PLine';
	end
end
end

function txt = iFormatPValue(pValue)
if ~isfinite(pValue)
	txt = 'n.s.';
elseif pValue < 0.001
	txt = 'p<0.001';
else
	txt = sprintf('p=%.3f', pValue);
end
end

function semValue = iSem(x)
x = x(:);
semValue = std(x, 0, 'omitnan') ./ sqrt(sum(isfinite(x)));
end
