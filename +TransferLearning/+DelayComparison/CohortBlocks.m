function T = CohortBlocks(Cohort)
%COHORTBLOCKS Per-mouse per-session light-learning table for one cohort.
%   T = CohortBlocks(Cohort) returns Mouse, DateTime, Performance, Source.
%
%   Undelayed cohorts follow the session definitions of
%   English_FigS1D_UndelayedLearningCurve (imaging: LAB + LAPB + LAI for the
%   naive stage, ALB + ALPB for the transfer stage).
%   Delayed behaviour cohorts are the Fig1B_LearningCurve_Sigmoid data
%   (L2A_L_0928 for the naive stage, A2L_L_0928 for the transfer stage:
%   1 s cue with water at cue + 2.5 s).
%   Delayed imaging cohorts are LADelayed (light->water, naive) and ALDelayed
%   (light->water after audio learning, transfer). They have no Phase column,
%   so every light-learning session is kept.
%   DelayedAudioWater is the audio-water stage of the same delayed ALDelayed
%   cohort (AudioLearnWater only, AudioPreTrain excluded); it is the control
%   for the delayed audio-water learning curve.
arguments
	Cohort (1,1) string {mustBeMember(Cohort, [ ...
		"UndelayedImagingNaive", "UndelayedImagingTransfer", ...
		"UndelayedRecordingNaive", "UndelayedRecordingTransfer", ...
		"DelayedBehaviorNaive", "DelayedBehaviorTransfer", ...
		"DelayedNaive", "DelayedTransfer", "DelayedAudioWater"])}
end

switch Cohort
	case "UndelayedImagingNaive"
		LAI = TransferLearning.LAInterspersed();
		badMice = iAudioWaterMice(LAI, "Naive");
		sess = { ...
			iTag(TransferLearning.DelayComparison.LightSessionTable(TransferLearning.LightAudioBaseline(), "LightWater", "Naive", "Learned"), "LightAudioBaseline"), ...
			iTag(TransferLearning.DelayComparison.LightSessionTable(TransferLearning.LAPureBehavior(), "LightWater", "Naive", "Learned"), "LAPureBehavior"), ...
			iTag(TransferLearning.DelayComparison.LightSessionTable(LAI, "LightWater", "Naive", "Learned"), "LAInterspersed")};
		sess{3} = sess{3}(~ismember(sess{3}.Mouse, badMice), :);
		T = vertcat(sess{:});
	case "UndelayedImagingTransfer"
		sess = { ...
			iTag(TransferLearning.DelayComparison.LightSessionTable(TransferLearning.AudioLightBaseline(), "LightWater", "Transfer", "Final"), "AudioLightBaseline"), ...
			iTag(TransferLearning.DelayComparison.LightSessionTable(TransferLearning.ALPureBehavior(), "LightWater", "Transfer", "Final"), "ALPureBehavior")};
		T = vertcat(sess{:});
	case "UndelayedRecordingNaive"
		LAI = TransferLearning.LAInterspersed();
		badMice = iAudioWaterMice(LAI, "Naive");
		sess = { ...
			iTag(TransferLearning.DelayComparison.LightSessionTable(TransferLearning.LightAudioBaseline(), "LightWater", "Naive", "Learned"), "LightAudioBaseline"), ...
			iTag(TransferLearning.DelayComparison.LightSessionTable(LAI, "LightWater", "Naive", "Learned"), "LAInterspersed")};
		sess{2} = sess{2}(~ismember(sess{2}.Mouse, badMice), :);
		T = vertcat(sess{:});
	case "UndelayedRecordingTransfer"
		T = iTag(TransferLearning.DelayComparison.LightSessionTable(TransferLearning.AudioLightBaseline(), "LightWater", "Transfer", "Final"), "AudioLightBaseline");
	case "DelayedBehaviorNaive"
		DS = UniExp.DataSet(TransferLearning.DelayComparison.BehaviorDataPath("L2A_L"));
		T = iTag(TransferLearning.DelayComparison.LightSessionTable(DS, iDelayedBehaviorStimuli), "L2A_L_0928");
	case "DelayedBehaviorTransfer"
		DS = UniExp.DataSet(TransferLearning.DelayComparison.BehaviorDataPath("A2L_L"));
		T = iTag(TransferLearning.DelayComparison.LightSessionTable(DS, iDelayedBehaviorStimuli), "A2L_L_0928");
	case "DelayedNaive"
		T = iTag(TransferLearning.DelayComparison.LightSessionTable(TransferLearning.LADelayed(), iDelayedLightStimuli), "LADelayed");
	case "DelayedTransfer"
		T = iTag(TransferLearning.DelayComparison.LightSessionTable(TransferLearning.ALDelayed(), iDelayedLightStimuli), "ALDelayed");
	case "DelayedAudioWater"
		T = iTag(TransferLearning.DelayComparison.LightSessionTable(TransferLearning.ALDelayed(), iDelayedAudioStimuli), "ALDelayed");
end
T = sortrows(T, {'Mouse','DateTime'});
end

function T = iTag(T, sourceName)
T.Source = repmat(string(sourceName), height(T), 1);
T = T(:, {'Mouse','DateTime','Performance','Source'});
end

function S = iDelayedBehaviorStimuli
% The Fig1B behaviour files label the light learning trials LightLearnWater
% (contingent) and LightLearnWaterAlways (water regardless of the response);
% both belong to the light learning curve, as in Fig1B.
S = ["LightLearnWater","LightLearnWaterAlways"];
end

function S = iDelayedLightStimuli
S = ["LightLearnWater","LightLearnWaterAlways"];
end

function S = iDelayedAudioStimuli
S = ["AudioLearnWater","AudioLearnWaterAlways"];
end

function badMice = iAudioWaterMice(DS, Phase)
Ta = DS.TableQuery("Mouse", Stimulus="AudioWater", Phase=Phase);
if isempty(Ta)
	badMice = strings(1, 0);
else
	badMice = unique(string(Ta.Mouse));
end
end
