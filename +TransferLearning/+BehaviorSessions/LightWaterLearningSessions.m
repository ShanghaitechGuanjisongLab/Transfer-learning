function T = LightWaterLearningSessions()
%LIGHTWATERLEARNINGSESSIONS 三组（Naive / Transfer / 7dayTransfer）的 LightWater 学习会话
%
%   T = TransferLearning.BehaviorSessions.LightWaterLearningSessions()
%
%   Naive         LightAudioBaseline(Naive→Learned) + LAInterspersed(Naive→Learned)
%                 LAInterspersed 中在 Naive 阶段混入 AudioWater 的鼠被剔除
%   Transfer      AudioLightBaseline(Transfer→Final)
%   7dayTransfer  Vacation7(Transfer→Final)
%
%   输出列：Group | Mouse | DateTime | Performance | Phase | Source | Session
%   均为成像队列、undelayed 范式，Session 为每只鼠按时间排序的会话序号。

LAB = TransferLearning.LightAudioBaseline();
LAI = TransferLearning.LAInterspersed();
ALB = TransferLearning.AudioLightBaseline();
V7 = TransferLearning.Vacation7();

badMice = string.empty(0, 1);
Tbad = LAI.TableQuery("Mouse", Stimulus="AudioWater", Phase="Naive");
if ~isempty(Tbad)
	badMice = unique(string(Tbad.Mouse));
end

naiveA = iSessions(LAB, "LightAudioBaseline", "Naive", "Learned", string.empty(0, 1), true);
naiveB = iSessions(LAI, "LAInterspersed", "Naive", "Learned", badMice, true);
naive = [naiveA; naiveB];
naive.Group(:) = "Naive";

tran = iSessions(ALB, "AudioLightBaseline", "Transfer", "Final", string.empty(0, 1));
tran.Group(:) = "Transfer";

gap = iSessions(V7, "Vacation7", "Transfer", "Final", string.empty(0, 1));
gap.Group(:) = "7dayTransfer";

T = [naive; tran; gap];
if isempty(T)
	return;
end
T.Group = string(T.Group);
T.Mouse = string(T.Mouse);
T.Source = string(T.Source);
T = sortrows(T, {'Group','Mouse','DateTime'});
[G, ~] = findgroups(T.Group, T.Mouse);
cellIdx = splitapply(@(x) {(1:numel(x))'}, T.DateTime, G);
T.Session = vertcat(cellIdx{:});
end

function S = iSessions(DS, sourceName, startPhase, endPhase, excludeMice, anyDesign)
if nargin < 6, anyDesign = false; end
Tq = TransferLearning.BehaviorSessions.iQueryLightWaterBlocks(DS, false, anyDesign);
Tq.Mouse = string(Tq.Mouse);
if ~isempty(excludeMice)
	Tq = Tq(~ismember(Tq.Mouse, string(excludeMice)), :);
end
S = TransferLearning.BehaviorSessions.iSessionizeByDateTime(Tq);
S.Phase = string(S.Phase);
S = sortrows(S, {'Mouse','DateTime'});
mice = unique(S.Mouse);
keep = false(height(S), 1);
for i = 1:numel(mice)
	idx = find(S.Mouse == mice(i));
	ph = S.Phase(idx);
	st = find(ph == string(startPhase), 1, 'first');
	if isempty(st)
		% 改 Design 口径后，LAInterspersed 的纯光水块没有 Phase 标注
		% （其 LAuWLw 混合块才有 Naive 标注）。此时退化为"该鼠最早的
		% 纯光水 session"，否则整只鼠会被丢掉（naive 组从 14 只降到 4 只）。
		st = 1;
	end
	ed = find(ph == string(endPhase) & (1:numel(ph))' >= st, 1, 'first');
	if isempty(ed)
		ed = numel(ph);
	end
	keep(idx(st:ed)) = true;
end
S = S(keep, :);
S.Source = repmat(string(sourceName), height(S), 1);
end
