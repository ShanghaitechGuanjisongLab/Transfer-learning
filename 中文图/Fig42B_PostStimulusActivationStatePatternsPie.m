% 中文图42B：刺激后激活状态变化模式占全细胞比例（饼图）

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

[idxNeg1, okNeg1] = iFindTimeIndex(xsSec, -1, 0.25);
[idx0, ok0] = iFindTimeIndex(xsSec, 0, 0.25);
[idx1, ok1] = iFindTimeIndex(xsSec, 1, 0.25);
if ~okNeg1 || ~ok0 || ~ok1
	error('Fig42B:BadTimeIndex', 'Cannot find samples close to -1s, 0s and 1s.');
end

G = struct();
G.Learned = DS.QueryNTATS(struct('Phase', 'Learned', 'Stimulus', 'AudioWater'), UniExp.Flags.ZScore, 1:24, UniExp.Flags.Median);

X = iGetNtats3D(G.Learned);
cellUID = iGetCellUID(G.Learned);

if size(X, 3) < 1
	error('Fig42B:BadNTATS', 'Expected Learned AudioWater NTATS.');
end

learnedNeg1 = X(:, idxNeg1, 1);
learned0 = X(:, idx0, 1);
learned1 = X(:, idx1, 1);

valid = isfinite(learnedNeg1) & isfinite(learned0) & isfinite(learned1);
nStatMice = iCountMiceForCells(DS.Cells, cellUID(valid));

dLearnedNeg1 = learnedNeg1 - learned0;
dLearned1 = learned1 - learned0;

reversalAfterStimulusMask = valid ...
	& ((dLearnedNeg1 > 0 & dLearned1 > 0) ...
	| (dLearnedNeg1 < 0 & dLearned1 < 0));

continuedChangeAfterStimulusMask = valid ...
	& ((learnedNeg1 < learned0 & learned0 < learned1) ...
	| (learnedNeg1 > learned0 & learned0 > learned1));

nTotal = size(X, 1);
nReversalAfterStimulus = sum(reversalAfterStimulusMask);
nContinuedChangeAfterStimulus = sum(continuedChangeAfterStimulusMask);
nOtherPatterns = nTotal - nReversalAfterStimulus - nContinuedChangeAfterStimulus;

fractions = [nReversalAfterStimulus, nContinuedChangeAfterStimulus, nOtherPatterns] ./ nTotal;
labels = [string(sprintf('Reversed\npost-stimulus\nactivation')), ...
	string(sprintf('Continued\npost-stimulus\nactivation change')), ...
	string(sprintf('Other\npost-stimulus\npatterns'))];
colors = [1 0 0; 0 0 1; 0.7922 0.7922 0.7922];
%% 

f = figure('Color', 'w', 'Name', '中文图42B Post-stimulus activation-state patterns');
f.Units = 'centimeters';
f.Position(3:4) = [4.5, 4];
f.PaperUnits = 'centimeters';
f.PaperPositionMode = 'manual';
f.PaperPosition = [0, 0, 4.5, 4];
f.PaperSize = [4.5,4];

ax = axes(f, 'Position', [0.345 0.18 0.31 0.70]);
MATLAB.Graphics.NestedPie({fractions}, ...
	WedgeColors={colors}, ...
	LabelText=repmat("", size(labels)), ...
	PercentStatus="on", ...
	PercentFontColor='k', ...
	RhoLower=0.4, ...
	LineWidth=0.5, ...
	LabelOffset=0, ...
	AxesHandle=ax);

axis(ax, 'equal');
ax.Visible = 'off';
ax.XLim = [-1.16, 1.16];
ax.YLim = [-1.16, 1.16];

wedgePatches = findobj(ax, 'Type', 'Patch');
for iPatch = 1:numel(wedgePatches)
	if isprop(wedgePatches(iPatch), 'FaceColor')
		wedgePatches(iPatch).FaceColor = 'none';
	end
	if isprop(wedgePatches(iPatch), 'FaceAlpha')
		wedgePatches(iPatch).FaceAlpha = 0;
	end
	if isprop(wedgePatches(iPatch), 'LineWidth')
		wedgePatches(iPatch).LineWidth = 1;
	end
end

set(findobj(f, 'Type', 'text'), 'FontSize', 6);
iTunePercentLabels(ax);
labelHandles = iAddPieLabels(f, fractions, labels);

outDirUNC = fullfile('\\Data-Server-2\个人数据\张天夫', char(datetime('now', 'Format', 'yyyyMM')));
if ~isfolder(outDirUNC)
	mkdir(outDirUNC);
end

svgPath = TransferLearning.ExportStandardFigure(f, 1, '中文图Fig42B_PostStimulusActivationStatePatternsPie.svg');
fprintf('Wrote: %s\n', svgPath);
fprintf('Fig42B mice included in statistics: %d\n', nStatMice);
fprintf('Fig42B pie counts: reversal-after-stimulus = %d cells, continued-change-after-stimulus = %d cells, other patterns = %d cells, Total = %d cells\n', ...
	nReversalAfterStimulus, nContinuedChangeAfterStimulus, nOtherPatterns, nTotal);

counts = table;
counts.Category = labels.';
counts.Count = [nReversalAfterStimulus; nContinuedChangeAfterStimulus; nOtherPatterns];
counts.Fraction = fractions.';
assignin('base', 'Fig42B_PieCounts', counts);

function X = iGetNtats3D(S)
if istable(S)
	nt = S.NTATS;
elseif isstruct(S) && isfield(S, 'NTATS')
	nt = S.NTATS;
else
	nt = S;
end

if isa(nt, 'MATLAB.DataTypes.NDTable')
	X = nt.Data;
	if isstruct(X) && isfield(X, 'Data')
		X = X.Data;
	end
	if ndims(X) == 2
		X = reshape(X, size(X, 1), size(X, 2), 1);
	end
	return;
end

if isnumeric(nt)
	if ndims(nt) == 2
		X = reshape(nt, size(nt, 1), size(nt, 2), 1);
		return;
	end
	if ndims(nt) ~= 3
		error('Fig42B:BadNTATSContainer', 'Expected NTATS to be 3D numeric or NDTable.');
	end
	X = nt;
	return;
end

	error('Fig42B:BadNTATSContainer', 'Unsupported NTATS container type: %s', class(nt));
end

function cellUID = iGetCellUID(S)
if istable(S) && ismember('CellUID', S.Properties.VariableNames)
	cellUID = uint64(S.CellUID(:));
else
	cellUID = uint64.empty(0, 1);
end
end

function nMice = iCountMiceForCells(cellTable, cellUID)
nMice = 0;
if isempty(cellUID) || isempty(cellTable) || ~all(ismember({'CellUID','Mouse'}, cellTable.Properties.VariableNames))
	return;
end
cellMap = cellTable(:, {'CellUID','Mouse'});
cellMap.CellUID = uint64(cellMap.CellUID);
[hasCell, loc] = ismember(uint64(cellUID(:)), cellMap.CellUID);
if any(hasCell)
	nMice = numel(unique(string(cellMap.Mouse(loc(hasCell)))));
end
end

function [idx, ok] = iFindTimeIndex(xsSec, tSec, tolSec)
if isempty(xsSec) || ~isvector(xsSec)
	idx = 1;
	ok = false;
	return;
end

[d, idx] = min(abs(xsSec(:) - tSec));
ok = isfinite(d) && (d <= tolSec);
end

function iTunePercentLabels(ax)
percentTexts = findall(ax, 'Type', 'Text');
for iText = 1:numel(percentTexts)
	textString = string(percentTexts(iText).String);
	if ~contains(textString, '%')
		continue;
	end
	if percentTexts(iText).Position(2) >= 0
		percentTexts(iText).Position = [-0.06, 0.58, 0];
	else
		percentTexts(iText).Position = [0.06, -0.58, 0];
	end
	percentTexts(iText).HorizontalAlignment = 'center';
	percentTexts(iText).VerticalAlignment = 'middle';
	percentTexts(iText).FontSize = 6;
end
end

function labelHandles = iAddPieLabels(fig, fractions, labels)
fractions = fractions(:).';
labels = string(labels(:).');
labelHandles = gobjects(numel(labels), 1);
if isempty(fractions)
	return;
end

labelBoxes = [0.015, 0.50, 0.355, 0.34; ...
	0.615, 0.14, 0.365, 0.43; ...
	0.35, 0.03, 0.30, 0.22];
labelAlignments = ["right", "left", "center"];

for iLabel = 1:numel(labels)
	if ~(fractions(iLabel) > 0)
		continue;
	end
	labelHandles(iLabel) = annotation(fig, 'textbox', labelBoxes(iLabel, :), ...
		'String', labels(iLabel), ...
		'EdgeColor', 'none', ...
		'FontSize', 6, ...
		'HorizontalAlignment', labelAlignments(iLabel), ...
		'VerticalAlignment', 'middle', ...
		'FitBoxToText', 'off');
	end
end