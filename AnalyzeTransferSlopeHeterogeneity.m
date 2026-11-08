% TransferLearning 光水学习斜率与响应异质性统一统计。
%
% 输出三部分结果：
% 1. 12 h Transfer 的逐鼠 LearningSpeed 分别与 Naive、7 d、TH 抑制、cFos 抑制比较。
% 2. Naive、12 h、7 d、TH 四组各自的 LearningSpeed 与响应异质性的 Spearman 相关，
%    分别报告 MOp2/3、MOp5 和两层合并结果。
% 3. 12 h Transfer 的响应异质性分别与 Naive、7 d、TH 比较，
%    同样报告 MOp2/3、MOp5 和两层合并结果。
%
% 学习速度定义（不再使用 sigmoid 拟合）：
%   LS = Σ(后续命中率 − 首 block 命中率) / Σ(1 − 各 block 命中率)。
% 每组汇总时取该组内最大 block 数；每次两组比较时，另取两组共同最大 block 数。
% 不足的 block 向右补全为该鼠已有 block 中的最大命中率；补全命中率为 1 时
% 学习速度按定义记为 0。相关分析使用各组自身完整学习曲线。
% 组间差异使用双侧 Mann–Whitney 秩和检验；显著性阈值为 p < 0.05，不另行校正。
%
% 斜率的 Naive、12 h 和 TH 队列包含成像鼠和纯行为鼠：
% Naive = LightAudioBaseline + LAPureBehavior + LAInterspersed；
% 12 h = AudioLightBaseline + ALPureBehavior；7 d = Vacation7；
% TH = THInhibit + THBehavior（PO 纯行为）。
% 各组使用各自 LightWater 学习会话，Naive 阶段混入 AudioWater 的 LAInterspersed
% 鼠整只剔除。TH 纯行为沿用 BuildPOBehaviorTrialTable 的块筛选与序号。
% 响应异质性仅能用成像鼠计算，使用与斜率拟合相同规格筛选后的成像会话。
% cFos 只有行为数据，仅用于斜率比较，不计算异质性。
%
% 学习速度使用每鼠完整原始光水学习曲线，不因首次达到 100% 而截断。
% 响应异质性：逐细胞逐会话取 cue +1 s 的 z 分数中位数，跨所选会话取均值，
% 仅保留 |z| ≤ 1 的细胞，计算细胞间标准差；每层至少三个有效细胞。
% 响应异质性沿用成像组既有筛选，至少保留两个未达 100% 命中率的会话。
% TH 使用 Fig4D 的 Transfer→Final 纯光水会话及未学满块筛选，且剔除混入
% AudioWater 的会话。
% 两层合并值 = 两层中等响应细胞数加权的异质性均值。
%
% 输出：命令窗口完整表格，以及数据服务器个人目录下 2026xx 文件夹中的四个 CSV。
% 本文件保持脚本形式，在 MATLAB 编辑器中运行（F5）。

thisDir = fileparts(mfilename('fullpath'));
if ~exist('UniExp.DataSet', 'class')
	prjFile = fullfile(thisDir, '..', 'Transferlearning.prj');
	if exist(prjFile, 'file')
		matlab.project.loadProject(prjFile);
	end
end

%% 1. 各组逐鼠斜率（Naive 和 12 h 同时纳入成像与纯行为鼠）
behaviorTables = struct();
behaviorTables.Naive = TransferLearning.DelayComparison.CohortBlocks("UndelayedImagingNaive");
behaviorTables.Naive.Group = repmat("Naive", height(behaviorTables.Naive), 1);
behaviorTables.Transfer = TransferLearning.DelayComparison.CohortBlocks("UndelayedImagingTransfer");
behaviorTables.Transfer.Group = repmat("12 h", height(behaviorTables.Transfer), 1);
behaviorTables.Gap = iImagingTransferSessions(TransferLearning.Vacation7(), "Vacation7");
behaviorTables.TH = iImagingTransferSessions(TransferLearning.THInhibit(), "THInhibit");
% TH 同时纳入 PO 纯行为鼠，按既有 BuildPOBehaviorTrialTable 的逐块命中率聚合。
behaviorTables.TH = [behaviorTables.TH; iPOBehaviorSessions()];
% 不对行为曲线按首次命中率 100% 截断，避免把快速学满的鼠错误记为 LS=0。

% 响应异质性只读取成像会话，不能包含纯行为鼠；与既有异质性图一致，
% 至少保留两个未达 100% 命中率的会话，避免跨会话平均退化。
sessionTables = struct();
sessionTables.Naive = behaviorTables.Naive(ismember(behaviorTables.Naive.Source, ...
	["LightAudioBaseline", "LAInterspersed"]), :);
sessionTables.Transfer = behaviorTables.Transfer(behaviorTables.Transfer.Source == "AudioLightBaseline", :);
sessionTables.Gap = behaviorTables.Gap;
sessionTables.TH = behaviorTables.TH(behaviorTables.TH.Source == "THInhibit", :);
for group = ["Naive", "Transfer", "Gap", "TH"]
	sessionTables.(group) = iCeilingFilteredSessions(sessionTables.(group), 2);
end

fitTables = struct();
fitTables.Naive = iFitGroup(behaviorTables.Naive, "Naive");
fitTables.Transfer = iFitGroup(behaviorTables.Transfer, "12 h");
fitTables.Gap = iFitGroup(behaviorTables.Gap, "7 d");
fitTables.TH = iFitGroup(behaviorTables.TH, "TH");

% cFos 抑制组及其实验内对照分别按组内最大 block 数补齐后计算。
cFosSessions = TransferLearning.BehaviorSessions.CFosInhibitionSessions();
cFosControl = iFitGroup(cFosSessions(cFosSessions.Group == "Control", :), "cFos control");
cFosInhibit = iFitGroup(cFosSessions(cFosSessions.Group == "MOp", :), "cFos");
fitTables.CFosControl = cFosControl;
fitTables.CFos = cFosInhibit;

fitFields = fieldnames(fitTables);
slopeSummary = table(strings(0, 1), zeros(0, 1), zeros(0, 1), nan(0, 1), nan(0, 1), nan(0, 1), ...
	'VariableNames', {'Group', 'NMice', 'NBlocks', 'MeanSlope', 'SemSlope', 'MedianSlope'});
for iF = 1:numel(fitFields)
	Fit = fitTables.(fitFields{iF});
	slopeSummary = [slopeSummary; table(string(Fit.Group(1)), height(Fit), Fit.NBlocks(1), ...
		mean(Fit.Slope), std(Fit.Slope) / sqrt(height(Fit)), median(Fit.Slope), ...
		'VariableNames', slopeSummary.Properties.VariableNames)]; %#ok<AGROW>
end

slopeComparisons = table(strings(0, 1), zeros(0, 1), zeros(0, 1), zeros(0, 1), ...
	nan(0, 1), nan(0, 1), nan(0, 1), nan(0, 1), strings(0, 1), strings(0, 1), ...
	'VariableNames', {'Comparison', 'NBlocks', 'N12hOrA', 'NOtherOrB', 'MeanA', 'MeanB', ...
	'MeanDifferenceAminusB', 'PValue', 'Significance', 'Direction'});
slopeComparisons = iAddSlopeComparison(slopeComparisons, "12 h − Naive", ...
	behaviorTables.Transfer, behaviorTables.Naive);
slopeComparisons = iAddSlopeComparison(slopeComparisons, "12 h − 7 d", ...
	behaviorTables.Transfer, behaviorTables.Gap);
slopeComparisons = iAddSlopeComparison(slopeComparisons, "12 h − TH", ...
	behaviorTables.Transfer, behaviorTables.TH);
slopeComparisons = iAddSlopeComparison(slopeComparisons, "12 h − cFos", ...
	behaviorTables.Transfer, cFosSessions(cFosSessions.Group == "MOp", :));
slopeComparisons = iAddSlopeComparison(slopeComparisons, "cFos control − cFos（实验内对照）", ...
	cFosSessions(cFosSessions.Group == "Control", :), cFosSessions(cFosSessions.Group == "MOp", :));

fprintf('\n========== 各组 LearningSpeed 汇总（组内等长 block，最高命中率补全）==========\n');
disp(slopeSummary);
for group = ["Naive", "Transfer", "TH"]
	T = behaviorTables.(group);
	T = T(ismember(T.Mouse, fitTables.(group).Mouse), :);
	fprintf('%s 学习速度纳入鼠的来源构成：\n', fitTables.(group).Group(1));
	disp(groupcounts(T, 'Source'));
end
fprintf('Naive、12 h 与 TH 的学习速度统计包含成像鼠及纯行为鼠；异质性只用成像鼠。\n');
fprintf('汇总表的 NBlocks 为组内 block 数；组间比较另取两组共同最大 block 数。\n');
fprintf('不足部分均以该鼠已有最高命中率向右补齐。\n');
fprintf('cFos 数据不含细胞成像，故不纳入响应异质性计算。\n');

fprintf('\n========== 1. 光水 12 h Transfer 与其他组：LearningSpeed 比较 ==========\n');
iPrintComparisonTable(slopeComparisons, "斜率");

%% 2. 各组成像鼠逐层响应异质性
heterogeneity = table();
for group = ["Naive", "Transfer", "Gap", "TH"]
	S = sessionTables.(group);
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
		DS = datasetSpecs{iD, 1};
		source = datasetSpecs{iD, 2};
		Ssub = S(S.Source == source, :);
		if isempty(Ssub)
			continue;
		end
		for layer = ["MOp2/3", "MOp5"]
			H = TransferLearning.Metrics.ResponseHeterogeneity(DS, Ssub, "LightWater");
			H = H(H.Layer == layer, :);
			if isempty(H)
				continue;
			end
			H.Group = repmat(iGroupLabel(group), height(H), 1);
			H.Source = repmat(source, height(H), 1);
			heterogeneity = [heterogeneity; H]; %#ok<AGROW>
		end
	end
end
heterogeneity = iAddPooledHeterogeneity(heterogeneity);

%% 3. 各组斜率与响应异质性相关
correlationResults = table(strings(0, 1), strings(0, 1), zeros(0, 1), nan(0, 1), nan(0, 1), ...
	strings(0, 1), strings(0, 1), 'VariableNames', ...
	{'Group', 'Layer', 'N', 'Rho', 'PValue', 'Significance', 'Direction'});
for group = ["Naive", "Transfer", "Gap", "TH"]
	Fit = fitTables.(group);
	for layer = ["MOp2/3", "MOp5", "Pooled"]
		H = heterogeneity(heterogeneity.Group == iGroupLabel(group) & heterogeneity.Layer == layer, :);
		[J, iF, iH] = innerjoin(Fit(:, {'Mouse', 'Slope'}), H(:, {'Mouse', 'SD', 'NCells'}), 'Keys', 'Mouse');
		x = double(J.SD);
		y = double(J.Slope);
		ok = isfinite(x) & isfinite(y);
		x = x(ok); y = y(ok);
		if numel(x) >= 3 && std(x) > 0 && std(y) > 0
			[rho, p] = corr(x, y, 'Type', 'Spearman');
		else
			rho = NaN; p = NaN;
		end
		correlationResults = [correlationResults; table(iGroupLabel(group), layer, numel(x), rho, p, ...
			iSignificanceText(p), iCorrelationDirection(rho, p), ...
			'VariableNames', correlationResults.Properties.VariableNames)]; %#ok<AGROW>
	end
end
fprintf('\n========== 2. 各组 LearningSpeed 与响应异质性：Spearman 相关 ==========\n');
iPrintCorrelationTable(correlationResults);

%% 4. 12 h Transfer 与其他组的响应异质性比较
heterogeneityComparisons = table(strings(0, 1), strings(0, 1), zeros(0, 1), zeros(0, 1), ...
	nan(0, 1), nan(0, 1), nan(0, 1), nan(0, 1), strings(0, 1), strings(0, 1), ...
	'VariableNames', {'Comparison', 'Layer', 'N12hOrA', 'NOtherOrB', 'MeanA', 'MeanB', ...
	'MeanDifferenceAminusB', 'PValue', 'Significance', 'Direction'});
for other = ["Naive", "7 d", "TH"]
	for layer = ["MOp2/3", "MOp5", "Pooled"]
		x = heterogeneity.SD(heterogeneity.Group == "12 h" & heterogeneity.Layer == layer);
		y = heterogeneity.SD(heterogeneity.Group == other & heterogeneity.Layer == layer);
		x = x(isfinite(x)); y = y(isfinite(y));
		if ~isempty(x) && ~isempty(y)
			p = ranksum(x, y);
		else
			p = NaN;
		end
		heterogeneityComparisons = [heterogeneityComparisons; table("12 h − " + other, layer, ...
			numel(x), numel(y), mean(x), mean(y), mean(x) - mean(y), p, ...
			iSignificanceText(p), iDifferenceDirection(mean(x) - mean(y), p), ...
			'VariableNames', heterogeneityComparisons.Properties.VariableNames)]; %#ok<AGROW>
	end
end
fprintf('\n========== 3. 光水 12 h Transfer 与其他组：响应异质性比较 ==========\n');
fprintf('各层及合并层均仅纳入具有有效异质性值的成像鼠；n 按“12 h 鼠数/对照组鼠数”输出。\n');
iPrintHeterogeneityTable(heterogeneityComparisons);

%% 5. 保存完整统计表
outDir = fullfile('\\Data-Server-2\个人数据', getenv('USERNAME'), char(datetime('now', 'Format', 'yyyyMM')));
if ~isfolder(outDir)
	mkdir(outDir);
end
writetable(slopeComparisons, fullfile(outDir, 'Transfer_Slope_GroupComparisons.csv'));
writetable(correlationResults, fullfile(outDir, 'Transfer_Slope_Heterogeneity_Spearman.csv'));
writetable(heterogeneityComparisons, fullfile(outDir, 'Transfer_Heterogeneity_GroupComparisons.csv'));
writetable(slopeSummary, fullfile(outDir, 'Transfer_Slope_GroupSummary.csv'));
fprintf('\n已保存四个统计 CSV：%s\n', outDir);

assignin('base', 'TransferSlopeHeterogeneity_SlopeSummary', slopeSummary);
assignin('base', 'TransferSlopeHeterogeneity_SlopeComparisons', slopeComparisons);
assignin('base', 'TransferSlopeHeterogeneity_Correlations', correlationResults);
assignin('base', 'TransferSlopeHeterogeneity_HeterogeneityComparisons', heterogeneityComparisons);
assignin('base', 'TransferSlopeHeterogeneity_PerMouseSlopes', fitTables);
assignin('base', 'TransferSlopeHeterogeneity_PerMouseHeterogeneity', heterogeneity);

%% ========== 局部函数 ==========
function Fit = iFitGroup(Sess, label)
% 每组所有鼠使用相同的 block 数，缺失部分向右补为该鼠已有最高命中率。
S = sortrows(Sess, {'Mouse', 'DateTime'});
mice = unique(string(S.Mouse), 'stable');
nBlocks = max(splitapply(@numel, S.Mouse, findgroups(S.Mouse)));
slopes = nan(numel(mice), 1);
for i = 1:numel(mice)
	R = S(S.Mouse == mice(i), :);
	y = double(R.Performance(:));
	y = y(isfinite(y));
	if isempty(y)
		continue;
	end
	if numel(y) < nBlocks
		y(end + 1:nBlocks, 1) = max(y);
	end
	slopes(i) = sum(y(2:end) - y(1)) / sum(1 - y);
end
Fit = table(repmat(string(label), numel(mice), 1), mice, slopes, ...
	repmat(nBlocks, numel(mice), 1), 'VariableNames', {'Group', 'Mouse', 'Slope', 'NBlocks'});
end

function T = iAddSlopeComparison(T, comparison, SessA, SessB)
nBlocks = max(splitapply(@numel, [SessA.Mouse; SessB.Mouse], ...
	findgroups([SessA.Mouse; SessB.Mouse])));
FitA = iFitGroupAtBlocks(SessA, "A", nBlocks);
FitB = iFitGroupAtBlocks(SessB, "B", nBlocks);
x = double(FitA.Slope); y = double(FitB.Slope);
x = x(isfinite(x)); y = y(isfinite(y));
if ~isempty(x) && ~isempty(y)
	p = ranksum(x, y);
else
	p = NaN;
end
T = [T; table(comparison, nBlocks, numel(x), numel(y), mean(x), mean(y), mean(x) - mean(y), ...
	p, iSignificanceText(p), iDifferenceDirection(mean(x) - mean(y), p), ...
	'VariableNames', T.Properties.VariableNames)];
end

function Fit = iFitGroupAtBlocks(Sess, label, nBlocks)
% 在本次两组比较的共同 block 数下计算学习速度。
S = sortrows(Sess, {'Mouse', 'DateTime'});
mice = unique(string(S.Mouse), 'stable');
slopes = nan(numel(mice), 1);
for i = 1:numel(mice)
	y = double(S.Performance(S.Mouse == mice(i)));
	y = y(isfinite(y));
	if isempty(y)
		continue;
	end
	if numel(y) < nBlocks
		y(end + 1:nBlocks, 1) = max(y);
	end
	slopes(i) = sum(y(2:end) - y(1)) / sum(1 - y);
end
Fit = table(repmat(string(label), numel(mice), 1), mice, slopes, ...
	repmat(nBlocks, numel(mice), 1), 'VariableNames', {'Group', 'Mouse', 'Slope', 'NBlocks'});
end

function S = iCeilingFilteredSessions(S, minSessions)
S = sortrows(S, {'Group', 'Mouse', 'DateTime'});
keep = false(height(S), 1);
for m = unique(S.Mouse)'
	idx = find(S.Mouse == m);
	i100 = find(double(S.Performance(idx)) >= 1 - 1e-12, 1, 'first');
	if isempty(i100)
		use = idx;
	else
		use = idx(1:i100 - 1);
	end
	% 即使首个会话整块命中率已为 100%，也至少保留首个会话供斜率拟合判断。
	use = idx(1:min(max(1, numel(use)), numel(idx)));
	if numel(use) >= minSessions
		keep(use) = true;
	end
end
S = S(keep, :);
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

function label = iGroupLabel(group)
switch group
	case "Naive"
		label = "Naive";
	case "Transfer"
		label = "12 h";
	case "Gap"
		label = "7 d";
	case "TH"
		label = "TH";
	otherwise
		error('未知组名：%s', group);
end
end

function H = iAddPooledHeterogeneity(H)
if isempty(H)
	return;
end
rows = table();
for g = unique(H.Group)'
	for m = unique(H.Mouse(H.Group == g))'
		R = H(H.Group == g & H.Mouse == m, :);
		n23 = R.NCells(R.Layer == "MOp2/3");
		n5 = R.NCells(R.Layer == "MOp5");
		if isempty(n23), n23 = 0; end
		if isempty(n5), n5 = 0; end
		v23 = R.SD(R.Layer == "MOp2/3");
		v5 = R.SD(R.Layer == "MOp5");
		if isempty(v23), v23 = NaN; end
		if isempty(v5), v5 = NaN; end
		nTotal = sum([n23; n5]);
		if nTotal > 0
			v = sum([n23 * v23; n5 * v5], 'omitnan') / nTotal;
		else
			v = NaN;
		end
		rows = [rows; table(string(m), "Pooled", v, nTotal, string(g), R.Source(1), ...
			'VariableNames', {'Mouse', 'Layer', 'SD', 'NCells', 'Group', 'Source'})]; %#ok<AGROW>
	end
end
H = [H; rows];
end

function text = iSignificanceText(p)
if ~isfinite(p)
	text = "无法计算";
elseif p < 0.001
	text = "显著（p<0.001）";
elseif p < 0.05
	text = "显著";
else
	text = "不显著";
end
end

function text = iDifferenceDirection(delta, p)
if ~isfinite(delta) || ~isfinite(p)
	text = "无法判断";
elseif p < 0.05 && delta > 0
	text = "12 h/前者显著更高";
elseif p < 0.05 && delta < 0
	text = "12 h/前者显著更低";
elseif delta > 0
	text = "12 h/前者更高，不显著";
elseif delta < 0
	text = "12 h/前者更低，不显著";
else
	text = "无差异";
end
end

function text = iCorrelationDirection(rho, p)
if ~isfinite(rho) || ~isfinite(p)
	text = "无法判断";
elseif p < 0.05 && rho > 0
	text = "显著正相关";
elseif p < 0.05 && rho < 0
	text = "显著负相关";
elseif rho > 0
	text = "正相关，不显著";
elseif rho < 0
	text = "负相关，不显著";
else
	text = "无相关";
end
end

function iPrintComparisonTable(T, metric)
for i = 1:height(T)
	fprintf('%s：共同 block 数=%d；均值 %.4f vs %.4f，差值 %+.4f；n=%d/%d；p=%.6g；%s；%s\n', ...
		T.Comparison(i), T.NBlocks(i), T.MeanA(i), T.MeanB(i), T.MeanDifferenceAminusB(i), ...
		T.N12hOrA(i), T.NOtherOrB(i), T.PValue(i), T.Significance(i), T.Direction(i));
end
fprintf('（上述组间检验均为双侧 Mann–Whitney 秩和检验，指标为%s。）\n', metric);
end

function iPrintCorrelationTable(T)
for i = 1:height(T)
	fprintf('%s，%s：n=%d；Spearman ρ=%+.4f；p=%.6g；%s；%s\n', ...
		T.Group(i), T.Layer(i), T.N(i), T.Rho(i), T.PValue(i), T.Significance(i), T.Direction(i));
end
end

function iPrintHeterogeneityTable(T)
for i = 1:height(T)
	fprintf('%s，%s：均值 %.4f vs %.4f，差值 %+.4f；n=%d/%d；p=%.6g；%s；%s\n', ...
		T.Comparison(i), T.Layer(i), T.MeanA(i), T.MeanB(i), T.MeanDifferenceAminusB(i), ...
		T.N12hOrA(i), T.NOtherOrB(i), T.PValue(i), T.Significance(i), T.Direction(i));
end
end
