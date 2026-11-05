% Fig1｜时间连续性决定跨模态迁移的行为优势（仅生成 MATLAB 图窗）
%
% 目标任务 X = LightWater（声→光方向）
%   naive   直接学 LW              LightAudioBaseline(Naive→Learned) + LAInterspersed(Naive→Learned)
%   transfer 先学 AW 再学 LW        · 12 h：AudioLightBaseline(Transfer→Final)
%                                  · 7 d ：Vacation7(Transfer→Final)
%                                  · 穿插：ALInterspersed 数据缺失，图上留位标注
%
% A 三种时间关系示意
% B Light-water 学习曲线（逐 block 实测均值 + SEM 误差线，不画拟合、不加阴影）
% C 首个 light-water block 命中率（逐鼠）
% D 达 50% 所需 block 数（逐鼠）
% E 迁移优势随任务间时间 Δt 的变化（上：首块命中率；下：达 50% block 数；共享 x 轴）

if ~exist('UniExp.DataSet', 'class')
	thisDir = fileparts(mfilename('fullpath'));
	prjFile = fullfile(thisDir, 'Transferlearning.prj');
	if ~exist(prjFile, 'file')
		prjFile = fullfile(thisDir, '..', 'Transferlearning.prj');
	end
	if exist(prjFile, 'file')
		matlab.project.loadProject(prjFile);
	end
end
warning('off', 'UniExp:Exception:Block_must_warn');

groupOrder = ["Naive", "Transfer", "7dayTransfer"];
groupLabels = ["Naive (LW direct)", "Transfer (AW→12 h→LW)", "Transfer (AW→7 d→LW)"];
colors = [TransferLearning.NaiveColor; TransferLearning.TransferColor; TransferLearning.ColorB];

Sess = TransferLearning.BehaviorSessions.LightWaterLearningSessions();
Summ = TransferLearning.Metrics.PerMouseSessionSummary(Sess);

% ---------- B: 组水平学习曲线 ----------
curveIn = Sess(:, {'Mouse','DateTime','Performance','Group'});
[~, summaryL] = evalc('UniExp.LearningSummarize(curveIn)');
rowNames = string(summaryL.Properties.RowNames);
meanMat = cell(1, numel(groupOrder));
semMat = cell(1, numel(groupOrder));
for k = 1:numel(groupOrder)
	ix = find(rowNames == groupOrder(k), 1, 'first');
	mv = double(summaryL.MeanCurve{ix}(:));
	sv = double(summaryL.SemCurve{ix}(:));
	meanMat{k} = mv(1:find(isfinite(mv), 1, 'last')).';
	semMat{k} = sv(1:find(isfinite(sv), 1, 'last')).';
end
xMax = min(10, max(cellfun(@numel, meanMat)));
for k = 1:numel(groupOrder)
	meanMat{k} = meanMat{k}(1:min(xMax, numel(meanMat{k})));
	semMat{k} = semMat{k}(1:min(xMax, numel(semMat{k})));
end

% ---------- 统计 ----------
sess7 = Sess(Sess.Session <= 7, :);
pGroup7 = TransferLearning.Style.TwoWayAnovaGroupPValue(sess7, 'Performance', 'Session', 'Group', 'Mouse');
pairIdx = [1 2; 2 3; 1 3];
pFirst = nan(3, 1);
pHalf = nan(3, 1);
for i = 1:3
	pFirst(i) = iRanksum(Summ.FirstPerf(Summ.Group == groupOrder(pairIdx(i,1))), ...
		Summ.FirstPerf(Summ.Group == groupOrder(pairIdx(i,2))));
	pHalf(i) = iRanksum(Summ.BlocksToHalf(Summ.Group == groupOrder(pairIdx(i,1))), ...
		Summ.BlocksToHalf(Summ.Group == groupOrder(pairIdx(i,2))));
end
yFirst = [mean(Summ.FirstPerf(Summ.Group == "Naive")); ...
	mean(Summ.FirstPerf(Summ.Group == "Transfer")); ...
	mean(Summ.FirstPerf(Summ.Group == "7dayTransfer"))];
eFirst = [iSem(Summ.FirstPerf(Summ.Group == "Naive")); ...
	iSem(Summ.FirstPerf(Summ.Group == "Transfer")); ...
	iSem(Summ.FirstPerf(Summ.Group == "7dayTransfer"))];
yHalf = [mean(Summ.BlocksToHalf(Summ.Group == "Naive")); ...
	mean(Summ.BlocksToHalf(Summ.Group == "Transfer")); ...
	mean(Summ.BlocksToHalf(Summ.Group == "7dayTransfer"))];
eHalf = [iSem(Summ.BlocksToHalf(Summ.Group == "Naive")); ...
	iSem(Summ.BlocksToHalf(Summ.Group == "Transfer")); ...
	iSem(Summ.BlocksToHalf(Summ.Group == "7dayTransfer"))];

%% ---------- 出图 ----------
f = figure('Color', 'w', 'Name', 'Fig1 time continuity behavior');
f.Units = 'centimeters';
f.Position(3:4) = [22, 11];

pos = struct( ...
	'A', [0.030 0.545 0.215 0.360], ...
	'B', [0.300 0.520 0.330 0.410], ...
	'C', [0.055 0.060 0.155 0.270], ...
	'D', [0.275 0.060 0.155 0.270], ...
	'E1', [0.715 0.560 0.250 0.330], ...
	'E2', [0.715 0.080 0.250 0.300]);

% A 示意
axA = axes(f, 'Position', pos.A);
iDrawDesignSchematic(axA, colors);

% B 学习曲线：只画实测均值（点 + SEM 误差线），不画 Sigmoid 拟合、不加阴影
axB = axes(f, 'Position', pos.B);
hold(axB, 'on');
for k = 1:numel(groupOrder)
	xk = (1:numel(meanMat{k})).';
	yk = meanMat{k}(:);
	ek = semMat{k}(:);
	plot(axB, xk, yk, '-', 'Color', colors(k, :), 'LineWidth', 1, 'HandleVisibility', 'off');
	errorbar(axB, xk, yk, ek, 'o', 'Color', colors(k, :), 'MarkerFaceColor', colors(k, :), ...
		'MarkerSize', 3, 'LineWidth', 0.8, 'CapSize', 2, 'HandleVisibility', 'off');
end
proxy = gobjects(numel(groupOrder), 1);
for k = 1:numel(groupOrder)
	proxy(k) = plot(axB, nan, nan, '-o', 'Color', colors(k, :), 'MarkerFaceColor', colors(k, :), ...
		'MarkerSize', 3, 'LineWidth', 1);
end
xlabel(axB, 'Block');
ylabel(axB, 'Hit rate');
xlim(axB, [0.7, xMax + 0.3]);
ylim(axB, [0, 1]);
yticks(axB, 0:0.2:1);
title(axB, 'Light-water learning curve', 'FontWeight', 'normal');
lg = legend(axB, proxy, cellstr(groupLabels), 'Location', 'southeast');
lg.Box = 'off';
box(axB, 'off');

% C 首块
axC = axes(f, 'Position', pos.C);
iBarPanel(axC, {Summ.FirstPerf(Summ.Group == groupOrder(1)); ...
	Summ.FirstPerf(Summ.Group == groupOrder(2)); ...
	Summ.FirstPerf(Summ.Group == groupOrder(3))}, ...
	[1 2; 2 3], [pFirst(1); pFirst(2)], colors, ["Naive", "12 h", "7 d"], ...
	'First light-water block', 0.05);

% D 达 50%
axD = axes(f, 'Position', pos.D);
iBarPanel(axD, {Summ.BlocksToHalf(Summ.Group == groupOrder(1)); ...
	Summ.BlocksToHalf(Summ.Group == groupOrder(2)); ...
	Summ.BlocksToHalf(Summ.Group == groupOrder(3))}, ...
	[1 2; 2 3], [pHalf(1); pHalf(2)], colors, ["Naive", "12 h", "7 d"], ...
	'Blocks to 50% (LW)', 0.05);

% E 上：首块命中率 vs Δt
axE1 = axes(f, 'Position', pos.E1);
iDeltaPanel(axE1, yFirst, eFirst, colors, 'First LW block hit rate');
title(axE1, 'Transfer advantage vs \Deltat', 'FontWeight', 'normal');

% E 下：达 50% block vs Δt
axE2 = axes(f, 'Position', pos.E2);
iDeltaPanel(axE2, yHalf, eHalf, colors, 'Blocks to 50% (LW)');
xlabel(axE2, 'Task interval \Deltat');

iPanelLetters(f, {axA, axB, axC, axD, axE1});
annotation(f, 'textbox', [0.02 0.968 0.9 0.03], 'String', ...
	'Fig1  Temporal continuity sets the cross-modal transfer advantage', ...
	'EdgeColor', 'none', 'FontSize', 9, 'FontWeight', 'bold');

outDir = fileparts(TransferLearning.StandardFigureSvgPath('Fig1_TimeContinuityBehavior.svg'));
figPath = fullfile(outDir, 'Fig1_TimeContinuityBehavior.fig');
savefig(f, figPath);
fprintf('Saved: %s\n', figPath);

fprintf('\n=== Fig1 ===\n');
for k = 1:3
	fprintf('%-14s n=%d  first=%.3f+-%.3f  blocks-to-50%%=%.2f+-%.2f\n', groupOrder(k), ...
		sum(Summ.Group == groupOrder(k)), mean(Summ.FirstPerf(Summ.Group == groupOrder(k))), ...
		iSem(Summ.FirstPerf(Summ.Group == groupOrder(k))), ...
		mean(Summ.BlocksToHalf(Summ.Group == groupOrder(k))), iSem(Summ.BlocksToHalf(Summ.Group == groupOrder(k))));
end
fprintf('LME group effect (blocks 1-7) p = %.4g\n', pGroup7);
for i = 1:3
	fprintf('%s vs %s: first-block p=%.4g, blocks-to-50%% p=%.4g\n', ...
		groupOrder(pairIdx(i,1)), groupOrder(pairIdx(i,2)), pFirst(i), pHalf(i));
end
fprintf('Interleaved arm (AW-IL-LW): dataset unavailable, not drawn.\n');

assignin('base', 'Fig1_Data', struct('Sessions', Sess, 'PerMouse', Summ, ...
	'PGroup7', pGroup7, 'PFirst', pFirst, 'PHalf', pHalf));

%% ------------------------------------------------------------------
function iDeltaPanel(ax, y, e, colors, ylab)
hold(ax, 'on');
xD = [1 2 3];
for k = 1:3
	errorbar(ax, xD(k), y(k), e(k), 'o', 'Color', colors(k, :), 'LineWidth', 1.4, ...
		'MarkerFaceColor', 'w', 'MarkerSize', 5, 'CapSize', 3);
end
plot(ax, xD, y, '-', 'Color', [0.65 0.65 0.65], 'LineWidth', 1, 'HandleVisibility', 'off');
% 穿插臂缺数据：在 Δt≈0 处留空位标注
text(ax, 0.75, max(y) * 0.55, sprintf('interleaved\n(n/a)'), 'FontSize', 6, ...
	'Color', [0.6 0.6 0.6], 'HorizontalAlignment', 'center', 'Interpreter', 'none');
ylabel(ax, ylab);
xlim(ax, [0.6, 3.4]);
ax.XTick = xD;
ax.XTickLabel = {'no prior', '12 h', '7 d'};
box(ax, 'off');
end

function iDrawDesignSchematic(ax, colors)
hold(ax, 'on');
axis(ax, 'off');
xlim(ax, [0, 10]);
ylim(ax, [-0.2, 3.9]);
rows = [2.55, 1.45, 0.35];
rowLabels = ["Naive", "Transfer 12 h", "Transfer 7 d"];
for r = 1:3
	text(ax, 0.05, rows(r) + 0.22, rowLabels(r), 'FontSize', 6, 'FontWeight', 'bold', ...
		'Color', colors(r, :), 'VerticalAlignment', 'middle');
end
iBox(ax, 2.6, 6.4, rows(1), colors(1,:), 'light \rightarrow water');
iBox(ax, 2.6, 4.1, rows(2), colors(2,:), 'audio');
iBox(ax, 4.7, 6.4, rows(2), colors(2,:), 'light');
text(ax, 4.4, rows(2) + 0.62, '12 h', 'FontSize', 6, 'HorizontalAlignment', 'center');
iBox(ax, 2.6, 4.1, rows(3), colors(3,:), 'audio');
iBox(ax, 7.3, 9.6, rows(3), colors(3,:), 'light');
plot(ax, [4.1, 7.3], [rows(3) + 0.22, rows(3) + 0.22], ':', 'Color', [0.45 0.45 0.45], 'LineWidth', 1);
text(ax, 5.7, rows(3) + 0.34, '7 d home cage', 'FontSize', 6, ...
	'HorizontalAlignment', 'center', 'Color', [0.35 0.35 0.35]);
text(ax, 5.0, -0.12, 'task-internal time \rightarrow', 'FontSize', 6, 'HorizontalAlignment', 'center');
end

function iBox(ax, x0, x1, y0, col, label)
patch(ax, [x0 x1 x1 x0], y0 + [0 0 0.45 0.45], col, 'FaceAlpha', 0.22, 'EdgeColor', col, 'LineWidth', 0.8);
text(ax, (x0 + x1) / 2, y0 + 0.225, label, 'FontSize', 6, ...
	'HorizontalAlignment', 'center', 'VerticalAlignment', 'middle');
end

function iBarPanel(ax, data, pairs, pVals, cols, labels, ttl, thr)
data = reshape(data, 1, []);
axes(ax);
CompareGroup = table(pairs, 'VariableNames', {'GroupPair'});
[~, Opt, Bars, EB] = UniExp.BarScatterCompare(data, UniExp.Flags.empty, CompareGroup, ...
	UniExp.Flags.IndividualErrorbars, 'AsteriskThreshold', thr);
if isscalar(Bars)
	Bars.FaceColor = 'flat';
	Bars.CData = cols;
else
	for k = 1:numel(Bars)
		Bars(k).FaceColor = cols(k, :);
	end
end
for k = 1:numel(Bars)
	Bars(k).BarWidth = 0.5;
	Bars(k).EdgeColor = 'none';
	Bars(k).FaceAlpha = 1;
end
if istable(EB) && ~isempty(EB) && ismember('Object', EB.Properties.VariableNames)
	for k = 1:height(EB)
		eb = EB.Object(k);
		if isgraphics(eb) && k <= size(cols, 1)
			eb.Color = cols(k, :);
		end
	end
end
yTop = 0;
if isfield(Opt, 'MultiCompare') && istable(Opt.MultiCompare) && ismember('PText', Opt.MultiCompare.Properties.VariableNames)
	pairStr = string(num2str(pairs));
	for k = 1:height(Opt.MultiCompare)
		gp = string(num2str(Opt.MultiCompare.GroupPair(k, :)));
		pick = find(ismember(pairStr, gp), 1, 'first');
		pt = Opt.MultiCompare.PText(k);
		pl = Opt.MultiCompare.PLine(k);
		if isgraphics(pt) && ~isempty(pick)
			pt.String = TransferLearning.Style.iFormatPText(pVals(pick));
		end
		if isgraphics(pl)
			yTop = max(yTop, max(pl.YData));
		end
	end
end
ax.XTick = 1:numel(labels);
ax.XTickLabel = cellstr(labels);
title(ax, ttl, 'FontWeight', 'normal');
if yTop > 0
	ylim(ax, [0, yTop * 1.12]);
end
box(ax, 'off');
end

function iPanelLetters(f, axList)
letters = ["A", "B", "C", "D", "E", "F"];
for k = 1:numel(axList)
	p = axList{k}.Position;
	annotation(f, 'textbox', [p(1) - 0.008, p(2) + p(4) + 0.005, 0.04, 0.03], ...
		'String', letters(k), 'FontSize', 10, 'FontWeight', 'bold', 'EdgeColor', 'none', ...
		'VerticalAlignment', 'bottom');
end
end

function p = iRanksum(x, y)
[p, ~] = TransferLearning.BehaviorSessions.iRanksumSafe(x, y);
end

function s = iSem(x)
x = double(x(:));
x = x(isfinite(x));
if isempty(x)
	s = NaN;
else
	s = std(x) / sqrt(numel(x));
end
end

function fitOut = iFitSigmoid(T)
xObs = double(T.Session(:));
yObs = double(T.Performance(:));
use = isfinite(xObs) & isfinite(yObs);
xObs = xObs(use);
yObs = yObs(use);
p0 = [log(0.8); max(median(xObs), 1)];
p = fminsearch(@(q) sum((yObs - iSigmoid(q, xObs)).^2, 'omitnan'), p0, ...
	optimset('Display', 'off', 'MaxFunEvals', 10000, 'MaxIter', 10000));
fitOut = struct('ParamRaw', p);
end

function y = iSigmoid(p, x)
y = 1 ./ (1 + exp(-exp(p(1)) .* (x - p(2))));
end
