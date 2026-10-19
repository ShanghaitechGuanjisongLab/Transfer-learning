% English FigS3A: per-mouse divergence vs sigmoid learning slope on ALDelayed
% （英文图/Fig1G_DivergenceVsSlope_Scatter 的 Delayed 版；用户裁定只用 ALDelayed 单组，
% 不画 Naive/Transfer 对比——LADelayed 目前仅 1 个光水会话拟合不出学习斜率）。
%
% Divergence: 英文图/Fig1G 口径——每鼠首个 LightLearnWater 会话（transfer/光水学习首块；
%   LightLearnWaterAlways 总是给水不参与），cue-onset 逐回合相减后取 +1.5 s（延迟任务
%   名义给水时刻，Fig1G 的 1.0 s 延迟版）的 细胞×回合 矩阵，全部细胞（不分 2/5 层），
%   sqrt(trial-noise / signal)，QueryNTS ZScore 基线 1:24。
% Slope: Fig1G 的 sigmoid 管线——每鼠全部 LightLearnWater 会话的 block hit rate
%   （每会话 = 1 block）做 sigmoid 拟合（下界自由、上界=1），取 Slope。
% 相关：Spearman；散点单色（TransferColor）+ 线性拟合线（ColorA）+ 右上角 p。
%
% Outputs (SVG):
%   - English_FigS3A_Delayed_DivergenceVsSlope_Scatter.svg
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
xs = TransferLearning.Xs;
if isduration(xs)
	xsSec = seconds(xs);
else
	xsSec = double(xs);
end
[idx0, ok0] = iFindTimeIndex(xsSec, 0, 0.25);
[idxT, okT] = iFindTimeIndex(xsSec, 1.5, 0.25);
if ~ok0 || ~okT
	error('FigS3A:TimeIndexMissing', 'Cannot find 0 s or 1.5 s sample in TransferLearning.Xs.');
end

%% 1. Per-mouse divergence（首个 LightLearnWater 会话，Fig1G 口径）
DivData = iCollectFirstLightDiv(DS, idx0, idxT);
DivData = DivData(isfinite(DivData.Divergence), :);

%% 2. Per-mouse sigmoid slope over LightLearnWater sessions
blocks = iLightLearnBlocksByMouse(DS);
blocks = sortrows(blocks, ["Mouse", "DateTime"]);
blocks = iAddBlockIndex(blocks);
FitTbl = iFitSigmoidPerMouse(blocks);
if isempty(FitTbl)
	error('FigS3A:NoFits', 'No per-mouse sigmoid fit could be computed.');
end

%% 3. Join divergence + slope per mouse
DivData.Mouse = string(DivData.Mouse);
FitTbl.Mouse = string(FitTbl.Mouse);
[~, loc] = ismember(DivData.Mouse, FitTbl.Mouse);
DivData.Slope = nan(height(DivData), 1);
has = loc > 0;
DivData.Slope(has) = FitTbl.Slope(loc(has));
DivData = DivData(has & isfinite(DivData.Slope), :);
if height(DivData) < 2
	error('FigS3A:TooFewMice', 'Fewer than 2 mice with both divergence and slope.');
end

%% 4. Correlation + figure
colorP = TransferLearning.TransferColor;
colorFit = TransferLearning.ColorA;

xAll = double(DivData.Divergence);
yAll = double(DivData.Slope);
if std(xAll) <= 0 || std(yAll) <= 0
	error('FigS3A:ZeroVariance', 'All mice have zero variance for correlation.');
end
[rho, p] = corr(xAll, yAll, 'Type', 'Spearman');
fprintf('\n=== FigS3A (Delayed) Divergence vs Sigmoid slope ===\n');
fprintf('ALDelayed mice: %d\n', height(DivData));
fprintf('Spearman r=%.3f, p=%.4g\n', rho, p);
disp(DivData);

f = figure('Color', 'w', 'Name', 'English FigS3A delayed Divergence vs Sigmoid slope');
f.Units = 'centimeters';
f.Position(3:4) = [6, 8];

tl = tiledlayout(f, 1, 1, 'TileSpacing', 'compact', 'Padding', 'compact');
xl = xlabel(tl, 'Divergence');
xl.FontSize = 12;

ax = nexttile(tl, 1);
hold(ax, 'on');
box(ax, 'off');
ax.FontSize = 12;
ax.LineWidth = 2;
if isprop(ax, 'Toolbar') && ~isempty(ax.Toolbar)
	ax.Toolbar.Visible = 'off';
end
scatter(ax, DivData.Divergence, DivData.Slope, 5, colorP, 'o', 'filled', 'LineWidth', 0.2);
ylabel(ax, 'Sigmoid slope', 'FontSize', 12);
fitP = polyfit(xAll, yAll, 1);
xFit = [min(xAll), max(xAll)];
plot(ax, xFit, polyval(fitP, xFit), '-', 'Color', colorFit, 'LineWidth', 2);
text(ax, 0.97, 0.97, iPLabel(p), 'Units', 'normalized', 'HorizontalAlignment', 'right', ...
	'VerticalAlignment', 'top', 'FontSize', 12);

svgPath = TransferLearning.ExportStandardFigure(f, 2, 'English_FigS3A_Delayed_DivergenceVsSlope_Scatter.svg');
fprintf('Wrote: %s\n', svgPath);

assignin('base', 'FigS3A_Delayed_DivSlope', struct('Data', DivData, 'Rho', rho, 'PValue', p, 'Fit', FitTbl));

%% ========== local functions（散度口径同 Fig1G；斜率管线同 Fig1G，会话定义适配 ALDelayed） ==========
function out = iCollectFirstLightDiv(DS, idx0, idxT)
% 每鼠首个 LightLearnWater 会话（Always 不参与），cue-onset 相减后取 idxT 时刻全部细胞散度。
out = table(strings(0, 1), nan(0, 1), NaT(0, 1), 'VariableNames', {'Mouse', 'Divergence', 'DateTime'});
T = DS.TableQuery(["Mouse","DateTime","TrialUID","TrialIndex","Behavior","Stimulus"]);
if isempty(T)
	return;
end
T.Mouse = string(T.Mouse);
T.Stimulus = string(T.Stimulus);
T.DateTime = iNormalizeDateTime(T.DateTime);
T = T(T.Stimulus == "LightLearnWater", :);
mice = unique(T.Mouse);
for i = 1:numel(mice)
	m = mice(i);
	Tm = T(T.Mouse == m, :);
	dt = min(Tm.DateTime);
	Ts = sortrows(Tm(Tm.DateTime == dt, :), 'TrialIndex');
	trialUIDs = unique(uint64(Ts.TrialUID), 'stable');
	if numel(trialUIDs) < 2
		continue;
	end
	nts = DS.QueryNTS(struct('Stimulus', "LightLearnWater", 'Mouse', m, 'DateTime', dt), UniExp.Flags.ZScore, 1:24);
	if iscell(nts)
		nts = nts{1};
	end
	if isempty(nts)
		continue;
	end
	ctt = iBuildCTT(nts, trialUIDs, idx0);
	if isempty(ctt) || size(ctt, 2) < 2
		continue;
	end
	xAtT = ctt(:, :, idxT);
	if size(xAtT, 1) < 3
		continue;
	end
	totalSignal = sum(mean(xAtT, 2).^2);
	totalNoise = sum(var(xAtT, [], 2));
	if ~(totalSignal > 0)
		continue;
	end
	divValue = sqrt(totalNoise / totalSignal);
	out = [out; table(string(m), double(divValue), dt, 'VariableNames', {'Mouse', 'Divergence', 'DateTime'})]; %#ok<AGROW>
end
end

function [ctt, cellUIDs] = iBuildCTT(nts, trialUIDs, idx0)
% cells × trials × time（cue-onset 相减），同 Fig1G 的 iBuildCTT。
ctt = [];
cellUIDs = uint64([]);
keepTrial = ismember(uint64(nts.TrialUID), trialUIDs);
nts = nts(keepTrial, :);
if isempty(nts)
	return;
end
trialUIDs = trialUIDs(ismember(trialUIDs, unique(uint64(nts.TrialUID), 'stable')));
if numel(trialUIDs) < 2
	return;
end
allCells = unique(uint64(nts.CellUID), 'stable');
traceCell = cell(numel(allCells), 1);
keepUID = zeros(numel(allCells), 1, 'uint64');
nKeep = 0;
for iC = 1:numel(allCells)
	cid = allCells(iC);
	rows = uint64(nts.CellUID) == cid;
	uid = uint64(nts.TrialUID(rows));
	sig = double(nts.TrialSignal(rows, :));
	[tf, loc] = ismember(trialUIDs, uid);
	if ~all(tf)
		continue;
	end
	ordered = sig(loc, :);
	if any(~isfinite(ordered), 'all')
		continue;
	end
	nKeep = nKeep + 1;
	traceCell{nKeep} = ordered;
	keepUID(nKeep) = cid;
end
if nKeep < 1
	return;
end
traceCell = traceCell(1:nKeep);
keepUID = keepUID(1:nKeep);
nTrial = size(traceCell{1}, 1);
nTime = size(traceCell{1}, 2);
ctt = nan(nKeep, nTrial, nTime);
for iC = 1:nKeep
	ctt(iC, :, :) = traceCell{iC};
end
ctt = ctt - ctt(:, :, idx0);
cellUIDs = keepUID;
end

function out = iLightLearnBlocksByMouse(DS)
% 每鼠全部 LightLearnWater 会话 = block 序列（hit rate = 该会话 LightLearnWater 回合均值）。
out = table(string.empty(0, 1), NaT(0, 1), nan(0, 1), 'VariableNames', {'Mouse', 'DateTime', 'Performance'});
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
S = S(isfinite(S.Performance), :);
out = S;
end

function T = iAddBlockIndex(T)
T.Mouse = string(T.Mouse);
T = sortrows(T, {'Mouse', 'DateTime'});
[G, ~] = findgroups(T.Mouse);
sessCell = splitapply(@(x) {(1:numel(x))'}, T.DateTime, G);
T.Block = vertcat(sessCell{:});
end

function fitTable = iFitSigmoidPerMouse(T)
% 同 Fig1G：每鼠 sigmoid 拟合（≥2 个有效 block 且性能非恒定）。
T = sortrows(T, {'Mouse', 'DateTime'});
mice = unique(string(T.Mouse), 'stable');
slopeVec = nan(numel(mice), 1);
lowerVec = nan(numel(mice), 1);
upperVec = nan(numel(mice), 1);
midpointVec = nan(numel(mice), 1);
rSquaredVec = nan(numel(mice), 1);
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
	lowerVec(iMouse) = fitMouse.Lower;
	upperVec(iMouse) = fitMouse.Upper;
	slopeVec(iMouse) = fitMouse.Slope;
	midpointVec(iMouse) = fitMouse.Midpoint;
	rSquaredVec(iMouse) = fitMouse.RSquared;
	keep(iMouse) = true;
end
fitTable = table;
fitTable.Mouse = mice(keep);
fitTable.Lower = lowerVec(keep);
fitTable.Upper = upperVec(keep);
fitTable.Slope = slopeVec(keep);
fitTable.Midpoint = midpointVec(keep);
fitTable.RSquared = rSquaredVec(keep);
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
yHat = iSigmoidFromParams(p, xObs);
SSE = sum((yObs - yHat).^2, 'omitnan');
SST = sum((yObs - mean(yObs, 'omitnan')).^2, 'omitnan');
if SST == 0
	rSquared = NaN;
else
	rSquared = 1 - SSE / SST;
end
[lower, upper, slope, midpoint] = iDecodeSigmoidParams(p);
fitOut = struct('Lower', lower, 'Upper', upper, 'Slope', slope, 'Midpoint', midpoint, 'RSquared', rSquared);
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
