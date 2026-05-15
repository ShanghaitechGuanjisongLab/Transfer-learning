function Params = DefaultParams()
% Cue/reward inputs plus three modeled cortical populations:
%   CueIn    (sensory cue input vector, not counted as L2/3 activity)
%   L23      (L2/3 population receiving CueIn through a plastic afferent map)
%   Reward   (reward input cells, independent from L5)
%   L5RewardRecv (L5 cells receiving L2/3 and Reward input)
%   L5Read   (L5 behavioural readout cells with task-shaped I-pool)
% One plastic E-E matrix spans all L2/3 and L5 cells. It is structurally
% all-to-all except for the diagonal self-projections.
% Decision phase uses sensory cue input only; L2/3 receives this input,
% then all L2/3/L5 populations settle through the recurrent internal
% projection. During learning, reward and readout feedback are added to the
% settled cue-decision network state; Reward input drives L5RewardRecv through
% a plastic afferent map, and readout drive remains a one-way input to L5Read.
% Learning phase applies outer-product Hebbian updates on cue-to-L2/3,
% reward-to-L5RewardRecv, and recurrent internal matrices plus cell-specific
% inhibitory WIE/WEI plasticity in L23/L5RewardRecv/L5Read pathways.
% Locked parameters: experiment design, acceptance/stop gates, and mechanism switches. Tuning
% scripts may not override these fields through THParamOverrides.
Params.MaxPretrainSessions = 16;
Params.NoiseCueBacktrainMaxAttempts = 16;
Params.NumMice = 20;
Params.NumSessions = 8;
Params.NumTrials = 30;
Params.Ceiling = 1.00;
Params.TransferHighestAlpha = 0.05;
Params.ClampNegativeActivity = 1;
Params.ClampNegativePatterns = 1;

% Tunable parameters: network size, behavior threshold, iteration count,
% model dynamics, plasticity strength, connection caps, initialization
% distributions, modality overlap, and consolidation drift.
Params.NL23 = 96;
Params.NCueInput = Params.NL23;
Params.NReward = 64;
Params.NL5Read = 64;
Params.NL5RewardRecv = 2 * Params.NL5Read;
Params.NIL23 = 24;
Params.NIL5RewardRecv = 16;
Params.NIL5Read = 16;
Params.HitThreshold = 0.7;
Params.RecurrentPasses = 2;
Params = TransferLearning.THModel.RefreshDerivedCellCounts(Params);

Params.ResponseScale = 1.45;
Params.NoiseCue = 0.70;
Params.NoiseRew = 0.15;
Params.NoiseRead = 0.12;
Params.Comp_Cue = 0.95;
Params.Comp_Rew = 1.00;
Params.Comp_Read = 1.20;
Params.CueInputGain = 0.54;
Params.NoiseCueBacktrainInputGain = 0.30;
Params.CueInputGainPretrain = 1.40;
Params.RewInputGain = 1.45;
Params.THRewardRecvInputGain = 1.50;
Params.ReadInputGain = 0.00;
Params.THReadInputGain = 2.80;
Params.THReadHeterogeneityGain = 2.50;
Params.InitWeightDistributionMode = 1;
Params.InitWeightChiSquareDof = 3;
Params.InitExcWeightMean = 0.10;
Params.InitExcWeightStd = 0.06;
Params.WCap = 2.50;
Params.AfferentWCap = 2.50;
Params.RewardAfferentNorm = 1.00;
Params.HebbRate = 0.007;
Params.FormalHebbGainStd = 0.35;
Params.FormalHebbGainMin = 0.65;
Params.FormalHebbGainMax = 1.55;
Params.FormalHitTeachingScale = 1.3;
Params.InhPlasticityRate = 0.0035;
Params.InhTargetAct = 0.00;
Params.InhWeightMax = 1.00;
Params.InitInhWeightMean = 0.86;
Params.InitInhWeightStd = 0.20;
Params.IToIGain = 0.50;
Params.CueModalityCorr = -1;
Params.OvernightRetention = 0.96;
Params.OvernightNoise = 0.002;
TransferLearning.THModel.ValidateParameterGrouping(Params);
end
