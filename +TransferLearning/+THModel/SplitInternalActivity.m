function [l23Part, l5RewardRecvPart, l5ReadPart] = SplitInternalActivity(internalActivity, Params)
l23End = Params.NL23;
l5RewardRecvEnd = Params.NL23 + Params.NL5RewardRecv;
l23Part = internalActivity(1:l23End, :);
l5RewardRecvPart = internalActivity(l23End+1:l5RewardRecvEnd, :);
l5ReadPart = internalActivity(l5RewardRecvEnd+1:end, :);
end
