% 中文图332A：初始光水与迁移光水双泳道热图（全细胞，不做对齐、不做筛选）

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
xMask = (xsSec >= -1) & (xsSec <= 2);
xsPlot = xsSec(xMask);

GInitial = iQueryInitialLightAll();
GTransfer = iQueryTransferLightAll();

XInitial = iGetNtats2D(GInitial);
XTransfer = iGetNtats2D(GTransfer);

[idx1s, ok1s] = iFindTimeIndex(xsSec, 1, 0.25);
if ~ok1s
	error('中文图332A:No1s', 'Cannot find sample close to 1s.');
end

vInit1s = XInitial(:, idx1s);
vTran1s = XTransfer(:, idx1s);
[~, sortInit] = sort(vInit1s, 'descend', 'MissingPlacement', 'last');
[~, sortTran] = sort(vTran1s, 'descend', 'MissingPlacement', 'last');

XInitialPlot = XInitial(sortInit, xMask);
XTransferPlot = XTransfer(sortTran, xMask);

allVals = [XInitialPlot(:); XTransferPlot(:)];
negV = min(allVals, [], 'omitnan');
posV = max(allVals, [], 'omitnan');
if ~isfinite(negV)
	negV = -1;
end
if ~isfinite(posV)
	posV = 1;
end
climLowAbs = sqrt(abs(min(negV, 0)));
climHighAbs = sqrt(abs(max(posV, 0)));
CLim = [-climLowAbs, climHighAbs];
%% 

f = figure('Color', 'w', 'Name', '中文图332A 初始/迁移光水热图');
f.Units = 'centimeters';
f.Position(3:4) = [9, 8];
f.PaperUnits = 'centimeters';
f.PaperSize = [9, 8];

L = tiledlayout(f, 1, 2, 'TileSpacing', 'none', 'Padding', 'tight');

laneData = {XInitialPlot, XTransferPlot};
[~, Axes] = UniExp.LanearHeatmap( ...
	laneData, ...
	SubTitles=["Naive", "Transfer"], ...
	Flags=[UniExp.Flags.HideYAxis, UniExp.Flags.SymmetricColormap], ...
	CLim=CLim, ...
	Layout=L, ...
	ImagescStyle={'XData', [xsPlot(1), xsPlot(end)]}, ...
	LMHColor=[0,0,1; 1,1,1; 1,0,0]);

ax1 = Axes(1);
ax2 = Axes(2);
axesAll = [ax1, ax2];
for ax = axesAll
	ax.YDir = 'normal';
	ax.FontSize = 12;
	ax.FontName = 'Segoe UI Emoji';
	ax.LineWidth = 2;
	ax.TickDir = 'in';
	ax.YTick = [];
	ax.YTickLabel = {};
	ax.XTick = [0 1];
	ax.XTickLabel = {"💡", "💧"};
	xline(ax, 0, '--k', 'LineWidth', 2);
	xline(ax, 1, '-k', 'LineWidth', 2);
	box(ax, 'on');
	if isprop(ax, 'Toolbar') && ~isempty(ax.Toolbar)
		ax.Toolbar.Visible = 'off';
	end
end

xlabel(L, 'Time', 'FontSize', 12);

CB = colorbar(ax2);
CB.Layout.Tile = 'east';
CB.Label.String = 'z-score';
CB.FontSize = 12;
CB.Label.FontSize = 12;

outDirUNC = fullfile('\\Data-Server-2\个人数据\张天夫', char(datetime('now', 'Format', 'yyyyMM')));
if ~isfolder(outDirUNC)
	mkdir(outDirUNC);
end
svgPath = fullfile(outDirUNC, '中文图Fig332A_InitialTransferLight_Heatmap.svg');
TransferLearning.PrintFigure(f, svgPath, ForceLegendOrColorbar=true);
fprintf('Wrote: %s\n', svgPath);

assignin('base', 'Fig332A_Initial1s', vInit1s);
assignin('base', 'Fig332A_Transfer1s', vTran1s);

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
	error('中文图332A:BadNTATS', 'Unsupported NTATS container type: %s', class(nt));
end

function [idx, ok] = iFindTimeIndex(xsSec, tSec, tolSec)
[d, idx] = min(abs(xsSec(:) - tSec));
ok = isfinite(d) && (d <= tolSec);
end

function y = iNiceLimit(x)
if ~isfinite(x) || x <= 0
	y = 1;
	return;
end
e = floor(log10(x));
f = x / 10^e;
if f <= 1
	f2 = 1;
elseif f <= 2
	f2 = 2;
elseif f <= 5
	f2 = 5;
else
	f2 = 10;
end
y = f2 * 10^e;
end

