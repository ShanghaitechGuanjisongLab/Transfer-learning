function [rL5Read, rL5ReadInhibitory] = RunReadoutArea(preL5Read, readoutInhibitorySource, Mouse, Params)
activeSource = max(readoutInhibitorySource, 0);
[inhDrive, rawL5ReadInhibitory] = TransferLearning.THModel.RunInhibitoryPool(max(Mouse.WEI_L5Read, 0) * activeSource, Mouse.WII_L5Read, Params, false);
rL5ReadInhibitory = TransferLearning.THModel.ClampActivity(Params.ResponseScale * tanh(rawL5ReadInhibitory), Params);
rL5Read = Params.ResponseScale * tanh(preL5Read - Params.InhibitorySuppressionGain * (max(Mouse.WIE_L5Read, 0) * inhDrive));
rL5Read = TransferLearning.THModel.ClampActivity(rL5Read, Params);
end
