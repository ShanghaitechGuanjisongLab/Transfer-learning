% English FigS2D (formerly Trial_ContextCrossMatrix_ALDelayed): cue pre/post
% decoder context cross matrix (3x3) on ALDelayed, Always (always-water)
% contexts excluded from the analysis, mimicking the style of Fig2A_ContextCrossMatrix.m.
%
% Data source:
% - CueModel_ContextCrossMatrix_ALDelayed_Results.mat (cache, via
%   TransferLearning.CachePath in the server personal cache folder, not the repo)
%   (if missing, this script auto-runs 信息编码/CueModel_ContextCrossMatrix_ALDelayed.m)
%
% Time range:
% - Fixed display window: [-1.5, 1.5] s (delayed task: nominal water at cue +1.5 s)
%
% Significance (same convention as Fig2A_ContextCrossMatrix.m, 2A style):
% - NO P-value lines and no point-wise markers; each tile carries the significance
%   of the SAME 1.0..1.5 s window taken as a whole (the 0.5 s window ending at
%   nominal water delivery, the delayed-task analog of the 4x4's 0.5..1 s window;
%   per-mouse mean P(post) minus mean null over the window, one-sample sign-rank)
%   as a single P-value text hugging the tile's top-right corner.
%
% Output (SVG):
% - English_FigS2D_Delayed_ContextCrossMatrix.svg
%
% Execution:
% - Keep this file as a script (do NOT convert to function).
% - Open in MATLAB Editor and Run/F5.

thisDir = fileparts(mfilename('fullpath'));
if ~exist('UniExp.DataSet', 'class')
	prjFile = fullfile(thisDir, '..', 'Transferlearning.prj');
	if exist(prjFile, 'file')
		matlab.project.loadProject(prjFile);
	end
end

matPath = TransferLearning.CachePath('CueModel_ContextCrossMatrix_ALDelayed_Results.mat');
genScript = fullfile(thisDir, '..', '信息编码', 'CueModel_ContextCrossMatrix_ALDelayed.m');
if ~isfile(matPath)
	fprintf('Results cache missing (%s)\nGenerating it now via %s ...\n', matPath, genScript);
	iRunGeneratorScript(genScript);
end
if ~isfile(matPath)
	error('Trial_ContextCrossMatrix_ALDelayed:NoResults', ...
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
% 行色 = 训练上下文（同 4x4 版：cue-only=NaiveColor，声水=ColorB，光水=TransferColor）
rowColors = [TransferLearning.NaiveColor; TransferLearning.ColorB; TransferLearning.TransferColor];

fprintf('=== Trial: ALDelayed 3x3 context cross matrix (%s) ===\n', S.dsName);
fprintf('n = %d mice in every tile: %s\n', numel(mouseNames), strjoin(reshape(mouseNames, 1, []), ', '));
fprintf('\n%-18s', 'train \ read');
for c = 1:nCtx
	fprintf('%-44s', S.ctxLabel(c));
end
fprintf('\n');
for r = 1:nCtx
	fprintf('%-18s', char(S.ctxLabel(r)));
	for c = 1:nCtx
		v = squeeze(accM(r, c, :));
		v = v(isfinite(v));
		mn = mean(curves{r, c}, 1, 'omitnan');
		mn95 = mean(nulls{r, c}, 1, 'omitnan');
		winMaskS = (tVec(:) >= 1.0) & (tVec(:) <= 1.5);
		nSig = sum(v > 0.5);
		pR = iWindowP(curves{r, c}, nulls{r, c}, tVec);
		if isfinite(pR)
			pStr = sprintf('p=%.3g', pR);
		else
			pStr = 'p=n.a.';
		end
		fprintf('%-44s', sprintf('%.3f ± %.3f, %d/%d*, %d/%dt, %s', mean(v), iSem(v), nSig, numel(v), ...
			sum(mn(winMaskS) > mn95(winMaskS)), sum(winMaskS), pStr));
	end
	fprintf('\n');
end
fprintf('(k/m* = mice with accuracy > 0.5; k/mt = time points above the null 95%% within 1.0-1.5 s; p = the 1.0-1.5 s window as a whole)\n');

%% ---------- figure ----------
f = figure('Color', 'w', 'Name', 'English FigS2D ALDelayed cue decoder 3x3 context matrix');
f.Units = 'centimeters';
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
		ylim(ax, [0 1.15]);
		xlim(ax, [-1.5 1.5]);
		% 显著性（同 Fig2A_ContextCrossMatrix.m 的 2A 版式）：1.0..1.5 s（名义给水
		% cue+1.5 s 前 0.5 s）窗口整体标显著性，不画横线不逐点打点；P 值文本在下方循环画
		pWindow(r, c) = iWindowP(V, nulls{r, c}, tVec);
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
		if isprop(ax, 'Toolbar') && ~isempty(ax.Toolbar)
			ax.Toolbar.Visible = 'off';
		end
		Ax(r, c) = ax;
	end
end
% "Read-out context" 字样改标在 Layout 级 title（用户裁定，同 2A）
xlabel(Layout, 'Time from cue onset (s)');
ylabel(Layout, sprintf('P(post)\nTraining context'));
title(Layout, 'Read-out context');
TransferLearning.ApplyStandardExportStyle(f, 2);
MATLAB.Graphics.UnifyAxesLims(Ax(:), @xlim, @ylim);
for iA = 1:numel(Ax)
	xlim(Ax(iA), [-1.5 1.5]);
end

% 显著性标注（2A 版式）：不画横线，窗口整体 P 值文本贴靠每格右上角（归一化定位，不越界）
for r = 1:nCtx
	for c = 1:nCtx
		iSigBar(Ax(r, c), pWindow(r, c));
	end
end

svgPath = TransferLearning.ExportStandardFigure(f, 1, 'English_FigS2D_Delayed_ContextCrossMatrix.svg');
fprintf('Wrote: %s\n', svgPath);

assignin('base', 'Trial_ContextCrossMatrix_ALDelayed_Stats', struct('accM', accM, 'curves', curves, ...
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
% 1.0-1.5 s 窗口（名义给水 cue+1.5 s 前 0.5 s，同 Trial_ContextCrossMatrix.m 的
% "the window ending at water delivery" 口径）作为一个整体的显著性：
% 逐鼠取窗口内 P(post) 与 null 的均值差，跨鼠单样本 sign-rank。所有 tile 都算在这段窗口内。
tVec = tVec(:)';
winMask = (tVec >= 1.0) & (tVec <= 1.5);
dd = mean(V(:, winMask), 2, 'omitnan') - mean(N(:, winMask), 2, 'omitnan');
dd = dd(isfinite(dd));
if isempty(dd) || all(dd == 0)
	p = NaN;
	return;
end
p = signrank(dd);
end

function iSigBar(ax, p)
% 显著性标注（2A 版式，用户裁定）：不画 P 值横线，窗口整体显著性 P 值文本
% 贴靠 tile 右上角（归一化定位，不越界）。
if ~isfinite(p)
	starStr = 'n.s.';
elseif p < 0.001
	starStr = '＊＊＊＊';
else
	starStr = TransferLearning.Style.iFormatPText(p);
end
text(ax, 0.98, 0.98, starStr, 'Units', 'normalized', ...
	'HorizontalAlignment', 'right', 'VerticalAlignment', 'top', ...
	'FontSize', 7, 'HandleVisibility', 'off');
end

function iRunGeneratorScript(genScript)
if ~isfile(genScript)
	error('Trial_ContextCrossMatrix_ALDelayed:NoGenerator', 'Missing generator script: %s', genScript);
end
iEnsureParallelPool;
oldDir = pwd;
cleaner = onCleanup(@() cd(oldDir)); %#ok<NASGU>
run(genScript);
end

function iEnsureParallelPool
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
warning('Trial_ContextCrossMatrix_ALDelayed:NoPool', ...
	'Parallel pool unavailable; the generator will run serially (much slower).');
ps = parallel.Settings;
ps.Pool.AutoCreate = false;
end
