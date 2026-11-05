% Fig1: LightWater 学习曲线，三组按任务间时间 Δt 排列
%
% 分组（均为成像队列、undelayed 范式）：
%   Naive        无 Δt（未学过声水任务）  LightAudioBaseline + LAInterspersed 的 Naive→Learned
%   Transfer     Δt = 12 h              AudioLightBaseline 的 Transfer→Final
%   7dayTransfer Δt = 7 d               Vacation7 的 Transfer→Final
%
% 三组共用同一任务内时间轴（LightWater 的 block 序号，每 block 30 试次、间隔 12 h）。
%
% 输出（\\Data-Server-2\个人数据\<USERNAME>\yyyyMM）：
%   - Fig1_ThreeGroupLightWaterLearningCurve.svg
%   - Fig1_ThreeGroupLightWaterFirstBlock_Inset.svg
%   - Fig1_ThreeGroupLightWaterLearningCurve.csv（逐 block mean/sem/n）
%   - Fig1_ThreeGroupLightWaterLearningCurveFit.csv（Sigmoid 参数）
%   - Fig1_ThreeGroupLightWaterFirstBlock.csv（逐鼠首 block 命中率）
%   - 本脚本副本
%
% Execution（硬性要求）：
% - 保持为脚本（不要改成 function）。
% - 在 MATLAB 编辑器中打开后 Run/F5。

if ~exist('UniExp.DataSet', 'class')
	thisFile = mfilename('fullpath');
	thisDir = fileparts(thisFile);
	prjFile = fullfile(thisDir, 'Transferlearning.prj');
	if ~exist(prjFile, 'file')
		prjFile = fullfile(thisDir, '..', 'Transferlearning.prj');
	end
	if exist(prjFile, 'file')
		matlab.project.loadProject(prjFile);
	end
end

LAB = TransferLearning.LightAudioBaseline();
LAI = TransferLearning.LAInterspersed();
ALB = TransferLearning.AudioLightBaseline();
V7 = TransferLearning.Vacation7();

groupOrder = ["Naive", "Transfer", "7dayTransfer"];
% 与 Fig3B 的 7 天间隔配色保持一致
colors = [TransferLearning.NaiveColor; TransferLearning.TransferColor; TransferLearning.ColorB];

% LAInterspersed 是穿插范式，剔除去声水阶段混入声水试次的鼠
badMice = iMiceWithStimulusInPhase(LAI, "AudioWater", "Naive");
naiveA = iLightWaterSessions(LAB, "LightAudioBaseline", "Naive", "Learned", strings(0, 1));
naiveB = iLightWaterSessions(LAI, "LAInterspersed", "Naive", "Learned", badMice);
naive = [naiveA; naiveB];
naive.Group(:) = "Naive";

tran = iLightWaterSessions(ALB, "AudioLightBaseline", "Transfer", "Final", strings(0, 1));
tran.Group(:) = "Transfer";

gap = iLightWaterSessions(V7, "Vacation7", "Transfer", "Final", strings(0, 1));
gap.Group(:) = "7dayTransfer";

allSessions = [naive; tran; gap];
if isempty(allSessions)
	error('Fig1_ThreeGroup:EmptyData', '三组均未取到 LightWater 会话。');
end
allSessions.Mouse = string(allSessions.Mouse);
allSessions.Group = string(allSessions.Group);
allSessions.Source = string(allSessions.Source);
iAssertUniqueMouse(allSessions);
if numel(unique(allSessions.Group)) ~= numel(groupOrder)
	error('Fig1_ThreeGroup:MissingGroup', '分组不全，实际得到：%s', strjoin(unique(allSessions.Group)', ','));
end

allSessions = sortrows(allSessions, ["Group", "Mouse", "DateTime"]);
allSessions = TransferLearning.BehaviorSessions.iAddSessionIndex(allSessions);

nMice = zeros(1, numel(groupOrder));
for k = 1:numel(groupOrder)
	nMice(k) = numel(unique(allSessions.Mouse(allSessions.Group == groupOrder(k))));
end

sessionForSummary = allSessions(:, ["Mouse", "DateTime", "Performance", "Group"]);
sessionForSummary.Group = string(sessionForSummary.Group);
[meanMat, semMat, x] = iSummarize(sessionForSummary, groupOrder);
nMat = iNBySession(allSessions, numel(x), groupOrder);

fits = cell(1, numel(groupOrder));
for k = 1:numel(groupOrder)
	fitInput = iFilterToDisplayedMice(allSessions(allSessions.Group == groupOrder(k), :));
	fits{k} = iFitSigmoidCurve(fitInput, groupOrder(k));
end

perMouseHalf = iPerMouseHalfBlock(allSessions, groupOrder);

sess7 = allSessions(allSessions.Session <= 7, :);
pGroup7 = TransferLearning.Style.TwoWayAnovaGroupPValue(sess7, 'Performance', 'Session', 'Group', 'Mouse');

perMouse = iFirstBlockPerMouse(allSessions);
xFirst = cell(1, numel(groupOrder));
for k = 1:numel(groupOrder)
	xFirst{k} = perMouse.FirstPerf(perMouse.Group == groupOrder(k) & isfinite(perMouse.FirstPerf));
end
pairIdx = [1 2; 1 3; 2 3];
pFirst = nan(size(pairIdx, 1), 1);
pSlope = nan(size(pairIdx, 1), 1);
for iPair = 1:size(pairIdx, 1)
	[pFirst(iPair), ~] = TransferLearning.BehaviorSessions.iRanksumSafe(xFirst{pairIdx(iPair, 1)}, xFirst{pairIdx(iPair, 2)});
	[pSlope(iPair), ~] = TransferLearning.BehaviorSessions.iRanksumSafe( ...
		perMouseHalf{pairIdx(iPair, 1)}, perMouseHalf{pairIdx(iPair, 2)});
end

% ---------- 主图：三组学习曲线（含 legend → Scale=2，9×8 cm） ----------
% 只显示前 10 个 block（与 FigS1D 一致）；Sigmoid 拟合仍用全部 block
nBlocksShow = 10;
xMax = min(nBlocksShow, max(x));
f = figure('Color', 'w', 'Name', 'Fig1 three-group LightWater learning curve');
f.Units = 'centimeters';
f.Position(3:4) = [9, 8];
f.PaperUnits = 'centimeters';
f.PaperSize = [9, 8];
f.PaperPositionMode = 'auto';
ax = axes(f);
hold(ax, 'on');

meanCells = iTrimCells(meanMat, xMax);
semCells = iTrimCells(semMat, xMax);
MATLAB.Graphics.MultiShadowedLines(meanCells, semCells, 1 / (numel(groupOrder) + 1), EdgeColors=colors);

xFit = (1:xMax).';
for k = 1:numel(groupOrder)
	plot(ax, xFit, iSigmoidFromParams(fits{k}.ParamRaw, xFit), '--', 'Color', colors(k, :), 'LineWidth', 1, 'HandleVisibility', 'off');
end

proxy = gobjects(numel(groupOrder), 1);
labels = groupOrder;
for k = 1:numel(groupOrder)
	proxy(k) = plot(ax, nan, nan, '-', 'Color', colors(k, :), 'LineWidth', 2);
end

xlabel(ax, 'Block');
ylabel(ax, 'Hit rate');
xlim(ax, [1, xMax]);
ylim(ax, [0, 1.12]);

yBar = 1.02;
plot(ax, [1, 7], [yBar, yBar], 'k-', 'LineWidth', 1, 'HandleVisibility', 'off');
text(ax, 4, yBar + 0.02, iFormatP(pGroup7), 'HorizontalAlignment', 'center', 'VerticalAlignment', 'bottom', 'HandleVisibility', 'off');
yticks(ax, 0:0.2:1);

lg = legend(ax, proxy, cellstr(labels), 'Location', 'southeast');
lg.Box = 'off';
box(ax, 'off');
if isprop(ax, 'Toolbar') && ~isempty(ax.Toolbar)
	ax.Toolbar.Visible = 'off';
end
svgPath = TransferLearning.ExportStandardFigure(f, 2, 'Fig1_ThreeGroupLightWaterLearningCurve.svg');
outDir = fileparts(svgPath);
fprintf('Wrote: %s\n', svgPath);

% ---------- Inset：首 block 命中率（规范：4×4 cm，透明，Scale=2） ----------
f2 = figure('Color', 'w', 'Name', 'Fig1 three-group first block');
f2.Units = 'centimeters';
f2.Position(3:4) = [4, 4];
f2.PaperUnits = 'centimeters';
f2.PaperSize = [4, 4];
f2.PaperPositionMode = 'auto';
ax2 = axes(f2);
CompareGroup = table(pairIdx, 'VariableNames', {'GroupPair'});
[~, Opt2, Bars2, ErrorBars2] = UniExp.BarScatterCompare(xFirst, UniExp.Flags.empty, CompareGroup, UniExp.Flags.IndividualErrorbars, 'AsteriskThreshold', 0.05);
ax2.XTick = 1:numel(groupOrder);
ax2.XTickLabel = {};
ax2.Color = 'none';
if isscalar(Bars2)
	Bars2.FaceColor = 'flat';
	Bars2.CData = colors;
else
	for kB = 1:numel(Bars2)
		Bars2(kB).FaceColor = colors(kB, :);
	end
end
for kB = 1:numel(Bars2)
	Bars2(kB).BarWidth = 0.5;
	Bars2(kB).EdgeColor = 'none';
	Bars2(kB).FaceAlpha = 1;
end
if istable(ErrorBars2) && ~isempty(ErrorBars2) && ismember('Object', ErrorBars2.Properties.VariableNames)
	for kE = 1:height(ErrorBars2)
		eb = ErrorBars2.Object(kE);
		if isgraphics(eb) && kE <= size(colors, 1)
			eb.Color = colors(kE, :);
		end
	end
end
% multcompare 不感知非配对口径，PText 覆盖为 rank-sum p
if isfield(Opt2, 'MultiCompare') && istable(Opt2.MultiCompare) && ismember('PText', Opt2.MultiCompare.Properties.VariableNames)
	mc2 = Opt2.MultiCompare;
	if height(mc2) ~= size(pairIdx, 1)
		error('Fig1_ThreeGroup:PTextMismatch', 'PText 行数(%d)与比较对数(%d)不一致。', height(mc2), size(pairIdx, 1));
	end
	for ip = 1:height(mc2)
		pt = mc2.PText(ip);
		if isgraphics(pt)
			pt.String = iFormatP(pFirst(ip));
			pt.Tag = 'PText';
		end
	end
end
ylabel(ax2, 'Hit rate');
title(ax2, 'First block', 'FontWeight', 'normal');
legend(ax2, 'off');
box(ax2, 'off');
if isprop(ax2, 'Toolbar') && ~isempty(ax2.Toolbar)
	ax2.Toolbar.Visible = 'off';
end
svgInset = TransferLearning.ExportStandardFigureTransparent(f2, 2, 'Fig1_ThreeGroupLightWaterFirstBlock_Inset.svg');
fprintf('Wrote: %s\n', svgInset);

% ---------- 统计与表格 ----------
curveTable = table;
curveTable.Block = x;
for k = 1:numel(groupOrder)
	curveTable.(groupOrder(k) + "_Mean") = meanMat(:, k);
	curveTable.(groupOrder(k) + "_Sem") = semMat(:, k);
	curveTable.(groupOrder(k) + "_N") = nMat(:, k);
end
writetable(curveTable, fullfile(outDir, 'Fig1_ThreeGroupLightWaterLearningCurve.csv'));

fitTable = table;
fitTable.Group = groupOrder(:);
fitTable.NMice = nMice(:);
fitTable.Lower = cellfun(@(s) s.Lower, fits)';
fitTable.Upper = cellfun(@(s) s.Upper, fits)';
fitTable.Slope = cellfun(@(s) s.Slope, fits)';
fitTable.Midpoint = cellfun(@(s) s.Midpoint, fits)';
fitTable.RSquared = cellfun(@(s) s.RSquared, fits)';
writetable(fitTable, fullfile(outDir, 'Fig1_ThreeGroupLightWaterLearningCurveFit.csv'));

firstTable = table;
firstTable.Pair = strings(size(pairIdx, 1), 1);
for iPair = 1:size(pairIdx, 1)
	firstTable.Pair(iPair) = groupOrder(pairIdx(iPair, 1)) + "_vs_" + groupOrder(pairIdx(iPair, 2));
end
firstTable.RanksumP = pFirst;
firstTable.PerMouseHalfBlockRanksumP = pSlope;
firstTable.GroupEffectP_Block1to7 = repmat(pGroup7, size(pairIdx, 1), 1);
writetable(firstTable, fullfile(outDir, 'Fig1_ThreeGroupLightWaterFirstBlock.csv'));

thisFile = [mfilename('fullpath'), '.m'];
copyfile(thisFile, fullfile(outDir, 'Fig1_ThreeGroupLightWaterLearningCurve.m'));

fprintf('\n=== Fig1 three-group LightWater learning curve ===\n');
for k = 1:numel(groupOrder)
	fprintf('%s: n = %d mice, %d blocks max, sigmoid slope = %.3f, R2 = %.3f\n', ...
		groupOrder(k), nMice(k), sum(isfinite(meanMat(:, k))), fits{k}.Slope, fits{k}.RSquared);
	sv = perMouseHalf{k};
	fprintf('  first block = %.3f +/- %.3f; blocks to 50%% = %.2f +/- %.2f (n = %d)\n', ...
		mean(xFirst{k}), std(xFirst{k}) / sqrt(numel(xFirst{k})), mean(sv), std(sv) / sqrt(numel(sv)), numel(sv));
end
fprintf('LME group effect (blocks 1-7) p = %.4g\n', pGroup7);
for iPair = 1:size(pairIdx, 1)
	fprintf('%s vs %s: first block ranksum p = %.4g; blocks-to-50%% ranksum p = %.4g\n', ...
		groupOrder(pairIdx(iPair, 1)), groupOrder(pairIdx(iPair, 2)), pFirst(iPair), pSlope(iPair));
end

assignin('base', 'Fig1_ThreeGroupStats', struct('Group', groupOrder, 'NMice', nMice, ...
	'Slope', cellfun(@(s) s.Slope, fits), 'PGroup7', pGroup7, 'FirstBlock', {xFirst}, ...
	'PFirst', pFirst, 'PerMouseHalfBlock', perMouseHalf, 'PHalfBlock', pSlope));

%% ------------------------------------------------------------------
function S = iLightWaterSessions(DS, sourceName, startPhase, endPhase, excludeMice)
T = TransferLearning.BehaviorSessions.iQueryLightWaterBlocks(DS, false);
T.Mouse = string(T.Mouse);
if ~isempty(excludeMice)
	T = T(~ismember(T.Mouse, string(excludeMice)), :);
end
S = TransferLearning.BehaviorSessions.iSessionizeByDateTime(T);
S = iSelectPhaseRange(S, startPhase, endPhase);
S.Source = repmat(string(sourceName), height(S), 1);
end

function S = iSelectPhaseRange(S, startPhase, endPhase)
S.Mouse = string(S.Mouse);
S.Phase = string(S.Phase);
S = sortrows(S, {'Mouse', 'DateTime'});
mice = unique(S.Mouse);
keepRows = false(height(S), 1);
for i = 1:numel(mice)
	idx = find(S.Mouse == mice(i));
	ph = S.Phase(idx);
	st = find(ph == string(startPhase), 1, 'first');
	if isempty(st)
		continue;
	end
	ed = find(ph == string(endPhase) & (1:numel(ph))' >= st, 1, 'first');
	if isempty(ed)
		ed = numel(ph);
	end
	keepRows(idx(st:ed)) = true;
end
S = S(keepRows, :);
end

function badMice = iMiceWithStimulusInPhase(DS, stimulusName, phaseName)
T = DS.TableQuery("Mouse", Stimulus=stimulusName, Phase=phaseName);
if isempty(T)
	badMice = strings(0, 1);
else
	badMice = unique(string(T.Mouse));
end
end

function iAssertUniqueMouse(T)
[G, mice] = findgroups(T.Mouse);
nGroups = splitapply(@(x) numel(unique(string(x))), T.Group, G);
dup = mice(nGroups > 1);
if ~isempty(dup)
	error('Fig1_ThreeGroup:MouseInMultipleGroups', '以下小鼠同时出现在多个分组：%s', strjoin(dup', ', '));
end
[G2, mice2] = findgroups(T.Mouse);
nSources = splitapply(@(x) numel(unique(string(x))), T.Source, G2);
dup2 = mice2(nSources > 1);
if ~isempty(dup2)
	error('Fig1_ThreeGroup:DuplicateMouseAcrossSources', '以下小鼠在同一分组内出现于多个数据源：%s', strjoin(dup2', ', '));
end
end

function [meanMat, semMat, x] = iSummarize(sessionForSummary, groupOrder)
[summaryL, ~] = UniExp.LearningSummarize(sessionForSummary);
rowNames = string(summaryL.Properties.RowNames);
meanCells = summaryL.MeanCurve(:);
semCells = summaryL.SemCurve(:);
idx = zeros(1, numel(groupOrder));
for k = 1:numel(groupOrder)
	idx(k) = find(rowNames == groupOrder(k), 1, 'first');
	if isempty(idx(k))
		error('Fig1_ThreeGroup:MissingSummaryGroup', '学习总结中缺少分组 %s。', groupOrder(k));
	end
end
maxLen = max(cellfun(@(c) numel(c), meanCells(idx)));
meanMat = nan(maxLen, numel(groupOrder));
semMat = nan(maxLen, numel(groupOrder));
for k = 1:numel(groupOrder)
	mv = double(meanCells{idx(k)}(:));
	sv = double(semCells{idx(k)}(:));
	meanMat(1:numel(mv), k) = mv;
	semMat(1:numel(sv), k) = sv;
end
x = (1:maxLen).';
end

function nMat = iNBySession(allSessions, nBlocks, groupOrder)
nMat = zeros(nBlocks, numel(groupOrder));
for k = 1:numel(groupOrder)
	for s = 1:nBlocks
		rowsS = allSessions.Group == groupOrder(k) & double(allSessions.Session) == s & isfinite(double(allSessions.Performance));
		if any(rowsS)
			nMat(s, k) = numel(unique(allSessions.Mouse(rowsS)));
		end
	end
end
end

function c = iTrimCells(m, nMax)
c = cell(1, size(m, 2));
for k = 1:size(m, 2)
	last = find(isfinite(m(:, k)), 1, 'last');
	last = min([last, nMax]);
	if isempty(last)
		c{k} = nan(0, 1);
	else
		c{k} = m(1:last, k).';
	end
end
end

function T = iFirstBlockPerMouse(allSessions)
T = allSessions(allSessions.Session == 1, ["Group", "Mouse", "Performance"]);
T.Properties.VariableNames{'Performance'} = 'FirstPerf';
end

function T = iFilterToDisplayedMice(T)
% 纳入拟合的鼠需有 ≥2 个 block 且 ≥2 个不同 Performance（与 Fig1B / FigS1D 相同）
T.Mouse = string(T.Mouse);
mice = unique(T.Mouse, 'stable');
keep = false(height(T), 1);
for i = 1:numel(mice)
	r = T.Mouse == mice(i);
	y = double(T.Performance(r));
	y = y(isfinite(y));
	if numel(y) >= 2 && numel(unique(y)) >= 2
		keep(r) = true;
	end
end
T = T(keep, :);
end

function vals = iPerMouseHalfBlock(allSessions, groupOrder)
% 每鼠达到 50% 命中率所需的 block 数（相邻两点线性插值）；直到最后仍未达到者取末次 block + 1
vals = cell(1, numel(groupOrder));
for k = 1:numel(groupOrder)
	sub = allSessions(allSessions.Group == groupOrder(k), :);
	mice = unique(sub.Mouse);
	v = nan(numel(mice), 1);
	for i = 1:numel(mice)
		S = sortrows(sub(sub.Mouse == mice(i), :), 'Session');
		x = double(S.Session);
		y = double(S.Performance);
		use = isfinite(x) & isfinite(y);
		x = x(use);
		y = y(use);
		if isempty(x)
			continue;
		end
		ic = find(y >= 0.5, 1, 'first');
		if isempty(ic)
			v(i) = max(x) + 1;
		elseif ic == 1
			v(i) = x(1);
		else
			v(i) = x(ic - 1) + (0.5 - y(ic - 1)) / (y(ic) - y(ic - 1));
		end
	end
	vals{k} = v(isfinite(v));
end
end

function fitOut = iFitSigmoidCurve(T, groupName)
xObs = double(T.Session(:));
yObs = double(T.Performance(:));
use = isfinite(xObs) & isfinite(yObs);
xObs = xObs(use);
yObs = yObs(use);
if isempty(xObs)
	error('Fig1_ThreeGroup:NoDataForGroup', '分组 %s 没有可拟合的数据。', groupName);
end
p0 = [log(0.8); max(median(xObs), 1)];
obj = @(p) sum((yObs - iSigmoidFromParams(p, xObs)).^2, 'omitnan');
opt = optimset('Display', 'off', 'MaxFunEvals', 10000, 'MaxIter', 10000);
p = fminsearch(obj, p0, opt);
yHat = iSigmoidFromParams(p, xObs);
SSE = sum((yObs - yHat).^2, 'omitnan');
SST = sum((yObs - mean(yObs, 'omitnan')).^2, 'omitnan');
fitOut = struct;
fitOut.Group = string(groupName);
fitOut.ParamRaw = p;
[fitOut.Lower, fitOut.Upper, fitOut.Slope, fitOut.Midpoint] = iDecodeSigmoidParams(p);
fitOut.SSE = SSE;
if SST == 0
	fitOut.RSquared = NaN;
else
	fitOut.RSquared = 1 - SSE / SST;
end
end

function y = iSigmoidFromParams(p, x)
[~, ~, slope, midpoint] = iDecodeSigmoidParams(p);
y = 1 ./ (1 + exp(-slope .* (x - midpoint)));
end

function [lower, upper, slope, midpoint] = iDecodeSigmoidParams(p)
% 下渐近线固定 0、上渐近线固定 1（与 Fig1B / FigS1D 同一口径），p = [log(slope); midpoint]
lower = 0;
upper = 1;
slope = exp(p(1));
midpoint = p(2);
end

function y = iLogit(x)
x = min(max(x, 1e-6), 1 - 1e-6);
y = log(x ./ (1 - x));
end

function s = iFormatP(p)
if ~isfinite(p)
	s = 'n.s.';
elseif p < 0.001
	s = '***';
elseif p < 0.01
	s = '**';
elseif p < 0.05
	s = '*';
else
	s = 'n.s.';
end
end
