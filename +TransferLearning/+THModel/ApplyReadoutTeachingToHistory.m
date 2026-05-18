function postHistory = ApplyReadoutTeachingToHistory(processHistory, l5ReadTeachingActivity, Params)
postHistory = processHistory;
l5ReadRows = Params.NL23 + Params.NL5RewardRecv + (1:Params.NL5Read);
postHistory(l5ReadRows, :) = repmat(l5ReadTeachingActivity(:), 1, size(processHistory, 2));
end