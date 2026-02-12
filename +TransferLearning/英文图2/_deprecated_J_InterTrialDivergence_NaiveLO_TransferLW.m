% [DEPRECATED] v6 设计文档已移除此面板（Naive LO vs Transfer LW 对比不显著 p=0.089）
%
% 英文图2J：Inter-trial divergence（PCA trajectories, 2 tiles）
%
% 两个 tile 来自 PCA 图：
%   - Naive LightOnly（LightAudioBaseline + LAInterspersed, 相邻 2 回合平均 -> 10 条线）
%   - Transfer LightWater（AudioLightBaseline, 相邻 3 回合平均 -> 10 条线）
%
% 小标题：Naive💡 与 💡💧Trans.
% 大标题：Inter-trial divergence
%
% Execution:
%   TransferLearning.英文图2.J_InterTrialDivergence_NaiveLO_TransferLW

outDirUNC = "\\Data-Server-2\个人数据\张天夫\202601";
svgName = "English_Fig2J_InterTrialDivergence_NaiveLO_TransferLW.svg";

originSec = 0.0;
useCellFilter = false;

% --- 1) Data sources
% Naive LightOnly: LightAudioBaseline + LAInterspersed
DSNaive = {
	TransferLearning.LightAudioBaseline()
	TransferLearning.LAInterspersed()
};
% Transfer LightWater: AudioLightBaseline
DSTransfer = {
	TransferLearning.AudioLightBaseline()
};

% --- 2) Build super-mouse NTATS from NTS trials
% Naive LightOnly: 20 trials -> average each 2 adjacent trials -> 10 lines
[G_naiveLO, info_naiveLO] = iNtsSuperMouse(DSNaive, "Naive", "LightOnly", 20, useCellFilter);
G_naiveLO_plot = iAverageAdjacentTrials(G_naiveLO, 2);

% Transfer LightWater: 30 trials -> average each 3 adjacent trials -> 10 lines
[G_transferLW, info_transferLW] = iNtsSuperMouse(DSTransfer, "Transfer", "LightWater", 30, useCellFilter);
G_transferLW_plot = iAverageAdjacentTrials(G_transferLW, 3);

%% --- 3) Plot (two tiles)
f = figure('Color', 'w', 'Name', 'English Fig2J Inter-trial divergence');
f.Units = 'centimeters';
f.Position(3:4) = [6.0, 4.0];

Layout = tiledlayout(f, 1, 2, 'TileSpacing', 'compact', 'Padding', 'compact');
T = title(Layout, 'Inter-trial divergence');
T.FontSize = 6;

ax1 = nexttile(Layout, 1);
iPlotPcaOnAxes(ax1, G_naiveLO_plot, "Naive💡", originSec);

ax2 = nexttile(Layout, 2);
iPlotPcaOnAxes(ax2, G_transferLW_plot, "💡💧Trans.", originSec);

MATLAB.Graphics.UnifyAxesLims([ax1, ax2], @xlim);
MATLAB.Graphics.UnifyAxesLims([ax1, ax2], @ylim);

% --- 4) Export
if ~isfolder(outDirUNC)
	mkdir(outDirUNC);
end
svgPath = fullfile(outDirUNC, svgName);
TransferLearning.PrintFigure(f, svgPath);
fprintf('Wrote: %s\n', svgPath);

assignin('base', 'Fig2J_Info_NaiveLO', info_naiveLO);
assignin('base', 'Fig2J_Info_TransferLW', info_transferLW);

%% === Local helpers ===

function [GroupNtats, info] = iNtsSuperMouse(DSList, phaseName, stimulusName, minTrials, useCellFilter)
cellTraces = {};
nTime = [];

for iDS = 1:numel(DSList)
	DS = DSList{iDS};
	ntsCell = DS.QueryNTS(struct('Stimulus', string(stimulusName), 'Phase', string(phaseName)), UniExp.Flags.DeltaF, 1:24);
	nts = ntsCell{1};
	if isempty(nts), continue; end

	if useCellFilter
		keepUids = iQueryNtatsKeepUids(DS, phaseName, stimulusName);
		if isempty(keepUids), continue; end
	else
		keepUids = uint64([]);
	end

	cellUIDs = unique(uint64(nts.CellUID));
	for iC = 1:numel(cellUIDs)
		cid = cellUIDs(iC);
		if useCellFilter && ~ismember(cid, keepUids), continue; end
		rowsC = (uint64(nts.CellUID) == cid);
		if sum(rowsC) < minTrials, continue; end
		uid = uint64(nts.TrialUID(rowsC));
		sig = double(nts.TrialSignal(rowsC, :));
		[~, order] = sort(uid);
		sig = sig(order, :);
		sig = sig(1:minTrials, :);
		if any(~isfinite(sig), 'all'), continue; end
		cellTraces{end+1, 1} = sig; %#ok<AGROW>
		if isempty(nTime), nTime = size(sig, 2); end
	end
end

if isempty(cellTraces)
	error('Fig2J:EmptySuperMouse', 'No cells found for Phase=%s Stimulus=%s.', phaseName, stimulusName);
end

nCells = numel(cellTraces);
nTrials = minTrials;
CellTrialTimes = nan(nCells, nTrials, nTime);
for iC = 1:nCells
	CellTrialTimes(iC, :, :) = cellTraces{iC};
end

ntatsData = permute(CellTrialTimes, [1, 3, 2]);
sampleRate = 8;
idx0 = 3 * sampleRate;
idx0 = max(1, min(size(ntatsData, 2), idx0));
baseline0 = ntatsData(:, idx0, :);
ntatsData = ntatsData - baseline0;
ntats = MATLAB.DataTypes.NDTable(ntatsData);
GroupNtats = table(ntats, 'VariableNames', "NTATS");
info = table(nCells, nTrials, 'VariableNames', ["NCells","NTrials"]);
end

function keepUids = iQueryNtatsKeepUids(DS, phaseName, stimulusName)
keepUids = uint64([]);
queryStruct = struct('Stimulus', string(stimulusName), 'Phase', string(phaseName));
ntatsGroup = DS.QueryNTATS(queryStruct, UniExp.Flags.DeltaF, 1:24, UniExp.Flags.Median);
if isempty(ntatsGroup), return; end
keepUids = iSelectLatePeakCells(ntatsGroup);
end

function keepUids = iSelectLatePeakCells(ntatsGroup)
keepUids = uint64([]);
if isempty(ntatsGroup) || height(ntatsGroup) == 0, return; end
if ~ismember('CellUID', ntatsGroup.Properties.VariableNames), return; end
cellUIDs = uint64(ntatsGroup.CellUID);
data = squeeze(ntatsGroup.NTATS{:,:,1});
if ~ismatrix(data), return; end
sampleRate = 8;
idxCue0 = 3 * sampleRate;
idx0 = max(1, min(size(data, 2), idxCue0));
sigNtats = data - data(:, idx0);
idx0_1 = idxCue0:(idxCue0 + sampleRate);
idx1_2 = (idxCue0 + sampleRate):(idxCue0 + 2 * sampleRate);
idx0_1 = idx0_1(idx0_1 >= 1 & idx0_1 <= size(sigNtats, 2));
idx1_2 = idx1_2(idx1_2 >= 1 & idx1_2 <= size(sigNtats, 2));
if isempty(idx0_1) || isempty(idx1_2), return; end
peak0_1 = max(sigNtats(:, idx0_1), [], 2);
peak1_2 = max(sigNtats(:, idx1_2), [], 2);
keepUids = cellUIDs(peak1_2 > peak0_1);
end

function GroupNtatsOut = iAverageAdjacentTrials(GroupNtatsIn, groupSize)
X = GroupNtatsIn.NTATS{:,:,:};
if ndims(X) ~= 3, GroupNtatsOut = GroupNtatsIn; return; end
nTrial = size(X, 3);
nKeep = floor(nTrial / groupSize) * groupSize;
if nKeep < groupSize, GroupNtatsOut = GroupNtatsIn; return; end
X = X(:, :, 1:nKeep);
nGroup = nKeep / groupSize;
Xr = reshape(X, size(X,1), size(X,2), groupSize, nGroup);
Xg = reshape(mean(Xr, 3, 'omitnan'), size(X,1), size(X,2), nGroup);
ntats = MATLAB.DataTypes.NDTable(Xg);
GroupNtatsOut = table(ntats, 'VariableNames', "NTATS");
end

function iPlotPcaOnAxes(ax, GroupNtats, titleText, originSec)
PcaTable = UniExp.LinearPca(GroupNtats.NTATS, 2);
PcaLines = PcaTable.Score;
PcaDataAll = PcaLines.Data;
nTime = size(PcaDataAll, 2);
sampleRate = 8;
idxCue0 = 3 * sampleRate;
idxWater1 = idxCue0 + round(1.0 * sampleRate);
idxStart = idxCue0;
idxCue0 = max(1, min(nTime, idxCue0));
idxWater1 = max(1, min(nTime, idxWater1));
idxStart = max(1, min(nTime, idxStart));
idxPlotTime = idxStart:idxWater1;

PcaData = PcaDataAll(:, idxPlotTime, :);
originIdx = 1 + round(originSec * sampleRate);
originIdx = max(1, min(size(PcaData, 2), originIdx));
baseline = PcaData(:, originIdx, :);
PcaData = PcaData - baseline;

ax.FontSize = 6;
ax.FontName = 'Segoe UI Emoji';
box(ax, 'off');
grid(ax, 'off');
hold(ax, 'on');

nLines = size(PcaData, 3);
cDark = [0.16 0.36 0.64];
cLight = [0.72 0.83 0.95];
if nLines >= 2
	cmap = interp1([0 1], [cLight; cDark], linspace(0, 1, nLines));
else
	cmap = cDark;
end
colormap(ax, cmap);

Markers = table;
Markers.Index = numel(idxPlotTime);
Markers.Shape = "^";

[~, scatters] = UniExp.SegmentFadePlot( ...
	table(permute(PcaData, [3, 1, 2]), cmap, 'VariableNames', ["Points", "Color"]), ...
	Markers, ax, ...
	'PatchArguments', {'LineWidth', 1}, ...
	'ScatterArguments', {'SizeData', 9, 'MarkerEdgeColor', 'k', 'MarkerFaceColor', 'w', 'LineWidth', 0.75, 'MarkerFaceAlpha', 1});

if ~isempty(scatters), uistack(scatters, 'top'); end

xlabel(ax, sprintf('PC1 (%.2g%%)', PcaTable.Explained(1)));
ylabel(ax, sprintf('PC2 (%.2g%%)', PcaTable.Explained(2)));
title(ax, titleText);
view(ax, 2);
ax.Toolbar.Visible = 'off';
end
