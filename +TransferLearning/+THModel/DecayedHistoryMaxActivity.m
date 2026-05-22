function activity = DecayedHistoryMaxActivity(activityHistory, historyDecay)
historyLength = size(activityHistory, 2);
historyWeights = historyDecay .^ (historyLength - 1:-1:0);
activity = max(activityHistory .* historyWeights, [], 2);
end