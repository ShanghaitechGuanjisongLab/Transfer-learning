if ~exist('UniExp.DataSet', 'class')
	thisFile = mfilename('fullpath');
	thisDir = fileparts(thisFile);
	prjFile = fullfile(thisDir, '..', 'Transferlearning.prj');
	if exist(prjFile, 'file')
		matlab.project.loadProject(prjFile);
	end
end

MB = TransferLearning.MOpBaseline();
xs = TransferLearning.Xs;
if isduration(xs)
	xs = seconds(xs);
end
xsSec = double(xs(:));
idxNeg3 = 1;
idxCue = find(xsSec >= 0, 1, 'first');
if isempty(idxCue)
	error('Fig371A:NoCueIndex', 'Cannot find the first nonnegative sample as cue onset.');
end

rows = iQueryContinualLightRows(MB);
[repBlock, blockScores] = iSelectRepresentativeBlock(rows, MB, idxNeg3, idxCue);
[cellTrialTimes, trialOrder, cellUIDs] = iBuildCellTrialTimes(rows(uint64(rows.BlockUID) == repBlock.BlockUID, :), idxCue);

sampleSignal = permute(cellTrialTimes, [3, 2, 1]);
[coeff, ~, explained] = UniExp.DimensionalPca(sampleSignal([1, end], :, :), [false, false, true], 2);
trialPc1 = reshape(pagemtimes(reshape(sampleSignal, [], size(sampleSignal, 3)), coeff(:, 1)), size(sampleSignal, 1), size(sampleSignal, 2));
xPlot = xsSec(1:idxCue);
cmap = iTrialColormap(size(trialPc1, 2));

f = figure('Color', 'w', 'Name', '中文图371A Baseline convergence PC1 trajectory');
f.Units = 'centimeters';
f.Position(3:4) = [9.0, 8.0];
f.PaperUnits = 'centimeters';
f.PaperPositionMode = 'manual';
f.PaperPosition = [0, 0, 9.0, 8.0];
f.PaperSize = [9.0, 8.0];

ax = axes(f);
hold(ax, 'on');

for iTrial = 1:size(trialPc1, 2)
	line(ax, xPlot, trialPc1(:, iTrial), 'Color', cmap(iTrial, :), 'LineWidth', 2, 'HandleVisibility', 'off');
end

colormap(ax, cmap);
clim(ax, [1, size(trialPc1, 2)]);
cb = colorbar(ax);
cb.Box = 'off';
cb.FontSize = 12;
cb.Label.String = 'Trial#';
cb.Label.FontSize = 12;

ax.FontSize = 12;
ax.FontName = 'Segoe UI Emoji';
ax.LineWidth = 2;
if isprop(ax.XAxis, 'LineWidth')
	ax.XAxis.LineWidth = 2;
	ax.YAxis.LineWidth = 2;
end
box(ax, 'off');
grid(ax, 'off');

ax.XTick = -3:1:0;
ax.XTickLabel = {'-3', '-2', '-1', '💡'};
xlabel(ax, 'Time(s)');
ylabel(ax, 'PC1');
title(ax, 'Continual💡');

if isprop(ax, 'Toolbar') && ~isempty(ax.Toolbar)
	ax.Toolbar.Visible = 'off';
end

outDirUNC = fullfile('\\Data-Server-2\个人数据\张天夫', char(datetime('now', 'Format', 'yyyyMM')));
if ~isfolder(outDirUNC)
	mkdir(outDirUNC);
end
svgPath = '中文图Fig371A_BaselineConvergence_PC1Trajectory.svg';
svgPath = TransferLearning.ExportStandardFigure(f, 2, svgPath);
fprintf('Selected block: Mouse=%s | BlockUID=%d | DateTime=%s | NCell=%d | TrialCount=%d | MeanStd(-3s)=%.4f | MeanStd(0s)=%.4f | MeanLog2Ratio=%.4f\n', ...
	char(repBlock.Mouse), repBlock.BlockUID, char(string(repBlock.DateTime)), repBlock.NCell, repBlock.TrialCount, repBlock.MeanStdNeg3, repBlock.MeanStd0, repBlock.MeanLog2Ratio);
fprintf('Wrote: %s\n', svgPath);

assignin('base', 'Fig371A_SelectedBlock', repBlock);
assignin('base', 'Fig371A_BlockScores', blockScores);
assignin('base', 'Fig371A_TrialPc1', trialPc1);
assignin('base', 'Fig371A_TrialOrder', trialOrder);
assignin('base', 'Fig371A_CellUID', cellUIDs);

function rows = iQueryContinualLightRows(MB)
query = table("TransferLight", "LightWater", "Transfer", "声光无穿插", {[]}, ...
	'VariableNames', {'GroupName', 'Stimulus', 'Phase', 'Paradigm', 'Behavior'});
groupNts = MB.QueryNTS(query, ExtraColumns=["Mouse", "BlockUID", "TrialRI"]);
rows = groupNts.TransferLight;
rows.Mouse = string(rows.Mouse);
rows.BlockUID = uint64(rows.BlockUID);
rows = sortrows(rows, ["BlockUID", "CellUID", "TrialRI"]);
end

function [repBlock, blockScores] = iSelectRepresentativeBlock(rows, MB, idxNeg3, idxCue)
blockInfo = unique(MB.TableQuery(["BlockUID", "Mouse", "DateTime"], Phase="Transfer", Stimulus="LightWater", Paradigm="声光无穿插"));
blockInfo.BlockUID = uint64(blockInfo.BlockUID);
blockInfo.Mouse = string(blockInfo.Mouse);

	blockUIDs = unique(uint64(rows.BlockUID), 'stable');
	blockScores = table(uint64(blockUIDs), strings(numel(blockUIDs), 1), NaT(numel(blockUIDs), 1), nan(numel(blockUIDs), 1), ...
		nan(numel(blockUIDs), 1), nan(numel(blockUIDs), 1), nan(numel(blockUIDs), 1), nan(numel(blockUIDs), 1), ...
		'VariableNames', {'BlockUID', 'Mouse', 'DateTime', 'TrialCount', 'NCell', 'MeanStdNeg3', 'MeanStd0', 'MeanLog2Ratio'});

	for iBlock = 1:numel(blockUIDs)
		blockRows = rows(uint64(rows.BlockUID) == blockUIDs(iBlock), :);
		[cellTrialTimes, trialOrder, ~] = iBuildCellTrialTimes(blockRows, idxCue);
		blockScores.TrialCount(iBlock) = numel(trialOrder);
		blockScores.NCell(iBlock) = size(cellTrialTimes, 1);
		infoRow = blockInfo(blockInfo.BlockUID == blockUIDs(iBlock), :);
		if ~isempty(infoRow)
			blockScores.Mouse(iBlock) = infoRow.Mouse(1);
			blockScores.DateTime(iBlock) = infoRow.DateTime(1);
		end
		if size(cellTrialTimes, 1) < 2 || size(cellTrialTimes, 2) < 2
			continue;
		end
		stdMat = squeeze(std(cellTrialTimes, 0, 2));
		if isvector(stdMat)
			stdMat = reshape(stdMat, [], size(cellTrialTimes, 3));
		end
		neg3 = stdMat(:, idxNeg3);
		atCue = stdMat(:, idxCue);
		keep = isfinite(neg3) & isfinite(atCue) & (atCue > 0);
		neg3 = neg3(keep);
		atCue = atCue(keep);
		if isempty(neg3)
			continue;
		end
		blockScores.MeanStdNeg3(iBlock) = mean(neg3, 'omitnan');
		blockScores.MeanStd0(iBlock) = mean(atCue, 'omitnan');
		blockScores.MeanLog2Ratio(iBlock) = mean(log2(neg3 ./ atCue), 'omitnan');
	end

	valid = isfinite(blockScores.MeanLog2Ratio) & isfinite(blockScores.MeanStdNeg3) & isfinite(blockScores.MeanStd0);
	blockScores = blockScores(valid, :);
	if isempty(blockScores)
		error('Fig371A:NoRepresentativeBlock', 'No valid Continual LightWater block was found.');
	end
	blockScores = sortrows(blockScores, {'MeanLog2Ratio', 'MeanStdNeg3', 'MeanStd0'}, {'descend', 'descend', 'ascend'});
	repBlock = blockScores(1, :);
end

function [cellTrialTimes, trialOrder, keepCellUID] = iBuildCellTrialTimes(blockRows, endIdx)
	trialOrder = unique(double(blockRows.TrialRI), 'stable');
	cellUIDs = unique(uint64(blockRows.CellUID), 'stable');
	traceCell = cell(numel(cellUIDs), 1);
	keepCellUID = uint64([]);
	for iCell = 1:numel(cellUIDs)
		cid = cellUIDs(iCell);
		rowsC = uint64(blockRows.CellUID) == cid;
		trialRI = double(blockRows.TrialRI(rowsC));
		sig = double(blockRows.TrialSignal(rowsC, 1:endIdx));
		[tf, loc] = ismember(trialOrder, trialRI);
		if ~all(tf)
			continue;
		end
		ordered = sig(loc, :);
		if any(~isfinite(ordered), 'all')
			continue;
		end
		traceCell{iCell} = ordered;
		keepCellUID(end + 1, 1) = cid; %#ok<AGROW>
	end

	keep = ~cellfun(@isempty, traceCell);
	traceCell = traceCell(keep);
	if isempty(traceCell)
		cellTrialTimes = nan(0, numel(trialOrder), endIdx);
		keepCellUID = uint64([]);
		return;
	end

	cellTrialTimes = nan(numel(traceCell), numel(trialOrder), endIdx);
	for iCell = 1:numel(traceCell)
		cellTrialTimes(iCell, :, :) = traceCell{iCell};
	end
	keepCellUID = keepCellUID(keep);
end

function cmap = iTrialColormap(nTrial)
	if nTrial <= 1
		cmap = [0.15, 0.75, 0.20];
		return;
	end
	startColor = [0.15, 0.75, 0.20];
	endColor = [0.90, 0.05, 0.95];
	mix = linspace(0, 1, nTrial).';
	cmap = (1 - mix) .* startColor + mix .* endColor;
end

