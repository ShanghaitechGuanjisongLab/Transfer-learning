RSP = TransferLearning.RSPd();
MOp = TransferLearning.AudioLightBaseline();
xsSec = seconds(TransferLearning.Xs);
[idx1, ok1] = iFindTimeIndex(xsSec, 1, 0.25);
if ~ok1
	error('EnglishFig4C:No1s', 'Cannot find sample close to 1s.');
end
baseMask = (xsSec >= -3) & (xsSec < 0);
if nnz(baseMask) < 3
	error('EnglishFig4C:BadBaseline', 'Baseline window (-3~0s) has too few samples.');
end
kSigma = 3;

GRSP = RSP.QueryNTATS(struct('Phase','Transfer','Stimulus','LightWater','Design','LightWater'), UniExp.Flags.ZScore, 1:24, UniExp.Flags.Median);
GMOp = MOp.QueryNTATS(struct('Phase','Transfer','Stimulus','LightWater','Design','LightWater'), UniExp.Flags.ZScore, 1:24, UniExp.Flags.Median);

XRSP = iNtatsData(GRSP.NTATS);
XMOp = iNtatsData(GMOp.NTATS);

XRSP = iKeepActiveCellsAt1s(XRSP, baseMask, idx1, kSigma);
XMOp = iKeepActiveCellsAt1s(XMOp, baseMask, idx1, kSigma);

meanRSP = mean(XRSP, 1, 'omitnan');
meanMOp = mean(XMOp, 1, 'omitnan');
semRSP  = std(XRSP, 0, 1, 'omitnan') ./ sqrt(max(1, sum(isfinite(XRSP), 1)));
semMOp  = std(XMOp, 0, 1, 'omitnan') ./ sqrt(max(1, sum(isfinite(XMOp), 1)));

svgName = "English_Fig4C_Onset_RSPd_vs_MOp.svg";
f = figure('Color','w', 'Name','English Fig4C RSPd vs MOp');
f.Units = 'centimeters';
f.Position(3:4) = [9, 8];

ax = axes(f);
hold(ax,'on');
ax.FontSize = 12;
ax.LineWidth = 2;
if isprop(ax, 'Toolbar') && ~isempty(ax.Toolbar)
	ax.Toolbar.Visible = 'off';
end
if isprop(ax.XAxis, 'LineWidth')
	ax.XAxis.LineWidth = 2;
	ax.YAxis.LineWidth = 2;
end

cols = TransferLearning.GroupColors(["RSPd", "MOp"]);
meanCells = {meanRSP(:), meanMOp(:)};
semCells  = {semRSP(:),  semMOp(:)};

Patches = MATLAB.Graphics.MultiShadowedLines(meanCells, semCells, 0.2, X=xsSec(:), EdgeColors=cols);
for iPatch = 1:numel(Patches)
	if isprop(Patches(iPatch), 'LineWidth')
		Patches(iPatch).LineWidth = 2;
	end
	if isprop(Patches(iPatch), 'FaceAlpha')
		Patches(iPatch).FaceAlpha = 1/3;
	end
end

xline(ax, 0, '--k', 'LineWidth', 2);
xline(ax, 1, '--k', 'LineWidth', 2);

box(ax,'off');
grid(ax,'off');
ax.TickLabelInterpreter = 'none';
tickValues = unique([ax.XTick(:); 0; 1]).';
ax.XTick = tickValues;
tickLabels = arrayfun(@(value) sprintf('%g', value), tickValues, 'UniformOutput', false);
isZeroTick = abs(tickValues - 0) < 1e-9;
isOneTick = abs(tickValues - 1) < 1e-9;
tickLabels(isZeroTick) = {'💡'};
tickLabels(isOneTick) = {'💧'};
ax.XTickLabel = tickLabels;
if isprop(ax.XAxis, 'FontName')
	ax.XAxis.FontName = 'Segoe UI Emoji';
end
if isprop(ax.YAxis, 'FontName')
	ax.YAxis.FontName = 'Arial';
end
ylabel(ax, 'z-score', 'FontSize', 12);

xlabel(ax, 'Time (s)', 'FontSize', 12);

labels = {'RSPd', 'MOp'};
lgd = legend(Patches, labels, 'Location', MATLAB.Graphics.OptimizedLegendLocation(Patches), 'Box','off', 'FontSize', 12);
lgd.FontName = 'Arial';

allText = findall(f, 'Type', 'Text');
for iText = 1:numel(allText)
	allText(iText).FontSize = 12;
end

svgPath = svgName;
svgPath = TransferLearning.ExportStandardFigure(f, 2, svgPath);
fprintf('Wrote: %s\n', svgPath);

function X = iKeepActiveCellsAt1s(X, baseMask, idx1, kSigma)
if isempty(X), return; end
baseMu = mean(X(:, baseMask), 2, 'omitnan');
baseSd = std(X(:, baseMask), 0, 2, 'omitnan');
val1 = X(:, idx1);
keep = isfinite(val1) & isfinite(baseMu) & isfinite(baseSd) & (val1 > baseMu + kSigma .* baseSd);
X = X(keep, :);
end

function [idx, ok] = iFindTimeIndex(xsSec, tSec, tolSec)
[d, idx] = min(abs(xsSec(:) - tSec));
ok = isfinite(d) && (d <= tolSec);
end

function X = iNtatsData(NT)
if isa(NT, 'MATLAB.DataTypes.NDTable')
	X = NT.Data;
else
	X = NT;
end
X = squeeze(X);
end

