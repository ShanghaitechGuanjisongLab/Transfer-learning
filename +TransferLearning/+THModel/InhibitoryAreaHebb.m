function [WIE, WEI, WII] = InhibitoryAreaHebb(WIE, WEI, WII, activityE, Params, eta, activityI)
activeE = max(activityE(:), 0);
if ~any(TransferLearning.THModel.GatherValue(activeE > 0))
	return;
end
if nargin < 7 || isempty(activityI)
	inhDrive = TransferLearning.THModel.RunInhibitoryPool(max(WEI, 0) * activeE, WII, Params, false);
else
	inhDrive = max(activityI(:), 0);
end
deltaWIE = eta * (activeE .* (inhDrive' - activeE));
deltaWEI = eta * ((inhDrive - 0.5) * activeE');
deltaWII = eta * (inhDrive .* (inhDrive' - inhDrive));
WIE = TransferLearning.THModel.ClampWeightsNonnegative(WIE + deltaWIE, Params.WeightMax, Params.InitWeightMin);
WEI = TransferLearning.THModel.ClampWeightsNonnegative(WEI + deltaWEI, Params.WeightMax, Params.InitWeightMin);
WII = TransferLearning.THModel.ZeroSelfProjection(TransferLearning.THModel.ClampWeightsNonnegative(WII + deltaWII, Params.WeightMax, Params.InitWeightMin));
end
