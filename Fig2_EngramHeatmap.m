% Fig2b｜印迹细胞群体热图（两个队列各自独立成图，每图 3×3 网格）
%
% 图 1（12 h 队列，AudioLightBaseline）三列：
%   A  naive     （Phase = Naive, Stimulus = AudioOnly）
%   B  learned   （Phase = Learned, AudioWater）
%   C  transfer  （Phase = Transfer, LightWater）
%
% 图 2（7 d 队列，Vacation7）三列同上。
%
% 印迹细胞 = **learned 阶段** cue +1 s 超过基线均值 + 3σ（基线 = −3~0 s）的细胞，
%            从该队列所有细胞中挑选。
%            （基线 = −3~0 s）的细胞。
% 三列使用同一批细胞、同一行序；行序 = 按 learned cue +1 s 响应降序。
%
% 色限：两队列三条件合并后取对称稳健 ±p97(|z|)，超出饱和。
%       不要用 1–99 分位的不对称范围：正尾可达 ~55，会把整个负半边压成一条细边。

if ~exist('UniExp.DataSet', 'class')
	thisDir = fileparts(mfilename('fullpath'));
	prjFile = fullfile(thisDir, 'Transferlearning.prj');
	if exist(prjFile, 'file')
		matlab.project.loadProject(prjFile);
	end
end
warning('off', 'UniExp:Exception:Block_must_warn');

xs = TransferLearning.Xs;
if isduration(xs), xsSec = seconds(xs); else, xsSec = double(xs); end
xsSec = xsSec(:);
xMask = (xsSec >= -1) & (xsSec <= 2);
xsPlot = xsSec(xMask);
baseMask = (xsSec >= -3) & (xsSec < 0);
[~, idx1s] = min(abs(xsSec - 1));
kSigma = 3;

D12 = iCollect(TransferLearning.AudioLightBaseline(), baseMask, idx1s, kSigma);
D7  = iCollect(TransferLearning.Vacation7(), baseMask, idx1s, kSigma);
D12 = iSortByLearned(D12);
D7  = iSortByLearned(D7);

fprintf('\n=== engram heatmaps (3 columns each) ===\n');
for c = 1:2
	if c == 1, D = D12; tag = "12 h"; else, D = D7; tag = "7 d"; end
	if isempty(D.keep)
		fprintf('%s: no cells\n', tag);
		continue;
	end
	fprintf(['%s: %4d learned-active cells from %d mice (all cells %d) | ' ...
		'naive z %.2f | learned z %.2f | LW z %.2f | still active %.1f%%\n'], ...
		tag, numel(D.keep), numel(unique(D.mouse(D.keep))), numel(D.mouse), ...
		mean(D.XN(D.keep, idx1s), 'omitnan'), mean(D.XL(D.keep, idx1s), 'omitnan'), ...
		mean(D.XT(D.keep, idx1s), 'omitnan'), 100 * mean(D.transferActive(D.keep)));
end

% ---- shared colour limits（两队列三条件合并）----
allV = [iTake(D12, xMask); iTake(D7, xMask)];
allV = allV(isfinite(allV));
if isempty(allV)
	CLim = [-1 1];
else
	scale = max(0.5, prctile(abs(allV), 97));
	CLim = [-scale, scale];
end
fprintf('colour limits: [%.2f, %.2f] (values beyond saturate)\n', CLim(1), CLim(2));

%% ---- 两个独立热图 ----
outDir = fileparts(mfilename('fullpath'));
iHeatFigure(D12, '12 h', TransferLearning.TransferColor, CLim, xsPlot, xMask, ...
	fullfile(outDir, 'Fig2b_EngramHeatmap_12h.fig'), 'Fig2b_EngramHeatmap_12h.svg');
iHeatFigure(D7, '7 d', TransferLearning.ColorB, CLim, xsPlot, xMask, ...
	fullfile(outDir, 'Fig2b_EngramHeatmap_7d.fig'), 'Fig2b_EngramHeatmap_7d.svg');

assignin('base', 'EngramHeatmap_Data', struct('D12', D12, 'D7', D7, ...
	'Idx1s', idx1s, 'XMask', xMask, 'CLim', CLim));

%% ------------------------------------------------------------------
function V = iTake(D, xMask)
if isempty(D.keep)
	V = zeros(0, nnz(xMask));
	return;
end
V = [D.XN(D.keep, xMask); D.XL(D.keep, xMask); D.XT(D.keep, xMask)];
end
function D = iCollect(DS, baseMask, idx1s, kSigma)
% 每只鼠取：最后一个 learned 的 AudioWater 会话、第一个 transfer 的 LightWater 会话、
%           最后一个 naive 的 AudioOnly 会话；三者细胞 UID 取交集。
xs = TransferLearning.Xs;
if isduration(xs), xsSec = seconds(xs); else, xsSec = double(xs); end
if ndims(xsSec) > 2, xsSec = squeeze(xsSec); end

TL = DS.TableQuery(["Mouse","DateTime"], Phase="Learned", Stimulus="AudioWater", Design="AudioWater");
TT = DS.TableQuery(["Mouse","DateTime"], Phase="Transfer", Stimulus="LightWater", Design="LightWater");
TN = DS.TableQuery(["Mouse","DateTime","Design"], Phase="Naive", Stimulus="AudioOnly");
D = struct('XN', [], 'XL', [], 'XT', [], ...
	'naiveActive', false(0, 1), 'learnedActive', false(0, 1), 'transferActive', false(0, 1), ...
	'mouse', strings(0, 1), 'keep', []);
if isempty(TL) || isempty(TT) || isempty(TN)
	return;
end
TL.Mouse = string(TL.Mouse);
TT.Mouse = string(TT.Mouse);
TN.Mouse = string(TN.Mouse);
TN.Design = string(TN.Design);
gL = groupsummary(TL, "Mouse", "max", "DateTime");
gT = groupsummary(TT(:, ["Mouse","DateTime"]), "Mouse", "min", "DateTime");
S = innerjoin(gL(:, {'Mouse','max_DateTime'}), gT(:, {'Mouse','min_DateTime'}), 'Keys', 'Mouse');
S = renamevars(S, {'max_DateTime','min_DateTime'}, {'LastLearned','FirstTransfer'});

% naive：每鼠最后一次 AudioOnly 会话，连同该会话的 Design（LAu / LAuW）
naiveMice = string(unique(TN.Mouse));
naiveDT = NaT(numel(naiveMice), 1);
naiveDes = strings(numel(naiveMice), 1);
for i = 1:numel(naiveMice)
	sub = TN(TN.Mouse == naiveMice(i), :);
	[~, ix] = max(sub.DateTime);
	naiveDT(i) = sub.DateTime(ix);
	naiveDes(i) = string(sub.Design(ix));
end

nAll = height(S);
S = S(ismember(S.Mouse, naiveMice), :);
nDrop = nAll - height(S);
if nDrop > 0
	fprintf('(%d mouse/mice without naive AudioOnly session excluded)\n', nDrop);
end

for i = 1:height(S)
	m = S.Mouse(i);
	ixN = find(naiveMice == m, 1, 'first');
	QN = table(categorical("Naive"), categorical("AudioOnly"), categorical(naiveDes(ixN)), ...
		categorical(m), naiveDT(ixN), "Naive", ...
		'VariableNames', {'Phase','Stimulus','Design','Mouse','DateTime','GroupName'});
	QL = table(categorical("Learned"), categorical("AudioWater"), categorical("AudioWater"), ...
		categorical(m), S.LastLearned(i), "Learned", ...
		'VariableNames', {'Phase','Stimulus','Design','Mouse','DateTime','GroupName'});
	QT = table(categorical("Transfer"), categorical("LightWater"), categorical("LightWater"), ...
		categorical(m), S.FirstTransfer(i), "Transfer", ...
		'VariableNames', {'Phase','Stimulus','Design','Mouse','DateTime','GroupName'});
	GN = DS.QueryNTATS(QN, UniExp.Flags.ZScore, 1:24, UniExp.Flags.Median);
	GL = DS.QueryNTATS(QL, UniExp.Flags.ZScore, 1:24, UniExp.Flags.Median);
	GT = DS.QueryNTATS(QT, UniExp.Flags.ZScore, 1:24, UniExp.Flags.Median);
	XN = iMat(GN.NTATS);
	XL = iMat(GL.NTATS);
	XT = iMat(GT.NTATS);
	if isempty(XL) || isempty(XT) || isempty(XN), continue; end
	% 各自去重后取三者 CellUID 交集，保证同批细胞、同一行序
	[uN, iN] = unique(uint64(GN.CellUID), 'stable'); XN = XN(iN, :);
	[uL, iL] = unique(uint64(GL.CellUID), 'stable'); XL = XL(iL, :);
	[uT, iT] = unique(uint64(GT.CellUID), 'stable'); XT = XT(iT, :);
	[c1, a1, b1] = intersect(uN, uL, 'stable');
	[c2, a2, b2] = intersect(c1, uT, 'stable');
	nCell = numel(c2);
	XN = XN(a1(a2), :);
	XL = XL(b1(a2), :);
	XT = XT(b2, :);
	if nCell < 3, continue; end
	D.XN = [D.XN; XN]; %#ok<AGROW>
	D.XL = [D.XL; XL]; %#ok<AGROW>
	D.XT = [D.XT; XT]; %#ok<AGROW>
	D.naiveActive = [D.naiveActive; logical(iActive(XN, baseMask, idx1s, kSigma))]; %#ok<AGROW>
	D.learnedActive = [D.learnedActive; logical(iActive(XL, baseMask, idx1s, kSigma))]; %#ok<AGROW>
	D.transferActive = [D.transferActive; logical(iActive(XT, baseMask, idx1s, kSigma))]; %#ok<AGROW>
	D.mouse = [D.mouse; repmat(m, nCell, 1)]; %#ok<AGROW>
end
D.keep = find(D.learnedActive);
end

function D = iSortByLearned(D)
if isempty(D.keep), return; end
xs = TransferLearning.Xs;
if isduration(xs), xsSec = seconds(xs); else, xsSec = double(xs); end
if ndims(xsSec) > 2, xsSec = squeeze(xsSec); end
[~, idx1s] = min(abs(xsSec(:) - 1));
v = D.XL(D.keep, idx1s);
v(~isfinite(v)) = -Inf;
[~, ord] = sort(v, 'descend');
D.keep = D.keep(ord);
end

function X = iMat(X)
if isa(X, 'MATLAB.DataTypes.NDTable'), X = X.Data; end
X = double(X);
if ndims(X) == 3, X = squeeze(X(:, :, 1)); end
end

function active = iActive(X, baseMask, idx1s, kSigma)
bMu = mean(X(:, baseMask), 2, 'omitnan');
bSd = std(X(:, baseMask), 0, 2, 'omitnan');
v1 = X(:, idx1s);
active = isfinite(v1) & isfinite(bMu) & isfinite(bSd) & (v1 > bMu + kSigma .* bSd);
end

function svgPath = iHeatFigure(D, lab, col, CLim, xsPlot, xMask, figPath, svgName)
% 上排：三列热图 naive(AudioOnly) / learned(AudioWater) / transfer(LightWater)，
% 同一批细胞、同一行序，纵向可直接对比。
% 下排：同样三列，把热图选出的这些细胞压成 mean ± SEM 阴影误差带。
% 尺寸遵守《英文图规范》：基础高 4 cm、基础宽 7.5 cm（1.5 的 5 倍），
% 因是两行 tile，放大 ×2 → 图窗 15 × 8 cm，导出缩放 2。
f = figure('Color', 'w', 'Name', sprintf('Engram heatmap %s', lab));
f.Units = 'centimeters';
f.Position(3:4) = [15, 8];

xc = [0.070 0.355 0.640];
w = 0.250;
yT = 0.420; hT = 0.520;   % 上两行：热图（3×3 网格中占 2 行）
yB = 0.115; hB = 0.265;   % 下 1 行：mean ± SEM 阴影带
svgPath = '';

if isempty(D.keep)
	annotation(f, 'textbox', [0.1 0.45 0.8 0.1], 'String', ...
		sprintf('%s: no learned-active cells', lab), 'EdgeColor', 'none', ...
		'HorizontalAlignment', 'center');
	savefig(f, figPath);
	fprintf('Saved: %s\n', figPath);
	return;
end

Z = {D.XN(D.keep, xMask), D.XL(D.keep, xMask), D.XT(D.keep, xMask)};
Xall = {D.XN, D.XL, D.XT};
% 队列名不重复写在每个 tile 标题里（规范：重复信息只写一次），三列标题只写条件
grp = {'Naive (audio only)', 'Learned (audio-water)', 'Transfer (light-water)'};

ax = gobjects(1, 3);
for k = 1:3
	ax(k) = axes(f, 'Position', [xc(k) yT w hT]);
	iHeat(ax(k), xsPlot, Z{k}, CLim, grp{k}, k == 1);
	ax(k).Title.Color = col;
	% 上下两排 X 轴相同 → 只有下排保留 X 轴
	ax(k).XTickLabel = {};
	xlabel(ax(k), '');
end
% 三个 tile 的 Y 轴相同：统一极限
if exist('MATLAB.Graphics.UnifyAxesLims', 'file')
	try, evalc('MATLAB.Graphics.UnifyAxesLims(ax);'); catch, end %#ok<CTCH>
end

cm = iCmap(CLim);
colormap(f, cm);
axCB = axes(f, 'Position', [0.905 yT 0.012 hT]);
lvl = linspace(CLim(1), CLim(2), 256)';
imagesc(axCB, [0 1], linspace(CLim(1), CLim(2), 256), repmat(lvl, 1, 2), CLim);
colormap(axCB, cm);
set(axCB, 'XTick', [], 'YDir', 'normal', 'FontSize', 6, 'TickDir', 'out', 'LineWidth', 0.5, ...
	'YAxisLocation', 'right');
axCB.YTick = [CLim(1), 0, CLim(2)];
axCB.YTickLabel = {sprintf('%.1f', CLim(1)), '0', sprintf('%.1f', CLim(2))};
title(axCB, 'z', 'FontSize', 6, 'FontWeight', 'normal');

% ---- 下排：印迹细胞压成 mean ± SEM 阴影误差带 ----
band = cell(1, 3);
for k = 1:3
	[theta, se] = iMouseBand(Xall{k}, D, xMask);
	band{k} = struct('theta', theta, 'se', se);
end
lo = min(cellfun(@(b) min(b.theta - b.se, [], 'omitnan'), band));
hi = max(cellfun(@(b) max(b.theta + b.se, [], 'omitnan'), band));
if ~isfinite(lo) || ~isfinite(hi) || hi <= lo, lo = -1; hi = 1; end
pad = 0.12 * (hi - lo);
ylimB = [lo - pad, hi + pad];

axB = gobjects(1, 3);
for k = 1:3
	axB(k) = axes(f, 'Position', [xc(k) yB w hB]);
	iBandPanel(axB(k), xsPlot, band{k}, col, ylimB, k == 1);
end

savefig(f, figPath);
fprintf('Saved: %s\n', figPath);
% 两行 tile → 放大 ×2 导出（字号 12 pt、坐标轴线 1 pt，成图后按 ×0.5 排入）
svgPath = TransferLearning.ExportStandardFigure(f, 2, svgName);
fprintf('Saved: %s\n', svgPath);
end

function iHeat(ax, xsPlot, Z, CLim, ttl, showY)
if nargin < 6
	showY = true;
end
if isempty(Z)
	axis(ax, 'off');
	return;
end
imagesc(ax, xsPlot, 1:size(Z, 1), Z, CLim);
set(ax, 'YDir', 'reverse', 'TickDir', 'out', 'FontSize', 6, 'LineWidth', 0.5);
colormap(ax, iCmap(CLim));
hold(ax, 'on');
xline(ax, 0, '--', 'Color', [0.3 0.3 0.3], 'LineWidth', 0.5);
xline(ax, 1, '-.', 'Color', [0.3 0.3 0.3], 'LineWidth', 0.5);
xlabel(ax, 'Time from cue (s)');
% Y 轴刻度保持自动（规范：不手动设置 Y 轴刻度）；相同 Y 轴只保留最左列的 ylabel
ticks = ax.YTick;
if size(Z, 1) > 1
	if showY
		ylabel(ax, 'Cells');
	else
		ax.YTickLabel = repmat({''}, numel(ticks), 1);
	end
end
title(ax, ttl, 'FontWeight', 'normal', 'FontSize', 6);
box(ax, 'on');
end

function [theta, se] = iMouseBand(X, D, xSel)
% 热图选出的细胞 → 逐鼠先取均值，再跨鼠求 mean ± SEM（避免细胞多的鼠主导）
rowMask = false(size(X, 1), 1);
rowMask(D.keep) = true;
mice = unique(D.mouse);
M = nan(numel(mice), nnz(xSel));
for i = 1:numel(mice)
	r = rowMask & (D.mouse == mice(i));
	if ~any(r), continue; end
	M(i, :) = mean(X(r, xSel), 1, 'omitnan');
end
theta = mean(M, 1, 'omitnan');
se = std(M, 0, 1, 'omitnan') ./ sqrt(sum(isfinite(M), 1));
se(~isfinite(se)) = 0;
theta(~isfinite(theta)) = 0;
end

function iBandPanel(ax, xPlot, b, col, ylimB, showY)
hold(ax, 'on');
x = reshape(xPlot, 1, []);
theta = reshape(b.theta, 1, []);
se = reshape(b.se, 1, []);
patch(ax, [x, fliplr(x)], [theta - se, fliplr(theta + se)], col, ...
	'FaceAlpha', 0.25, 'EdgeColor', 'none', 'HandleVisibility', 'off');
plot(ax, x, theta, '-', 'Color', col * 0.85, 'LineWidth', 1);
yline(ax, 0, ':', 'Color', [0.5 0.5 0.5], 'LineWidth', 0.5);
xline(ax, 0, '--', 'Color', [0.45 0.45 0.45], 'LineWidth', 0.5);
xline(ax, 1, '-.', 'Color', [0.45 0.45 0.45], 'LineWidth', 0.5);
xlim(ax, [x(1), x(end)]);
ylim(ax, ylimB);
xlabel(ax, 'Time from cue (s)');
set(ax, 'FontSize', 6, 'LineWidth', 0.5, 'TickDir', 'out', 'Box', 'off');
if showY
	ylabel(ax, 'z-score');
else
	ax.YTickLabel = repmat({''}, numel(ax.YTick), 1);
end
end

function cm = iCmap(CLim)
neg = TransferLearning.HeatmapNegative;
pos = TransferLearning.HeatmapPositive;
n = 128;
lo = [linspace(neg(1), 1, n)', linspace(neg(2), 1, n)', linspace(neg(3), 1, n)'];
hi = [linspace(1, pos(1), n)', linspace(1, pos(2), n)', linspace(1, pos(3), n)'];
if CLim(1) < 0 && CLim(2) > 0
	cm = [lo; hi(2:end, :)];
elseif CLim(2) <= 0
	cm = lo;
else
	cm = hi;
end
end
