% Trial figure (no figure number yet): the English Fig3D cue pre/post decoder
% laid out as a complete 4x4 cross-context matrix. Rows = training context,
% columns = read-out context; the diagonal is the decoder's own 5-fold
% out-of-fold self-test, every off-diagonal tile is the SAME decoder read out on
% a held-out context it was never trained on.
%
% Mimics 英文图/Fig3D_GapDecoderTransfer.m tile-for-tile (same decoder output,
% same shading, same permutation null, same axis limits), extended to sixteen
% tiles of one cohort (AudioLightBaseline, no gap; n = 10 mice in every tile
% because all four contexts share the registered cell set).
%
% Per tile: mean +/- s.e.m. P(post) over mice, grey dashed line = 95th
% percentile of the label-shuffled permutation null (200 shuffles, averaged over
% mice). Significance follows the English Fig1B/2H convention instead of
% pointwise markers: every tile carries a horizontal black line above the curve
% spanning the SAME 0.5..1 s window (the window ending at water delivery), and
% above it the significance of that window taken as a whole (per-mouse mean
% P(post) minus mean null over 0.5..1 s, one-sample sign-rank; 1B/2H star/p text
% convention).
% Line colour encodes the TRAINING context, so a row can be followed across its
% read-outs. The AW -> LW tile is the Fig3D direction with the whole initial
% learning phase as the AudioWater training pool; the AO -> LW tile asks how much
% of that light-water signal the audio calibration trials alone already carry,
% and the AO <-> LO pair (both cue-only, interleaved in the same calibration
% blocks) how much of the cue response is shared between the two cue identities.
%
% Labelling: the CONTEXT NAMES live on the tiles (read-out context in the
% first-row titles, training context in the first-column ylabels, each written
% once because it repeats along that dimension); the Layout-level xlabel/ylabel
% carry the axis quantity plus which dimension runs along that axis (read-out vs
% training), not the names again.
%
% Water is delivered at cue + 1 s, so the post window (0..1 s) ends exactly at
% water delivery in every context.
%
% Input: CueModel_ContextCrossMatrix_Results.mat（经 TransferLearning.CachePath 存放在数据服务器
%   个人缓存目录，不在代码工作区内、不被 git 追踪）。缓存缺失时本脚本自动运行
%   信息编码/CueModel_ContextCrossMatrix.m 现场生成，不要求先手动运行别的脚本
%   （生成开并行池 + 200 次置换，只跑一次，之后直接读缓存）。
%
% Output (SVG):
%   - Trial_ContextCrossMatrix.svg
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

matPath = TransferLearning.CachePath('CueModel_ContextCrossMatrix_Results.mat');
genScript = fullfile(thisDir, '..', '信息编码', 'CueModel_ContextCrossMatrix.m');
if ~isfile(matPath)
	% 入口脚本自给自足：结果缓存缺失时现场运行生成脚本补齐，不要求先手动运行别的脚本。
	fprintf('Results cache missing (%s)\nGenerating it now via %s ...\n', matPath, genScript);
	iRunGeneratorScript(genScript);
end
if ~isfile(matPath)
	error('Trial_ContextCrossMatrix:NoResults', ...
		'%s still missing after running %s.', matPath, genScript);
end
S = load(matPath);
tVec = S.tVec;
nT = numel(tVec);
nCtx = numel(S.ctxLabel);
curves = S.curves;
nulls = S.nulls;
accM = S.accM;
mouseNames = S.mouseNames;
% line colour = training context (rows); Light only adds a blue so each of the
% four contexts keeps its own colour (AO purple, LO blue, AW green, LW orange)
ctxBlue = [0.13, 0.44, 0.80];
rowColors = [TransferLearning.NaiveColor; ctxBlue; TransferLearning.ColorB; TransferLearning.TransferColor];

fprintf('=== Trial: 4x4 context cross matrix of the cue pre/post decoder (%s) ===\n', S.dsName);
fprintf('n = %d mice in every tile: %s\n', numel(mouseNames), strjoin(reshape(mouseNames, 1, []), ', '));
fprintf('\n%-14s', 'train \ read');
for c = 1:nCtx
	fprintf('%-42s', S.ctxLabel(c));
end
fprintf('\n');
for r = 1:nCtx
	fprintf('%-14s', char(S.ctxLabel(r)));
	for c = 1:nCtx
		v = squeeze(accM(r, c, :));
		v = v(isfinite(v));
		mn = mean(curves{r, c}, 1, 'omitnan');
		mn95 = mean(nulls{r, c}, 1, 'omitnan');
		nSig = sum(v > 0.5);
		winMask = (tVec(:) >= 0.5) & (tVec(:) <= 1);
		pR = iWindowP(curves{r, c}, nulls{r, c}, tVec);
		if isfinite(pR)
			pStr = sprintf('p=%.3g', pR);
		else
			pStr = 'p=n.a.';
		end
		fprintf('%-42s', sprintf('%.3f ± %.3f, %d/%d*, %d/%dt, %s', mean(v), iSem(v), nSig, numel(v), ...
			sum(mn(winMask) > mn95(winMask)), sum(winMask), pStr));
	end
	fprintf('\n');
end
fprintf('(k/m* = mice with accuracy > 0.5; k/mt = time points above the null 95%% within 0.5-1 s; p = the 0.5-1 s window as a whole)\n');
%% 

% ---------- figure ----------
f = figure('Color', 'w', 'Name', 'Trial: cue decoder 4x4 context cross matrix');
f.Units = 'centimeters';
% 与 3x3 版逐 tile 同尺寸（tile 5.3 x 4.3 cm），行数 x 列数 3 -> 4
f.Position(3:4) = [9, 8];
Layout = tiledlayout(f, nCtx, nCtx, 'TileSpacing', 'tight', 'Padding', 'tight');

Ax = gobjects(nCtx, nCtx);
pWindow = nan(nCtx, nCtx);
for r = 1:nCtx
	for c = 1:nCtx
		ax = nexttile(Layout);
		hold(ax, 'on');
		V = curves{r, c};
		mn = mean(V, 1, 'omitnan');
		se = zeros(1, nT);
		for iT = 1:nT
			se(iT) = iSem(V(:, iT));
		end
		n95 = mean(nulls{r, c}, 1, 'omitnan');
		iShadedError(ax, tVec, mn, se, rowColors(r, :), 1.2, 'P(post)');
		plot(ax, tVec, n95, '--', 'Color', [0.55 0.55 0.55], 'LineWidth', 1, 'DisplayName', 'null 95%');
		yline(ax, 0.5, ':', 'Color', [0.75 0.75 0.75], 'LineWidth', 0.6, 'HandleVisibility', 'off');
		xline(ax, 0, '--', 'Color', [0.35 0.35 0.35], 'LineWidth', 0.8, 'HandleVisibility', 'off');
		% y 上限留出显著性标注空间（同英文图1B/2H 为 P 值标注扩展 y 上限的做法）
		ylim(ax, [0 1.15]);
		% 显著性（模仿英文图1B/2H）：所有 tile 的横线统一画在 0.5..1 s，窗口整体标显著性，
		% 不逐点打点。横线与标注在统一轴限之后绘制（见下方循环），保证不越出轴范围
		pWindow(r, c) = iWindowP(V, nulls{r, c}, tVec);
		% 规范：列重复信息（读出上下文）只写在第一行标题；行重复信息（训练上下文）
		% 写在第一列 ylabel；维度名（哪一行是训练、哪一列是测试）写在 Layout 级
		if r == 1
			title(ax, S.ctxLabel(c), 'FontSize', 8, 'FontWeight', 'normal');
		end
		if c == 1
			ylabel(ax, S.ctxLabel(r), 'FontSize', 8);
			ax.YAxis.Visible = 'on';
		else
			ax.YAxis.Visible = 'off';
		end
		if r == nCtx
			ax.XAxis.Visible = 'on';
		else
			ax.XAxis.Visible = 'off';
		end
		legend(ax, 'off');
		ax.Color = 'none';
		box(ax, 'off');
		Ax(r, c) = ax;
	end
end
% 规范：Layout 级只写轴量与该轴上的维度名（读出/训练），不重复 tile 上已有的组名
xlabel(Layout, sprintf('Time from cue onset (s)\nRead-out context'));
ylabel(Layout, sprintf('P(post)\nTraining context'));
% 规范：先结算标准样式与 padding，再统一各 tile 轴限，否则 padding 会拆掉统一的轴限
TransferLearning.ApplyStandardExportStyle(f, 2);
MATLAB.Graphics.UnifyAxesLims(Ax(:), @xlim, @ylim);

% 显著性标注在统一轴限之后画（英文图1B/2H 式：0.5..1 s 上方横线 + 窗口整体显著性 p），
% 并按最终轴限钳制横线与文本，防止末列 tile 贴图缘被裁
for r = 1:nCtx
	for c = 1:nCtx
		iSigBar(Ax(r, c), tVec, mean(curves{r, c}, 1, 'omitnan'), pWindow(r, c));
	end
end

svgPath = TransferLearning.ExportStandardFigure(f, 1, 'Trial_ContextCrossMatrix.svg');
fprintf('Wrote: %s\n', svgPath);

assignin('base', 'Trial_ContextCrossMatrixStats', struct('accM', accM, 'curves', curves, ...
	'nulls', nulls, 'tVec', tVec, 'mice', mouseNames, 'ctxLabel', S.ctxLabel));

%% ========== local functions ==========
function s = iSem(v)
v = v(:);
ok = isfinite(v);
if ~any(ok)
	s = NaN;
	return;
end
s = std(v(ok)) / sqrt(sum(ok));
end

function iShadedError(ax, x, mn, se, col, lw, dn)
x = x(:)';
mn = mn(:)';
se = se(:)';
ok = isfinite(mn) & isfinite(se);
x = x(ok);
mn = mn(ok);
se = se(ok);
if isempty(x)
	return;
end
fill(ax, [x fliplr(x)], [mn + se fliplr(mn - se)], col, ...
	'FaceAlpha', 0.25, 'EdgeColor', 'none', 'HandleVisibility', 'off');
plot(ax, x, mn, '-', 'Color', col, 'LineWidth', lw, 'DisplayName', dn);
end

function p = iWindowP(V, N, tVec)
% 0.5..1 s 窗口作为一个整体的显著性：逐鼠取窗口内 P(post) 与 null 的均值差，
% 跨鼠单样本 sign-rank（代替逐时间点判断）。所有 tile 的显著性都算在这段窗口内。
tVec = tVec(:)';
winMask = (tVec >= 0.5) & (tVec <= 1);
dd = mean(V(:, winMask), 2, 'omitnan') - mean(N(:, winMask), 2, 'omitnan');
dd = dd(isfinite(dd));
if isempty(dd) || all(dd == 0)
	p = NaN;
	return;
end
p = signrank(dd);
end

function iSigBar(ax, tVec, mn, p)
% 模仿英文图1B/2H 的显著性标注：所有 tile 的横线统一画在 0.5..1 s 窗口的曲线上方，
% 窗口整体显著性 p 标在线上方。
% 横线用 line 图元绘制：plot 的 2 点水平线会被标准样式误判为轴对齐细线而被重调。
% 横线与文本都钳在轴限内：末列 tile 贴图缘，越界部分会被裁掉。
tVec = tVec(:)';
winMask = (tVec >= 0.5) & (tVec <= 1);
xl = xlim(ax);
yrange = diff(ylim(ax));
yTop = max(mn(winMask), [], 'omitnan');
yBar = yTop + 0.05 * yrange;
x1 = max(0.5, xl(1));
x2 = min(1, xl(2));
line(ax, [x1, x2], [yBar, yBar], 'Color', 'k', 'LineWidth', 1, 'HandleVisibility', 'off');
if ~isfinite(p)
	starStr = 'n.s.';
elseif p < 0.001
	starStr = '＊＊＊＊';
else
	starStr = TransferLearning.Style.iFormatPText(p);
end
hT = text(ax, (x1 + x2) / 2, yBar + 0.02 * yrange, starStr, ...
	'HorizontalAlignment', 'center', 'VerticalAlignment', 'bottom', ...
	'FontSize', 7, 'HandleVisibility', 'off');
% 文本宽度在数据坐标下可能超出轴范围，按 Extent 平移回轴内
ext = hT.Extent;
xShift = 0;
if ext(1) < xl(1)
	xShift = xl(1) - ext(1);
elseif ext(1) + ext(3) > xl(2)
	xShift = xl(2) - ext(1) - ext(3);
end
if xShift ~= 0
	hT.Position(1) = hT.Position(1) + xShift;
end
end

function iRunGeneratorScript(genScript)
% 在独立的函数工作区里 run 生成脚本，其变量不会污染本脚本的工作区；
% 并恢复 cd（生成脚本会 cd 到工程根目录）。
if ~isfile(genScript)
	error('Trial_ContextCrossMatrix:NoGenerator', 'Missing generator script: %s', genScript);
end
iEnsureParallelPool;
oldDir = pwd;
cleaner = onCleanup(@() cd(oldDir)); %#ok<NASGU>
run(genScript);
end

function iEnsureParallelPool
% 生成脚本内部用 parfor。本机默认池（=逻辑核数，56 worker）会因 worker 过多启动失败，
% 这里先建一个稳妥规模的池；实在建不起来就让 parfor 串行执行（慢但能跑完）。
if ~isempty(gcp('nocreate'))
	return;
end
for nW = unique([min(24, feature('numcores')), 16, 8], 'stable')
	try
		parpool('Processes', nW);
		return;
	catch
	end
end
warning('Trial_ContextCrossMatrix:NoPool', ...
	'Parallel pool unavailable; the generator will run serially (much slower).');
ps = parallel.Settings;
ps.Pool.AutoCreate = false;
end
