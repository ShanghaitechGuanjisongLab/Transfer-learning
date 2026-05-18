function [WIE, WEI, WII] = InhibitoryAreaHebb(WIE, WEI, WII, activityE, Params, eta)
activeE = max(activityE(:), 0);
if ~any(TransferLearning.THModel.GatherValue(activeE > 0))
	return;
end
inhDrive = TransferLearning.THModel.RunInhibitoryPool(max(WEI, 0) * activeE, WII, Params, false);
deltaWIE = eta * (activeE .* (inhDrive' - activeE));
deltaWEI = eta * ((inhDrive - 0.5) * activeE');
deltaWII = eta * (inhDrive .* (inhDrive' - inhDrive));
WIE = TransferLearning.THModel.ClampWeightsNonnegative(WIE + deltaWIE, Params.WeightMax);
WEI = TransferLearning.THModel.ClampWeightsNonnegative(WEI + deltaWEI, Params.WeightMax);
WII = TransferLearning.THModel.ZeroSelfProjection(TransferLearning.THModel.ClampWeightsNonnegative(WII + deltaWII, Params.WeightMax));
end
