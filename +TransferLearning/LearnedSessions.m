function [Sessions, Info] = LearnedSessions(DS, Design, Options)
% LearnedSessions  找出"已学会"的会话：从首次出现连续N次命中率高于阈值的那一次起算。
%
% 命中率按会话（DateTime）计算，取该会话内指定Design的所有试次。
% 若某只鼠从未满足条件，则该鼠不返回任何会话。
% 起始点之后默认只保留命中率仍高于阈值的会话（DropBelowThreshold），
% 因此起始之后出现的掉线会话不会被算作"已学会"。
%
% 输出：
%   Sessions 已学会会话的DateTime列向量
%   Info     每只鼠一行的表：Mouse, Sessions(会话数), HitRate(命中率向量), OnsetIndex(起始会话序号)

arguments
	DS
	Design (1,1) string
	Options.Threshold (1,1) double = 0.80
	Options.Consecutive (1,1) double = 2
	Options.DropBelowThreshold (1,1) logical = true
end

Timing = TransferLearning.BuildTrialTiming(DS);
selected = Timing.Design == Design;
sessionList = sort(unique(Timing.DateTime(selected)));
nSession = numel(sessionList);

sessionMouse = strings(nSession, 1);
sessionHitRate = nan(nSession, 1);
for iSession = 1:nSession
	rows = selected & Timing.DateTime == sessionList(iSession);
	sessionHitRate(iSession) = mean(Timing.Outcome(rows) == "命中", 'omitnan');
	sessionMouse(iSession) = string(Timing.Mouse(find(rows, 1)));
end

Sessions = NaT(0, 1);
Mouse = strings(0, 1);
NSession = zeros(0, 1);
HitRate = {};
OnsetIndex = zeros(0, 1);
for m = unique(sessionMouse).'
	idx = find(sessionMouse == m);
	hitRate = sessionHitRate(idx);
	onsets = hitRate(1:end-1) > Options.Threshold & hitRate(2:end) > Options.Threshold;
	first = find(onsets, 1);
	if isempty(first)
		continue;
	end
	learned = first:numel(idx);
	if Options.DropBelowThreshold
		learned = learned(hitRate(learned) > Options.Threshold);
	end
	if isempty(learned)
		continue;
	end
	Sessions = [Sessions; sessionList(idx(learned))];
	Mouse = [Mouse; m];
	NSession = [NSession; numel(learned)];
	HitRate = [HitRate; {hitRate(:).'}];
	OnsetIndex = [OnsetIndex; first];
end
Info = table(Mouse, NSession, HitRate, OnsetIndex);
end
