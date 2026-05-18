function [l23DeltaActivity, l5RewardRecvDeltaActivity, l5ReadDeltaActivity] = DecisionIterationDeltaActivity(processHistory, Mouse, Params, teachingSignalScale)
if nargin < 4 || isempty(teachingSignalScale) || ~isfinite(teachingSignalScale)
	teachingSignalScale = 1;
end
requiredHistoryLength = Params.RecurrentPasses + 1;
processHistory = processHistory(:, 1:requiredHistoryLength);
initialActivity = processHistory(:, 1);
iterationHistory = processHistory(:, 2:requiredHistoryLength);

if teachingSignalScale ~= 0
	l5ReadRows = Params.NL23 + Params.NL5RewardRecv + (1:Params.NL5Read);
	l5ReadTeachingActivity = TransferLearning.THModel.PatternActivity(Mouse.L5ReadoutPattern, Params);
	iterationHistory(l5ReadRows, :) = iterationHistory(l5ReadRows, :) + teachingSignalScale * (repmat(l5ReadTeachingActivity(:), 1, Params.RecurrentPasses) - iterationHistory(l5ReadRows, :));
end

iterationWeights = Params.DecisionIterationEarlyWeightDecay .^ (Params.RecurrentPasses - 1:-1:0);
iterationWeights = iterationWeights ./ sum(iterationWeights);
meanIterationActivity = iterationHistory * iterationWeights(:);
deltaActivity = meanIterationActivity - initialActivity;
[l23DeltaActivity, l5RewardRecvDeltaActivity, l5ReadDeltaActivity] = TransferLearning.THModel.SplitInternalActivity(deltaActivity, Params);
end