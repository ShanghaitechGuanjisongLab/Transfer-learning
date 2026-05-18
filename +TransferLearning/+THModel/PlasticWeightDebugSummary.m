function weightSummary = PlasticWeightDebugSummary(Mouse, Params)
internalWeights = TransferLearning.THModel.NonSelfInternalWeights(Mouse.W_L23L5ToL23L5);
l5ReadWIE = TransferLearning.THModel.GatherValue(Mouse.WIE_L5Read(:));
l5ReadWEI = TransferLearning.THModel.GatherValue(Mouse.WEI_L5Read(:));
weightSummary.CueMean = NaN;
weightSummary.CueZeroFraction = NaN;
weightSummary.CueCapFraction = NaN;
weightSummary.InternalMean = mean(internalWeights, 'omitnan');
weightSummary.InternalZeroFraction = mean(internalWeights <= 0, 'omitnan');
weightSummary.InternalCapFraction = mean(internalWeights >= 0.999 * Params.WeightMax, 'omitnan');
weightSummary.L5ReadWIEMean = mean(l5ReadWIE, 'omitnan');
weightSummary.L5ReadWIEZeroFraction = mean(l5ReadWIE <= 0, 'omitnan');
weightSummary.L5ReadWIECapFraction = mean(l5ReadWIE >= 0.999 * Params.WeightMax, 'omitnan');
weightSummary.L5ReadWEIMean = mean(l5ReadWEI, 'omitnan');
weightSummary.L5ReadWEIZeroFraction = mean(l5ReadWEI <= 0, 'omitnan');
weightSummary.L5ReadWEICapFraction = mean(l5ReadWEI >= 0.999 * Params.WeightMax, 'omitnan');
end
