function pattern = ClampPattern(pattern, Params)
if Params.ClampNegativePatterns ~= 0
	pattern = max(pattern, 0);
	rmsValue = TransferLearning.THModel.GatherScalar(sqrt(mean(pattern .^ 2, 'omitnan')));
	if isfinite(rmsValue) && rmsValue > eps
		pattern = pattern ./ rmsValue;
	end
end
end