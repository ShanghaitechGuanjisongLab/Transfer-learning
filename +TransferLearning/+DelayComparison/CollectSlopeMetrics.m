function M = CollectSlopeMetrics(Cohort)
%COLLECTSLOPEMETRICS Per-mouse divergence / heterogeneity joined with slope.
%   M = CollectSlopeMetrics("Undelayed") uses the original cohort
%   (LightAudioBaseline + LAInterspersed for naive, AudioLightBaseline for
%   transfer; cue + 1 s, LightWater trials).
%   M = CollectSlopeMetrics("Delayed") uses TransferLearning.ALDelayed
%   (light->water after audio learning; cue + 1.5 s, LightLearnWater trials).
%   The delayed naive cohort (LADelayed) has a single session per mouse and
%   therefore no sigmoid slope, so it cannot be part of these scatters.
%
%   M.Divergence    Mouse, Divergence, Group, Slope
%   M.Heterogeneity Mouse, Heterogeneity, NCell, Group, Layer, Slope
arguments
	Cohort (1,1) string {mustBeMember(Cohort, ["Undelayed","Delayed"])}
end

DivN = table(strings(0,1), nan(0,1), strings(0,1), 'VariableNames', {'Mouse','Divergence','Group'});
if Cohort == "Undelayed"
	TimeSec = 1;
	Stimulus = "LightWater";
	LAB = TransferLearning.LightAudioBaseline();
	LAI = TransferLearning.LAInterspersed();
	ALB = TransferLearning.AudioLightBaseline();

	SessN = TransferLearning.DelayComparison.AddBlockIndex( ...
		TransferLearning.DelayComparison.CohortBlocks("UndelayedRecordingNaive"));
	SessT = TransferLearning.DelayComparison.AddBlockIndex( ...
		TransferLearning.DelayComparison.CohortBlocks("UndelayedRecordingTransfer"));
	Fit = TransferLearning.DelayComparison.FitSigmoidPerMouse([SessN; SessT]);

	DivN = [ ...
		TransferLearning.DelayComparison.SessionDivergence(LAB, SessN(SessN.Source == "LightAudioBaseline" & SessN.Block == 1, :), Stimulus, TimeSec); ...
		TransferLearning.DelayComparison.SessionDivergence(LAI, SessN(SessN.Source == "LAInterspersed" & SessN.Block == 1, :), Stimulus, TimeSec)];
	DivN.Group(:) = "Naive";
	DivT = TransferLearning.DelayComparison.SessionDivergence(ALB, SessT(SessT.Block == 1, :), Stimulus, TimeSec);
	DivT.Group(:) = "Transfer";

	SessNc = TransferLearning.DelayComparison.ExcludeCeilingSessions(SessN);
	SessTc = TransferLearning.DelayComparison.ExcludeCeilingSessions(SessT);
	SessHet = {LAB, SessNc(SessNc.Source == "LightAudioBaseline", :), "Naive"; ...
		LAI, SessNc(SessNc.Source == "LAInterspersed", :), "Naive"; ...
		ALB, SessTc, "Transfer"};
else
	TimeSec = 1.5;
	Stimulus = "LightLearnWater";
	ALD = TransferLearning.ALDelayed();

	SessD = TransferLearning.DelayComparison.AddBlockIndex( ...
		TransferLearning.DelayComparison.CohortBlocks("DelayedTransfer"));
	Fit = TransferLearning.DelayComparison.FitSigmoidPerMouse(SessD);

	DivT = TransferLearning.DelayComparison.SessionDivergence(ALD, SessD(SessD.Block == 1, :), Stimulus, TimeSec);
	DivT.Group(:) = "Transfer";

	SessDc = TransferLearning.DelayComparison.ExcludeCeilingSessions(SessD);
	SessHet = {ALD, SessDc, "Transfer"};
end

Het = table();
for layer = ["MOp2/3", "MOp5"]
	for i = 1:size(SessHet, 1)
		H = TransferLearning.DelayComparison.SessionHeterogeneity(SessHet{i, 1}, SessHet{i, 2}, ...
			Stimulus, TimeSec, layer);
		H.Group(:) = SessHet{i, 3};
		H.Layer(:) = layer;
		Het = [Het; H]; %#ok<AGROW>
	end
end

Div = [DivN; DivT];
M.Divergence = iJoinSlope(Div, Fit, "Divergence");
M.Heterogeneity = iJoinSlope(Het, Fit, "Heterogeneity");
end

function T = iJoinSlope(T, Fit, XVar)
T.Mouse = string(T.Mouse);
[~, loc] = ismember(T.Mouse, string(Fit.Mouse));
T.Slope = nan(height(T), 1);
has = loc > 0;
T.Slope(has) = Fit.Slope(loc(has));
T = T(isfinite(double(T.(XVar))) & isfinite(T.Slope), :);
end
