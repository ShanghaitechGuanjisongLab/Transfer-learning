% 延迟（delay）范式纯行为队列的 sigmoid 斜率：逐 trial MLE + 会话级 LS
%
% 队列（均无钙成像，纯行为）：
%   DelayedBehaviorNaive    = L2A_L_0928（光→声，naive 阶段）
%   DelayedBehaviorTransfer = A2L_L_0928（声→光，迁移阶段）
% 延迟范式：cue 1 s → delay 0.5 s → 舔水得水；刺激标签 LightLearnWater / LightLearnWaterAlways
%
% 同时给出未延迟纯行为队列（LAPureBehavior / ALPureBehavior）作对照。
clear variables; close all;
cd('d:\git\Transfer-Learning');
if ~exist('UniExp.DataSet', 'class')
	matlab.project.loadProject('d:\git\Transfer-Learning\Transferlearning.prj');
end
warning('off', 'UniExp:Exception:Block_must_warn');

out = struct();

%% 延迟：naive 与 transfer
out.DelayedNaive = iRun("DelayedBehaviorNaive", "L2A_L", "delayed Naive (L2A_L)");
out.DelayedTransfer = iRun("DelayedBehaviorTransfer", "A2L_L", "delayed 12 h (A2L_L)");

%% 未延迟纯行为（对照）
out.UndelayedNaive = iRunSessions("UndelayedImagingNaive", "LAPureBehavior", ...
	TransferLearning.LAPureBehavior(), "undelayed Naive (pure behavior)");
out.UndelayedTransfer = iRunSessions("UndelayedImagingTransfer", "ALPureBehavior", ...
	TransferLearning.ALPureBehavior(), "undelayed 12 h (pure behavior)");

%% 组间比较
fprintf('\n=== 组间比较（Spearman 无关，用秩和；k 取逐 trial MLE）===\n');
iCompare("delayed Naive vs delayed 12 h", out.DelayedNaive.Mle, out.DelayedTransfer.Mle);
iCompare("undelayed Naive vs undelayed 12 h", out.UndelayedNaive.Mle, out.UndelayedTransfer.Mle);
iCompare("Naive: delayed vs undelayed", out.DelayedNaive.Mle, out.UndelayedNaive.Mle);
iCompare("12 h: delayed vs undelayed", out.DelayedTransfer.Mle, out.UndelayedTransfer.Mle);

%% ---------------------------------------------------------------
function out = iRun(cohortName, pathKey, label)
sessions = TransferLearning.DelayComparison.CohortBlocks(cohortName);
DS = UniExp.DataSet(TransferLearning.DelayComparison.BehaviorDataPath(pathKey));
stimuli = ["LightLearnWater", "LightLearnWaterAlways"];
out = iFitAll(DS, sessions, stimuli, label);
end

function out = iRunSessions(cohortName, sourceName, DS, label)
sessions = TransferLearning.DelayComparison.CohortBlocks(cohortName);
sessions = sessions(string(sessions.Source) == sourceName, :);
out = iFitAll(DS, sessions, "LightWater", label);
end

function out = iFitAll(DS, sessions, stimuli, label)
sessions = sessions(:, {'Mouse', 'DateTime', 'Performance'});
sessions.Mouse = string(sessions.Mouse);
sessions = sortrows(sessions, {'Mouse', 'DateTime'});
mice = unique(sessions.Mouse, 'stable');

mle = nan(numel(mice), 1); ls = nan(numel(mice), 1); nb = zeros(numel(mice), 1);
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
	nb(i) = numel(unique(loc(ok)));
	if nb(i) < 2, continue; end
	[~, ~, blockIdx] = unique(loc(ok));
	mle(i) = iFitMLE(double(blockIdx), y(ok));
	ls(i) = iFitLS(double(blockIdx), y(ok));
end

fprintf('\n===== %s =====\n', label);
fprintf('  %-10s %6s %8s %8s\n', 'Mouse', 'nBlk', 'k_MLE', 'k_LS');
for i = 1:numel(mice)
	fprintf('  %-10s %6d %8.2f %8.2f\n', mice(i), nb(i), mle(i), ls(i));
end
fprintf('  %-10s %6s %8.2f %8.2f   (median)\n', sprintf('n=%d', numel(mice)), '', ...
	median(mle, 'omitnan'), median(ls, 'omitnan'));
fprintf('  %-10s %6s %8.2f %8.2f   (mean)\n', '', '', mean(mle, 'omitnan'), mean(ls, 'omitnan'));
out = struct('Mouse', mice, 'NBlock', nb, 'Mle', mle, 'LS', ls, 'Label', label);
end

function iCompare(name, a, b)
a = a(isfinite(a)); b = b(isfinite(b));
if numel(a) < 2 || numel(b) < 2
	fprintf('  %-38s 样本不足\n', name);
	return;
end
p = ranksum(a, b);
fprintf('  %-38s n=%2d/%2d  median %5.2f vs %5.2f  p=%.4g\n', name, numel(a), numel(b), ...
	median(a), median(b), p);
end

function k = iFitMLE(x, y)
starts = [log(0.2) median(x); log(0.8) median(x); log(2) median(x); log(6) median(x)];
best = inf; pBest = [NaN NaN];
for i = 1:size(starts, 1)
	p = fminsearch(@(p) iNLL(p, x, y), starts(i, :), ...
		optimset('Display', 'off', 'MaxFunEvals', 5000, 'MaxIter', 2000));
	o = iNLL(p, x, y);
	if isfinite(o) && o < best
		best = o; pBest = p;
	end
end
k = exp(min(pBest(1), log(200)));
end

function o = iNLL(p, x, y)
k = exp(min(p(1), log(200)));
pr = 1 ./ (1 + exp(-k * (x - p(2))));
pr = min(max(pr, 1e-12), 1 - 1e-12);
o = -sum(y .* log(pr) + (1 - y) .* log(1 - pr));
end

function k = iFitLS(x, y)
%先在 trial 级求会话命中率，再做会话级最小二乘
[g, xb] = findgroups(x);
perf = splitapply(@mean, y, g);
obj = @(p) sum((perf - 1 ./ (1 + exp(-exp(p(1)) .* (xb - p(2))))).^ 2);
pBest = [NaN NaN]; best = inf;
for lk = log([0.2 0.8 2 6])
	p = fminsearch(obj, [lk median(xb)], optimset('Display', 'off'));
	o = obj(p);
	if isfinite(o) && o < best
		best = o; pBest = p;
	end
end
k = exp(pBest(1));
end
