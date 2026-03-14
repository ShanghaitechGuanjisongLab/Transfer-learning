function EnglishFig4C_OnsetCompare_RSPd_vs_MOp()
outDirUNC = "\\Data-Server-2\个人数据\张天夫\202602";

RSP = TransferLearning.RSPd();
MOp = TransferLearning.AudioLightBaseline();
xsSec = seconds(TransferLearning.Xs);
[idx1, ok1] = TransferLearning.Fig36.iFindTimeIndex(xsSec, 1, 0.25);
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

XRSP = TransferLearning.Fig36.iNtatsData(GRSP.NTATS);
XMOp = TransferLearning.Fig36.iNtatsData(GMOp.NTATS);

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
ax.FontSize = 6;
ax.Toolbar.Visible = 'off';

% Reference palette from 范例 SVGs: #e60012 (crimson), #0070c0 (blue)
cols = [230/255, 0,       18/255;   % RSPd  – #e60012
        0,       112/255, 192/255]; % MOp   – #0070c0
meanCells = {meanRSP(:), meanMOp(:)};
semCells  = {semRSP(:),  semMOp(:)};

Patches = MATLAB.Graphics.MultiShadowedLines(meanCells, semCells, 0.2, X=xsSec(:), EdgeColors=cols);

xline(ax, 0, ':k');
xline(ax, 1, '-k');

box(ax,'off');
grid(ax,'off');
xlabel(ax, 'Time (s)', 'FontSize', 6);
ylabel(ax, 'z-score', 'FontSize', 6);

labels = {'RSPd', 'MOp'};
legend(Patches, labels, 'Location', MATLAB.Graphics.OptimizedLegendLocation(Patches), 'Box','off', 'FontSize', 6);

if ~isfolder(outDirUNC), mkdir(outDirUNC); end
svgPath = fullfile(outDirUNC, svgName);
TransferLearning.PrintFigure(f, svgPath);
fprintf('Wrote: %s\n', svgPath);
end

function X = iKeepActiveCellsAt1s(X, baseMask, idx1, kSigma)
if isempty(X), return; end
baseMu = mean(X(:, baseMask), 2, 'omitnan');
baseSd = std(X(:, baseMask), 0, 2, 'omitnan');
val1 = X(:, idx1);
keep = isfinite(val1) & isfinite(baseMu) & isfinite(baseSd) & (val1 > baseMu + kSigma .* baseSd);
X = X(keep, :);
end