function [bMouse, bPhase, bDesign] = AlignBlockMeta(B, DT)
%ALIGNBLOCKMETA 把 Blocks 的每一行对齐到 DateTimes，取回 (鼠, 阶段, 设计)
%
%   为什么需要这个函数
%     `Blocks` 与 `DateTimes` 是两张**行序不同**的表：同一个 `DateTime` 在两张表里的行号
%     不一样（实测 114 个 block 只有 39 行恰好对齐）。因此**绝不能按行号**把 `DT` 的
%     `Mouse`/`Phase` 装到 `B` 上，否则会把 A 鼠的阶段标签装到 B 鼠的记录上。
%     两张表的 `DateTime` 各自无重复，故按值匹配是唯一的。
%
%   输入
%     B  : `Blocks` 表，需含 `DateTime`、`Design`
%     DT : `DateTimes` 表，需含 `DateTime`、`Mouse`、`Phase`
%   输出
%     bMouse, bPhase, bDesign : 与 `B` **同行数**的 string 列向量
%       · 未匹配上的行取 `""`（调用方应据此跳过该 block）
%       · `Phase` 为缺失值写 `"(无)"`，避免 string 的 `<missing>` 在比较里传播
%
%   见 `TransferLearning.BlockSampleRate`

bMouse = strings(height(B), 1);
bPhase = strings(height(B), 1);
bDesign = strings(height(B), 1);
for j = 1:height(B)
	k = find(DT.DateTime == B.DateTime(j), 1);
	if isempty(k); continue; end
	bMouse(j) = string(DT.Mouse(k));
	p = string(DT.Phase(k));
	if ismissing(p); p = "(无)"; end
	bPhase(j) = p;
	bDesign(j) = string(B.Design(j));
end
end
