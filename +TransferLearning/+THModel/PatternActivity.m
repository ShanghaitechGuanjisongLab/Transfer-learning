function activity = PatternActivity(pattern, Params)
activity = Params.ResponseScale * (pattern(:) > 0);
end