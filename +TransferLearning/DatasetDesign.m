function [PerMouse, StimCounts, DesignLines] = DatasetDesign(DS, probeStimuli)
%DATASETDESIGN 汇总一个数据集中每只鼠的训练阶段序列
%
% 以会话（DateTime）为单位判定该会话的性质：
%   - 只出现探测性刺激（AudioOnly/LightOnly/WaterOnly，每种约 10 试次）→ Probe
%   - 某一训练刺激占绝对多数（≥ 次多数两倍）→ 该刺激
%   - 两个训练刺激试次数相当 → "A+B"（穿插设计）
% 按时间顺序把连续相同性质合并为一个阶段；相同刺激若再次出现
% （末尾 Recall 或交替设计）视为新阶段。阶段若以 Recall 为主会标注 [Recall]。
%
% 输出
%   PerMouse    : Mouse | Design | StageKey | NSessions | NStages | Stages | Counts | Phases
%   StimCounts  : Stimulus | Blocks | Mice     （Blocks = 该刺激 ≥15 试次的 (会话×刺激) 数）
%   DesignLines : "阶段序列  (n 只)"，按鼠数降序，同序列的计数取 min–max

arguments
	DS
	probeStimuli (1,:) string = ["AudioOnly", "LightOnly", "WaterOnly"]
end

% 延迟任务的数据集没有 Phase 列
try
	T = DS.TableQuery(["Mouse", "DateTime", "Stimulus", "Phase"]);
	T.Phase = string(T.Phase);
catch
	T = DS.TableQuery(["Mouse", "DateTime", "Stimulus"]);
	T.Phase = repmat(missing, height(T), 1);
end
T.Mouse = string(T.Mouse);
T.Stimulus = string(T.Stimulus);
T = T(~ismissing(T.Stimulus) & ~ismember(T.Stimulus, ["StartMonitor", "StopMonitor"]), :);
if isempty(T)
	PerMouse = table(strings(0, 1), strings(0, 1), strings(0, 1), zeros(0, 1), zeros(0, 1), ...
		{cell(0, 1)}, {cell(0, 1)}, {cell(0, 1)}, ...
		'VariableNames', {'Mouse', 'Design', 'StageKey', 'NSessions', 'NStages', 'Stages', 'Counts', 'Phases'});
	StimCounts = table(strings(0, 1), zeros(0, 1), zeros(0, 1), ...
		'VariableNames', {'Stimulus', 'Blocks', 'Mice'});
	DesignLines = strings(0, 1);
	return;
end

[G, mouseKey, dtKey] = findgroups(T.Mouse, T.DateTime);
nSess = numel(mouseKey);
kind = strings(nSess, 1);
phase = strings(nSess, 1);
for i = 1:nSess
	sub = T(G == i, :);
	u = unique(sub.Stimulus);
	counts = zeros(numel(u), 1);
	for k = 1:numel(u)
		counts(k) = sum(sub.Stimulus == u(k));
	end
	keep = ~ismember(u, probeStimuli) & counts >= 15;
	if ~any(keep)
		kind(i) = "Probe";
	else
		tu = u(keep);
		tc = counts(keep);
		[~, ord] = sort(tc, 'descend');
		tu = tu(ord);
		tc = tc(ord);
		if numel(tc) > 1 && tc(1) < 2 * tc(2)
			kind(i) = strjoin(tu(tc >= 0.5 * tc(1)), '+');
		else
			kind(i) = tu(1);
		end
	end
	phase(i) = iModeString(sub.Phase);
end
B = table(mouseKey, dtKey, kind, phase, 'VariableNames', {'Mouse', 'DateTime', 'Kind', 'Phase'});
B = sortrows(B, {'Mouse', 'DateTime'});

mice = unique(B.Mouse);
design = strings(numel(mice), 1);
stageKey = strings(numel(mice), 1);
nSessions = zeros(numel(mice), 1);
nStages = zeros(numel(mice), 1);
stageCell = cell(numel(mice), 1);
countCell = cell(numel(mice), 1);
phaseCell = cell(numel(mice), 1);
for i = 1:numel(mice)
	rows = B.Mouse == mice(i);
	sek = B.Kind(rows);
	sph = B.Phase(rows);
	sdt = B.DateTime(rows);
	[stages, counts, phases, starts] = iCollapse(sek, sph, sdt);
	labels = strings(numel(stages), 1);
	for k = 1:numel(stages)
		labels(k) = sprintf('%s(%d)', stages(k), counts(k));
		if ismember(phases(k), ["Recall", "Review"])
			labels(k) = labels(k) + "[" + phases(k) + "]";
		end
	end
	sep = repmat(" → ", 1, max(numel(labels) - 1, 0));
	for k = 2:numel(labels)
		gapDays = days(sdt(starts(k)) - sdt(starts(k) - 1));
		if gapDays >= 5
			sep(k - 1) = sprintf(' → 〔%.1f d〕→ ', gapDays);
		end
	end
	d = labels(1);
	for k = 2:numel(labels)
		d = d + sep(k - 1) + labels(k);
	end
	design(i) = d;
	stageKey(i) = strjoin(stages, '>');
	nSessions(i) = sum(rows);
	nStages(i) = numel(stages);
	stageCell{i} = stages;
	countCell{i} = counts;
	phaseCell{i} = phases;
end
PerMouse = table(mice, design, stageKey, nSessions, nStages, stageCell, countCell, phaseCell, ...
	'VariableNames', {'Mouse', 'Design', 'StageKey', 'NSessions', 'NStages', 'Stages', 'Counts', 'Phases'});

[~, ~, grp] = unique(stageKey);
nPerKey = accumarray(grp, 1);
order = sortrows([nPerKey, (1:numel(nPerKey))'], [-1 2]);
DesignLines = strings(numel(nPerKey), 1);
for j = 1:numel(nPerKey)
	kk = order(j, 2);
	sel = find(grp == kk);
	stages = stageCell{sel(1)};
	parts = strings(numel(stages), 1);
	for k = 1:numel(stages)
		vals = cellfun(@(c) c(k), countCell(sel));
		if min(vals) == max(vals)
			parts(k) = sprintf('%s(%d)', stages(k), min(vals));
		else
			parts(k) = sprintf('%s(%d-%d)', stages(k), min(vals), max(vals));
		end
		nMarked = sum(cellfun(@(c) ismember(c(k), ["Recall", "Review"]), phaseCell(sel)));
		if nMarked >= numel(sel) / 2
			vals2 = string(cellfun(@(c) c(k), phaseCell(sel), 'UniformOutput', false));
			u2 = unique(vals2);
			cnt2 = arrayfun(@(x) sum(vals2 == x), u2);
			[~, ix2] = max(cnt2);
			parts(k) = parts(k) + "[" + u2(ix2) + "]";
		end
	end
	DesignLines(kk) = sprintf('%s  (%d 只)', strjoin(parts, ' → '), order(j, 1));
end
DesignLines = DesignLines(order(:, 2));

% 各刺激的 block 数：(会话 × 刺激) 且该刺激试次数 ≥ 15
[GB, mKey3, ~, sKey3] = findgroups(T.Mouse, T.DateTime, T.Stimulus);
nTrials = splitapply(@numel, T.Stimulus, GB);
stimuli = unique(sKey3);
blocks = zeros(numel(stimuli), 1);
nMice = zeros(numel(stimuli), 1);
for k = 1:numel(stimuli)
	selB = sKey3 == stimuli(k) & nTrials >= 15;
	blocks(k) = sum(selB);
	nMice(k) = numel(unique(mKey3(selB)));
end
StimCounts = table(stimuli, blocks, nMice, 'VariableNames', {'Stimulus', 'Blocks', 'Mice'});
end

function s = iModeString(x)
x = string(x);
x = x(~ismissing(x));
if isempty(x)
	s = missing;
	return;
end
u = unique(x);
counts = zeros(numel(u), 1);
for k = 1:numel(u)
	counts(k) = sum(x == u(k));
end
[~, ix] = max(counts);
s = u(ix);
end

function [stages, counts, phases, starts] = iCollapse(s, ph, dt)
stages = s(1);
counts = 1;
for k = 2:numel(s)
	sameStage = s(k) == stages(end) && days(dt(k) - dt(k - 1)) < 5;
	if sameStage
		counts(end) = counts(end) + 1;
	else
		stages(end + 1, 1) = s(k);
		counts(end + 1, 1) = 1;
	end
end
phases = strings(numel(stages), 1);
starts = cumsum([1; counts(1:end - 1)]);
for k = 1:numel(stages)
	phases(k) = iModeString(ph(starts(k):starts(k) + counts(k) - 1));
end
end
