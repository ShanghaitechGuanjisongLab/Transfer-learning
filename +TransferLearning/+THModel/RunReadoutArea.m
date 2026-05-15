function rL5Read = RunReadoutArea(preL5Read, readoutInhibitorySource, Mouse, Params)
activeSource = max(readoutInhibitorySource, 0);
numSourceCells = size(activeSource, 1);
inhDrive = TransferLearning.THModel.RunInhibitoryPool(Mouse.WIE_L5Read * activeSource / numSourceCells, Mouse.WII_L5Read, Params, Params.NIL5Read, false);
rL5Read = Params.ResponseScale * tanh(preL5Read - Params.Comp_Read * (Mouse.WEI_L5Read * inhDrive) / Params.NIL5Read);
rL5Read = TransferLearning.THModel.ClampActivity(rL5Read, Params);
end
