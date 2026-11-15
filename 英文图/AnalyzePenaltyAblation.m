% Penalty ablation: does the Naive vs 12h slope difference depend on the
% Jeffreys/Firth term and/or the weak log(k) prior?
%
% 4 objectives, all with lower asymptote fixed at 0 (FixLowerZero):
%   full   : LL + 0.5*logdetI - 0.5*(log k / 2)^2     (current implementation)
%   noJeff : LL               - 0.5*(log k / 2)^2
%   noPrior: LL + 0.5*logdetI
%   mle    : LL
%
% Cohort: same as ComparePenalizedSigmoidSlopes default (Naive / 12h from
% BuildIntervalBehaviorCurves), mouse-level trial tables.
clear variables; close all;
cd('d:\git\Transfer-Learning');
if ~exist('UniExp.DataSet', 'class')
	matlab.project.loadProject('d:\git\Transfer-Learning\Transferlearning.prj');
end
warning('off', 'UniExp:Exception:Block_must_warn');

[Curves, Trials] = TransferLearning.BuildIntervalBehaviorCurves();
Curves.Group = string(Curves.Group);
Trials.Group = string(Trials.Group);
TT = innerjoin(Trials, Curves(:, {'Group', 'Mouse', 'DateTime', 'Block'}), ...
	'Keys', {'Group', 'Mouse', 'DateTime'});

variants = ["full", "noJeff", "noPrior", "mle"];
groups = ["Naive", "12h"];
K = struct();
for v = variants
	K.(v) = table(strings(0, 1), strings(0, 1), nan(0, 1), nan(0, 1), ...
		'VariableNames', {'Group', 'Mouse', 'K', 'Mid'});
end

for g = groups
	mice = unique(string(TT.Mouse(TT.Group == g)));
	for m = mice.'
		Q = TT(TT.Group == g & TT.Mouse == m, :);
		x = double(Q.Block); y = double(Q.Behavior);
		ok = isfinite(x) & isfinite(y);
		x = x(ok); y = y(ok);
		if numel(unique(x)) < 2, continue; end
		for v = variants
			[p, obj] = iFit(x, y, v); %#ok<ASGLU>
			K.(v) = [K.(v); table(g, m, exp(p(1)), p(2), ...
				'VariableNames', {'Group', 'Mouse', 'K', 'Mid'})]; %#ok<AGROW>
		end
	end
end

fprintf('\n%-8s %6s %8s %8s %8s %10s\n', 'variant', 'nN', 'nT', 'medN', 'medT', 'p');
for v = variants
	T = K.(v);
	kN = T.K(T.Group == "Naive"); kT = T.K(T.Group == "12h");
	p = ranksum(kN, kT);
	fprintf('%-8s %6d %8d %8.2f %8.2f %10.3g   (mean %.2f vs %.2f)\n', ...
		v, numel(kN), numel(kT), median(kN), median(kT), p, mean(kN), mean(kT));
end

function [p, obj] = iFit(x, y, variant)
%multi-start over 4 slope starts, midpoint starts at median/min/max
starts = [];
for lk = log([0.2 0.8 2 6])
	for mv = unique([median(x), min(x), max(x)])
		starts(end + 1, :) = [lk, mv]; %#ok<AGROW>
	end
end
best = inf; p = nan(1, 2);
for i = 1:size(starts, 1)
	q = fminsearch(@(pp) iObjective(pp, x, y, variant), starts(i, :), ...
		optimset('Display', 'off', 'MaxFunEvals', 5000, 'MaxIter', 2000));
	o = iObjective(q, x, y, variant);
	if isfinite(o) && o < best
		best = o; p = q;
	end
end
obj = best;
end

function o = iObjective(p, x, y, variant)
k = exp(min(p(1), log(200)));
m = p(2);
pr = 1 ./ (1 + exp(-k * (x - m)));
pr = min(max(pr, 1e-12), 1 - 1e-12);
LL = sum(y .* log(pr) + (1 - y) .* log(1 - pr));
eta = k * (x - m); q = 1 ./ (1 + exp(-eta)); dq = q .* (1 - q);
J = [dq .* (x - m), -k * dq];
I = J' * (J .* (pr .* (1 - pr))) + eye(2) * 1e-10;
jeff = 0.5 * log(det(I));
prior = -0.5 * (p(1) / 2) ^ 2;
switch variant
	case "full"
		pen = jeff + prior;
	case "noJeff"
		pen = prior;
	case "noPrior"
		pen = jeff;
	otherwise
		pen = 0;
end
o = -(LL + pen);
end
