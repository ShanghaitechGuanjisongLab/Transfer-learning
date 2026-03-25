% 英文图2C：Inter-trial divergence PCA（2 tiles）
%
% v6 Panel C: PCA 散度图 — Naive AO (散) vs Learned AW (聚)
%
% 两个 tile 来自 PCA 图：
%   - Naive AudioOnly（相邻 2 回合平均 -> 10 条线）
%   - Learned AudioWater（相邻 3 回合平均 -> 10 条线）
%
% 小标题仅写：Naive🔊 与 🔊💧100%
% 大标题写：Inter-trial divergence
%
% Execution:
%   TransferLearning.英文图2.C_InterTrialDivergence_PCA


% Time (s) to use as PCA origin after cropping (0 = cue time).
originSec = 0.0;

% Toggle late-peak cell filtering (false = use all cells)
useCellFilter = false;

% --- 0) Ensure project loaded (for UniExp)
try
	if ~exist('UniExp.DataSet', 'class')
		thisFile = mfilename('fullpath');
		thisDir = fileparts(thisFile);
		prjFile = fullfile(thisDir, '..', '..', 'Transferlearning.prj');
		if exist(prjFile, 'file')
			try
				matlab.project.loadProject(prjFile);
			catch
			end
		end
	end
catch
end

% --- 1) Data sources (AudioLightBaseline + ALInterspersed)
DSList = {
	TransferLearning.AudioLightBaseline()
	TransferLearning.ALInterspersed()
};

% --- 2) Build super-mouse NTATS from NTS trials
% Learned AudioWater: take first 30 trials per cell -> average each 3 adjacent trials
[G_learn, info_learn] = iNtsSuperMouse(DSList, "Learned", "AudioWater", 30, useCellFilter);
G_learn_plot = iAverageAdjacentTrials(G_learn, 3);

% Naive AudioOnly: allow 20 trials -> average each 2 adjacent trials
[G_audioOnly, info_audioOnly] = iNtsSuperMouse(DSList, "Naive", "AudioOnly", 20, useCellFilter);
G_audioOnly_plot = iAverageAdjacentTrials(G_audioOnly, 2);

%% 
% --- 3) Plot (two tiles)
f = figure('Color', 'w', 'Name', 'English Fig2C Inter-trial divergence PCA');
f.Units = 'centimeters';
f.Position(3:4) = [6.0, 4.0]; % 60mm x 40mm

Layout = tiledlayout(f, 1, 2, 'TileSpacing', 'compact', 'Padding', 'compact');
try
	T = title(Layout, 'Inter-trial divergence');
	T.FontSize = 6;
catch
end

ax1 = nexttile(Layout, 1);
palette2 = TransferLearning.FigurePalette(2);
iPlotPcaOnAxes(ax1, G_audioOnly_plot, "Naive🔊", originSec, palette2(1,:));

ax2 = nexttile(Layout, 2);
iPlotPcaOnAxes(ax2, G_learn_plot, "🔊💧100%", originSec, palette2(2,:));

% Unify axis ranges across tiles
try
	MATLAB.Graphics.UnifyAxesLims([ax1, ax2], @xlim);
	MATLAB.Graphics.UnifyAxesLims([ax1, ax2], @ylim);
catch
end

% --- 4) Export
try
outDirUNC = fullfile('\\Data-Server-2\个人数据\张天夫', char(datetime('now', 'Format', 'yyyyMM')));
	if ~isfolder(outDirUNC)
		mkdir(outDirUNC);
	end
catch
end

svgName = "English_Fig2C_InterTrialDivergence_PCA.svg";
svgPath = fullfile(outDirUNC, svgName);
TransferLearning.PrintFigure(f, svgPath);
fprintf('Wrote: %s\n', svgPath);

assignin('base', 'Fig2C_Info_Learned', info_learn);
assignin('base', 'Fig2C_Info_AudioOnly', info_audioOnly);

function [GroupNtats, info] = iNtsSuperMouse(DSList, phaseName, stimulusName, minTrials, useCellFilter)
% Pool all mice into one "super mouse" using QueryNTS (DeltaF).
% Drop cells with < minTrials trials, then take first minTrials for PCA.

cellTraces = {};
nTime = [];

for iDS = 1:numel(DSList)
	DS = DSList{iDS};
	try
		ntsCell = DS.QueryNTS(struct('Stimulus', string(stimulusName), 'Phase', string(phaseName)), UniExp.Flags.DeltaF, 1:24);
		nts = ntsCell{1};
	catch
		nts = [];
	end
	if isempty(nts)
		continue;
	end

	if useCellFilter
		keepUids = iQueryNtatsKeepUids(DS, phaseName, stimulusName);
		if isempty(keepUids)
			continue;
		end
	else
		keepUids = uint64([]);
	end

	cellUIDs = unique(uint64(nts.CellUID));
	for iC = 1:numel(cellUIDs)
		cid = cellUIDs(iC);
		if useCellFilter && ~ismember(cid, keepUids)
			continue;
		end
		rowsC = (uint64(nts.CellUID) == cid);
		if sum(rowsC) < minTrials
			continue;
		end
		uid = uint64(nts.TrialUID(rowsC));
		sig = double(nts.TrialSignal(rowsC, :));
		[uidSorted, order] = sort(uid);
		sig = sig(order, :);
		if size(sig, 1) < minTrials
			continue;
		end
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
	error('Fig2C:EmptySuperMouse', 'No cells found after pooling for Phase=%s Stimulus=%s.', phaseName, stimulusName);
end

nCells = numel(cellTraces);
nTrials = minTrials;
CellTrialTimes = nan(nCells, nTrials, nTime);
for iC = 1:nCells
	CellTrialTimes(iC, :, :) = cellTraces{iC};
end

% Build NTATS-like NDTable: [Cell x Time x Trial]
ntatsData = permute(CellTrialTimes, [1, 3, 2]);
% Subtract 0s timepoint from all timepoints (per cell/trial)
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
try
	ntatsGroup = DS.QueryNTATS(queryStruct, UniExp.Flags.DeltaF, 1:24, UniExp.Flags.Median);
catch
	ntatsGroup = [];
end

keepUids = iSelectLatePeakCellsNtatsGroup(ntatsGroup);
end

function keepUids = iSelectLatePeakCellsNtatsGroup(ntatsGroup)
keepUids = uint64([]);
if isempty(ntatsGroup) || ~istable(ntatsGroup) || height(ntatsGroup) == 0
	return
end

if ~ismember('CellUID', ntatsGroup.Properties.VariableNames) || ~ismember('NTATS', ntatsGroup.Properties.VariableNames)
	return
end

cellUIDs = uint64(ntatsGroup.CellUID);
keepMask = false(numel(cellUIDs), 1);

try
	nGroups = size(ntatsGroup.NTATS, 3);
catch
	nGroups = 1;
end

sampleRate = 8;
idxCue0 = 3 * sampleRate;

for g = 1:nGroups
	try
		data = ntatsGroup.NTATS{:,:, g};
	catch
		continue
	end
	data = squeeze(data);
	if ~ismatrix(data)
		continue
	end
	idx0 = max(1, min(size(data, 2), idxCue0));
	sigNtats = data - data(:, idx0);

	idx0_1 = idxCue0:(idxCue0 + sampleRate);
	idx1_2 = (idxCue0 + sampleRate):(idxCue0 + 2 * sampleRate);
	idx0_1 = idx0_1(idx0_1 >= 1 & idx0_1 <= size(sigNtats, 2));
	idx1_2 = idx1_2(idx1_2 >= 1 & idx1_2 <= size(sigNtats, 2));
	if isempty(idx0_1) || isempty(idx1_2)
		continue
	end

	peak0_1 = max(sigNtats(:, idx0_1), [], 2);
	peak1_2 = max(sigNtats(:, idx1_2), [], 2);
	keepMask = keepMask | (peak1_2 > peak0_1);
end

keepUids = cellUIDs(keepMask);
end

function GroupNtatsOut = iAverageAdjacentTrials(GroupNtatsIn, groupSize)
% Average adjacent trials (3rd dim of NTATS NDTable) to reduce number of lines.
% Input/Output table format: table with variable NTATS being MATLAB.DataTypes.NDTable.
if isempty(GroupNtatsIn) || ~istable(GroupNtatsIn) || height(GroupNtatsIn) == 0
	GroupNtatsOut = GroupNtatsIn;
	return;
end
if ~ismember('NTATS', GroupNtatsIn.Properties.VariableNames)
	GroupNtatsOut = GroupNtatsIn;
	return;
end

X = GroupNtatsIn.NTATS{:,:,:};
if ndims(X) ~= 3
	GroupNtatsOut = GroupNtatsIn;
	return;
end

nTrial = size(X, 3);
nKeep = floor(nTrial / groupSize) * groupSize;
if nKeep < groupSize
	GroupNtatsOut = GroupNtatsIn;
	return;
end
if nKeep ~= nTrial
	X = X(:, :, 1:nKeep);
end

nGroup = nKeep / groupSize;
Xr = reshape(X, size(X,1), size(X,2), groupSize, nGroup);
Xg = mean(Xr, 3, 'omitnan');

% mean() keeps the reduced dimension, so Xg is [nCell x nTime x 1 x nGroup].
% Reshape back to 3D [nCell x nTime x nGroup] for UniExp.LinearPca.
Xg = reshape(Xg, size(X,1), size(X,2), nGroup);

ntats = MATLAB.DataTypes.NDTable(Xg);
GroupNtatsOut = table(ntats, 'VariableNames', "NTATS");
end

function iPlotPcaOnAxes(ax, GroupNtats, titleText, originSec, lineColor)
PcaTable = UniExp.LinearPca(GroupNtats.NTATS, 2);
PcaLines = PcaTable.Score;

% Only plot 0~1s relative to cue.
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

% Shift each trajectory so the originSec point is at the origin.
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
cmap = iTintRamp(lineColor, nLines);

Markers = table;
Markers.Index = numel(idxPlotTime);
Markers.Shape = "^";

[~, scatters] = UniExp.SegmentFadePlot( ...
	table(permute(PcaData, [3, 1, 2]), cmap, 'VariableNames', ["Points", "Color"]), ...
	Markers, ax, ...
	'PatchArguments', {'LineWidth', 1}, ...
	'ScatterArguments', {'SizeData', 9, 'MarkerEdgeColor', 'k', 'MarkerFaceColor', 'w', 'LineWidth', 0.75, 'MarkerFaceAlpha', 1});

try
	if ~isempty(scatters)
		uistack(scatters, 'top');
	end
catch
end

xlabel(ax, sprintf('PC1 (%.2g%%)', PcaTable.Explained(1)));
ylabel(ax, sprintf('PC2 (%.2g%%)', PcaTable.Explained(2)));
title(ax, titleText);

try
	view(ax, 2);
catch
end

try
	if isprop(ax, 'Toolbar') && ~isempty(ax.Toolbar)
		ax.Toolbar.Visible = 'off';
	end
catch
end
end

	function cmap = iTintRamp(baseColor, nLines)
	if nLines <= 1
		cmap = baseColor;
		return;
	end

	mix = linspace(0.45, 1.00, nLines)';
	darkFloor = 0.10;
	cmap = baseColor .* mix + darkFloor .* (1 - mix);
	end
