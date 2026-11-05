function S = CFosInhibitionSessions()
%CFOSINHIBITIONSESSIONS cFos 标记抑制实验的光水学习会话（Control vs MOp 抑制组）
%
%   S = TransferLearning.BehaviorSessions.CFosInhibitionSessions()
%
%   数据：\\Data-Server-2\个人数据\张天夫\202611\cFos合集.v3.mat
%   分组：MarkTimes==0 的鼠为 Control（标记的是空笼期活跃细胞）；
%         ExpressedBrain 恰为 "MOp" 且 MarkTimes>0 的鼠为 MOp 抑制组。
%
%   输出列：Group | Mouse | DateTime | Performance | Session

DS = UniExp.DataSet("\\Data-Server-2\个人数据\张天夫\202611\cFos合集.v3.mat");

M = DS.Mice;
M.Mouse = string(M.Mouse);
M.Group = string(M.ExpressedBrain);
M.Group(~logical(M.MarkTimes)) = "Control";
keep = M.Group == "Control" | M.Group == "MOp";
M = M(keep, :);
[~, first] = unique(M.Mouse, 'stable');
M = M(first, :);

Tq = DS.TableQuery(["Mouse","DateTime","Stimulus","Behavior"], Stimulus="LightWater");
Tq.Mouse = string(Tq.Mouse);
Tq = innerjoin(Tq, M(:, {'Mouse','Group'}), 'Keys', 'Mouse');
if isempty(Tq)
	S = table(strings(0,1), NaT(0,1), strings(0,1), nan(0,1), zeros(0,1), ...
		'VariableNames', {'Group','Mouse','DateTime','Performance','Session'});
	return;
end
Tq.Group = string(Tq.Group);
S = TransferLearning.BehaviorSessions.iSessionizeByDateTime(Tq(:, {'Mouse','DateTime','Behavior','Group'}));
S = sortrows(S, {'Group','Mouse','DateTime'});
S = TransferLearning.BehaviorSessions.iAddSessionIndex(S);
end
