% Sigmoid 学习斜率 k 的定义图：曲线示意 + 公式 + 字母解释
% 曲线用项目主口径（下渐近线固定 0、上渐近线 1）；公式给出含 L 的一般式。
thisDir = fileparts(mfilename('fullpath'));
if ~exist('TransferLearning', 'class')
	matlab.project.loadProject(fullfile(thisDir, '..', 'Transferlearning.prj'));
end

Scale = 2;
Wcm = 16;  Hcm = 9.5;      % 最终排版尺寸
f = figure('Color', 'w', 'Name', 'Sigmoid learning slope definition');
f.Units = 'centimeters';
f.Position(3:4) = [Wcm Hcm] * Scale;
f.PaperUnits = 'centimeters';
f.PaperSize = [Wcm Hcm] * Scale;
f.PaperPosition = [0 0 Wcm Hcm] * Scale;
f.PaperPositionMode = 'manual';

%% ---------- 左：曲线示意 ----------
kShape = 1.6;  mMid = 4;  L = 0;
xv = linspace(0.4, 8.2, 800);
pv = L + (1 - L) ./ (1 + exp(-kShape * (xv - mMid)));

ax = axes(f, 'Position', [0.055 0.155 0.335 0.715]);
hold(ax, 'on');
box(ax, 'off');
plot(ax, xv, pv, '-', 'Color', 'k', 'LineWidth', 1);
% 上、下渐近线
plot(ax, [0.4 8.2], [1 1], ':', 'Color', [0.55 0.55 0.55], 'LineWidth', 0.6);
plot(ax, [0.4 8.2], [0 0], ':', 'Color', [0.55 0.55 0.55], 'LineWidth', 0.6);
% 中点竖线
plot(ax, [mMid mMid], [0 0.5], '--', 'Color', [0.55 0.55 0.55], 'LineWidth', 0.6);
% 概率空间最大瞬时斜率处的切线
tgX = [mMid - 1.2, mMid + 1.25];
tgY = 0.5 + (kShape / 4) * (tgX - mMid);
plot(ax, tgX, tgY, '-', 'Color', [0.35 0.45 0.75], 'LineWidth', 0.9);
plot(ax, mMid, 0.5, 'o', 'MarkerSize', 3.5, 'MarkerFaceColor', 'k', 'MarkerEdgeColor', 'k');
% 标注
text(ax, 0.55, 0.05, 'L = 0');
text(ax, mMid + 0.12, 0.06, 'm');
text(ax, 4.35, 0.30, 'slope = k/4');
% 用不可见点固定取值范围，避免手动设 xlim/ylim
plot(ax, [0.4 8.2 NaN 0.4 8.2], [0 0 NaN 1.04 1.04], 'LineStyle', 'none', 'HandleVisibility', 'off');
axis(ax, 'padded');
ax.XTick = 1:7;
ax.YTick = [0 0.5 1];
ax.YTickLabel = {'', '0.5', ''};
text(ax, 0.55, 1.00, '1', 'VerticalAlignment', 'bottom');
xlabel(ax, 'Training block x');
ylabel(ax, 'Hit rate p(x)');

%% ---------- 右：公式与字母解释 ----------
ax2 = axes(f, 'Position', [0.425 0.02 0.565 0.96]);
ax2.XLim = [0 1];
ax2.YLim = [0 1];
ax2.Visible = 'off';
hold(ax2, 'on');

yF1 = 0.965;
yF2 = 0.855;
yF3 = 0.745;
yF4 = 0.635;
text(ax2, 0, yF1, '$p(x) = L + \frac{1-L}{1+e^{-k(x-m)}}$', ...
	'Interpreter', 'latex', 'HorizontalAlignment', 'left', 'VerticalAlignment', 'middle');
text(ax2, 0, yF2, '$\ell(k,m) = \sum_{t}\left[\, y_t\ln p_t + (1-y_t)\ln(1-p_t)\right]$', ...
	'Interpreter', 'latex', 'HorizontalAlignment', 'left', 'VerticalAlignment', 'middle');
text(ax2, 0, yF3, '$\left.\frac{dp}{dx}\right|_{\max} = \frac{k}{4}$', ...
	'Interpreter', 'latex', 'HorizontalAlignment', 'left', 'VerticalAlignment', 'middle');
text(ax2, 0, yF4, '$k = \frac{\mathrm{logit}\,\bar{p}_{2} - \mathrm{logit}\,\bar{p}_{1}}{x_{2} - x_{1}}$', ...
	'Interpreter', 'latex', 'HorizontalAlignment', 'left', 'VerticalAlignment', 'middle');

sym = {'p(x)', 'x', 'y_t', 'x_t, p_t', 'L', 'k', 'm', 'k/4', 'p̄_i', 'logit p'};
des = { ...
	'第 x 个 block 的预测命中率'; ...
	'训练 block（会话）序号'; ...
	'第 t 个 trial 的命中结果（0/1）'; ...
	'该 trial 所属 block，及其 p_t = p(x_t)'; ...
	'下渐近线（未学习命中率）'; ...
	'学习斜率（单位 1/block）'; ...
	'曲线中点，p(m) = (L+1)/2'; ...
	'概率空间最大瞬时斜率'; ...
	'= h_i/n_i，第 i 个 block 的经验命中率'; ...
	'= ln[p/(1−p)]'};
yRows = linspace(0.575, 0.105, numel(sym)).';
for iRow = 1:numel(yRows)
	text(ax2, 0.000, yRows(iRow), sym{iRow}, 'Interpreter', 'tex', ...
		'HorizontalAlignment', 'left', 'VerticalAlignment', 'middle');
	text(ax2, 0.165, yRows(iRow), des{iRow}, 'Interpreter', 'tex', ...
		'HorizontalAlignment', 'left', 'VerticalAlignment', 'middle');
end
text(ax2, 0.000, 0.022, '两点式仅适用于 2 个 block；≥3 个 block 需数值最大化 ℓ', ...
	'Interpreter', 'tex', 'HorizontalAlignment', 'left', 'VerticalAlignment', 'middle');

SvgPath = TransferLearning.ExportStandardFigure(f, Scale, 'Sigmoid学习斜率_公式图.svg');
fprintf('Wrote: %s\n', SvgPath);
