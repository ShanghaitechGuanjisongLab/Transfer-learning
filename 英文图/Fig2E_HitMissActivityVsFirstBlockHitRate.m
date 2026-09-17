% English Fig2E: activity of hit cells correlates with first-block hit rate,
% miss cells do not
%
% Per mouse, within the first transfer light-water block:
%   - hit cells  = choice decoder weight w > 0 at 0.7 s
%   - miss cells = choice decoder weight w < 0 at 0.7 s
%   - cell activity = mean z-score at cue +1 s across all trials of the block
% Scatter: per-mouse mean activity of hit cells (top) / miss cells (bottom)
% vs first-block hit rate; Spearman correlation across mice.
%
% Outputs (SVG):
%   - English_Fig2E_HitMissActivityVsFirstBlockHitRate.svg
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

actHit = nan(numel(data.choice), 1);
actMiss = nan(numel(data.choice), 1);
hitRate = nan(numel(data.choice), 1);
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
	if isempty(trialUIDs)
		continue;
	end
	hitRate(i) = mean(behTrial == 1);
	act = iCellMeanZat1s(rows, cellUIDs, trialUIDs, idx1s);
	if isempty(act)
		continue;
	end
	aHit = act(ismember(cellUIDs, hitCells));
	aMiss = act(ismember(cellUIDs, missCells));
	aHit = aHit(isfinite(aHit));
	aMiss = aMiss(isfinite(aMiss));
	if isempty(aHit) || isempty(aMiss)
		continue;
	end
	actHit(i) = mean(aHit);
	actMiss(i) = mean(aMiss);
	miceOut(i) = m;
end
ok = isfinite(actHit) & isfinite(actMiss) & isfinite(hitRate);
actHit = actHit(ok);
actMiss = actMiss(ok);
hitRate = hitRate(ok);
miceOut = miceOut(ok);
if numel(actHit) < 4
	error('Fig2E:InsufficientMice', 'Fewer than 4 mice with valid hit/miss activity.');
end

[rhoHit, pHit] = corr(hitRate, actHit, 'Type', 'Spearman');
[rhoMiss, pMiss] = corr(hitRate, actMiss, 'Type', 'Spearman');
fprintf('=== Fig2E activity (first transfer light-water block) vs first-block hit rate ===\n');
fprintf('hit cells:  Spearman rho = %.3f, p = %.4g (n = %d mice)\n', rhoHit, pHit, numel(actHit));
fprintf('miss cells: Spearman rho = %.3f, p = %.4g\n', rhoMiss, pMiss);

colorHit = [0.85 0.33 0.10];
colorMiss = [0.10 0.45 0.70];

f = figure('Color', 'w', 'Name', 'English Fig2E hit/miss activity vs first-block hit rate');
f.Units = 'centimeters';
f.Position(3:4) = [9, 4.5];
f.PaperUnits = 'centimeters';
f.PaperSize = [9, 4.5];
f.PaperPositionMode = 'auto';

ax1 = subplot(1, 2, 1);
hold(ax1, 'on');
plot(ax1, hitRate, actHit, '.', 'Color', colorHit, 'MarkerSize', 12, 'HandleVisibility', 'off');
iAddFitLine(ax1, hitRate, actHit, colorHit);
xlabel(ax1, 'First-block hit rate', 'FontSize', 8);
ylabel(ax1, 'Hit-cell activity at cue +1 s', 'FontSize', 8);
iAddRhoText(ax1, rhoHit, pHit);
box(ax1, 'off');
ax1.FontSize = 7;
ax1.LineWidth = 1;
ax1.Color = 'none';

ax2 = subplot(1, 2, 2);
hold(ax2, 'on');
plot(ax2, hitRate, actMiss, '.', 'Color', colorMiss, 'MarkerSize', 12, 'HandleVisibility', 'off');
iAddFitLine(ax2, hitRate, actMiss, colorMiss);
xlabel(ax2, 'First-block hit rate', 'FontSize', 8);
ylabel(ax2, 'Miss-cell activity at cue +1 s', 'FontSize', 8);
iAddRhoText(ax2, rhoMiss, pMiss);
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
svgPath = TransferLearning.ExportStandardFigure(f, 2, 'English_Fig2E_HitMissActivityVsFirstBlockHitRate.svg');
fprintf('Wrote: %s\n', svgPath);

assignin('base', 'Fig2E_ActivityStats', struct('Mouse', miceOut, 'ActHit', actHit, 'ActMiss', actMiss, 'HitRate', hitRate, 'rhoHit', rhoHit, 'pHit', pHit, 'rhoMiss', rhoMiss, 'pMiss', pMiss));

%% ========== local functions ==========
function iAddFitLine(ax, x, y, col)
ok = isfinite(x) & isfinite(y);
if sum(ok) < 3
	return;
end
p = polyfit(x(ok), y(ok), 1);
xx = linspace(min(x(ok)), max(x(ok)), 50);
plot(ax, xx, polyval(p, xx), '-', 'Color', col, 'LineWidth', 1.2, 'HandleVisibility', 'off');
end

function iAddRhoText(ax, rho, p)
if p < 0.001
	txt = sprintf('Spearman \\rho = %.2f\np < 0.001', rho);
else
	txt = sprintf('Spearman \\rho = %.2f\np = %.3g', rho, p);
end
text(ax, 0.03, 0.97, txt, 'Units', 'normalized', 'VerticalAlignment', 'top', 'FontSize', 7, 'HandleVisibility', 'off');
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

function act = iCellMeanZat1s(rows, cellUIDs, trialUIDs, idx1s)
act = nan(numel(cellUIDs), 1);
rows = rows(ismember(uint64(rows.TrialUID), trialUIDs), :);
for iC = 1:numel(cellUIDs)
	rC = rows(uint64(rows.CellUID) == cellUIDs(iC), :);
	if isempty(rC)
		continue;
	end
	vals = nan(height(rC), 1);
	for iR = 1:height(rC)
		sig = double(rC.TrialSignal{iR});
		vals(iR) = sig(idx1s);
	end
	act(iC) = mean(vals, 'omitnan');
end
end
