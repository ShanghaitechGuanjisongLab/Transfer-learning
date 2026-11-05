function T = CellResponseTable(R)
% CellResponseTable  把一个EarlyOnsetCells结果汇总成每个细胞一行的响应表。
%
% 用于跨条件比较群体的cue锁定响应模式（文献Fig 1i口径：每细胞取线索后0~1 s平均响应，
% 再跨细胞求相关）。
%
% 输出列：Key, Mouse, CellUID, ActiveFrac, Resp

C = R.Cells;
neuroTime = double(seconds(TransferLearning.Xs(:).'));
responseWindow = neuroTime >= 0 & neuroTime <= 1;
cueResponse = mean(R.CueTraces(:, responseWindow), 2);
moveWindow = R.Grid >= 0 & R.Grid <= 0.5;
moveResponse = mean(R.Traces(:, moveWindow), 2);

[key, ~, group] = unique(string(C.Mouse) + "|" + string(C.CellUID));
nGroup = numel(key);
mouse = strings(nGroup, 1);
cellUID = zeros(nGroup, 1, 'uint64');
activeFrac = zeros(nGroup, 1);
respCue = nan(nGroup, 1);
respMove = nan(nGroup, 1);
for iGroup = 1:nGroup
	rows = group == iGroup;
	first = find(rows, 1);
	mouse(iGroup) = C.Mouse(first);
	cellUID(iGroup) = C.CellUID(first);
	activeFrac(iGroup) = mean(C.Class(rows) == "movement-active");
	respCue(iGroup) = mean(cueResponse(rows), 'omitnan');
	respMove(iGroup) = mean(moveResponse(rows), 'omitnan');
end

T = table(key, mouse, cellUID, activeFrac, respCue, respMove, ...
	'VariableNames', {'Key', 'Mouse', 'CellUID', 'ActiveFrac', 'RespCue', 'RespMove'});
end
