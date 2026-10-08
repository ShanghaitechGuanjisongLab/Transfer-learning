% Trial figure (no figure number yet): grouped bar chart of the post-cue minus
% pre-cue decoder output for all sixteen cells of the 4x4 context cross matrix,
% drawn in the style of 中文图/Fig54B_PreFormalConnectionWeightStdBars.m
% (grouped bars with one colour per group, individual s.e.m. error bars,
% per-mouse scatter, legend outside).
%
% Quantity per bar: for every mouse and every matrix cell, the P(post) curve of
% the decoder is averaged over the post-cue time points (t > 0, +0.06..+0.96 s)
% and over the pre-cue time points (t < 0, -0.96..-0.06 s), and the difference is
% taken:
%   ΔP(post) = mean_post-cue P(post) - mean_pre-cue P(post)
% So each bar holds n = 10 repeat values (one per mouse) with their s.e.m., drawn
% as individual error bars plus one scatter point per mouse.
%
% Layout: x-axis = TRAINING context (4 groups), bar colour = READ-OUT context
% (4 colours). This is the dimension swap of 英文图/Trial_ContextCrossMatrix.m,
% where the row (and the line colour) is the training context and the column is
% the read-out context: here the training dimension forms the x groups so that
% one training context can be compared across its four read-outs.
% Mapping is enforced by UniExp.BarScatterCompare's 2-D grouped table syntax:
% RowNames -> x groups, VariableNames -> bar series / colours, and Data{i, j}
% is drawn at x group i in series j - i.e. deltaM(training, read-out) as
% verified by reading back every series' YData against deltaM below.
% The four diagonal bars (Audio only -> Audio only, Light only -> Light only,
% Audio-water -> Audio-water, Light-water -> Light-water) are the 5-fold
% out-of-fold self-tests; the other twelve are true cross-context transfers.
%
% Asterisk rule (as asked): one '*' on a bar when the post-cue vs pre-cue
% difference of that cell is significant across mice, no mark when it is not.
% Test = Wilcoxon signed-rank on the 10 per-mouse ΔP(post) values against 0
% (equivalently the paired post-cue vs pre-cue comparison within mouse); the
% one-sample t-test p is printed to the command window for reference, together
% with the Bonferroni-corrected survival over the sixteen cells. No between-group
% P-value lines are drawn: the marking is per bar, not per pair.
%
% Input: 信息编码/CueModel_ContextCrossMatrix_Results.mat
%          (run CueModel_ContextCrossMatrix.m first)
%
% Output (SVG):
%   - Trial_ContextCrossMatrixDeltaBars.svg
%
% Execution (hard requirement):
% - Keep this file as a script (do NOT convert to function).
% - Open in MATLAB Editor and Run/F5.

thisDir = fileparts(mfilename('fullpath'));
if ~exist('UniExp.DataSet', 'class')
	prjFile = fullfile(thisDir, '..', 'Transferlearning.prj');
	if exist(prjFile, 'file')
		matlab.project.loadProject(prjFile);
	end
end

matPath = fullfile(thisDir, '..', '信息编码', 'CueModel_ContextCrossMatrix_Results.mat');
if ~isfile(matPath)
	error('Trial_DeltaBars:NoResults', ...
		'Missing %s - run CueModel_ContextCrossMatrix.m first.', matPath);
end
S = load(matPath);
curves = S.curves;
nulls = S.nulls;
tVec = S.tVec;
ctxLabel = S.ctxLabel;          % ["Audio only", "Audio-water", "Light-water"]
mouseNames = S.mouseNames;
nCtx = numel(ctxLabel);
nM = numel(mouseNames);
% 四个上下文的颜色（本图颜色编码读出上下文），调色板与 Trial_ContextCrossMatrix.m
% 一致：AO 紫、LO 蓝、AW 绿、LW 橙
ctxBlue = [0.13, 0.44, 0.80];
ctxColors = [TransferLearning.NaiveColor; ctxBlue; TransferLearning.ColorB; TransferLearning.TransferColor];

%% ---------- per-bar statistics ----------
preIdx = tVec < 0;
postIdx = tVec > 0;
deltaM = nan(nCtx, nCtx, nM);
pRank = nan(nCtx, nCtx);
pT = nan(nCtx, nCtx);
nSigT = zeros(nCtx, nCtx);
dMean = nan(nCtx, nCtx);
dSem = nan(nCtx, nCtx);
for r = 1:nCtx
	for c = 1:nCtx
		V = curves{r, c};
		d = mean(V(:, postIdx), 2) - mean(V(:, preIdx), 2);
		deltaM(r, c, :) = d(:);
		dMean(r, c) = mean(d);
		dSem(r, c) = iSem(d);
		pT(r, c) = iOneSampleTTest(d);
		pRank(r, c) = iSignRank(d);
		nSigT(r, c) = sum(d > 0);
	end
end
pBonf = 0.05 / numel(pRank);
nKeepBonf = sum(pRank < pBonf, 'all');

fprintf('=== Trial: pre vs post cue decoder output, 4x4 context cross matrix (%s) ===\n', S.dsName);
fprintf('n = %d mice in every bar: %s\n', nM, strjoin(reshape(mouseNames, 1, []), ', '));
fprintf('ΔP(post) = mean P(post) over post-cue points (%.2f..%.2f s) − mean over pre-cue points (%.2f..%.2f s)\n\n', ...
	tVec(find(postIdx, 1)), tVec(find(postIdx, 1, 'last')), tVec(find(preIdx, 1)), tVec(find(preIdx, 1, 'last')));
fprintf('%-14s', 'train \ read');
for c = 1:nCtx
	fprintf('%-40s', ctxLabel(c));
end
fprintf('\n');
for r = 1:nCtx
	fprintf('%-14s', char(ctxLabel(r)));
	for c = 1:nCtx
		fprintf('%-40s', sprintf('Δ %.3f ± %.3f, %d/%d >0, Wilcoxon p=%.4f%s, t-test p=%.4g', ...
			dMean(r, c), dSem(r, c), nSigT(r, c), nM, pRank(r, c), ...
			iif(pRank(r, c) < 0.05, '*', ''), pT(r, c)));
	end
	fprintf('\n');
end
fprintf('\nAsterisk threshold: Wilcoxon signed-rank p < 0.05; Bonferroni over the %d bars = %.4f -> %d/%d bars remain significant.\n', ...
	numel(pRank), pBonf, nKeepBonf, numel(pRank));
for r = 1:nCtx
	for c = 1:nCtx
		mn = mean(curves{r, c}, 1, 'omitnan');
		mn95 = mean(nulls{r, c}, 1, 'omitnan');
		if r == c
			kind = 'self OOF';
		else
			kind = 'transfer';
		end
		fprintf('%s → %s (%s): curve above permutation null 95%% at %d/%d time points\n', ...
			ctxLabel(r), ctxLabel(c), kind, sum(mn > mn95), numel(tVec));
	end
end
%% ---------- figure ----------
dataCell = cell(nCtx, nCtx);
for r = 1:nCtx          % rows = training context (x groups)
	for c = 1:nCtx      % columns = read-out context (colours)
		dataCell{r, c} = squeeze(deltaM(r, c, :));
	end
end
dataTable = cell2table(dataCell, 'VariableNames', cellstr(ctxLabel), 'RowNames', cellstr(ctxLabel));
dataTable.Properties.DimensionNames = cellstr(["Train", "ReadOut"]);
colorTable = array2table(ctxColors, 'VariableNames', {'R', 'G', 'B'}, 'RowNames', cellstr(ctxLabel));

f = figure('Color', 'w', 'Name', 'Trial: pre vs post cue decoder difference, 4x4 context matrix');
f.Units = 'centimeters';
% 4 组 x 4 色共 16 条，较 3x3 版（15 cm）加宽
f.Position(3:4) = [21, 8];
f.PaperUnits = 'centimeters';
f.PaperSize = [21, 8];
f.PaperPositionMode = 'auto';
Layout = tiledlayout(f, 1, 1, 'TileSpacing', 'tight', 'Padding', 'tight');
ax = nexttile(Layout);
hold(ax, 'on');

% 组内条形 + 独立误差条 + 图例（二维分组表语法：行名 = X 轴，列名 = 条形系列/颜色）
[~, optional, barHandles, errorBars] = UniExp.BarScatterCompare(dataTable, colorTable, ax, ...
	UniExp.Flags.IndividualErrorbars);
% 校验维度映射：第 c 个系列（读出上下文 c）在 X 组 r（训练上下文 r）上应等于 deltaM(r,c)
iCheckMapping(ax, barHandles, mean(deltaM, 3), ctxLabel);
for iBar = 1:numel(barHandles)
	barHandles(iBar).LineStyle = 'none';
	barHandles(iBar).FaceColor = ctxColors(iBar, :);
	barHandles(iBar).FaceAlpha = 0.8;
	if isprop(barHandles(iBar), 'BaseLine') && isgraphics(barHandles(iBar).BaseLine)
		barHandles(iBar).BaseLine.Visible = 'off';
	end
end
% 误差条改为深色，避免与同色填充条形混淆
for iRow = 1:height(errorBars)
	eBar = errorBars.Object(iRow);
	if isgraphics(eBar)
		eBar.Color = [0.2 0.2 0.2];
		eBar.LineWidth = 1;
	end
end

% 每鼠散点（同一格内轻微抖动，避免重叠）：c = 条形系列（读出），r = X 组（训练）
rng(7);
for c = 1:nCtx
	xBar = barHandles(c).XEndPoints(:);
	for r = 1:nCtx
		v = squeeze(deltaM(r, c, :));
		scatter(ax, xBar(r) + (rand(numel(v), 1) - 0.5) * 0.16, v, 12, ...
			[0.05 0.05 0.05], 'filled', 'MarkerFaceAlpha', 0.85);
	end
end

% 每格显著性星号：线索前后感应差异在鼠水平是否显著
for c = 1:nCtx
	xBar = barHandles(c).XEndPoints(:);
	for r = 1:nCtx
		if pRank(r, c) < 0.05
			yTop = max(dMean(r, c) + dSem(r, c), max(squeeze(deltaM(r, c, :)))) + 0.012;
			text(ax, xBar(r), yTop, '*', 'HorizontalAlignment', 'center', ...
				'FontSize', 12, 'FontWeight', 'bold');
		end
	end
end

yline(ax, 0, '-', 'Color', [0.55 0.55 0.55], 'LineWidth', 0.6, 'HandleVisibility', 'off');
xlabel(ax, 'Training context');
ylabel(ax, 'ΔP(post) = post-cue − pre-cue');
legendHandle = optional.Legend;
legendHandle.String = cellstr(ctxLabel);
legendHandle.Title.String = 'Read-out context';
legendHandle.Title.FontWeight = 'normal';
legendHandle.Location = 'eastoutside';
box(ax, 'off');
grid(ax, 'off');
ax.Color = 'none';
if isprop(ax, 'Toolbar') && ~isempty(ax.Toolbar)
	ax.Toolbar.Visible = 'off';
end

% 规范：先结算标准样式与 padding，再定最终轴限，否则 padding 会拆掉手设轴限
TransferLearning.ApplyStandardExportStyle(f, 2);
% 三个 X 标签较长，禁止自动旋转（旋转后在 tight padding 下会被裁切）
ax.XTickLabelRotation = 0;
xlim(ax, [0.4, nCtx + 0.6]);
ylim(ax, [-0.03, max(dMean + dSem, [], 'all') * 1.22]);

svgPath = TransferLearning.ExportStandardFigure(f, 2, 'Trial_ContextCrossMatrixDeltaBars.svg');
fprintf('\nWrote: %s\n', svgPath);

assignin('base', 'Trial_ContextCrossMatrixDelta', struct('deltaM', deltaM, 'dMean', dMean, ...
	'dSem', dSem, 'pRank', pRank, 'pT', pT, 'pBonf', pBonf, 'mice', mouseNames, ...
	'tVec', tVec, 'ctxLabel', ctxLabel));

%% ========== local functions ==========
function iCheckMapping(ax, barHandles, dMean, ctxLabel)
% Fail loudly if the bar geometry no longer matches deltaM(training, read-out),
% i.e. if UniExp.BarScatterCompare's row/column -> x-group/series mapping
% changed: series c must carry deltaM(:, c) over the x groups 1..nCtx.
nCtx = numel(ctxLabel);
for c = 1:nCtx
	if numel(barHandles) < c
		error('Trial_DeltaBars:BarMapping', 'Expected %d bar series, got %d.', nCtx, numel(barHandles));
	end
	expected = dMean(:, c)';
	actual = barHandles(c).YData;
	if ~isequalwithequalnans(round(actual, 6), round(expected, 6))
		error('Trial_DeltaBars:BarMapping', ...
			['Series %d does not hold the expected values.\nexpected (train x read-out %s): %s\nactual: %s\n' ...
			'The row/column -> x-group/colour mapping of BarScatterCompare changed; fix the data layout.'], ...
			c, char(ctxLabel(c)), mat2str(expected, 4), mat2str(actual, 4));
	end
end
fprintf('Bar mapping verified: x groups = training context, colours = read-out context (x labels: %s).\n', ...
	strjoin(cellstr(ax.XTickLabel'), ' / '));
end

function p = iSignRank(d)
% Two-sided Wilcoxon signed-rank test of a paired difference against 0.
d = d(isfinite(d));
if numel(d) < 2 || all(d == 0)
	p = NaN;
	return;
end
p = signrank(d);
end

function p = iOneSampleTTest(d)
% Reference one-sample t-test against 0 (ttest's single output is h, not p).
d = d(isfinite(d));
if numel(d) < 2 || std(d) == 0
	p = NaN;
	return;
end
[~, p] = ttest(d);
end

function s = iSem(v)
v = v(:);
ok = isfinite(v);
if ~any(ok)
	s = NaN;
	return;
end
s = std(v(ok)) / sqrt(sum(ok));
end

function s = iif(c, a, b)
if c; s = a; else; s = b; end
end
