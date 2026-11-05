function Fit = FitSigmoidPerMouse(T, LowerFixed)
%FITSIGMOIDPERMOUSE Per-mouse sigmoid fit of hit rate over block index.
%   T must contain Mouse, Block and Performance (see AddBlockIndex). Mice with
%   fewer than two blocks or without performance variation are skipped.
%   LowerFixed=true fixes the lower asymptote at 0 (spec of Fig1B and FigS1D);
%   the default leaves it free (spec of Fig1G / Fig1H).
%   Returns Group (when T has a Group column), Mouse, Lower, Upper, Slope,
%   Midpoint and RSquared.
arguments
	T table
	LowerFixed (1,1) logical = false
end
T = sortrows(T, {'Mouse','DateTime'});
mice = unique(string(T.Mouse), 'stable');
n = numel(mice);
Lower = nan(n, 1); Upper = nan(n, 1); Slope = nan(n, 1);
Midpoint = nan(n, 1); RSquared = nan(n, 1);
keep = false(n, 1);
for i = 1:n
	rows = string(T.Mouse) == mice(i) & isfinite(double(T.Block)) & isfinite(double(T.Performance));
	Ti = T(rows, :);
	if height(Ti) < 2 || numel(unique(double(Ti.Performance))) < 2
		continue;
	end
	f = TransferLearning.DelayComparison.FitSigmoidGroup(Ti, mice(i), LowerFixed);
	Lower(i) = f.Lower; Upper(i) = f.Upper; Slope(i) = f.Slope;
	Midpoint(i) = f.Midpoint; RSquared(i) = f.RSquared;
	keep(i) = true;
end
Fit = table;
if ismember('Group', T.Properties.VariableNames)
	group = strings(n, 1);
	for i = 1:n
		group(i) = string(T.Group(find(string(T.Mouse) == mice(i), 1)));
	end
	Fit.Group = group(keep);
end
Fit.Mouse = mice(keep);
Fit.Lower = Lower(keep);
Fit.Upper = Upper(keep);
Fit.Slope = Slope(keep);
Fit.Midpoint = Midpoint(keep);
Fit.RSquared = RSquared(keep);
end
