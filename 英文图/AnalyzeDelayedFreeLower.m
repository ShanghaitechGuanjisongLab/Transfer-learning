% 延迟纯行为队列：放开下渐近线（3 参数 trial 级 MLE）
%
% 模型 p(x) = L + (1-L)/(1+exp(-k(x-m)))，上渐近线固定 1，L/k/m 全自由
% 参数化：L = 1/(1+exp(-a))，k = exp(b)，m 自由
% 逐 trial 二项似然、无惩罚、多起点取最优（L 3 × k 4 × m ≤3）
% 对照：未延迟纯行为队列（同一步骤）
clear variables; close all;
cd('d:\git\Transfer-Learning');
if ~exist('UniExp.DataSet', 'class')
	matlab.project.loadProject('d:\git\Transfer-Learning\Transferlearning.prj');
end
warning('off', 'UniExp:Exception:Block_must_warn');
stim = ["LightLearnWater", "LightLearnWaterAlways"];

DN = iRun(UniExp.DataSet(TransferLearning.DelayComparison.BehaviorDataPath("L2A_L")), ...
	TransferLearning.DelayComparison.CohortBlocks("DelayedBehaviorNaive"), stim, "delayed Naive");
DT = iRun(UniExp.DataSet(TransferLearning.DelayComparison.BehaviorDataPath("A2L_L")), ...
	TransferLearning.DelayComparison.CohortBlocks("DelayedBehaviorTransfer"), stim, "delayed 12 h");
UN = iRun(TransferLearning.LAPureBehavior(), ...
	iSub(TransferLearning.DelayComparison.CohortBlocks("UndelayedImagingNaive"), "LAPureBehavior"), ...
	"LightWater", "undelayed Naive (pure-behavior)");
UT = iRun(TransferLearning.ALPureBehavior(), ...
	iSub(TransferLearning.DelayComparison.CohortBlocks("UndelayedImagingTransfer"), "ALPureBehavior"), ...
	"LightWater", "undelayed 12 h (pure-behavior)");

fprintf('\n========== 放开下渐近线后的组间比较 ==========\n');
iCmp("delayed   Naive vs 12 h（k）", DN.K, DT.K);
iCmp("delayed   Naive vs 12 h（L）", DN.L, DT.L);
iCmp("undelayed Naive vs 12 h（k）", UN.K, UT.K);
iCmp("undelayed Naive vs 12 h（L）", UN.L, UT.L);
iCmp("Naive: delayed vs undelayed（k）", DN.K, UN.K);
iCmp("12 h:  delayed vs undelayed（k）", DT.K, UT.K);

%% ---------------------------------------------------------------
function S = iSub(T, source)
S = T(string(T.Source) == source, :);
end

function out = iRun(DS, sessions, stimuli, label)
sessions = sessions(:, {'Mouse', 'DateTime', 'Performance'});
sessions.Mouse = string(sessions.Mouse);
sessions = sortrows(sessions, {'Mouse', 'DateTime'});
mice = unique(sessions.Mouse, 'stable');
n = numel(mice);
L = nan(n, 1); K = nan(n, 1); M = nan(n, 1); NB = zeros(n, 1);
for i = 1:n
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
	NB(i) = numel(unique(loc(ok)));
	if NB(i) < 2, continue; end
	[~, ~, blockIdx] = unique(loc(ok));
	[L(i), K(i), M(i)] = iFitFreeLower(double(blockIdx), y(ok));
end

fprintf('\n===== %s =====\n', label);
fprintf('  %-10s %5s %7s %8s %8s\n', 'Mouse', 'nBlk', 'L', 'k', 'm');
for i = 1:n
	fprintf('  %-10s %5d %7.2f %8.2f %8.2f\n', mice(i), NB(i), L(i), K(i), M(i));
end
fprintf('  n=%d  median L=%.2f  k=%.2f   (k<0.3: %d 只)\n', n, ...
	median(L, 'omitnan'), median(K, 'omitnan'), sum(K < 0.3));
out = struct('Mouse', mice, 'L', L, 'K', K, 'M', M, 'NB', NB);
end

function iCmp(name, a, b)
a = a(isfinite(a)); b = b(isfinite(b));
if numel(a) < 2 || numel(b) < 2
	fprintf('  %-32s 样本不足\n', name);
	return;
end
fprintf('  %-32s n=%2d/%2d  median %6.2f vs %6.2f  p=%.4g\n', name, numel(a), numel(b), ...
	median(a), median(b), ranksum(a, b));
end

function [L, k, m] = iFitFreeLower(x, y)
starts = [];
for a = log([0.05 0.2 0.45] ./ (1 - [0.05 0.2 0.45]))
	for b = log([0.2 0.8 2 6])
		for mm = unique([median(x), min(x), max(x)])
			starts(end + 1, :) = [a, b, mm]; %#ok<AGROW>
		end
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
L = 1 / (1 + exp(-pBest(1)));
k = exp(min(pBest(2), log(200)));
m = pBest(3);
end

function o = iNLL(p, x, y)
L = 1 / (1 + exp(-p(1)));
k = exp(min(p(2), log(200)));
pr = L + (1 - L) ./ (1 + exp(-k * (x - p(3))));
pr = min(max(pr, 1e-12), 1 - 1e-12);
o = -sum(y .* log(pr) + (1 - y) .* log(1 - pr));
end
