% English Fig2D: hit cells in hit trials are more convergent across trials
% than miss cells in miss trials
%
% Divergence uses the Figure 1 definition (inter-trial divergence at
% cue +1 s: sqrt(sum across cells of trial-to-trial variance / sum of
% squared trial means)), computed within the first transfer light-water
% block of each mouse:
%   - hit divergence : hit-weight cells (choice decoder w > 0) over hit trials
%   - miss divergence: miss-weight cells (choice decoder w < 0) over miss trials
% Paired comparison across mice (sign-rank).
%
% Outputs (SVG):
%   - English_Fig2D_HitMissCellDivergence.svg
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

sampleRate = 8;
xs = TransferLearning.Xs;
if isduration(xs)
	xsSec = seconds(xs);
else
	xsSec = double(xs);
end
[~, idx1s] = min(abs(xsSec - 1));

data = TransferLearning.BuildCueChoiceDecoderData();
DS = TransferLearning.AudioLightBaseline();

divHit = nan(numel(data.choice), 1);
divMiss = nan(numel(data.choice), 1);
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
	hitTrials = trialUIDs(behTrial == 1);
	missTrials = trialUIDs(behTrial == 0);
	if numel(hitTrials) < 3 || numel(missTrials) < 3
		continue;
	end
	X = iBuildCellTrialMatrix(rows, cellUIDs, trialUIDs, idx1s);
	if isempty(X)
		continue;
	end
	[~, cLoc] = ismember(cellUIDs, cellUIDs); %#ok<ASGLU>
	Xh = X(ismember(cellUIDs, hitCells), behTrial == 1);
	Xm = X(ismember(cellUIDs, missCells), behTrial == 0);
	if size(Xh, 1) < 3 || size(Xh, 2) < 3 || size(Xm, 1) < 3 || size(Xm, 2) < 3
		continue;
	end
	divHit(i) = iDivFromX(Xh);
	divMiss(i) = iDivFromX(Xm);
	miceOut(i) = m;
end
ok = isfinite(divHit) & isfinite(divMiss);
divHit = divHit(ok);
divMiss = divMiss(ok);
miceOut = miceOut(ok);
if numel(divHit) < 4
	error('Fig2D:InsufficientMice', 'Fewer than 4 mice with valid hit/miss divergence.');
end

pPaired = signrank(divHit, divMiss);
fprintf('=== Fig2D divergence (first transfer light-water block) ===\n');
fprintf('hit cells in hit trials:   %.3f +/- %.3f (n = %d mice)\n', mean(divHit), std(divHit) / sqrt(numel(divHit)), numel(divHit));
fprintf('miss cells in miss trials: %.3f +/- %.3f\n', mean(divMiss), std(divMiss) / sqrt(numel(divMiss)));
fprintf('paired signrank p = %.4g\n', pPaired);

colorHit = [0.85 0.33 0.10];
colorMiss = [0.10 0.45 0.70];

f = figure('Color', 'w', 'Name', 'English Fig2D hit vs miss cell divergence');
f.Units = 'centimeters';
f.Position(3:4) = [4.5, 4.5];
f.PaperUnits = 'centimeters';
f.PaperSize = [4.5, 4.5];
f.PaperPositionMode = 'auto';
ax = axes(f);
hold(ax, 'on');
b = bar(ax, [mean(divHit), mean(divMiss)], 0.5);
b.FaceColor = 'flat';
b.CData = [colorHit; colorMiss];
b.EdgeColor = 'none';
b.FaceAlpha = 1/3;
b.LineWidth = 1;
se = [std(divHit) / sqrt(numel(divHit)), std(divMiss) / sqrt(numel(divMiss))];
errorbar(ax, 1:2, [mean(divHit), mean(divMiss)], se, 'k.', 'CapSize', 4, 'LineWidth', 1, 'HandleVisibility', 'off');
for i = 1:numel(divHit)
	plot(ax, [1 2], [divHit(i) divMiss(i)], '-', 'Color', [0.5 0.5 0.5], 'LineWidth', 0.5, 'HandleVisibility', 'off');
end
plot(ax, ones(numel(divHit), 1), divHit, '.', 'Color', colorHit, 'MarkerSize', 8, 'HandleVisibility', 'off');
plot(ax, 2 * ones(numel(divMiss), 1), divMiss, '.', 'Color', colorMiss, 'MarkerSize', 8, 'HandleVisibility', 'off');
yl = ylim(ax);
yrange = yl(2) - yl(1);
yLine = yl(2) + 0.05 * yrange;
plot(ax, [1 1.15 1.15 2 2], [yLine - 0.02 * yrange, yLine, yLine, yLine, yLine - 0.02 * yrange], 'k-', 'LineWidth', 1, 'HandleVisibility', 'off');
if pPaired < 0.001
	starStr = '＊＊＊';
elseif pPaired < 0.01
	starStr = '＊＊';
elseif pPaired < 0.05
	starStr = '＊';
else
	starStr = 'n.s.';
end
text(ax, 1.5, yLine + 0.02 * yrange, starStr, 'HorizontalAlignment', 'center', 'VerticalAlignment', 'bottom', 'FontSize', 8, 'HandleVisibility', 'off');
ylim(ax, [0, yLine + 0.25 * yrange]);
set(ax, 'XTick', [1 2], 'XTickLabel', {'hit cells, hit trials', 'miss cells, miss trials'});
ax.XTickLabelFontSize = 7;
ylabel(ax, 'Inter-trial divergence', 'FontSize', 8);
box(ax, 'off');
ax.FontSize = 7;
ax.LineWidth = 1;
ax.Color = 'none';
if isprop(ax, 'Toolbar') && ~isempty(ax.Toolbar)
	ax.Toolbar.Visible = 'off';
end

outDirUNC = fullfile('\\Data-Server-2\个人数据\张天夫', char(datetime('now', 'Format', 'yyyyMM')));
if ~isfolder(outDirUNC)
	mkdir(outDirUNC);
end
svgPath = TransferLearning.ExportStandardFigure(f, 2, 'English_Fig2D_HitMissCellDivergence.svg');
fprintf('Wrote: %s\n', svgPath);

assignin('base', 'Fig2D_DivergenceStats', struct('Mouse', miceOut, 'DivHit', divHit, 'DivMiss', divMiss, 'pPaired', pPaired));

%% ========== local functions ==========
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
	rows.Mouse = string(rows.Mouse);
	rows.DateTime = datetime(rows.DateTime);
	if ~isempty(rows.DateTime.TimeZone)
		rows.DateTime.TimeZone = '';
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
			sig = double(rC.TrialSignal{1});
			X(iC, iT) = sig(idx1s);
		end
	end
end
end

function div = iDivFromX(X)
totalSignal = sum(mean(X, 2).^2);
totalNoise = sum(var(X, [], 2));
if totalSignal > 0
	div = sqrt(totalNoise / totalSignal);
else
	div = NaN;
end
end
