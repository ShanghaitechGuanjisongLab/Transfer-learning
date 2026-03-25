% 中文图333C：模仿英文图2C，比较 Naive / Transfer 💡💧 的 inter-trial divergence PCA（2x2）

if ~exist('UniExp.DataSet', 'class')
	thisFile = mfilename('fullpath');
	thisDir = fileparts(thisFile);
	prjFile = fullfile(thisDir, '..', 'Transferlearning.prj');
	if exist(prjFile, 'file')
		matlab.project.loadProject(prjFile);
	end
end

originSec = 0.0;
minTrialsPerCell = 20;
avgGroupSize = 2;

LAB = TransferLearning.LightAudioBaseline();
LAI = TransferLearning.LAInterspersed();
ALB = TransferLearning.AudioLightBaseline();

GNaive23 = iBuildLightSuperMouse({LAB, LAI}, "Naive", "MOp2/3", minTrialsPerCell, avgGroupSize);
GTran23 = iBuildLightSuperMouse({ALB}, "Transfer", "MOp2/3", minTrialsPerCell, avgGroupSize);
GNaive5 = iBuildLightSuperMouse({LAB, LAI}, "Naive", "MOp5", minTrialsPerCell, avgGroupSize);
GTran5 = iBuildLightSuperMouse({ALB}, "Transfer", "MOp5", minTrialsPerCell, avgGroupSize);

f = figure('Color', 'w', 'Name', '中文图333C Naive Transfer Light PCA');
f.Units = 'centimeters';
f.Position(3:4) = [3, 4];
f.PaperUnits = 'centimeters';
f.PaperPositionMode = 'manual';
f.PaperPosition = [0, 0, 3, 4];
f.PaperSize = [3, 4];

Layout = tiledlayout(f, 2, 2, 'TileSpacing', 'compact', 'Padding', 'compact');

palette2 = [1, 0, 0; 0, 0, 1];
ax1 = nexttile(Layout, 1);
iPlotPcaOnAxes(ax1, GNaive23, "Naive 💡💧 MOp2/3", originSec, palette2(1,:));

ax2 = nexttile(Layout, 2);
iPlotPcaOnAxes(ax2, GTran23, "Transfer 💡💧 MOp2/3", originSec, palette2(2,:));

ax3 = nexttile(Layout, 3);
iPlotPcaOnAxes(ax3, GNaive5, "Naive 💡💧 MOp5", originSec, palette2(1,:));

ax4 = nexttile(Layout, 4);
iPlotPcaOnAxes(ax4, GTran5, "Transfer 💡💧 MOp5", originSec, palette2(2,:));

MATLAB.Graphics.UnifyAxesLims([ax1, ax2, ax3, ax4], @xlim);
MATLAB.Graphics.UnifyAxesLims([ax1, ax2, ax3, ax4], @ylim);

outDirUNC = fullfile("\\Data-Server-2\个人数据\张天夫", char(datetime('now', 'Format', 'yyyyMM')));
if ~isfolder(outDirUNC)
	mkdir(outDirUNC);
end
svgPath = fullfile(outDirUNC, '中文图Fig333C_NaiveTransferLight_InterTrialDivergence_PCA.svg');
print(f, svgPath, '-dsvg');
fprintf('Wrote: %s\n', svgPath);

assignin('base', 'Fig333C_Groups', struct('Naive23', GNaive23, 'Transfer23', GTran23, 'Naive5', GNaive5, 'Transfer5', GTran5));

function GroupNtatsOut = iBuildLightSuperMouse(DSList, phaseName, zLayer, minTrialsPerCell, avgGroupSize)
	cellTraces = {};
	for iDS = 1:numel(DSList)
		DS = DSList{iDS};
		if string(phaseName) == "Naive" && contains(class(DS), 'LAInterspersed')
			excludeMice = iFindMiceWithAudioWaterInPhase(DS, "Naive");
		else
			excludeMice = strings(0, 1);
		end
		Sess = iChosenPureSessionTrials(DS, string(phaseName), "LightWater", excludeMice);
		if isempty(Sess)
			continue;
		end
		ntsCell = DS.QueryNTS(struct('Phase', string(phaseName), 'Stimulus', "LightWater"), UniExp.Flags.ZScore, 1:24);
		if isempty(ntsCell) || isempty(ntsCell{1})
			continue;
		end
		nts = ntsCell{1};
		T = innerjoin(nts, Sess, 'Keys', 'TrialUID');
		if isempty(T)
			continue;
		end
		T = iFilterTableByZLayer(DS, T, zLayer);
		if isempty(T)
			continue;
		end
		T = sortrows(T, ["Mouse", "DateTime", "TrialIndex", "CellUID"]);
		cellTraces = [cellTraces; iCollectCellTraces(T, minTrialsPerCell)]; %#ok<AGROW>
	end
	if isempty(cellTraces)
		error('Fig333C:EmptySuperMouse', 'No pooled cell traces for %s %s.', phaseName, zLayer);
	end
	GroupNtatsOut = iAverageAdjacentTrials(iCellTracesToNtatsGroup(cellTraces), avgGroupSize);
end

function Sess = iChosenPureSessionTrials(DS, phaseName, stimulusName, excludeMice)
	T = DS.TableQuery(["Mouse", "DateTime", "TrialUID", "TrialIndex", "Stimulus", "Phase"], Phase=phaseName);
	if isempty(T)
		Sess = table();
		return;
	end
	T.Mouse = string(T.Mouse);
	T.Stimulus = string(T.Stimulus);
	T.Phase = string(T.Phase);
	T.DateTime = iNormalizeDateTime(T.DateTime);
	if ~isempty(excludeMice)
		T = T(~ismember(T.Mouse, string(excludeMice(:))), :);
	end
	mice = unique(T.Mouse);
	Rows = cell(numel(mice), 1);
	for iM = 1:numel(mice)
		m = mice(iM);
		Tm = T(T.Mouse == m, :);
		dts = sort(unique(Tm.DateTime), 'ascend');
		picked = table();
		for iD = 1:numel(dts)
			R = Tm(Tm.DateTime == dts(iD), :);
			if any(R.Stimulus == stimulusName) && ~any(R.Stimulus ~= stimulusName)
				picked = sortrows(R(R.Stimulus == stimulusName, ["Mouse", "DateTime", "TrialUID", "TrialIndex"]), 'TrialIndex');
				break;
			end
		end
		if isempty(picked)
			Rows{iM} = table();
		else
			Rows{iM} = picked;
		end
	end
	Rows = Rows(~cellfun(@isempty, Rows));
	if isempty(Rows)
		Sess = table();
	else
		Sess = vertcat(Rows{:});
	end
end

function traces = iCollectCellTraces(T, minTrialsPerCell)
	traces = {};
	cellUIDs = unique(uint64(T.CellUID), 'stable');
	for iC = 1:numel(cellUIDs)
		cid = cellUIDs(iC);
		Tc = T(uint64(T.CellUID) == cid, :);
		Tc = sortrows(Tc, 'TrialIndex');
		sig = double(Tc.TrialSignal);
		if size(sig, 1) < minTrialsPerCell
			continue;
		end
		sig = sig(1:minTrialsPerCell, :);
		if any(~isfinite(sig), 'all')
			continue;
		end
		traces{end+1, 1} = sig; %#ok<AGROW>
	end
end

function G = iCellTracesToNtatsGroup(cellTraces)
	nCell = numel(cellTraces);
	nTrial = size(cellTraces{1}, 1);
	nTime = size(cellTraces{1}, 2);
	X = nan(nCell, nTime, nTrial);
	idx0 = 24;
	for iC = 1:nCell
		sig = cellTraces{iC};
		sig = sig - sig(:, idx0);
		X(iC, :, :) = sig';
	end
	G = table(MATLAB.DataTypes.NDTable(X), 'VariableNames', "NTATS");
end

function Gout = iAverageAdjacentTrials(Gin, groupSize)
	X = Gin.NTATS{:,:,:};
	nTrial = size(X, 3);
	nKeep = floor(nTrial / groupSize) * groupSize;
	if nKeep < groupSize * 2
		error('Fig333C:TooFewTrialGroups', 'Need at least two averaged trial groups for PCA.');
	end
	X = X(:, :, 1:nKeep);
	nGroup = nKeep / groupSize;
	Xr = reshape(X, size(X,1), size(X,2), groupSize, nGroup);
	Xg = mean(Xr, 3, 'omitnan');
	Xg = reshape(Xg, size(X,1), size(X,2), nGroup);
	Gout = table(MATLAB.DataTypes.NDTable(Xg), 'VariableNames', "NTATS");
end

function iPlotPcaOnAxes(ax, GroupNtats, titleText, originSec, lineColor)
	PcaTable = UniExp.LinearPca(GroupNtats.NTATS, 2);
	PcaLines = PcaTable.Score;
	PcaDataAll = PcaLines.Data;
	nTime = size(PcaDataAll, 2);
	sampleRate = 8;
	idxCue0 = 3 * sampleRate;
	idxWater1 = idxCue0 + round(1.0 * sampleRate);
	idxPlotTime = idxCue0:idxWater1;
	PcaData = PcaDataAll(:, idxPlotTime, :);
	originIdx = 1 + round(originSec * sampleRate);
	originIdx = max(1, min(size(PcaData, 2), originIdx));
	baseline = PcaData(:, originIdx, :);
	PcaData = PcaData - baseline;
	ax.FontSize = 6;
	ax.FontName = 'Segoe UI Emoji';
	ax.LineWidth = 1;
	box(ax, 'off');
	grid(ax, 'off');
	hold(ax, 'on');
	nLines = size(PcaData, 3);
	cmap = iTintRamp(lineColor, nLines);
	Markers = table;
	Markers.Index = numel(idxPlotTime);
	Markers.Shape = "^";
	[~, scatters] = UniExp.SegmentFadePlot(table(permute(PcaData, [3, 1, 2]), cmap, 'VariableNames', ["Points", "Color"]), Markers, ax, 'PatchArguments', {'LineWidth', 1}, 'ScatterArguments', {'SizeData', 9, 'MarkerEdgeColor', 'k', 'MarkerFaceColor', 'w', 'LineWidth', 0.2, 'MarkerFaceAlpha', 1});
	if ~isempty(scatters)
		uistack(scatters, 'top');
	end
	xlabel(ax, sprintf('PC1 (%.2g%%)', PcaTable.Explained(1)), 'FontSize', 6);
	ylabel(ax, sprintf('PC2 (%.2g%%)', PcaTable.Explained(2)), 'FontSize', 6);
	title(ax, titleText, 'FontSize', 6, 'FontWeight', 'normal');
	view(ax, 2);
	if isprop(ax, 'Toolbar') && ~isempty(ax.Toolbar)
		ax.Toolbar.Visible = 'off';
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

function badMice = iFindMiceWithAudioWaterInPhase(DS, phaseName)
	T = DS.TableQuery(["Mouse", "BlockUID"], Phase=phaseName);
	if isempty(T)
		badMice = strings(0, 1);
		return;
	end
	Tr = DS.Trials;
	TrStim = string(Tr.Stimulus);
	TrBU = uint64(Tr.BlockUID);
	T.Mouse = string(T.Mouse);
	blkBU = uint64(T.BlockUID);
	mice = unique(T.Mouse);
	bad = false(size(mice));
	for i = 1:numel(mice)
		bu = blkBU(T.Mouse == mice(i));
		rows = ismember(TrBU, bu);
		bad(i) = any(TrStim(rows) == "AudioWater");
	end
	badMice = mice(bad);
end

function T = iFilterTableByZLayer(DS, T, zLayer)
	C = DS.Cells(:, {'CellUID', 'ZLayer'});
	uid = uint64(T.CellUID);
	Cu = uint64(C.CellUID);
	[tf, loc] = ismember(uid, Cu);
	z = strings(size(uid));
	z(tf) = string(C.ZLayer(loc(tf)));
	T = T(z == string(zLayer), :);
end

function dt = iNormalizeDateTime(dt)
	if isdatetime(dt)
		if ~isempty(dt.TimeZone)
			dt.TimeZone = '';
		end
		return;
	end
	dt = datetime(dt, 'ConvertFrom', 'datenum');
	if ~isempty(dt.TimeZone)
		dt.TimeZone = '';
	end
end