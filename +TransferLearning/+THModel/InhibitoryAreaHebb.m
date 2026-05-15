function [WIE, WEI, WII] = InhibitoryAreaHebb(WIE, WEI, WII, activityE, Params, plasticitySign)
if nargin < 6 || isempty(plasticitySign)
	plasticitySign = 1;
end
activeE = max(activityE(:) - Params.InhTargetAct, 0);
if ~any(TransferLearning.THModel.GatherValue(activeE > 0))
	return;
end
numExcCells = numel(activeE);
numInhibitoryCells = size(WII, 1);
inhDrive = TransferLearning.THModel.RunInhibitoryPool(WIE * activeE / numExcCells, WII, Params, numInhibitoryCells, false);
if ~any(TransferLearning.THModel.GatherValue(inhDrive > 0))
	return;
end
signedRate = plasticitySign * Params.InhPlasticityRate;
deltaWIE = signedRate * (inhDrive * activeE');
deltaWEI = signedRate * (activeE * inhDrive');
deltaWII = signedRate * (inhDrive * inhDrive');
WIE = TransferLearning.THModel.ClampWeightsNonnegative(WIE + deltaWIE, Params.InhWeightMax);
WEI = TransferLearning.THModel.ClampWeightsNonnegative(WEI + deltaWEI, Params.InhWeightMax);
WII = TransferLearning.THModel.ZeroSelfProjection(TransferLearning.THModel.ClampWeightsNonnegative(WII + deltaWII, Params.InhWeightMax));
end
