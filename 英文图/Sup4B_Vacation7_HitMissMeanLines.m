% Sup4B_Vacation7_HitMissMeanLines.m —— Sup Fig 4B：7 天组（V7）学习期与迁移期命中/错失的群体均值曲线
%
% 目的：7 天组在旧任务（声水）学会后停训 7 天；本图用同一批 learned-active 细胞，
%       对比「学会期（声水）」、「迁移期命中（光水 hit）」、「迁移期错失（光水 miss）」三条群体均值线，
%       说明旧任务的表征本身是完好的，问题出在新任务的读出/唤起，而不是"没学会"。
%
% 口径沿用 英文图/Fig1G_Learned_TransferHitMiss_MeanLines.m：
%   QueryNTATS（ZScore，F0 = 1:24，Median 叠加）+ NtatsCellStrip；
%   learned-active = 学会期 1 s 处 > 基线均值 + 3σ。
%
% 输出：English_Sup4B_Vacation7_HitMissMeanLines.svg

thisDir = fileparts(mfilename('fullpath'));
if ~exist('UniExp.DataSet', 'class')
	prjFile = fullfile(thisDir, '..', 'Transferlearning.prj');
	if exist(prjFile, 'file'), matlab.project.loadProject(prjFile); end
end
addpath(fullfile(thisDir, '..'));

DS = TransferLearning.Vacation7();
xs = TransferLearning.Xs;
if isduration(xs), xsSec = seconds(xs); else, xsSec = double(xs); end
xsSec = double(xsSec(:));

xMask    = (xsSec >= -1) & (xsSec <= 3);
xsPlot   = xsSec(xMask);
baseMask = (xsSec >= -3) & (xsSec < 0);
kSigma   = 3;

[idx1s, ok1s] = iFindTimeIndex(xsSec, 1, 0.25);
if ~ok1s, error('Sup4B:No1s', '找不到 1 s 采样点。'); end

qL = struct('Phase', 'Learned',  'Stimulus', 'AudioWater');
qH = struct('Phase', 'Transfer', 'Stimulus', 'LightWater', 'Behavior', 1);
qM = struct('Phase', 'Transfer', 'Stimulus', 'LightWater', 'Behavior', 0);

G = struct();
G.Learned = DS.QueryNTATS(qL, UniExp.Flags.ZScore, 1:24, UniExp.Flags.Median);
G.Hit     = DS.QueryNTATS(qH, UniExp.Flags.ZScore, 1:24, UniExp.Flags.Median);
G.Miss    = DS.QueryNTATS(qM, UniExp.Flags.ZScore, 1:24, UniExp.Flags.Median);

S = UniExp.NtatsCellStrip(G);
X = iGetNtats3D(S);

XLearned = squeeze(X(:, :, 1));
baseMu = mean(XLearned(:, baseMask), 2, 'omitnan');
baseSd = std(XLearned(:, baseMask), 0, 2, 'omitnan');
v1 = XLearned(:, idx1s);
activeMask = isfinite(v1) & isfinite(baseMu) & isfinite(baseSd) & (v1 > (baseMu + kSigma * baseSd));

X = X(activeMask, xMask, :);
nCells = size(X, 1);
Y = nan(numel(xsPlot), 3);
E = nan(numel(xsPlot), 3);
for iL = 1:3
	D = squeeze(X(:, :, iL));
	Y(:, iL) = mean(D, 1, 'omitnan')';
	E(:, iL) = std(D, 0, 1, 'omitnan')' / sqrt(nCells);
end

% 试计数（图注用）
T = DS.TableQuery(["Mouse","Phase","Stimulus","Behavior"]);
T.Phase = fillmissing(string(T.Phase), 'constant', "<none>");
T.Stimulus = fillmissing(string(T.Stimulus), 'constant', "<none>");
nTr = [nnz(T.Phase == "Learned" & T.Stimulus == "AudioWater"), ...
	nnz(T.Phase == "Transfer" & T.Stimulus == "LightWater" & T.Behavior == 1), ...
	nnz(T.Phase == "Transfer" & T.Stimulus == "LightWater" & T.Behavior == 0)];
nMice = numel(unique(string(T.Mouse)));

figW = 7.4; figH = 3.8;
f = figure('Color', 'w', 'Name', 'Sup4B V7 hit/miss mean lines');
f.Units = 'centimeters';
f.Position(3:4) = [figW figH];
f.PaperUnits = 'centimeters';
f.PaperSize = [figW figH];
f.PaperPosition = [0 0 figW figH];
f.PaperPositionMode = 'manual';

ax = axes(f, 'Position', [0.130 0.105 0.455 0.845]);
hold(ax, 'on');
lineColors = [TransferLearning.ColorLearned; TransferLearning.ColorHit; TransferLearning.ColorMiss] / 255;
Patches = MATLAB.Graphics.MultiShadowedLines(Y, E, 0.2, X=repmat(xsPlot, 1, 3), EdgeColors=lineColors);
xline(ax, 0, '--', 'Color', [0.5 0.5 0.5], 'LineWidth', 0.4);
xline(ax, 1, '--', 'Color', [0.5 0.5 0.5], 'LineWidth', 0.4);
xlabel(ax, 'Time (s)', 'FontSize', 6);
ylabel(ax, 'z-score', 'FontSize', 6);
ax.FontSize = 6; ax.LineWidth = 0.5; box(ax, 'off');

LegendLines = gobjects(size(Patches));
for i = 1:numel(Patches)
	LegendLines(i) = plot(ax, [NaN NaN], [NaN NaN], '-', 'Color', Patches(i).EdgeColor, 'LineWidth', 1);
end
lg = legend(LegendLines, {'learned', 'light hit', 'light miss'}, ...
	'Location', 'eastoutside', 'Box', 'off', 'FontSize', 5);
lg.AutoUpdate = 'off';   % 防止后加的手绘轴线/刻度污染图例

TransferLearning.Style.ApplyStandardFigureStyle(f, 1);
% 标准格式会重置轴位，需在其后重设（否则 eastoutside 图例会把轴压扁），随后直接 print
ax.Position = [0.130 0.105 0.455 0.845];
ax.XTick = -1:1:3;

% 收紧 y 范围到数据（含 SEM 阴影）外侧一点，避免 L 的下边离数据太远
yLo = min(min(Y - E, [], 'omitnan'), [], 'omitnan');
yHi = max(max(Y + E, [], 'omitnan'), [], 'omitnan');
ylim(ax, [yLo - 0.08 * (yHi - yLo), yHi + 0.05 * (yHi - yLo)]);
xlim(ax, [-1, 3.15]);
ax.YTick = 0:1:3;

% —— 去掉 MATLAB 常规横纵轴，改画「短 L 比例尺」：竖向 1 z、横向 1 s ——
ax.XAxis.Visible = 'off';
ax.YAxis.Visible = 'off';
ax.Box = 'off';
cAx = [0.30 0.30 0.30];
xL = ax.XLim(1); xR = ax.XLim(2);
yB = ax.YLim(1); yT = ax.YLim(2);
dxR = xR - xL;  dyR = yT - yB;
% 比例尺原点：放在线索前曲线（含 SEM）上方，避免与基线重叠
preMask = tAx < 0;
yPre = max(max(Y(preMask, :) + E(preMask, :), [], 'omitnan'), [], 'omitnan');
x0 = xL + 0.045 * dxR;
y0 = yPre + 0.14 * dyR;
lenY = 0.5;                 % 竖向 0.5 个 z
lenX = 0.5;                 % 横向 0.5 s
plot(ax, [x0 x0], [y0, y0 + lenY], '-', 'Color', cAx, 'LineWidth', 0.7, ...
	'Clipping', 'off', 'HandleVisibility', 'off');
plot(ax, [x0, x0 + lenX], [y0 y0], '-', 'Color', cAx, 'LineWidth', 0.7, ...
	'Clipping', 'off', 'HandleVisibility', 'off');
% 臂端数值（对应 z-score 与时间）
text(ax, x0 - 0.018 * dxR, y0 + lenY, '0.5z', 'HorizontalAlignment', 'right', ...
	'VerticalAlignment', 'middle', 'FontSize', 6, 'Color', cAx, 'HandleVisibility', 'off');
text(ax, x0 + lenX, y0 - 0.030 * dyR, '0.5 s', 'HorizontalAlignment', 'right', ...
	'VerticalAlignment', 'top', 'FontSize', 6, 'Color', cAx, 'HandleVisibility', 'off');
% 坐标标题本图不再显示（用比例尺表达量与单位）
svgPath = TransferLearning.StandardFigureSvgPath('English_Sup4B_Vacation7_HitMissMeanLines.svg');
print(f, svgPath, '-dsvg');
fprintf('Wrote: %s\n', svgPath);

fprintf('\n=== V7（%d 鼠）===\n', nMice);
fprintf('learned-active 细胞 = %d\n', nCells);
fprintf('试次：learned %d | light hit %d | light miss %d\n', nTr(1), nTr(2), nTr(3));
wWin = xsPlot >= 0.5 & xsPlot <= 1.5;
condNames = ["learned", "hit", "miss"];
for iL = 1:3
	fprintf('  %-8s 窗内均值 z = %.2f\n', condNames(iL), mean(Y(wWin, iL), 'omitnan'));
end

%% ========== local ==========
function X = iGetNtats3D(S)
if istable(S)
	nt = S.NTATS;
elseif isstruct(S) && isfield(S, 'NTATS')
	nt = S.NTATS;
else
	nt = S;
end
if isa(nt, 'MATLAB.DataTypes.NDTable')
	try
		X = nt.Data.Data;
	catch
		X = nt{:,:,:}.Data;
	end
	return;
end
if isnumeric(nt) && ndims(nt) == 3
	X = nt;
	return;
end
error('Sup4B:BadNTATS', 'Unsupported NTATS container: %s', class(nt));
end

function [idx, ok] = iFindTimeIndex(xsSec, tSec, tolSec)
if isempty(xsSec) || ~isvector(xsSec)
	idx = 1; ok = false; return;
end
[d, idx] = min(abs(xsSec(:) - tSec));
ok = isfinite(d) && (d <= tolSec);
end
