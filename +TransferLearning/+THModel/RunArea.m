function rE = RunArea(pre, areaSpec, Mouse, Params)
switch areaSpec
case 'l23'
	WIE = Mouse.WIE_L23; WEI = Mouse.WEI_L23; WII = Mouse.WII_L23;
	NI = Params.NIL23; NE = Params.NL23; Comp = Params.Comp_Cue;
case 'reward'
	rE = Params.ResponseScale * tanh(pre);
	rE = TransferLearning.THModel.ClampActivity(rE, Params);
	return;
case 'l5rewardrecv'
	WIE = Mouse.WIE_L5RewardRecv; WEI = Mouse.WEI_L5RewardRecv; WII = Mouse.WII_L5RewardRecv;
	NI = Params.NIL5RewardRecv; NE = Params.NL5RewardRecv; Comp = Params.Comp_Rew;
end
exc = max(pre, 0);
inhI = TransferLearning.THModel.RunInhibitoryPool(WIE * exc / NE, WII, Params, NI, true);
rE = Params.ResponseScale * tanh(pre - Comp * (WEI * inhI) / NI);
rE = TransferLearning.THModel.ClampActivity(rE, Params);
end
