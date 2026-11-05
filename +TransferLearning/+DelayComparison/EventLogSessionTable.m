function T = EventLogSessionTable(DS, Stimuli)
%EVENTLOGSESSIONTABLE Per-session hit rate for behaviour-only LearnWater data.
%   Behaviour-only datasets (delay thalamus 行为.mat) store the trial outcome
%   only in Blocks.EventLog ("命中"/"错失"); their Trials table has no
%   Behavior column, so LightSessionTable cannot be used. This function pairs
%   every Trials row with its outcome event the same way
%   TransferLearning.BuildTrialTiming does, keeps the trials whose Stimulus is
%   in Stimuli, and averages them per session (DateTime).
%
%   T = EventLogSessionTable(DS, Stimuli) returns Mouse, DateTime,
%   Performance, NTrial, sorted by Mouse and DateTime.
arguments
	DS
	Stimuli (1,:) string
end

Outcome = iTrialOutcome(DS);

[~, locBlock] = ismember(DS.Trials.BlockUID, DS.Blocks.BlockUID);
[blockMouse, blockDateTime] = iBlockIdentity(DS);
mouse = blockMouse(locBlock);
dateTime = blockDateTime(locBlock);

selected = ismember(string(DS.Trials.Stimulus), Stimuli);
if ~any(selected)
	T = table(strings(0, 1), NaT(0, 1), nan(0, 1), zeros(0, 1), ...
		'VariableNames', {'Mouse','DateTime','Performance','NTrial'});
	return;
end

[G, mouseList, dtList] = findgroups(mouse(selected), dateTime(selected));
perf = splitapply(@(x) mean(x == "命中"), Outcome(selected), G);
nTrial = splitapply(@numel, Outcome(selected), G);

T = table(mouseList, dtList, perf, nTrial, ...
	'VariableNames', {'Mouse','DateTime','Performance','NTrial'});
T = sortrows(T, {'Mouse','DateTime'});
end

function Outcome = iTrialOutcome(DS)
% Each trial's outcome is the first 命中/错失 event between its own
% 回合开始 and the next one; the window mirrors BuildTrialTiming.
Outcome = strings(height(DS.Trials), 1);
trialStart = seconds(DS.Trials.Time);
outcomeEvents = ["命中", "错失"];
for iBlock = 1:height(DS.Blocks)
	E = DS.Blocks.EventLog{iBlock};
	rows = find(DS.Trials.BlockUID == DS.Blocks.BlockUID(iBlock));
	if isempty(rows) || isempty(E) || ~istimetable(E)
		continue;
	end
	eventTime = seconds(E.Time);
	eventName = string(E.Event);
	for j = 1:numel(rows)
		lo = trialStart(rows(j)) - 0.01;
		if j < numel(rows)
			hi = trialStart(rows(j + 1)) - 0.01;
		else
			hi = inf;
		end
		inWindow = eventTime >= lo & eventTime < hi;
		nameInWindow = eventName(inWindow);
		k = find(ismember(nameInWindow, outcomeEvents), 1);
		if ~isempty(k)
			Outcome(rows(j)) = nameInWindow(k);
		end
	end
end
end

function [Mouse, DateTime] = iBlockIdentity(DS)
% Blocks.DateTime may carry a time zone that DateTimes.DateTime does not, so
% strip zones before matching (same handling as BuildTrialTiming).
blockDateTime = DS.Blocks.DateTime;
dateTimeDateTime = DS.DateTimes.DateTime;
if ~isempty(blockDateTime.TimeZone)
	blockDateTime.TimeZone = '';
end
if ~isempty(dateTimeDateTime.TimeZone)
	dateTimeDateTime.TimeZone = '';
end
[matchDT, locDT] = ismember(blockDateTime, dateTimeDateTime);
DateTime = NaT(height(DS.Blocks), 1);
DateTime(matchDT) = dateTimeDateTime(locDT(matchDT));
Mouse = strings(height(DS.Blocks), 1);
if ismember('Mouse', string(DS.DateTimes.Properties.VariableNames))
	Mouse(matchDT) = string(DS.DateTimes.Mouse(locDT(matchDT)));
end
end
