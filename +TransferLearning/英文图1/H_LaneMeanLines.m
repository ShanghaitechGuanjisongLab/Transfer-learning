% 英文图1H：四泳道平均线图（与1F相同细胞集）
%
% 四条线：Naive AudioOnly、Naive LightOnly、Learned AudioWater、Transfer LightWater
% 细胞筛选：与1F相同，仅保留在 Learned AudioWater 和 Transfer LightWater 两阶段1s处均活跃的细胞
% 使用 MATLAB.Graphics.MultiShadowedLines 画 mean ± SEM
% Naive 两条线使用虚线以区分阶段
%
% Execution:
%   TransferLearning.英文图1.H_LaneMeanLines

outDirUNC = "\\Data-Server-2\个人数据\张天夫\202602";

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
f.Position(3:4) = [9, 7.6]; % 60mm x 40mm

ax = axes(f);
hold(ax, 'on');
ax.FontSize = 12;

laneColors2 = GlobalOptimization.ColorAllocate(2,[1,1,1;1,1,1]);
% Cue相同的线用相同颜色：Audio(1,3)同色，Light(2,4)同色
laneColors = laneColors2([1; 2; 1; 2], :);

Patches = MATLAB.Graphics.MultiShadowedLines( ...
	Y, E, 0.2, ...
	X=repmat(xsPlot(:), 1, 4), ...
	EdgeColors=laneColors, ...
	Ax=ax,LineStyles=[":";":";"-";"-"]);

xline(ax, 0, ':k');
xline(ax, 1, '-k');

box(ax, 'off');
grid(ax, 'off');
xlabel(ax, 'Time (s)');
ylabel(ax, 'z-score');

laneLabels = ["🔊", "💡", "🔊💧100%", "💡💧Trans."];
lg = legend(Patches, laneLabels, 'Location', MATLAB.Graphics.OptimizedLegendLocation(Patches), 'Box', 'off');

ax.Toolbar.Visible = 'off';

% --- 7) Export
if ~isfolder(outDirUNC)
	mkdir(outDirUNC);
end
title(ax,'🔊💡 reactive cells');
svgName = "English_Fig1H_LaneMeanLines.svg";
svgPath = fullfile(outDirUNC, svgName);
TransferLearning.PrintFigure(f, svgPath);
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
