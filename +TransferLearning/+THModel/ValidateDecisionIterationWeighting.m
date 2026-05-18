function ValidateDecisionIterationWeighting(Params)
if Params.DecisionIterationEarlyWeightDecay < 0 || Params.DecisionIterationEarlyWeightDecay > 1
	error('THModel:InvalidDecisionIterationEarlyWeightDecay', 'DecisionIterationEarlyWeightDecay must be in [0, 1].');
end
end