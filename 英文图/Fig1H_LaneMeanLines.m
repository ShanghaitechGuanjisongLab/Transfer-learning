% 英文图1H：四泳道平均线图（与1F相同细胞集）
%
% 四条线：Naive AudioOnly、Naive LightOnly、Learned AudioWater、Transfer LightWater
% 细胞筛选：与1F相同，仅保留在 Learned AudioWater 和 Transfer LightWater 两阶段1s处均活跃的细胞
% 使用 MATLAB.Graphics.MultiShadowedLines 画 mean ± SEM
% Naive 两条线使用虚线以区分阶段
%
% Execution:
%   run('英文图/Fig1H_LaneMeanLines.m')


DS = TransferLearning.AudioLightBaseline();

% --- 1) Time axis
xs = TransferLearning.Xs;
if isduration(xs), xsSec = seconds(xs); else, xsSec = double(xs); end

xMask = (xsSec >= -1) & (xsSec <= 2);
xsPlot = xsSec(xMask);

baseMask = (xsSec >= -3) & (xsSec < 0);
kSigma = 3;

[idx1s, ok1s] = iFindTimeIndex(xsSec, 1, 0.25);
if ~ok1s
	error('Fig1H:No1s', 'Cannot find sample close to 1s.');
end

% --- 2) Query 4 lanes (Median ZScore NTATS)
qNaiveAudioOnly = struct('Stimulus', 'AudioOnly');
qNaiveLightOnly = struct('Stimulus', 'LightOnly');
qLearnedAudio   = struct('Phase', 'Learned',  'Stimulus', 'AudioWater');
qTransferLight  = struct('Phase', 'Transfer', 'Stimulus', 'LightWater');

G = struct();
G.NaiveAudioOnly = DS.QueryNTATS(qNaiveAudioOnly, UniExp.Flags.ZScore, 1:24, UniExp.Flags.Median);
G.NaiveLightOnly = DS.QueryNTATS(qNaiveLightOnly, UniExp.Flags.ZScore, 1:24, UniExp.Flags.Median);
G.LearnedAudio   = DS.QueryNTATS(qLearnedAudio,   UniExp.Flags.ZScore, 1:24, UniExp.Flags.Median);
G.TransferLight  = DS.QueryNTATS(qTransferLight,   UniExp.Flags.ZScore, 1:24, UniExp.Flags.Median);

% --- 3) Unify cells
S = UniExp.NtatsCellStrip(G);
X = iGetNtats3D(S); % [nCell x nTime x 4]

% --- 4) Active cell filtering: BOTH Learned AW and Transfer LW active at 1s
nLanes = size(X, 3);
activeByLane = false(size(X, 1), nLanes);
for iL = 1:nLanes
	XL = squeeze(X(:, :, iL));
	baseMu = mean(XL(:, baseMask), 2, 'omitnan');
	baseSd = std(XL(:, baseMask), 0, 2, 'omitnan');
	v1 = XL(:, idx1s);
	activeByLane(:, iL) = isfinite(v1) & isfinite(baseMu) & isfinite(baseSd) & (v1 > (baseMu + kSigma * baseSd));
end
activeMask = activeByLane(:, 3) & activeByLane(:, 4);
X = X(activeMask, :, :);
fprintf('Active cells (both Learned & Transfer): %d / %d\n', sum(activeMask), numel(activeMask));

% --- 5) Compute mean ± SEM per lane (plot window only)
X_plot = X(:, xMask, :); % [nCell x nTimePlot x 4]
nCells = size(X_plot, 1);
nT = size(X_plot, 2);

Y = nan(nT, 4);
E = nan(nT, 4);
for iL = 1:4
	D = squeeze(X_plot(:, :, iL)); % [nCell x nT]
	Y(:, iL) = mean(D, 1, 'omitnan')';
	E(:, iL) = std(D, 0, 1, 'omitnan')' / sqrt(nCells);
end
%% 

% --- 6) Plot
f = figure('Color', 'w', 'Name', 'English Fig1H Lane Mean Lines');
f.Units = 'centimeters';
f.Position(3:4) = [9, 8];
f.PaperUnits = 'centimeters';
f.PaperPositionMode = 'manual';
f.PaperPosition = [0, 0, 9, 8];
f.PaperSize = [9, 8];

ax = axes(f);
hold(ax, 'on');
ax.FontSize = 12;
ax.FontName = 'Segoe UI Emoji';
ax.LineWidth = 2;

laneColors2 = [230, 0, 18; 0, 112, 192] ./ 255;
laneColors = laneColors2([1; 2; 1; 2], :);
lineStyles = ["--"; "--"; "-"; "-"];

hMain = MATLAB.Graphics.MultiShadowedLines(Y, E, 0.18, ...
	Ax=ax, ...
	X=xsPlot(:), ...
	EdgeColors=laneColors, ...
	LineStyles=lineStyles);
set(hMain, 'LineWidth', 2);
for iHandle = 1:numel(hMain)
	setappdata(hMain(iHandle), 'TransferLearningPreserveLineWidth', true);
end

xl0 = xline(ax, 0, ':k', 'LineWidth', 2);
xl1 = xline(ax, 1, '-k', 'LineWidth', 2);
setappdata(xl0, 'TransferLearningPreserveLineWidth', true);
setappdata(xl1, 'TransferLearningPreserveLineWidth', true);

box(ax, 'off');
grid(ax, 'off');
xlabel(ax, 'Time (s)', 'FontSize', 12);
ylabel(ax, 'z-score', 'FontSize', 12);

laneLabels = ["🔊", "💡", "🔊💧100%", "💡💧Trans."];
lg = legend(hMain, laneLabels, 'Location', 'northwest', 'Box', 'off');
lg.FontSize = 12;
lg.FontName = 'Segoe UI Emoji';

ax.Toolbar.Visible = 'off';

% --- 7) Export
outDirUNC = fullfile('\\Data-Server-2\个人数据\张天夫', char(datetime('now', 'Format', 'yyyyMM')));
if ~isfolder(outDirUNC)
	mkdir(outDirUNC);
end
title(ax,'🔊💡 reactive cells', 'FontSize', 12, 'FontWeight', 'normal');
svgName = "English_Fig1H_LaneMeanLines.svg";
svgPath = fullfile(outDirUNC, svgName);
print(f, svgPath, '-dsvg');
fprintf('Wrote: %s\n', svgPath);

assignin('base', 'Fig1H_MeanLines_Y', Y);
assignin('base', 'Fig1H_MeanLines_SEM', E);
assignin('base', 'Fig1H_nCells', nCells);

%% --- Local helpers

function X = iGetNtats3D(S)
if istable(S)
	nt = S.NTATS;
elseif isstruct(S) && isfield(S, 'NTATS')
	nt = S.NTATS;
else
	nt = S;
end
if isa(nt, 'MATLAB.DataTypes.NDTable')
	X = nt.Data.Data;
	return;
end
if isnumeric(nt) && ndims(nt) == 3
	X = nt;
	return;
end
error('Fig1H:BadNTATS', 'Unsupported NTATS container type: %s', class(nt));
end

function [idx, ok] = iFindTimeIndex(xsSec, tSec, tolSec)
if isempty(xsSec) || ~isvector(xsSec)
	idx = 1; ok = false; return;
end
[d, idx] = min(abs(xsSec(:) - tSec));
ok = isfinite(d) && (d <= tolSec);
end
