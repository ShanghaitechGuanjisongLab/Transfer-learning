%% 20260709 — Light Learning Curve: A2L vs L
% 对 DataSetA2L (AL Light) 和 DataSetL (LA Light) 两组：
%   1. 用 UniExp.LearningSummarize 补齐数据并输出表格
%   2. Nature 风格 errorbar 图（参考 beh0709_nature_style.mlx）
%   3. 逐点 AnovaN 分析（与作图点一一对应）
% 输出 SVG+CSV 到 \\Data-Server-2\个人数据\杨青宁\202607

%% --- 0. 路径与项目加载 ---
dataRoot = '\\Data-Server-2\个人数据\杨青宁\202607\行为学';
OUTPUT_DIR = '\\Data-Server-2\个人数据\杨青宁\202607';
svgName = '20260709_LightLearningCurve_A2L_vs_L.svg';
summaryCsvName = '20260709_LightLearningCurve_Summary.csv';
anovaCsvName = '20260709_LightLearningCurve_AnovaN.csv';

if ~exist('UniExp.DataSet', 'class')
	prjFile = fullfile('d:\Users\杨青宁\Documents\MATLAB\Transfer-learning', 'Transferlearning.prj');
	matlab.project.loadProject(prjFile);
end

%% --- 1. 加载数据 ---
DataSetA   = UniExp.DataSet(fullfile(dataRoot, 'A2L_A.mat'));
DataSet2A  = UniExp.DataSet(fullfile(dataRoot, 'L2A_A.mat'));
DataSetA2L = UniExp.DataSet(fullfile(dataRoot, 'A2L_L.mat'));
DataSetL   = UniExp.DataSet(fullfile(dataRoot, 'L2A_L.mat'));

%% --- 2. 提取会话表 ---
sessionA2L = DataSetA2L.TableQuery(["Mouse", "DateTime", "Performance"]);
sessionA2L.Group(:) = "A2L";
sessionL   = DataSetL.TableQuery(["Mouse", "DateTime", "Performance"]);
sessionL.Group(:)   = "L";
allSessions = [sessionA2L; sessionL];
allSessions = sortrows(allSessions, ["Group", "Mouse", "DateTime"]);

fprintf('A2L: %d sessions, %d unique mice\n', ...
	height(sessionA2L), numel(unique(sessionA2L.Mouse)));
fprintf('L:   %d sessions, %d unique mice\n', ...
	height(sessionL),   numel(unique(sessionL.Mouse)));

%% --- 3. UniExp.LearningSummarize（补齐+输出表格）---
[Summary, PValueOverall] = UniExp.LearningSummarize(allSessions);
disp(Summary);
fprintf('Overall P = %.6f\n', PValueOverall);

% 解包 mean/sem（两组长度可能不同，A2L=8block, L=9block）
mA2L = Summary.MeanCurve{1}(:);  sA2L = Summary.SemCurve{1}(:);
mL   = Summary.MeanCurve{2}(:);  sL   = Summary.SemCurve{2}(:);
maxLen = max(numel(mA2L), numel(mL));
meanMat = nan(maxLen, 2); semMat = nan(maxLen, 2);
meanMat(1:numel(mA2L),1) = mA2L; meanMat(1:numel(mL),2) = mL;
semMat(1:numel(sA2L),1)  = sA2L; semMat(1:numel(sL),2)  = sL;
x = (1:maxLen).';

% 输出 summary 表格
summaryTable = table;
summaryTable.Block    = x;
summaryTable.A2L_Mean = meanMat(:,1);
summaryTable.A2L_SEM  = semMat(:,1);
summaryTable.A2L_N    = grpstats(allSessions(allSessions.Group=="A2L",:), ...
    findgroups(allSessions.DateTime(allSessions.Group=="A2L")), 'numel');
summaryTable.L_Mean   = meanMat(:,2);
summaryTable.L_SEM    = semMat(:,2);
summaryTable.L_N      = grpstats(allSessions(allSessions.Group=="L",:), ...
    findgroups(allSessions.DateTime(allSessions.Group=="L")), 'numel');
writetable(summaryTable, fullfile(OUTPUT_DIR, summaryCsvName));
fprintf('Wrote: %s\n', fullfile(OUTPUT_DIR, summaryCsvName));

%% --- 4. 构建对齐后的每鼠每点矩阵（与 LearningSummarize 补齐逻辑一致）---
% 将各鼠的 session 对齐到最大 block 数，缺失 block 用该鼠最高 performance 填充
sessionA2L = sortrows(sessionA2L, ["Mouse", "DateTime"]);
sessionL   = sortrows(sessionL,   ["Mouse", "DateTime"]);

nBlocks = numel(x);
[perfMatA2L, perfMatL] = iAlignPerformanceMatrices(sessionA2L, sessionL, nBlocks);

%% --- 5. 逐点 AnovaN ---
fprintf('\n--- Point-by-point AnovaN ---\n');
anovaTable = table;
anovaTable.Block    = (1:nBlocks).';
anovaTable.A2L_Mean = nan(nBlocks,1);
anovaTable.L_Mean   = nan(nBlocks,1);
anovaTable.A2L_N    = zeros(nBlocks,1);
anovaTable.L_N      = zeros(nBlocks,1);
anovaTable.P_Value  = nan(nBlocks,1);

for b = 1:nBlocks
	yA2L = perfMatA2L(:,b);
	yL   = perfMatL(:,b);
	vA = isfinite(yA2L); vB = isfinite(yL);
	nA = sum(vA); nB = sum(vB);
	anovaTable.A2L_Mean(b) = mean(yA2L(vA));
	anovaTable.L_Mean(b)   = mean(yL(vB));
	anovaTable.A2L_N(b)    = nA;
	anovaTable.L_N(b)      = nB;

	if nA < 2 || nB < 2
		fprintf('Block %d: A2L=%.3f (n=%d), L=%.3f (n=%d), p=NaN\n', ...
			b, anovaTable.A2L_Mean(b), nA, anovaTable.L_Mean(b), nB);
		continue;
	end

	y  = [yA2L(vA); yL(vB)];
	gCat = categorical([repmat("A2L", nA, 1); repmat("L", nB, 1)]);
	groupTbl = table(y, gCat, 'VariableNames', ["Performance", "Group"]);

	try
		pVal = UniExp.TabularAnovaN("Performance", groupTbl, Display=false);
		anovaTable.P_Value(b) = pVal;
		fprintf('Block %d: A2L=%.3f (n=%d), L=%.3f (n=%d), p=%.6f\n', ...
			b, anovaTable.A2L_Mean(b), nA, anovaTable.L_Mean(b), nB, pVal);
	catch ME
		fprintf('Block %d: AnovaN failed: %s\n', b, ME.message);
	end
end
disp(anovaTable);
writetable(anovaTable, fullfile(OUTPUT_DIR, anovaCsvName));
fprintf('Wrote: %s\n', fullfile(OUTPUT_DIR, anovaCsvName));

%% --- 6. Nature 风格 errorbar 图 ---
TEAL   = [0.259, 0.580, 0.620];  % A2L
VIOLET = [0.604, 0.302, 0.557];  % L

commonBlocks = 8;  % 两组在 block 1-8 均有数据
bIdx = 1:commonBlocks;
yA2L_plot = meanMat(bIdx,1);  errA2L = semMat(bIdx,1);
yL_plot   = meanMat(bIdx,2);  errL   = semMat(bIdx,2);

f = figure('Position', [100, 100, 550, 420], 'Color', 'w');

errorbar(yL_plot, errL, '-s', ...
	'MarkerSize', 11, ...
	'MarkerEdgeColor', VIOLET, ...
	'MarkerFaceColor', VIOLET + 0.5*(1-VIOLET), ...
	'Color', VIOLET, ...
	'LineWidth', 2.5, ...
	'CapSize', 10);
hold on;

errorbar(yA2L_plot, errA2L, '-s', ...
	'MarkerSize', 11, ...
	'MarkerEdgeColor', TEAL, ...
	'MarkerFaceColor', TEAL + 0.5*(1-TEAL), ...
	'Color', TEAL, ...
	'LineWidth', 2.5, ...
	'CapSize', 10);

% 显著性星号
for b = 1:numel(bIdx)
	pVal = anovaTable.P_Value(b);
	if isfinite(pVal) && pVal < 0.05
		yMax = max(yA2L_plot(b)+errA2L(b), yL_plot(b)+errL(b));
		if pVal < 0.001,      sigStr = '***';
		elseif pVal < 0.01,   sigStr = '**';
		else,                 sigStr = '*';
		end
		text(b, yMax+0.04, sigStr, ...
			'HorizontalAlignment', 'center', ...
			'VerticalAlignment', 'bottom', ...
			'FontSize', 14, 'FontName', 'Arial');
	end
end
hold off;

xlabel('Session (day)', 'FontSize', 16, 'FontName', 'Arial');
ylabel('Performance', 'FontSize', 16, 'FontName', 'Arial');
legend({'Light (LA→Light)', 'Continual Light (AL→Light)'}, ...
	'Location', 'southeast', 'Box', 'off', 'FontSize', 14);
box off;
set(gca, 'FontSize', 14, 'LineWidth', 1.2, 'TickDir', 'out');
xlim([0.5, commonBlocks+0.5]);
ylim([0, 1]);
title('Light learning curves: Continual vs LA pre-exposed', ...
	'FontSize', 12, 'FontWeight', 'normal', 'FontName', 'Arial');

%% --- 7. 导出 SVG ---
if ~isfolder(OUTPUT_DIR)
	mkdir(OUTPUT_DIR);
end
print(gcf, fullfile(OUTPUT_DIR, svgName), '-dsvg', '-vector');
fprintf('Wrote: %s\n', fullfile(OUTPUT_DIR, svgName));

%% --- 8. 写入工作区 ---
assignin('base', 'LightLearningCurve_A2LvsL_Summary', summaryTable);
assignin('base', 'LightLearningCurve_A2LvsL_AnovaN',  anovaTable);
assignin('base', 'LightLearningCurve_A2LvsL_A2L_Matrix', perfMatA2L);
assignin('base', 'LightLearningCurve_A2LvsL_L_Matrix',   perfMatL);

fprintf('\n=== Done ===\n');

%% ===================== 本地函数 =====================
function [perfMatA2L, perfMatL] = iAlignPerformanceMatrices(sA2L, sL, nBlocks)
[ugA, mA] = findgroups(sA2L.Mouse); numA = numel(mA);
[ugL, mL] = findgroups(sL.Mouse);    numL = numel(mL);
perfMatA2L = nan(numA, nBlocks);
perfMatL   = nan(numL, nBlocks);

for m = 1:numA
	rows = ugA == m;
	mp = double(sA2L.Performance(rows));
	[~,~,bidx] = unique(sA2L.DateTime(rows));
	maxP = max(mp);
	for b = 1:numel(bidx)
		if bidx(b) <= nBlocks, perfMatA2L(m, bidx(b)) = mp(b); end
	end
	perfMatA2L(m, isnan(perfMatA2L(m,:))) = maxP;
end

for m = 1:numL
	rows = ugL == m;
	mp = double(sL.Performance(rows));
	[~,~,bidx] = unique(sL.DateTime(rows));
	maxP = max(mp);
	for b = 1:numel(bidx)
		if bidx(b) <= nBlocks, perfMatL(m, bidx(b)) = mp(b); end
	end
	perfMatL(m, isnan(perfMatL(m,:))) = maxP;
end
end
