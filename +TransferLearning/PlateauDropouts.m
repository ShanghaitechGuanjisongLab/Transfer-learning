function Excluded = PlateauDropouts(DS, Design, Options)
% PlateauDropouts  找出"到达平台期后又掉线"的会话，供从转移模态中剔除。
%
% 判据：某只鼠在该Design的会话中命中率首次超过 PlateauThreshold 之后，
% 若后续某会话命中率低于 DropThreshold，则该会话判为掉线。
% 典型情形：yqn2200 的光水会话 0.66 0.68 0.97 0.91 0.91 0.38，
% 最后一个会话在已到平台期后跌到 0.38，应剔除（用户 2026-10-21 指定）。

arguments
	DS
	Design (1,1) string
	Options.PlateauThreshold (1,1) double = 0.85
	Options.DropThreshold (1,1) double = 0.50
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

Excluded = NaT(0, 1);
for m = unique(sessionMouse).'
	idx = find(sessionMouse == m);
	hitRate = sessionHitRate(idx);
	plateau = find(hitRate > Options.PlateauThreshold, 1);
	if isempty(plateau)
		continue;
	end
	dropouts = plateau:numel(idx);
	dropouts = dropouts(hitRate(dropouts) < Options.DropThreshold);
	Excluded = [Excluded; sessionList(idx(dropouts))];
end
end
