% 延迟范式纯行为队列：剔除"拟合退化"鼠后的斜率结果
%
% 退化/不合格判据（任一即剔除）：
%   A 首块命中率 > 0.5      —— 起点不 naive，sigmoid 下限 0 的前提不成立
%   B Spearman(block, perf) < 0.3 —— 整体无上升趋势
%   C k_MLE < 0.3            —— 拟合退化为近似平坦
% 同时给出未延迟纯行为队列在同一筛法下的结果作对照。
clear variables; close all;
cd('d:\git\Transfer-Learning');
if ~exist('UniExp.DataSet', 'class')
	matlab.project.loadProject('d:\git\Transfer-Learning\Transferlearning.prj');
end
warning('off', 'UniExp:Exception:Block_must_warn');
stim = ["LightLearnWater", "LightLearnWaterAlways"];

DN = iAnalyze(UniExp.DataSet(TransferLearning.DelayComparison.BehaviorDataPath("L2A_L")), ...
	TransferLearning.DelayComparison.CohortBlocks("DelayedBehaviorNaive"), stim, "delayed Naive");
DT = iAnalyze(UniExp.DataSet(TransferLearning.DelayComparison.BehaviorDataPath("A2L_L")), ...
	TransferLearning.DelayComparison.CohortBlocks("DelayedBehaviorTransfer"), stim, "delayed 12 h");
UN = iAnalyze(TransferLearning.LAPureBehavior(), ...
	iSub(TransferLearning.DelayComparison.CohortBlocks("UndelayedImagingNaive"), "LAPureBehavior"), ...
	"LightWater", "undelayed Naive (pure-behavior)");
UT = iAnalyze(TransferLearning.ALPureBehavior(), ...
	iSub(TransferLearning.DelayComparison.CohortBlocks("UndelayedImagingTransfer"), "ALPureBehavior"), ...
	"LightWater", "undelayed 12 h (pure-behavior)");

fprintf('\n========== 各种筛法下 Naive vs 12 h ==========\n');
iScen("delayed   全部", DN, DT);
iScen("delayed   剔 C(k<0.3)", DN(DN.K >= 0.3 | ~isfinite(DN.K), :), DT(DT.K >= 0.3 | ~isfinite(DT.K), :));
iScen("delayed   剔 A+B+C", DN(iKeep(DN), :), DT(iKeep(DT), :));
iScen("undelayed 全部", UN, UT);
iScen("undelayed 剔 A+B+C", UN(iKeep(UN), :), UT(iKeep(UT), :));

%% ---------------------------------------------------------------
function S = iSub(T, source)
S = T(string(T.Source) == source, :);
end

function ok = iKeep(T)
ok = T.K >= 0.3 & T.First <= 0.5 & T.Rho >= 0.3;
end

function T = iAnalyze(DS, sessions, stimuli, label)
sessions = sessions(:, {'Mouse', 'DateTime', 'Performance'});
sessions.Mouse = string(sessions.Mouse);
sessions = sortrows(sessions, {'Mouse', 'DateTime'});
mice = unique(sessions.Mouse, 'stable');
n = numel(mice);
K = nan(n, 1); LS = nan(n, 1); NB = zeros(n, 1); First = nan(n, 1); Rho = nan(n, 1);
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
	[g, xb] = findgroups(double(blockIdx));
	perf = splitapply(@mean, y(ok), g);
	First(i) = perf(1);
	Rho(i) = corr(xb, perf, 'Type', 'Spearman');
	K(i) = iFitMLE(double(blockIdx), y(ok));
	LS(i) = iFitLS(xb, perf);
end
T = table(mice, NB, First, Rho, K, LS, 'VariableNames', ...
	{'Mouse', 'NBlock', 'First', 'Rho', 'K', 'LS'});

fprintf('\n===== %s =====\n', label);
fprintf('  %-10s %5s %6s %6s %8s %8s  %s\n', 'Mouse', 'nBlk', 'first', 'rho', 'k_MLE', 'k_LS', 'flags');
for i = 1:n
	f = "";
	if First(i) > 0.5, f = f + "A "; end
	if Rho(i) < 0.3, f = f + "B "; end
	if K(i) < 0.3, f = f + "C "; end
	fprintf('  %-10s %5d %6.2f %6.2f %8.2f %8.2f  %s\n', mice(i), NB(i), First(i), Rho(i), K(i), LS(i), f);
end
fprintf('  n=%d  median k_MLE=%.2f  k_LS=%.2f   (A:%d B:%d C:%d)\n', n, ...
	median(K, 'omitnan'), median(LS, 'omitnan'), sum(First > 0.5), sum(Rho < 0.3), sum(K < 0.3));
end

function iScen(name, A, B)
a = A.K(isfinite(A.K)); b = B.K(isfinite(B.K));
if numel(a) < 2 || numel(b) < 2
	fprintf('  %-22s 样本不足 (n=%d/%d)\n', name, numel(a), numel(b));
	return;
end
fprintf('  %-22s n=%2d/%2d  median %5.2f vs %5.2f  mean %5.2f vs %5.2f  p=%.4g\n', ...
	name, numel(a), numel(b), median(a), median(b), mean(a), mean(b), ranksum(a, b));
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

function k = iFitLS(xb, perf)
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
