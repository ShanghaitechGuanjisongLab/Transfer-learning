function state = RunInternalAreas(inputToL23, inputToL5RewardRecv, inputToL5Read, Mouse, Params, useReadoutInhibition, readoutInhibitionSource)
if nargin < 6
	useReadoutInhibition = true;
end
if nargin < 7 || isempty(readoutInhibitionSource)
	readoutInhibitionSource = TransferLearning.THModel.Zeros([Params.NL23 + Params.NL5RewardRecv, size(inputToL23, 2)]);
end
state.L23 = TransferLearning.THModel.RunArea(inputToL23, 'l23', Mouse, Params);
state.L5RewardRecv = TransferLearning.THModel.RunArea(inputToL5RewardRecv, 'l5rewardrecv', Mouse, Params);
if useReadoutInhibition
	state.L5Read = TransferLearning.THModel.RunReadoutArea(inputToL5Read, readoutInhibitionSource, Mouse, Params);
else
	state.L5Read = TransferLearning.THModel.ClampActivity(Params.ResponseScale * tanh(inputToL5Read), Params);
end
state.All = [state.L23; state.L5RewardRecv; state.L5Read];
end
