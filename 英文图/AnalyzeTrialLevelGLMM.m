% 逐 trial GLMM：hit ~ block * delay * group + (1|mouse)
%
% 四格（纯行为队列，无钙成像）：
%   undelayed Naive = LAPureBehavior      delayed Naive = L2A_L_0928
%   undelayed 12 h  = ALPureBehavior      delayed 12 h  = A2L_L_0928
% 可选：把成像鼠也并进来（UseImaging = true）
%
% 报告：各格 n 鼠 / n trial；固定效应表；固定效应 ANOVA。
clear variables; close all;
cd('d:\git\Transfer-Learning');
if ~exist('UniExp.DataSet', 'class')
	matlab.project.loadProject('d:\git\Transfer-Learning\Transferlearning.prj');
end
warning('off', 'UniExp:Exception:Block_must_warn');

UseImaging = false;

T = table();
T = [T; iTrials(TransferLearning.LAPureBehavior(), ...
	iSub(TransferLearning.DelayComparison.CohortBlocks("UndelayedImagingNaive"), "LAPureBehavior"), ...
	"LightWater", "undelayed", "Naive")];
T = [T; iTrials(TransferLearning.ALPureBehavior(), ...
	iSub(TransferLearning.DelayComparison.CohortBlocks("UndelayedImagingTransfer"), "ALPureBehavior"), ...
	"LightWater", "undelayed", "12h")];
T = [T; iTrials(UniExp.DataSet(TransferLearning.DelayComparison.BehaviorDataPath("L2A_L")), ...
	TransferLearning.DelayComparison.CohortBlocks("DelayedBehaviorNaive"), ...
	["LightLearnWater", "LightLearnWaterAlways"], "delayed", "Naive")];
T = [T; iTrials(UniExp.DataSet(TransferLearning.DelayComparison.BehaviorDataPath("A2L_L")), ...
	TransferLearning.DelayComparison.CohortBlocks("DelayedBehaviorTransfer"), ...
	["LightLearnWater", "LightLearnWaterAlways"], "delayed", "12h")];

if UseImaging
	T = [T; iTrials(TransferLearning.LightAudioBaseline(), ...
		iSub(TransferLearning.DelayComparison.CohortBlocks("UndelayedRecordingNaive"), "LightAudioBaseline"), ...
		"LightWater", "undelayed", "Naive")];
	T = [T; iTrials(TransferLearning.LAInterspersed(), ...
		iSub(TransferLearning.DelayComparison.CohortBlocks("UndelayedRecordingNaive"), "LAInterspersed"), ...
		"LightWater", "undelayed", "Naive")];
	T = [T; iTrials(TransferLearning.ALDelayed(), ...
		TransferLearning.DelayComparison.CohortBlocks("DelayedTransfer"), ...
		["LightLearnWater", "LightLearnWaterAlways"], "delayed", "12h")];
end

T.delay = categorical(T.delay, ["undelayed", "delayed"]);
T.group = categorical(T.group, ["Naive", "12h"]);
T.mouse = categorical(T.mouse);
T.blockC = T.block - 1;

fprintf('\n=== 各格样本 ===\n');
[g, dl, gp] = findgroups(string(T.delay), string(T.group));
nm = splitapply(@(m) numel(unique(m)), T.mouse, g);
nt = splitapply(@numel, T.y, g);
for k = 1:numel(dl)
	fprintf('  %-9s %-5s  %2d 只鼠 / %6d trial\n', dl{k}, gp{k}, nm(k), nt(k));
end
fprintf('  合计 %d 只鼠 / %d trial\n', numel(unique(T.mouse)), height(T));

fprintf('\n=== 拟合 GLMM（Laplace）... ===\n');
mdl = fitglme(T, 'y ~ blockC*delay*group + (1|mouse)', ...
	'Distribution', 'binomial', 'Link', 'logit', 'FitMethod', 'Laplace');
disp(mdl);
fprintf('\n=== 固定效应 ANOVA ===\n');
disp(anova(mdl));

%% ---------------------------------------------------------------
function S = iSub(T, source)
S = T(string(T.Source) == source, :);
end

function out = iTrials(DS, sessions, stimuli, delayLabel, groupLabel)
sessions = sessions(:, {'Mouse', 'DateTime', 'Performance'});
sessions.Mouse = string(sessions.Mouse);
sessions = sortrows(sessions, {'Mouse', 'DateTime'});
mice = unique(sessions.Mouse, 'stable');
out = table();
for i = 1:numel(mice)
	m = mice(i);
	dt = unique(sessions.DateTime(sessions.Mouse == m));
	Tq = DS.TableQuery(["Mouse", "DateTime", "Stimulus", "Behavior"], Mouse = m);
	if isempty(Tq), continue; end
	Tq = Tq(ismember(string(Tq.Stimulus), stimuli), :);
	if isempty(Tq), continue; end
	tqDT = Tq.DateTime;
	if ~isempty(tqDT.TimeZone), tqDT.TimeZone = ''; end
	if ~isempty(dt.TimeZone), dt.TimeZone = ''; end
	[~, loc] = ismember(tqDT, dt);
	y = double(Tq.Behavior);
	ok = isfinite(y) & loc > 0;
	if sum(ok) == 0, continue; end
	out = [out; table(repmat(m, sum(ok), 1), double(loc(ok)), y(ok), ...
		repmat(string(delayLabel), sum(ok), 1), repmat(string(groupLabel), sum(ok), 1), ...
		'VariableNames', {'mouse', 'block', 'y', 'delay', 'group'})]; %#ok<AGROW>
end
end
