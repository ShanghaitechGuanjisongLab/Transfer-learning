function [Mean, Sem, N] = CurveSummary(T, X)
%CURVESUMMARY Mean, SEM and mouse count per block index.
%   T must contain Block and Performance (see AddBlockIndex).
arguments
	T table
	X (:,1) double
end
Mean = nan(numel(X), 1);
Sem = nan(numel(X), 1);
N = zeros(numel(X), 1);
block = double(T.Block);
perf = double(T.Performance);
mouse = string(T.Mouse);
for k = 1:numel(X)
	rows = block == X(k) & isfinite(perf);
	vals = perf(rows);
	N(k) = numel(unique(mouse(rows)));
	if isempty(vals)
		continue;
	end
	Mean(k) = mean(vals);
	if numel(vals) > 1
		Sem(k) = std(vals) / sqrt(numel(vals));
	else
		Sem(k) = 0;
	end
end
end
