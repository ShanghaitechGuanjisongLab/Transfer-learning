% 延迟两组：达到"最大表现"所需训练 block 数
%
% 多种定义，避免单一指标的偶然性：
%   bMax      首次达到该鼠观测最大值（max）
%   b90rel    首次达到该鼠最大值的 90%
%   b90abs    首次达到 0.90（绝对）
%   b95abs    首次达到 0.95（绝对）
%   bLastNew  最后一次刷新自身最高值（之后不再提升）
% 均以 block 序号计（1 起），未达到者记为 max+1（删失）。
clear variables; close all;
cd('d:\git\Transfer-Learning');
if ~exist('UniExp.DataSet', 'class')
	matlab.project.loadProject('d:\git\Transfer-Learning\Transferlearning.prj');
end
warning('off', 'UniExp:Exception:Block_must_warn');

A = iPerMouse(TransferLearning.DelayComparison.CohortBlocks("DelayedBehaviorNaive"), "Naive");
B = iPerMouse(TransferLearning.DelayComparison.CohortBlocks("DelayedBehaviorTransfer"), "12h");

for X = {A, B}
	X = X{1};
	fprintf('\n===== %s =====\n', X.Label);
	fprintf('  %-10s %5s %6s %6s %7s %7s %7s %8s\n', 'Mouse', 'nBlk', 'max', ...
		'bMax', 'b90rel', 'b90abs', 'b95abs', 'bLastNew');
	for i = 1:height(X.T)
		fprintf('  %-10s %5d %6.2f %6d %7d %7d %7d %8d\n', X.T.Mouse(i), X.T.NBlk(i), ...
			X.T.Max(i), X.T.bMax(i), X.T.b90rel(i), X.T.b90abs(i), X.T.b95abs(i), X.T.bLastNew(i));
	end
end

fprintf('\n===== 组间比较（中位数 / 均值 / p）=====\n');
metrics = ["bMax", "b90rel", "b90abs", "b95abs", "bLastNew"];
for m = metrics
	fprintf('  %-9s Naive %5.2f / %5.2f   vs   12 h %5.2f / %5.2f   p=%.4g\n', m, ...
		median(A.T.(m)), mean(A.T.(m)), median(B.T.(m)), mean(B.T.(m)), ...
		ranksum(A.T.(m), B.T.(m)));
end

%% ---------------------------------------------------------------
function out = iPerMouse(S, label)
S.Mouse = string(S.Mouse);
S = sortrows(S, {'Mouse', 'DateTime'});
mice = unique(S.Mouse, 'stable');
n = numel(mice);
NB = zeros(n, 1); MX = nan(n, 1); bMax = nan(n, 1); b90rel = nan(n, 1);
b90abs = nan(n, 1); b95abs = nan(n, 1); bLastNew = nan(n, 1);
for i = 1:n
	v = double(S.Performance(S.Mouse == mice(i)));
	v = v(isfinite(v));
	NB(i) = numel(v);
	if isempty(v), continue; end
	L = numel(v);
	MX(i) = max(v);
	bMax(i) = find(v >= MX(i) - 1e-12, 1, 'first');
	b90rel(i) = iFirst(v, 0.9 * MX(i));
	b90abs(i) = iFirst(v, 0.90);
	b95abs(i) = iFirst(v, 0.95);
	% 最后一次刷新自身最高值的 block
	runMax = cummax(v);
	isNew = [true; diff(runMax) > 1e-12];
	idx = find(isNew);
	bLastNew(i) = idx(end);
	% 删失处理：未达到记 L+1
	if isempty(b90rel(i)) || isnan(b90rel(i)), b90rel(i) = L + 1; end
	if isnan(b90abs(i)), b90abs(i) = L + 1; end
	if isnan(b95abs(i)), b95abs(i) = L + 1; end
end
out = struct('Label', label, 'T', table(mice, NB, MX, bMax, b90rel, b90abs, b95abs, bLastNew, ...
	'VariableNames', {'Mouse', 'NBlk', 'Max', 'bMax', 'b90rel', 'b90abs', 'b95abs', 'bLastNew'}));
end

function idx = iFirst(v, thr)
idx = find(v >= thr - 1e-12, 1, 'first');
if isempty(idx), idx = NaN; end
end
