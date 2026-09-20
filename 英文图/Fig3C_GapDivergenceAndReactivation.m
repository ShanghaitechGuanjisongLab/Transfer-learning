% English Fig3C (merged, like Chinese Fig46D): two stacked bar tiles,
% No gap (AudioLightBaseline) vs 7-day gap (Vacation7)
%
%   Top tile:    inter-trial divergence at cue +1 s within the first transfer
%                light-water block (Figure 1 definition: sqrt(sum across cells
%                of trial-to-trial variance / sum of squared trial means));
%                cells missing data in any trial are excluded cell-wise so
%                that no mouse is dropped because of individual bad cells.
%   Bottom tile: reactivation probability P(transfer-active | learned-active)
%                at cue +1 s per mouse, from
%                iBuildProb_TransferGivenLearnedAudio_1s_PerMouseLayer
%                (RequireHitMiss = false), layer values combined by
%                learned-active cell counts (same as old Fig2N / Fig46D).
%
% Both comparisons: rank-sum (unpaired, different mice); for uniform reporting
% the BarScatterCompare PText is overwritten with the rank-sum p.
%
% Outputs (SVG):
%   - English_Fig3C_GapDivergenceAndReactivation.svg
%
% Execution (hard requirement):
% - Keep this file as a script (do NOT convert to function).
% - Open in MATLAB Editor and Run/F5.

if ~exist('UniExp.DataSet', 'class')
	thisDir = fileparts(mfilename('fullpath'));
	prjFile = fullfile(thisDir, '..', 'Transferlearning.prj');
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
[~, idx1s] = min(abs(xsSec - 1));

CtrlDS = TransferLearning.AudioLightBaseline();
V7DS = TransferLearning.Vacation7();

colorCtrl = TransferLearning.TransferColor;
colorGap = TransferLearning.ColorB;
palette2 = [colorCtrl; colorGap];
CompareGroup = table([1 2], 'VariableNames', {'GroupPair'});

% ---------- top tile data: divergence ----------
divCtrl = iGroupDivergence(CtrlDS, idx1s);
divV7 = iGroupDivergence(V7DS, idx1s);
[pDiv, ~] = ranksum(divCtrl, divV7);
fprintf('=== Fig3C top: population divergence (first transfer light-water block) ===\n');
fprintf('  No gap:    %.3f +/- %.3f (n = %d mice)\n', mean(divCtrl), iSem(divCtrl), numel(divCtrl));
fprintf('  7-day gap: %.3f +/- %.3f (n = %d mice)\n', mean(divV7), iSem(divV7), numel(divV7));
fprintf('  rank-sum p = %.4g\n', pDiv);

% ---------- bottom tile data: reactivation ----------
RCtrl = iBuildProb_TransferGivenLearnedAudio_1s_PerMouseLayer( ...
	DataSet = CtrlDS, Source = "AudioLightBaseline", RequireHitMiss = false);
RV7 = iBuildProb_TransferGivenLearnedAudio_1s_PerMouseLayer( ...
	DataSet = V7DS, Source = "Vacation7", RequireHitMiss = false);
if isempty(RCtrl) || isempty(RV7)
	error('English_Fig3C:EmptyBuild', 'Empty rows from P(T|L) builder.');
end
RCtrl.Group = repmat("Control", height(RCtrl), 1);
RV7.Group = repmat("Vacation7", height(RV7), 1);
R = [RCtrl; RV7];
R.Mouse = string(R.Mouse);

% 层合并：按 learned-active 细胞数加权（与中文图46D/旧Fig2N相同）
n23 = R.NLearnedActive23;
n5 = R.NLearnedActive5;
n23(~isfinite(n23)) = 0;
n5(~isfinite(n5)) = 0;
w23 = n23 .* R.Prob23;
w5 = n5 .* R.Prob5;
w23(~isfinite(w23)) = 0;
w5(~isfinite(w5)) = 0;
nTotal = n23 + n5;
R.PTgivenL = (w23 + w5) ./ nTotal;
R.PTgivenL(nTotal == 0) = NaN;

reactCtrlMask = R.Group == "Control" & isfinite(R.PTgivenL);
reactV7Mask = R.Group == "Vacation7" & isfinite(R.PTgivenL);
xCtrl = R.PTgivenL(reactCtrlMask);
xV7 = R.PTgivenL(reactV7Mask);
nReactCellsCtrl = sum(nTotal(reactCtrlMask), 'omitnan');
nReactCellsV7 = sum(nTotal(reactV7Mask), 'omitnan');
[pReact, ~] = ranksum(xCtrl, xV7);

fprintf('=== Fig3C bottom: Reactivation P(T|L) ===\n');
fprintf('  No gap:    mice n=%d, learned-active cells n=%d, mean=%.4f +/- %.4f\n', ...
	numel(xCtrl), nReactCellsCtrl, mean(xCtrl), iSem(xCtrl));
fprintf('  7-day gap: mice n=%d, learned-active cells n=%d, mean=%.4f +/- %.4f\n', ...
	numel(xV7), nReactCellsV7, mean(xV7), iSem(xV7));
fprintf('  rank-sum p = %.4g\n', pReact);

%% ---------- figure: 2 stacked tiles (中文图46D/Fig3J 样式) ----------
% 规范：两行 bar tile 例外，一般不放大；高 4 cm、宽 3 cm（2 bar ≤3 cm）
f = figure('Color', 'w', 'Name', 'English Fig3C gap divergence and reactivation');
f.Units = 'centimeters';
f.Position(3:4) = [3, 4];
f.PaperUnits = 'centimeters';
f.PaperPositionMode = 'manual';
f.PaperPosition = [0, 0, 3, 4];
f.PaperSize = [3, 4];

% 两行 tile + 旋转 x 标签：tight 外边距会把旋转标签裁出纸面，用 loose 留出标签空间
Layout = tiledlayout(f, 2, 1, 'TileSpacing', 'tight', 'Padding', 'loose');

% ---- Tile 1: Divergence ----
nexttile(Layout, 1);
[~, Opt1, Bars1, EB1] = UniExp.BarScatterCompare( ...
	{double(divCtrl(:)), double(divV7(:))}, UniExp.Flags.empty, CompareGroup, ...
	UniExp.Flags.IndividualErrorbars, 'AsteriskThreshold', 0.05);
ax1 = gca;
delete(findobj(ax1, 'Type', 'Scatter'));
iStyleBars(Bars1, palette2);
iStyleErrorBars(EB1, palette2);
iOverridePText(Opt1, pDiv);
ax1.XTick = [1 2];
ax1.XTickLabel = {};
ylabel(ax1, 'Divergence');
iStyleAxesCommon(ax1);

% ---- Tile 2: Reactivation ----
nexttile(Layout, 2);
[~, Opt2, Bars2, EB2] = UniExp.BarScatterCompare( ...
	{double(xCtrl(:)), double(xV7(:))}, UniExp.Flags.empty, CompareGroup, ...
	UniExp.Flags.IndividualErrorbars, 'AsteriskThreshold', 0.05);
ax2 = gca;
delete(findobj(ax2, 'Type', 'Scatter'));
iStyleBars(Bars2, palette2);
iStyleErrorBars(EB2, palette2);
iOverridePText(Opt2, pReact);
ax2.XTick = [1 2];
% 2-bar tile：加 3 个前导空格触发 MATLAB 自动旋转标签，免手工旋转
ax2.XTickLabel = {'   No gap', '   7-day gap'};
ylabel(ax2, 'Reactivation');
iStyleAxesCommon(ax2);

outDirUNC = fullfile('\\Data-Server-2\个人数据\张天夫', char(datetime('now', 'Format', 'yyyyMM')));
if ~isfolder(outDirUNC)
	mkdir(outDirUNC);
end
svgPath = TransferLearning.ExportStandardFigure(f, 1, 'English_Fig3C_GapDivergenceAndReactivation.svg');
fprintf('Wrote: %s\n', svgPath);

assignin('base', 'Fig3C_MergedStats', struct( ...
	'divCtrl', divCtrl, 'divV7', divV7, 'pDiv', pDiv, ...
	'reactCtrl', xCtrl, 'reactV7', xV7, 'pReact', pReact, ...
	'nReactCellsCtrl', nReactCellsCtrl, 'nReactCellsV7', nReactCellsV7));

%% ========== local functions ==========
function iStyleAxesCommon(ax)
legend(ax, 'off');
box(ax, 'off');
grid(ax, 'off');
ax.Color = 'none';
if isprop(ax, 'Toolbar') && ~isempty(ax.Toolbar)
	ax.Toolbar.Visible = 'off';
end
end

function iStyleBars(Bars, palette2)
if isscalar(Bars)
	Bars.FaceColor = 'flat';
	nB = numel(Bars.YData);
	Bars.CData = repmat(palette2, ceil(nB / 2), 1);
	Bars.CData = Bars.CData(1:nB, :);
	Bars.BarWidth = 0.5;
	Bars.FaceAlpha = 1;
	Bars.LineWidth = 1;
	Bars.BaseLine.LineWidth = 1;
	Bars.EdgeColor = 'none';
	return;
end
for kB = 1:numel(Bars)
	Bars(kB).FaceColor = palette2(kB, :);
	Bars(kB).BarWidth = 0.5;
	Bars(kB).FaceAlpha = 1;
	Bars(kB).LineWidth = 1;
	Bars(kB).BaseLine.LineWidth = 1;
	Bars(kB).EdgeColor = 'none';
end
end

function iStyleErrorBars(errorBars, palette2)
if ~(istable(errorBars) && ~isempty(errorBars) && ismember('Object', errorBars.Properties.VariableNames))
	return;
end
for iE = 1:height(errorBars)
	eb = errorBars.Object(iE);
	if ~isgraphics(eb)
		continue;
	end
	eb.LineWidth = 1;
	xData = double(eb.XData(:));
	xData = xData(isfinite(xData));
	if isempty(xData)
		continue;
	end
	[~, colorIndex] = min(abs((1:size(palette2, 1)).' - xData(1)));
	eb.Color = palette2(colorIndex, :);
end
end

function iOverridePText(Optional, p)
% anova/multcompare 口径之外统一报告 rank-sum p
if ~(isfield(Optional, 'MultiCompare') && istable(Optional.MultiCompare))
	return;
end
mc = Optional.MultiCompare;
if ~ismember('PText', mc.Properties.VariableNames)
	return;
end
for ip = 1:height(mc)
	pt = mc.PText(ip);
	if isgraphics(pt)
		pt.String = TransferLearning.Style.iFormatPText(p);
		pt.Tag = 'PText';
	end
end
if ismember('PLine', mc.Properties.VariableNames)
	for ip = 1:height(mc)
		pl = mc.PLine(ip);
		if isgraphics(pl)
			pl.Tag = 'PLine';
		end
	end
end
end

function s = iSem(v)
v = v(:);
ok = isfinite(v);
if ~any(ok)
	s = NaN;
	return;
end
s = std(v(ok)) / sqrt(sum(ok));
end

function div = iGroupDivergence(DS, idx1s)
% 每鼠首个 transfer light-water block 的群体 divergence（Fig1 定义）
T = DS.TableQuery(["Mouse", "DateTime", "TrialUID", "TrialIndex"], ...
	Phase = "Transfer", Stimulus = "LightWater");
T.Mouse = string(T.Mouse);
T.DateTime = datetime(T.DateTime);
if ~isempty(T.DateTime.TimeZone)
	T.DateTime.TimeZone = '';
end
mice = unique(T.Mouse);
div = nan(numel(mice), 1);
for i = 1:numel(mice)
	m = mice(i);
	Tm = T(T.Mouse == m, :);
	dt1 = min(Tm.DateTime);
	Tm = sortrows(Tm(Tm.DateTime == dt1, :), "TrialIndex");
	trialUIDs = unique(uint64(Tm.TrialUID), 'stable');
	if numel(trialUIDs) < 2
		continue;
	end
	nts = DS.QueryNTS(struct('Stimulus', "LightWater", 'Mouse', m), UniExp.Flags.ZScore, 1:24);
	if iscell(nts)
		parts = nts(~cellfun(@isempty, nts));
		if isempty(parts)
			continue;
		end
		nts = vertcat(parts{:});
	end
	if isempty(nts)
		continue;
	end
	X = iBuildCellTrialMatrix(nts, trialUIDs, idx1s);
	if isempty(X)
		continue;
	end
	% 只保留完整细胞（所有 trial 都有数据且有限值）；
	% 个别缺数据的细胞只剔除该细胞，不让 NaN 传导丢掉整鼠（同中文图46D的细胞过滤）
	X = X(all(isfinite(X), 2), :);
	if size(X, 1) < 3 || size(X, 2) < 2
		continue;
	end
	sig = sum(mean(X, 2).^2);
	noi = sum(var(X, [], 2));
	if sig > 0
		div(i) = sqrt(noi / sig);
	end
end
div = div(isfinite(div));
end

function X = iBuildCellTrialMatrix(nts, trialUIDs, idx1s)
% cells x trials 矩阵，元素 = 该细胞在该 trial 的 z@cue+1s
nts.CellUID = uint64(nts.CellUID);
nts.TrialUID = uint64(nts.TrialUID);
cellUIDs = unique(nts.CellUID, 'stable');
X = nan(numel(cellUIDs), numel(trialUIDs));
for iT = 1:numel(trialUIDs)
	rT = nts(nts.TrialUID == trialUIDs(iT), :);
	for iC = 1:numel(cellUIDs)
		rC = rT(rT.CellUID == cellUIDs(iC), :);
		if height(rC) == 1
			sig = double(rC.TrialSignal);
			X(iC, iT) = sig(idx1s);
		end
	end
end
end
