function [Mouse, Result] = SimulatePretraining(Mouse, Params, Cond, numSessions)
if nargin < 3 || isempty(Cond)
	Cond.RewardInputLevel = 1.00;
end
if nargin < 4 || isempty(numSessions)
	numSessions = Params.MaxPretrainSessions;
end

perf = nan(1, numSessions);
firstPerfectSession = NaN;
lastPerf = NaN;

for iSession = 1:numSessions
	[perf(iSession), ~, ~, Mouse] = TransferLearning.THModel.SimulateSession(Mouse, Params, Cond, true);
	lastPerf = perf(iSession);
	if perf(iSession) >= Params.Ceiling
		firstPerfectSession = iSession;
		perf(iSession) = Params.Ceiling;
		if iSession < numSessions
			perf(iSession + 1:end) = Params.Ceiling;
		end
		break;
	end
end

reached = isfinite(firstPerfectSession);
if reached
	trainingSessions = firstPerfectSession;
	finalHit = Params.Ceiling;
else
	trainingSessions = numSessions;
	finalHit = lastPerf;
end

Result.Performance = perf;
Result.Reached = reached;
Result.TrainingSessions = trainingSessions;
Result.FirstPerfectSession = firstPerfectSession;
Result.FinalHit = finalHit;
end
