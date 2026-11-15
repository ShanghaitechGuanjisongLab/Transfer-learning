% 检验：延迟 12 h 组斜率偏平，是"天花板/提升空间小"造成的吗？
%
% 三项检查：
%  1 限制到早期 block（1-3、1-4）再做 group*block GLMM —— 饱和尚未发生时组间差异是否还在
%  2 逐鼠拟合"下限 0、上限自由"的 3 参数 sigmoid（trial 级 MLE），比较两组的 k 与 U
%  3 观测到的末块命中率（天花板水平）
clear variables; close all;
cd('d:\git\Transfer-Learning');
if ~exist('UniExp.DataSet', 'class')
	matlab.project.loadProject('d:\git\Transfer-Learning\Transferlearning.prj');
end
warning('off', 'UniExp:Exception:Block_must_warn');
stim = ["LightLearnWater", "LightLearnWaterAlways"];

T = iTrials(UniExp.DataSet(TransferLearning.DelayComparison.BehaviorDataPath("L2A_L")), ...
	TransferLearning.DelayComparison.CohortBlocks("DelayedBehaviorNaive"), stim, "Naive");
T = [T; iTrials(UniExp.DataSet(TransferLearning.DelayComparison.BehaviorDataPath("A2L_L")), ...
	TransferLearning.DelayComparison.CohortBlocks("DelayedBehaviorTransfer"), stim, "12h")];
T.group = categorical(T.group, ["Naive", "12h"]);
T.mouse = categorical(T.mouse);
T.blockC = T.block - 1;

fprintf('\n=== 1) 早期窗口的 group*block GLMM ===\n');
for w = [3 4 6]
	S = T(T.block <= w, :);
	mdl = fitglme(S, 'y ~ blockC*group + (1|mouse)', 'Distribution', 'binomial', ...
		'Link', 'logit', 'FitMethod', 'Laplace');
	a = anova(mdl);
	iRow = strcmp(a.Term, 'group:blockC');
	fprintf('  block 1-%d：n=%d trial   group:blockC  F=%.2f  p=%.4g\n', w, height(S), ...
		a.FStat(iRow), a.pValue(iRow));
end

fprintf('\n=== 2) 逐鼠 3 参数（下限 0、上限自由）trial 级 MLE ===\n');
mice = categories(T.mouse);
grp = strings(numel(mice), 1);
K = nan(numel(mice), 1); U = nan(numel(mice), 1); NB = zeros(numel(mice), 1);
for i = 1:numel(mice)
	m = mice{i};
	rows = T.mouse == m;
	x = T.block(rows); y = T.y(rows);
	NB(i) = max(x);
	grp(i) = string(T.group(find(rows, 1)));
	[K(i), U(i)] = iFitFreeUpper(x, y);
end
fprintf('  %-10s %-6s %5s %8s %8s\n', 'Mouse', 'group', 'nBlk', 'k', 'U');
for i = 1:numel(mice)
	fprintf('  %-10s %-6s %5d %8.2f %8.2f\n', mice{i}, grp(i), NB(i), K(i), U(i));
end
for g = ["Naive", "12h"]
	fprintf('  %-6s n=%2d  median k=%.2f  median U=%.2f\n', g, sum(grp == g), ...
		median(K(grp == g), 'omitnan'), median(U(grp == g), 'omitnan'));
end
pK = ranksum(K(grp == "Naive"), K(grp == "12h"));
pU = ranksum(U(grp == "Naive"), U(grp == "12h"));
fprintf('  k 组间 p=%.4g    U 组间 p=%.4g\n', pK, pU);

fprintf('\n=== 3) 观测水平（整体命中率 / 末块命中率）===\n');
for g = ["Naive", "12h"]
	S = T(T.group == g, :);
	lastBlk = zeros(0, 1);
	for m = categories(S.mouse).'
		R = S(S.mouse == m, :);
		lastBlk(end + 1, 1) = mean(R.y(R.block == max(R.block))); %#ok<SAGROW>
	end
	fprintf('  %-6s 整体 %.3f   末块均值 %.3f (范围 %.2f-%.2f)\n', g, mean(S.y), ...
		mean(lastBlk), min(lastBlk), max(lastBlk));
end

%% ---------------------------------------------------------------
function out = iTrials(DS, sessions, stimuli, groupLabel)
sessions = sessions(:, {'Mouse', 'DateTime', 'Performance'});
sessions.Mouse = string(sessions.Mouse);
sessions = sortrows(sessions, {'Mouse', 'DateTime'});
mice = unique(sessions.Mouse, 'stable');
out = table();
for i = 1:numel(mice)
	m = mice(i);
	dt = unique(sessions.DateTime(sessions.Mouse == m));
	Tq = DS.TableQuery(["Mouse", "DateTime", "Stimulus", "Behavior"], Mouse = m);
	if isempty(Tq), continue; end
	Tq = Tq(ismember(string(Tq.Stimulus), stimuli), :);
	if isempty(Tq), continue; end
	tqDT = Tq.DateTime;
	if ~isempty(tqDT.TimeZone), tqDT.TimeZone = ''; end
	if ~isempty(dt.TimeZone), dt.TimeZone = ''; end
	[~, loc] = ismember(tqDT, dt);
	y = double(Tq.Behavior);
	ok = isfinite(y) & loc > 0;
	if sum(ok) == 0, continue; end
	out = [out; table(repmat(m, sum(ok), 1), double(loc(ok)), y(ok), ...
		repmat(string(groupLabel), sum(ok), 1), ...
		'VariableNames', {'mouse', 'block', 'y', 'group'})]; %#ok<AGROW>
end
end

function [k, U] = iFitFreeUpper(x, y)
%p = U / (1 + exp(-k(x-m)))，下限 0；U 自由
starts = [];
for u = [0.7 0.85 0.95]
	for lk = log([0.2 0.8 2 6])
		starts(end + 1, :) = [iLogit(u), lk, median(x)]; %#ok<AGROW>
	end
end
best = inf; pBest = [NaN NaN NaN];
for i = 1:size(starts, 1)
	p = fminsearch(@(p) iNLL(p, x, y), starts(i, :), ...
		optimset('Display', 'off', 'MaxFunEvals', 8000, 'MaxIter', 3000));
	o = iNLL(p, x, y);
	if isfinite(o) && o < best
		best = o; pBest = p;
	end
end
U = 1 / (1 + exp(-pBest(1)));
k = exp(min(pBest(2), log(200)));
end

function o = iNLL(p, x, y)
U = 1 / (1 + exp(-p(1)));
k = exp(min(p(2), log(200)));
pr = U ./ (1 + exp(-k * (x - p(3))));
pr = min(max(pr, 1e-12), 1 - 1e-12);
o = -sum(y .* log(pr) + (1 - y) .* log(1 - pr));
end

function y = iLogit(x)
x = min(max(x, 1e-6), 1 - 1e-6);
y = log(x / (1 - x));
end
