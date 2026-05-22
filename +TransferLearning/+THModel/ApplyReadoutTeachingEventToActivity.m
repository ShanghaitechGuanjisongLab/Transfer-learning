function taughtActivity = ApplyReadoutTeachingEventToActivity(activity, Mouse, Params, teachingSignalScale)
taughtActivity = activity;
l5ReadRows = Params.NL23 + Params.NL5RewardRecv + (1:Params.NL5Read);
l5ReadTeachingActivity = TransferLearning.THModel.PatternActivity(Mouse.L5ReadoutPattern, Params);
taughtActivity(l5ReadRows) = activity(l5ReadRows) + teachingSignalScale * (l5ReadTeachingActivity(:) - activity(l5ReadRows));
end
