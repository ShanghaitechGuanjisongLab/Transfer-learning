function [rE, rI] = RunArea(pre, areaSpec, Mouse, Params, inhibitoryInput)
switch areaSpec
case 'l23'
	WIE = Mouse.WIE_L23; WEI = Mouse.WEI_L23; WII = Mouse.WII_L23;
case 'l5rewardrecv'
	WIE = Mouse.WIE_L5RewardRecv; WEI = Mouse.WEI_L5RewardRecv; WII = Mouse.WII_L5RewardRecv;
end
if nargin < 5 || isempty(inhibitoryInput)
	inhibitoryInput = TransferLearning.THModel.Zeros([size(WEI, 1), size(pre, 2)]);
end
exc = max(pre, 0);
[inhI, rI] = TransferLearning.THModel.RunInhibitoryPool(max(WEI, 0) * exc + inhibitoryInput, WII, Params, true);
rE = Params.ResponseScale * tanh(pre - Params.InhibitorySuppressionGain * (max(WIE, 0) * inhI));
rE = TransferLearning.THModel.ClampActivity(rE, Params);
end
