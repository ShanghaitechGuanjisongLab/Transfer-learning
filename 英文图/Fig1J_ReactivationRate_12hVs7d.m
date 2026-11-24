% Fig1J：12 h vs 7 d 的 reactivation 率对比
%
% Reactivation = P(Transfer active | Learned active) @ cue + 1 s
%   L = Learned 阶段声水（AudioWater）1 s 处 > 基线均值 + 3σ
%   T = Transfer 首个纯光水（LightWater）session，同判据
% 小鼠层面：MOp2/3 与 MOp5 的 P(T|L) 按 learned-active 细胞数加权合并成每鼠一个值。
% 组间比较：ranksum（12 h = AudioLightBaseline，n=11；7 d = Vacation7，n=6）。
%
% 口径与 中文图/Fig46D_Vacation7VsCtrl_ReactivationRate.m 的上面板（Reactivation）一致，
% 样式对齐 1C 的两柱图（无边框柱 + 逐鼠散点 + 单向 SEM + 括号上写 p）。
%
% 输出：English_Fig1J_ReactivationRate_12hVs7d.svg（30 × 40 mm，Scale 1）

clear variables; close all;
cd('d:\git\Transfer-Learning');
if ~any(strcmpi(strsplit(path, pathsep), 'd:\git\Transfer-Learning'))
	addpath('d:\git\Transfer-Learning');
end
addpath('d:\git\Transfer-Learning\英文图');
if ~exist('UniExp.DataSet', 'class')
	matlab.project.loadProject('d:\git\Transfer-Learning\Transferlearning.prj');
end
warning('off', 'UniExp:Exception:Block_must_warn');

%% 数据
CtrlDS = TransferLearning.AudioLightBaseline();
V7DS = TransferLearning.Vacation7();

RCtrl = iBuildProb_TransferGivenLearnedAudio_1s_PerMouseLayer( ...
	DataSet=CtrlDS, Source="AudioLightBaseline", RequireHitMiss=false);
RV7 = iBuildProb_TransferGivenLearnedAudio_1s_PerMouseLayer( ...
	DataSet=V7DS, Source="Vacation7", RequireHitMiss=false);
if isempty(RCtrl) || isempty(RV7)
	error('Fig1J:EmptyBuild', 'P(T|L) 构建返回空表。');
end

p12 = iWeightedPTL(RCtrl);  p12 = p12(isfinite(p12));
p7d = iWeightedPTL(RV7);    p7d = p7d(isfinite(p7d));

pv = iRS(p12, p7d);
fprintf('\n=== Fig1J reactivation P(T|L) ===\n');
fprintf('12 h : mice n=%2d  mean=%.3f  SEM=%.3f\n', numel(p12), mean(p12), iSEM(p12));
fprintf('7 d  : mice n=%2d  mean=%.3f  SEM=%.3f\n', numel(p7d), mean(p7d), iSEM(p7d));
fprintf('ranksum p = %.4g\n', pv);
fprintf('learned-active cells: 12 h=%d  7 d=%d\n', ...
	sum(RCtrl.NLearnedActive23 + RCtrl.NLearnedActive5, 'omitnan'), ...
	sum(RV7.NLearnedActive23 + RV7.NLearnedActive5, 'omitnan'));

%% 绘图（对齐 1C 两柱图样式）
figW = 3.0;  figH = 4.0;
f = figure('Color', 'w', 'Name', 'English Fig1J Reactivation 12h vs 7d');
f.Units = 'centimeters';
f.Position(3:4) = [figW figH];
f.PaperUnits = 'centimeters';
f.PaperSize = [figW figH];
f.PaperPosition = [0 0 figW figH];
f.PaperPositionMode = 'manual';

ax = axes(f, 'Position', [0.225 0.155 0.705 0.775]);
hold(ax, 'on');

vals = {p12, p7d};
cols = [TransferLearning.Color12h; TransferLearning.Color7d] / 255;
labels = ["12 h", "7 d"];

y = [mean(vals{1}), mean(vals{2})];
e = [iSEM(vals{1}), iSEM(vals{2})];
for k = 1:2
	bar(ax, k, y(k), 0.50, 'FaceColor', cols(k, :), 'EdgeColor', 'none');
	% 逐鼠散点：填充 = 柱色稍加深，细描边
	jit = (rand(numel(vals{k}), 1) - 0.5) * 0.20;
	scatter(ax, k + jit, vals{k}, 3.8, 'o', 'filled', ...
		'MarkerFaceColor', iDark(cols(k, :), 0.80), ...
		'MarkerEdgeColor', iDark(cols(k, :), 0.55), 'LineWidth', 0.15, ...
		'HandleVisibility', 'off');
	% 单向误差棒（压在散点之上）
	cErr = iDark(cols(k, :), 0.50);
	plot(ax, [k k], [y(k), y(k) + e(k)], '-', 'Color', cErr, ...
		'LineWidth', 0.6, 'HandleVisibility', 'off');
	plot(ax, [k - 0.07, k + 0.07], [y(k) + e(k), y(k) + e(k)], '-', 'Color', cErr, ...
		'LineWidth', 0.6, 'HandleVisibility', 'off');
end

ax.XTick = 1:2;
ax.XTickLabel = cellstr(labels);
ax.XTickLabelRotation = 0;
xlim(ax, [0.4 2.6]);
% 括号放在柱顶+SEM 与最高散点之上
yHi = max([y(:) + e(:); vals{1}(:); vals{2}(:)]);
yBr = yHi * 1.07;
ylim(ax, [0, yBr * 1.28]);
% 轴样式：L 形、朝外刻度、无上/右框（与 Fig1I/1K 一致）
ax.FontSize = 6;
ax.LineWidth = 0.75;
ax.TickDir = 'out';
ax.TickLength = [0.025 0.025];
box(ax, 'off');
grid(ax, 'off');

plot(ax, [1 2], [yBr yBr], '-', 'Color', [0.2 0.2 0.2], 'LineWidth', 0.5, 'HandleVisibility', 'off');
text(ax, 1.5, yBr * 1.02, ['  ' iFmtP(pv)], 'HorizontalAlignment', 'center', ...
	'VerticalAlignment', 'bottom', 'FontSize', 5.5, 'Color', [0.2 0.2 0.2], 'HandleVisibility', 'off');

% 统一样式（散点的尺寸/描边自己控制，不被覆盖）
TransferLearning.Style.ApplyStandardFigureStyle(f, 1, PreserveScatterStyle = true);
ax.Position = [0.225 0.155 0.705 0.775];
ylim(ax, [0, yBr * 1.28]);
ax.XTick = 1:2;  ax.XTickLabel = cellstr(labels);  ax.XTickLabelRotation = 0;
ax.LineWidth = 0.75;  ax.TickDir = 'out';  ax.TickLength = [0.025 0.025];
ylabel(ax, 'Reactivation', 'FontSize', 6);

svgPath = TransferLearning.StandardFigureSvgPath('English_Fig1J_ReactivationRate_12hVs7d.svg');
print(f, svgPath, '-dsvg');
fprintf('Wrote: %s\n', svgPath);

%% ================= 局部函数 =================
function p = iWeightedPTL(R)
% 两层按 learned-active 细胞数加权合并成一个每鼠 P(T|L)
n23 = R.NLearnedActive23;  n5 = R.NLearnedActive5;
n23(~isfinite(n23)) = 0;   n5(~isfinite(n5)) = 0;
w23 = n23 .* R.Prob23;     w5 = n5 .* R.Prob5;
w23(~isfinite(w23)) = 0;   w5(~isfinite(w5)) = 0;
nTot = n23 + n5;
p = (w23 + w5) ./ nTot;
p(nTot == 0) = NaN;
end

function p = iRS(a, b)
[p, ~] = TransferLearning.BehaviorSessions.iRanksumSafe(a, b);
end

function s = iSEM(x)
x = double(x(:)); x = x(isfinite(x));
if isempty(x), s = NaN; else, s = std(x) / sqrt(numel(x)); end
end

function s = iFmtP(p)
if ~isfinite(p) || p >= 0.05
	s = 'n.s.';
elseif p < 1e-3
	s = 'p < 0.001';
else
	s = sprintf('p = %.3f', p);
end
end

function c = iDark(rgb, vMul)
% 同色系派生色：只按 vMul 降明度，不动色相与饱和度
h = rgb2hsv(rgb);
h(3) = h(3) * vMul;
c = hsv2rgb(h);
end
