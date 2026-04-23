% 中文图331B：声水学会、光水迁移命中/错失三条均值线

if ~exist('UniExp.DataSet', 'class')
	thisFile = mfilename('fullpath');
	thisDir = fileparts(thisFile);
	prjFile = fullfile(thisDir, '..', 'Transferlearning.prj');
	if exist(prjFile, 'file')
		matlab.project.loadProject(prjFile);
	end
end

DS = TransferLearning.AudioLightBaseline();
xs = TransferLearning.Xs;
if isduration(xs)
	xsSec = seconds(xs);
else
	xsSec = double(xs);
end

xMask = (xsSec >= -1) & (xsSec <= 2);
xsPlot = xsSec(xMask);
baseMask = (xsSec >= -3) & (xsSec < 0);
kSigma = 3;

[idx1s, ok1s] = iFindTimeIndex(xsSec, 1, 0.25);
if ~ok1s
	error('中文图331B:No1s', 'Cannot find sample close to 1s.');
end

qLearnedAudio = struct('Phase', 'Learned', 'Stimulus', 'AudioWater');
qTHit = struct('Phase', 'Transfer', 'Stimulus', 'LightWater', 'Behavior', 1);
qTMiss = struct('Phase', 'Transfer', 'Stimulus', 'LightWater', 'Behavior', 0);

G = struct();
G.LearnedAudio = DS.QueryNTATS(qLearnedAudio, UniExp.Flags.ZScore, 1:24, UniExp.Flags.Median);
G.TransferHit = DS.QueryNTATS(qTHit, UniExp.Flags.ZScore, 1:24, UniExp.Flags.Median);
G.TransferMiss = DS.QueryNTATS(qTMiss, UniExp.Flags.ZScore, 1:24, UniExp.Flags.Median);

S = UniExp.NtatsCellStrip(G);
X = iGetNtats3D(S);

XLearned = squeeze(X(:, :, 1));
baseMu = mean(XLearned(:, baseMask), 2, 'omitnan');
baseSd = std(XLearned(:, baseMask), 0, 2, 'omitnan');
v1 = XLearned(:, idx1s);
activeMask = isfinite(v1) & isfinite(baseMu) & isfinite(baseSd) & (v1 > (baseMu + kSigma * baseSd));
X = X(activeMask, xMask, :);

nCells = size(X, 1);
nT = size(X, 2);
Y = nan(nT, 3);
E = nan(nT, 3);
for iL = 1:3
	D = squeeze(X(:, :, iL));
	Y(:, iL) = mean(D, 1, 'omitnan')';
	E(:, iL) = std(D, 0, 1, 'omitnan')' / sqrt(nCells);
end

f = figure('Color', 'w', 'Name', '中文图331B 三条均值线');
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

palette2 = TransferLearning.FigurePalette(2);
lineColors = [palette2(1, :); palette2(2, :); palette2(2, :)];
lineStyles = ["-"; "-"; "--"];

Patches = MATLAB.Graphics.MultiShadowedLines( ...
	Y, E, 0.2, ...
	X=repmat(xsPlot(:), 1, 3), ...
	EdgeColors=lineColors, ...
	Ax=ax, ...
	LineStyles=lineStyles);

xline(ax, 0, '--k', 'LineWidth', 2);
xline(ax, 1, '-k', 'LineWidth', 2);

box(ax, 'off');
grid(ax, 'off');
xlabel(ax, 'Time', 'FontSize', 12);
ylabel(ax, 'z-score', 'FontSize', 12);
ax.XTick = [0 1];
ax.XTickLabel = {"🔊/💡", "💧"};

lg = legend(Patches, ["🔊Learned", "💡Hit", "💡Miss"], 'Location', MATLAB.Graphics.OptimizedLegendLocation(Patches), 'Box', 'off');
lg.FontSize = 12;

if isprop(ax, 'Toolbar') && ~isempty(ax.Toolbar)
	ax.Toolbar.Visible = 'off';
end

outDirUNC = fullfile('\\Data-Server-2\个人数据\张天夫', char(datetime('now', 'Format', 'yyyyMM')));
if ~isfolder(outDirUNC)
	mkdir(outDirUNC);
end

svgPath = '中文图Fig331B_Learned_TransferHitMiss_MeanLines.svg';
svgPath = TransferLearning.ExportStandardFigure(f, 2, svgPath);
fprintf('Wrote: %s\n', svgPath);

assignin('base', 'Fig331B_MeanLines_Y', Y);
assignin('base', 'Fig331B_MeanLines_SEM', E);
assignin('base', 'Fig331B_nCells', nCells);


function X = iGetNtats3D(S)
if istable(S)
	nt = S.NTATS;
elseif isstruct(S) && isfield(S, 'NTATS')
	nt = S.NTATS;
else
	nt = S;
end
if isa(nt, 'MATLAB.DataTypes.NDTable')
	try
		X = nt.Data.Data;
	catch
		X = nt{:,:,:}.Data;
	end
	return;
end
if isnumeric(nt) && ndims(nt) == 3
	X = nt;
	return;
end
	error('中文图331B:BadNTATS', 'Unsupported NTATS container type: %s', class(nt));
end

function [idx, ok] = iFindTimeIndex(xsSec, tSec, tolSec)
if isempty(xsSec) || ~isvector(xsSec)
	idx = 1;
	ok = false;
	return;
end
[d, idx] = min(abs(xsSec(:) - tSec));
ok = isfinite(d) && (d <= tolSec);
end

