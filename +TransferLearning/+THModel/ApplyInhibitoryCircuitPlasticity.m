function Mouse = ApplyInhibitoryCircuitPlasticity(Mouse, Params, activityL23, activityL5RewardRecv, activityL5Read, eta, activityIL23, activityIL5Read)
if nargin < 8
	activityIL5Read = [];
end
[Mouse.WIE_L23, Mouse.WEI_L23, Mouse.WII_L23] = TransferLearning.THModel.InhibitoryAreaHebb(Mouse.WIE_L23, Mouse.WEI_L23, Mouse.WII_L23, activityL23, Params, eta);
[Mouse.WIE_L5RewardRecv, Mouse.WEI_L5RewardRecv, Mouse.WII_L5RewardRecv] = TransferLearning.THModel.InhibitoryAreaHebb(Mouse.WIE_L5RewardRecv, Mouse.WEI_L5RewardRecv, Mouse.WII_L5RewardRecv, activityL5RewardRecv, Params, eta);
readoutInhibitorySource = [activityL23; activityL5RewardRecv];
[Mouse.WIE_L5Read, Mouse.WEI_L5Read, Mouse.WII_L5Read] = TransferLearning.THModel.ReadoutInhibitoryHebb(Mouse.WIE_L5Read, Mouse.WEI_L5Read, Mouse.WII_L5Read, readoutInhibitorySource, activityL5Read, Params, eta, activityIL5Read);
if nargin < 7 || isempty(activityIL23)
	activeL23 = max(activityL23(:), 0);
	activityIL23 = TransferLearning.THModel.RunInhibitoryPool(max(Mouse.WEI_L23, 0) * activeL23, Mouse.WII_L23, Params, false);
end
Mouse.WI23ToL5RewardRecv = TransferLearning.THModel.InhibitoryProjectionHebb(Mouse.WI23ToL5RewardRecv, activityIL23, activityL5RewardRecv, Params, eta);
Mouse.WI23ToL5Read = TransferLearning.THModel.InhibitoryProjectionHebb(Mouse.WI23ToL5Read, activityIL23, activityL5Read, Params, eta);
end
