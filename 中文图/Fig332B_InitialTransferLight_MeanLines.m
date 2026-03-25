% 中文图332B：初始光水与迁移光水两条均值线（全细胞，不做筛选）

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
cueBaseMask = (xsSec >= -1) & (xsSec < 0);

GInitial = iQueryInitialLightAll();
GTransfer = iQueryTransferLightAll();
XInitial = iGetNtats2D(GInitial);
XTransfer = iGetNtats2D(GTransfer);

XInitial = XInitial - mean(XInitial(:, cueBaseMask), 2, 'omitnan');
XTransfer = XTransfer - mean(XTransfer(:, cueBaseMask), 2, 'omitnan');

XInitial = XInitial(:, xMask);
XTransfer = XTransfer(:, xMask);

Y = [mean(XInitial, 1, 'omitnan')' mean(XTransfer, 1, 'omitnan')'];
nEff = [sum(isfinite(XInitial), 1)' sum(isfinite(XTransfer), 1)'];
E = [std(XInitial, 0, 1, 'omitnan')' std(XTransfer, 0, 1, 'omitnan')'] ./ sqrt(max(nEff, 1));

f = figure('Color', 'w', 'Name', '中文图332B 初始/迁移光水均值线');
f.Units = 'centimeters';
f.Position(3:4) = [9, 8];
f.PaperUnits = 'centimeters';
f.PaperPositionMode = 'manual';
f.PaperPosition = [0, 0, 9, 8];
f.PaperSize = [9, 8];

ax = axes(f);
hold(ax, 'on');
ax.FontSize = 12;
ax.FontName = 'Segoe UI Emoji';
ax.LineWidth = 2;

palette2 = TransferLearning.FigurePalette(2);
lineColors = [palette2(1, :); palette2(2, :)];
Patches = MATLAB.Graphics.MultiShadowedLines( ...
	Y, E, 0.2, ...
	X=repmat(xsPlot(:), 1, 2), ...
	EdgeColors=lineColors, ...
	Ax=ax, ...
	LineStyles=["-"; "-"]);

xline(ax, 0, '--k', 'LineWidth', 2);
xline(ax, 1, '-k', 'LineWidth', 2);
box(ax, 'off');
grid(ax, 'off');
xlabel(ax, 'Time', 'FontSize', 12);
ylabel(ax, 'z-score', 'FontSize', 12);
ax.XTick = [0 1];
ax.XTickLabel = {"💡", "💧"};

lg = legend(Patches, ["Initial", "Transfer"], 'Location', MATLAB.Graphics.OptimizedLegendLocation(Patches), 'Box', 'off');
lg.String = ["Naive", "Transfer"];
lg.FontSize = 12;

if isprop(ax, 'Toolbar') && ~isempty(ax.Toolbar)
	ax.Toolbar.Visible = 'off';
end

outDirUNC = fullfile('\\Data-Server-2\个人数据\张天夫', char(datetime('now', 'Format', 'yyyyMM')));
if ~isfolder(outDirUNC)
	mkdir(outDirUNC);
end
svgPath = fullfile(outDirUNC, '中文图Fig332B_InitialTransferLight_MeanLines.svg');
TransferLearning.PrintFigure(f, svgPath, ForceLegendOrColorbar=true);
fprintf('Wrote: %s\n', svgPath);

assignin('base', 'Fig332B_InitialTransfer_Mean', Y);
assignin('base', 'Fig332B_InitialTransfer_SEM', E);

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
	error('中文图332B:BadNTATS', 'Unsupported NTATS container type: %s', class(nt));
end