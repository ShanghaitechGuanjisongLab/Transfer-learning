% 惩罚版 sigmoid 斜率 × 响应异质性（与 Fig4D 同口径，但斜率换成逐 trial 惩罚估计）
%
% 对照：
%   LS   = 会话级最小二乘（下限 0、上限 1）—— 即 Fig4D 用的斜率
%   Pen  = 逐 trial 二项似然 + Jeffreys/Firth + log(k)~N(0,2²)（FixLowerZero）
%
% 异质性 = TransferLearning.Metrics.ResponseHeterogeneity（cue+1 s 的跨细胞 SD），
%          会话先做 pre-ceiling 筛选（首次 100% 及其后剔除），两层按有效细胞数加权合并。
% 相关：Spearman。
%
% 组：12 h（AudioLightBaseline）、Naive（LightAudioBaseline + LAInterspersed，仅成像）
clear variables; close all;
cd('d:\git\Transfer-Learning');
if ~exist('UniExp.DataSet', 'class')
	matlab.project.loadProject('d:\git\Transfer-Learning\Transferlearning.prj');
end
warning('off', 'UniExp:Exception:Block_must_warn');

%% 12 h：单数据集
report("12 h", TransferLearning.AudioLightBaseline(), ...
	TransferLearning.DelayComparison.CohortBlocks("UndelayedRecordingTransfer"));

%% Naive：两个成像数据集拼起来
iNaiveBoth();

%% ---------------------------------------------------------------
function D = report(groupName, DS, sessions)
D = table();
sessions = sessions(:, {'Mouse', 'DateTime', 'Performance'});
sessions.Mouse = string(sessions.Mouse);

% --- 逐 trial 斜率：full 惩罚版 + 纯 MLE（无任何惩罚）
pen = iTrialSlopes(DS, sessions, "full");
mle = iTrialSlopes(DS, sessions, "mle");
% --- LS 斜率（对照）
lsFit = TransferLearning.DelayComparison.FitSigmoidPerMouse( ...
	TransferLearning.DelayComparison.AddBlockIndex(sessions), true);

% --- 异质性
hetSessions = iPreCeilingSessions(sessions);
het = TransferLearning.Metrics.ResponseHeterogeneity(DS, hetSessions, "LightWater");
het = het(ismember(string(het.Layer), ["MOp2/3", "MOp5"]) & isfinite(het.SD) & het.NCells > 0, :);
if isempty(het)
	fprintf('%s：无异质性数据\n', groupName);
	return;
end
[g, mice] = findgroups(string(het.Mouse));
pooled = splitapply(@(s, n) sum(s .* n) / sum(n), het.SD, het.NCells, g);
H = table(mice, pooled, 'VariableNames', {'Mouse', 'Heterogeneity'});

fprintf('\n=== %s ===\n', groupName);
iCorr("LS slope", lsFit, H);
iCorr("trial MLE（无惩罚）", mle, H);
iCorr("trial 惩罚版", pen, H);

D = innerjoin(H, lsFit(:, {'Mouse', 'Slope'}), 'Keys', 'Mouse');
D.Properties.VariableNames{'Slope'} = 'LSSlope';
D = innerjoin(D, pen(:, {'Mouse', 'Slope'}), 'Keys', 'Mouse');
D.Properties.VariableNames{'Slope'} = 'PenSlope';
D = innerjoin(D, mle(:, {'Mouse', 'Slope'}), 'Keys', 'Mouse');
D.Properties.VariableNames{'Slope'} = 'MleSlope';
D = D(isfinite(D.LSSlope) & isfinite(D.PenSlope) & isfinite(D.MleSlope), :);
end

function iCorrPooled(Name, A, B)
D = [A; B];
if height(D) < 3, return; end
fprintf('\n=== %s（合并 n=%d）===\n', Name, height(D));
[r1, p1] = iRho(D.Heterogeneity, D.LSSlope);
[r2, p2] = iRho(D.Heterogeneity, D.MleSlope);
[r3, p3] = iRho(D.Heterogeneity, D.PenSlope);
fprintf('  LS        rho=%+.3f  p=%.4g\n', r1, p1);
fprintf('  trial MLE  rho=%+.3f  p=%.4g\n', r2, p2);
fprintf('  trial 惩罚  rho=%+.3f  p=%.4g\n', r3, p3);
end

function [rho, p] = iRho(a, b)
[rho, p] = corr(a, b, 'Type', 'Spearman');
end

function iCorr(label, fitTable, H)
D = innerjoin(fitTable(:, {'Mouse', 'Slope'}), H, 'Keys', 'Mouse');
D = D(isfinite(D.Slope) & isfinite(D.Heterogeneity), :);
if height(D) < 3
	fprintf('  %-12s 有效鼠 %d（<3，跳过）\n', label, height(D));
	return;
end
[rho, p] = corr(D.Heterogeneity, D.Slope, 'Type', 'Spearman');
fprintf('  %-12s n=%2d  Spearman rho=%+.3f  p=%.4g  (slope 范围 %.2f–%.2f)\n', ...
	label, height(D), rho, p, min(D.Slope), max(D.Slope));
end

function T = iScaleTable(T, factor)
T.Slope = T.Slope * factor;
end

function pen = iTrialSlopes(DS, sessions, method)
mice = unique(sessions.Mouse, 'stable');
pen = table(strings(0, 1), nan(0, 1), 'VariableNames', {'Mouse', 'Slope'});
for m = mice.'
	fprintf('  [%s] 拟合 %s ...\n', method, m);
	dt = unique(sessions.DateTime(sessions.Mouse == m));
	Tq = DS.TableQuery(["Mouse", "DateTime", "Stimulus", "Behavior"], Mouse = m, Stimulus = "LightWater");
	if isempty(Tq)
		continue;
	end
	% 时区统一（DS 的 DateTime 带时区，sessions 的不带）
	tqDT = Tq.DateTime;
	if ~isempty(tqDT.TimeZone), tqDT.TimeZone = ''; end
	if ~isempty(dt.TimeZone), dt.TimeZone = ''; end
	[~, loc] = ismember(tqDT, dt);
	y = double(Tq.Behavior);
	ok = isfinite(y) & loc > 0;
	if sum(ok) == 0 || numel(unique(loc(ok))) < 2
		continue;
	end
	% 把 DateTime 映射到该鼠的 session 序号（1..n）
	[~, ~, blockIdx] = unique(loc(ok));
	if method == "full"
		f = TransferLearning.FitPenalizedSigmoid(double(blockIdx), y(ok), FixLowerZero = true);
		k = f.Slope;
	else
		k = iFitMLE(double(blockIdx), y(ok));
	end
	pen = [pen; table(m, k, 'VariableNames', {'Mouse', 'Slope'})]; %#ok<AGROW>
end
end

function k = iFitMLE(x, y)
%逐 trial 二项似然，无任何惩罚；多起点取最优；k 上限 200 防爆炸
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

function S = iPreCeilingSessions(sessions)
%仅异质性用的会话筛选：剔除首次命中率 100% 的会话及其之后，且要求至少 2 个未学满会话
sessions = sortrows(sessions, {'Mouse', 'DateTime'});
keep = false(height(sessions), 1);
names = unique(string(sessions.Mouse), 'stable');
for i = 1:numel(names)
	idx = find(string(sessions.Mouse) == names(i));
	y = double(sessions.Performance(idx));
	c = find(y >= 1 - 1e-12, 1, 'first');
	if isempty(c)
		sel = idx;
	else
		sel = idx(1:max(c - 1, 0));
	end
	if numel(sel) >= 2
		keep(sel) = true;
	end
end
S = sessions(keep, :);
end

function iNaiveBoth()
S1 = TransferLearning.DelayComparison.CohortBlocks("UndelayedImagingNaive");
S1 = S1(strcmp(string(S1.Source), "LightAudioBaseline"), :);
D1 = report("Naive (LightAudioBaseline)", TransferLearning.LightAudioBaseline(), S1);
S2 = TransferLearning.DelayComparison.CohortBlocks("UndelayedImagingNaive");
S2 = S2(strcmp(string(S2.Source), "LAInterspersed"), :);
D2 = report("Naive (LAInterspersed)", TransferLearning.LAInterspersed(), S2);
if ~isempty(D1) && ~isempty(D2)
	iCorrPooled("Naive 成像合并", D1, D2);
end
end
