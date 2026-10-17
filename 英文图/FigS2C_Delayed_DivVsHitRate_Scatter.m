% English FigS2C: first-block hit rate vs divergence（延迟任务版）——模仿英文图1F
% （英文图/Fig1F_DivVsHitRate_Scatter.m），Naive/Transfer 两组散点 + 合并拟合线。
%
% 数据源（均取每鼠首个光水训练会话，只取 LightLearnWater 回合）：
%   Naive    = TransferLearning.LADelayed（有延迟光声钙成像，光水转声水，延迟任务）
%              每鼠首个含 LightLearnWater 的会话（本库无 Phase 列；LA 范式光水在前，
%              该会话即光水学习初始 = Naive 首次）。
%   Transfer = TransferLearning.ALDelayed（有延迟不舔不给水钙成像，声水转光水，延迟任务）
%              每鼠首个含 LightLearnWater 的会话（= 声水学习后的首次光水 = Transfer 首块），
%              同英文图/ALDelayed_DivVsHitRate_Scatter.m 的会话定义。
%
% 与英文图1F 的口径差别（其余完全一致）：
%   1) 散度取样点用 cue +1.5 s（延迟任务的反应/名义给水时刻）而非 1F 的 +1 s；
%   2) 排除 Always 给水的 trial：命中率与散度只算 LightLearnWater 回合，
%      LightLearnWaterAlways（总是给水）不参与。
% 散度定义同 Fig1F：z-score 后逐回合减 cue onset 值，取指定时刻的 细胞×回合 矩阵 X，
% div = sqrt( sum(var(X,[],2)) / sum(mean(X,2).^2) )。
% 相关性：Spearman（Naive + Transfer 全体合并，同 Fig1F 单拟合线）。
%
% Output (SVG):
%   - English_FigS2C_Delayed_DivVsHitRate_Scatter.svg
%
% Execution (hard requirement):
% - Keep this file as a script (do NOT convert to function).
% - Open in MATLAB Editor and Run/F5.

if ~exist('TransferLearning', 'class') || ~exist('UniExp.DataSet', 'class')
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

xs = TransferLearning.Xs;
if isduration(xs)
	xsSec = seconds(xs);
else
	xsSec = double(xs);
end
[idx0, ok0] = iFindTimeIndex(xsSec, 0, 0.25);
[idx15, ok15] = iFindTimeIndex(xsSec, 1.5, 0.25);
if ~ok0 || ~ok15
	error('FigS2C:TimeIndexMissing', 'Cannot find 0 s or 1.5 s sample in TransferLearning.Xs.');
end

naive = iCollectFirstSessionData(TransferLearning.LADelayed(), "Naive", "LADelayed", idx0, idx15);
transfer = iCollectFirstSessionData(TransferLearning.ALDelayed(), "Transfer", "ALDelayed", idx0, idx15);

Data = [naive; transfer];
Data.Group = categorical(string(Data.Group), ["Naive", "Transfer"]);

colorNaive = TransferLearning.NaiveColor;
colorTransfer = TransferLearning.TransferColor;
colorFit = TransferLearning.ColorA;

use = isfinite(Data.Divergence) & isfinite(Data.HitRate);
if nnz(use) < 3
	error('FigS2C:TooFewPoints', 'Too few valid mice for correlation (got %d).', nnz(use));
end
xAll = Data.Divergence(use);
yAll = Data.HitRate(use);
if std(xAll) <= 0 || std(yAll) <= 0
	error('FigS2C:ZeroVariance', 'All mice have zero variance for correlation.');
end
[rho, p] = corr(xAll, yAll, 'Type', 'Spearman');

maskNaive = use & (string(Data.Group) == "Naive");
maskTran = use & (string(Data.Group) == "Transfer");

% ---------- figure（模仿英文图1F：6×8 cm，Scale=2） ----------
f = figure('Color', 'w', 'Name', 'English FigS2C Delayed first-block hit rate vs divergence');
f.Units = 'centimeters';
f.Position(3:4) = [6, 8];
f.PaperUnits = 'centimeters';
f.PaperPositionMode = 'manual';
f.PaperPosition = [0, 0, 6, 8];
f.PaperSize = [6, 8];

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

scatterMarker = 'o';
scatterSize = 5;
hN = scatter(ax, Data.Divergence(maskNaive), Data.HitRate(maskNaive), scatterSize, colorNaive, scatterMarker, 'filled', 'LineWidth', 0.2);
hT = scatter(ax, Data.Divergence(maskTran), Data.HitRate(maskTran), scatterSize, colorTransfer, scatterMarker, 'filled', 'LineWidth', 0.2);
ylabel(ax, 'First block hit rate', 'FontSize', 12);

fitP = polyfit(xAll, yAll, 1);
xFit = [min(xAll), max(xAll)];
plot(ax, xFit, polyval(fitP, xFit), '-', 'Color', colorFit, 'LineWidth', 2);

lgd = legend(ax, [hN, hT], {'Naive', 'Transfer'}, 'Location', 'northoutside', 'Orientation', 'horizontal');
lgd.FontSize = 12;
lgd.Box = 'off';

iText(ax, 0.97, 0.97, iPLabel(p), 'Units', 'normalized', ...
	'HorizontalAlignment', 'right', 'VerticalAlignment', 'top', 'FontSize', 12);
title('💡💧')

fprintf('\n=== FigS2C (delayed) first-block hit rate vs divergence (cue +1.5 s, LightLearnWater only) ===\n');
disp(Data);
fprintf('Naive mice: %d\nTransfer mice: %d\n', nnz(maskNaive), nnz(maskTran));
fprintf('Spearman rho=%.3f, p=%.4g (n=%d mice, pooled)\n', rho, p, nnz(use));

svgPath = TransferLearning.ExportStandardFigure(f, 2, 'English_FigS2C_Delayed_DivVsHitRate_Scatter.svg');
fprintf('Wrote: %s\n', svgPath);

assignin('base', 'FigS2C_FirstSessionData', Data);
assignin('base', 'FigS2C_Stats', table(rho, p, nnz(maskNaive), nnz(maskTran), ...
	'VariableNames', {'Rho', 'PValue', 'NNaive', 'NTransfer'}));

%% ========== local functions（口径同英文图1F / ALDelayed_DivVsHitRate_Scatter） ==========
function out = iCollectFirstSessionData(DS, groupName, sourceName, idx0, idx15)
% 每鼠首个含 LightLearnWater 的会话（Always 回合不取），命中率 + cue+1.5 s 散度各一行。
out = iEmptyOutputTable();
T = DS.TableQuery(["Mouse", "DateTime", "TrialUID", "TrialIndex", "Behavior", "Stimulus"]);
T.Mouse = string(T.Mouse);
T.Stimulus = string(T.Stimulus);
T = T(T.Stimulus == "LightLearnWater", :);
if isempty(T)
	return;
end
mice = unique(T.Mouse);
Rows = cell(numel(mice), 1);
for i = 1:numel(mice)
	m = mice(i);
	Tm = T(T.Mouse == m, :);
	dt = min(Tm.DateTime);
	Ts = sortrows(Tm(Tm.DateTime == dt, :), 'TrialIndex');
	Rows{i} = iSessionRow(DS, m, dt, Ts, groupName, sourceName, idx0, idx15);
end
out = vertcat(Rows{:});
end

function row = iSessionRow(DS, mouseName, dt, SessTbl, groupName, sourceName, idx0, idx15)
row = iEmptyOutputTable();
trialUIDs = unique(uint64(SessTbl.TrialUID), 'stable');
if numel(trialUIDs) < 2
	return;
end
beh = double(SessTbl.Behavior);
beh = beh(isfinite(beh));
if isempty(beh)
	return;
end
hitRate = mean(beh);
nts = DS.QueryNTS(struct('Stimulus', "LightLearnWater", 'Mouse', mouseName, 'DateTime', dt), UniExp.Flags.ZScore, 1:24);
if iscell(nts)
	nts = nts{1};
end
if isempty(nts)
	return;
end
[ctt, ~] = iBuildCTT(nts, trialUIDs, idx0);
if isempty(ctt) || size(ctt, 2) < 2
	return;
end
xAt15 = ctt(:, :, idx15);
divValue = iAllCellDivergence(xAt15);
row = table(string(mouseName), string(groupName), double(hitRate), double(divValue), ...
	iNormalizeDateTime(dt), string(sourceName), ...
	'VariableNames', {'Mouse', 'Group', 'HitRate', 'Divergence', 'DateTime', 'Source'});
end

function div = iAllCellDivergence(xAt15)
if size(xAt15, 1) < 3
	div = NaN;
	return;
end
X = xAt15;
totalSignal = sum(mean(X, 2).^2);
totalNoise = sum(var(X, [], 2));
if totalSignal > 0
	div = sqrt(totalNoise / totalSignal);
else
	div = NaN;
end
end

function [ctt, cellUIDs] = iBuildCTT(nts, trialUIDs, idx0)
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

function T = iEmptyOutputTable()
T = table(string.empty(0, 1), string.empty(0, 1), nan(0, 1), nan(0, 1), NaT(0, 1), string.empty(0, 1), ...
	'VariableNames', {'Mouse', 'Group', 'HitRate', 'Divergence', 'DateTime', 'Source'});
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
else
	txt = sprintf('p = %.3f', p);
end
end

function iText(ax, x, y, txt, varargin)
text(ax, x, y, txt, varargin{:});
end
