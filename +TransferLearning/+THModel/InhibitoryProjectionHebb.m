function W = InhibitoryProjectionHebb(W, sourceInhibitoryActivity, targetExcitatoryActivity, Params, eta)
activeSource = max(sourceInhibitoryActivity(:), 0);
activeTarget = max(targetExcitatoryActivity(:), 0);
if ~any(TransferLearning.THModel.GatherValue(activeTarget > 0))
	return;
end
deltaW = eta * (activeTarget .* (activeSource' - activeTarget));
W = TransferLearning.THModel.ClampWeightsNonnegative(W + deltaW, Params.WeightMax, Params.InitWeightMin);
end