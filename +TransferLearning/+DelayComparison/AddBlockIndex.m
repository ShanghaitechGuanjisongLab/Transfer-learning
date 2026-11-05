function T = AddBlockIndex(T)
%ADDBLOCKINDEX Per-mouse session index (1..n) ordered by DateTime.
arguments
	T table
end
T.Mouse = string(T.Mouse);
T = sortrows(T, {'Mouse','DateTime'});
[G, ~] = findgroups(T.Mouse);
blockCell = splitapply(@(x) {(1:numel(x))'}, T.DateTime, G);
T.Block = vertcat(blockCell{:});
end
