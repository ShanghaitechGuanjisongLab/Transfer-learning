function Probe = CueDecisionProbeNoLocalInh(Mouse, cueInputPattern, Params, cueGain)
if nargin < 4
	cueGain = Params.CueInputGain;
end
probeMouse = Mouse;
probeMouse.WIE_L23 = TransferLearning.THModel.Zeros(size(Mouse.WIE_L23));
probeMouse.WEI_L23 = TransferLearning.THModel.Zeros(size(Mouse.WEI_L23));
probeMouse.WII_L23 = TransferLearning.THModel.Zeros(size(Mouse.WII_L23));
probeMouse.WIE_L5RewardRecv = TransferLearning.THModel.Zeros(size(Mouse.WIE_L5RewardRecv));
probeMouse.WEI_L5RewardRecv = TransferLearning.THModel.Zeros(size(Mouse.WEI_L5RewardRecv));
probeMouse.WII_L5RewardRecv = TransferLearning.THModel.Zeros(size(Mouse.WII_L5RewardRecv));
probeMouse.WIE_L5Read = TransferLearning.THModel.Zeros(size(Mouse.WIE_L5Read));
probeMouse.WEI_L5Read = TransferLearning.THModel.Zeros(size(Mouse.WEI_L5Read));
probeMouse.WII_L5Read = TransferLearning.THModel.Zeros(size(Mouse.WII_L5Read));
Probe = TransferLearning.THModel.CueDecisionProbe(probeMouse, cueInputPattern, Params, cueGain);
end
