% 三种光水学习速度、响应异质性及置换检验统一统计。
%
% 队列：Naive = LAB + LAPureBehavior + LAI；12 h = ALB + ALPureBehavior；
% 7 d = Vacation7；TH = THInhibit + PO 纯行为；cFos 使用其行为数据。
% 行为分析保留完整原始学习曲线；响应异质性只用成像鼠。
%
% 学习速度指标：
% 1. BlocksTo50：达到 50% 命中率的 block，使用相邻 block 线性插值。
% 2. Sigmoid slope：下限固定 0、上限固定 1，斜率和中点自由。
% 3. LearningSpeed：Σ(后续命中率−首 block 命中率)/Σ(1−各 block 命中率)。
%    每组比较取两组最大 block 数，向右补为该鼠历史最高命中率。
%
% 组间差异：双侧 Mann–Whitney 秩和检验。
% sigmoid 斜率额外进行双侧标签置换检验：逐鼠独立拟合，置换标签不会改变任何
% 一只鼠的曲线，故置换逐鼠斜率标签与置换后重新拟合在数学上完全等价。
% 可枚举时精确枚举全部标签分配，否则 5000 次。
% 相关：各成像组学习速度与响应异质性的 Spearman，分层及两层合并。
% 异质性组间：12 h 分别与 Naive、7 d、TH 比较，分层及两层合并。
%
% 输出：MATLAB 统计 CSV 和 Markdown 报告。保持脚本形式，在编辑器中运行（F5）。

thisDir = fileparts(mfilename('fullpath'));
if ~exist('UniExp.DataSet', 'class')
	prjFile = fullfile(thisDir, '..', 'Transferlearning.prj');
	if exist(prjFile, 'file')
		matlab.project.loadProject(prjFile);
	end
end

outDir = fullfile('\\Data-Server-2\个人数据', getenv('USERNAME'), char(datetime('now', 'Format', 'yyyyMM')));
if ~isfolder(outDir)
	mkdir(outDir);
end

%% 1. 完整行为队列
S = struct();
S.Naive = TransferLearning.DelayComparison.CohortBlocks("UndelayedImagingNaive");
S.Naive.Group = repmat("Naive", height(S.Naive), 1);
S.Transfer = TransferLearning.DelayComparison.CohortBlocks("UndelayedImagingTransfer");
S.Transfer.Group = repmat("12 h", height(S.Transfer), 1);
S.Gap = iImagingSessions(TransferLearning.Vacation7(), "Vacation7");
S.TH = [iImagingSessions(TransferLearning.THInhibit(), "THInhibit"); iPOSessions()];
CFos = TransferLearning.BehaviorSessions.CFosInhibitionSessions();
S.CFosControl = CFos(CFos.Group == "Control", :);
S.CFos = CFos(CFos.Group == "MOp", :);
labels = struct('Naive', "Naive", 'Transfer', "12 h", 'Gap', "7 d", 'TH', "TH", ...
	'CFosControl', "cFos control", 'CFos', "cFos");
fields = fieldnames(S);

%% 2. 三种逐鼠学习速度
Metrics = struct();
for i = 1:numel(fields)
	f = fields{i};
	Metrics.(f) = iComputeMetrics(S.(f), labels.(f));
end

MetricSummary = table(strings(0, 1), strings(0, 1), zeros(0, 1), nan(0, 1), nan(0, 1), nan(0, 1), ...
	'VariableNames', {'Metric', 'Group', 'NMice', 'Mean', 'SEM', 'Median'});
for metric = ["BlocksTo50", "SigmoidSlope", "LearningSpeed"]
	for i = 1:numel(fields)
		x = double(Metrics.(fields{i}).(metric));
		x = x(isfinite(x));
		MetricSummary = [MetricSummary; table(metric, labels.(fields{i}), numel(x), ...
			mean(x), std(x) / sqrt(numel(x)), median(x), ...
			'VariableNames', MetricSummary.Properties.VariableNames)]; %#ok<AGROW>
	end
end
fprintf('\n========== 三种学习速度：各组汇总 ==========\n');
disp(MetricSummary);

%% 3. sigmoid 组间秩和检验与置换检验
GroupTests = table(strings(0, 1), strings(0, 1), strings(0, 1), zeros(0, 1), zeros(0, 1), ...
	nan(0, 1), nan(0, 1), nan(0, 1), nan(0, 1), strings(0, 1), strings(0, 1), ...
	'VariableNames', {'Metric', 'Comparison', 'Test', 'NA', 'NB', 'MeanA', 'MeanB', ...
	'MeanDifferenceAminusB', 'PValue', 'Direction', 'Significance'});
pairSpecs = {"Transfer", "Naive"; "Transfer", "Gap"; "Transfer", "TH"; ...
	"Transfer", "CFos"; "CFosControl", "CFos"};
for metric = ["BlocksTo50", "SigmoidSlope", "LearningSpeed"]
	for i = 1:size(pairSpecs, 1)
		A = S.(pairSpecs{i, 1}); B = S.(pairSpecs{i, 2});
		if metric == "LearningSpeed"
			[x, y, nBlocks] = iLearningSpeedPair(A, B);
			metricName = "LearningSpeed（共同 " + nBlocks + " blocks）";
		else
			x = Metrics.(pairSpecs{i, 1}).(metric);
			y = Metrics.(pairSpecs{i, 2}).(metric);
			metricName = metric;
		end
		x = x(isfinite(x)); y = y(isfinite(y));
		p = ranksum(x, y);
		GroupTests = [GroupTests; iGroupRow(metricName, labels.(pairSpecs{i, 1}) + " − " + labels.(pairSpecs{i, 2}), ...
			"秩和检验", x, y, p)]; %#ok<AGROW>
	end
end

fprintf('\n========== 三种学习速度：组间秩和检验 ==========\n');
disp(GroupTests);

fprintf('\n开始 sigmoid 斜率逐鼠标签置换检验（双侧斜率均值差）。\n');
PermutationTests = table(strings(0, 1), zeros(0, 1), zeros(0, 1), nan(0, 1), nan(0, 1), ...
	nan(0, 1), nan(0, 1), strings(0, 1), zeros(0, 1), strings(0, 1), ...
	'VariableNames', {'Comparison', 'NA', 'NB', 'MeanA', 'MeanB', 'ObservedDifference', ...
	'PValue', 'Method', 'NPermutation', 'Significance'});
for i = 1:size(pairSpecs, 1)
	A = S.(pairSpecs{i, 1}); B = S.(pairSpecs{i, 2});
	name = labels.(pairSpecs{i, 1}) + " − " + labels.(pairSpecs{i, 2});
	[p, observed, meanA, meanB, nA, nB, method, nPerm] = iPermuteSigmoid(A, B, name, 5000);
	PermutationTests = [PermutationTests; table(name, nA, nB, meanA, meanB, observed, p, method, nPerm, ...
		iSigText(p), 'VariableNames', PermutationTests.Properties.VariableNames)]; %#ok<AGROW>
	fprintf('%s：斜率均值差 %+.4f，%s，p=%.6g。\n', name, observed, method, p);
end

%% 4. 响应异质性（仅成像鼠）
H = table();
imagingTables = struct();
imagingTables.Naive = S.Naive(ismember(S.Naive.Source, ["LightAudioBaseline", "LAInterspersed"]), :);
imagingTables.Transfer = S.Transfer(S.Transfer.Source == "AudioLightBaseline", :);
imagingTables.Gap = S.Gap;
imagingTables.TH = S.TH(S.TH.Source == "THInhibit", :);
for group = ["Naive", "Transfer", "Gap", "TH"]
	T = iCeilingFilter(imagingTables.(group));
	if group == "Naive"
		datasetSpecs = {TransferLearning.LightAudioBaseline(), "LightAudioBaseline"; ...
			TransferLearning.LAInterspersed(), "LAInterspersed"};
	elseif group == "Transfer"
		datasetSpecs = {TransferLearning.AudioLightBaseline(), "AudioLightBaseline"};
	elseif group == "Gap"
		datasetSpecs = {TransferLearning.Vacation7(), "Vacation7"};
	else
		datasetSpecs = {TransferLearning.THInhibit(), "THInhibit"};
	end
	for iD = 1:size(datasetSpecs, 1)
		DS = datasetSpecs{iD, 1}; source = datasetSpecs{iD, 2};
		Tsub = T(T.Source == source, :);
		if isempty(Tsub), continue; end
		for layer = ["MOp2/3", "MOp5"]
			R = TransferLearning.Metrics.ResponseHeterogeneity(DS, Tsub, "LightWater");
			R = R(R.Layer == layer, :);
			if isempty(R), continue; end
			R.Group = repmat(labels.(group), height(R), 1);
			H = [H; R]; %#ok<AGROW>
		end
	end
end
H = iAddPooled(H);

%% 5. 三种学习速度与响应异质性的 Spearman 相关
Correlations = table(strings(0, 1), strings(0, 1), strings(0, 1), zeros(0, 1), ...
	nan(0, 1), nan(0, 1), strings(0, 1), strings(0, 1), ...
	'VariableNames', {'Metric', 'Group', 'Layer', 'N', 'Rho', 'PValue', 'Significance', 'Direction'});
for group = ["Naive", "Transfer", "Gap", "TH"]
	for metric = ["BlocksTo50", "SigmoidSlope", "LearningSpeed"]
		for layer = ["MOp2/3", "MOp5", "Pooled"]
			R = H(H.Group == labels.(group) & H.Layer == layer, :);
			J = innerjoin(Metrics.(group)(:, {'Mouse', char(metric)}), R(:, {'Mouse', 'SD'}), 'Keys', 'Mouse');
			x = double(J.SD); y = double(J.(metric));
			ok = isfinite(x) & isfinite(y); x = x(ok); y = y(ok);
			if numel(x) >= 3 && std(x) > 0 && std(y) > 0
				[rho, p] = corr(x, y, 'Type', 'Spearman');
			else
				rho = NaN; p = NaN;
			end
			Correlations = [Correlations; table(metric, labels.(group), layer, numel(x), rho, p, ...
				iSigText(p), iCorrDirection(rho, p), 'VariableNames', Correlations.Properties.VariableNames)]; %#ok<AGROW>
		end
	end
end
fprintf('\n========== 三种学习速度与响应异质性的 Spearman 相关 ==========\n');
disp(Correlations);

%% 6. 响应异质性组间比较
HTests = table(strings(0, 1), strings(0, 1), zeros(0, 1), zeros(0, 1), nan(0, 1), nan(0, 1), ...
	nan(0, 1), nan(0, 1), strings(0, 1), strings(0, 1), ...
	'VariableNames', {'Comparison', 'Layer', 'NA', 'NB', 'MeanA', 'MeanB', ...
	'MeanDifferenceAminusB', 'PValue', 'Significance', 'Direction'});
for other = ["Naive", "7 d", "TH"]
	for layer = ["MOp2/3", "MOp5", "Pooled"]
		x = H.SD(H.Group == "12 h" & H.Layer == layer);
		y = H.SD(H.Group == other & H.Layer == layer);
		x = x(isfinite(x)); y = y(isfinite(y)); p = ranksum(x, y);
		HTests = [HTests; table("12 h − " + other, layer, numel(x), numel(y), mean(x), mean(y), ...
			mean(x) - mean(y), p, iSigText(p), iDiffDirection(mean(x) - mean(y), p), ...
			'VariableNames', HTests.Properties.VariableNames)]; %#ok<AGROW>
	end
end
fprintf('\n========== 响应异质性组间比较 ==========\n');
disp(HTests);

%% 7. 保存统计表
writetable(MetricSummary, fullfile(outDir, 'LearningMetrics_GroupSummary.csv'));
writetable(GroupTests, fullfile(outDir, 'LearningMetrics_All_GroupRankSum.csv'));
writetable(PermutationTests, fullfile(outDir, 'SigmoidSlope_PermutationTests.csv'));
writetable(Correlations, fullfile(outDir, 'LearningMetrics_Heterogeneity_Spearman.csv'));
writetable(HTests, fullfile(outDir, 'Heterogeneity_GroupComparisons.csv'));
writetable(H, fullfile(outDir, 'Heterogeneity_PerMouse.csv'));

assignin('base', 'LearningMetrics_GroupSummary', MetricSummary);
assignin('base', 'LearningMetrics_GroupTests', GroupTests);
assignin('base', 'LearningMetrics_SigmoidPermutationTests', PermutationTests);
assignin('base', 'LearningMetrics_HeterogeneityCorrelations', Correlations);
assignin('base', 'LearningMetrics_HeterogeneityGroupTests', HTests);
assignin('base', 'LearningMetrics_PerMouse', Metrics);
assignin('base', 'LearningMetrics_Heterogeneity', H);
fprintf('\n统计完成，CSV 已保存：%s\n', outDir);

%% ========== 局部函数 ==========
function M = iComputeMetrics(S, label)
B = TransferLearning.DelayComparison.FitSigmoidPerMouse(TransferLearning.DelayComparison.AddBlockIndex(S), true);
mice = unique(string(S.Mouse), 'stable');
b50 = nan(numel(mice), 1); ls = nan(numel(mice), 1); slope = nan(numel(mice), 1);
for i = 1:numel(mice)
	R = sortrows(S(S.Mouse == mice(i), :), 'DateTime');
	y = double(R.Performance); y = y(isfinite(y));
	if isempty(y), continue; end
	ic = find(y >= 0.5, 1, 'first');
	if isempty(ic)
		b50(i) = numel(y) + 1;
	elseif ic == 1
		b50(i) = 1;
	else
		b50(i) = ic - 1 + (0.5 - y(ic - 1)) / (y(ic) - y(ic - 1));
	end
	yLS = y; yLS(end + 1:max(splitapply(@numel, S.Mouse, findgroups(S.Mouse))), 1) = max(y);
	ls(i) = sum(yLS(2:end) - yLS(1)) / sum(1 - yLS);
	j = find(B.Mouse == mice(i), 1);
	if ~isempty(j), slope(i) = B.Slope(j); end
end
M = table(repmat(string(label), numel(mice), 1), mice, b50, slope, ls, ...
	'VariableNames', {'Group', 'Mouse', 'BlocksTo50', 'SigmoidSlope', 'LearningSpeed'});
end

function [x, y, nBlocks] = iLearningSpeedPair(A, B)
nBlocks = max(splitapply(@numel, [A.Mouse; B.Mouse], findgroups([A.Mouse; B.Mouse])));
x = iLSAtN(A, nBlocks); y = iLSAtN(B, nBlocks);
end

function ls = iLSAtN(S, nBlocks)
mice = unique(string(S.Mouse), 'stable'); ls = nan(numel(mice), 1);
for i = 1:numel(mice)
	y = double(S.Performance(S.Mouse == mice(i))); y = y(isfinite(y));
	if isempty(y), continue; end
	y(end + 1:nBlocks, 1) = max(y);
	ls(i) = sum(y(2:end) - y(1)) / sum(1 - y);
end
end

function T = iGroupRow(metric, comparison, test, x, y, p)
T = table(metric, comparison, test, numel(x), numel(y), mean(x), mean(y), mean(x) - mean(y), p, ...
	iDiffDirection(mean(x) - mean(y), p), iSigText(p), 'VariableNames', ...
	{'Metric', 'Comparison', 'Test', 'NA', 'NB', 'MeanA', 'MeanB', ...
	'MeanDifferenceAminusB', 'PValue', 'Direction', 'Significance'});
end

function [p, observed, meanA, meanB, nA, nB, method, nPerm] = iPermuteSigmoid(A, B, comparison, maxPerm)
rng(20261108, 'twister');
x = iFitSlopes(A); y = iFitSlopes(B);
nA = numel(x); nB = numel(y);
meanA = mean(x); meanB = mean(y); observed = meanA - meanB;
allX = [x; y]; n = numel(allX);
nAssign = nchoosek(n, nA);
if nAssign <= maxPerm
	assignments = nchoosek(1:n, nA);
	method = "精确枚举全部标签分配";
else
	assignments = nan(maxPerm, nA);
	for i = 1:maxPerm
		assignments(i, :) = randperm(n, nA);
	end
	method = maxPerm + " 次随机标签置换";
end
nPerm = size(assignments, 1);
nullDiff = nan(nPerm, 1);
for i = 1:nPerm
	mask = false(n, 1); mask(assignments(i, :)) = true;
	nullDiff(i) = mean(allX(mask)) - mean(allX(~mask));
end
p = (1 + sum(abs(nullDiff) >= abs(observed))) / (nPerm + 1);
fprintf('%s：%d 个可拟合鼠，%s。\n', comparison, n, method);
end

function slopes = iFitSlopes(S)
B = TransferLearning.DelayComparison.FitSigmoidPerMouse(TransferLearning.DelayComparison.AddBlockIndex(S), true);
slopes = double(B.Slope); slopes = slopes(isfinite(slopes));
end

function S = iImagingSessions(DS, source)
S = TransferLearning.DelayComparison.LightSessionTable(DS, "LightWater", "Transfer", "Final");
S.Group = repmat("Transfer", height(S), 1);
S.Source = repmat(string(source), height(S), 1);
S = S(:, {'Group', 'Mouse', 'DateTime', 'Performance', 'Source'});
end

function S = iPOSessions()
T = TransferLearning.BuildPOBehaviorTrialTable();
[G, mouse, dt] = findgroups(T.Mouse, T.DateTime, T.Block);
performance = splitapply(@(x) mean(double(x), 'omitnan'), T.Behavior, G);
S = table(repmat("TH", numel(performance), 1), mouse, dt, performance, ...
	repmat("POBehaviorOnly", numel(performance), 1), ...
	'VariableNames', {'Group', 'Mouse', 'DateTime', 'Performance', 'Source'});
end

function S = iCeilingFilter(S)
S = sortrows(S, {'Mouse', 'DateTime'}); keep = false(height(S), 1);
for m = unique(S.Mouse)'
	idx = find(S.Mouse == m);
	i100 = find(double(S.Performance(idx)) >= 1 - 1e-12, 1, 'first');
	if isempty(i100), use = idx; else, use = idx(1:i100 - 1); end
	use = idx(1:min(max(1, numel(use)), numel(idx)));
	if numel(use) >= 2, keep(use) = true; end
end
S = S(keep, :);
end

function H = iAddPooled(H)
R = table(strings(0, 1), strings(0, 1), nan(0, 1), zeros(0, 1), strings(0, 1), ...
	'VariableNames', {'Mouse', 'Layer', 'SD', 'NCells', 'Group'});
for g = unique(H.Group)'
	for m = unique(H.Mouse(H.Group == g))'
		T = H(H.Group == g & H.Mouse == m, :);
		n = sum(T.NCells);
		if n > 0, v = sum(T.NCells .* T.SD) / n; else, v = NaN; end
		R = [R; table(string(m), "Pooled", v, n, string(g), 'VariableNames', R.Properties.VariableNames)]; %#ok<AGROW>
	end
end
H = [H; R];
end

function t = iSigText(p)
if ~isfinite(p), t = "无法计算"; elseif p < 0.001, t = "显著（p<0.001）"; elseif p < 0.05, t = "显著"; else, t = "不显著"; end
end

function t = iDiffDirection(d, p)
if p < 0.05 && d > 0, t = "前者显著更高"; elseif p < 0.05 && d < 0, t = "前者显著更低";
elseif d > 0, t = "前者更高，不显著"; elseif d < 0, t = "前者更低，不显著"; else, t = "无差异"; end
end

function t = iCorrDirection(r, p)
if ~isfinite(r), t = "无法计算"; elseif p < 0.05 && r > 0, t = "显著正相关"; elseif p < 0.05 && r < 0, t = "显著负相关";
elseif r > 0, t = "正相关，不显著"; elseif r < 0, t = "负相关，不显著"; else, t = "无相关"; end
end
