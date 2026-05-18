function [WIE, WEI, WII] = ReadoutInhibitoryHebb(WIE, WEI, WII, sourceActivity, readoutActivity, Params, eta, readoutInhibitoryActivity)
hasInhibitoryTeaching = nargin >= 8 && ~isempty(readoutInhibitoryActivity);
activeSource = max(sourceActivity(:), 0);
inhDrive = TransferLearning.THModel.RunInhibitoryPool(max(WEI, 0) * activeSource, WII, Params, false);
if hasInhibitoryTeaching
	taughtInhDrive = max(readoutInhibitoryActivity(:), 0);
else
	taughtInhDrive = inhDrive;
end
hasCurrentInhDrive = any(TransferLearning.THModel.GatherValue(inhDrive > 0));
hasTaughtInhDrive = any(TransferLearning.THModel.GatherValue(taughtInhDrive > 0));
if ~hasCurrentInhDrive && ~hasTaughtInhDrive
	return;
end
activeReadout = max(readoutActivity(:), 0);
hasActiveReadout = any(TransferLearning.THModel.GatherValue(activeReadout > 0));
if ~hasActiveReadout && ~hasInhibitoryTeaching
	return;
end
deltaWIE = TransferLearning.THModel.Zeros(size(WIE));
deltaWEI = eta * ((taughtInhDrive - 0.5) * activeSource');
deltaWII = TransferLearning.THModel.Zeros(size(WII));
if hasActiveReadout
	deltaWIE = eta * (activeReadout .* (inhDrive' - activeReadout));
end
if hasCurrentInhDrive
	deltaWII = eta * (inhDrive .* (inhDrive' - inhDrive));
end
WIE = TransferLearning.THModel.ClampWeightsNonnegative(WIE + deltaWIE, Params.WeightMax);
WEI = TransferLearning.THModel.ClampWeightsNonnegative(WEI + deltaWEI, Params.WeightMax);
WII = TransferLearning.THModel.ZeroSelfProjection(TransferLearning.THModel.ClampWeightsNonnegative(WII + deltaWII, Params.WeightMax));
end
