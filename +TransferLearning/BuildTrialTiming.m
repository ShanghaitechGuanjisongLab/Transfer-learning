function T = BuildTrialTiming(DS)
% BuildTrialTiming  从各Block的EventLog中解析每回合的高精度时序。
%
% EventLog为timetable，记录"回合开始/声音响/声音停/灯光亮/灯光灭/命中/错失/给水"
% 的绝对时刻(Block时钟)。Trials.Time对应"回合开始"。本函数把每回合只出现一次的
% 线索时刻与结果时刻配到对应回合上，供后续按运动起始(movement onset)对齐使用。
%
% 输出表每行对应DS.Trials的一行，列：
%   TrialUID, BlockUID, DateTime, Mouse, Phase, Design, Stimulus, Behavior,
%   TrialStart, CueTime, CueKind, OutcomeTime, Outcome, RT
% 其中TrialStart/CueTime/OutcomeTime均为Block时钟下的秒数；RT为秒。

nTrial = height(DS.Trials);
TrialStart = seconds(DS.Trials.Time);
CueTime = nan(nTrial, 1);
OutcomeTime = nan(nTrial, 1);
CueKind = strings(nTrial, 1);
Outcome = strings(nTrial, 1);

CueEvents = ["声音响", "灯光亮"];
OutcomeEvents = ["命中", "错失"];

for iBlock = 1:height(DS.Blocks)
	E = DS.Blocks.EventLog{iBlock};
	rows = find(DS.Trials.BlockUID == DS.Blocks.BlockUID(iBlock));
	if isempty(rows) || isempty(E) || ~istimetable(E)
		continue;
	end
	eventTime = seconds(E.Time);
	eventName = string(E.Event);
	for j = 1:numel(rows)
		% 回合的结束边界取下一个回合的"回合开始"，避免把下一回合的事件算进来
		lo = TrialStart(rows(j)) - 0.01;
		if j < numel(rows)
			hi = TrialStart(rows(j + 1)) - 0.01;
		else
			hi = inf;
		end
		inWindow = eventTime >= lo & eventTime < hi;
		windowTime = eventTime(inWindow);
		windowName = eventName(inWindow);
		k = find(ismember(windowName, CueEvents), 1);
		if ~isempty(k)
			CueTime(rows(j)) = windowTime(k);
			CueKind(rows(j)) = windowName(k);
		end
		k = find(ismember(windowName, OutcomeEvents), 1);
		if ~isempty(k)
			OutcomeTime(rows(j)) = windowTime(k);
			Outcome(rows(j)) = windowName(k);
		end
	end
end

% 部分数据源的Blocks.DateTime带时区、DateTimes.DateTime不带，需先去时区再比对
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
Mouse = strings(height(DS.Blocks), 1);
Phase = strings(height(DS.Blocks), 1);
DateTime(matchDT) = dateTimeDateTime(locDT(matchDT));
Mouse(matchDT) = string(DS.DateTimes.Mouse(locDT(matchDT)));
if ismember('Phase', string(DS.DateTimes.Properties.VariableNames))
	Phase(matchDT) = string(DS.DateTimes.Phase(locDT(matchDT)));
end

[~, locBlock] = ismember(DS.Trials.BlockUID, DS.Blocks.BlockUID);

T = table( ...
	DS.Trials.TrialUID, ...
	DS.Trials.BlockUID, ...
	DateTime(locBlock), ...
	Mouse(locBlock), ...
	Phase(locBlock), ...
	string(DS.Blocks.Design(locBlock)), ...
	string(DS.Trials.Stimulus), ...
	DS.Trials.Behavior, ...
	TrialStart, ...
	CueTime, ...
	CueKind, ...
	OutcomeTime, ...
	Outcome, ...
	OutcomeTime - CueTime, ...
	'VariableNames', {'TrialUID', 'BlockUID', 'DateTime', 'Mouse', 'Phase', 'Design', ...
	'Stimulus', 'Behavior', 'TrialStart', 'CueTime', 'CueKind', 'OutcomeTime', 'Outcome', 'RT'});
end
