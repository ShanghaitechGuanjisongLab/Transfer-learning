% English Fig4C: Mean NTATS overlay – RSPd vs MOp (Transfer LightWater)
%
% MultiShadowedLines comparing mean z-scored NTATS across all cells.
%
% Execution:
%   TransferLearning.英文图4.B_OnsetCompare_RSPd_vs_MOp

outDirUNC = "\\Data-Server-2\个人数据\张天夫\202601";

RSP = TransferLearning.RSPd();
MOp = TransferLearning.AudioLightBaseline();
xsSec = seconds(TransferLearning.Xs);

GRSP = RSP.QueryNTATS(struct('Phase','Transfer','Stimulus','LightWater','Design','LightWater'), UniExp.Flags.ZScore, 1:24, UniExp.Flags.Median);
GMOp = MOp.QueryNTATS(struct('Phase','Transfer','Stimulus','LightWater','Design','LightWater'), UniExp.Flags.ZScore, 1:24, UniExp.Flags.Median);

XRSP = TransferLearning.Fig36.iNtatsData(GRSP.NTATS);
XMOp = TransferLearning.Fig36.iNtatsData(GMOp.NTATS);

meanRSP = mean(XRSP, 1, 'omitnan');
meanMOp = mean(XMOp, 1, 'omitnan');
semRSP  = std(XRSP, 0, 1, 'omitnan') ./ sqrt(max(1, sum(isfinite(XRSP), 1)));
semMOp  = std(XMOp, 0, 1, 'omitnan') ./ sqrt(max(1, sum(isfinite(XMOp), 1)));

%% 
% --- Plot
svgName = "English_Fig4C_Onset_RSPd_vs_MOp.svg";
f = figure('Color','w', 'Name','English Fig4C RSPd vs MOp');
f.Units = 'centimeters';
f.Position(3:4) = [9, 8];

ax = axes(f);
hold(ax,'on');
ax.FontSize = 12;
ax.Toolbar.Visible = 'off';

cols = GlobalOptimization.ColorAllocate(2, [1,1,1;1,1,1]);
meanCells = {meanRSP(:), meanMOp(:)};
semCells  = {semRSP(:),  semMOp(:)};

Patches = MATLAB.Graphics.MultiShadowedLines(meanCells, semCells, 0.2, X=xsSec(:), EdgeColors=cols);

xline(ax, 0, ':k');
xline(ax, 1, '-k');

box(ax,'off');
grid(ax,'off');
xlabel(ax, 'Time (s)',FontSize=12);
ylabel(ax, 'z-score',FontSize=12);

labels = {'RSPd', 'MOp'};
legend(Patches, labels, 'Location', MATLAB.Graphics.OptimizedLegendLocation(Patches), 'Box','off');

% --- Export
if ~isfolder(outDirUNC), mkdir(outDirUNC); end
svgPath = fullfile(outDirUNC, svgName);
TransferLearning.PrintFigure(f, svgPath);
fprintf('Wrote: %s\n', svgPath);
