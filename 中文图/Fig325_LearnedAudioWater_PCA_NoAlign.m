% 中文图36：Learned 🔊💧 的 inter-trial divergence PCA（单 tile，不对齐到 0 点）

if ~exist('UniExp.DataSet', 'class')
	thisFile = mfilename('fullpath');
	thisDir = fileparts(thisFile);
	prjFile = fullfile(thisDir, '..', 'Transferlearning.prj');
	if exist(prjFile, 'file')
		matlab.project.loadProject(prjFile);
	end
end

DSList = {
	TransferLearning.AudioLightBaseline()
	TransferLearning.ALInterspersed()
};

G = iNtsSuperMouse(DSList, "Learned", "AudioWater", 30);
GPlot = iAverageAdjacentTrials(G, 3);

f = figure('Color', 'w', 'Name', '中文图36 Learned AudioWater PCA No Align');
f.Units = 'centimeters';
f.Position(3:4) = [6.5, 9.0];
f.PaperUnits = 'centimeters';
f.PaperPositionMode = 'manual';
f.PaperPosition = [0, 0, 6.5, 9.0];
f.PaperSize = [6.5, 9.0];

tlo = tiledlayout(f, 1, 1, 'TileSpacing', 'compact', 'Padding', 'compact');
ax = nexttile(tlo, 1);
palette2 = TransferLearning.FigurePalette(2);
[hCue, hWater, hTrial, hDrift] = iPlotPcaOnAxes(ax, GPlot, palette2(2, :));

lgd = legend(ax, [hTrial, hDrift, hCue, hWater], ["Trial", "Resting drift", "🔊", "💧"], 'Location', 'southoutside', 'Orientation', 'horizontal', 'NumColumns', 2);
lgd.Box = 'off';
lgd.FontSize = 10;
lgd.FontName = 'Segoe UI Emoji';
lgd.ItemTokenSize = [8, 8];

outDirUNC = fullfile('\\Data-Server-2\个人数据\张天夫', char(datetime('now', 'Format', 'yyyyMM')));
if ~isfolder(outDirUNC)
	mkdir(outDirUNC);
end

svgPath = fullfile(outDirUNC, '中文图Fig36_LearnedAudioWater_PCA_NoAlign.svg');
TransferLearning.PrintFigure(f, svgPath, ForceLegendOrColorbar=true);
fprintf('Wrote: %s\n', svgPath);

assignin('base', 'Fig36_GroupNtats', GPlot);

function GroupNtats = iNtsSuperMouse(DSList, phaseName, stimulusName, minTrials)
cellTraces = {};
nTime = [];

for iDS = 1:numel(DSList)
	DS = DSList{iDS};
	ntsCell = DS.QueryNTS(struct('Stimulus', string(stimulusName), 'Phase', string(phaseName)), UniExp.Flags.No_special_operation, 1:24);
	nts = ntsCell{1};
	cellUIDs = unique(uint64(nts.CellUID));
	for iC = 1:numel(cellUIDs)
		cid = cellUIDs(iC);
		rowsC = (uint64(nts.CellUID) == cid);
		if sum(rowsC) < minTrials
			continue;
		end
		uid = uint64(nts.TrialUID(rowsC));
		sig = double(nts.TrialSignal(rowsC, :));
		[~, order] = sort(uid);
		sig = sig(order, :);
		sig = sig(1:minTrials, :);
		if any(~isfinite(sig), 'all')
			continue;
		end
		cellTraces{end+1, 1} = sig; %#ok<AGROW>
		if isempty(nTime)
			nTime = size(sig, 2);
		end
	end
end

if isempty(cellTraces)
	error('中文图36:EmptySuperMouse', 'No cells found after pooling for requested trials.');
end

nCells = numel(cellTraces);
CellTrialTimes = nan(nCells, minTrials, nTime);
for iC = 1:nCells
	CellTrialTimes(iC, :, :) = cellTraces{iC};
end

ntatsData = permute(CellTrialTimes, [1, 3, 2]);
ntats = MATLAB.DataTypes.NDTable(ntatsData);
GroupNtats = table(ntats, 'VariableNames', "NTATS");
end

function GroupNtatsOut = iAverageAdjacentTrials(GroupNtatsIn, groupSize)
X = GroupNtatsIn.NTATS{:,:,:};
nTrial = size(X, 3);
nKeep = floor(nTrial / groupSize) * groupSize;
X = X(:, :, 1:nKeep);
nGroup = nKeep / groupSize;
Xr = reshape(X, size(X, 1), size(X, 2), groupSize, nGroup);
Xg = mean(Xr, 3, 'omitnan');
Xg = reshape(Xg, size(X, 1), size(X, 2), nGroup);
ntats = MATLAB.DataTypes.NDTable(Xg);
GroupNtatsOut = table(ntats, 'VariableNames', "NTATS");
end

function [hCue, hWater, hTrial, hDrift] = iPlotPcaOnAxes(ax, GroupNtats, lineColor)
PcaTable = UniExp.LinearPca(GroupNtats.NTATS, 2);
PcaLines = PcaTable.Score;

PcaDataAll = PcaLines.Data;
nTime = size(PcaDataAll, 2);
sampleRate = 8;
idxCue = 3 * sampleRate;
idxWater = idxCue + round(1.0 * sampleRate);
idxCue = max(1, min(nTime, idxCue));
idxWater = max(1, min(nTime, idxWater));
idxPlotTime = idxCue:idxWater;
PcaData = PcaDataAll(:, idxPlotTime, :);

ax.FontSize = 12;
ax.FontName = 'Segoe UI Emoji';
ax.LineWidth = 2;
box(ax, 'off');
grid(ax, 'off');
hold(ax, 'on');

nLines = size(PcaData, 3);
cuePts = squeeze(PcaData(:, 1, :)).';
waterPts = squeeze(PcaData(:, end, :)).';

	lineColors = iAlphaRamp([1 0 0], nLines);
	for iLine = 1:nLines
		xy = squeeze(PcaData(:, :, iLine));
		plot(ax, xy(1, :), xy(2, :), '-', 'LineWidth', 2, 'Color', lineColors(iLine, :));
	end

% Connect 0s points (cue onset) across trials with blue dashed line
plot(ax, cuePts(:, 1), cuePts(:, 2), '--', 'LineWidth', 1.5, 'Color', [0 0 1]);

scatter(ax, cuePts(:, 1), cuePts(:, 2), 18, 'o', 'MarkerEdgeColor', 'k', 'MarkerFaceColor', 'w', 'LineWidth', 0.2);
scatter(ax, waterPts(:, 1), waterPts(:, 2), 20, '^', 'MarkerEdgeColor', 'k', 'MarkerFaceColor', 'w', 'LineWidth', 0.2);

hCue = scatter(ax, nan, nan, 18, 'o', 'MarkerEdgeColor', 'k', 'MarkerFaceColor', 'w', 'LineWidth', 0.2);
hWater = scatter(ax, nan, nan, 20, '^', 'MarkerEdgeColor', 'k', 'MarkerFaceColor', 'w', 'LineWidth', 0.2);
hTrial = plot(ax, nan, nan, '-', 'LineWidth', 2, 'Color', [1 0 0]);
hDrift = plot(ax, nan, nan, '--', 'LineWidth', 1.5, 'Color', [0 0 1]);

	xlabel(ax, sprintf('PC1 (%.1f%%)', PcaTable.Explained(1)), 'FontSize', 12);
	ylabel(ax, sprintf('PC2 (%.1f%%)', PcaTable.Explained(2)), 'FontSize', 12);
view(ax, 2);
if isprop(ax, 'Toolbar') && ~isempty(ax.Toolbar)
	ax.Toolbar.Visible = 'off';
end
end

function colors = iAlphaRamp(baseColor, nLines)
if nLines <= 1
	colors = [baseColor, 1];
	return;
end

alphaVals = linspace(0.25, 1.0, nLines)';
colors = [repmat(baseColor, nLines, 1), alphaVals];
end