% English Fig1F mimic on ALDelayed: first-Light-block hit rate vs inter-trial divergence at cue +1.5 s.
% 数据源：TransferLearning.ALDelayed（有延迟不舔不给水钙成像，声水转光水，延迟任务）。
% 与英文图1F（英文图/Fig1F_DivVsHitRate_Scatter.m）口径一致：每鼠取首个 Light 训练会话（首个含 LightLearnWater 回合的 DateTime，本库无 Phase 列，等价 Transfer 首块），命中率=该会话 LightLearnWater 回合 Behavior 均值，散度=全体细胞 inter-trial 散度；唯一差别是散度取样点用 cue +1.5 s（延迟任务的反应时刻）而非 +1 s。
% 散度定义同 Fig1F：z-score 后逐回合减 cue onset 值，取指定时刻的 细胞×回合 矩阵 X，div = sqrt( sum(var(X,[],2)) / sum(mean(X,2).^2) )。
% 相关性：Spearman。

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

DS = TransferLearning.ALDelayed();

xs = TransferLearning.Xs;
if isduration(xs)
	xsSec = seconds(xs);
else
	xsSec = double(xs);
end
[idx0, ok0] = iFindTimeIndex(xsSec, 0, 0.25);
[idx15, ok15] = iFindTimeIndex(xsSec, 1.5, 0.25);
if ~ok0 || ~ok15
	error('ALDelayedDivHit:TimeIndexMissing', 'Cannot find 0 s or 1.5 s sample in TransferLearning.Xs.');
end

T = DS.TableQuery(["Mouse","DateTime","TrialUID","TrialIndex","Behavior","Stimulus"]);
T.Mouse = string(T.Mouse);
T.Stimulus = string(T.Stimulus);
T = T(T.Stimulus == "LightLearnWater", :);
if isempty(T)
	error('ALDelayedDivHit:NoLightTrials', 'No LightLearnWater trials found in ALDelayed.');
end

mice = unique(T.Mouse);
Rows = cell(numel(mice), 1);
for i = 1:numel(mice)
	m = mice(i);
	Tm = T(T.Mouse == m, :);
	dt = min(Tm.DateTime);
	Ts = sortrows(Tm(Tm.DateTime == dt, :), 'TrialIndex');
	Rows{i} = iSessionRow(DS, m, dt, Ts, idx0, idx15);
end
Data = vertcat(Rows{:});
Data = Data(isfinite(Data.HitRate) & isfinite(Data.Divergence), :);
if height(Data) < 3
	error('ALDelayedDivHit:TooFewPoints', 'Too few valid mice for correlation (got %d).', height(Data));
end

xAll = Data.Divergence;
yAll = Data.HitRate;
if std(xAll) <= 0 || std(yAll) <= 0
	error('ALDelayedDivHit:ZeroVariance', 'All mice have zero variance for correlation.');
end
[rho, p] = corr(xAll, yAll, 'Type', 'Spearman');

% ---------- figure（模仿英文图1F：6×8 cm，Scale=2） ----------
f = figure('Color', 'w', 'Name', 'ALDelayed First Light block hit rate vs divergence');
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

colorTransfer = TransferLearning.TransferColor;
colorFit = TransferLearning.ColorA;
hT = scatter(ax, xAll, yAll, 5, colorTransfer, 'o', 'filled', 'LineWidth', 0.2);
fitP = polyfit(xAll, yAll, 1);
xFit = [min(xAll), max(xAll)];
plot(ax, xFit, polyval(fitP, xFit), '-', 'Color', colorFit, 'LineWidth', 2);
ylabel(ax, 'First Light block hit rate', 'FontSize', 12);

lgd = legend(ax, hT, {'Transfer'}, 'Location', 'northoutside', 'Orientation', 'horizontal');
lgd.FontSize = 12;
lgd.Box = 'off';

iText(ax, 0.97, 0.97, iPLabel(p), 'Units', 'normalized', ...
	'HorizontalAlignment', 'right', 'VerticalAlignment', 'top', 'FontSize', 12);
title('💡💧')

fprintf('\n=== ALDelayed first-Light-block hit rate vs divergence (cue +1.5 s) ===\n');
disp(Data);
fprintf('Spearman rho=%.3f, p=%.4g (n=%d mice)\n', rho, p, height(Data));

svgPath = TransferLearning.ExportStandardFigure(f, 2, 'English_ALDelayed_DivVsHitRate_Scatter.svg');
fprintf('Wrote: %s\n', svgPath);

assignin('base', 'ALDelayed_DivVsHitRate_Data', Data);
assignin('base', 'ALDelayed_DivVsHitRate_Stats', table(rho, p, height(Data), 'VariableNames', {'Rho','PValue','NMice'}));

%% ========== local functions（口径同英文图1F） ==========
function row = iSessionRow(DS, mouseName, dt, SessTbl, idx0, idx15)
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
row = table(string(mouseName), double(hitRate), double(divValue), iNormalizeDateTime(dt), ...
	'VariableNames', {'Mouse','HitRate','Divergence','DateTime'});
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
T = table(string.empty(0, 1), nan(0, 1), nan(0, 1), NaT(0, 1), ...
	'VariableNames', {'Mouse','HitRate','Divergence','DateTime'});
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
