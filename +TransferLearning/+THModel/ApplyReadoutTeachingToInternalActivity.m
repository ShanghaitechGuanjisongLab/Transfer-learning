function [postActivity, l5ReadTeachingActivity] = ApplyReadoutTeachingToInternalActivity(internalActivity, Mouse, Params, teachingSignalScale)
if nargin < 4 || isempty(teachingSignalScale) || ~isfinite(teachingSignalScale)
	teachingSignalScale = 1;
end
postActivity = internalActivity;
l5ReadTeachingActivity = TransferLearning.THModel.PatternActivity(Mouse.L5ReadoutPattern, Params);
l5ReadRows = Params.NL23 + Params.NL5RewardRecv + (1:Params.NL5Read);
postActivity(l5ReadRows, :) = internalActivity(l5ReadRows, :) + teachingSignalScale * (repmat(l5ReadTeachingActivity(:), 1, size(internalActivity, 2)) - internalActivity(l5ReadRows, :));
end