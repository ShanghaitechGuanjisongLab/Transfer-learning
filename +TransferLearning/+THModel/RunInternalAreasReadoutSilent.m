function state = RunInternalAreasReadoutSilent(inputToL23, inputToL5RewardRecv, inputToL5Read, Mouse, Params)
state.L23 = TransferLearning.THModel.RunArea(inputToL23, 'l23', Mouse, Params);
state.L5RewardRecv = TransferLearning.THModel.RunArea(inputToL5RewardRecv, 'l5rewardrecv', Mouse, Params);
state.L5Read = TransferLearning.THModel.Zeros([Params.NL5Read, size(inputToL5Read, 2)]);
state.All = [state.L23; state.L5RewardRecv; state.L5Read];
end
