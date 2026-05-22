function [perf, Signals, perfExpected, Mouse, TrialTable] = SimulateSession(Mouse, Params, Cond, usePreCue)
if ~(isfield(Params, 'NoiseFirstStateCarryover') && Params.NoiseFirstStateCarryover ~= 0)
	error('THModel:SingleTeachingEventRequiresNoiseFirst', 'Single-teaching-event branch requires NoiseFirstStateCarryover.');
end
[perf, Signals, perfExpected, Mouse, TrialTable] = TransferLearning.THModel.SimulateSessionNoiseFirstSingleTeachingEvent(Mouse, Params, Cond, usePreCue);
end