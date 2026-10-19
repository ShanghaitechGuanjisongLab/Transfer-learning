% English FigS3B: sigmoid learning slope vs response heterogeneity on ALDelayed
% （英文图/Fig1H_SlopeVsHeterogeneity 的 Delayed 版；用户裁定只用 ALDelayed 单组，
% 不画 Naive/Transfer 对比——LADelayed 目前仅 1 个光水会话拟合不出学习斜率）。
%
% Slope: 每鼠全部 LightLearnWater 会话 block hit rate 的 sigmoid 拟合（同 Fig1H/Fig1G 管线，
%   会话定义适配 ALDelayed：无 Phase 列，全部 LightLearnWater 会话 = 迁移→学会 span；
%   LightLearnWaterAlways 总是给水不参与）。
% Response heterogeneity: Fig1I 度量（逐鼠逐层）——每细胞每会话 median z@+1.5 s
%   （延迟任务名义给水时刻，Fig1H 的 1.0 s 延迟版）→ 每细胞跨会话均值 → 过滤 [-1,1] →
%   细胞间 std。会话 = 全部 LightLearnWater 会话。
% 面板：1×2（L2/3 | L5），x = response heterogeneity，y = sigmoid slope；
%   散点单色（TransferColor，方块同 Fig1H 的 Transfer 记号）+ 灰拟合线 + 右上角 p（Spearman）。
%
% Outputs (SVG):
%   - English_FigS3B_Delayed_SlopeVsHeterogeneity.svg
%
% Execution (hard requirement):
% - Keep this file as a script (do NOT convert to function).
% - Open in MATLAB Editor and Run/F5.

thisDir = fileparts(mfilename('fullpath'));
if ~exist('UniExp.DataSet', 'class')
	prjFile = fullfile(thisDir, '..', 'Transferlearning.prj');
	if exist(prjFile, 'file')
		matlab.project.loadProject(prjFile);
	end
end

DS = TransferLearning.ALDelayed();
CellMap = DS.Cells;
CellMap.Mouse = string(CellMap.Mouse);
CellMap.CellUID = uint64(CellMap.CellUID);
CellMap.ZLayer = string(CellMap.ZLayer);

xs = TransferLearning.Xs;
if isduration(xs)
	xsSec = seconds(xs);
else
	xsSec = double(xs);
end
[idxT, okT] = iFindTimeIndex(xsSec, 1.5, 0.25);
if ~okT
	error('FigS3B:No15s', 'Cannot find sample close to 1.5 s in time axis.');
end

% ---- Slope：全部 LightLearnWater 会话的 sigmoid（同 Fig1H 管线） ----
blocks = iLightLearnBlocksByMouse(DS);
blocks = sortrows(blocks, ["Mouse", "DateTime"]);
blocks = iAddBlockIndex(blocks);
sigmoidFitTable = iFitSigmoidPerMouse(blocks);
if isempty(sigmoidFitTable)
	error('FigS3B:NoSigmoidFits', 'No per-mouse sigmoid fit could be computed.');
end

% ---- Heterogeneity：Fig1I 度量，逐鼠逐层（全部 LightLearnWater 会话） ----
layers = ["MOp2/3"; "MOp5"];
layerLabels = ["L2/3"; "L5"];
SessUsed = iLightLearnSessions(DS);
[hetTbl, hetMice] = iMouseAvgSDByLayer(DS, CellMap, SessUsed, idxT, layers);
fprintf('FigS3B: slope mice = %d, heterogeneity mice = %d\n', height(sigmoidFitTable), numel(hetMice));

colorP = TransferLearning.TransferColor;
colorFit = [0.5 0.5 0.5];

f = figure('Color', 'w', 'Name', 'English FigS3B delayed Slope vs Heterogeneity');
f.Units = 'centimeters';
f.Position(3:4) = [12, 8];
f.PaperUnits = 'centimeters';
f.PaperSize = [12, 8];
f.PaperPositionMode = 'auto';

tl = tiledlayout(f, 1, 2, 'TileSpacing', 'tight', 'Padding', 'tight');
xlabel(tl, 'Response heterogeneity', 'FontSize', 12);
axAll = gobjects(numel(layers), 1);

for iL = 1:numel(layers)
	layerName = layers(iL);
	layerLabel = layerLabels(iL);
	het = hetTbl.SD(hetTbl.Layer == layerName);
	miceL = hetTbl.Mouse(hetTbl.Layer == layerName);
	[tf, loc] = ismember(miceL, sigmoidFitTable.Mouse);
	slope = nan(numel(miceL), 1);
	slope(tf) = sigmoidFitTable.Slope(loc(tf));
	use = isfinite(slope) & isfinite(het);
	xU = het(use);
	yU = slope(use);

	if numel(xU) >= 3 && std(xU) > 0 && std(yU) > 0
		[rho, p] = corr(xU, yU, 'Type', 'Spearman');
	else
		rho = NaN;
		p = NaN;
	end
	fprintf('\n=== FigS3B (Delayed) %s ===\n', layerLabel);
	fprintf('mice: %d | Spearman rho=%.3f, p=%.4g\n', numel(xU), rho, p);

	ax = nexttile(tl, iL);
	hold(ax, 'on');
	ax.FontSize = 12;
	ax.LineWidth = 2;
	box(ax, 'off');
	scatter(ax, xU, yU, 10, colorP, 's', 'filled', 'LineWidth', 0.2);
	if iL == 1
		ylabel(ax, 'Sigmoid slope', 'FontSize', 12);
	else
		ax.YAxis.Visible = 'off';
	end
	if numel(xU) >= 2 && std(xU) > 0
		fitP = polyfit(xU, yU, 1);
		xFitLine = [min(xU), max(xU)];
		plot(ax, xFitLine, polyval(fitP, xFitLine), '-', 'Color', colorFit, 'LineWidth', 2);
	end
	title(ax, layerLabel, 'FontSize', 12);
	text(ax, 0.97, 0.97, iPLabel(p), 'Units', 'normalized', 'HorizontalAlignment', 'right', ...
		'VerticalAlignment', 'top', 'FontSize', 12);
	if isprop(ax, 'Toolbar') && ~isempty(ax.Toolbar)
		ax.Toolbar.Visible = 'off';
	end
	axAll(iL) = ax;
end

% 同 Fig1H：先结算导出样式（padding 生效），再统一 Y 轴跨度，导出时不再触发重算
TransferLearning.ApplyStandardExportStyle(f, 2);
MATLAB.Graphics.UnifyAxesLims(axAll(:), @ylim);
svgPath = TransferLearning.ExportStandardFigure(f, 2, 'English_FigS3B_Delayed_SlopeVsHeterogeneity.svg');
fprintf('Wrote: %s\n', svgPath);

assignin('base', 'FigS3B_Delayed_SlopeHet', struct('Heterogeneity', hetTbl, 'Slope', sigmoidFitTable));

%% ========== local functions（斜率同 Fig1G/Fig1H；异质性同 Fig1I，会话定义适配 ALDelayed） ==========
function Sess = iLightLearnSessions(DS)
% 全部 LightLearnWater 会话（每会话 Performance = LightLearnWater 回合 hit 均值；Always 不参与）。
Sess = table(string.empty(0, 1), NaT(0, 1), nan(0, 1), 'VariableNames', {'Mouse', 'DateTime', 'Performance'});
T = DS.TableQuery(["Mouse","DateTime","TrialUID","TrialIndex","Behavior","Stimulus"]);
if isempty(T)
	return;
end
T.Mouse = string(T.Mouse);
T.Stimulus = string(T.Stimulus);
T.DateTime = iNormalizeDateTime(T.DateTime);
T = T(T.Stimulus == "LightLearnWater", :);
[G, mouseList, dtList] = findgroups(T.Mouse, T.DateTime);
val = double(T.Behavior);
perf = splitapply(@(x) mean(x, 'omitnan'), val, G);
S = table(mouseList, dtList, perf, 'VariableNames', {'Mouse', 'DateTime', 'Performance'});
Sess = S(isfinite(S.Performance), :);
end

function out = iLightLearnBlocksByMouse(DS)
out = iLightLearnSessions(DS);
end

function [outTbl, miceOut] = iMouseAvgSDByLayer(DS, CellMap, SessUsed, idxT, layers)
% Fig1I 的 iDMouseAvgByLayerSingleSource 口径：每细胞每会话 median z@idxT →
% 每细胞跨会话均值 → 过滤 [-1,1] → 细胞间 std（逐鼠逐层）。
outTbl = table(strings(0, 1), strings(0, 1), nan(0, 1), nan(0, 1), 'VariableNames', {'Mouse', 'Layer', 'SD', 'NCells'});
miceOut = string.empty(0, 1);
if isempty(SessUsed)
	return;
end
miceIn = unique(string(SessUsed.Mouse));
dts = unique(SessUsed.DateTime);
try
	ntsCell = DS.QueryNTS(struct('Stimulus', "LightLearnWater", 'DateTime', dts), UniExp.Flags.ZScore, 1:24, 'ExtraColumns', ["DateTime"]);
catch
	return;
end
if isempty(ntsCell) || isempty(ntsCell{1})
	return;
end
rawTbl = ntsCell{1};
rawTbl.CellUID = uint64(rawTbl.CellUID);
rawTbl.DateTime = iNormalizeDateTime(datetime(rawTbl.DateTime));
[~, loc] = ismember(rawTbl.CellUID, CellMap.CellUID);
rawTbl.ZLayer = strings(height(rawTbl), 1);
has = loc > 0;
rawTbl.ZLayer(has) = CellMap.ZLayer(loc(has));
sig = double(rawTbl.TrialSignal);
zT = sig(:, idxT);

[G1, cellU1, dtU1, zLayer1] = findgroups(rawTbl.CellUID, rawTbl.DateTime, string(rawTbl.ZLayer));
medT = splitapply(@(x) median(x, 'omitnan'), zT, G1);

dtMouse = SessUsed(:, {'DateTime', 'Mouse'});
dtMouse.Mouse = string(dtMouse.Mouse);
[~, iU] = unique(dtMouse.DateTime);
dtMouse = dtMouse(iU, :);

medTbl = table(cellU1, dtU1, zLayer1, medT, 'VariableNames', {'CellUID', 'DateTime', 'ZLayer', 'Med'});
medTbl = innerjoin(medTbl, dtMouse, 'Keys', 'DateTime');

rows = [];
for iM = 1:numel(miceIn)
	for iL = 1:numel(layers)
		layerName = layers(iL);
		R = medTbl(string(medTbl.Mouse) == miceIn(iM) & string(medTbl.ZLayer) == layerName, :);
		if isempty(R)
			continue;
		end
		[~, ~, cellID] = unique(R.CellUID);
		meanPerCell = accumarray(cellID, R.Med, [], @mean);
		vals = meanPerCell(isfinite(meanPerCell) & meanPerCell >= -1 & meanPerCell <= 1);
		if numel(vals) >= 3
			rows = [rows; {miceIn(iM), layerName, std(vals), numel(vals)}]; %#ok<AGROW>
		end
	end
end
if isempty(rows)
	return;
end
outTbl = cell2table(rows, 'VariableNames', {'Mouse', 'Layer', 'SD', 'NCells'});
outTbl.Mouse = string(outTbl.Mouse);
outTbl.Layer = string(outTbl.Layer);
outTbl.SD = double(outTbl.SD);
outTbl.NCells = double(outTbl.NCells);
miceOut = unique(outTbl.Mouse);
end

function T = iAddBlockIndex(T)
T.Mouse = string(T.Mouse);
T = sortrows(T, {'Mouse', 'DateTime'});
[G, ~] = findgroups(T.Mouse);
sessCell = splitapply(@(x) {(1:numel(x))'}, T.DateTime, G);
T.Block = vertcat(sessCell{:});
end

function fitTable = iFitSigmoidPerMouse(T)
T = sortrows(T, {'Mouse', 'DateTime'});
mice = unique(string(T.Mouse), 'stable');
slopeVec = nan(numel(mice), 1);
keep = false(numel(mice), 1);
for iMouse = 1:numel(mice)
	mouseTable = T(string(T.Mouse) == mice(iMouse), :);
	mouseTable = sortrows(mouseTable, 'DateTime');
	finiteRows = isfinite(double(mouseTable.Block)) & isfinite(double(mouseTable.Performance));
	mouseTable = mouseTable(finiteRows, :);
	if height(mouseTable) < 2
		continue;
	end
	if numel(unique(double(mouseTable.Performance))) < 2
		continue;
	end
	fitMouse = iFitSigmoidCurve(mouseTable);
	slopeVec(iMouse) = fitMouse.Slope;
	keep(iMouse) = true;
end
fitTable = table;
fitTable.Mouse = mice(keep);
fitTable.Slope = slopeVec(keep);
end

function fitOut = iFitSigmoidCurve(T)
xObs = double(T.Block(:));
yObs = double(T.Performance(:));
use = isfinite(xObs) & isfinite(yObs);
xObs = xObs(use);
yObs = yObs(use);
p0 = [iLogit(max(min(min(yObs), 0.45), 0.01)); log(0.8); max(median(xObs), 1)];
obj = @(p) sum((yObs - iSigmoidFromParams(p, xObs)).^2, 'omitnan');
opt = optimset('Display', 'off', 'MaxFunEvals', 10000, 'MaxIter', 10000);
p = fminsearch(obj, p0, opt);
[~, ~, slope, ~] = iDecodeSigmoidParams(p);
fitOut = struct('Slope', slope);
end

function y = iSigmoidFromParams(p, x)
[lower, upper, slope, midpoint] = iDecodeSigmoidParams(p);
y = lower + (upper - lower) ./ (1 + exp(-slope .* (x - midpoint)));
end

function [lower, upper, slope, midpoint] = iDecodeSigmoidParams(p)
lower = 1 ./ (1 + exp(-p(1)));
upper = 1;
slope = exp(p(2));
midpoint = p(3);
end

function y = iLogit(x)
x = min(max(x, 1e-6), 1 - 1e-6);
y = log(x ./ (1 - x));
end

function dt = iNormalizeDateTime(dt)
dt = datetime(dt);
if ~isempty(dt.TimeZone)
	dt.TimeZone = '';
end
end

function [idx, ok] = iFindTimeIndex(xsSec, targetSec, tolSec)
[d, idx] = min(abs(xsSec(:) - targetSec));
ok = isfinite(d) && (d <= tolSec);
end

function txt = iPLabel(p)
if ~isfinite(p)
	txt = 'p = NaN';
elseif p < 0.001
	txt = 'p < 0.001';
elseif p < 0.01
	txt = sprintf('p = %.3f', p);
else
	txt = sprintf('p = %.2f', p);
end
end
