function values = Standardize(values)
values = values(:);
values = values - mean(values);
sd = std(values, 0);
sdValue = TransferLearning.THModel.GatherScalar(sd);
if ~isfinite(sdValue) || sdValue < eps
	sd = 1;
end
values = values ./ sd;
end
