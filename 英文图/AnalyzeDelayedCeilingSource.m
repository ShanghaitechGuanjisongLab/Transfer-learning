% 12 h 延迟组后期的"饱和"是天花板效应吗？
%
% 三项检查：
%  1 每只 12 h 鼠的末段水平（末两块均值）——有多少已经贴到 1.0
%  2 逐鼠末段斜率（empirical logit 对 block 的回归，block>=3）与剩余空间 (1-plateau) 的相关
%     ——如果饱和是天花板造成，剩余空间越小，末段斜率应越接近 0
%  3 按末段水平分层：plateau>=0.95 与 <0.95 两组的末段斜率
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
	fprintf('  %-10s %5s %8s %8s %10s\n', 'Mouse', 'nBlk', 'plateau', 'lateSlope', 'headroom');
	for i = 1:height(X.T)
		fprintf('  %-10s %5d %8.3f %8.3f %10.3f\n', X.T.Mouse(i), X.T.NBlk(i), ...
			X.T.Plateau(i), X.T.LateSlope(i), 1 - X.T.Plateau(i));
	end
	hi = X.T.Plateau >= 0.95;
	fprintf('  plateau>=0.95: %d 只  vs  <0.95: %d 只\n', sum(hi), sum(~hi));
	fprintf('  lateSlope 中位：高平台 %+.3f  vs 低平台 %+.3f   p=%.4g\n', ...
		median(X.T.LateSlope(hi), 'omitnan'), median(X.T.LateSlope(~hi), 'omitnan'), ...
		ranksum(X.T.LateSlope(hi), X.T.LateSlope(~hi)));
	ok = isfinite(X.T.LateSlope) & isfinite(X.T.Plateau);
	[rho, p] = corr(X.T.Plateau(ok), X.T.LateSlope(ok), 'Type', 'Spearman');
	fprintf('  plateau 与 lateSlope 相关：rho=%+.3f  p=%.4g\n', rho, p);
end

fprintf('\n===== 两组横向比较 =====\n');
fprintf('  plateau 中位：Naive %.3f  vs  12 h %.3f   p=%.4g\n', ...
	median(A.T.Plateau), median(B.T.Plateau), ranksum(A.T.Plateau, B.T.Plateau));
fprintf('  lateSlope 中位：Naive %+.3f  vs  12 h %+.3f   p=%.4g\n', ...
	median(A.T.LateSlope, 'omitnan'), median(B.T.LateSlope, 'omitnan'), ...
	ranksum(A.T.LateSlope, B.T.LateSlope));

%% ---------------------------------------------------------------
function out = iPerMouse(S, label)
S.Mouse = string(S.Mouse);
S = sortrows(S, {'Mouse', 'DateTime'});
mice = unique(S.Mouse, 'stable');
n = numel(mice);
NB = zeros(n, 1); PL = nan(n, 1); SL = nan(n, 1);
for i = 1:n
	v = double(S.Performance(S.Mouse == mice(i)));
	v = v(isfinite(v));
	NB(i) = numel(v);
	if numel(v) < 3, continue; end
	PL(i) = mean(v(max(1, end - 1):end));         % 末两块均值作为平台
	b = (1:numel(v))';
	% empirical logit（加 0.5 校正）对 block 的回归，取 block>=3 段
	use = b >= 3;
	if sum(use) < 2
		use = true(size(b));
	end
	el = log((v + 0.5) ./ (numel(v) * 0 + 1 - v + 0.5));  % 占位，下行重算
	el = log((v(use) + 0.5) ./ (1 - v(use) + 0.5));
	pp = polyfit(b(use), el, 1);
	SL(i) = pp(1);
end
out = struct('Label', label, 'T', table(mice, NB, PL, SL, 'VariableNames', ...
	{'Mouse', 'NBlk', 'Plateau', 'LateSlope'}));
end
