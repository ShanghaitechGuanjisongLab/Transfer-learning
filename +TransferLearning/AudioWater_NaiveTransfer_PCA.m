function AudioWater_NaiveTransfer_PCA()
% TransferLearning.AudioWater_NaiveTransfer_PCA
%
% Make PCA trajectory plots (like distanceAndPcaRe) for AudioWater pooled across mice:
% - Naive session (all trials within that session)
% - Learned session (all trials within that session)
%
% Output: SVG to \\Data-Server-2\个人数据\张天夫\202601

outDirUNC = "\\Data-Server-2\个人数据\张天夫\202601";

% --- 0) Ensure project loaded (for UniExp)
try
	if ~exist('UniExp.DataSet', 'class')
		thisFile = mfilename('fullpath');
		thisDir = fileparts(thisFile);
		prjFile = fullfile(thisDir, '..', 'Transferlearning.prj');
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

% --- 2) Super mouse from QueryNTS (DeltaF), no replenish, drop cells <30 trials
[G_naive, info_naive] = iNtsSuperMouse(DSList, "Naive", "AudioWater", 30);
[G_learn, info_learn] = iNtsSuperMouse(DSList, "Learned", "AudioWater", 30);

% --- 4) Plot + export
[fNaive, axNaive] = iPlotPca(G_naive, sprintf('Naive AudioWater  (SuperMouse, nCell=%d, nTrial=%d)', info_naive.NCells, info_naive.NTrials));
[fLearn, axLearn] = iPlotPca(G_learn, sprintf('Learned AudioWater  (SuperMouse, nCell=%d, nTrial=%d)', info_learn.NCells, info_learn.NTrials));

% Unify axis ranges across Naive vs Learned/Transfer
try
	MATLAB.Graphics.UnifyAxesLims([axNaive, axLearn], @xlim);
	MATLAB.Graphics.UnifyAxesLims([axNaive, axLearn], @ylim);
catch
end

TransferLearning.PrintFigure(fNaive, fullfile(outDirUNC, "AudioWater_Naive_PCA.svg"));
TransferLearning.PrintFigure(fLearn, fullfile(outDirUNC, "AudioWater_Learned_PCA.svg"));

end

function [GroupNtats, info] = iNtsSuperMouse(DSList, phaseName, stimulusName, minTrials)
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

	cellUIDs = unique(uint64(nts.CellUID));
	for iC = 1:numel(cellUIDs)
		cid = cellUIDs(iC);
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
	error('AudioWaterPCA:EmptySuperMouse', 'No cells found after pooling for Phase=%s Stimulus=%s.', phaseName, stimulusName);
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

function [f, ax] = iPlotPca(GroupNtats, titleText)
PcaTable = UniExp.LinearPca(GroupNtats.NTATS, 2);
PcaLines = PcaTable.Score;

% NOTE: PcaLines.Data follows the convention used in distanceAndPcaRe.m:
%   size = [PCDim x Time x Line]
% SegmentFadePlot expects Points as [Line x (XY/XYZ) x Time].

% Only plot 0~1s relative to cue.
% Project convention (see distanceAndPcaRe.m): SampleRate=8, and key indices are:
%   0s (cue)    -> 3*SampleRate
%   1s (water)  -> 4*SampleRate
PcaDataAll = PcaLines.Data;
nTime = size(PcaDataAll, 2);
sampleRate = 8;
idxCue0 = 3 * sampleRate;
idxWater1 = 4 * sampleRate;

idxCue0 = max(1, min(nTime, idxCue0));
idxWater1 = max(1, min(nTime, idxWater1));
idxPlotTime = idxCue0:idxWater1;

PcaData = PcaDataAll(:, idxPlotTime, :);

f = figure('Color', 'w');
MATLAB.Graphics.FigureAspectRatio(45, 40, 1);
ax = axes(f);
ax.FontSize = 6;
box(ax, 'off');
grid(ax, 'off');
hold(ax, 'on');

% Marker: only 1s (▲)
Markers = table;
% Place marker at 1s (water). After cropping to 0~1s, it is the last point.
Markers.Index = numel(idxPlotTime);
Markers.Shape = "^";

[~, scatters] = UniExp.SegmentFadePlot( ...
	table(permute(PcaData, [3, 1, 2]), 'VariableNames', "Points"), ...
	Markers, ax, ...
	'PatchArguments', {'LineWidth', 1}, ...
	'ScatterArguments', {'SizeData', 36, 'MarkerEdgeColor', 'k', 'MarkerFaceColor', 'w', 'LineWidth', 0.75, 'MarkerFaceAlpha', 1});

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
