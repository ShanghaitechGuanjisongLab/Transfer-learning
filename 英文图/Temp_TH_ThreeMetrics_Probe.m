% 探针：TH 抑制组 vs 12 h 对照组，三个行为指标（first block / blocks to 50% / slope）
% 哪个指标显著？
%
% 口径与英文图/Fig4E_THInhibitVs12h_PenalizedSigmoidSlopeHistogram.m 完全一致：
%   12 h  = TransferLearning.BuildIntervalBehaviorCurves() 里 Group=="12h"
%   TH    = BuildTHInhibitTrialTable()（成像鼠）+ BuildPOBehaviorTrialTable()（纯行为鼠）
%   slope = 逐 trial 惩罚 sigmoid（FixLowerZero），ComparePenalizedSigmoidSlopes 给出
%           每鼠 Slope 与 "THInhibit - 12h" 的 Welch p（在 log k 上）
% 另外两个指标按逐鼠逐 block 命中率算（与 Metrics.PerMouseSessionSummary 同一定义）：
%   FirstPerf     = 首个 block 的命中率
%   BlocksToHalf  = 首个 >=0.5 的 block，相邻两点线性插值；始终未达到记 max(block)+1
% 检验：非配对 ranksum（与 Fig1 柱图口径一致），并额外给出 slope 的 Welch p

if ~exist('UniExp.DataSet', 'class')
	thisDir = fileparts(mfilename('fullpath'));
	prjFile = fullfile(thisDir, '..', 'Transferlearning.prj');
	if exist(prjFile, 'file')
		matlab.project.loadProject(prjFile);
	end
end
if ~any(strcmpi(strsplit(path, pathsep), 'd:\git\Transfer-Learning'))
	addpath('d:\git\Transfer-Learning');
end
warning('off', 'UniExp:Exception:Block_must_warn');

%% ---------- 试次级表 ----------
[IntervalCurves, IntervalTrials] = TransferLearning.BuildIntervalBehaviorCurves();
controlTrials = IntervalTrials(IntervalTrials.Group == "12h", :);
controlCurves = IntervalCurves(IntervalCurves.Group == "12h", :);
controlTrials = innerjoin(controlTrials, ...
	controlCurves(:, {'Group', 'Mouse', 'DateTime', 'Block'}), ...
	'Keys', {'Group', 'Mouse', 'DateTime'});
thImagingTrials = TransferLearning.BuildTHInhibitTrialTable();
thBehaviorTrials = TransferLearning.BuildPOBehaviorTrialTable();
commonVariables = {'Group', 'Mouse', 'DateTime', 'Block', 'Behavior', 'Source'};
trialTable = [controlTrials(:, commonVariables); ...
	thImagingTrials(:, commonVariables); thBehaviorTrials(:, commonVariables)];

%% ---------- slope ----------
R = TransferLearning.ComparePenalizedSigmoidSlopes(50000, trialTable, FixLowerZero = true);
PM = R.PerMouse;
okC = PM.Group == "12h" & PM.FitEligible;
okT = PM.Group == "THInhibit" & PM.FitEligible;
slopeC = PM.Slope(okC);
slopeT = PM.Slope(okT);
wRow = R.Pairwise(R.Pairwise.Comparison == "THInhibit - 12h", :);

%% ---------- first block / blocks to 50% ----------
perMouse = table(strings(0, 1), strings(0, 1), nan(0, 1), nan(0, 1), ...
	'VariableNames', {'Group', 'Mouse', 'FirstPerf', 'BlocksToHalf'});
mice = unique(string(trialTable.Mouse), 'stable');
grps = unique(string(trialTable.Group), 'stable');
for iG = 1:numel(grps)
	for iM = 1:numel(mice)
		R1 = trialTable(string(trialTable.Group) == grps(iG) & string(trialTable.Mouse) == mice(iM), :);
		if isempty(R1)
			continue;
		end
		blk = double(R1.Block);
		beh = double(R1.Behavior);
		bi = unique(blk);
		rate = arrayfun(@(b) mean(beh(blk == b), 'omitnan'), bi);
		fp = rate(1);
		half = iBlocksToHalf(bi, rate);
		perMouse = [perMouse; table(grps(iG), mice(iM), fp, half, ...
			'VariableNames', {'Group', 'Mouse', 'FirstPerf', 'BlocksToHalf'})]; %#ok<AGROW>
	end
end
fpC = perMouse.FirstPerf(perMouse.Group == "12h");
fpT = perMouse.FirstPerf(perMouse.Group == "THInhibit");
hbC = perMouse.BlocksToHalf(perMouse.Group == "12h");
hbT = perMouse.BlocksToHalf(perMouse.Group == "THInhibit");

%% ---------- 报告 ----------
fprintf('\n=== TH 抑制 vs 12 h：三个指标 ===\n');
iReport('First block   ', fpC, fpT);
iReport('Blocks to 50% ', hbC, hbT);
iReport('Slope (k)     ', slopeC, slopeT);
fprintf('Slope 额外：Welch（log k）p = %.4g\n', wRow.WelchPValue);
disp(wRow);

assignin('base', 'TH_ThreeMetrics', struct( ...
	'FirstPerf', {fpC, fpT}, 'BlocksToHalf', {hbC, hbT}, 'Slope', {slopeC, slopeT}, ...
	'PerMouse', perMouse, 'PenalizedFit', R));

%% ================= 局部函数 =================
function iReport(name, a, b)
a = double(a(:));
b = double(b(:));
a = a(isfinite(a));
b = b(isfinite(b));
[p, ~] = TransferLearning.BehaviorSessions.iRanksumSafe(a, b);
fprintf('%s 12h %.3f ± %.3f (n=%d) | TH %.3f ± %.3f (n=%d) | ranksum p = %.4g %s\n', ...
	name, mean(a), iSEM(a), numel(a), mean(b), iSEM(b), numel(b), p, iStar(p));
end

function s = iStar(p)
if ~isfinite(p)
	s = '';
elseif p < 1e-4
	s = '****';
elseif p < 1e-3
	s = '***';
elseif p < 1e-2
	s = '**';
elseif p < 0.05
	s = '*';
else
	s = 'n.s.';
end
end

function half = iBlocksToHalf(x, y)
x = double(x(:));
y = double(y(:));
use = isfinite(y);
x = x(use);
y = y(use);
if isempty(y)
	half = NaN;
	return;
end
ic = find(y >= 0.5, 1, 'first');
if isempty(ic)
	half = max(x) + 1;
elseif ic == 1
	half = x(1);
else
	half = x(ic - 1) + (0.5 - y(ic - 1)) / (y(ic) - y(ic - 1));
end
end

function s = iSEM(x)
x = double(x(:));
x = x(isfinite(x));
if isempty(x)
	s = NaN;
else
	s = std(x) / sqrt(numel(x));
end
end
