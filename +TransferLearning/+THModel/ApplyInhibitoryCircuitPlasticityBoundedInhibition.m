function Mouse = ApplyInhibitoryCircuitPlasticityBoundedInhibition(Mouse, Params, activityL23, activityL5RewardRecv, activityL5Read, eta, activityIL23, activityIL5Read)
if nargin < 8
	activityIL5Read = [];
end
[Mouse.WIE_L23, Mouse.WEI_L23, Mouse.WII_L23] = iInhibitoryAreaHebbBounded(Mouse.WIE_L23, Mouse.WEI_L23, Mouse.WII_L23, activityL23, Params, eta);
[Mouse.WIE_L5RewardRecv, Mouse.WEI_L5RewardRecv, Mouse.WII_L5RewardRecv] = iInhibitoryAreaHebbBounded(Mouse.WIE_L5RewardRecv, Mouse.WEI_L5RewardRecv, Mouse.WII_L5RewardRecv, activityL5RewardRecv, Params, eta);
readoutInhibitorySource = [activityL23; activityL5RewardRecv];
[Mouse.WIE_L5Read, Mouse.WEI_L5Read, Mouse.WII_L5Read] = iReadoutInhibitoryHebbBounded(Mouse.WIE_L5Read, Mouse.WEI_L5Read, Mouse.WII_L5Read, readoutInhibitorySource, activityL5Read, Params, eta, activityIL5Read);
if nargin < 7 || isempty(activityIL23)
	activeL23 = max(activityL23(:), 0);
	inhibitoryDriveL23 = TransferLearning.THModel.RunInhibitoryPool(max(Mouse.WEI_L23, 0) * activeL23, Mouse.WII_L23, Params, false);
	activityIL23 = iBoundedInhibitoryActivity(inhibitoryDriveL23, Params);
end
Mouse.WI23ToL5RewardRecv = TransferLearning.THModel.InhibitoryProjectionHebb(Mouse.WI23ToL5RewardRecv, activityIL23, activityL5RewardRecv, Params, eta);
Mouse.WI23ToL5Read = TransferLearning.THModel.InhibitoryProjectionHebb(Mouse.WI23ToL5Read, activityIL23, activityL5Read, Params, eta);
end

function [WIE, WEI, WII] = iInhibitoryAreaHebbBounded(WIE, WEI, WII, activityE, Params, eta)
activeE = max(activityE(:), 0);
if ~any(TransferLearning.THModel.GatherValue(activeE > 0))
	return;
end
inhibitoryDrive = TransferLearning.THModel.RunInhibitoryPool(max(WEI, 0) * activeE, WII, Params, false);
activeI = iBoundedInhibitoryActivity(inhibitoryDrive, Params);
deltaWIE = eta * (activeE .* (activeI' - activeE));
deltaWEI = eta * ((activeI - 0.5 * Params.ResponseScale) * activeE');
deltaWII = eta * (activeI .* (activeI' - activeI));
WIE = TransferLearning.THModel.ClampWeightsNonnegative(WIE + deltaWIE, Params.WeightMax, Params.InitWeightMin);
WEI = TransferLearning.THModel.ClampWeightsNonnegative(WEI + deltaWEI, Params.WeightMax, Params.InitWeightMin);
WII = TransferLearning.THModel.ZeroSelfProjection(TransferLearning.THModel.ClampWeightsNonnegative(WII + deltaWII, Params.WeightMax, Params.InitWeightMin));
end

function [WIE, WEI, WII] = iReadoutInhibitoryHebbBounded(WIE, WEI, WII, sourceActivity, readoutActivity, Params, eta, readoutInhibitoryActivity)
hasInhibitoryTeaching = nargin >= 8 && ~isempty(readoutInhibitoryActivity);
activeSource = max(sourceActivity(:), 0);
inhibitoryDrive = TransferLearning.THModel.RunInhibitoryPool(max(WEI, 0) * activeSource, WII, Params, false);
activeI = iBoundedInhibitoryActivity(inhibitoryDrive, Params);
if hasInhibitoryTeaching
	taughtI = max(readoutInhibitoryActivity(:), 0);
else
	taughtI = activeI;
end
hasCurrentI = any(TransferLearning.THModel.GatherValue(activeI > 0));
hasTaughtI = any(TransferLearning.THModel.GatherValue(taughtI > 0));
if ~hasCurrentI && ~hasTaughtI
	return;
end
activeReadout = max(readoutActivity(:), 0);
hasActiveReadout = any(TransferLearning.THModel.GatherValue(activeReadout > 0));
if ~hasActiveReadout && ~hasInhibitoryTeaching
	return;
end
deltaWIE = TransferLearning.THModel.Zeros(size(WIE));
deltaWEI = eta * ((taughtI - 0.5 * Params.ResponseScale) * activeSource');
deltaWII = TransferLearning.THModel.Zeros(size(WII));
if hasActiveReadout
	deltaWIE = eta * (activeReadout .* (activeI' - activeReadout));
end
if hasCurrentI
	deltaWII = eta * (activeI .* (activeI' - activeI));
end
WIE = TransferLearning.THModel.ClampWeightsNonnegative(WIE + deltaWIE, Params.WeightMax, Params.InitWeightMin);
WEI = TransferLearning.THModel.ClampWeightsNonnegative(WEI + deltaWEI, Params.WeightMax, Params.InitWeightMin);
WII = TransferLearning.THModel.ZeroSelfProjection(TransferLearning.THModel.ClampWeightsNonnegative(WII + deltaWII, Params.WeightMax, Params.InitWeightMin));
end

function activity = iBoundedInhibitoryActivity(inhibitoryDrive, Params)
activity = TransferLearning.THModel.ClampActivity(Params.ResponseScale * tanh(inhibitoryDrive), Params);
end
