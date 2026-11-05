function T = ExcludeCeilingSessions(T)
%EXCLUDECEILINGSESSIONS Drop training sessions from the first perfect session.
%   Same rule as Fig1H_SlopeVsHeterogeneity: for each mouse keep the sessions
%   before the first session whose hit rate reaches 1; mice whose first
%   session is already perfect are dropped, as are mice left with fewer than
%   two sessions.
arguments
	T table
end
T = sortrows(T, {'Mouse','DateTime'});
mice = unique(T.Mouse);
keep = false(height(T), 1);
for i = 1:numel(mice)
	idx = find(T.Mouse == mice(i));
	perf = double(T.Performance(idx));
	firstPerfect = find(perf >= 1 - 1e-12, 1, 'first');
	if isempty(firstPerfect)
		endIdx = numel(idx);
	else
		endIdx = firstPerfect - 1;
	end
	if endIdx < 2
		continue;
	end
	keep(idx(1:endIdx)) = true;
end
T = T(keep, :);
end
