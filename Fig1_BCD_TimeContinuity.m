% Fig1 b/c/d｜按《英文图规范》重制
%
% b  三组光水学习曲线（Session 1–7，均值 ± SEM，有 legend → 图窗与字号 ×2）
% c  首个光水 block 命中率（bar + 单向 SEM + P 值线）
% d  达 50% 所需 block 数（同上）
%
% 规范要点：
%   - 基础高 4 cm、宽为 1.5 cm 整倍数；有 legend 的图 ×2
%   - 字号基础 6 pt（Scale 1），有 legend 的图 12 pt（Scale 2）
%   - 轴线 0.5 pt、线图/errorbar 1 pt（Scale 2 时统一 ×2）
%   - bar 与 errorbar 同色、无边框、无散点、errorbar 单向
%   - 不手动设 Y 轴刻度；P 值线用 MATLAB.Graphics.PLine（经 BarScatterCompare 间接调用）
%   - 图窗总宽 ≤ 182 mm
clear variables; close all;
cd('d:\git\Transfer-Learning');
if ~exist('UniExp.DataSet','class')
	matlab.project.loadProject('d:\git\Transfer-Learning\Transferlearning.prj');
end
warning('off','UniExp:Exception:Block_must_warn');

groupOrder = ["Naive","Transfer","7dayTransfer"];
groupLabels = ["Naive","12 h","7 d"];
colors = [TransferLearning.NaiveColor; TransferLearning.TransferColor; TransferLearning.ColorB];

Sess = TransferLearning.BehaviorSessions.LightWaterLearningSessions();
Summ = TransferLearning.Metrics.PerMouseSessionSummary(Sess);
sess7 = Sess(Sess.Session <= 7, :);
pGroup7 = TransferLearning.Style.TwoWayAnovaGroupPValue(sess7, 'Performance', 'Session', 'Group', 'Mouse');
pairIdx = [1 2; 2 3; 1 3];
pFirst = nan(3,1); pHalf = nan(3,1);
for i = 1:3
	pFirst(i) = iRS(Summ.FirstPerf(Summ.Group == groupOrder(pairIdx(i,1))), ...
		Summ.FirstPerf(Summ.Group == groupOrder(pairIdx(i,2))));
	pHalf(i) = iRS(Summ.BlocksToHalf(Summ.Group == groupOrder(pairIdx(i,1))), ...
		Summ.BlocksToHalf(Summ.Group == groupOrder(pairIdx(i,2))));
end

%% ================= B：学习曲线（有 legend → 8×8 cm，Scale 2）=================
fB = figure('Color','w','Name','Fig1b learning curve');
fB.Units = 'centimeters'; fB.Position(3:4) = [9 8];
axB = axes(fB,'Position',[0.145 0.125 0.815 0.795]); hold(axB,'on');
xMax = 7;
proxy = gobjects(3,1);
for k = 1:3
	S = Sess(Sess.Group == groupOrder(k) & Sess.Session <= xMax, :);
	xu = (1:xMax)';
	mu = nan(xMax,1); se = nan(xMax,1);
	for s = 1:xMax
		v = S.Performance(S.Session == s);
		v = v(isfinite(v));
		if isempty(v), continue; end
		mu(s) = mean(v); se(s) = std(v)/sqrt(numel(v));
	end
	ok = isfinite(mu);
	% 与原 Fig1 一致的样式：连线 + 带端点帽的 errorbar + 实心圆点（按 Scale 2 放大）
	plot(axB, xu(ok), mu(ok), '-', 'Color', colors(k,:), 'LineWidth', 2, ...
		'HandleVisibility','off');
	errorbar(axB, xu(ok), mu(ok), se(ok), 'o', 'Color', colors(k,:), ...
		'LineWidth', 1.6, 'MarkerSize', 6, 'MarkerFaceColor', colors(k,:), ...
		'MarkerEdgeColor', colors(k,:), 'CapSize', 4, 'HandleVisibility','off');
	proxy(k) = plot(axB, nan, nan, '-o', 'Color', colors(k,:), ...
		'MarkerFaceColor', colors(k,:), 'MarkerEdgeColor', colors(k,:), ...
		'MarkerSize', 5, 'LineWidth', 2);
end
xlim(axB,[0.5 xMax+0.5]);
axB.XTick = 1:xMax;
axB.XTickLabel = arrayfun(@(v) sprintf('%d',v), 1:xMax, 'UniformOutput', false);
xlabel(axB,'Block');
ylabel(axB,'Hit rate');
title(axB,'Light-water learning curve','FontWeight','normal');
lg = legend(axB, proxy, cellstr(groupLabels), 'Location','southeast');
lg.Box = 'off'; lg.FontSize = 12;
box(axB,'off');

%% ================= C：首块（单独一张 4.5×4 cm，Scale 1）=================
fC = figure('Color','w','Name','Fig1c first light-water block');
fC.Units = 'centimeters'; fC.Position(3:4) = [4.5 4];
axC = axes(fC,'Position',[0.20 0.19 0.73 0.68]);
iBar(axC, {Summ.FirstPerf(Summ.Group == groupOrder(1)); Summ.FirstPerf(Summ.Group == groupOrder(2)); ...
	Summ.FirstPerf(Summ.Group == groupOrder(3))}, [1 2; 2 3], pFirst(1:2), colors, groupLabels, ...
	'First block', 'Hit rate');

%% ================= D：达 50%（单独一张 4.5×4 cm，Scale 1）=================
fD = figure('Color','w','Name','Fig1d blocks to 50%');
fD.Units = 'centimeters'; fD.Position(3:4) = [4.5 4];
axD = axes(fD,'Position',[0.24 0.19 0.69 0.68]);
iBar(axD, {Summ.BlocksToHalf(Summ.Group == groupOrder(1)); Summ.BlocksToHalf(Summ.Group == groupOrder(2)); ...
	Summ.BlocksToHalf(Summ.Group == groupOrder(3))}, [1 2; 2 3], pHalf(1:2), colors, groupLabels, ...
	'Blocks to 50%', 'Blocks');

%% ================= C+D 合并版（6 × 4 cm，Scale 1）=================
fCD = figure('Color','w','Name','Fig1cd combined');
fCD.Units = 'centimeters'; fCD.Position(3:4) = [6 4];
axCj = axes(fCD,'Position',[0.115 0.195 0.355 0.665]);
iBar(axCj, {Summ.FirstPerf(Summ.Group == groupOrder(1)); Summ.FirstPerf(Summ.Group == groupOrder(2)); ...
	Summ.FirstPerf(Summ.Group == groupOrder(3))}, [1 2; 2 3], pFirst(1:2), colors, groupLabels, ...
	'First block', 'Hit rate');
axDj = axes(fCD,'Position',[0.605 0.195 0.355 0.665]);
iBar(axDj, {Summ.BlocksToHalf(Summ.Group == groupOrder(1)); Summ.BlocksToHalf(Summ.Group == groupOrder(2)); ...
	Summ.BlocksToHalf(Summ.Group == groupOrder(3))}, [1 2; 2 3], pHalf(1:2), colors, groupLabels, ...
	'Blocks to 50%', 'Blocks');

%% ---------------- 导出 ----------------
pB  = TransferLearning.ExportStandardFigure(fB, 2, 'Fig1b_LearningCurve.svg');
pC  = TransferLearning.ExportStandardFigure(fC, 1, 'Fig1c_FirstBlock.svg');
pD  = TransferLearning.ExportStandardFigure(fD, 1, 'Fig1d_BlocksTo50.svg');
fprintf('Wrote: %s\n', pB);
fprintf('Wrote: %s\n', pC);
fprintf('Wrote: %s\n', pD);

pCD = TransferLearning.ExportStandardFigure(fCD, 1, 'Fig1cd_FirstBlock_Half.svg');
fprintf('Wrote: %s\n', pCD);

fprintf('\n=== Fig1 b/c/d ===\n');
for k = 1:3
	S = Summ(Summ.Group == groupOrder(k), :);
	fprintf('%-13s n=%2d  first %.3f+-%.3f  half %.2f+-%.2f\n', groupOrder(k), height(S), ...
		mean(S.FirstPerf), iSEM(S.FirstPerf), mean(S.BlocksToHalf), iSEM(S.BlocksToHalf));
end
fprintf('LME group p = %.4g | first N-T %.4g T-7d %.4g | half N-T %.4g T-7d %.4g\n', ...
	pGroup7, pFirst(1), pFirst(2), pHalf(1), pHalf(2));

%% ------------------------------------------------------------------
function iBar(ax, data, pairs, pVals, cols, labels, ttl, ylab)
hold(ax,'on');
y = cellfun(@(v) mean(v(isfinite(v))), data);
e = cellfun(@(v) iSEM(v), data);
h = bar(ax, 1:3, y, 0.38, 'FaceColor','flat');
h.CData = cols; h.EdgeColor = 'none'; h.LineWidth = 0.5;
for k = 1:3
	% 单向 errorbar（只向上）
	errorbar(ax, k, y(k), 0, e(k), 'Color', cols(k,:), 'LineWidth', 0.5, 'CapSize', 2);
end
ax.XTick = 1:3; ax.XTickLabel = cellstr(labels);
ax.FontSize = 6; ax.LineWidth = 0.5;
xlim(ax,[0.4 3.6]);
ylabel(ax, ylab);
title(ax, ttl, 'FontWeight','normal');

% P 值线：两条比较线错开高度，上方留白避免压标题
rng = max(y(:) + e(:));
ax.YLim = [0, rng * 1.70];
for k = 1:size(pairs,1)
	xa = pairs(k,1); xb = pairs(k,2);
	yy = rng * (1.12 + 0.20 * k);
	plot(ax, [xa xb], [yy yy], '-', 'Color', [0.2 0.2 0.2], 'LineWidth', 0.5);
	text(ax, mean([xa xb]), yy + rng*0.02, ...
		TransferLearning.Style.iFormatPText(pVals(k)), 'FontSize', 6, ...
		'HorizontalAlignment','center', 'VerticalAlignment','bottom');
end
box(ax,'off');
end

function p = iRS(a, b)
[p, ~] = TransferLearning.BehaviorSessions.iRanksumSafe(a, b);
end

function s = iSEM(x)
x = double(x(:)); x = x(isfinite(x));
if isempty(x), s = NaN; else, s = std(x)/sqrt(numel(x)); end
end
