function Mouse = ApplyInhibitoryCircuitPlasticity(Mouse, Params, activityL23, activityL5RewardRecv, activityL5Read, plasticitySign)
if nargin < 6 || isempty(plasticitySign)
	plasticitySign = 1;
end
[Mouse.WIE_L23, Mouse.WEI_L23, Mouse.WII_L23] = TransferLearning.THModel.InhibitoryAreaHebb(Mouse.WIE_L23, Mouse.WEI_L23, Mouse.WII_L23, activityL23, Params, plasticitySign);
[Mouse.WIE_L5RewardRecv, Mouse.WEI_L5RewardRecv, Mouse.WII_L5RewardRecv] = TransferLearning.THModel.InhibitoryAreaHebb(Mouse.WIE_L5RewardRecv, Mouse.WEI_L5RewardRecv, Mouse.WII_L5RewardRecv, activityL5RewardRecv, Params, plasticitySign);
readoutInhibitorySource = [activityL23; activityL5RewardRecv];
[Mouse.WIE_L5Read, Mouse.WEI_L5Read, Mouse.WII_L5Read] = TransferLearning.THModel.ReadoutInhibitoryHebb(Mouse.WIE_L5Read, Mouse.WEI_L5Read, Mouse.WII_L5Read, readoutInhibitorySource, activityL5Read, Params, plasticitySign);
end
