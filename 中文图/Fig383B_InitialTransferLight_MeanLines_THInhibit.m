% 中文图383B：初始光水、迁移光水与 TH 抑制组均值钙曲线

if ~exist('UniExp.DataSet', 'class')
	thisFile = mfilename('fullpath');
	thisDir = fileparts(thisFile);
	prjFile = fullfile(thisDir, '..', 'Transferlearning.prj');
	if exist(prjFile, 'file')
		matlab.project.loadProject(prjFile);
	end
end

xs = TransferLearning.Xs;
if ~isduration(xs)
	xs = seconds(xs);
end
xsSec = seconds(xs);
[idx0s, ok0s] = iFindTimeIndex(xsSec, 0, 0.25);
if ~ok0s
	error('Fig383B:No0s', 'Cannot find sample close to 0s.');
end
xMask = (xsSec >= 0) & (xsSec <= 2);
xsPlot = xsSec(xMask);

GTransfer = iQueryTransferLightAll();
XTransferByLayer = iNtatsByLayer(GTransfer);
XTHByLayer = iQueryTHInhibitLightAll_Fig3HStyle();

f = figure('Color', 'w', 'Name', '中文图383B 初始/迁移/TH 光水均值线');
f.Units = 'centimeters';
f.Position(3:4) = [12, 12];
f.PaperUnits = 'centimeters';
f.PaperPositionMode = 'manual';
f.PaperPosition = [0, 0, 12, 12];
f.PaperSize = [12, 12];

Layout = tiledlayout(f, 2, 1, 'TileSpacing', 'compact', 'Padding', 'compact');
title(Layout, 'Real mice', 'FontSize', 12, 'FontWeight', 'normal');
ylabel(Layout, 'z-score', 'FontSize', 12);

lineColors = TransferLearning.FigurePalette(3);
lineColors = lineColors([2 3], :);
groupLabels = ["Continual", "TH inhibited"];
layerFields = ["L23", "L5"];
layerTitles = ["L2/3", "L5"];
nGroup = numel(groupLabels);
nTime = numel(xsPlot);
Stats = struct();
for iLayer = 1:numel(layerFields)
	layerField = char(layerFields(iLayer));
	XTransfer = iPrepareTraceMatrix(XTransferByLayer.(layerField), idx0s, xMask);
	XTH = iPrepareTraceMatrix(XTHByLayer.(layerField), idx0s, xMask);
	[Y, E, nEff] = iMeanSemByGroup({XTransfer, XTH}, nTime, nGroup);
	Stats.(layerField).Mean = Y;
	Stats.(layerField).SEM = E;
	Stats.(layerField).N = nEff;
	fprintf('%s Continual rows: %d\n', char(layerTitles(iLayer)), size(XTransfer, 1));
	fprintf('%s TH inhibited rows: %d\n', char(layerTitles(iLayer)), size(XTH, 1));
	Stats.(layerField).ContinualVsTHInhibitedP = iLineComparisonPValue(XTransfer, XTH);

	ax = nexttile(Layout, iLayer);
	hold(ax, 'on');
	ax.FontSize = 12;
	ax.FontName = 'Segoe UI Emoji';
	ax.LineWidth = 2;
	ax.XAxis.LineWidth = 2;
	ax.YAxis.LineWidth = 2;

	Patches = MATLAB.Graphics.MultiShadowedLines( ...
		Y, E, 0.2, ...
		X=repmat(xsPlot(:), 1, nGroup), ...
		EdgeColors=lineColors, ...
		Ax=ax, ...
		LineStyles=repmat("-", nGroup, 1));
	for p = Patches(:)'
		p.LineWidth = 2;
	end

	xline(ax, 0, '--k', 'LineWidth', 2);
	xline(ax, 1, '-k', 'LineWidth', 2);
	box(ax, 'off');
	grid(ax, 'off');
	if iLayer == numel(layerFields)
		xlabel(ax, 'Time', 'FontSize', 12);
	else
		ax.XAxis.Visible = 'off';
	end
	ylabel(ax, layerTitles(iLayer), 'FontSize', 12);
	iAnnotateLineComparison(ax, xsPlot, Y, Stats.(layerField).ContinualVsTHInhibitedP);
	ax.XTick = [0 1];
	ax.XTickLabel = {"💡", "💧"};
	if iLayer == 1
		lg = legend(Patches, groupLabels, 'Location', 'north', 'Orientation', 'horizontal', 'NumColumns', nGroup, 'Box', 'off');
		lg.Layout.Tile = 'north';
		lg.FontSize = 12;
	end
	if isprop(ax, 'Toolbar') && ~isempty(ax.Toolbar)
		ax.Toolbar.Visible = 'off';
	end
end

svgPath = TransferLearning.ExportStandardFigure(f, 2, '中文图Fig383B_InitialTransferLight_MeanLines_THInhibit.svg');
fprintf('Wrote: %s\n', svgPath);

assignin('base', 'Fig383B_InitialTransferTH_ByLayer', Stats);

function G = iQueryTransferLightAll()
ALB = TransferLearning.AudioLightBaseline();
qTransferLW = struct('Phase', 'Transfer', 'Stimulus', 'LightWater');
G = ALB.QueryNTATS(qTransferLW, UniExp.Flags.ZScore, 1:24, UniExp.Flags.Median);
G = iAttachZLayer(G, ALB);
end

function XByLayer = iQueryTHInhibitLightAll_Fig3HStyle()
THDS = TransferLearning.THInhibit();
SessTH = iLightWaterSessions(THDS);
SessTH = iKeepPureLW_NoMustWarn(THDS, SessTH);
SessTH = iKeepPhaseRange(THDS, SessTH, "Transfer", "Final");
SessTH = iExcludeCeilingSessions(SessTH);
if isempty(SessTH)
	error('Fig383B:NoTHSessions', 'No retained TH inhibited LightWater sessions using the Fig3H data path.');
end
dtTH = unique(SessTH.DateTime);
rawTH = iBatchQueryRawNTS(THDS, dtTH);
rawTH = iAttachZLayer(rawTH, THDS);
XByLayer = iSessionCellMedianTracesByLayer(rawTH, dtTH);
if isempty(XByLayer.L23) && isempty(XByLayer.L5)
	error('Fig383B:NoTHNTS', 'No TH inhibited NTS traces were retained.');
end
end

function rawTbl = iBatchQueryRawNTS(DS, dts)
q = struct('Stimulus', 'LightWater', 'DateTime', dts);
ntsCell = DS.QueryNTS(q, UniExp.Flags.ZScore, 1:24, 'ExtraColumns', "DateTime");
if isempty(ntsCell) || isempty(ntsCell{1})
	rawTbl = table();
	return;
end
rawTbl = ntsCell{1};
rawTbl.CellUID = uint64(rawTbl.CellUID);
rawTbl.DateTime = iNormDT(rawTbl.DateTime);
end

function XByLayer = iSessionCellMedianTracesByLayer(rawTbl, dts)
XByLayer = iEmptyLayerStruct();
if isempty(rawTbl)
	return;
end
layerFields = ["L23", "L5"];
layerValues = ["MOp2/3", "MOp5"];
XCells = struct();
for iLayer = 1:numel(layerFields)
	XCells.(char(layerFields(iLayer))) = cell(numel(dts), 1);
end
for iDT = 1:numel(dts)
	rows = rawTbl.DateTime == dts(iDT);
	if ~any(rows)
		continue;
	end
	sub = rawTbl(rows, :);
	sig = iTrialSignal2D(sub.TrialSignal);
	cellUIDs = uint64(sub.CellUID);
	zLayer = string(sub.ZLayer);
	for iLayer = 1:numel(layerFields)
		layerField = char(layerFields(iLayer));
		maskLayer = zLayer == layerValues(iLayer);
		uid = unique(cellUIDs(maskLayer), 'stable');
		XHere = nan(numel(uid), size(sig, 2));
		for iCell = 1:numel(uid)
			rowsCell = maskLayer & (cellUIDs == uid(iCell));
			XHere(iCell, :) = median(sig(rowsCell, :), 1, 'omitnan');
		end
		XCells.(layerField){iDT} = XHere;
	end
end
for iLayer = 1:numel(layerFields)
	layerField = char(layerFields(iLayer));
	theseCells = XCells.(layerField);
	theseCells = theseCells(~cellfun('isempty', theseCells));
	if ~isempty(theseCells)
		XByLayer.(layerField) = vertcat(theseCells{:});
	end
end
end

function XByLayer = iNtatsByLayer(G)
X = iGetNtats2D(G);
zLayer = string(G.ZLayer);
XByLayer = iEmptyLayerStruct();
XByLayer.L23 = X(zLayer == "MOp2/3", :);
XByLayer.L5 = X(zLayer == "MOp5", :);
end

function XByLayer = iEmptyLayerStruct()
XByLayer = struct('L23', [], 'L5', []);
end

function X = iPrepareTraceMatrix(X, idx0s, xMask)
X = iZeroAnchorZScore(X, idx0s);
X = X(:, xMask);
end

function [Y, E, nEff] = iMeanSemByGroup(XAll, nTime, nGroup)
Y = nan(nTime, nGroup);
E = nan(nTime, nGroup);
nEff = nan(nTime, nGroup);
for iGroup = 1:nGroup
	X = XAll{iGroup};
	Y(:, iGroup) = mean(X, 1, 'omitnan').';
	nEff(:, iGroup) = sum(isfinite(X), 1).';
	E(:, iGroup) = std(X, 0, 1, 'omitnan').' ./ sqrt(max(nEff(:, iGroup), 1));
end
end

function pValue = iLineComparisonPValue(XA, XB)
a = mean(XA, 2, 'omitnan');
b = mean(XB, 2, 'omitnan');
a = a(isfinite(a));
b = b(isfinite(b));
if isempty(a) || isempty(b)
	pValue = NaN;
	return;
end
pValue = ranksum(a, b);
end

function iAnnotateLineComparison(ax, xsPlot, Y, pValue)
if ~isfinite(pValue) || pValue >= 0.05
	return;
end
meanDiff = abs(Y(:, 1) - Y(:, 2));
meanDiff(~all(isfinite(Y), 2)) = NaN;
if all(isnan(meanDiff))
	return;
end
[~, idxMax] = max(meanDiff, [], 'omitnan');
xAt = xsPlot(idxMax);
yPair = Y(idxMax, :);
yMid = mean(yPair);
yHalfLen = abs(diff(yPair)) / 4;
if yHalfLen == 0
	yHalfLen = diff(ax.YLim) * 0.015;
end
plot(ax, [xAt xAt], [yMid - yHalfLen, yMid + yHalfLen], 'k-', 'LineWidth', 2, 'HandleVisibility', 'off');
if xAt < mean(xsPlot([1 end]))
	xText = xAt + 0.05 * range(xsPlot);
	hAlign = 'left';
else
	xText = xAt - 0.05 * range(xsPlot);
	hAlign = 'right';
end
text(ax, xText, yMid, iPToStars(pValue), 'FontSize', 12, ...
	'HorizontalAlignment', hAlign, 'VerticalAlignment', 'middle', 'HandleVisibility', 'off');
end

function stars = iPToStars(pValue)
if pValue < 0.001
	stars = '***';
elseif pValue < 0.01
	stars = '**';
else
	stars = '*';
end
end

function T = iAttachZLayer(T, DS)
if isempty(T)
	T.ZLayer = strings(0, 1);
	return;
end
CellTbl = DS.Cells(:, {'CellUID','ZLayer'});
CellTbl.CellUID = uint64(CellTbl.CellUID);
CellTbl.ZLayer = string(CellTbl.ZLayer);
T.CellUID = uint64(T.CellUID);
[tf, loc] = ismember(T.CellUID, CellTbl.CellUID);
zLayer = strings(height(T), 1);
zLayer(tf) = CellTbl.ZLayer(loc(tf));
T.ZLayer = zLayer;
end

function sig = iTrialSignal2D(trialSignal)
if isa(trialSignal, 'MATLAB.DataTypes.NDTable')
	sig = double(trialSignal.Data);
else
	sig = double(trialSignal);
end
end

function X = iZeroAnchorZScore(X, idx0s)
X = X - X(:, idx0s);
end

function X = iGetNtats2D(G)
if istable(G)
	nt = G.NTATS;
else
	nt = G;
end
if isa(nt, 'MATLAB.DataTypes.NDTable')
	X = double(nt.Data);
	return;
end
if isnumeric(nt) && ismatrix(nt)
	X = double(nt);
	return;
end
error(['Unsupported NTATS container type: ', class(nt)]);
end

function [idx, ok] = iFindTimeIndex(xsSec, tSec, tolSec)
[d, idx] = min(abs(xsSec(:) - tSec));
ok = isfinite(d) && (d <= tolSec);
end

function Sess = iLightWaterSessions(DS)
blockVars = string(DS.Blocks.Properties.VariableNames);
if any(blockVars == "MustWarn")
	Blocks = DS.Blocks(:, {'BlockUID','DateTime','MustWarn'});
else
	Blocks = DS.Blocks(:, {'BlockUID','DateTime'});
	Blocks.MustWarn = strings(height(Blocks), 1);
end
Blocks.BlockUID = uint64(Blocks.BlockUID);
Blocks.DateTime = iNormDT(Blocks.DateTime);
Blocks.MustWarn = string(Blocks.MustWarn);
DT = DS.DateTimes(:, {'DateTime','Mouse','Phase'});
DT.DateTime = iNormDT(DT.DateTime);
DT.Mouse = string(DT.Mouse);
DT.Phase = string(DT.Phase);
Tr = DS.Trials(:, {'BlockUID','Stimulus','Behavior'});
Tr.BlockUID = uint64(Tr.BlockUID);
TrLW = Tr(string(Tr.Stimulus) == "LightWater", {'BlockUID','Behavior'});
if isempty(TrLW)
	Sess = table(string.empty(0,1), NaT(0,1), string.empty(0,1), nan(0,1), 'VariableNames', {'Mouse','DateTime','Phase','Performance'});
	return;
end
[G, bu] = findgroups(uint64(TrLW.BlockUID));
lwPerf = splitapply(@(x) mean(double(x), 'omitnan'), TrLW.Behavior, G);
perfByBlock = table(uint64(bu), lwPerf, 'VariableNames', {'BlockUID','LWPerf'});
T = innerjoin(perfByBlock, Blocks, 'Keys', 'BlockUID');
keep = ismissing(T.MustWarn) | (T.MustWarn == "");
T = T(keep, :);
T = innerjoin(T, DT, 'Keys', 'DateTime');
[G2, mouse, dt] = findgroups(T.Mouse, T.DateTime);
perf2 = splitapply(@(x) mean(double(x), 'omitnan'), T.LWPerf, G2);
phase2 = splitapply(@(x) string(x(1)), T.Phase, G2);
Sess = table(mouse, dt, phase2, perf2, 'VariableNames', {'Mouse','DateTime','Phase','Performance'});
Sess = sortrows(Sess, {'Mouse','DateTime'});
end

function SessOut = iKeepPureLW_NoMustWarn(DS, SessIn)
SessOut = SessIn;
if isempty(SessOut)
	return;
end
Blocks = DS.Blocks(:, {'BlockUID','DateTime'});
Blocks.BlockUID = uint64(Blocks.BlockUID);
Blocks.DateTime = iNormDT(Blocks.DateTime);
Tr = DS.Trials(:, {'BlockUID','Stimulus'});
Tr.BlockUID = uint64(Tr.BlockUID);
TrAW = Tr(string(Tr.Stimulus) == "AudioWater", {'BlockUID'});
if isempty(TrAW)
	return;
end
blkAW = unique(uint64(TrAW.BlockUID));
TAW = innerjoin(table(blkAW, 'VariableNames', {'BlockUID'}), Blocks, 'Keys', 'BlockUID');
dtAW = unique(TAW.DateTime);
SessOut = SessOut(~ismember(SessOut.DateTime, dtAW), :);
end

function SessOut = iKeepPhaseRange(DS, SessIn, phaseStart, phaseEnd)
SessOut = SessIn;
if isempty(SessOut)
	return;
end
DT = DS.DateTimes(:, {'DateTime','Mouse','Phase'});
DT.DateTime = iNormDT(DT.DateTime);
DT.Mouse = string(DT.Mouse);
DT.Phase = string(DT.Phase);
keep = false(height(SessOut), 1);
for mouseName = unique(string(SessOut.Mouse))'
	dtM = DT(DT.Mouse == mouseName, :);
	phDates = dtM.DateTime(dtM.Phase == phaseStart);
	endDates = dtM.DateTime(dtM.Phase == phaseEnd);
	if isempty(phDates) || isempty(endDates)
		continue;
	end
	startDT = min(phDates);
	endDT = max(endDates);
	rows = (string(SessOut.Mouse) == mouseName) & (SessOut.DateTime >= startDT) & (SessOut.DateTime <= endDT);
	keep = keep | rows;
end
SessOut = SessOut(keep, :);
end

function SessOut = iExcludeCeilingSessions(SessIn)
SessOut = sortrows(SessIn, {'Mouse','DateTime'});
remove = false(height(SessOut), 1);
for mouseName = unique(SessOut.Mouse)'
	rows = find(SessOut.Mouse == mouseName);
	p = double(SessOut.Performance(rows));
	i100 = find(p >= 1 - 1e-12, 1, 'first');
	if ~isempty(i100)
		remove(rows(i100:end)) = true;
	end
end
SessOut(remove, :) = [];
perf = double(SessOut.Performance);
SessOut = SessOut(isfinite(perf) & perf >= -1e-12 & perf < 1 - 1e-12, :);
end

function dt = iNormDT(dt)
dt = datetime(dt);
if ~isempty(dt) && ~isempty(dt.TimeZone)
	dt.TimeZone = '';
end
end