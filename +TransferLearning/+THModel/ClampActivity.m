function activity = ClampActivity(activity, Params)
if Params.ClampNegativeActivity ~= 0
	activity = max(activity, 0);
end
end