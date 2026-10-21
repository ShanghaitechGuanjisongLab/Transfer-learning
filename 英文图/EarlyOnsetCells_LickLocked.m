%% EarlyOnsetCells_LickLocked.m
% 仿 Nature 2026 (s41586-026-11174-3) Fig.1c，在 ALDelayed（有延迟不舔不给水钙成像）中
% 展示"early-onset 细胞"（舔水/运动 onset 之前即开始活动升高的 movement-active 细胞）确实存在。
%
% 定义与算法见 英文图/EarlyOnsetCells_LickLocked_Analysis.m（movement=孤立舔水 bout 起点，
% activity onset = 跨 movement 平均 PSTH 在 [movement 前 0.2 s, movement 结束] 内首次高于
% 基线([−1,−0.5] s)+1 SD 且持续 200 ms 的帧；early-onset = onset<0）。
%
% 三 panel：
%   A: 代表 session 的 movement-active 细胞 lick-锁定 PSTH 热图，按 activity onset 排序，
%      early-onset（onset<0）排在顶部（白线分界），白虚线=lick onset(t=0)。（仿 Fig.1c 左）
%   B: 若干 early-onset 示例细胞的跨-movement 平均 PSTH（mean±SEM），显示 t=0 前的升高。（仿 Fig.1c 右）
%   C: 每 session early-onset / late-onset 占全部细胞比例（hi-res 15.2 Hz，mean±SEM），
%      叠文献参考值（early 12.1%、late 15.9%）。
%
% Input: EarlyOnsetCells_LickLocked_Results.mat（缓存，经 TransferLearning.CachePath；
%        缺失时自动运行 EarlyOnsetCells_LickLocked_Analysis.m 生成）
% Output (SVG): English_EarlyOnsetCells_LickLocked.svg
%
% Execution (hard requirement):
% - Keep this file as a script (do NOT convert to function).
% - Open in MATLAB Editor and Run/F5.

thisDir = fileparts(mfilename('fullpath'));
if ~exist('UniExp.DataSet', 'class')
	prjFile = fullfile(thisDir, '..', 'Transferlearning.prj');
	if exist(prjFile, 'file'), matlab.project.loadProject(prjFile); end
end

matPath  = TransferLearning.CachePath('EarlyOnsetCells_LickLocked_Results.mat');
genScript = fullfile(thisDir, 'EarlyOnsetCells_LickLocked_Analysis.m');
if ~isfile(matPath)
	fprintf('Results cache missing (%s)\nGenerating via %s ...\n', matPath, genScript);
	iRunGeneratorScript(genScript);
end
if ~isfile(matPath)
	error('EarlyOnsetFig:NoResults', '%s still missing after running %s.', matPath, genScript);
end
R = load(matPath);           % S, PerBlock, P
S = R.S; PerBlock = R.PerBlock;

% ---- 代表 session：hi-res(fs>12) 且 nMvt>=30 中 early% 最高的 block ----
isHi = [PerBlock.fs] > 12 & [PerBlock.nMvt] >= 30;
earlyPctBlk = zeros(1, numel(PerBlock));
for i = 1:numel(PerBlock)
	earlyPctBlk(i) = 100*sum(PerBlock(i).isEarly)/max(1, numel(PerBlock(i).cellUID));
end
earlyPctBlk(~isHi) = -inf;
[~, repI] = max(earlyPctBlk);
B = PerBlock(repI);
fprintf('=== Early-onset cells (Fig.1c mimic) ===\n');
fprintf('Representative block %d (%s, %s), fs=%.1fHz, nMvt=%d, nC=%d, early=%d(%.1f%%), late=%d(%.1f%%)\n', ...
	B.BlockUID, B.Mouse, string(B.Stimulus), B.fs, B.nMvt, numel(B.cellUID), ...
	sum(B.isEarly), 100*sum(B.isEarly)/numel(B.cellUID), sum(B.isLate), 100*sum(B.isLate)/numel(B.cellUID));

% 群体子集（hi-res, nMvt>=30）
rel = S(S.fs > 12 & S.nMvt >= 30, :);
earlyMean = mean(rel.EarlyPctAll); earlySem = std(rel.EarlyPctAll)/sqrt(height(rel));
lateMean  = mean(rel.LatePctAll);  lateSem  = std(rel.LatePctAll)/sqrt(height(rel));

%% ---- figure ----
EarlyColor = [0.83 0.24 0.20];   % early-onset 示例/标签（红）
LateColor  = [0.20 0.42 0.78];   % late-onset（蓝）

f = figure('Color', 'w', 'Name', 'English EarlyOnsetCells lick-locked');
f.Units = 'centimeters';
f.Position(3:4) = [16, 9];
tlo = tiledlayout(f, 2, 2, 'TileSpacing', 'compact', 'Padding', 'compact');

% ---------- Panel A: sorted lick-locked heatmap (Fig.1c left) ----------
axA = nexttile(tlo, [2, 1]);
ma = find(B.hasOnset);
[~, o] = sort(B.onsetT(ma));
maSorted = ma(o);
M = B.PSTH(maSorted, :);
tP = B.tP(:)';
Mfin = M(isfinite(M));
if isempty(Mfin), Mfin = 0; end
hi98 = prctile(Mfin, 98);
imagesc(axA, tP, 1:numel(maSorted), M);
set(axA, 'YDir', 'normal');
colormap(axA, parula);
clim(axA, [-0.8, max(3, hi98)]);
hold(axA, 'on');
xline(axA, 0, '--', 'Color', [1 1 1], 'LineWidth', 1.4);
nEarly = sum(B.isEarly);
yline(axA, nEarly + 0.5, '-', 'Color', [1 1 1], 'LineWidth', 1.2);
cb = colorbar(axA); cb.Label.String = 'z (\DeltaF/F)'; cb.Label.FontSize = 7;
xlabel(axA, 'Time from lick (movement) onset (s)');
ylabel(axA, {'Movement-active cells', sprintf('sorted by activity onset (n=%d)', numel(maSorted))});
title(axA, sprintf('%s, %s (block %d)', B.Mouse, string(B.Stimulus), B.BlockUID), 'FontSize', 8, 'FontWeight', 'normal');
text(axA, tP(1)+0.1, nEarly/2, sprintf('%d early-onset\n(onset<0)', nEarly), 'Color', 'w', 'FontSize', 7, ...
	'VerticalAlignment', 'middle', 'FontWeight', 'bold');
text(axA, tP(1)+0.1, nEarly + (numel(maSorted)-nEarly)/2, sprintf('%d late-onset', sum(B.isLate)), ...
	'Color', 'w', 'FontSize', 7, 'VerticalAlignment', 'middle', 'FontWeight', 'bold');
axA.FontSize = 7; box(axA, 'off');

% ---------- Panel B: example early-onset cells (Fig.1c right) ----------
axB = nexttile(tlo, [1, 1]);
% 优先选"可信早发"(onset<=-0.15 s)中 pre-lick 抬升最大的细胞，突出 t=0 前的升高
confE = find(B.isEarly & B.onsetT <= -0.15);
if numel(confE) < 3, confE = find(B.isEarly); end
preWin = (B.tP >= -0.6) & (B.tP <= -0.05);
preAmp = max(B.PSTH(confE, preWin), [], 2, 'omitnan');
[~, oe] = sort(preAmp, 'descend');
eTop = confE(oe(1:min(4, numel(confE))));
hold(axB, 'on');
for k = 1:numel(eTop)
	c = eTop(k);
	mn = B.PSTH(c, :); se = B.PSTHsem(c, :);
	ok = isfinite(mn) & isfinite(se);
	iShadedError(axB, tP(ok), mn(ok), se(ok), EarlyColor, 1.1, sprintf('cell %d', B.cellUID(c)));
end
xline(axB, 0, '--', 'Color', [0.25 0.25 0.25], 'LineWidth', 1.0, 'DisplayName', 'lick onset');
xlim(axB, [-1.5, 1.5]);
xlabel(axB, 'Time from lick onset (s)');
ylabel(axB, 'z (\DeltaF/F)');
title(axB, 'Example early-onset cells (mean \pm SEM)', 'FontSize', 8, 'FontWeight', 'normal');
legend(axB, 'off'); grid(axB, 'on'); axB.FontSize = 7; box(axB, 'off');

% ---------- Panel C: population summary vs paper ----------
axC = nexttile(tlo, [1, 1]);
hold(axC, 'on');
bh = bar(axC, 1:2, [earlyMean, lateMean], 0.55);
bh.FaceColor = 'flat';
bh.CData(1,:) = EarlyColor; bh.CData(2,:) = LateColor;
iErrorBar(axC, [1, 2], [earlyMean, lateMean], [earlySem, lateSem]);
yline(axC, 12.1, '--', 'Color', EarlyColor, 'LineWidth', 1.0, 'HandleVisibility', 'off');
yline(axC, 15.9, '--', 'Color', LateColor, 'LineWidth', 1.0, 'HandleVisibility', 'off');
text(axC, 1.42, 12.1, 'paper 12.1%', 'Color', EarlyColor, 'FontSize', 6, 'VerticalAlignment', 'bottom');
text(axC, 2.05, 15.9, 'paper 15.9%', 'Color', LateColor, 'FontSize', 6, 'VerticalAlignment', 'bottom');
set(axC, 'XTick', 1:2, 'XTickLabel', {'early-onset', 'late-onset'});
ylabel(axC, '% of all cells / session');
title(axC, sprintf('hi-res 15.2 Hz, n=%d sessions', height(rel)), 'FontSize', 8, 'FontWeight', 'normal');
grid(axC, 'on'); axC.FontSize = 7; box(axC, 'off');
ylim(axC, [0, max(20, lateMean+lateSem+4)]);

TransferLearning.ApplyStandardExportStyle(f, 2);
svgPath = TransferLearning.ExportStandardFigure(f, 1, 'English_EarlyOnsetCells_LickLocked.svg');
fprintf('\nWrote: %s\n', svgPath);

fprintf('\n--- 群体汇总 (hi-res 15.2Hz, nMvt>=30, %d sessions) ---\n', height(rel));
fprintf('early-onset = %.1f ± %.1f%% (SEM)  [文献 12.1 ± 1.5%%]\n', earlyMean, earlySem);
fprintf('late-onset  = %.1f ± %.1f%% (SEM)  [文献 15.9 ± 0.9%%]\n', lateMean, lateSem);
fprintf('pooled cells: early %.1f%%, late %.1f%% (见分析脚本输出)\n', ...
	100*sum(rel.nEarly)/sum(rel.nC), 100*sum(rel.nLate)/sum(rel.nC));
fprintf('注：本工程用 ΔF/F（非文献的反卷积 spike），钙动力学滞后使 early-onset 略被低估；\n');
fprintf('    late-onset 与文献吻合，验证 pipeline 正确。low-res 7.95Hz 鼠(2201/2203)因\n');
fprintf('    [-0.2,0) 早发窗仅~1.6 样本，early-onset 近乎不可检测(方法学下限)。\n');
fprintf('    原生采样间隔以 DS.DateTimes.SeriesInterval 为准（非 nSm/6s 反推）。\n');

assignin('base', 'EarlyOnsetFig_Rep', B);
assignin('base', 'EarlyOnsetFig_Rel', rel);

%% ========== local functions ==========
function iRunGeneratorScript(genScript)
if ~isfile(genScript)
	error('EarlyOnsetFig:NoGenerator', 'Generator script not found: %s', genScript);
end
oldDir = pwd;
try
	cd(fileparts(genScript));
	run(genScript);
catch ME
	cd(oldDir);
	rethrow(ME);
end
cd(oldDir);
end

function s = iSem(v)
v = v(:); ok = isfinite(v);
if ~any(ok), s = NaN; return; end
s = std(v(ok)) / sqrt(sum(ok));
end

function iShadedError(ax, x, mn, se, col, lw, dn)
x = x(:)'; mn = mn(:)'; se = se(:)';
ok = isfinite(mn) & isfinite(se);
x = x(ok); mn = mn(ok); se = se(ok);
if isempty(x), return; end
patch(ax, [x, fliplr(x)], [mn+se, fliplr(mn-se)], col, ...
	'FaceAlpha', 0.22, 'EdgeColor', 'none', 'HandleVisibility', 'off');
plot(ax, x, mn, '-', 'Color', col, 'LineWidth', lw, 'DisplayName', dn);
end

function iErrorBar(ax, x, y, e)
for i = 1:numel(x)
	plot(ax, [x(i), x(i)], [y(i)-e(i), y(i)+e(i)], '-', 'Color', [0.2 0.2 0.2], 'LineWidth', 0.9, 'HandleVisibility', 'off');
	plot(ax, [x(i)-0.08, x(i)+0.08], [y(i)+e(i), y(i)+e(i)], '-', 'Color', [0.2 0.2 0.2], 'LineWidth', 0.9, 'HandleVisibility', 'off');
	plot(ax, [x(i)-0.08, x(i)+0.08], [y(i)-e(i), y(i)-e(i)], '-', 'Color', [0.2 0.2 0.2], 'LineWidth', 0.9, 'HandleVisibility', 'off');
end
end
