% 只看延迟范式的两组（Light water）：Naive vs 12 h 是否有差异
%
% 模型：y ~ block * group + (1|mouse)，二项 logit，Laplace
% 关注：group:block（学习速率差异）、group（起始水平差异）
% UseImaging 控制是否并入延迟成像队列（ALDelayed, 4 只；LADelayed 每只仅 1 session，无法提供速率信息）
clear variables; close all;
cd('d:\git\Transfer-Learning');
if ~exist('UniExp.DataSet', 'class')
	matlab.project.loadProject('d:\git\Transfer-Learning\Transferlearning.prj');
end
warning('off', 'UniExp:Exception:Block_must_warn');

UseImaging = false;
stim = ["LightLearnWater", "LightLearnWaterAlways"];

T = iTrials(UniExp.DataSet(TransferLearning.DelayComparison.BehaviorDataPath("L2A_L")), ...
	TransferLearning.DelayComparison.CohortBlocks("DelayedBehaviorNaive"), stim, "Naive");
T = [T; iTrials(UniExp.DataSet(TransferLearning.DelayComparison.BehaviorDataPath("A2L_L")), ...
	TransferLearning.DelayComparison.CohortBlocks("DelayedBehaviorTransfer"), stim, "12h")];
if UseImaging
	T = [T; iTrials(TransferLearning.ALDelayed(), ...
		TransferLearning.DelayComparison.CohortBlocks("DelayedTransfer"), stim, "12h")];
end
T.group = categorical(T.group, ["Naive", "12h"]);
T.mouse = categorical(T.mouse);
T.blockC = T.block - 1;

fprintf('\n=== 延迟范式：两组样本 ===\n');
[g, gp] = findgroups(string(T.group));
nm = splitapply(@(m) numel(unique(m)), T.mouse, g);
nt = splitapply(@numel, T.y, g);
for k = 1:numel(gp)
	fprintf('  %-5s %2d 只鼠 / %6d trial\n', gp{k}, nm(k), nt(k));
end

fprintf('\n=== 模型 A：y ~ block*group + (1|mouse) ===\n');
mdl = fitglme(T, 'y ~ blockC*group + (1|mouse)', 'Distribution', 'binomial', ...
	'Link', 'logit', 'FitMethod', 'Laplace');
disp(mdl);
fprintf('\n--- 固定效应 ANOVA ---\n');
disp(anova(mdl));

% 各组斜率（logit/block）与 odds 倍数
b = fixedEffects(mdl);
names = {mdl.CoefficientNames{:}};
iB = find(strcmp(names, 'blockC'), 1);
iGB = find(strcmp(names, 'blockC:group_12h'), 1);
if isempty(iGB)
	iGB = find(strcmp(names, 'group_12h:blockC'), 1);
end
slopeN = b(iB); slopeT = b(iB) + b(iGB);
fprintf('\n=== 换算 ===\n');
fprintf('  Naive 斜率 %.3f logit/block  (OR %.2f /block)\n', slopeN, exp(slopeN));
fprintf('  12 h  斜率 %.3f logit/block  (OR %.2f /block)\n', slopeT, exp(slopeT));
fprintf('  差值 %.3f logit/block\n', b(iGB));

fprintf('\n=== 模型 B：加 block^2 检验曲率 ===\n');
T.blockC2 = T.blockC .^ 2;
mdl2 = fitglme(T, 'y ~ blockC*group + blockC2*group + (1|mouse)', ...
	'Distribution', 'binomial', 'Link', 'logit', 'FitMethod', 'Laplace');
disp(mdl2);
fprintf('\n--- 模型 B 固定效应 ANOVA ---\n');
disp(anova(mdl2));

% 模型 B 下逐 block 的瞬时斜率（logit/block）
b2 = fixedEffects(mdl2);
nm2 = mdl2.CoefficientNames;
gv = @(s) iCoeff(b2, nm2, s);
b0 = gv('(Intercept)'); bG = gv('group_12h');
bB = gv('blockC'); bB2 = gv('blockC2');
bBG = gv('blockC:group_12h'); bB2G = gv('blockC2:group_12h');
fprintf('\n=== 瞬时斜率 dlogit/dblock（模型 B）===\n');
fprintf('  block   Naive    12 h\n');
for blk = 1:6
	u = blk - 1;
	sN = bB + 2 * bB2 * u;
	sT = (bB + bBG) + 2 * (bB2 + bB2G) * u;
	fprintf('  %5d  %7.3f  %7.3f\n', blk, sN, sT);
end

%% ---------------------------------------------------------------
function out = iTrials(DS, sessions, stimuli, groupLabel)
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
		repmat(string(groupLabel), sum(ok), 1), ...
		'VariableNames', {'mouse', 'block', 'y', 'group'})]; %#ok<AGROW>
end
end
