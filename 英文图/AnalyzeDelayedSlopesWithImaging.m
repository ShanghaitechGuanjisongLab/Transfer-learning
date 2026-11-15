% 延迟范式：纯行为 vs 加入成像鼠后的斜率变化
%
% 队列：
%   DelayedBehaviorNaive    = L2A_L_0928（纯行为）
%   DelayedNaive            = LADelayed（成像）
%   DelayedBehaviorTransfer = A2L_L_0928（纯行为）
%   DelayedTransfer         = ALDelayed（成像）
clear variables; close all;
cd('d:\git\Transfer-Learning');
if ~exist('UniExp.DataSet', 'class')
	matlab.project.loadProject('d:\git\Transfer-Learning\Transferlearning.prj');
end
warning('off', 'UniExp:Exception:Block_must_warn');

stim = ["LightLearnWater", "LightLearnWaterAlways"];

Bnaive = iSlopes(UniExp.DataSet(TransferLearning.DelayComparison.BehaviorDataPath("L2A_L")), ...
	TransferLearning.DelayComparison.CohortBlocks("DelayedBehaviorNaive"), stim, "behavior Naive");
Btrans = iSlopes(UniExp.DataSet(TransferLearning.DelayComparison.BehaviorDataPath("A2L_L")), ...
	TransferLearning.DelayComparison.CohortBlocks("DelayedBehaviorTransfer"), stim, "behavior 12 h");
Inaive = iSlopes(TransferLearning.LADelayed(), ...
	TransferLearning.DelayComparison.CohortBlocks("DelayedNaive"), stim, "imaging Naive (LADelayed)");
Itrans = iSlopes(TransferLearning.ALDelayed(), ...
	TransferLearning.DelayComparison.CohortBlocks("DelayedTransfer"), stim, "imaging 12 h (ALDelayed)");

fprintf('\n=== 合并后的组间比较（k 取逐 trial MLE）===\n');
kN_b = Bnaive.K(isfinite(Bnaive.K)); kT_b = Btrans.K(isfinite(Btrans.K));
kN_a = [kN_b; Inaive.K(isfinite(Inaive.K))];
kT_a = [kT_b; Itrans.K(isfinite(Itrans.K))];
fprintf('  纯行为：      Naive n=%2d median %.2f  vs  12 h n=%2d median %.2f   p=%.4g\n', ...
	numel(kN_b), median(kN_b), numel(kT_b), median(kT_b), ranksum(kN_b, kT_b));
fprintf('  含成像：      Naive n=%2d median %.2f  vs  12 h n=%2d median %.2f   p=%.4g\n', ...
	numel(kN_a), median(kN_a), numel(kT_a), median(kT_a), ranksum(kN_a, kT_a));
fprintf('  纯行为 vs 含成像（Naive）：  median %.2f vs %.2f   p=%.4g\n', ...
	median(kN_b), median(kN_a), ranksum(kN_b, kN_a));
fprintf('  纯行为 vs 含成像（12 h）：   median %.2f vs %.2f   p=%.4g\n', ...
	median(kT_b), median(kT_a), ranksum(kT_b, kT_a));

%% ---------------------------------------------------------------
function out = iSlopes(DS, sessions, stimuli, label)
sessions = sessions(:, {'Mouse', 'DateTime', 'Performance'});
sessions.Mouse = string(sessions.Mouse);
sessions = sortrows(sessions, {'Mouse', 'DateTime'});
mice = unique(sessions.Mouse, 'stable');
K = nan(numel(mice), 1); NB = zeros(numel(mice), 1); LS = nan(numel(mice), 1);
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
	NB(i) = numel(unique(loc(ok)));
	if NB(i) < 2, continue; end
	[~, ~, blockIdx] = unique(loc(ok));
	K(i) = iFitMLE(double(blockIdx), y(ok));
	LS(i) = iFitLS(double(blockIdx), y(ok));
end
fprintf('\n===== %s =====\n', label);
fprintf('  %-10s %6s %8s %8s\n', 'Mouse', 'nBlk', 'k_MLE', 'k_LS');
for i = 1:numel(mice)
	fprintf('  %-10s %6d %8.2f %8.2f\n', mice(i), NB(i), K(i), LS(i));
end
fprintf('  n=%d  median k_MLE=%.2f  median k_LS=%.2f\n', numel(mice), ...
	median(K, 'omitnan'), median(LS, 'omitnan'));
out = struct('Mouse', mice, 'K', K, 'LS', LS, 'NB', NB);
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
[g, xb] = findgroups(x);
perf = splitapply(@mean, y, g);
obj = @(p) sum((perf - 1 ./ (1 + exp(-exp(p(1)) .* (xb - p(2))))).^ 2);
best = inf; pBest = [NaN NaN];
for lk = log([0.2 0.8 2 6])
	p = fminsearch(obj, [lk median(xb)], optimset('Display', 'off'));
	o = obj(p);
	if isfinite(o) && o < best
		best = o; pBest = p;
	end
end
k = exp(pBest(1));
end
