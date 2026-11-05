% 印迹细胞的群体曲线（原 Fig2b 下排的 mean ± SEM，已从热图面板拆出）
%
% 两两互斥的两组，合起来正好是热图的所有行：
%   彩色 = learned & transfer active（在首个光水 block 仍被驱动）
%   灰色 = learned only（不再被驱动）
% 逐鼠先取所选细胞均值，再跨鼠平均（n = mice，避免细胞多的鼠主导），
% 灰色组使用与彩色组**相同的鼠**（配对），因此两条曲线只差"哪些细胞进入"。
%
% 数据：优先复用 Fig2_EngramHeatmap.m 留在 base 的 EngramHeatmap_Data；
%       不存在时先运行热图脚本。
%
% 输出：4 个面板  A 12 h learned / B 12 h first LW / C 7 d learned / D 7 d first LW

if ~exist('EngramHeatmap_Data', 'var')
	run(fullfile(fileparts(mfilename('fullpath')), 'Fig2_EngramHeatmap.m'));
end
E = EngramHeatmap_Data;
D12 = E.D12; D7 = E.D7; xMask = E.XMask;

xs = TransferLearning.Xs;
if isduration(xs), xsSec = seconds(xs); else, xsSec = double(xs); end
xsSec = xsSec(:);
xPlot = xsSec(xMask);

f = figure('Color','w','Name','Engram cells: population traces');
f.Units = 'centimeters'; f.Position(3:4) = [24, 7.6];
xc = [0.055 0.295 0.545 0.785]; w = 0.165; y = 0.16; h = 0.66;

col12 = TransferLearning.TransferColor;
col7  = TransferLearning.ColorB;

yLim12 = iGroupYLim(D12, xMask);
yLim7  = iGroupYLim(D7,  xMask);

ax = gobjects(1,4);
ax(1) = axes(f,'Position',[xc(1) y w h]);
iGroupTrace(ax(1), D12, "L", xMask, yLim12, col12, {'12 h, learned',''});

ax(2) = axes(f,'Position',[xc(2) y w h]);
iGroupTrace(ax(2), D12, "T", xMask, yLim12, col12, {'12 h, transfer',''});

ax(3) = axes(f,'Position',[xc(3) y w h]);
iGroupTrace(ax(3), D7, "L", xMask, yLim7, col7, {'7 d, learned',''});

ax(4) = axes(f,'Position',[xc(4) y w h]);
iGroupTrace(ax(4), D7, "T", xMask, yLim7, col7, {'7 d, transfer',''});

iLetters(f, {ax(1), ax(2), ax(3), ax(4)});
outDir = fileparts(mfilename('fullpath'));
savefig(f, fullfile(outDir,'Fig2_EngramPopulationCurves.fig'));
fprintf('Saved: %s\n', fullfile(outDir,'Fig2_EngramPopulationCurves.fig'));

%% ---------------------------------------------------------------
function yLim = iGroupYLim(D, xSel)
rx = iReactivatedMask(D); lo = iLearnedOnlyMask(D);
used = iUsedMice([iMouseMeans(D.XL, D, xSel, rx); iMouseMeans(D.XT, D, xSel, rx)], D);
if numel(used) < 2, used = unique(D.mouse); end
sets = {iMouseMeans(D.XL, D, xSel, rx, 3, used), iMouseMeans(D.XL, D, xSel, lo, 3, used), ...
	iMouseMeans(D.XT, D, xSel, rx, 3, used), iMouseMeans(D.XT, D, xSel, lo, 3, used)};
vals = [];
for i = 1:numel(sets)
	M = sets{i};
	if isempty(M) || ~any(isfinite(M(:))), continue; end
	theta = mean(M, 1, 'omitnan');
	se = std(M, 0, 1, 'omitnan') ./ sqrt(sum(isfinite(M), 1));
	se(~isfinite(se)) = 0;
	vals = [vals, theta - se, theta + se]; %#ok<AGROW>
end
vals = vals(isfinite(vals));
if isempty(vals)
	yLim = [-1 1];
else
	yLim = [min(vals), max(vals)];
	pad = 0.15 * max(diff(yLim), 0.5);
	yLim = [yLim(1) - pad, yLim(2) + pad];
end
end

function en = iEngramMask(D)
en = false(size(D.XL, 1), 1);
en(D.keep) = true;
end

function rx = iReactivatedMask(D)
rx = iEngramMask(D) & logical(D.transferActive(:));
end

function lo = iLearnedOnlyMask(D)
lo = iEngramMask(D) & ~logical(D.transferActive(:));
end

function M = iMouseMeans(X, D, xSel, rowMask, minCells, miceSub)
if nargin < 5 || isempty(minCells), minCells = 3; end
if nargin < 6 || isempty(miceSub), miceSub = unique(D.mouse); end
mice = miceSub(:);
M = nan(numel(mice), nnz(xSel));
for i = 1:numel(mice)
	r = rowMask(:) & (D.mouse == mice(i));
	if nnz(r) < minCells, continue; end
	M(i, :) = mean(X(r, xSel), 1, 'omitnan');
end
if minCells > 1 && sum(any(isfinite(M), 2)) < 2
	M = iMouseMeans(X, D, xSel, rowMask, 1, mice);
end
end

function mice = iUsedMice(M, D, miceSub)
if nargin < 3 || isempty(miceSub), miceSub = unique(D.mouse); end
mice = miceSub(:);
ok = any(isfinite(M), 2);
if numel(ok) ~= numel(mice)
	ok = any(reshape(ok, numel(mice), []), 2);
end
mice = mice(ok);
end

function iGroupTrace(ax, D, which, xSel, yLim, col, ttl)
hold(ax, 'on');
xs = TransferLearning.Xs;
if isduration(xs), xsSec = seconds(xs); else, xsSec = double(xs); end
if ndims(xsSec) > 2, xsSec = squeeze(xsSec); end
xPlot = xsSec(xSel);

if which == "L"
	X = D.XL; tag = 'learned';
else
	X = D.XT; tag = 'transfer';
end
en = iEngramMask(D); rx = iReactivatedMask(D); lo = iLearnedOnlyMask(D);
used = iUsedMice([iMouseMeans(D.XL, D, xSel, rx); iMouseMeans(D.XT, D, xSel, rx)], D);
if numel(used) < 2, used = unique(D.mouse); end
MN = iMouseMeans(X, D, xSel, lo, 3, used);
ME = iMouseMeans(X, D, xSel, rx, 3, used);
hN = iBand(ax, MN, xPlot, [0.55 0.55 0.55], false);
hE = iBand(ax, ME, xPlot, col, true);
nN = nnz(any(isfinite(MN), 2)); nE = nnz(any(isfinite(ME), 2));

yline(ax, 0, ':', 'Color', [0.5 0.5 0.5], 'LineWidth', 0.8);
xline(ax, 0, '--', 'Color', [0.6 0.6 0.6], 'LineWidth', 0.6);
xline(ax, 1, '-.', 'Color', [0.6 0.6 0.6], 'LineWidth', 0.6);
xlim(ax, [xPlot(1), xPlot(end)]);
ylim(ax, yLim);
xlabel(ax, 'Time from cue (s)');
ylabel(ax, 'z-score');

if which == "L"
	ttl2 = sprintf('%d/%d also active in LW', nnz(rx), nnz(en));
else
	ttl2 = sprintf('%d/%d still active', nnz(rx), nnz(en));
end
title(ax, {ttl{1}, ttl2}, 'FontWeight', 'normal', 'FontSize', 8);

if which == "L"
	legend(ax, [hE, hN], {sprintf('learned & transfer (%d mice)', nE), ...
		sprintf('learned only (%d mice)', nN)}, ...
		'Location', 'southeast', 'FontSize', 6, 'Box', 'off');
end
box(ax, 'off');
end

function h = iBand(ax, M, xPlot, col, isStrong)
theta = reshape(mean(M, 1, 'omitnan'), 1, []);
se = reshape(std(M, 0, 1, 'omitnan') ./ sqrt(sum(isfinite(M), 1)), 1, []);
se(~isfinite(se)) = 0;
xPlot = reshape(xPlot, 1, []);
patch(ax, [xPlot, fliplr(xPlot)], [theta - se, fliplr(theta + se)], col, ...
	'FaceAlpha', 0.22, 'EdgeColor', 'none', 'HandleVisibility', 'off');
if isStrong
	h = plot(ax, xPlot, theta, '-', 'Color', col * 0.85, 'LineWidth', 2.0);
else
	h = plot(ax, xPlot, theta, '-', 'Color', [0.45 0.45 0.45], 'LineWidth', 1.2);
end
end

function iLetters(f, axList)
letters = arrayfun(@(k) string(char(64 + k)), 1:numel(axList));
for k = 1:numel(axList)
	p = axList{k}.Position;
	annotation(f, 'textbox', [p(1) - 0.030, p(2) + p(4) + 0.004, 0.03 0.03], ...
		'String', letters(k), 'FontSize', 9, 'FontWeight', 'bold', 'EdgeColor', 'none', ...
		'VerticalAlignment', 'bottom');
end
end
