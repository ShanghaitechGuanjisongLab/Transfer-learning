% Fig1 三组光水学习曲线（与 Fig1_MetricBars_* 完全同一数据源）
%
% 队列：TransferLearning.BehaviorSessions.LightWaterLearningSessions（undelayed 成像队列）
%       Naive / Transfer(12 h) / 7dayTransfer(7 d)，与 bar 图逐鼠指标同源。
% 数据：TransferLearning.Metrics.LightWaterMetricData 的缓存 Sess 表
%       （Session = 每鼠按时间排序的会话序号，即 block）。
%
% 样式：每 block 跨鼠 mean ± SEM，用**阴影带**（vector patch）表示；
%       实心圆点 + 连线；每组再叠一条**虚线 sigmoid 拟合线**（对逐鼠逐会话命中率做最小二乘拟合）。
% 配色：与 bar 图一致 TransferLearning.ColorNaive / Color12h / Color7d。
% 尺寸：排版 45×40 mm、6 pt → 导出 90×80 mm、12 pt。

groupOrder = ["Naive", "Transfer", "7dayTransfer"];
groupLabel = ["Naive", "12 h", "7 d"];
groupColor = [TransferLearning.ColorNaive; TransferLearning.Color12h; TransferLearning.Color7d] / 255;
%描边/误差棒颜色：与填充同色为纯实心点；想让点更清楚可改成 groupColor*0.8（会有一圈深描边）
nG = numel(groupOrder);
edgeColor = zeros(nG, 3);
for g = 1:nG
	edgeColor(g, :) = groupColor(g, :);
end

%% 数据（缓存；结构改动后置 ForceRebuild=true）
D = TransferLearning.Metrics.LightWaterMetricData(ForceRebuild = false);
Sess = D.Sess;

nG = numel(groupOrder);
X = cell(nG, 1); MU = cell(nG, 1); SEM = cell(nG, 1); FIT = cell(nG, 1);
maxBlock = 7;   %只显示前 maxBlock 个 block（三组都适用；设 Inf 则全画）
fprintf('\n=== 三组光水学习曲线（mean±SEM，跳鼠，block 1–%d）===\n', maxBlock);
for g = 1:nG
	S = Sess(string(Sess.Group) == groupOrder(g), :);
	b = double(S.Session);
	p = double(S.Performance);
	ok = isfinite(b) & isfinite(p) & b >= 1 & b <= maxBlock;
	b = b(ok);
	p = p(ok);
	ub = unique(b);
	MU{g} = zeros(numel(ub), 1);
	SEM{g} = zeros(numel(ub), 1);
	for k = 1:numel(ub)
		v = p(b == ub(k));
		MU{g}(k) = mean(v);
		SEM{g}(k) = std(v) / sqrt(numel(v));
		fprintf('      block %2d: n=%2d  mean=%.3f  sem=%.3f\n', ub(k), numel(v), MU{g}(k), SEM{g}(k));
	end
	X{g} = ub;
	%sigmoid 拟合用同一批（block 1–maxBlock）逐鼠逐会话命中率
	FIT{g} = iFitSigmoidCurve(S(ok, :), groupOrder(g));
	fprintf('  %-13s 鼠 %2d，block 1–%d，拟合斜率 k=%.3f\n', groupOrder(g), ...
		numel(unique(string(S.Mouse))), max(ub), FIT{g}.Slope);
end

%% 统计：两两 two-way ANOVA（Group × Block，block 1–maxBlock）
%因变量为逐鼠逐 block 的命中率；组效应 p 取自 anovan（mouse 未作为随机效应建模，
%与 Fig61B 既有的「two-way ANOVA Group P (blocks 1-7)」口径一致）。
Tb = table();
for g = 1:nG
	S = Sess(string(Sess.Group) == groupOrder(g), :);
	b = double(S.Session);
	p = double(S.Performance);
	m = string(S.Mouse);
	ok = isfinite(b) & isfinite(p) & b >= 1 & b <= maxBlock;
	Tb = [Tb; table(repmat(groupOrder(g), nnz(ok), 1), m(ok), b(ok), p(ok), ...
		'VariableNames', {'Group', 'Mouse', 'Block', 'Y'})]; %#ok<AGROW>
end
pairIdx = [1 2; 1 3; 2 3];
pGroup = nan(3, 1);
fprintf('\n=== 两两 two-way ANOVA（Group × Block）===\n');
for k = 1:3
	Q = Tb(ismember(Tb.Group, groupOrder(pairIdx(k, :))), :);
	panova = anovan(Q.Y, {categorical(Q.Group), Q.Block}, 'Model', 'interaction', ...
		'display', 'off', 'varnames', {'Group', 'Block'});
	pGroup(k) = panova(1);
	fprintf('  %-13s vs %-13s Group p=%.4g  交互 p=%.4g  (n=%d)\n', ...
		groupOrder(pairIdx(k, 1)), groupOrder(pairIdx(k, 2)), ...
		panova(1), panova(3), height(Q));
end

%% 画图
f = figure('Color', 'w', 'Name', 'Fig1 three cohorts learning curve');
f.Units = 'centimeters';
f.Position(3:4) = [9,8];
hold on;

%点大小：样式会把所有 LineWidth 设为 1 pt（导出 12 pt 体系下 2 pt），
%而 marker 的描边宽度也走 LineWidth，所以点要开得比线宽大一截才不会被描边吃掉
markerSize = 8;   %pt（导出尺寸）→ 排版后约 4 pt、直径 ≈1.4 mm
%---- 先画 mean±SEM 阴影带（三组一次画完，压在最底层）----
[yC, sC, xC] = iBuildBandCells(MU, SEM);
hBand = MATLAB.Graphics.MultiShadowedLines(yC, sC, X = xC, EdgeColors = groupColor);
for p = hBand(:)'
	if isprop(p, 'LineWidth')
		p.LineWidth = 0.5;
	end
end
hPt = gobjects(nG, 1);
xFit = linspace(1, maxBlock, 200).';
for g = 1:nG
	%绘制顺序：阴影带在最下、虚线拟合、均值连线、实心点在最上
	plot( xFit, iSigmoidFromParams(FIT{g}.ParamRaw, xFit), '--', ...
		'Color', groupColor(g, :) * 0.65, 'LineWidth', 1, 'Tag', 'fitLine');
	plot(X{g}, MU{g}, '-', 'Color', groupColor(g, :), 'LineWidth', 1, 'Tag', 'connLine');
	hPt(g) = plot(X{g}, MU{g}, 'o', 'LineStyle', 'none', 'Tag', 'dataPt', ...
		'MarkerSize', markerSize, 'MarkerFaceColor', groupColor(g, :), ...
		'MarkerEdgeColor', 'none');
end
ax=gca;
xlabel('Block');
ylabel('Hit rate');
box('off');

lg = legend(hPt, cellstr(groupLabel), 'Location', 'southeast', 'NumColumns', 1);
lg.Box = 'off';
title('💡💧');
%先上标准样式（所有线宽会被统一成 1 pt），再把虚线拟合线调细
TransferLearning.ApplyStandardExportStyle(f, 2);
set(findall(f, 'Type', 'line', '-regexp', 'Tag', '^fitLine'), 'LineWidth', 0.6 * figScale);
svgPath = TransferLearning.StandardFigureSvgPath('English_Fig1B_ThreeCohorts_LearningCurve.svg');
print(f, svgPath, '-dsvg');
fprintf('\nWrote: %s\n', svgPath);

%% ---------------------------------------------------------------
function [yCells, sCells, xCells] = iBuildBandCells(meanCell, semCell)
%把 mean/SEM 的 cell 整理成 MultiShadowedLines 需要的 cell（在最后一个有限点处截断）
nLines = numel(meanCell);
yCells = cell(1, nLines);
sCells = cell(1, nLines);
xCells = cell(1, nLines);
for j = 1:nLines
	y = meanCell{j}(:);
	s = semCell{j}(:);
	last = find(isfinite(y) & isfinite(s), 1, 'last');
	if isempty(last)
		yCells{j} = nan(0, 1);
		sCells{j} = nan(0, 1);
		xCells{j} = nan(0, 1);
	else
		yCells{j} = y(1:last);
		sCells{j} = s(1:last);
		xCells{j} = (1:last)';
	end
end
end

function fitOut = iFitSigmoidCurve(T, groupName)
%对逐鼠逐会话命中率做最小二乘 sigmoid 拟合： y = 1/(1+exp(-k*(x-x0)))
T = sortrows(T, {'Mouse', 'DateTime'});
xObs = double(T.Session(:));
yObs = double(T.Performance(:));
use = isfinite(xObs) & isfinite(yObs);
xObs = xObs(use);
yObs = yObs(use);
if isempty(xObs)
	error('Fig1B:NoDataForGroup', 'No valid session data for group %s.', char(groupName));
end
p0 = [log(1); median(xObs, 'omitnan')];
obj = @(p) sum((yObs - iSigmoidFromParams(p, xObs)).^2, 'omitnan');
opt = optimset('Display', 'off', 'MaxFunEvals', 10000, 'MaxIter', 10000);
p = fminsearch(obj, p0, opt);
fitOut = struct;
fitOut.Group = string(groupName);
fitOut.ParamRaw = p;
fitOut.Slope = exp(p(1));
fitOut.Midpoint = p(2);
end

function y = iSigmoidFromParams(p, x)
slope = exp(p(1));
midpoint = p(2);
z = -slope .* (double(x) - midpoint);
z = max(min(z, 60), -60);
y = 1 ./ (1 + exp(z));
end