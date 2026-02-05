% 英文图1K：散度代表性细胞
%
% 左tile：散度最大的细胞，取离均值最远的4个回合，4条-1~2s曲线，标题 Divergent cell
% 右tile：散度最小的细胞，取离均值最近的4个回合，4条-1~2s曲线，标题 Convergent cell
% yticklabels分别标注 Trial 1~Trial 4
% 排除1s处没有任何回合超过基线+3σ的细胞
%
% Execution:
%   run('D:\Users\张天夫\Documents\MATLAB\Transfer-learning\+TransferLearning\英文图1\K_DivergenceRepresentativeCells.m')

outDirUNC = "\\Data-Server-2\个人数据\张天夫\202601";
svgName = "English_Fig1K_DivergenceRepresentativeCells.svg";

% --- 0) Ensure project loaded
try
	if ~exist('UniExp.DataSet','class')
		thisFile = mfilename('fullpath');
		thisDir = fileparts(thisFile);
		prjFile = fullfile(thisDir, '..', '..', 'Transferlearning.prj');
		if exist(prjFile,'file')
			try matlab.project.loadProject(prjFile); catch, end
		end
	end
catch
end

kSigma = 3; % threshold for active cell

% --- 1) Load dataset (使用声光迁移数据集的Transfer LightWater)
DS = TransferLearning.AudioLightBaseline();

% Time axis
xs = TransferLearning.Xs;
xsSec = seconds(xs);
baseMask = (xsSec >= -1) & (xsSec < 0);
plotMask = (xsSec >= -1) & (xsSec <= 2);
xsPlot = xsSec(plotMask);
idx1s = find(abs(xsSec - 1) < 0.05, 1, 'first');
if isempty(idx1s)
	[~, idx1s] = min(abs(xsSec - 1));
end

% --- 2) Get Transfer LightWater trials (first pure session per mouse)
Ttrans = DS.TableQuery(["Mouse","DateTime","TrialUID"], Phase="Transfer", Stimulus="LightWater");
Ttrans.Mouse = string(Ttrans.Mouse);
Ttrans.DateTime = datetime(Ttrans.DateTime);
Ttrans.DateTime.TimeZone = '';

% Pick first Transfer session per mouse
dtTransT = groupsummary(Ttrans, "Mouse", "min", "DateTime");
dtTransT.Properties.VariableNames{end} = 'DateTimeTransfer';

% Use QueryNTS DeltaF (per-trial signals)

% --- 3) Calculate per-cell divergence and find best examples
allCellDiv = [];
allCellData = {};

for iM = 1:height(dtTransT)
	m = dtTransT.Mouse(iM);
	dtT = dtTransT.DateTimeTransfer(iM);
	
	% Get trial UIDs for this mouse/session
	mask = Ttrans.Mouse == m & Ttrans.DateTime == dtT;
	trialUIDs = uint64(Ttrans.TrialUID(mask));
	if numel(trialUIDs) < 4
		continue;
	end
	
	% Query per-trial DeltaF for this mouse/session
	nts = [];
	try
		ntsCell = DS.QueryNTS(struct('Phase', 'Transfer', 'Stimulus', 'LightWater', 'Mouse', string(m)), UniExp.Flags.DeltaF, 1:24);
		nts = ntsCell{1};
	catch
		nts = [];
	end
	if isempty(nts), continue; end
	
	% Keep only trials in this session
	try
		inTrial = ismember(uint64(nts.TrialUID), trialUIDs);
		nts = nts(inTrial, :);
	catch
		continue;
	end
	if isempty(nts), continue; end
	
	cellUIDs = unique(uint64(nts.CellUID));
	if isempty(cellUIDs), continue; end
	
	for iC = 1:numel(cellUIDs)
		cid = cellUIDs(iC);
		rowsC = (uint64(nts.CellUID) == cid);
		if sum(rowsC) < 4
			continue;
		end
		
		uid = uint64(nts.TrialUID(rowsC));
		sig = double(nts.TrialSignal(rowsC, :));
		
		[tf, loc] = ismember(trialUIDs, uid);
		if nnz(tf) < 4
			continue;
		end
		
		% Use only trials present for this cell (ordered by trialUIDs)
		sigOrdered = sig(loc(tf), :);
		usedTrialUIDs = trialUIDs(tf);
		if any(~isfinite(sigOrdered), 'all')
			continue;
		end
		
		vals1s = sigOrdered(:, idx1s);
		if any(~isfinite(vals1s))
			continue;
		end
		
		% Active threshold: baseline mean + 3*std (baseline = 1:24)
		baseVals = sigOrdered(:, 1:24);
		baseMu = mean(baseVals(:), 'omitnan');
		baseSd = std(baseVals(:), 0, 'omitnan');
		if ~isfinite(baseMu) || ~isfinite(baseSd)
			continue;
		end
		if baseSd < eps
			baseSd = 1;
		end
		thresh = baseMu + kSigma * baseSd;
		if max(vals1s) <= thresh
			continue;
		end
		
		% Divergence for this cell using 3D input
		cellDiv = TransferLearning.Divergence(reshape(sigOrdered, [1, size(sigOrdered, 1), size(sigOrdered, 2)]));
		if ~isfinite(cellDiv)
			continue;
		end
		
		allCellDiv(end+1) = cellDiv;
		allCellData{end+1} = struct('CellUID', cid, 'Mouse', m, 'Z', sigOrdered, 'Vals1s', vals1s, 'TrialUIDs', usedTrialUIDs);
	end
end

if numel(allCellDiv) < 2
	error('Fig1K:NotEnoughCells', 'Need at least 2 cells with sufficient trials.');
end

fprintf('Found %d active cells (at least one trial > %dσ at 1s)\n', numel(allCellDiv), kSigma);

% Find most divergent and most convergent cells
[~, idxMax] = max(allCellDiv);
[~, idxMin] = min(allCellDiv);

divCell = allCellData{idxMax};
convCell = allCellData{idxMin};

fprintf('Divergent cell: Mouse=%s, CellUID=%d, div=%.3f\n', divCell.Mouse, divCell.CellUID, allCellDiv(idxMax));
fprintf('Convergent cell: Mouse=%s, CellUID=%d, div=%.3f\n', convCell.Mouse, convCell.CellUID, allCellDiv(idxMin));

% --- 4) Select 4 trials for each cell
% Divergent: 4 trials furthest from mean
meanDiv = mean(divCell.Vals1s);
distDiv = abs(divCell.Vals1s - meanDiv);
[~, sortIdxDiv] = sort(distDiv, 'descend');
selDiv = sortIdxDiv(1:min(4, numel(sortIdxDiv)));

% Convergent: 4 trials closest to mean
meanConv = mean(convCell.Vals1s);
distConv = abs(convCell.Vals1s - meanConv);
[~, sortIdxConv] = sort(distConv, 'ascend');
selConv = sortIdxConv(1:min(4, numel(sortIdxConv)));

% Extract plot data
ZdivPlot = divCell.Z(selDiv, plotMask);
ZconvPlot = convCell.Z(selConv, plotMask);

% --- 5) Compute offsets to ensure traces don't touch AND align baselines (like H图)
gap = 1.5; % gap between traces
baseIdxPlot = (xsPlot >= -1) & (xsPlot < 0);

% Baseline means for each trace
baseDivArr = mean(ZdivPlot(:, baseIdxPlot), 2, 'omitnan');
baseConvArr = mean(ZconvPlot(:, baseIdxPlot), 2, 'omitnan');

% --- Right tile (Convergent) first: compute offsets
% Stack from bottom (Trial 4) to top (Trial 1)
offsetsConv = zeros(4, 1);
offsetsConv(4) = 0;
for iT = 3:-1:1
	prevMax = max(ZconvPlot(iT+1, :) + offsetsConv(iT+1), [], 'omitnan');
	currMin = min(ZconvPlot(iT, :), [], 'omitnan');
	offsetsConv(iT) = prevMax - currMin + gap;
end
baseTicksConv = baseConvArr + offsetsConv;

% --- Left tile (Divergent): align each baseline to corresponding right tile baseline
offsetsDiv = baseTicksConv - baseDivArr;

% Check if left tile traces overlap after alignment, and adjust if needed
for iT = 3:-1:1
	currMax = max(ZdivPlot(iT+1, :) + offsetsDiv(iT+1), [], 'omitnan');
	currMin = min(ZdivPlot(iT, :) + offsetsDiv(iT), [], 'omitnan');
	if currMax >= currMin - gap
		% Need to push trace iT up
		extraShift = currMax - currMin + gap;
		offsetsDiv(iT) = offsetsDiv(iT) + extraShift;
	end
end
baseTicksDiv = baseDivArr + offsetsDiv;

% --- 6) Plot
f = figure('Color','w', 'Name', 'English Fig1K Divergence Representative Cells');
f.Units = 'centimeters';
f.Position(3:4) = [4.5, 4.0]; % 45mm x 40mm (same as H)

TL = tiledlayout(1, 2, 'TileSpacing', 'compact', 'Padding', 'compact');

% --- Left tile: Divergent cell
ax1 = nexttile(TL);
hold(ax1, 'on');

for iT = 1:4
	trace = ZdivPlot(iT, :) + offsetsDiv(iT);
	plot(ax1, xsPlot, trace, '-', 'LineWidth', 1, 'Color', [0.3 0.3 0.3]);
end

xline(ax1, 0, ':k');
xline(ax1, 1, '-k');
xlim(ax1, [-1 2]);
title(ax1, 'Divergent cell', 'FontSize', 6);
% Use right tile's baseline yticks (they should now be aligned)
[sortedTicks, sortIdx] = sort(baseTicksConv);
trialLabels = {'Trial 1', 'Trial 2', 'Trial 3', 'Trial 4'};
ax1.YTick = sortedTicks;
ax1.YTickLabel = trialLabels(sortIdx);
ax1.FontSize = 6;
box(ax1, 'off');
try ax1.Toolbar.Visible = 'off'; catch, end

% --- Right tile: Convergent cell
ax2 = nexttile(TL);
hold(ax2, 'on');

for iT = 1:4
	trace = ZconvPlot(iT, :) + offsetsConv(iT);
	plot(ax2, xsPlot, trace, '-', 'LineWidth', 1, 'Color', [0.3 0.3 0.3]);
end

xline(ax2, 0, ':k');
xline(ax2, 1, '-k');
xlim(ax2, [-1 2]);
title(ax2, 'Convergent cell', 'FontSize', 6);
ax2.YTick = sortedTicks;
ax2.YTickLabel = trialLabels(sortIdx);
ax2.FontSize = 6;
box(ax2, 'off');
try ax2.Toolbar.Visible = 'off'; catch, end

% Unify ylim
MATLAB.Graphics.UnifyAxesLims([ax1, ax2], @ylim);

% Shared xlabel
xlabel(TL, 'Time (s)', 'FontSize', 6);

% --- 6) Export
try
	if ~isfolder(outDirUNC)
		mkdir(outDirUNC);
	end
catch
end

svgPath = fullfile(outDirUNC, svgName);
try
	TransferLearning.PrintFigure(f, svgPath);
	fprintf('Wrote: %s\n', svgPath);
catch ME
	warning(ME.identifier, 'Export failed: %s', ME.message);
end
