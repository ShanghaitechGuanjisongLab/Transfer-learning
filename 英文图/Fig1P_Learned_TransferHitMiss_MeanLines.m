% 英文图1P：声水学会、光水迁移命中/错失三条均值线

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

xMask = (xsSec >= -1) & (xsSec <= 3);
xsPlot = xsSec(xMask);
baseMask = (xsSec >= -3) & (xsSec < 0);
kSigma = 3;

[idx1s, ok1s] = iFindTimeIndex(xsSec, 1, 0.25);
if ~ok1s
	error('Fig1P:No1s', 'Cannot find sample close to 1s.');
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
panelNames = ["Learned"; "Hit"; "Miss"];
sampleMasks = false(size(X, 1), numel(panelNames));
for panelIndex = 1:numel(panelNames)
	panelData = squeeze(X(:, :, panelIndex));
	sampleMasks(:, panelIndex) = activeMask & any(isfinite(panelData(:, xMask)), 2);
end
sampleCounts = TransferLearning.PanelSampleCountTable(S, panelNames, sampleMasks, DS.Cells);
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
%% 

f = figure('Color', 'w', 'Name', 'English Fig1P Learned Transfer Hit Miss mean lines');
f.Units = 'centimeters';
f.Position(3:4) = [12, 8];

hold('on');

lineColors = [TransferLearning.ColorLearned; TransferLearning.ColorHit; TransferLearning.ColorMiss] / 255;

Patches = MATLAB.Graphics.MultiShadowedLines(Y, E, 0.2, X=repmat(xsPlot(:), 1, 3), EdgeColors=lineColors);

xline(0, '--');
xline(1, '--');

box('off');
xlabel( 'Time');
ylabel( 'z-score');
XTL=string(xticklabels);
[~,Index]=ismember([0,1],xticks);
XTL(Index)=["🔊/💡", "💧"];
xticklabels(XTL);

lg = legend(Patches, ["🔊Learned", "💡Hit", "💡Miss"],Location="northwest");
title('🔊💧 learned active cells');
svgPath = 'English_Fig1P_Learned_TransferHitMiss_MeanLines.svg';
svgPath = TransferLearning.ExportStandardFigure(f, 2, svgPath);

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
	error('Fig1P:BadNTATS', 'Unsupported NTATS container type: %s', class(nt));
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