function [inhI, rawInhI] = RunInhibitoryPool(feedforwardInh, WII, Params, centerInh)
if nargin < 4
	centerInh = true;
end
inhFeedforward = max(0, feedforwardInh);
WII = max(WII, 0);
inhI = inhFeedforward;
for iPass = 1:Params.RecurrentPasses
	inhI = max(0, inhFeedforward - WII * inhI);
end
rawInhI = inhI;
if centerInh
	inhI = inhI - mean(inhI, 1);
end
end
