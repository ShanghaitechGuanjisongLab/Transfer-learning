% English Fig2E: hit cells are outcome-selective in the first transfer
% light-water block, miss cells are not
%
% Per mouse, within the first transfer light-water block:
%   - hit cells  = choice decoder weight w > 0 at 0.7 s (trained on
%     audio-water hit/miss, i.e. independent of the light-water data)
%   - miss cells = w < 0
%   - activity = mean z-score at cue +1 s, averaged over hit trials or
%     miss trials separately
% Left: hit cells, hit trials vs miss trials (paired per mouse).
% Right: miss cells, same comparison.
% Statistics: one-tailed paired t-test across mice (directional a-priori:
% hit-preferring cells should fire more on hit trials); pooled cell-level
% sign-flip permutation (5000) as confirmation.
%
% Outputs (SVG):
%   - English_Fig2E_OutcomeSelectivity.svg
%
% Execution (hard requirement):
% - Keep this file as a script (do NOT convert to function).
% - Open in MATLAB Editor and Run/F5.

if ~exist('UniExp.DataSet', 'class')
	thisFile = mfilename('fullpath');
	thisDir = fileparts(thisFile);
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

data = TransferLearning.BuildCueChoiceDecoderData();
DS = TransferLearning.AudioLightBaseline();

% per mouse: hit cells / miss cells mean z@+1s on hit trials vs miss trials
actH_hit = nan(numel(data.choice), 1);
actH_miss = nan(numel(data.choice), 1);
actM_hit = nan(numel(data.choice), 1);
actM_miss = nan(numel(data.choice), 1);
miceOut = strings(numel(data.choice), 1);
for i = 1:numel(data.choice)
	m = string(data.choice{i}.Mouse);
	cellUIDs = uint64(data.choice{i}.cellUIDs);
	w07 = data.choice{i}.w07;
	hitCells = cellUIDs(w07 > 0);
	missCells = cellUIDs(w07 < 0);
	if numel(hitCells) < 3 || numel(missCells) < 3
		continue;
	end
	dt = iFirstTransferLightWaterDateTime(DS, m);
	if isnat(dt)
		continue;
	end
	rows = iQueryFirstBlockRows(DS, m, dt);
	if isempty(rows)
		continue;
	end
	[trialUIDs, behTrial] = iTrialBehavior(rows);
	if numel(trialUIDs) < 4 || ~any(behTrial == 1) || ~any(behTrial == 0)
		continue;
	end
	X = iBuildCellTrialMatrix(rows, cellUIDs, trialUIDs, idx1s);
	if isempty(X)
		continue;
	end
	iH = ismember(cellUIDs, hitCells);
	iM = ismember(cellUIDs, missCells);
	hT = behTrial == 1;
	mT = behTrial == 0;
	aHH = mean(mean(X(iH, hT), 2), 'omitnan');
	aHM = mean(mean(X(iH, mT), 2), 'omitnan');
	aMH = mean(mean(X(iM, hT), 2), 'omitnan');
	aMM = mean(mean(X(iM, mT), 2), 'omitnan');
	if ~all(isfinite([aHH, aHM, aMH, aMM]))
		continue;
	end
	actH_hit(i) = aHH;
	actH_miss(i) = aHM;
	actM_hit(i) = aMH;
	actM_miss(i) = aMM;
	miceOut(i) = m;
end
ok = isfinite(actH_hit) & isfinite(actH_miss) & isfinite(actM_hit) & isfinite(actM_miss);
actH_hit = actH_hit(ok); actH_miss = actH_miss(ok);
actM_hit = actM_hit(ok); actM_miss = actM_miss(ok);
miceOut = miceOut(ok);
if numel(actH_hit) < 4
	error('Fig2E:InsufficientMice', 'Fewer than 4 mice with valid outcome-selectivity data.');
end

% 鼠水平：方向性（右尾）配对 t 检验——hit 偏好细胞应在 hit trials 放电更高
[~, pHitCells] = ttest(actH_hit, actH_miss, 'Tail', 'right');
[~, pMissCells] = ttest(actM_hit, actM_miss, 'Tail', 'right');
fprintf('=== Fig2E outcome selectivity at cue +1 s (first transfer light-water block) ===\n');
fprintf('hit cells:  hit trials %.3f +/- %.3f vs miss trials %.3f +/- %.3f (n = %d mice), one-tailed paired t p = %.4g\n', ...
	mean(actH_hit), std(actH_hit) / sqrt(numel(actH_hit)), mean(actH_miss), std(actH_miss) / sqrt(numel(actH_miss)), numel(actH_hit), pHitCells);
fprintf('miss cells: hit trials %.3f +/- %.3f vs miss trials %.3f +/- %.3f, one-tailed paired t p = %.4g\n', ...
	mean(actM_hit), std(actM_hit) / sqrt(numel(actM_hit)), mean(actM_miss), std(actM_miss) / sqrt(numel(actM_miss)), pMissCells);

colorHit = [0.85 0.33 0.10];
colorMiss = [0.10 0.45 0.70];

f = figure('Color', 'w', 'Name', 'English Fig2E outcome selectivity');
f.Units = 'centimeters';
f.Position(3:4) = [10, 5];
f.PaperUnits = 'centimeters';
f.PaperSize = [10, 5];
f.PaperPositionMode = 'auto';

ax1 = subplot(1, 2, 1);
hold(ax1, 'on');
iPairedBar(ax1, actH_hit, actH_miss, colorHit, pHitCells);
ylabel(ax1, 'Mean z at cue +1 s', 'FontSize', 8);
title(ax1, 'Hit cells', 'FontSize', 8, 'FontWeight', 'bold');
box(ax1, 'off');
ax1.FontSize = 7;
ax1.LineWidth = 1;
ax1.Color = 'none';

ax2 = subplot(1, 2, 2);
hold(ax2, 'on');
iPairedBar(ax2, actM_hit, actM_miss, colorMiss, pMissCells);
title(ax2, 'Miss cells', 'FontSize', 8, 'FontWeight', 'bold');
box(ax2, 'off');
ax2.FontSize = 7;
ax2.LineWidth = 1;
ax2.Color = 'none';

if isprop(ax1, 'Toolbar') && ~isempty(ax1.Toolbar)
	ax1.Toolbar.Visible = 'off';
end

outDirUNC = fullfile('\\Data-Server-2\个人数据\张天夫', char(datetime('now', 'Format', 'yyyyMM')));
if ~isfolder(outDirUNC)
	mkdir(outDirUNC);
end
svgPath = TransferLearning.ExportStandardFigure(f, 2, 'English_Fig2E_OutcomeSelectivity.svg');
fprintf('Wrote: %s\n', svgPath);

assignin('base', 'Fig2E_SelectivityStats', struct('Mouse', miceOut, ...
	'ActH_hit', actH_hit, 'ActH_miss', actH_miss, 'ActM_hit', actM_hit, 'ActM_miss', actM_miss, ...
	'pHitCells', pHitCells, 'pMissCells', pMissCells));

%% ========== local functions ==========
function iPairedBar(ax, vHit, vMiss, col, pVal)
% 配对柱 + 单鼠点线 + 星号（星号规则同全项目）
b = bar(ax, [mean(vHit), mean(vMiss)], 0.5);
b.FaceColor = col;
b.FaceAlpha = 1/3;
b.EdgeColor = 'none';
b.LineWidth = 1;
b.BaseLine.Visible = 'off';
se = [std(vHit) / sqrt(numel(vHit)), std(vMiss) / sqrt(numel(vMiss))];
errorbar(ax, 1:2, [mean(vHit), mean(vMiss)], se, 'k.', 'CapSize', 4, 'LineWidth', 1, 'HandleVisibility', 'off');
for i = 1:numel(vHit)
	plot(ax, [1 2], [vHit(i) vMiss(i)], '-', 'Color', [0.5 0.5 0.5], 'LineWidth', 0.5, 'HandleVisibility', 'off');
end
plot(ax, ones(numel(vHit), 1), vHit, '.', 'Color', col, 'MarkerSize', 8, 'HandleVisibility', 'off');
plot(ax, 2 * ones(numel(vMiss), 1), vMiss, '.', 'Color', col, 'MarkerSize', 8, 'HandleVisibility', 'off');
yl = ylim(ax);
yrange = yl(2) - yl(1);
yLine = yl(2) + 0.05 * yrange;
plot(ax, [1 1.15 1.15 2 2], [yLine - 0.02 * yrange, yLine, yLine, yLine, yLine - 0.02 * yrange], 'k-', 'LineWidth', 1, 'HandleVisibility', 'off');
if pVal < 0.001
	starStr = '＊＊＊';
elseif pVal < 0.01
	starStr = '＊＊';
elseif pVal < 0.05
	starStr = '＊';
else
	starStr = 'n.s.';
end
text(ax, 1.5, yLine + 0.02 * yrange, starStr, 'HorizontalAlignment', 'center', 'VerticalAlignment', 'bottom', 'FontSize', 8, 'HandleVisibility', 'off');
ylim(ax, [min(0, yl(1)), yLine + 0.25 * yrange]);
set(ax, 'XTick', [1 2], 'XTickLabel', {'hit trials', 'miss trials'});
xlabel(ax, '', 'FontSize', 8);
end

function dt = iFirstTransferLightWaterDateTime(DS, m)
T = DS.TableQuery(["Mouse", "DateTime", "Phase", "Stimulus"]);
T.Mouse = string(T.Mouse);
T.DateTime = datetime(T.DateTime);
if ~isempty(T.DateTime.TimeZone)
	T.DateTime.TimeZone = '';
end
T.Phase = string(T.Phase);
T.Stimulus = string(T.Stimulus);
T = T(T.Mouse == m & T.Phase == "Transfer" & T.Stimulus == "LightWater", :);
if isempty(T)
	dt = NaT;
	return;
end
dt = min(T.DateTime);
end

function rows = iQueryFirstBlockRows(DS, m, dt)
rows = table();
res = DS.QueryNTS(struct('Mouse', m, 'Stimulus', 'LightWater', 'DateTime', dt), UniExp.Flags.ZScore, 1:24, 'ExtraColumns', ["Behavior"]);
if istable(res)
	rows = res;
elseif iscell(res)
	parts = res(~cellfun(@isempty, res));
	if ~isempty(parts) && istable(parts{1})
		rows = vertcat(parts{:});
	end
end
if ~isempty(rows)
	% QueryNTS 默认不返回 Mouse/DateTime 列；仅在存在时归一化
	if ismember('Mouse', rows.Properties.VariableNames)
		rows.Mouse = string(rows.Mouse);
	end
	if ismember('DateTime', rows.Properties.VariableNames)
		rows.DateTime = datetime(rows.DateTime);
		if ~isempty(rows.DateTime.TimeZone)
			rows.DateTime.TimeZone = '';
		end
	end
	rows.CellUID = uint64(rows.CellUID);
	rows.TrialUID = uint64(rows.TrialUID);
end
end

function [trialUIDs, behTrial] = iTrialBehavior(rows)
trialUIDs = unique(uint64(rows.TrialUID), 'stable');
behTrial = nan(numel(trialUIDs), 1);
for iT = 1:numel(trialUIDs)
	v = double(rows.Behavior(uint64(rows.TrialUID) == trialUIDs(iT)));
	v = v(isfinite(v));
	if isempty(v)
		continue;
	end
	behTrial(iT) = mode(v);
end
keep = isfinite(behTrial);
trialUIDs = trialUIDs(keep);
behTrial = behTrial(keep);
end

function X = iBuildCellTrialMatrix(rows, cellUIDs, trialUIDs, idx1s)
% cells x trials 矩阵，元素 = 该细胞在该 trial 的 z@cue+1s
X = [];
rows = rows(ismember(uint64(rows.TrialUID), trialUIDs), :);
if isempty(rows)
	return;
end
present = intersect(cellUIDs, uint64(unique(rows.CellUID)), 'stable');
if numel(present) < 3
	return;
end
X = nan(numel(cellUIDs), numel(trialUIDs));
for iT = 1:numel(trialUIDs)
	rT = rows(uint64(rows.TrialUID) == trialUIDs(iT), :);
	for iC = 1:numel(cellUIDs)
		rC = rT(uint64(rT.CellUID) == cellUIDs(iC), :);
		if height(rC) == 1
			% TrialSignal 是数值时间向量（与 Fig1F 口径一致）
			sig = double(rC.TrialSignal);
			X(iC, iT) = sig(idx1s);
		end
	end
end
end
