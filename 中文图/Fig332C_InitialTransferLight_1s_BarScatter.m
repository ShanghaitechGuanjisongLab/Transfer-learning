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

GInitial = iQueryInitialLightAll();
GTransfer = iQueryTransferLightAll();
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
[~, ~, Bars, EB] = UniExp.BarScatterCompare({double(vInitial(:)), double(vTransfer(:))}, false, compareGroup);
delete(findobj(axTop, 'Type', 'Scatter'));
ax = axTop;
ax.FontSize = 6;
ax.FontName = 'Segoe UI Emoji';
ax.LineWidth = 1;
if isprop(ax.XAxis, 'LineWidth')
	ax.XAxis.LineWidth = 1;
	ax.YAxis.LineWidth = 1;
end
ylabel(ax, '\Delta z-score');
ax.XTick = [];
ax.XTickLabel = {};
box(ax, 'off');
grid(ax, 'off');

palette2 = TransferLearning.FigurePalette(2);
colorInitial = palette2(1, :);
colorTransfer = palette2(2, :);
if isscalar(Bars)
	Bars.FaceColor = 'flat';
	Bars.CData = [colorInitial; colorTransfer];
	Bars.BarWidth = 0.5;
	Bars.LineWidth = 1;
	Bars.BaseLine.LineWidth = 1;
	Bars.EdgeColor = 'none';
	Bars.FaceAlpha = 1/3;
else
	for ib = 1:numel(Bars)
		if ib == 1
			Bars(ib).FaceColor = colorInitial;
		else
			Bars(ib).FaceColor = colorTransfer;
		end
		Bars(ib).FaceAlpha = 1/3;
		Bars(ib).LineWidth = 1;
		Bars(ib).BaseLine.LineWidth = 1;
		Bars(ib).EdgeColor = 'none';
	end
end

for eb = EB.Object(:)'
	eb.LineWidth = 1;
	if isprop(eb, 'Color')
		eb.Color = [0 0 0];
	end
	if isprop(eb, 'LineStyle')
		eb.LineStyle = 'none';
	end
end

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
	if isprop(allText(it), 'String')
		allText(it).String = iPTextToStars(allText(it).String);
	end
end

allAxes = findall(f, 'Type', 'Axes');
for ia = 1:numel(allAxes)
	allAxes(ia).FontSize = 6;
end

axBottom = nexttile(TL, 2);
[~, optBottom, bars2, ebBottom] = UniExp.BarScatterCompare({double(activeNaive(:)), double(activeTransfer(:))}, false, compareGroup, UniExp.Flags.IndividualErrorbars, 'AsteriskThreshold', 1);
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
ylabel(axBottom, 'active fraction');
box(axBottom, 'off');
grid(axBottom, 'off');

iStyleBars(bars2, colorInitial, colorTransfer);
iStyleIndividualErrorbars(ebBottom, colorInitial, colorTransfer);
iApplyPText(optBottom, pActive);
ylim(axBottom, [0, max(0.1, axBottom.YLim(2))]);

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
svgPath = '中文图Fig332C_InitialTransferLight_1s_BarScatter.svg';
svgPath = TransferLearning.ExportStandardFigure(f, 1, svgPath);
fprintf('Wrote: %s\n', svgPath);

assignin('base', 'Fig332C_NTATS1s', struct('Initial', vInitial, 'Transfer', vTransfer, 'Idx0', idx0s, 'Idx1', idx1s, 'XsSec', xsSec, 'ActiveNaive', activeNaive, 'ActiveTransfer', activeTransfer, 'PActive', pActive));

function G = iQueryInitialLightAll()
LAB = TransferLearning.LightAudioBaseline();
LAI = TransferLearning.LAInterspersed();
qNaiveLW = struct('Phase', 'Naive', 'Stimulus', 'LightWater');
badNaive = iFindMiceWithAudioWaterInPhase(LAI, "Naive");
qNaiveLW_LAI = qNaiveLW;
qNaiveLW_LAI.Mouse = iMiceInPhaseStimulus(LAI, "Naive", "LightWater", badNaive);
G1 = LAB.QueryNTATS(qNaiveLW, UniExp.Flags.ZScore, 1:24, UniExp.Flags.Median);
G2 = LAI.QueryNTATS(qNaiveLW_LAI, UniExp.Flags.ZScore, 1:24, UniExp.Flags.Median);
G = iVcatNtatsTables(G1, G2);
end

function G = iQueryTransferLightAll()
ALB = TransferLearning.AudioLightBaseline();
qTransferLW = struct('Phase', 'Transfer', 'Stimulus', 'LightWater');
G = ALB.QueryNTATS(qTransferLW, UniExp.Flags.ZScore, 1:24, UniExp.Flags.Median);
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
	Bars.FaceAlpha = 1/3;
	return;
end
for ib = 1:numel(Bars)
	if ib == 1
		Bars(ib).FaceColor = colorInitial;
	else
		Bars(ib).FaceColor = colorTransfer;
	end
	Bars(ib).LineWidth = 1;
	Bars(ib).BaseLine.LineWidth = 1;
	Bars(ib).EdgeColor = 'none';
	Bars(ib).FaceAlpha = 1/3;
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
		eb.Color = barColors(min(iObj, 2), :);
	end
	if isprop(eb, 'LineStyle')
		eb.LineStyle = 'none';
	end
	if isprop(eb, 'CapSize')
		eb.CapSize = 5.28;
	end
end
end

function iApplyPText(options, pValue)
if isfield(options, 'MultiCompare') && istable(options.MultiCompare) && ismember('PText', options.MultiCompare.Properties.VariableNames)
	for pt = options.MultiCompare.PText(:)'
		pt.FontSize = 6;
		pt.FontName = 'Segoe UI Emoji';
		pt.String = iPValueToStars(pValue);
	end
end
if isfield(options, 'MultiCompare') && istable(options.MultiCompare) && ismember('PLine', options.MultiCompare.Properties.VariableNames)
	for pl = options.MultiCompare.PLine(:)'
		pl.LineWidth = 1;
	end
end
end

function out = iPTextToStars(in)
out = in;
if isstring(in)
	if isscalar(in)
		out = string(iPTextToStars(char(in)));
	else
		out = arrayfun(@(s) string(iPTextToStars(char(s))), in);
	end
	return;
end
if iscell(in)
	out = cell(size(in));
	for ii = 1:numel(in)
		out{ii} = iPTextToStars(in{ii});
	end
	return;
end
if ~ischar(in)
	return;
end
token = regexp(in, 'p\s*=\s*([0-9]*\.?[0-9]+([eE][-+]?[0-9]+)?)', 'tokens', 'once');
if isempty(token)
	return;
end
p = str2double(token{1});
if p < 1e-4
	out = '****';
elseif p < 1e-3
	out = '***';
elseif p < 1e-2
	out = '**';
elseif p < 0.05
	out = '*';
else
	out = 'ns';
end
end

function out = iPValueToStars(p)
if ~isfinite(p)
	out = 'ns';
elseif p < 1e-4
	out = '****';
elseif p < 1e-3
	out = '***';
elseif p < 1e-2
	out = '**';
elseif p < 0.05
	out = '*';
else
	out = 'ns';
end
end

