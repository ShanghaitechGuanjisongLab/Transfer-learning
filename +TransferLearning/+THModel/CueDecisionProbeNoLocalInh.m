function Probe = CueDecisionProbeNoLocalInh(Mouse, cueInputPattern, Params, cueGain, l23InhibitoryCuePattern)
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
probeMouse.WI23ToL5RewardRecv = TransferLearning.THModel.Zeros(size(Mouse.WI23ToL5RewardRecv));
probeMouse.WI23ToL5Read = TransferLearning.THModel.Zeros(size(Mouse.WI23ToL5Read));
if nargin < 5 || isempty(l23InhibitoryCuePattern)
	l23InhibitoryCuePattern = TransferLearning.THModel.Zeros([Params.NIL23, 1]);
end
Probe = TransferLearning.THModel.CueDecisionProbe(probeMouse, cueInputPattern, Params, cueGain, l23InhibitoryCuePattern);
end
