% Exploratory Makino-style display: one representative mouse per group and
% 10 unaveraged single-trial L2/3 population trajectories in PC1-PC3 space.
%
% Naive and Transfer use the same first-light-water-block definitions and
% complete-trial cell rules as PrepareFig44CEData. The representative mouse
% is the one whose full-block L2/3 divergence is closest to its group median.
% PCA is fitted independently within each mouse using ALL complete trials;
% 10 equally spaced trials are then selected only for display. Consequently,
% axis orientation and axis spread must not be compared quantitatively across
% mice. Group inference remains based on the per-mouse divergence values.
%
% Outputs (exploratory; does not replace the established Fig1D):
%   English_Explore_RepresentativeMouse_10SingleTrialPCA_L23.svg
%   English_Explore_RepresentativeMouse_10SingleTrialPCA_L23.png
%
% Run as a script in MATLAB Editor.

nDisplayTrials = 10;

if ~exist('UniExp.DataSet', 'class') || ~exist('TransferLearning', 'class')
	thisDir = fileparts(mfilename('fullpath'));
	prjFile = fullfile(thisDir, '..', 'Transferlearning.prj');
	matlab.project.loadProject(prjFile);
end

% Reuse the established per-mouse divergence pipeline to avoid selecting
% exemplars by their visual appearance or by a desired group difference.
DivData = TransferLearning.PrepareFig44CEData();
DivSummary = DivData.DivergenceSummary;
RepNaive = iPickMedianMouse(DivSummary, "Naive");
RepTransfer = iPickMedianMouse(DivSummary, "Transfer");
Representatives = [RepNaive; RepTransfer];

xsSec = seconds(TransferLearning.Xs);
[~, idxCue] = min(abs(xsSec - 0));
[~, idxWater] = min(abs(xsSec - 1));
assert(idxCue < idxWater, 'ExplorePCA:BadTimeAxis', 'Invalid cue/water sample order.');

PlotData = cell(height(Representatives), 1);
for iR = 1:height(Representatives)
	rep = Representatives(iR, :);
	session = iLocateRepresentativeSession(rep);
	[CTT, cellUIDs] = iLoadCompleteL23(session);
	assert(~isempty(CTT), 'ExplorePCA:EmptyRepresentative', ...
		'No complete L2/3 cells for %s.', rep.Mouse);
	assert(size(CTT, 3) > idxWater, 'ExplorePCA:ShortTrace', ...
		'The calcium traces do not contain the cue +1 s sample.');

	% Verify that the newly loaded full-block data reproduce the divergence
	% used for median-based representative selection.
	X = CTT(:, :, idxWater);
	divCheck = iDivFromX(X);
	assert(abs(divCheck - rep.DivL23) < 1e-8, 'ExplorePCA:DivergenceMismatch', ...
		'Divergence mismatch for %s: %.12g versus %.12g.', ...
		rep.Mouse, divCheck, rep.DivL23);

	% UniExp.LinearPca expects cells x time x trials. Fit on every complete
	% trial, then subset the projected scores for display only.
	ntatsData = permute(CTT, [1, 3, 2]);
	ntats = MATLAB.DataTypes.NDTable(ntatsData);
	pcaTable = UniExp.LinearPca(ntats, 3, true);
	scoreAll = pcaTable.Score.Data;
	assert(size(scoreAll, 1) >= 3, 'ExplorePCA:TooFewPCs', ...
		'Fewer than three PCs available for %s.', rep.Mouse);

	nTrial = size(CTT, 2);
	displayIdx = unique(round(linspace(1, nTrial, min(nDisplayTrials, nTrial))), 'stable');
	scoreDisplay = scoreAll(:, idxCue:idxWater, displayIdx);

	PlotData{iR} = struct( ...
		'Score', scoreDisplay, ...
		'DisplayTrialIndex', displayIdx, ...
		'NTrial', nTrial, ...
		'NCell', numel(cellUIDs), ...
		'PcaTable', pcaTable);
	fprintf('%s representative: %s, D = %.4f (group median %.4f), %d cells, %d trials.\n', ...
		rep.Group, rep.Mouse, rep.DivL23, rep.GroupMedian, numel(cellUIDs), nTrial);
	fprintf('  Displayed trial positions: %s\n', mat2str(displayIdx));
	fprintf('  PC explained: %.1f%%, %.1f%%, %.1f%%\n', pcaTable.Explained(1:3));
end

f = figure('Color', 'w', 'Name', 'Representative-mouse single-trial PCA: Naive versus Transfer');
f.Units = 'centimeters';
f.Position(3:4) = [14, 8];
f.PaperUnits = 'centimeters';
f.PaperPositionMode = 'manual';
f.PaperPosition = [0, 0, 14, 8];
f.PaperSize = [14, 8];
layout = tiledlayout(f, 1, 2, 'TileSpacing', 'compact', 'Padding', 'loose');
title(layout, 'Ten unaveraged single-trial trajectories in representative mice');

groupColors = [TransferLearning.NaiveColor; TransferLearning.TransferColor];
for iR = 1:height(Representatives)
	rep = Representatives(iR, :);
	pd = PlotData{iR};
	ax = nexttile(layout, iR);
	hold(ax, 'on');
	iPlotSingleTrials3D(ax, pd.Score, groupColors(iR, :));
	title(ax, {char(rep.Group + " | " + rep.Mouse), ...
		sprintf('D = %.2f (group median %.2f); %d cells', ...
		rep.DivL23, rep.GroupMedian, pd.NCell)}, ...
		'FontWeight', 'normal', 'Interpreter', 'none');
	xlabel(ax, 'PC1');
	ylabel(ax, 'PC2');
	zlabel(ax, 'PC3');
	iSetPaddedLimits3D(ax, pd.Score);
	view(ax, 38, 20);
	axis(ax, 'vis3d');
	box(ax, 'off');
	grid(ax, 'off');
	if isprop(ax, 'Toolbar') && ~isempty(ax.Toolbar)
		ax.Toolbar.Visible = 'off';
	end
end

svgPath = TransferLearning.ExportStandardFigure(f, 2, ...
	'English_Explore_RepresentativeMouse_10SingleTrialPCA_L23.svg');
pngPath = strrep(svgPath, '.svg', '.png');
exportgraphics(f, pngPath, 'Resolution', 300);
fprintf('Wrote: %s\nWrote: %s\n', svgPath, pngPath);

ExploratoryRepresentativePCA = struct( ...
	'Representatives', Representatives, ...
	'PlotData', {PlotData}, ...
	'SvgPath', svgPath, ...
	'PngPath', pngPath);
assignin('base', 'ExploratoryRepresentativePCA', ExploratoryRepresentativePCA);

%% Local functions
function rep = iPickMedianMouse(summary, groupName)
T = summary(string(summary.Group) == groupName & isfinite(summary.DivL23), :);
assert(~isempty(T), 'ExplorePCA:EmptyGroup', 'No eligible mice in %s.', groupName);
T.Mouse = string(T.Mouse);
	groupMedian = median(T.DivL23);
	T.GroupMedian = repmat(groupMedian, height(T), 1);
	T.DistanceToMedian = abs(T.DivL23 - groupMedian);
	T = sortrows(T, {'DistanceToMedian', 'Mouse'}, {'ascend', 'ascend'});
	rep = T(1, :);
end

function session = iLocateRepresentativeSession(rep)
if rep.Group == "Transfer"
	candidates = {TransferLearning.AudioLightBaseline()};
	startPhase = "Transfer";
else
	candidates = {TransferLearning.LightAudioBaseline(), TransferLearning.LAInterspersed()};
	startPhase = "Naive";
end
session = struct([]);
for iDS = 1:numel(candidates)
	DS = candidates{iDS};
	T = DS.TableQuery(["Mouse", "DateTime", "TrialUID", "TrialIndex", "Phase", "Stimulus"], ...
		Mouse = rep.Mouse, Phase = startPhase);
	if isempty(T)
		continue;
	end
	T.DateTime = iNormalizeDateTime(T.DateTime);
	T.Stimulus = string(T.Stimulus);
	sessionDates = sort(unique(T.DateTime(T.Stimulus == "LightWater")), 'ascend');
	for iDate = 1:numel(sessionDates)
		dt = sessionDates(iDate);
		rowsDate = T(T.DateTime == dt, :);
		if any(rowsDate.Stimulus == "AudioWater")
			continue;
		end
		rowsLight = sortrows(rowsDate(rowsDate.Stimulus == "LightWater", :), 'TrialIndex');
		trialUIDs = unique(uint64(rowsLight.TrialUID), 'stable');
		assert(isempty(session), 'ExplorePCA:DuplicateSession', ...
			'Representative session matched more than one dataset: %s.', rep.Mouse);
		session = builtin('struct', 'DS', DS, 'Mouse', rep.Mouse, 'DateTime', dt, ...
			'TrialUIDs', trialUIDs);
		break;
	end
end
assert(~isempty(session), 'ExplorePCA:SessionNotFound', ...
	'Could not locate the selected session for %s.', rep.Mouse);
end

function [CTT, keepUID] = iLoadCompleteL23(session)
DS = session.DS;
query = struct('Stimulus', "LightWater", 'Mouse', session.Mouse, 'DateTime', session.DateTime);
res = DS.QueryNTS(query, UniExp.Flags.ZScore, 1:24);
nts = iCollapseNts(res);
assert(~isempty(nts), 'ExplorePCA:EmptyNTS', 'No NTS rows for %s.', session.Mouse);
nts.CellUID = uint64(nts.CellUID);
nts.TrialUID = uint64(nts.TrialUID);

cellTbl = DS.Cells;
cellTbl.Mouse = string(cellTbl.Mouse);
cellTbl.CellUID = uint64(cellTbl.CellUID);
cellTbl.ZLayer = string(cellTbl.ZLayer);
keepUID = cellTbl.CellUID(cellTbl.Mouse == session.Mouse & cellTbl.ZLayer == "MOp2/3");
nts = nts(ismember(nts.CellUID, keepUID) & ismember(nts.TrialUID, session.TrialUIDs), :);

allCells = unique(nts.CellUID);
traces = cell(numel(allCells), 1);
completeUID = zeros(0, 1, 'uint64');
nKeep = 0;
for iC = 1:numel(allCells)
	cid = allCells(iC);
	rows = nts.CellUID == cid;
	uid = nts.TrialUID(rows);
	sig = double(nts.TrialSignal(rows, :));
	[matched, loc] = ismember(session.TrialUIDs, uid);
	if ~all(matched)
		continue;
	end
	orderedSignal = sig(loc, :);
	if any(~isfinite(orderedSignal), 'all')
		continue;
	end
	nKeep = nKeep + 1;
	traces{nKeep} = orderedSignal;
	completeUID(nKeep, 1) = cid; %#ok<AGROW>
end
assert(nKeep >= 3, 'ExplorePCA:TooFewCells', ...
	'Fewer than three complete L2/3 cells for %s.', session.Mouse);

traces = traces(1:nKeep);
keepUID = completeUID;
nTrial = numel(session.TrialUIDs);
nTime = size(traces{1}, 2);
CTT = nan(nKeep, nTrial, nTime);
for iC = 1:nKeep
	CTT(iC, :, :) = reshape(traces{iC}, 1, nTrial, nTime);
end
end

function tbl = iCollapseNts(res)
if istable(res)
	tbl = res;
	return;
end
if iscell(res)
	parts = res(~cellfun(@isempty, res));
	if isempty(parts)
		tbl = table();
	else
		tbl = vertcat(parts{:});
	end
	return;
end
tbl = table();
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

function iPlotSingleTrials3D(ax, score, baseColor)
lineColor = 0.75 * baseColor + 0.25;
for iT = 1:size(score, 3)
	x = score(1, :, iT);
	y = score(2, :, iT);
	z = score(3, :, iT);
	plot3(ax, x, y, z, '-', 'Color', lineColor, 'LineWidth', 1.1, ...
		'HandleVisibility', 'off');
	hCue = plot3(ax, x(1), y(1), z(1), 'o', ...
		'MarkerSize', 4, 'MarkerEdgeColor', [0 0 0], 'MarkerFaceColor', 'w', ...
		'HandleVisibility', 'off');
	hWater = plot3(ax, x(end), y(end), z(end), 'o', ...
		'MarkerSize', 3.5, 'MarkerEdgeColor', [0.65 0 0], 'MarkerFaceColor', [0.65 0 0], ...
		'HandleVisibility', 'off');
	if iT == 1
		hCue.HandleVisibility = 'on';
		hWater.HandleVisibility = 'on';
	end
end
legend(ax, [hCue, hWater], {'Cue onset', 'Water (+1 s)'}, ...
	'Location', 'northeast', 'Box', 'off');
end

function iSetPaddedLimits3D(ax, score)
for iDim = 1:3
	v = reshape(score(iDim, :, :), [], 1);
	v = v(isfinite(v));
	lo = min(v);
	hi = max(v);
	pad = 0.08 * max(hi - lo, eps);
	switch iDim
		case 1
			xlim(ax, [lo - pad, hi + pad]);
		case 2
			ylim(ax, [lo - pad, hi + pad]);
		case 3
			zlim(ax, [lo - pad, hi + pad]);
	end
end
end

function dt = iNormalizeDateTime(dt)
dt = datetime(dt);
if ~isempty(dt.TimeZone)
	dt.TimeZone = '';
end
end
