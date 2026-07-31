%% First-block trial-wise learning curve: Transfer vs Naive
%  对 DataSetA2L (AL Light) 和 DataSetL (LA Light) 两组：
%   1. 每只小鼠取第一次记录（首个 DateTime）
%   2. 提取该 session 内所有 LightWater 试次的逐试次命中/未命中
%   3. 对齐到前 100 试次，画：
%       (a) 逐试次滑动平均学习曲线（组均值±SEM阴影）
%       (b) 分块柱状图（10试次/块）
%       (c) 累积正确曲线
%   4. 导出 SVG+CSV
%
%  执行方式：在 MATLAB Editor 打开后直接 Run/F5

%% --- 0. 路径与项目加载 ---
dataRoot = '\\Data-Server-2\个人数据\杨青宁\202607\行为学';
OUTPUT_DIR = '\\Data-Server-2\个人数据\杨青宁\202607';
svgName = '20260714_FirstBlockLearningCurve_A2L_vs_L.svg';
xlsxName = '20260714_FirstBlockLearningCurve_Summary.xlsx';

if ~exist('UniExp.DataSet', 'class')
	prjFile = fullfile('d:\Users\杨青宁\Documents\MATLAB\Transfer-learning', 'Transferlearning.prj');
	matlab.project.loadProject(prjFile);
end

%% --- 1. 加载数据 ---
DataSetA2L = UniExp.DataSet(fullfile(dataRoot, 'A2L_L.mat'));
DataSetL   = UniExp.DataSet(fullfile(dataRoot, 'L2A_L.mat'));

fprintf('=== DataSetA2L ===\n');
disp(DataSetA2L.DateTimes(1:min(5, height(DataSetA2L.DateTimes)), :));
fprintf('=== DataSetL ===\n');
disp(DataSetL.DateTimes(1:min(5, height(DataSetL.DateTimes)), :));

%% --- 2. 提取每只小鼠首次 session 的逐试次命中/未命中 ---
fprintf('\n--- Extracting first-session trial data ---\n');

trialsA2L = iExtractFirstSessionTrials(DataSetA2L, 'A2L');
trialsL   = iExtractFirstSessionTrials(DataSetL, 'L');

fprintf('A2L: %d mice, %d total trials\n', ...
	numel(unique(trialsA2L.Mouse)), height(trialsA2L));
fprintf('L:   %d mice, %d total trials\n', ...
	numel(unique(trialsL.Mouse)), height(trialsL));

% 合并
allTrials = [trialsA2L; trialsL];
allTrials = sortrows(allTrials, {'Group', 'Mouse', 'Trial'});

%% --- 3. 对齐到前 N_TRIAL 试次 ---
N_TRIAL = 100;
[alignedA2L, alignedL] = iAlignTrialsToMax(trialsA2L, trialsL, N_TRIAL);

fprintf('\nAligned matrices: A2L [%d x %d], L [%d x %d]\n', ...
	size(alignedA2L,1), size(alignedA2L,2), ...
	size(alignedL,1),   size(alignedL,2));

%% --- 4. 计算组均值±SEM & 滑动平均 ---
WINDOW = 11; % 滑动平均窗口

halfW = floor(WINDOW/2);
x = (1:N_TRIAL)';

% 原始均值±SEM
mA2L = mean(alignedA2L, 1, 'omitnan')';
sA2L = std(alignedA2L, 0, 1, 'omitnan')' ./ sqrt(sum(isfinite(alignedA2L), 1))';
mL   = mean(alignedL,   1, 'omitnan')';
sL   = std(alignedL,   0, 1, 'omitnan')' ./ sqrt(sum(isfinite(alignedL),   1))';

% 滑动均值±SEM（跨鼠）
kernel = ones(WINDOW,1)/WINDOW;
smA2L = conv(mA2L, kernel, 'same');
smL   = conv(mL,   kernel, 'same');
% 边界修正（conv在边缘半窗处偏倚，用有效值重新计算）
for i = 1:halfW
	smA2L(i) = mean(mA2L(1:i+halfW), 'omitnan');
	smL(i)   = mean(mL(1:i+halfW),   'omitnan');
	smA2L(N_TRIAL-i+1) = mean(mA2L(N_TRIAL-i-halfW+1:end), 'omitnan');
	smL(N_TRIAL-i+1)   = mean(mL(N_TRIAL-i-halfW+1:end),   'omitnan');
end

smA2L_sem = zeros(N_TRIAL,1);
smL_sem   = zeros(N_TRIAL,1);
for t = 1:N_TRIAL
	tStart = max(1, t-halfW);
	tEnd   = min(N_TRIAL, t+halfW);
	wA = mean(alignedA2L(:, tStart:tEnd), 2, 'omitnan');
	wL = mean(alignedL(:,   tStart:tEnd), 2, 'omitnan');
	vA = isfinite(wA); vL = isfinite(wL);
	if sum(vA) >= 2, smA2L_sem(t) = std(wA(vA)) / sqrt(sum(vA)); end
	if sum(vL) >= 2, smL_sem(t)   = std(wL(vL)) / sqrt(sum(vL)); end
end

%% --- 5. 分块统计（10试次/块）---
BLOCK_SIZE = 10;
nBlocks = floor(N_TRIAL / BLOCK_SIZE);
blockMeanA2L = zeros(nBlocks,1); blockSemA2L = zeros(nBlocks,1);
blockMeanL   = zeros(nBlocks,1); blockSemL   = zeros(nBlocks,1);

for b = 1:nBlocks
	tIdx = (b-1)*BLOCK_SIZE + (1:BLOCK_SIZE);
	blkA2L = mean(alignedA2L(:, tIdx), 2, 'omitnan');
	blkL   = mean(alignedL(:,   tIdx), 2, 'omitnan');
	vA = isfinite(blkA2L); vL = isfinite(blkL);
	if sum(vA) >= 2
		blockMeanA2L(b) = mean(blkA2L(vA));
		blockSemA2L(b)  = std(blkA2L(vA)) / sqrt(sum(vA));
	end
	if sum(vL) >= 2
		blockMeanL(b) = mean(blkL(vL));
		blockSemL(b)  = std(blkL(vL)) / sqrt(sum(vL));
	end
end

%% --- 5b. 分块统计检验（非配对：Welch t-test）---
blockP_A2LvsL = nan(nBlocks, 1);
for b = 1:nBlocks
	tIdx = (b-1)*BLOCK_SIZE + (1:BLOCK_SIZE);
	blkA2L = mean(alignedA2L(:, tIdx), 2, 'omitnan');
	blkL   = mean(alignedL(:,   tIdx), 2, 'omitnan');
	vA = isfinite(blkA2L); vL = isfinite(blkL);
	if sum(vA) >= 2 && sum(vL) >= 2
		[~, blockP_A2LvsL(b)] = ttest2(blkA2L(vA), blkL(vL), 'Vartype', 'unequal');
	end
end
sigBlocks = find(blockP_A2LvsL < 0.05);
fprintf('\nBlock-by-block Welch t-test (A2L vs L, unpaired):\n');
for b = 1:nBlocks
	sig = '';
	if blockP_A2LvsL(b) < 0.05, sig = ' *'; end
	if blockP_A2LvsL(b) < 0.01, sig = '**'; end
	if blockP_A2LvsL(b) < 0.001, sig = '***'; end
	fprintf('  Block %d: p=%.4f%s\n', b, blockP_A2LvsL(b), sig);
end

%% --- 6. 累积正确曲线 ---
cumA2L = cumsum(alignedA2L, 2, 'omitnan');
cumL   = cumsum(alignedL,   2, 'omitnan');
cumMeanA2L = mean(cumA2L, 1, 'omitnan')';
cumSemA2L  = std(cumA2L, 0, 1, 'omitnan')' ./ sqrt(sum(isfinite(cumA2L), 1))';
cumMeanL   = mean(cumL,   1, 'omitnan')';
cumSemL    = std(cumL,   0, 1, 'omitnan')' ./ sqrt(sum(isfinite(cumL),   1))';

chanceLevel = 0.5;
chanceCum = chanceLevel * x;

%% --- 7. 输出 Summary CSV ---
summaryTable = table;
summaryTable.Trial        = x;
summaryTable.A2L_Mean     = mA2L;
summaryTable.A2L_SEM      = sA2L;
summaryTable.A2L_Smooth   = smA2L;
summaryTable.A2L_SmoothSem = smA2L_sem;
summaryTable.L_Mean       = mL;
summaryTable.L_SEM        = sL;
summaryTable.L_Smooth     = smL;
summaryTable.L_SmoothSem  = smL_sem;
summaryTable.A2L_CumMean  = cumMeanA2L;
summaryTable.A2L_CumSem   = cumSemA2L;
summaryTable.L_CumMean    = cumMeanL;
summaryTable.L_CumSem     = cumSemL;

blockSummary = table;
blockSummary.Block      = (1:nBlocks)';
blockSummary.TrialRange = compose("%d-%d", (0:nBlocks-1)'*BLOCK_SIZE+1, (1:nBlocks)'*BLOCK_SIZE);
blockSummary.A2L_Mean   = blockMeanA2L;
blockSummary.A2L_SEM    = blockSemA2L;
blockSummary.L_Mean     = blockMeanL;
blockSummary.L_SEM      = blockSemL;

writetable(summaryTable, fullfile(OUTPUT_DIR, xlsxName), 'Sheet', 'TrialWise');
writetable(blockSummary, fullfile(OUTPUT_DIR, xlsxName), 'Sheet', 'BlockSummary');
fprintf('Wrote: %s\n', fullfile(OUTPUT_DIR, xlsxName));

%% ========================================================================
%  绘图
%  ========================================================================

TEAL   = [0.259, 0.580, 0.620];  % Transfer
VIOLET = [0.604, 0.302, 0.557];  % Naive
xBlock = (1:nBlocks)';
bWidth = 0.35; xOff = 0.2;

%% --- (a) 逐试次滑动平均学习曲线 ---
f1 = figure('Position', [100, 100, 650, 450], 'Color', 'w');
ax1 = axes(f1); hold(ax1, 'on');
fill(ax1, [x; flipud(x)], [smA2L - smA2L_sem; flipud(smA2L + smA2L_sem)], ...
	TEAL, 'EdgeColor', 'none', 'FaceAlpha', 0.2, 'HandleVisibility', 'off');
fill(ax1, [x; flipud(x)], [smL - smL_sem; flipud(smL + smL_sem)], ...
	VIOLET, 'EdgeColor', 'none', 'FaceAlpha', 0.2, 'HandleVisibility', 'off');
p1 = plot(ax1, x, smA2L, '-', 'Color', TEAL, 'LineWidth', 2.5, ...
	'DisplayName', sprintf('Transfer (n=%d)', size(alignedA2L,1)));
p2 = plot(ax1, x, smL, '-', 'Color', VIOLET, 'LineWidth', 2.5, ...
	'DisplayName', sprintf('Naive (n=%d)', size(alignedL,1)));
plot(ax1, x([1 end]), [chanceLevel chanceLevel], '--', 'Color', [0.5 0.5 0.5], ...
	'LineWidth', 1.2, 'HandleVisibility', 'off');
hold(ax1, 'off');
xlabel(ax1, 'Trial', 'FontSize', 14);
ylabel(ax1, 'Hit rate (smoothed)', 'FontSize', 14);
xlim(ax1, [1 N_TRIAL]); ylim(ax1, [0 1.05]);
legend(ax1, [p1, p2], 'Location', 'northwest', 'Box', 'off', 'FontSize', 12);
box(ax1, 'off');
set(ax1, 'FontSize', 13, 'LineWidth', 1.2, 'TickDir', 'out');
ax1.Toolbar.Visible = 'off';

%% --- (b) 分块柱状图 ---
f2 = figure('Position', [800, 100, 550, 400], 'Color', 'w');
ax2 = axes(f2); hold(ax2, 'on');
for b = 1:nBlocks
	rectangle(ax2, 'Position', [b - xOff - bWidth/2, 0, bWidth, blockMeanA2L(b)], ...
		'FaceColor', TEAL, 'EdgeColor', 'none', 'FaceAlpha', 0.7);
	errorbar(ax2, b - xOff, blockMeanA2L(b), blockSemA2L(b), ...
		'Color', TEAL, 'LineWidth', 1.5, 'CapSize', 6);
	rectangle(ax2, 'Position', [b + xOff - bWidth/2, 0, bWidth, blockMeanL(b)], ...
		'FaceColor', VIOLET, 'EdgeColor', 'none', 'FaceAlpha', 0.7);
	errorbar(ax2, b + xOff, blockMeanL(b), blockSemL(b), ...
		'Color', VIOLET, 'LineWidth', 1.5, 'CapSize', 6);
end
hold(ax2, 'off');
xlabel(ax2, 'Block (10 trials)', 'FontSize', 14);
ylabel(ax2, 'Hit rate', 'FontSize', 14);
xlim(ax2, [0.5, nBlocks+0.5]); ylim(ax2, [0 1.05]);
legend(ax2, {'Transfer', 'Naive'}, 'Location', 'northeast', ...
	'Box', 'off', 'FontSize', 11);
box(ax2, 'off');
set(ax2, 'FontSize', 13, 'LineWidth', 1.2, 'TickDir', 'out');
xticks(ax2, 1:nBlocks);
ax2.Toolbar.Visible = 'off';

% 显著性标注（Welch t-test, p<0.05）
sigYoffset = 0.05;
yl = ylim(ax2);
for b = sigBlocks(:)'
	yMax = max(blockMeanA2L(b)+blockSemA2L(b), blockMeanL(b)+blockSemL(b));
	ySig = yMax + sigYoffset;
	% 横线
	plot(ax2, [b-xOff, b+xOff], [ySig, ySig], 'k-', 'LineWidth', 1, 'HandleVisibility', 'off');
	% 竖线
	plot(ax2, [b-xOff, b-xOff], [ySig-0.01, ySig], 'k-', 'LineWidth', 1, 'HandleVisibility', 'off');
	plot(ax2, [b+xOff, b+xOff], [ySig-0.01, ySig], 'k-', 'LineWidth', 1, 'HandleVisibility', 'off');
	% 星号
	if blockP_A2LvsL(b) < 0.001,  sigStr = '***';
	elseif blockP_A2LvsL(b) < 0.01, sigStr = '**';
	else,                           sigStr = '*';
	end
	text(ax2, b, ySig+0.02, sigStr, ...
		'HorizontalAlignment', 'center', 'FontSize', 14, ...
		'FontName', 'Arial', 'HandleVisibility', 'off');
end

%% --- (c) 累积正确曲线 ---
f3 = figure('Position', [1400, 100, 550, 400], 'Color', 'w');
ax3 = axes(f3); hold(ax3, 'on');
fill(ax3, [x; flipud(x)], [cumMeanA2L - cumSemA2L; flipud(cumMeanA2L + cumSemA2L)], ...
	TEAL, 'EdgeColor', 'none', 'FaceAlpha', 0.2, 'HandleVisibility', 'off');
fill(ax3, [x; flipud(x)], [cumMeanL - cumSemL; flipud(cumMeanL + cumSemL)], ...
	VIOLET, 'EdgeColor', 'none', 'FaceAlpha', 0.2, 'HandleVisibility', 'off');
p3a = plot(ax3, x, cumMeanA2L, '-', 'Color', TEAL, 'LineWidth', 2.5, ...
	'DisplayName', 'Transfer');
p3b = plot(ax3, x, cumMeanL, '-', 'Color', VIOLET, 'LineWidth', 2.5, ...
	'DisplayName', 'Naive');
pChance = plot(ax3, x, chanceCum, '--', 'Color', [0.5 0.5 0.5], 'LineWidth', 1.2, ...
	'DisplayName', 'Chance');
pPerfect = plot(ax3, x, x, ':', 'Color', [0.7 0.7 0.7], 'LineWidth', 1, ...
	'DisplayName', 'Perfect');
hold(ax3, 'off');
xlabel(ax3, 'Trial', 'FontSize', 14);
ylabel(ax3, 'Cumulative correct', 'FontSize', 14);
xlim(ax3, [1 N_TRIAL]); ylim(ax3, [0 N_TRIAL]);
legend(ax3, [p3a, p3b, pChance, pPerfect], ...
	'Location', 'northwest', 'Box', 'off', 'FontSize', 11);
box(ax3, 'off');
set(ax3, 'FontSize', 13, 'LineWidth', 1.2, 'TickDir', 'out');
ax3.Toolbar.Visible = 'off';

%% --- 8. 导出 SVG ---
if ~isfolder(OUTPUT_DIR)
	mkdir(OUTPUT_DIR);
end

figure(f1);
print(gcf, fullfile(OUTPUT_DIR, 'FirstBlock_TrialWise.svg'), '-dsvg', '-vector');
fprintf('Wrote: %s\n', fullfile(OUTPUT_DIR, 'FirstBlock_TrialWise.svg'));

figure(f2);
print(gcf, fullfile(OUTPUT_DIR, 'FirstBlock_Blocked.svg'), '-dsvg', '-vector');
fprintf('Wrote: %s\n', fullfile(OUTPUT_DIR, 'FirstBlock_Blocked.svg'));

figure(f3);
print(gcf, fullfile(OUTPUT_DIR, 'FirstBlock_Cumulative.svg'), '-dsvg', '-vector');
fprintf('Wrote: %s\n', fullfile(OUTPUT_DIR, 'FirstBlock_Cumulative.svg'));

% 组合三图到一张 SVG
fCombined = figure('Position', [100, 100, 1600, 450], 'Color', 'w');
tcl = tiledlayout(fCombined, 1, 3, 'TileSpacing', 'compact', 'Padding', 'compact');

% --- 组合图 (a) ---
nexttile; hold on;
fill([x; flipud(x)], [smA2L - smA2L_sem; flipud(smA2L + smA2L_sem)], ...
	TEAL, 'EdgeColor', 'none', 'FaceAlpha', 0.2, 'HandleVisibility', 'off');
fill([x; flipud(x)], [smL - smL_sem; flipud(smL + smL_sem)], ...
	VIOLET, 'EdgeColor', 'none', 'FaceAlpha', 0.2, 'HandleVisibility', 'off');
h_a1 = plot(x, smA2L, '-', 'Color', TEAL, 'LineWidth', 2.5, 'DisplayName', 'Transfer');
h_a2 = plot(x, smL, '-', 'Color', VIOLET, 'LineWidth', 2.5, 'DisplayName', 'Naive');
plot(x([1,end]), [chanceLevel chanceLevel], '--', 'Color', [0.5 0.5 0.5], 'LineWidth', 1, ...
	'HandleVisibility', 'off');
hold off;
xlabel('Trial', 'FontSize', 12); ylabel('Hit rate (smoothed)', 'FontSize', 12);
xlim([1 N_TRIAL]); ylim([0 1.05]);
legend([h_a1, h_a2], 'Location', 'northwest', 'Box', 'off', 'FontSize', 10);
box off; set(gca, 'FontSize', 11, 'LineWidth', 1, 'TickDir', 'out');

% --- 组合图 (b) ---
nexttile; hold on;
for b = 1:nBlocks
	rectangle('Position', [b - xOff - bWidth/2, 0, bWidth, blockMeanA2L(b)], ...
		'FaceColor', TEAL, 'EdgeColor', 'none', 'FaceAlpha', 0.7);
	errorbar(b - xOff, blockMeanA2L(b), blockSemA2L(b), 'Color', TEAL, 'LineWidth', 1.5, 'CapSize', 6);
	rectangle('Position', [b + xOff - bWidth/2, 0, bWidth, blockMeanL(b)], ...
		'FaceColor', VIOLET, 'EdgeColor', 'none', 'FaceAlpha', 0.7);
	errorbar(b + xOff, blockMeanL(b), blockSemL(b), 'Color', VIOLET, 'LineWidth', 1.5, 'CapSize', 6);
end
% 用不可见线作为图例代理对象
h_b1 = plot(nan, nan, 's', 'Color', TEAL, 'MarkerFaceColor', TEAL, 'LineWidth', 2, ...
	'MarkerSize', 10, 'HandleVisibility', 'on');
h_b2 = plot(nan, nan, 's', 'Color', VIOLET, 'MarkerFaceColor', VIOLET, 'LineWidth', 2, ...
	'MarkerSize', 10, 'HandleVisibility', 'on');
% 显著性标注
for b = sigBlocks(:)'
	yMax = max(blockMeanA2L(b)+blockSemA2L(b), blockMeanL(b)+blockSemL(b));
	ySig = yMax + 0.05;
	plot([b-xOff, b+xOff], [ySig, ySig], 'k-', 'LineWidth', 1, 'HandleVisibility', 'off');
	plot([b-xOff, b-xOff], [ySig-0.01, ySig], 'k-', 'LineWidth', 1, 'HandleVisibility', 'off');
	plot([b+xOff, b+xOff], [ySig-0.01, ySig], 'k-', 'LineWidth', 1, 'HandleVisibility', 'off');
	if blockP_A2LvsL(b) < 0.001,  sigStr = '***';
	elseif blockP_A2LvsL(b) < 0.01, sigStr = '**';
	else,                           sigStr = '*';
	end
	text(b, ySig+0.02, sigStr, 'HorizontalAlignment', 'center', ...
		'FontSize', 12, 'FontName', 'Arial', 'HandleVisibility', 'off');
end
hold off;
xlabel('Block (10 trials)', 'FontSize', 12); ylabel('Hit rate', 'FontSize', 12);
xlim([0.5 nBlocks+0.5]); ylim([0 1.05]);
legend([h_b1, h_b2], {'Transfer', 'Naive'}, ...
	'Location', 'northeast', 'Box', 'off', 'FontSize', 10);
box off; set(gca, 'FontSize', 11, 'LineWidth', 1, 'TickDir', 'out'); xticks(1:nBlocks);

% --- 组合图 (c) ---
nexttile; hold on;
fill([x; flipud(x)], [cumMeanA2L - cumSemA2L; flipud(cumMeanA2L + cumSemA2L)], ...
	TEAL, 'EdgeColor', 'none', 'FaceAlpha', 0.2, 'HandleVisibility', 'off');
fill([x; flipud(x)], [cumMeanL - cumSemL; flipud(cumMeanL + cumSemL)], ...
	VIOLET, 'EdgeColor', 'none', 'FaceAlpha', 0.2, 'HandleVisibility', 'off');
h_c1 = plot(x, cumMeanA2L, '-', 'Color', TEAL, 'LineWidth', 2.5, 'DisplayName', 'Transfer');
h_c2 = plot(x, cumMeanL, '-', 'Color', VIOLET, 'LineWidth', 2.5, 'DisplayName', 'Naive');
h_c3 = plot(x, chanceCum, '--', 'Color', [0.5 0.5 0.5], 'LineWidth', 1, 'DisplayName', 'Chance');
h_c4 = plot(x, x, ':', 'Color', [0.7 0.7 0.7], 'LineWidth', 1, 'DisplayName', 'Perfect');
hold off;
xlabel('Trial', 'FontSize', 12); ylabel('Cumulative correct', 'FontSize', 12);
xlim([1 N_TRIAL]); ylim([0 N_TRIAL]);
legend([h_c1, h_c2, h_c3, h_c4], 'Location', 'northwest', 'Box', 'off', 'FontSize', 10);
box off; set(gca, 'FontSize', 11, 'LineWidth', 1, 'TickDir', 'out');

print(fCombined, fullfile(OUTPUT_DIR, svgName), '-dsvg', '-vector');
fprintf('Wrote: %s\n', fullfile(OUTPUT_DIR, svgName));

%% --- (d) Day 4 bar+scatter ---
% 第4个 session 表现：Transfer vs Naive
fprintf('\n--- Day 4 performance ---\n');

perfD4 = iDay4Performance(DataSetA2L, 'Transfer');
perfD4 = [perfD4; iDay4Performance(DataSetL, 'Naive')];
perfD4 = sortrows(perfD4, 'Group');

% 统计
yT = perfD4.Perf(strcmp(perfD4.Group, 'Transfer') & isfinite(perfD4.Perf));
yN = perfD4.Perf(strcmp(perfD4.Group, 'Naive') & isfinite(perfD4.Perf));
[~, pD4] = ttest2(yT, yN, 'Vartype', 'unequal');
pD4_MW = ranksum(yT, yN);
fprintf('Transfer: %.4f±%.4f (n=%d)\n', mean(yT), std(yT)/sqrt(numel(yT)), numel(yT));
fprintf('Naive:    %.4f±%.4f (n=%d)\n', mean(yN), std(yN)/sqrt(numel(yN)), numel(yN));
fprintf('Welch t-test p=%.6f, MW p=%.6f\n', pD4, pD4_MW);

fD4 = figure('Position', [100, 100, 350, 420], 'Color', 'w');
axD4 = axes(fD4); hold(axD4, 'on');

% 配色（沿用已有 TEAL/VIOLET，散点加深）
TEAL_DK   = TEAL   * 0.5;
VIOLET_DK = VIOLET * 0.5;

grpNames = {'Naive', 'Transfer'};
grpColors = [VIOLET; TEAL];
grpColorsDK = [VIOLET_DK; TEAL_DK];
xPos = [1, 2];
jit = 0.12;

for g = 1:2
	idx = strcmp(perfD4.Group, grpNames{g});
	y = perfD4.Perf(idx);
	y = y(isfinite(y));
	n = numel(y);
	my = mean(y);
	sy = std(y) / sqrt(n);

	% 柱（Nature 风格：半透明）
	rectangle(axD4, 'Position', [xPos(g)-0.18, 0, 0.36, my], ...
		'FaceColor', grpColors(g,:), 'EdgeColor', 'none', 'FaceAlpha', 0.55);
	% errorbar
	errorbar(axD4, xPos(g), my, sy, 'Color', grpColors(g,:), ...
		'LineWidth', 1.2, 'CapSize', 6);
	% 散点（同色填充，无描边）
	rng(g);
	xJ = xPos(g) + (rand(n,1)-0.5)*2*jit;
	scatter(axD4, xJ, y, 36, 'o', 'MarkerFaceColor', grpColorsDK(g,:), ...
		'MarkerEdgeColor', 'none', 'MarkerFaceAlpha', 0.85);
end

% 显著性横线 + 星号（Nature 风格）
if pD4 < 0.05
	yMax = max(perfD4.Perf(isfinite(perfD4.Perf)));
	ySig = yMax + 0.06;
	plot(axD4, [1, 2], [ySig, ySig], 'k-', 'LineWidth', 0.8, 'HandleVisibility', 'off');
	plot(axD4, [1, 1], [ySig-0.015, ySig], 'k-', 'LineWidth', 0.8, 'HandleVisibility', 'off');
	plot(axD4, [2, 2], [ySig-0.015, ySig], 'k-', 'LineWidth', 0.8, 'HandleVisibility', 'off');
	if pD4_MW < 0.001,    sigStr = '***';
	elseif pD4_MW < 0.01, sigStr = '**';
	else,                 sigStr = '*';
	end
	text(axD4, 1.5, ySig+0.025, sigStr, ...
		'HorizontalAlignment', 'center', ...
		'FontSize', 14, 'FontName', 'Arial', ...
		'HandleVisibility', 'off');
end

hold(axD4, 'off');

% Nature 风格轴设置
xlabel(axD4, '', 'FontSize', 12, 'FontName', 'Arial');
ylabel(axD4, 'Performance', 'FontSize', 12, 'FontName', 'Arial');
xlim(axD4, [0.5, 2.5]);
ylim(axD4, [0, 1.18]);
set(axD4, 'FontName', 'Arial', 'FontSize', 11, ...
	'LineWidth', 0.8, 'TickDir', 'out', 'TickLength', [0.02 0.02]);
xticks(axD4, [1, 2]);
xticklabels(axD4, {'Naive', 'Transfer'});
box(axD4, 'off');
axD4.Toolbar.Visible = 'off';

% 导出
print(fD4, fullfile(OUTPUT_DIR, 'FirstBlock_Day4_BarScatter.svg'), '-dsvg', '-vector');
fprintf('Wrote: %s\n', fullfile(OUTPUT_DIR, 'FirstBlock_Day4_BarScatter.svg'));

%% --- (e) First Block bar+scatter (trials 1-10) ---
fprintf('\n--- First Block performance (trials 1-10) ---\n');

b1A = mean(alignedA2L(:, 1:10), 2, 'omitnan');
b1L = mean(alignedL(:,   1:10), 2, 'omitnan');
b1A = b1A(isfinite(b1A));
b1L = b1L(isfinite(b1L));

[~, pFB] = ttest2(b1A, b1L, 'Vartype', 'unequal');
pFB_MW = ranksum(b1A, b1L);
fprintf('Naive:    %.4f±%.4f (n=%d)\n', mean(b1L), std(b1L)/sqrt(numel(b1L)), numel(b1L));
fprintf('Transfer: %.4f±%.4f (n=%d)\n', mean(b1A), std(b1A)/sqrt(numel(b1A)), numel(b1A));
fprintf('Welch t-test p=%.6f, MW p=%.6f\n', pFB, pFB_MW);

% 图
fFB = figure('Position', [100, 100, 350, 420], 'Color', 'w');
axFB = axes(fFB); hold(axFB, 'on');

TEAL_DK   = TEAL   * 0.5;
VIOLET_DK = VIOLET * 0.5;
jit = 0.12;

yGrp = {b1L, b1A};
grpLabels = {'Naive', 'Transfer'};
grpColors = [VIOLET; TEAL];
grpColorsDK = [VIOLET_DK; TEAL_DK];
nGrp = 2;

for g = 1:nGrp
	y = yGrp{g};
	n = numel(y);
	my = mean(y);
	sy = std(y) / sqrt(n);
	% 柱
	rectangle(axFB, 'Position', [g-0.18, 0, 0.36, my], ...
		'FaceColor', grpColors(g,:), 'EdgeColor', 'none', 'FaceAlpha', 0.55);
	% errorbar
	errorbar(axFB, g, my, sy, 'Color', grpColors(g,:), ...
		'LineWidth', 1.2, 'CapSize', 6);
	% 散点
	rng(g);
	xJ = g + (rand(n,1)-0.5)*2*jit;
	scatter(axFB, xJ, y, 36, 'o', 'MarkerFaceColor', grpColorsDK(g,:), ...
		'MarkerEdgeColor', 'none', 'MarkerFaceAlpha', 0.85);
end

% 显著性
if pFB < 0.05
	yMax = max([b1L; b1A]);
	ySig = yMax + 0.06;
	plot(axFB, [1, 2], [ySig, ySig], 'k-', 'LineWidth', 0.8, 'HandleVisibility', 'off');
	plot(axFB, [1, 1], [ySig-0.015, ySig], 'k-', 'LineWidth', 0.8, 'HandleVisibility', 'off');
	plot(axFB, [2, 2], [ySig-0.015, ySig], 'k-', 'LineWidth', 0.8, 'HandleVisibility', 'off');
	if pFB_MW < 0.001,     sigStr = '***';
	elseif pFB_MW < 0.01,  sigStr = '**';
	else,                  sigStr = '*';
	end
	text(axFB, 1.5, ySig+0.025, sigStr, ...
		'HorizontalAlignment', 'center', 'FontSize', 14, ...
		'FontName', 'Arial', 'HandleVisibility', 'off');
end

hold(axFB, 'off');
xlabel(axFB, '', 'FontSize', 12, 'FontName', 'Arial');
ylabel(axFB, 'Performance', 'FontSize', 12, 'FontName', 'Arial');
xlim(axFB, [0.5, 2.5]);
ylim(axFB, [0, 1.18]);
set(axFB, 'FontName', 'Arial', 'FontSize', 11, ...
	'LineWidth', 0.8, 'TickDir', 'out', 'TickLength', [0.02 0.02]);
xticks(axFB, [1, 2]);
xticklabels(axFB, grpLabels);
box(axFB, 'off');
axFB.Toolbar.Visible = 'off';

print(fFB, fullfile(OUTPUT_DIR, 'FirstBlock_Block1_BarScatter.svg'), '-dsvg', '-vector');
fprintf('Wrote: %s\n', fullfile(OUTPUT_DIR, 'FirstBlock_Block1_BarScatter.svg'));

%% --- 9. 写入工作区 ---
assignin('base', 'FirstBlock_A2L_Trials',   trialsA2L);
assignin('base', 'FirstBlock_L_Trials',     trialsL);
assignin('base', 'FirstBlock_Aligned_A2L',  alignedA2L);
assignin('base', 'FirstBlock_Aligned_L',    alignedL);
assignin('base', 'FirstBlock_Summary',      summaryTable);
assignin('base', 'FirstBlock_BlockSummary', blockSummary);
assignin('base', 'FirstBlock_Day4_Perf',    perfD4);
assignin('base', 'FirstBlock_Day4_p',       pD4);
assignin('base', 'FirstBlock_Day4_pMW',     pD4_MW);
assignin('base', 'FirstBlock_Block1_Naive',  b1L);
assignin('base', 'FirstBlock_Block1_Transfer', b1A);
assignin('base', 'FirstBlock_Block1_p',      pFB);
assignin('base', 'FirstBlock_Block1_pMW',    pFB_MW);

fprintf('\n=== Done ===\n');

%% ========================================================================
%  本地函数
%  ========================================================================

function T = iDay4Performance(DS, groupName)
	% 提取每只小鼠第4个 session 的 LightLearnWater 平均表现
	dtTbl = DS.DateTimes(:, {'DateTime', 'Mouse'});
	dtTbl.DateTime = datetime(dtTbl.DateTime);
	dtTbl.Mouse = string(dtTbl.Mouse);
	dtTbl = sortrows(dtTbl, {'Mouse', 'DateTime'});

	[G, mouseVals] = findgroups(dtTbl.Mouse);
	mouseVals = string(mouseVals);
	nMice = numel(mouseVals);

	T = table;
	T.Mouse = mouseVals;
	T.Group = repmat(string(groupName), nMice, 1);
	T.Perf = nan(nMice, 1);

	blk = DS.Blocks(:, {'BlockUID', 'DateTime'});
	blk.DateTime = datetime(blk.DateTime);

	for m = 1:nMice
		rows = dtTbl.Mouse == mouseVals(m);
		dts = sort(dtTbl.DateTime(rows));
		if numel(dts) < 4
			fprintf('  %s %s: <4 sessions, skipped\n', groupName, mouseVals(m));
			continue;
		end
		dt = dts(4);
		blkMatch = abs(blk.DateTime - dt) < seconds(60);
		blkIDs = blk.BlockUID(blkMatch);
		if isempty(blkIDs), continue; end

		tr = DS.Trials;
		tr.BlockUID = double(tr.BlockUID);
		trS = tr(ismember(tr.BlockUID, double(blkIDs)) & ...
			ismember(string(tr.Stimulus), ["LightLearnWater","LightLearnWaterAlways"]), :);
		hit = double(trS.Behavior);
		hit = hit(isfinite(hit));
		if ~isempty(hit)
			T.Perf(m) = mean(hit);
		end
	end
	fprintf('  %s: %d mice with Day 4 data\n', groupName, sum(isfinite(T.Perf)));
end

function T = iExtractFirstSessionTrials(DS, groupName)
	% 提取每只小鼠首次 DateTime session 的所有 LightWater 试次
	%
	% 输入: DS - UniExp.DataSet 对象
	%       groupName - 组名（字符串）
	% 输出: T - 表，每行一个试次，含 Mouse, Trial (1-based), Hit (0/1), Group

	% 1) DateTimes: 每鼠取最早 DateTime
	dtTbl = DS.DateTimes(:, {'DateTime', 'Mouse'});
	dtTbl.DateTime = datetime(dtTbl.DateTime);
	dtTbl.Mouse = string(dtTbl.Mouse);
	dtTbl = sortrows(dtTbl, {'Mouse', 'DateTime'});

	[Gdt, mouseVals] = findgroups(dtTbl.Mouse);
	firstDT = splitapply(@(x) min(x), dtTbl.DateTime, Gdt);
	firstDT = datetime(firstDT);  % 确保是 datetime 类型
	mouseVals = string(mouseVals);
	nMice = numel(mouseVals);

	fprintf('  %s: %d mice\n', groupName, nMice);
	for m = 1:nMice
		fprintf('    %s: first session %s\n', mouseVals(m), datestr(firstDT(m)));
	end

	% 2) 找到首次 DateTime 对应的 BlockUID
	blk = DS.Blocks(:, {'BlockUID', 'DateTime'});
	blk.BlockUID = double(blk.BlockUID);
	blk.DateTime = datetime(blk.DateTime);

	firstBlockUIDs = double([]);
	for m = 1:nMice
		dtMatch = abs(blk.DateTime - firstDT(m)) < seconds(60);
		if any(dtMatch)
			firstBlockUIDs = [firstBlockUIDs; blk.BlockUID(dtMatch)];
		end
	end

	% 3) 获取 Trials，筛选 LightLearnWater + LightLearnWaterAlways
	tr = DS.Trials(:, {'BlockUID', 'Stimulus', 'Behavior', 'TrialIndex'});
	tr.BlockUID = double(tr.BlockUID);
	trLW = tr(ismember(string(tr.Stimulus), ["LightLearnWater", "LightLearnWaterAlways"]), :);

	% 4) 仅保留首次 session 的试次
	trLW = trLW(ismember(trLW.BlockUID, firstBlockUIDs), :);
	if isempty(trLW)
		T = table(string.empty(0,1), zeros(0,1), zeros(0,1), strings(0,1), ...
			'VariableNames', {'Mouse', 'Trial', 'Hit', 'Group'});
		return;
	end

	% 5) 连接回 Blocks 获取 DateTime，再连接 DateTimes 获取 Mouse
	Tblk = innerjoin(trLW, blk, 'Keys', 'BlockUID');
	Tdt = innerjoin(Tblk, DS.DateTimes(:, {'DateTime', 'Mouse'}), 'Keys', 'DateTime');

	% 6) 整理输出
	Tdt.Mouse = string(Tdt.Mouse);
	Tdt = sortrows(Tdt, {'Mouse', 'TrialIndex'});

	T = table;
	T.Mouse = Tdt.Mouse;
	T.Trial = double(Tdt.TrialIndex);
	T.Hit   = double(Tdt.Behavior);
	T.Hit(~ismember(T.Hit, [0, 1])) = NaN;
	T.Group = repmat(string(groupName), height(T), 1);
	T = sortrows(T, {'Mouse', 'Trial'});
end


function [alignedA2L, alignedL] = iAlignTrialsToMax(trialsA2L, trialsL, maxTrials)
	% 将每只小鼠的试次序列对齐到统一的试次轴 1:maxTrials
	% 输出: [nMice x maxTrials] 矩阵，缺失值填 NaN

	miceA2L = unique(trialsA2L.Mouse);
	miceL   = unique(trialsL.Mouse);
	nA = numel(miceA2L);
	nL = numel(miceL);
	alignedA2L = nan(nA, maxTrials);
	alignedL   = nan(nL, maxTrials);

	for m = 1:nA
		rows = trialsA2L.Mouse == miceA2L(m);
		tr = trialsA2L.Trial(rows);
		hit = trialsA2L.Hit(rows);
		for i = 1:numel(tr)
			t = tr(i);
			if t >= 1 && t <= maxTrials
				alignedA2L(m, t) = hit(i);
			end
		end
	end
	for m = 1:nL
		rows = trialsL.Mouse == miceL(m);
		tr = trialsL.Trial(rows);
		hit = trialsL.Hit(rows);
		for i = 1:numel(tr)
			t = tr(i);
			if t >= 1 && t <= maxTrials
				alignedL(m, t) = hit(i);
			end
		end
	end
end
