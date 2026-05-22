function Mouse = ApplyInhibitoryCircuitPlasticityHistory(Mouse, Params, excitatoryHistory, inhibitoryHistory, eta, finalL5ReadInhibitoryTeachingActivity, eligibilityDecay)
if nargin < 6
	finalL5ReadInhibitoryTeachingActivity = [];
end
if nargin < 7 || isempty(eligibilityDecay)
	eligibilityDecay = 1;
end

numHistoryColumns = size(excitatoryHistory, 2);
if numHistoryColumns < 2
	return;
end

for iPass = 2:numHistoryColumns
	eligibilityWeight = eligibilityDecay ^ (numHistoryColumns - iPass);
	if eligibilityWeight == 0
		continue;
	end
	[l23Activity, l5RewardRecvActivity, l5ReadActivity] = TransferLearning.THModel.SplitInternalActivity(excitatoryHistory(:, iPass), Params);
	l23InhibitoryActivity = iBoundedInhibitoryActivity(inhibitoryHistory.L23(:, iPass), Params);
	if iPass == numHistoryColumns && ~isempty(finalL5ReadInhibitoryTeachingActivity)
		l5ReadInhibitoryActivity = finalL5ReadInhibitoryTeachingActivity;
	else
		l5ReadInhibitoryActivity = [];
	end
	Mouse = TransferLearning.THModel.ApplyInhibitoryCircuitPlasticityBoundedInhibition(Mouse, Params, l23Activity, l5RewardRecvActivity, l5ReadActivity, eta * eligibilityWeight, l23InhibitoryActivity, l5ReadInhibitoryActivity);
end
end

function activity = iBoundedInhibitoryActivity(inhibitoryDrive, Params)
activity = TransferLearning.THModel.ClampActivity(Params.ResponseScale * tanh(inhibitoryDrive), Params);
end
