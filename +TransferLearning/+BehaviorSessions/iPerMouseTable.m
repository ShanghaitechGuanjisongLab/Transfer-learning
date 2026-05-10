function PerMouse = iPerMouseTable(Sess)
Sess.Group = string(Sess.Group);
Sess.Mouse = string(Sess.Mouse);
[G, groupKeys, mouseKeys] = findgroups(Sess.Group, Sess.Mouse);
nSessions = splitapply(@numel, Sess.Performance, G);
meanPerf = splitapply(@(x) mean(double(x), 'omitnan'), Sess.Performance, G);
PerMouse = table(groupKeys, mouseKeys, nSessions, meanPerf, ...
	'VariableNames', {'Group','Mouse','NSessions','MeanPerformance'});
end