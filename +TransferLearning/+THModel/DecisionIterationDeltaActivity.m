function [l23DeltaActivity, l5RewardRecvDeltaActivity, l5ReadDeltaActivity] = DecisionIterationDeltaActivity(processHistory, ~, Params, ~)
requiredHistoryLength = Params.RecurrentPasses + 1;
processHistory = processHistory(:, 1:requiredHistoryLength);
initialActivity = processHistory(:, 1);
iterationHistory = processHistory(:, 2:requiredHistoryLength);

iterationWeights = Params.DecisionIterationEarlyWeightDecay .^ (Params.RecurrentPasses - 1:-1:0);
iterationWeights = iterationWeights ./ sum(iterationWeights);
meanIterationActivity = iterationHistory * iterationWeights(:);
deltaActivity = meanIterationActivity - initialActivity;
[l23DeltaActivity, l5RewardRecvDeltaActivity, l5ReadDeltaActivity] = TransferLearning.THModel.SplitInternalActivity(deltaActivity, Params);
end