% 中文图332C：比较初始光水与迁移光水的1s-0s z-score（全细胞，不做筛选）

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
	error('Fig332C:No0s', 'Cannot find sample close to 0s.');
end
[idx1s, ok1s] = iFindTimeIndex(xsSec, 1, 0.25);
if ~ok1s
	error('Fig332C:No1s', 'Cannot find sample close to 1s.');
end
baseMask = (xsSec >= -3) & (xsSec < 0);
kSigma = 3;

[GInitial, initialStats] = iQueryInitialLightAll();
[GTransfer, transferStats] = iQueryTransferLightAll();
XInitial = iGetNtats2D(GInitial);
XTransfer = iGetNtats2D(GTransfer);
XInitial = iZeroAnchorZScore(XInitial, idx0s);
XTransfer = iZeroAnchorZScore(XTransfer, idx0s);
vInitial = XInitial(:, idx1s);
vTransfer = XTransfer(:, idx1s);
vInitial = vInitial(isfinite(vInitial));
vTransfer = vTransfer(isfinite(vTransfer));

activeNaive = iActiveMask(XInitial, idx1s, baseMask, kSigma);
activeTransfer = iActiveMask(XTransfer, idx1s, baseMask, kSigma);
nNaive = size(XInitial, 1);
nTransfer = size(XTransfer, 1);
nNaiveActive = sum(activeNaive);
nTransferActive = sum(activeTransfer);
[~, pActive] = fishertest([nNaiveActive, nNaive - nNaiveActive; nTransferActive, nTransfer - nTransferActive]);
compareGroup = table([1 2], 'VariableNames', {'GroupPair'});

f = figure('Color', 'w', 'Name', '中文图332C 初始/迁移光水 1s 比较');
f.Units = 'centimeters';
f.Position(3:4) = [3, 4];
f.PaperUnits = 'centimeters';
f.PaperPositionMode = 'manual';
f.PaperPosition = [0, 0, 3, 4];
f.PaperSize = [3, 4];

TL = tiledlayout(f, 2, 1, 'TileSpacing', 'compact', 'Padding', 'compact');
axTop = nexttile(TL, 1);
[~, optTop, Bars, EB] = UniExp.BarScatterCompare({double(vInitial(:)), double(vTransfer(:))}, UniExp.Flags.empty, compareGroup, UniExp.Flags.IndividualErrorbars, 'AsteriskThreshold', 0.05);
pZScore = iExtractFirstPValue(optTop);
iTagPValueObjects(optTop);
delete(findobj(axTop, 'Type', 'Scatter'));
ax = axTop;
ax.FontSize = 6;
ax.FontName = 'Segoe UI Emoji';
ax.LineWidth = 1;
if isprop(ax.XAxis, 'LineWidth')
	ax.XAxis.LineWidth = 1;
	ax.YAxis.LineWidth = 1;
end
ylabel(ax, 'z-score');
ax.XTick = [];
ax.XTickLabel = {};
box(ax, 'off');
grid(ax, 'off');

groupColors = TransferLearning.GroupColors(["Naive", "Continual"]);
colorInitial = groupColors(1, :);
colorTransfer = groupColors(2, :);
if isscalar(Bars)
	Bars.FaceColor = 'flat';
	Bars.CData = [colorInitial; colorTransfer];
	Bars.BarWidth = 0.5;
	Bars.LineWidth = 1;
	Bars.BaseLine.LineWidth = 1;
	Bars.EdgeColor = 'none';
	Bars.FaceAlpha = 1;
else
	for ib = 1:numel(Bars)
		if ib == 1
			Bars(ib).FaceColor = colorInitial;
		else
			Bars(ib).FaceColor = colorTransfer;
		end
		Bars(ib).BarWidth = 0.5;
		Bars(ib).FaceAlpha = 1;
		Bars(ib).LineWidth = 1;
		Bars(ib).BaseLine.LineWidth = 1;
		Bars(ib).EdgeColor = 'none';
	end
end

iStyleIndividualErrorbars(EB, colorInitial, colorTransfer);

for ln = findobj(ax, 'Type', 'Line')'
	ln.LineWidth = 1;
end

scatters = findobj(ax, 'Type', 'Scatter');
for is = 1:numel(scatters)
	scatters(is).LineWidth = 0.2;
	if isprop(scatters(is), 'MarkerEdgeAlpha')
		scatters(is).MarkerEdgeAlpha = 0.5;
	end
	if isprop(scatters(is), 'MarkerFaceAlpha')
		scatters(is).MarkerFaceAlpha = 0.6;
	end
end

allText = findall(f, 'Type', 'Text');
for it = 1:numel(allText)
	allText(it).FontSize = 6;
end

allAxes = findall(f, 'Type', 'Axes');
for ia = 1:numel(allAxes)
	allAxes(ia).FontSize = 6;
end

axBottom = nexttile(TL, 2);
[~, optBottom, bars2, ebBottom] = UniExp.BarScatterCompare({double(activeNaive(:)), double(activeTransfer(:))}, UniExp.Flags.empty, compareGroup, UniExp.Flags.IndividualErrorbars, 'AsteriskThreshold', 0.05);
iTagPValueObjects(optBottom);
delete(findobj(axBottom, 'Type', 'Scatter'));
axBottom.FontSize = 6;
axBottom.FontName = 'Segoe UI Emoji';
axBottom.LineWidth = 1;
if isprop(axBottom.XAxis, 'LineWidth')
	axBottom.XAxis.LineWidth = 1;
	axBottom.YAxis.LineWidth = 1;
end
axBottom.XTick = [1 2];
axBottom.XTickLabel = {'Naive', 'Continual'};
ylabel(axBottom, 'Active fraction');
box(axBottom, 'off');
grid(axBottom, 'off');

iStyleBars(bars2, colorInitial, colorTransfer);
iStyleIndividualErrorbars(ebBottom, colorInitial, colorTransfer);
ylim(axBottom, [0, max(0.1, axBottom.YLim(2))]);

allText = findall(f, 'Type', 'Text');
for it = 1:numel(allText)
	allText(it).FontSize = 6;
end

if isprop(ax, 'Toolbar') && ~isempty(ax.Toolbar)
	ax.Toolbar.Visible = 'off';
end
if isprop(axBottom, 'Toolbar') && ~isempty(axBottom.Toolbar)
	axBottom.Toolbar.Visible = 'off';
end

outDirUNC = fullfile('\\Data-Server-2\个人数据\张天夫', char(datetime('now', 'Format', 'yyyyMM')));
if ~isfolder(outDirUNC)
	mkdir(outDirUNC);
end
svgPath = '中文图Fig44C_InitialTransferLight_1s_BarScatter.svg';
svgPath = TransferLearning.ExportStandardFigure(f, 1, svgPath);
fprintf('Wrote: %s\n', svgPath);
fprintf('Fig332C Naive: %d mice, %d cells\n', initialStats.MouseCount, initialStats.CellCount);
fprintf('Fig332C Continual: %d mice, %d cells\n', transferStats.MouseCount, transferStats.CellCount);
fprintf('Fig332C 1s z-score BarScatterCompare p = %.6g\n', pZScore);
fprintf('Fig332C active fraction Fisher exact p = %.6g\n', pActive);

assignin('base', 'Fig332C_NTATS1s', struct('Initial', vInitial, 'Transfer', vTransfer, 'Idx0', idx0s, 'Idx1', idx1s, 'XsSec', xsSec, 'ActiveNaive', activeNaive, 'ActiveTransfer', activeTransfer, 'PZScore', pZScore, 'PActive', pActive, 'InitialStats', initialStats, 'TransferStats', transferStats));

function [G, stats] = iQueryInitialLightAll()
LAB = TransferLearning.LightAudioBaseline();
LAI = TransferLearning.LAInterspersed();
qNaiveLW = struct('Phase', 'Naive', 'Stimulus', 'LightWater');
badNaive = iFindMiceWithAudioWaterInPhase(LAI, "Naive");
qNaiveLW_LAI = qNaiveLW;
qNaiveLW_LAI.Mouse = iMiceInPhaseStimulus(LAI, "Naive", "LightWater", badNaive);
G1 = LAB.QueryNTATS(qNaiveLW, UniExp.Flags.ZScore, 1:24, UniExp.Flags.Median);
G2 = LAI.QueryNTATS(qNaiveLW_LAI, UniExp.Flags.ZScore, 1:24, UniExp.Flags.Median);
G = iVcatNtatsTables(G1, G2);
stats = iGroupStats({G1, G2}, {LAB, LAI});
end

function [G, stats] = iQueryTransferLightAll()
ALB = TransferLearning.AudioLightBaseline();
qTransferLW = struct('Phase', 'Transfer', 'Stimulus', 'LightWater');
G = ALB.QueryNTATS(qTransferLW, UniExp.Flags.ZScore, 1:24, UniExp.Flags.Median);
stats = iGroupStats({G}, {ALB});
end

function mice = iMiceInPhaseStimulus(DS, phaseName, stimulusName, excludeMice)
T = DS.TableQuery("Mouse", Phase=phaseName, Stimulus=stimulusName);
if isempty(T)
	mice = string.empty(0,1);
	return;
end
mice = unique(string(T.Mouse));
mice = mice(~ismember(mice, string(excludeMice(:))));
end

function badMice = iFindMiceWithAudioWaterInPhase(DS, phaseName)
T = DS.TableQuery(["Mouse","BlockUID"], Phase=phaseName);
if isempty(T)
	badMice = strings(0,1);
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

function G = iVcatNtatsTables(G1, G2)
if isempty(G1)
	G = G2;
elseif isempty(G2)
	G = G1;
else
	G = [G1; G2];
end
end

function stats = iGroupStats(groupTables, dataSets)
cellCount = 0;
mouseNames = strings(0, 1);
for iGroup = 1:numel(groupTables)
	G = groupTables{iGroup};
	if isempty(G)
		continue;
	end
	cellCount = cellCount + height(G);
	cellMeta = dataSets{iGroup}.Cells(:, ["CellUID", "Mouse"]);
	cellMeta.Mouse = string(cellMeta.Mouse);
	[matched, loc] = ismember(uint64(G.CellUID), uint64(cellMeta.CellUID));
	mouseNames = [mouseNames; cellMeta.Mouse(loc(matched))]; %#ok<AGROW>
end
mouseNames = unique(mouseNames(~ismissing(mouseNames) & strlength(mouseNames) > 0), 'stable');
stats = struct('MouseCount', numel(mouseNames), 'CellCount', cellCount, 'MouseNames', mouseNames);
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
	error('Fig332C:BadNTATS', 'Unsupported NTATS container type: %s', class(nt));
end

function X = iZeroAnchorZScore(X, idx0s)
X = X - X(:, idx0s);
end

function [idx, ok] = iFindTimeIndex(xsSec, tSec, tolSec)
[d, idx] = min(abs(xsSec(:) - tSec));
ok = isfinite(d) && (d <= tolSec);
end

function mask = iActiveMask(X, idx1s, baseMask, kSigma)
baseMu = mean(X(:, baseMask), 2, 'omitnan');
baseSd = std(X(:, baseMask), 0, 2, 'omitnan');
v1 = X(:, idx1s);
mask = isfinite(v1) & isfinite(baseMu) & isfinite(baseSd) & (v1 > (baseMu + kSigma * baseSd));
end

function iStyleBars(Bars, colorInitial, colorTransfer)
if isscalar(Bars)
	Bars.FaceColor = 'flat';
	nBars = numel(Bars.YData);
	barColors = repmat([colorInitial; colorTransfer], ceil(nBars / 2), 1);
	Bars.CData = barColors(1:nBars, :);
	Bars.BarWidth = 0.5;
	Bars.LineWidth = 1;
	Bars.BaseLine.LineWidth = 1;
	Bars.EdgeColor = 'none';
	Bars.FaceAlpha = 1;
	return;
end
for ib = 1:numel(Bars)
	if ib == 1
		Bars(ib).FaceColor = colorInitial;
	else
		Bars(ib).FaceColor = colorTransfer;
	end
	Bars(ib).LineWidth = 1;
	Bars(ib).BarWidth = 0.5;
	Bars(ib).BaseLine.LineWidth = 1;
	Bars(ib).EdgeColor = 'none';
	Bars(ib).FaceAlpha = 1;
end
end

function iStyleIndividualErrorbars(ErrorBars, colorInitial, colorTransfer)
if istable(ErrorBars) && ismember('Object', ErrorBars.Properties.VariableNames)
	errorObjects = ErrorBars.Object;
elseif isstruct(ErrorBars) && isfield(ErrorBars, 'Object')
	errorObjects = ErrorBars.Object;
else
	return;
end
barColors = [colorInitial; colorTransfer];
for iObj = 1:numel(errorObjects)
	eb = errorObjects(iObj);
	eb.LineWidth = 1;
	if isprop(eb, 'Color')
		x = double(eb.XData(:));
		[~, colorIndex] = min(abs((1:size(barColors, 1)).' - x(1)));
		eb.Color = barColors(colorIndex, :);
	end
	if isprop(eb, 'LineStyle')
		eb.LineStyle = 'none';
	end
	if isprop(eb, 'CapSize')
		eb.CapSize = 5.28;
	end
end
end

function pValue = iExtractFirstPValue(options)
pValue = NaN;
if isfield(options, 'MultiCompare') && istable(options.MultiCompare) && ismember('PValue', options.MultiCompare.Properties.VariableNames) && ~isempty(options.MultiCompare.PValue)
	pValue = options.MultiCompare.PValue(1);
end
end

function iTagPValueObjects(optional)
if ~isstruct(optional) || ~isfield(optional, 'MultiCompare') || ~istable(optional.MultiCompare)
	return;
end
multiCompare = optional.MultiCompare;
if ismember('PLine', multiCompare.Properties.VariableNames)
	for pLine = multiCompare.PLine(:)'
		if isgraphics(pLine)
			pLine.Tag = 'PLine';
		end
	end
end
if ismember('PText', multiCompare.Properties.VariableNames)
	for pText = multiCompare.PText(:)'
		if isgraphics(pText)
			pText.Tag = 'PText';
		end
	end
end
end

