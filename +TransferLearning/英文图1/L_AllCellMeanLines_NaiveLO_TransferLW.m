% 英文图1L：所有细胞 Naive LightOnly vs Transfer LightWater 平均线图
%
% 两条线：Naive LightOnly (💡)、Transfer LightWater (💡💧Trans.)
% 细胞筛选：无，使用所有共有细胞
% 使用 MATLAB.Graphics.MultiShadowedLines 画 mean ± SEM
% Naive 线使用虚线以区分阶段
%
% Execution:
%   TransferLearning.英文图1.L_AllCellMeanLines_NaiveLO_TransferLW

outDirUNC = "\\Data-Server-2\个人数据\张天夫\202602";

DS = TransferLearning.AudioLightBaseline();

% --- 1) Time axis
xs = TransferLearning.Xs;
if isduration(xs), xsSec = seconds(xs); else, xsSec = double(xs); end

xMask = (xsSec >= -1) & (xsSec <= 2);
xsPlot = xsSec(xMask);

% --- 2) Query 2 lanes (Median ZScore NTATS)
qNaiveLightOnly = struct('Stimulus', 'LightOnly');
qTransferLight  = struct('Phase', 'Transfer', 'Stimulus', 'LightWater');

G = struct();
G.NaiveLightOnly = DS.QueryNTATS(qNaiveLightOnly, UniExp.Flags.ZScore, 1:24, UniExp.Flags.Median);
G.TransferLight  = DS.QueryNTATS(qTransferLight,   UniExp.Flags.ZScore, 1:24, UniExp.Flags.Median);

% --- 3) Each lane independently: exclude cells with NTATS<0 at 1s
[idx1s, ok1s] = iFindTimeIndex(xsSec, 1, 0.25);
if ~ok1s
	error('Fig1L:No1s', 'Cannot find sample close to 1s.');
end

ntatsNaive = iExtractMatrix(G.NaiveLightOnly); % [nCell1 x nTime]
ntatsTransfer = iExtractMatrix(G.TransferLight); % [nCell2 x nTime]

keepN = ntatsNaive(:, idx1s) >= 0;
keepT = ntatsTransfer(:, idx1s) >= 0;
ntatsNaive = ntatsNaive(keepN, :);
ntatsTransfer = ntatsTransfer(keepT, :);
nCellsN = size(ntatsNaive, 1);
nCellsT = size(ntatsTransfer, 1);
fprintf('Naive LightOnly cells (NTATS>=0 at 1s): %d\n', nCellsN);
fprintf('Transfer LightWater cells (NTATS>=0 at 1s): %d\n', nCellsT);

% --- 4) Compute mean ± SEM per lane (plot window only)
nT = sum(xMask);
Y = nan(nT, 2);
E = nan(nT, 2);

DN = ntatsNaive(:, xMask);
Y(:, 1) = mean(DN, 1, 'omitnan')';
E(:, 1) = std(DN, 0, 1, 'omitnan')' / sqrt(nCellsN);

DT = ntatsTransfer(:, xMask);
Y(:, 2) = mean(DT, 1, 'omitnan')';
E(:, 2) = std(DT, 0, 1, 'omitnan')' / sqrt(nCellsT);

% --- 5) Plot
svgName = "English_Fig1L_AllCellMeanLines_NaiveLO_TransferLW.svg";
f = figure('Color', 'w', 'Name', 'English Fig1L All Cell Mean Lines');
f.Units = 'centimeters';
f.Position(3:4) = [9, 7.6];

ax = axes(f);
hold(ax, 'on');
ax.FontSize = 12;

laneColors = GlobalOptimization.ColorAllocate(2, [1,1,1; 1,1,1]);
% 两条线同色系（都是Light cue），用第2色
laneColors = laneColors([2; 2], :);

Patches = MATLAB.Graphics.MultiShadowedLines( ...
	Y, E, 0.2, ...
	X=repmat(xsPlot(:), 1, 2), ...
	EdgeColors=laneColors, ...
	Ax=ax, LineStyles=[":"; "-"]);

xline(ax, 0, ':k');
xline(ax, 1, '-k');

box(ax, 'off');
grid(ax, 'off');
xlabel(ax, 'Time (s)');
ylabel(ax, 'z-score');

laneLabels = ["💡", "💡💧Trans."];
lg = legend(Patches, laneLabels, 'Location', MATLAB.Graphics.OptimizedLegendLocation(Patches), 'Box', 'off');

ax.Toolbar.Visible = 'off';

title(ax, sprintf('💡n=%d, 💡💧n=%d', nCellsN, nCellsT));

% --- 6) Export
if ~isfolder(outDirUNC)
	mkdir(outDirUNC);
end
svgPath = fullfile(outDirUNC, svgName);
TransferLearning.PrintFigure(f, svgPath);
fprintf('Wrote: %s\n', svgPath);

assignin('base', 'Fig1L_MeanLines_Y', Y);
assignin('base', 'Fig1L_MeanLines_SEM', E);
assignin('base', 'Fig1L_nCellsN', nCellsN);
assignin('base', 'Fig1L_nCellsT', nCellsT);

%% --- Local helpers

function M = iExtractMatrix(ntats)
% Extract [nCell x nTime] matrix from NTATS result
if istable(ntats)
	nt = ntats.NTATS;
elseif isstruct(ntats) && isfield(ntats, 'NTATS')
	nt = ntats.NTATS;
else
	nt = ntats;
end
if isa(nt, 'MATLAB.DataTypes.NDTable')
	M = squeeze(nt.Data); % [nCell x nTime]
	return;
end
if isnumeric(nt)
	M = squeeze(nt);
	return;
end
error('Fig1L:BadNTATS', 'Unsupported NTATS container type: %s', class(nt));
end

function [idx, ok] = iFindTimeIndex(xsSec, tSec, tolSec)
if isempty(xsSec) || ~isvector(xsSec)
	idx = 1; ok = false; return;
end
[d, idx] = min(abs(xsSec(:) - tSec));
ok = isfinite(d) && (d <= tolSec);
end
