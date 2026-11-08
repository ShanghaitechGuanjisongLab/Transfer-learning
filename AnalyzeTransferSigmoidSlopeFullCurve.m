% 光水学习 sigmoid 斜率重算：保留完整学习曲线。
%
% 本脚本用于纠正早期版本错误地排除首次命中率 100% 的 block 及其后 block
% 所导致的斜率偏差。与早期版本相同：下限固定 0、上限固定 1，斜率和中点自由。
% 但本版本不再按首次 100% 截断，保留每鼠全部原始光水学习 block。
%
% 队列：Naive、12 h 和 TH 均同时纳入成像鼠及纯行为鼠；7 d 使用 Vacation7。
% TH 纯行为沿用 BuildPOBehaviorTrialTable 的逐块筛选和 Block 序号。
% cFos 抑制使用其实验数据的行为鼠；cFos 无成像数据。
%
% 斜率按每鼠命中率随会话序号拟合，至少两个 block 且命中率有变化才纳入。
% 组间差异为双侧 Mann–Whitney 秩和检验；同时报告各组均值、SEM、中位数、鼠数。
% 本脚本仅重新计算斜率，不计算响应异质性，不覆盖 LearningSpeed 的统计 CSV。
%
% 执行：保持脚本形式，在 MATLAB 编辑器中运行（F5）。

thisDir = fileparts(mfilename('fullpath'));
if ~exist('UniExp.DataSet', 'class')
	prjFile = fullfile(thisDir, '..', 'Transferlearning.prj');
	if exist(prjFile, 'file')
		matlab.project.loadProject(prjFile);
	end
end

%% 各组完整光水学习会话
S = struct();
S.Naive = TransferLearning.DelayComparison.CohortBlocks("UndelayedImagingNaive");
S.Naive.Group = repmat("Naive", height(S.Naive), 1);
S.Transfer = TransferLearning.DelayComparison.CohortBlocks("UndelayedImagingTransfer");
S.Transfer.Group = repmat("12 h", height(S.Transfer), 1);
S.Gap = iImagingTransferSessions(TransferLearning.Vacation7(), "Vacation7");
S.TH = [iImagingTransferSessions(TransferLearning.THInhibit(), "THInhibit"); iPOBehaviorSessions()];
CFos = TransferLearning.BehaviorSessions.CFosInhibitionSessions();
S.CFosControl = CFos(CFos.Group == "Control", :);
S.CFos = CFos(CFos.Group == "MOp", :);

Fit = struct();
labels = struct('Naive', "Naive", 'Transfer', "12 h", 'Gap', "7 d", 'TH', "TH", ...
	'CFosControl', "cFos control", 'CFos', "cFos");
fitFields = fieldnames(S);
Summary = table(strings(0, 1), zeros(0, 1), nan(0, 1), nan(0, 1), nan(0, 1), ...
	'VariableNames', {'Group', 'NMice', 'MeanSlope', 'SemSlope', 'MedianSlope'});
for iF = 1:numel(fitFields)
	field = fitFields{iF};
	Fit.(field) = iFitGroup(S.(field), labels.(field));
	F = Fit.(field);
	Summary = [Summary; table(labels.(field), height(F), mean(F.Slope), ...
		std(F.Slope) / sqrt(height(F)), median(F.Slope), ...
		'VariableNames', Summary.Properties.VariableNames)]; %#ok<AGROW>
end

fprintf('\n========== 修正后 sigmoid 斜率汇总（完整学习曲线，下限 0、上限 1）==========\n');
disp(Summary);

Comparisons = iCompare("12 h − Naive", Fit.Transfer, Fit.Naive, table());
Comparisons = iCompare("12 h − 7 d", Fit.Transfer, Fit.Gap, Comparisons);
Comparisons = iCompare("12 h − TH", Fit.Transfer, Fit.TH, Comparisons);
Comparisons = iCompare("12 h − cFos", Fit.Transfer, Fit.CFos, Comparisons);
Comparisons = iCompare("cFos control − cFos（实验内对照）", Fit.CFosControl, Fit.CFos, Comparisons);

fprintf('\n========== 修正后 sigmoid 斜率组间比较 ==========\n');
for i = 1:height(Comparisons)
	fprintf('%s：均值 %.4f vs %.4f，差值 %+.4f；n=%d/%d；双侧秩和检验 p=%.6g\n', ...
		Comparisons.Comparison(i), Comparisons.MeanA(i), Comparisons.MeanB(i), ...
		Comparisons.MeanDifferenceAminusB(i), Comparisons.NA(i), Comparisons.NB(i), Comparisons.PValue(i));
end

outDir = fullfile('\\Data-Server-2\个人数据', getenv('USERNAME'), char(datetime('now', 'Format', 'yyyyMM')));
if ~isfolder(outDir)
	mkdir(outDir);
end
writetable(Summary, fullfile(outDir, 'Transfer_SigmoidSlope_FullCurve_GroupSummary.csv'));
writetable(Comparisons, fullfile(outDir, 'Transfer_SigmoidSlope_FullCurve_GroupComparisons.csv'));
fprintf('已保存修正后的 sigmoid 斜率统计：%s\n', outDir);

assignin('base', 'TransferSigmoidSlopeFullCurve_Summary', Summary);
assignin('base', 'TransferSigmoidSlopeFullCurve_Comparisons', Comparisons);
assignin('base', 'TransferSigmoidSlopeFullCurve_PerMouse', Fit);

%% ========== 局部函数 ==========
function Fit = iFitGroup(Sess, label)
S = TransferLearning.DelayComparison.AddBlockIndex(Sess);
Fit = TransferLearning.DelayComparison.FitSigmoidPerMouse(S, true);
Fit.Group = repmat(string(label), height(Fit), 1);
Fit = Fit(:, {'Group', 'Mouse', 'Slope', 'Midpoint', 'RSquared'});
end

function T = iCompare(comparison, FitA, FitB, T)
x = double(FitA.Slope); y = double(FitB.Slope);
x = x(isfinite(x)); y = y(isfinite(y));
p = ranksum(x, y);
T = [T; table(comparison, numel(x), numel(y), mean(x), mean(y), mean(x) - mean(y), p, ...
	'VariableNames', {'Comparison', 'NA', 'NB', 'MeanA', 'MeanB', 'MeanDifferenceAminusB', 'PValue'})];
end

function S = iImagingTransferSessions(DS, sourceName)
S = TransferLearning.DelayComparison.LightSessionTable(DS, "LightWater", "Transfer", "Final");
S.Group = repmat("Transfer", height(S), 1);
S.Source = repmat(string(sourceName), height(S), 1);
S = S(:, {'Group', 'Mouse', 'DateTime', 'Performance', 'Source'});
end

function S = iPOBehaviorSessions()
% PO 纯行为按既有 Block 序号取每鼠逐块平均命中率；同日多个块不合并。
T = TransferLearning.BuildPOBehaviorTrialTable();
[G, mouse, dt] = findgroups(T.Mouse, T.DateTime, T.Block);
performance = splitapply(@(x) mean(double(x), 'omitnan'), T.Behavior, G);
S = table(repmat("TH", numel(performance), 1), mouse, dt, performance, ...
	repmat("POBehaviorOnly", numel(performance), 1), ...
	'VariableNames', {'Group', 'Mouse', 'DateTime', 'Performance', 'Source'});
end
