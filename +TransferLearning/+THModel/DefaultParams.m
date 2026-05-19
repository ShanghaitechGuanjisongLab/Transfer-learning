function Params = DefaultParams()
% Direct cue/reward/readout inputs plus three modeled cortical populations:
%   CueIn    (sensory cue input vector, added directly to L2/3 activity)
%   L23      (L2/3 population receiving direct cue input)
%   L5RewardRecv (L5 cells receiving direct reward/teaching input)
%   L5Read   (L5 behavioural readout cells with task-shaped I-pool)
% One plastic E-E matrix spans all L2/3 and L5 cells. It is structurally
% all-to-all except for the diagonal self-projections.
% Decision phase uses sensory cue input only; L2/3 receives this input,
% then all L2/3/L5 populations settle through the recurrent internal
% projection. During learning, reward and readout feedback are direct inputs
% to their target L5 cells.
% Learning phase applies outer-product Hebbian updates on recurrent internal
% matrices plus cell-specific
% inhibitory WIE (I-to-E) and WEI (E-to-I) plasticity in L23/L5RewardRecv/L5Read pathways.
% Locked parameters: experiment design, acceptance/stop gates, and mechanism switches. Tuning
% scripts may not override these fields through THParamOverrides.
Params.MaxPretrainSessions = 16;
Params.NoiseCueBacktrainMaxAttempts = 64;
Params.NumMice = 40;
Params.NumSessions = 8;
Params.NumTrials = 30;
Params.Ceiling = 1.00;
Params.TransferHighestAlpha = 0.05;
Params.TransferTHOffFirstSessionHitMax = 0.60;
Params.ClampNegativeActivity = 1;
Params.ClampNegativePatterns = 1;
Params.NoiseFirstStateCarryover = 1;

% Tunable parameters: network size, behavior threshold, iteration count,
% model dynamics, plasticity strength, connection caps, initialization
% distributions, and cue active fractions/overlap.
Params.NL23 = 96;
Params.NCueInput = Params.NL23;
Params.NL5Read = 64;
Params.NL5RewardRecv = 2 * Params.NL5Read;
Params.NIL23 = 24;
Params.NIL5RewardRecv = 16;
Params.NIL5Read = 16;
Params.HitThreshold = 0.8;
Params.RecurrentPasses = 5;
Params.DecisionIterationEarlyWeightDecay = 0.6;
Params.NoiseCueBacktrainRecurrentPasses = 8;
Params.THOffTeachingSignalScale = 0.3;
Params = TransferLearning.THModel.RefreshDerivedCellCounts(Params);

Params.ResponseScale = 1;
Params.NoiseScale = 0.05;
Params.InhibitorySuppressionGain = 1.00;
Params.CueInputGain = 0.14;
Params.NoiseCueBacktrainInputGain = 0.010;
Params.CueInputGainPretrain = 0.60;
Params.InitWeightMin = -0.7;
Params.WeightMax = 0.50;
Params.ExcitatoryPostActivityThreshold = 0.3;
Params.PretrainHebbRate = 20e-3;
Params.FormalHebbRate = 6.2e-3;
Params.CueModalityCorr = 0.00;
TransferLearning.THModel.ValidateCueFractionParameters(Params);
TransferLearning.THModel.ValidateDecisionIterationWeighting(Params);
TransferLearning.THModel.ValidateParameterGrouping(Params);
end
