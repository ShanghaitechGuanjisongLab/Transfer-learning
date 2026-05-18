function teachingSignalScale = TeachingSignalScale(Cond, Params, usePreCue)
if usePreCue
	teachingSignalScale = 1.00;
	return;
end
if istable(Cond) && any(string(Cond.Properties.VariableNames) == "Name") && Cond.Name == "THOff"
	teachingSignalScale = Params.THOffTeachingSignalScale;
	return;
end
if istable(Cond) && any(string(Cond.Properties.VariableNames) == "TeachingSignalScale")
	teachingSignalScale = Cond.TeachingSignalScale;
elseif isstruct(Cond) && isfield(Cond, 'TeachingSignalScale')
	teachingSignalScale = Cond.TeachingSignalScale;
elseif istable(Cond) && any(string(Cond.Properties.VariableNames) == "RewardInputLevel")
	teachingSignalScale = Cond.RewardInputLevel;
elseif isstruct(Cond) && isfield(Cond, 'RewardInputLevel')
	teachingSignalScale = Cond.RewardInputLevel;
else
	teachingSignalScale = 1.00;
end
if ~isfinite(teachingSignalScale)
	teachingSignalScale = 1.00;
end
end