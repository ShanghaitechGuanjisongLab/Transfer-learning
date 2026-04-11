% 中文图324B：Naive/Learned 代表性细胞曲线

if ~exist('UniExp.DataSet', 'class')
	thisFile = mfilename('fullpath');
	thisDir = fileparts(thisFile);
	prjFile = fullfile(thisDir, '..', 'Transferlearning.prj');
	if exist(prjFile, 'file')
		matlab.project.loadProject(prjFile);
	end
end

DS = TransferLearning.AudioLightBaseline();
xs = TransferLearning.Xs;
xsSec = seconds(xs);

plotMask = (xsSec >= -1) & (xsSec <= 2);
xsPlot = xsSec(plotMask);

[idxNeg1, okNeg1] = iFindTimeIndex(xsSec, -1, 0.25);
[idx0, ok0] = iFindTimeIndex(xsSec, 0, 0.25);
[idx1, ok1] = iFindTimeIndex(xsSec, 1, 0.25);
if ~okNeg1 || ~ok0 || ~ok1
	error('中文图324B:BadTimeIndex', 'Cannot find samples close to -1s, 0s and 1s.');
end

G = struct();
G.Naive = DS.QueryNTATS(struct('Phase', 'Naive', 'Stimulus', 'AudioWater'), UniExp.Flags.ZScore, 1:24, UniExp.Flags.Median);
G.Learned = DS.QueryNTATS(struct('Phase', 'Learned', 'Stimulus', 'AudioWater'), UniExp.Flags.ZScore, 1:24, UniExp.Flags.Median);

S = UniExp.NtatsCellStrip(G);
cellMeta = DS.Cells(:, intersect(["CellUID", "Mouse"], string(DS.Cells.Properties.VariableNames), 'stable'));
if ~all(ismember(["CellUID", "Mouse"], string(cellMeta.Properties.VariableNames)))
	error('中文图324B:MissingCellMeta', 'DS.Cells lacks CellUID/Mouse metadata.');
end
cellMeta.Mouse = string(cellMeta.Mouse);
S = outerjoin(S, cellMeta, 'Keys', 'CellUID', 'MergeKeys', true, 'Type', 'left');
X = iGetNtats3D(S);

naiveNeg1 = X(:, idxNeg1, 1);
learnedNeg1 = X(:, idxNeg1, 2);
naive0 = X(:, idx0, 1);
learned0 = X(:, idx0, 2);
naive1 = X(:, idx1, 1);
learned1 = X(:, idx1, 2);

valid = isfinite(naiveNeg1) & isfinite(learnedNeg1) & isfinite(naive0) & isfinite(learned0) & isfinite(naive1) & isfinite(learned1);

posMask = valid ...
	& naiveNeg1 < naive0 & naive0 < naive1 ...
	& learnedNeg1 < learned0 & learned0 < learned1 ...
	& learned1 > naive1 ...
	& (naive1 - naive0) > (naive0 - naiveNeg1) ...
	& (learned1 - learned0) > (learned0 - learnedNeg1);

negMask = valid ...
	& naiveNeg1 > naive0 & naive0 > naive1 ...
	& learnedNeg1 > learned0 & learned0 > learned1 ...
	& naive1 > learned1 ...
	& (naive0 - naive1) > (naiveNeg1 - naive0) ...
	& (learned0 - learned1) > (learnedNeg1 - learned0);

if ~any(posMask)
	error('中文图324B:NoPositiveCell', 'No cell satisfies the positive criterion.');
end
if ~any(negMask)
	error('中文图324B:NoNegativeCell', 'No cell satisfies the negative criterion.');
end

learnedNeg0Diff = abs(learned0 - learnedNeg1);
learned01Diff = abs(learned1 - learned0);
learnedMinStepDiff = min(learnedNeg0Diff, learned01Diff);
posScore = 100 * learnedMinStepDiff + (learned1 - naive1) + 0.1 * ((naive1 - naive0) + (naive0 - naiveNeg1) + (learned1 - learned0) + (learned0 - learnedNeg1));
negScore = 100 * learnedMinStepDiff + (naive1 - learned1) + 0.1 * ((naiveNeg1 - naive0) + (naive0 - naive1) + (learnedNeg1 - learned0) + (learned0 - learned1));
posScore(~posMask) = -inf;
negScore(~negMask) = -inf;

[~, posIdx] = max(posScore);
[~, negIdx] = max(negScore);
if negIdx == posIdx
	negScore(negIdx) = -inf;
	[bestNeg2, negIdx2] = max(negScore);
	if isfinite(bestNeg2)
		negIdx = negIdx2;
	end
end

colorNaive = [1, 0, 0];
colorLearned = [0, 0, 1];

% Precompute shared Learned baseline for Y-axis label alignment
gap = 1.2;
baseMaskPre = (xsPlot >= -1) & (xsPlot < 0);
bL1 = iComputeLearnBase(xsPlot, squeeze(X(posIdx, plotMask, 1)), squeeze(X(posIdx, plotMask, 2)), baseMaskPre, gap);
bL2 = iComputeLearnBase(xsPlot, squeeze(X(negIdx, plotMask, 1)), squeeze(X(negIdx, plotMask, 2)), baseMaskPre, gap);
sharedLearnBase = max(bL1, bL2);

f = figure('Color', 'w', 'Name', '中文图324B Naive Learned 代表性细胞');
f.Units = 'centimeters';
f.Position(3:4) = [7.5, 4];

ax1 = axes(f, 'Units', 'normalized', 'Position', [0.12 0.22 0.31 0.58]);
[hNaive, hLearned] = iPlotOneCell(ax1, xsPlot, squeeze(X(posIdx, plotMask, 1)), squeeze(X(posIdx, plotMask, 2)), colorNaive, colorLearned, uint64(S.CellUID(posIdx)), 'Naive', 'Learned', sharedLearnBase);

ax2 = axes(f, 'Units', 'normalized', 'Position', [0.56 0.22 0.34 0.58]);
iPlotOneCell(ax2, xsPlot, squeeze(X(negIdx, plotMask, 1)), squeeze(X(negIdx, plotMask, 2)), colorNaive, colorLearned, uint64(S.CellUID(negIdx)), 'Naive', 'Learned', sharedLearnBase);
sharedYLim = [min(ax1.YLim(1), ax2.YLim(1)), max(ax1.YLim(2), ax2.YLim(2))];
set([ax1, ax2], 'YLim', sharedYLim);

annotation(f, 'textbox', [0.40 0.03 0.20 0.06], 'String', 'Time (s)', 'EdgeColor', 'none', ...
	'HorizontalAlignment', 'center', 'VerticalAlignment', 'middle', 'FontSize', 6);
annotation(f, 'line', [0.10 0.18], [0.90 0.90], 'Color', colorNaive, 'LineWidth', 1);
annotation(f, 'textbox', [0.18 0.865 0.12 0.07], 'String', 'Naive', 'EdgeColor', 'none', ...
	'HorizontalAlignment', 'left', 'VerticalAlignment', 'middle', 'FontSize', 6);
annotation(f, 'line', [0.30 0.38], [0.90 0.90], 'Color', colorLearned, 'LineWidth', 1);
annotation(f, 'textbox', [0.38 0.865 0.15 0.07], 'String', 'Learned', 'EdgeColor', 'none', ...
	'HorizontalAlignment', 'left', 'VerticalAlignment', 'middle', 'FontSize', 6);
annotation(f, 'textbox', [0.60 0.855 0.25 0.08], 'String', 'Accelerators', 'EdgeColor', 'none', ...
	'HorizontalAlignment', 'center', 'VerticalAlignment', 'middle', 'FontSize', 6, 'FontWeight', 'bold');

outDirUNC = fullfile('\\Data-Server-2\个人数据\张天夫', char(datetime('now', 'Format', 'yyyyMM')));
if ~isfolder(outDirUNC)
	mkdir(outDirUNC);
end

svgPath = fullfile(outDirUNC, '中文图Fig324B_NaiveLearnedRepresentativeCells.svg');
print(f, svgPath, '-dsvg');
fprintf('Wrote: %s\n', svgPath);

picked = table;
picked.Kind = ["Positive"; "Negative"];
picked.CellUID = uint64([S.CellUID(posIdx); S.CellUID(negIdx)]);
picked.Mouse = string([S.Mouse(posIdx); S.Mouse(negIdx)]);
picked.NaiveAtMinus1 = [naiveNeg1(posIdx); naiveNeg1(negIdx)];
picked.NaiveAt0 = [naive0(posIdx); naive0(negIdx)];
picked.NaiveAt1 = [naive1(posIdx); naive1(negIdx)];
picked.LearnedAtMinus1 = [learnedNeg1(posIdx); learnedNeg1(negIdx)];
picked.LearnedAt0 = [learned0(posIdx); learned0(negIdx)];
picked.LearnedAt1 = [learned1(posIdx); learned1(negIdx)];
assignin('base', 'Fig324B_PickedCells', picked);

function [hLower, hUpper] = iPlotOneCell(ax, xsPlot, yLower, yUpper, colorLower, colorUpper, cellUID, lowerLabel, upperLabel, fixedLearnBase)
hold(ax, 'on');
baseMaskLocal = (xsPlot >= -1) & (xsPlot < 0);
baseLower = mean(yLower(baseMaskLocal), 'omitnan');
baseUpper = mean(yUpper(baseMaskLocal), 'omitnan');

gap = 1.2;
offsetLower = -baseLower;
yLowerShift = yLower + offsetLower;
if nargin >= 10 && ~isempty(fixedLearnBase)
	offsetUpper = fixedLearnBase - baseUpper;
else
	offsetUpper = (max(yLowerShift, [], 'omitnan') - min(yUpper, [], 'omitnan')) + gap;
end
yUpperShift = yUpper + offsetUpper;
baseLowerShift = baseLower + offsetLower;
baseUpperShift = baseUpper + offsetUpper;

hLower = plot(ax, xsPlot, yLowerShift, 'Color', colorLower, 'LineWidth', 1);
hUpper = plot(ax, xsPlot, yUpperShift, 'Color', colorUpper, 'LineWidth', 1);
xline(ax, 0, ':k', 'LineWidth', 1);
xline(ax, 1, '-k', 'LineWidth', 1);
[anchorX, anchorY] = iAnchorTriplet(xsPlot, yUpperShift);
plot(ax, anchorX, anchorY, '--', 'Color', [0, 0.6809, 0], 'LineWidth', 0.5, 'HandleVisibility', 'off');
xlim(ax, [-1 2]);
ax.FontSize = 6;
ax.LineWidth = 1;
ax.TickDir = 'in';
ax.FontName = 'Segoe UI Emoji';
box(ax, 'off');
grid(ax, 'off');
ax.YTick = [baseLowerShift, baseUpperShift];
ax.YTickLabel = {lowerLabel, upperLabel};
xt = ax.XTick;
xtl = string(ax.XTickLabel);
idx0 = find(xt == 0, 1, 'first');
idx1x = find(xt == 1, 1, 'first');
if ~isempty(idx0)
	xtl(idx0) = "🔊";
end
if ~isempty(idx1x)
	xtl(idx1x) = "💧";
end
ax.XTickLabel = xtl;
title(ax, sprintf('Cell %u', cellUID), 'FontSize', 6, 'FontWeight', 'normal');
if isprop(ax, 'Toolbar') && ~isempty(ax.Toolbar)
	ax.Toolbar.Visible = 'off';
end
end

function [idx, ok] = iFindTimeIndex(xsSec, targetSec, tolSec)
[d, idx] = min(abs(xsSec - targetSec));
ok = isfinite(d) && d <= tolSec;
end

function [xAnchor, yAnchor] = iAnchorTriplet(xsPlot, y)
targets = [-1, 0, 1];
idx = zeros(size(targets));
for i = 1:numel(targets)
	[~, idx(i)] = min(abs(xsPlot - targets(i)));
end
xAnchor = xsPlot(idx);
yAnchor = y(idx);
end

function baseLearnShift = iComputeLearnBase(xsPlot, yNaive, yLearn, baseMask, gap)
baseNaive = mean(yNaive(baseMask), 'omitnan');
baseLearn = mean(yLearn(baseMask), 'omitnan');
offsetNaive = -baseNaive;
yNaiveShift = yNaive + offsetNaive;
offsetLearn = (max(yNaiveShift, [], 'omitnan') - min(yLearn, [], 'omitnan')) + gap;
baseLearnShift = baseLearn + offsetLearn;
end

function X = iGetNtats3D(S)
if istable(S)
	nt = S.NTATS;
elseif isstruct(S) && isfield(S, 'NTATS')
	nt = S.NTATS;
else
	nt = S;
end

if isa(nt, 'MATLAB.DataTypes.NDTable')
	try
		X = nt.Data.Data;
	catch
		X = nt{:,:,:}.Data;
	end
	return;
end

if isnumeric(nt)
	X = nt;
	return;
end

	error('中文图324B:BadNTATSContainer', 'Unsupported NTATS container type: %s', class(nt));
end