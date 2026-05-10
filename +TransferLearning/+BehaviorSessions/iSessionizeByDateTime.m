function S = iSessionizeByDateTime(T)
useBehavior = ismember('Behavior', string(T.Properties.VariableNames));
if ~ismember('Phase', T.Properties.VariableNames)
	T.Phase = repmat(missing, height(T), 1);
end
if ~ismember('Group', T.Properties.VariableNames)
	T.Group = repmat("", height(T), 1);
end

if useBehavior
	T = T(:, {'Mouse','DateTime','Behavior','Phase','Group'});
else
	T = T(:, {'Mouse','DateTime','Performance','Phase','Group'});
end
T.Mouse = string(T.Mouse);
T.Group = string(T.Group);
T.DateTime = TransferLearning.BehaviorSessions.iNormalizeDateTime(T.DateTime);
T = sortrows(T, {'Group','Mouse','DateTime'});

if useBehavior
	val = double(T.Behavior);
else
	val = double(T.Performance);
end

[G, groupKeys, mouseKeys, dtKeys] = findgroups(T.Group, T.Mouse, T.DateTime);
perf = splitapply(@(x) mean(x, 'omitnan'), val, G);
nBlocks = splitapply(@(x) sum(isfinite(x)), val, G);
phaseSession = splitapply(@(x) TransferLearning.BehaviorSessions.iPickSessionPhase(x), string(T.Phase), G);
S = table(groupKeys, mouseKeys, dtKeys, perf, nBlocks, phaseSession, ...
	'VariableNames', {'Group','Mouse','DateTime','Performance','NBlocksInSession','Phase'});
end