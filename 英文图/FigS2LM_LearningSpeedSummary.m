% FigS2LM_LearningSpeedSummary：四个组的学习速度（sigmoid slope）汇总。
%
% 组别（与 FigS2L / FigS2M 完全同源）：
% - Naive   undelayed：FigS1D 口径（LightAudioBaseline + LAPureBehavior + LAInterspersed）
% - Naive   delayed  ：Fig1B 的 LA Light（L2A_L_0928.mat）
% - Transfer undelayed：FigS1D 口径（AudioLightBaseline + ALPureBehavior）
% - Transfer delayed ：Fig1B 的 AL Light（A2L_L_0928.mat）
%
% 学习速度定义（每只鼠一个值）：
%   对该鼠的 block 序号 x（每鼠按 DateTime 排序）与命中率 y 拟合
%       y = (1) / (1 + exp(-slope * (x - midpoint)))
%   下渐近线固定 0、上渐近线固定 1，slope / midpoint 自由（fminsearch，初值同
%   Fig1B_LearningCurve_Sigmoid）；slope 即学习速度（单位 1/block）。
%   拟合要求：≥2 个 block 且命中率不是常数，否则该鼠不纳入。
%   组统计：均值±SEM、中位数[Q1, Q3]；组间比较用 Mann-Whitney U（ranksum，双侧）。
%
% 注：组水平拟合曲线（画在 FigS2L / FigS2M 上）同样是下渐近线固定 0、上渐近线固定 1，
% 因此本表与图上曲线的 slope 使用同一拟合规格，只是数据聚合层级不同（每鼠 vs 全体）。
%
% 执行方式（硬性要求）：本文件保持为脚本，在 MATLAB Editor 中直接 Run/F5。

% --- 0) Ensure project loaded
if ~exist('TransferLearning', 'class') || ~exist('UniExp.DataSet', 'class')
	thisFile = mfilename('fullpath');
	thisDir = fileparts(thisFile);
	prjFile = fullfile(thisDir, '..', 'Transferlearning.prj');
	if exist(prjFile, 'file')
		matlab.project.loadProject(prjFile);
	end
end

%% 1) 四组每鼠 slope
specs = { ...
	"Naive",    "Undelayed", "UndelayedImagingNaive"; ...
	"Naive",    "Delayed",   "DelayedBehaviorNaive"; ...
	"Transfer", "Undelayed", "UndelayedImagingTransfer"; ...
	"Transfer", "Delayed",   "DelayedBehaviorTransfer"};

Rows = table();
Slopes = cell(4, 1);
LowFitMice = strings(4, 1);
for i = 1:size(specs, 1)
	T = TransferLearning.DelayComparison.AddBlockIndex( ...
		TransferLearning.DelayComparison.CohortBlocks(specs{i, 3}));
	Fit = TransferLearning.DelayComparison.FitSigmoidPerMouse(T, true);
	s = double(Fit.Slope);
	Slopes{i} = s;
	% R² < 0.05 表示命中率随 block 非单调（如先升高后回落），sigmoid 无法描述该鼠的曲线
	lowFit = double(Fit.RSquared) < 0.05;
	LowFitMice(i) = strjoin(string(Fit.Mouse(lowFit))', ',');
	Rows = [Rows; table(specs{i,1}, specs{i,2}, numel(unique(T.Mouse)), numel(s), ...
		mean(s), std(s) / sqrt(numel(s)), median(s), ...
		quantile(s, 0.25), quantile(s, 0.75), nnz(lowFit), ...
		'VariableNames', {'Stage','Delay','NMiceTotal','NMiceFit','MeanSlope','SemSlope', ...
		'MedianSlope','Q1','Q3','NLowFit'})]; %#ok<AGROW>
end

fprintf('\n=== 学习速度（每鼠 sigmoid slope，1/block；lower=0, upper=1）===\n');
disp(Rows);
for i = 1:numel(LowFitMice)
	if LowFitMice(i) ~= ""
		fprintf('R² < 0.05（曲线非单调、sigmoid 无法描述）: %s — %s\n', specs{i,1} + " " + specs{i,2}, LowFitMice(i));
	end
end

%% 2) 组间比较（Mann-Whitney U）
pNaive = ranksum(Slopes{1}, Slopes{2});
pTransfer = ranksum(Slopes{3}, Slopes{4});
pUndelayed = ranksum(Slopes{1}, Slopes{3});
pDelayed = ranksum(Slopes{2}, Slopes{4});
fprintf('Naive    undelayed vs delayed  : p = %.4g\n', pNaive);
fprintf('Transfer undelayed vs delayed  : p = %.4g\n', pTransfer);
fprintf('Undelayed naive vs transfer    : p = %.4g\n', pUndelayed);
fprintf('Delayed   naive vs transfer    : p = %.4g\n', pDelayed);

% --- 3) 图上组水平拟合曲线的 slope（与 FigS2L / FigS2M 同一规格：lower=0, upper=1）
FitNU = TransferLearning.DelayComparison.FitSigmoidGroup( ...
	TransferLearning.DelayComparison.AddBlockIndex(TransferLearning.DelayComparison.CohortBlocks("UndelayedImagingNaive")), "NaiveUndelayed", true);
FitND = TransferLearning.DelayComparison.FitSigmoidGroup( ...
	TransferLearning.DelayComparison.AddBlockIndex(TransferLearning.DelayComparison.CohortBlocks("DelayedBehaviorNaive")), "NaiveDelayed", true);
FitTU = TransferLearning.DelayComparison.FitSigmoidGroup( ...
	TransferLearning.DelayComparison.AddBlockIndex(TransferLearning.DelayComparison.CohortBlocks("UndelayedImagingTransfer")), "TransferUndelayed", true);
FitTD = TransferLearning.DelayComparison.FitSigmoidGroup( ...
	TransferLearning.DelayComparison.AddBlockIndex(TransferLearning.DelayComparison.CohortBlocks("DelayedBehaviorTransfer")), "TransferDelayed", true);
fprintf('\n=== 图上组水平曲线 slope（FigS2L / FigS2M 绘制值）===\n');
fprintf('Naive    undelayed=%.4f  delayed=%.4f\n', FitNU.Slope, FitND.Slope);
fprintf('Transfer undelayed=%.4f  delayed=%.4f\n', FitTU.Slope, FitTD.Slope);

Rows.GroupSlope = [FitNU.Slope; FitND.Slope; FitTU.Slope; FitTD.Slope];
Rows.GroupSlopeSpec = repmat("lower=0, upper=1", 4, 1);

%% 4) 导出
Cmp = table(["Naive-undelayed vs Naive-delayed"; "Transfer-undelayed vs Transfer-delayed"; ...
	"Undelayed-naive vs Undelayed-transfer"; "Delayed-naive vs Delayed-transfer"], ...
	[pNaive; pTransfer; pUndelayed; pDelayed], 'VariableNames', {'Comparison','PValue'});
disp(Cmp);

outDir = fullfile('\\Data-Server-2\个人数据', getenv('USERNAME'), char(datetime('now', 'Format', 'yyyyMM')));
if ~isfolder(outDir)
	mkdir(outDir);
end
writetable(Rows, fullfile(outDir, 'English_FigS2LM_LearningSpeed_Summary.csv'));
writetable(Cmp, fullfile(outDir, 'English_FigS2LM_LearningSpeed_Tests.csv'));
fprintf('Wrote: %s\n', fullfile(outDir, 'English_FigS2LM_LearningSpeed_Summary.csv'));

assignin('base', 'FigS2LM_LearningSpeed', Rows);
assignin('base', 'FigS2LM_LearningSpeedTests', Cmp);
assignin('base', 'FigS2LM_PerMouseSlopes', Slopes);
