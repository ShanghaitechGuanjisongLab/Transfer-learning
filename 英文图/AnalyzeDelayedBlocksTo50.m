% 延迟范式两组：blocks to 50% 与首块命中率
%
% 口径同 TransferLearning.Metrics.PerMouseSessionSummary：
%   达到 50% 命中率的 block，相邻两点线性插值；末次仍未达到者记为 max(block)+1（删失）
clear variables; close all;
cd('d:\git\Transfer-Learning');
if ~exist('UniExp.DataSet', 'class')
	matlab.project.loadProject('d:\git\Transfer-Learning\Transferlearning.prj');
end
warning('off', 'UniExp:Exception:Block_must_warn');

A = iSummary(TransferLearning.DelayComparison.CohortBlocks("DelayedBehaviorNaive"), "Naive");
B = iSummary(TransferLearning.DelayComparison.CohortBlocks("DelayedBehaviorTransfer"), "12h");
C = iSummary(TransferLearning.DelayComparison.CohortBlocks("DelayedTransfer"), "12h (imaging)");

fprintf('\n=== blocks to 50%% ===\n');
iCmp("Naive vs 12 h（纯行为）", A.BlocksToHalf, B.BlocksToHalf);
iCmp("Naive vs 12 h（含成像）", A.BlocksToHalf, [B.BlocksToHalf; C.BlocksToHalf]);
fprintf('\n=== first block 命中率 ===\n');
iCmp("Naive vs 12 h（纯行为）", A.FirstPerf, B.FirstPerf);
iCmp("Naive vs 12 h（含成像）", A.FirstPerf, [B.FirstPerf; C.FirstPerf]);

%% ---------------------------------------------------------------
function T = iSummary(S, label)
S.Group = repmat(label, height(S), 1);
T = TransferLearning.Metrics.PerMouseSessionSummary(S(:, {'Group', 'Mouse', 'DateTime', 'Performance'}));
T.Mouse = string(T.Mouse);
cens = T.BlocksToHalf > T.NSessions;
fprintf('\n----- %s -----\n', label);
fprintf('  %-10s %5s %8s %10s\n', 'Mouse', 'nSes', 'first', 'blocks50');
for i = 1:height(T)
	tag = "";
	if cens(i), tag = "  (未达50%)"; end
	fprintf('  %-10s %5d %8.2f %10.2f%s\n', T.Mouse(i), T.NSessions(i), T.FirstPerf(i), ...
		T.BlocksToHalf(i), tag);
end
fprintf('  n=%d  median blocks50=%.2f  mean=%.2f  未达50%%: %d 只\n', height(T), ...
	median(T.BlocksToHalf), mean(T.BlocksToHalf), sum(cens));
end

function iCmp(name, a, b)
a = a(isfinite(a)); b = b(isfinite(b));
fprintf('  %-24s n=%2d/%2d  median %5.2f vs %5.2f  mean %5.2f vs %5.2f  p=%.4g\n', ...
	name, numel(a), numel(b), median(a), median(b), mean(a), mean(b), ranksum(a, b));
end
