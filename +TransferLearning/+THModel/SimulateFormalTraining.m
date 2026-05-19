function [Result, Mouse, State] = SimulateFormalTraining(Mouse, Params, Cond, numSessions, InitialState)
if nargin < 4 || isempty(numSessions)
	numSessions = Params.NumSessions;
end
if nargin < 5
	InitialState = [];
end

perf = nan(1, numSessions);
h23 = nan(1, numSessions);
h5 = nan(1, numSessions);
sessionMeanL23 = nan(Params.NL23, numSessions);
sessionMeanL5 = nan(Params.NL5, numSessions);
sessionMeanL5RewardRecv = nan(Params.NL5RewardRecv, numSessions);
sessionMeanL5Read = nan(Params.NL5Read, numSessions);
firstPerfectSession = NaN;
lastSignals = [];
completedSessions = 0;

if ~isempty(InitialState)
	completedSessions = InitialState.CompletedSessions;
	perf(1:completedSessions) = InitialState.Performance(1:completedSessions);
	h23(1:completedSessions) = InitialState.H23(1:completedSessions);
	h5(1:completedSessions) = InitialState.H5(1:completedSessions);
	sessionMeanL23(:, 1:completedSessions) = InitialState.SessionMeanL23(:, 1:completedSessions);
	sessionMeanL5(:, 1:completedSessions) = InitialState.SessionMeanL5(:, 1:completedSessions);
	sessionMeanL5RewardRecv(:, 1:completedSessions) = InitialState.SessionMeanL5RewardRecv(:, 1:completedSessions);
	sessionMeanL5Read(:, 1:completedSessions) = InitialState.SessionMeanL5Read(:, 1:completedSessions);
	firstPerfectSession = InitialState.FirstPerfectSession;
	lastSignals = InitialState.LastSignals;
end

for iSession = completedSessions + 1:numSessions
	if isfinite(firstPerfectSession)
		perf(iSession) = Params.Ceiling;
		sessionMeanL23(:, iSession) = lastSignals.ProcessMeanL23;
		sessionMeanL5(:, iSession) = lastSignals.ProcessMeanL5;
		sessionMeanL5RewardRecv(:, iSession) = lastSignals.ProcessMeanL5RewardRecv;
		sessionMeanL5Read(:, iSession) = lastSignals.ProcessMeanL5Read;
		h23(iSession) = h23(iSession - 1);
		h5(iSession) = h5(iSession - 1);
		continue;
	end

	[perf(iSession), Signals, ~, Mouse] = TransferLearning.THModel.SimulateSession(Mouse, Params, Cond, false);
	lastSignals = Signals;
	sessionMeanL23(:, iSession) = Signals.ProcessMeanL23;
	sessionMeanL5(:, iSession) = Signals.ProcessMeanL5;
	sessionMeanL5RewardRecv(:, iSession) = Signals.ProcessMeanL5RewardRecv;
	sessionMeanL5Read(:, iSession) = Signals.ProcessMeanL5Read;
	h23(iSession) = iRestrictedStd(mean(sessionMeanL23(:, 1:iSession), 2, 'omitnan'));
	h5(iSession) = iRestrictedStd(mean(sessionMeanL5(:, 1:iSession), 2, 'omitnan'));

	if perf(iSession) >= Params.Ceiling
		firstPerfectSession = iSession;
		perf(iSession) = Params.Ceiling;
	end
end

if isempty(lastSignals)
	error('THModel:NoFormalSessionSimulated', 'At least one formal session must be simulated before stopping.');
end

if isnan(firstPerfectSession)
	useIdx = 1:numSessions;
elseif firstPerfectSession == 1
	useIdx = [];
else
	useIdx = 1:firstPerfectSession - 1;
end

finalMeanL23 = mean(sessionMeanL23, 2, 'omitnan');
finalMeanL5 = mean(sessionMeanL5, 2, 'omitnan');
finalMeanL5RewardRecv = mean(sessionMeanL5RewardRecv, 2, 'omitnan');
finalMeanL5Read = mean(sessionMeanL5Read, 2, 'omitnan');

if numel(useIdx) >= 2
	fitX = (1:numel(useIdx))';
	fitY = perf(useIdx)';
	fitP = polyfit(fitX, fitY, 1);
	resultSlope = fitP(1);
	resultDeltaHit = mean(diff(fitY), 'omitnan');
else
	resultSlope = NaN;
	resultDeltaHit = NaN;
end

Result.Performance = perf;
Result.H23 = h23;
Result.H5 = h5;
Result.Slope = resultSlope;
Result.MeanDeltaHit = resultDeltaHit;
Result.MeanH23 = iRestrictedStd(finalMeanL23);
Result.MeanH5 = iRestrictedStd(finalMeanL5);
Result.MeanH5RewardRecv = iRestrictedStd(finalMeanL5RewardRecv);
Result.MeanH5Read = iRestrictedStd(finalMeanL5Read);
Result.ProcessMeanL5 = finalMeanL5;
Result.ProcessMeanL5RewardRecv = finalMeanL5RewardRecv;
Result.ProcessMeanL5Read = finalMeanL5Read;
Result.FirstPerfectSession = firstPerfectSession;
State.Performance = perf;
State.H23 = h23;
State.H5 = h5;
State.SessionMeanL23 = sessionMeanL23;
State.SessionMeanL5 = sessionMeanL5;
State.SessionMeanL5RewardRecv = sessionMeanL5RewardRecv;
State.SessionMeanL5Read = sessionMeanL5Read;
State.FirstPerfectSession = firstPerfectSession;
State.LastSignals = lastSignals;
State.CompletedSessions = numSessions;
end

function value = iRestrictedStd(values)
values = values(isfinite(values) & values >= -1 & values <= 1);
if numel(values) < 3
	values = values(isfinite(values));
end
if numel(values) < 3
	value = NaN;
else
	value = std(values, 0, 'omitnan');
end
end
