% 中文图324A：声水 Naive/Learned 代表性细胞曲线

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
	error('中文图324A:BadTimeIndex', 'Cannot find samples close to -1s, 0s and 1s.');
end

G = struct();
G.NaiveAudio = DS.QueryNTATS(struct('Phase', 'Naive', 'Stimulus', 'AudioWater'), UniExp.Flags.ZScore, 1:24, UniExp.Flags.Median);
G.LearnedAudio = DS.QueryNTATS(struct('Phase', 'Learned', 'Stimulus', 'AudioWater'), UniExp.Flags.ZScore, 1:24, UniExp.Flags.Median);

S = UniExp.NtatsCellStrip(G);
cellMeta = DS.Cells(:, intersect(["CellUID", "Mouse"], string(DS.Cells.Properties.VariableNames), 'stable'));
if ~all(ismember(["CellUID", "Mouse"], string(cellMeta.Properties.VariableNames)))
	error('中文图324A:MissingCellMeta', 'DS.Cells lacks CellUID/Mouse metadata.');
end
cellMeta.Mouse = string(cellMeta.Mouse);
S = outerjoin(S, cellMeta, 'Keys', 'CellUID', 'MergeKeys', true, 'Type', 'left');
X = iGetNtats3D(S);

if size(X, 3) < 2
	error('中文图324A:BadNTATS', 'Expected 2 lanes for Naive/Learned AudioWater.');
end
if ~all(ismember(["CellUID", "Mouse"], string(S.Properties.VariableNames)))
	error('中文图324A:MissingMeta', 'NtatsCellStrip output lacks CellUID/Mouse.');
end

naiveNeg1 = X(:, idxNeg1, 1);
learnNeg1 = X(:, idxNeg1, 2);
naive0 = X(:, idx0, 1);
learn0 = X(:, idx0, 2);
naive1 = X(:, idx1, 1);
learn1 = X(:, idx1, 2);

valid = isfinite(naiveNeg1) & isfinite(learnNeg1) & isfinite(naive0) & isfinite(learn0) & isfinite(naive1) & isfinite(learn1);

dNaiveNeg1 = naiveNeg1 - naive0;
dLearnNeg1 = learnNeg1 - learn0;
dNaive1 = naive1 - naive0;
dLearn1 = learn1 - learn0;

posMask = valid & dNaiveNeg1 > 0 & dLearnNeg1 > 0 & dNaive1 > 0 & dLearn1 > 0 & learn1 > naive1;
negMask = valid & dNaiveNeg1 < 0 & dLearnNeg1 < 0 & dNaive1 < 0 & dLearn1 < 0 & learn1 < naive1;

if ~any(posMask)
	error('中文图324A:NoPositiveCell', 'No cell satisfies the positive representative-cell criterion.');
end
if ~any(negMask)
	error('中文图324A:NoNegativeCell', 'No cell satisfies the negative representative-cell criterion.');
end

learnedNeg0Diff = abs(learn0 - learnNeg1);
learned01Diff = abs(learn1 - learn0);
learnedMinStepDiff = min(learnedNeg0Diff, learned01Diff);
posScore = 100 * learnedMinStepDiff + (learn1 - naive1) + 0.2 * (dNaiveNeg1 + dLearnNeg1 + dNaive1 + dLearn1);
negScore = 100 * learnedMinStepDiff + (naive1 - learn1) + 0.2 * (-(dNaiveNeg1 + dLearnNeg1 + dNaive1 + dLearn1));

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
colorLearn = [0, 0, 1];

% Precompute shared Learned baseline for Y-axis label alignment
gap = 1.2;
baseMaskPre = (xsPlot >= -1) & (xsPlot < 0);
bL1 = iComputeLearnBase(xsPlot, squeeze(X(posIdx, plotMask, 1)), squeeze(X(posIdx, plotMask, 2)), baseMaskPre, gap);
bL2 = iComputeLearnBase(xsPlot, squeeze(X(negIdx, plotMask, 1)), squeeze(X(negIdx, plotMask, 2)), baseMaskPre, gap);
sharedLearnBase = max(bL1, bL2);

f = figure('Color', 'w', 'Name', '中文图324A 声水代表性细胞');
f.Units = 'centimeters';
f.Position(3:4) = [7.5, 4];

ax1 = axes(f, 'Units', 'normalized', 'Position', [0.12 0.22 0.31 0.58]);
[hNaive, hLearn] = iPlotOneCell(ax1, xsPlot, squeeze(X(posIdx, plotMask, 1)), squeeze(X(posIdx, plotMask, 2)), colorNaive, colorLearn, uint64(S.CellUID(posIdx)), sharedLearnBase);

ax2 = axes(f, 'Units', 'normalized', 'Position', [0.56 0.22 0.34 0.58]);
iPlotOneCell(ax2, xsPlot, squeeze(X(negIdx, plotMask, 1)), squeeze(X(negIdx, plotMask, 2)), colorNaive, colorLearn, uint64(S.CellUID(negIdx)), sharedLearnBase);
sharedYLim = [min(ax1.YLim(1), ax2.YLim(1)), max(ax1.YLim(2), ax2.YLim(2))];
set([ax1, ax2], 'YLim', sharedYLim);
annotation(f, 'textbox', [0.40 0.03 0.20 0.06], 'String', 'Time (s)', 'EdgeColor', 'none', ...
	'HorizontalAlignment', 'center', 'VerticalAlignment', 'middle', 'FontSize', 6);

annotation(f, 'line', [0.10 0.18], [0.90 0.90], 'Color', colorNaive, 'LineWidth', 1);
annotation(f, 'textbox', [0.18 0.865 0.12 0.07], 'String', 'Naive', 'EdgeColor', 'none', ...
	'HorizontalAlignment', 'left', 'VerticalAlignment', 'middle', 'FontSize', 6);
annotation(f, 'line', [0.30 0.38], [0.90 0.90], 'Color', colorLearn, 'LineWidth', 1);
annotation(f, 'textbox', [0.38 0.865 0.15 0.07], 'String', 'Learned', 'EdgeColor', 'none', ...
	'HorizontalAlignment', 'left', 'VerticalAlignment', 'middle', 'FontSize', 6);
annotation(f, 'textbox', [0.62 0.855 0.22 0.08], 'String', 'Switchers', 'EdgeColor', 'none', ...
	'HorizontalAlignment', 'center', 'VerticalAlignment', 'middle', 'FontSize', 6, 'FontWeight', 'bold');

outDirUNC = fullfile('\\Data-Server-2\个人数据\张天夫', char(datetime('now', 'Format', 'yyyyMM')));
if ~isfolder(outDirUNC)
	mkdir(outDirUNC);
end

svgPath = fullfile(outDirUNC, '中文图Fig324A_AudioWaterRepresentativeCells.svg');
print(f, svgPath, '-dsvg');
fprintf('Wrote: %s\n', svgPath);

picked = table;
picked.Kind = ["Positive"; "Negative"];
picked.CellUID = uint64([S.CellUID(posIdx); S.CellUID(negIdx)]);
picked.Mouse = string([S.Mouse(posIdx); S.Mouse(negIdx)]);
picked.NaiveAtMinus1 = [naiveNeg1(posIdx); naiveNeg1(negIdx)];
picked.LearnedAtMinus1 = [learnNeg1(posIdx); learnNeg1(negIdx)];
picked.NaiveAt0 = [naive0(posIdx); naive0(negIdx)];
picked.LearnedAt0 = [learn0(posIdx); learn0(negIdx)];
picked.NaiveAt1 = [naive1(posIdx); naive1(negIdx)];
picked.LearnedAt1 = [learn1(posIdx); learn1(negIdx)];
assignin('base', 'Fig324A_PickedCells', picked);
assignin('base', 'Fig324A_CellStrip', S);

function [hNaive, hLearn] = iPlotOneCell(ax, xsPlot, yNaive, yLearn, colorNaive, colorLearn, cellUID, fixedLearnBase)
hold(ax, 'on');
baseMaskLocal = (xsPlot >= -1) & (xsPlot < 0);
baseNaive = mean(yNaive(baseMaskLocal), 'omitnan');
baseLearn = mean(yLearn(baseMaskLocal), 'omitnan');

gap = 1.2;
offsetNaive = -baseNaive;
yNaiveShift = yNaive + offsetNaive;
if nargin >= 8 && ~isempty(fixedLearnBase)
	offsetLearn = fixedLearnBase - baseLearn;
else
	offsetLearn = (max(yNaiveShift, [], 'omitnan') - min(yLearn, [], 'omitnan')) + gap;
end
yLearnShift = yLearn + offsetLearn;
baseNaiveShift = baseNaive + offsetNaive;
baseLearnShift = baseLearn + offsetLearn;

hNaive = plot(ax, xsPlot, yNaiveShift, 'Color', colorNaive, 'LineWidth', 1, 'DisplayName', 'Naive');
hLearn = plot(ax, xsPlot, yLearnShift, 'Color', colorLearn, 'LineWidth', 1, 'DisplayName', 'Learned');
xline(ax, 0, ':k', 'LineWidth', 1);
xline(ax, 1, '-k', 'LineWidth', 1);
[anchorX, anchorY] = iAnchorTriplet(xsPlot, yLearnShift);
plot(ax, anchorX, anchorY, '--', 'Color', [0, 0.6809, 0], 'LineWidth', 0.5, 'HandleVisibility', 'off');
xlim(ax, [-1 2]);
ax.FontSize = 6;
ax.LineWidth = 1;
ax.TickDir = 'in';
box(ax, 'off');
grid(ax, 'off');
ax.YTick = [baseNaiveShift, baseLearnShift];
ax.YTickLabel = {'Naive', 'Learned'};
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
ax.FontName = 'Segoe UI Emoji';
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

	error('中文图324A:BadNTATSContainer', 'Unsupported NTATS container type: %s', class(nt));
end