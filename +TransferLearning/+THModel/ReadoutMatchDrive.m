function [drive, targetMeanActivity, offTargetMeanActivity] = ReadoutMatchDrive(targetPattern, readoutActivity, Params)
targetMask = targetPattern(:) > 0;
offTargetMask = ~targetMask;
readoutActivity = readoutActivity(:);
if TransferLearning.THModel.GatherScalar(any(targetMask))
	targetMeanActivity = mean(readoutActivity(targetMask), 'omitnan');
else
	targetMeanActivity = 0;
end
if TransferLearning.THModel.GatherScalar(any(offTargetMask))
	offTargetMeanActivity = mean(readoutActivity(offTargetMask), 'omitnan');
else
	offTargetMeanActivity = 0;
end
drive = TransferLearning.THModel.GatherScalar((targetMeanActivity - offTargetMeanActivity) / Params.ResponseScale);
targetMeanActivity = TransferLearning.THModel.GatherScalar(targetMeanActivity);
offTargetMeanActivity = TransferLearning.THModel.GatherScalar(offTargetMeanActivity);
end