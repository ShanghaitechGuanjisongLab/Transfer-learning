function [drive, targetMeanActivity, offTargetMeanActivity] = ReadoutDecisionDrive(Mouse, l5ReadActivity, l5ReadInhibitoryActivity, Params)
targetPattern = [Mouse.L5ReadoutPattern; Mouse.L5ReadInhibitoryReadoutPattern];
readoutActivity = [l5ReadActivity; l5ReadInhibitoryActivity];
[drive, targetMeanActivity, offTargetMeanActivity] = TransferLearning.THModel.ReadoutMatchDrive(targetPattern, readoutActivity, Params);
end