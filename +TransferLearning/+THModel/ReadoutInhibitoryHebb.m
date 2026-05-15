function [WIE, WEI, WII] = ReadoutInhibitoryHebb(WIE, WEI, WII, sourceActivity, readoutActivity, Params, plasticitySign)
if nargin < 7 || isempty(plasticitySign)
	plasticitySign = 1;
end
activeSource = max(sourceActivity(:) - Params.InhTargetAct, 0);
if ~any(TransferLearning.THModel.GatherValue(activeSource > 0))
	return;
end
numSourceCells = numel(activeSource);
numInhibitoryCells = size(WII, 1);
inhDrive = TransferLearning.THModel.RunInhibitoryPool(WIE * activeSource / numSourceCells, WII, Params, numInhibitoryCells, false);
if ~any(TransferLearning.THModel.GatherValue(inhDrive > 0))
	return;
end
activeReadout = max(readoutActivity(:) - Params.InhTargetAct, 0);
if ~any(TransferLearning.THModel.GatherValue(activeReadout > 0))
	return;
end
signedRate = plasticitySign * Params.InhPlasticityRate;
deltaWIE = signedRate * (inhDrive * activeSource');
deltaWEI = signedRate * (activeReadout * inhDrive');
deltaWII = signedRate * (inhDrive * inhDrive');
WIE = TransferLearning.THModel.ClampWeightsNonnegative(WIE + deltaWIE, Params.InhWeightMax);
WEI = TransferLearning.THModel.ClampWeightsNonnegative(WEI + deltaWEI, Params.InhWeightMax);
WII = TransferLearning.THModel.ZeroSelfProjection(TransferLearning.THModel.ClampWeightsNonnegative(WII + deltaWII, Params.InhWeightMax));
end
