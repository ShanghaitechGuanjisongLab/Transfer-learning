function TrialTable = SampleDecisionTrials(Mouse, Params, cueMode, numTrials, includeNoise)
if nargin < 3 || isempty(cueMode)
	cueMode = "formalCue";
end
if nargin < 4 || isempty(numTrials)
	numTrials = Params.NumTrials;
end
if nargin < 5 || isempty(includeNoise)
	includeNoise = true;
end
cueMode = string(cueMode);
drive = nan(numTrials, 1);
hit = false(numTrials, 1);
cueCorrelation = nan(numTrials, 1);

for iTrial = 1:numTrials
	[cueInputPattern, cueGain] = iDecisionCuePattern(Mouse, Params, cueMode);
	if includeNoise
		cueInput = cueGain * cueInputPattern + Params.NoiseCue * TransferLearning.THModel.Randn([Params.NCueInput, 1]);
		preL23 = cueInput + Params.NoiseCue * TransferLearning.THModel.Randn([Params.NL23, 1]);
		preL5RewardRecv = Params.NoiseRew * TransferLearning.THModel.Randn([Params.NL5RewardRecv, 1]);
		preL5Read = Params.NoiseRead * TransferLearning.THModel.Randn([Params.NL5Read, 1]);
	else
		preL23 = cueGain * cueInputPattern;
		preL5RewardRecv = TransferLearning.THModel.Zeros([Params.NL5RewardRecv, 1]);
		preL5Read = TransferLearning.THModel.Zeros([Params.NL5Read, 1]);
	end
	[~, ~, rL5Read] = TransferLearning.THModel.RunInternalNetwork(preL23, preL5RewardRecv, preL5Read, Mouse, Params);
	drive(iTrial) = TransferLearning.THModel.GatherScalar(mean(Mouse.L5ReadoutPattern .* rL5Read));
	hit(iTrial) = drive(iTrial) >= Params.HitThreshold;
	cueCorrelation(iTrial) = iCueCorrelation(Mouse.PreCueInputPattern, cueInputPattern);
end

TrialTable = table((1:numTrials)', repmat(cueMode, numTrials, 1), hit, drive, cueCorrelation, ...
	'VariableNames', {'Trial','CueMode','Hit','Drive','PreCueCorrelation'});
end

function [cueInputPattern, cueGain] = iDecisionCuePattern(Mouse, Params, cueMode)
switch cueMode
case "preCue"
	cueInputPattern = Mouse.PreCueInputPattern;
	cueGain = Params.CueInputGainPretrain;
case "formalCue"
	cueInputPattern = Mouse.CueInputPattern;
	cueGain = Params.CueInputGain;
case "randomCue"
	cueInputPattern = TransferLearning.THModel.ClampPattern(TransferLearning.THModel.Standardize(TransferLearning.THModel.Randn([Params.NCueInput, 1])), Params);
	cueGain = Params.CueInputGain;
case "zeroCue"
	cueInputPattern = TransferLearning.THModel.Zeros([Params.NCueInput, 1]);
	cueGain = 0;
otherwise
	error('THModel:UnknownCueMode', 'Unknown cue mode: %s.', cueMode);
end
end

function rho = iCueCorrelation(a, b)
a = TransferLearning.THModel.GatherValue(a(:));
b = TransferLearning.THModel.GatherValue(b(:));
if std(a, 0) < eps || std(b, 0) < eps
	rho = NaN;
	return;
end
rho = corr(a, b);
end