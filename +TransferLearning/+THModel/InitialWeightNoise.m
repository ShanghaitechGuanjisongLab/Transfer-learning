function values = InitialWeightNoise(weightSize, Params)
modeValue = round(Params.InitWeightDistributionMode);
if modeValue == 0
	values = TransferLearning.THModel.Randn(weightSize);
	return;
end
if modeValue == 1
	dofValue = max(1, round(Params.InitWeightChiSquareDof));
	values = TransferLearning.THModel.Zeros(weightSize);
	for iDof = 1:dofValue
		r = TransferLearning.THModel.Randn(weightSize);
		values = values + r .^ 2;
	end
	values = (values - dofValue) ./ sqrt(2 * dofValue);
	return;
end
error('THModel:InvalidInitWeightDistributionMode', 'InitWeightDistributionMode must be 0 for normal or 1 for standardized chi-square noise.');
end