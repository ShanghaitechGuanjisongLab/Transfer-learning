function inhI = RunInhibitoryPool(feedforwardInh, WII, Params, numInhibitoryCells, centerInh)
if nargin < 5
	centerInh = true;
end
inhFeedforward = max(0, feedforwardInh);
inhI = inhFeedforward;
for iPass = 1:Params.RecurrentPasses
	inhI = max(0, inhFeedforward - Params.IToIGain * (WII * inhI) / numInhibitoryCells);
end
if centerInh
	inhI = inhI - mean(inhI, 1);
end
end
