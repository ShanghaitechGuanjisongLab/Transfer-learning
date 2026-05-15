function gain = MouseScalarGain(stdValue, minValue, maxValue)
if stdValue <= 0
	gain = 1;
	return;
end
gain = 1 + stdValue * TransferLearning.THModel.GatherScalar(TransferLearning.THModel.Randn([1, 1]));
gain = TransferLearning.THModel.Clamp(gain, minValue, maxValue);
end
