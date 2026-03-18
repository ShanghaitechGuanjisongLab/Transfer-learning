% 图3.5f：Learned AudioWater 活跃细胞，按其在 Transfer LightWater 是否活跃分组的平均NTATS±SEM
%
% Definition:
% - First select active cells in Phase=Learned, Stimulus=AudioWater.
% - Among those, split cells by whether they are active in Phase=Transfer, Stimulus=LightWater (ALL trials).
%
% Active-cell criterion (same as Fig3.5a):
%   max(0~1s) > mean(-3~0s) + 3*std(-3~0s)
%
% Plot:
% - MATLAB.Graphics.MultiShadowedLines
% - Time window shown: 0~3s (cue at 0s, water at 1s)
%
% Output:
% - SVG only to \\Data-Server-2\个人数据\张天夫\202601
%
% Execution:
%   TransferLearning.Fig35.F_MeanNTATS_LearnedAudio_SplitByTransferLWActive

outDirUNC = "\\Data-Server-2\个人数据\张天夫\202601";
svgName = "Fig3_2g_MeanNTATS_LearnedAudio_SplitByTransferLWActive_0to3.svg";

% --- 0) Ensure project loaded (for UniExp)
try
	if ~exist('UniExp.DataSet','class')
		thisFile = mfilename('fullpath');
		thisDir = fileparts(thisFile);
		prjFile = fullfile(thisDir, '..', '..', 'Transferlearning.prj');
		if exist(prjFile,'file')
			try
				matlab.project.loadProject(prjFile);
			catch
			end
		end
	end
catch
end

DS = TransferLearning.AudioLightBaseline();

% --- 1) Time axis and masks (match Fig3.5a/c)
xs = TransferLearning.Xs;
if ~isduration(xs)
	xs = seconds(xs);
end
xsSec = seconds(xs);

xMask = (xsSec >= 0) & (xsSec <= 3);
if nnz(xMask) < 5
	error('Fig3_5f:BadTimeMask', 'Too few samples in 0~3s window.');
end

baseMask = (xsSec >= -3) & (xsSec < 0);
respMask = (xsSec >= 0) & (xsSec <= 1);
if nnz(baseMask) < 5 || nnz(respMask) < 2
	error('Fig3_5f:BadActiveMasks', 'Too few samples in baseline/response window.');
end
kSigma = 3;

% --- 2) Query 2 lanes (Median ZScore NTATS)
qLearnedAudio = struct('Phase','Learned',  'Stimulus','AudioWater');
qTransferLW   = struct('Phase','Transfer', 'Stimulus','LightWater');

G = struct();
G.LearnedAudio = DS.QueryNTATS(qLearnedAudio, UniExp.Flags.ZScore, 1:24, UniExp.Flags.Median);
G.TransferLW   = DS.QueryNTATS(qTransferLW,   UniExp.Flags.ZScore, 1:24, UniExp.Flags.Median);

S = UniExp.NtatsCellStrip(G);
X = iGetNtats3D(S);
if isempty(X) || size(X,3) < 2
	error('Fig3_5f:BadNTATS', 'Expected NTATS to be [nCell x nTime x 2] for LearnedAudio/TransferLW.');
end

% --- 3) Learned-active selection (lane 1)
XLearn = squeeze(X(:,:,1));
activeLearned = iActiveMask(XLearn, baseMask, respMask, kSigma);

% --- 4) Split by TransferLW activity (lane 2)
XTran = squeeze(X(:,:,2));
activeTransfer = iActiveMask(XTran, baseMask, respMask, kSigma);

keep = activeLearned;
if nnz(keep) == 0
	error('Fig3_5f:Empty', 'No learned-active cells after filtering.');
end

XLearn0to3 = XLearn(keep, xMask);
isActiveInTransfer = activeTransfer(keep);

XA = XLearn0to3(isActiveInTransfer, :);
XI = XLearn0to3(~isActiveInTransfer, :);

[muA, seA, nA] = iMeanSemAcrossCells(XA);
[muI, seI, nI] = iMeanSemAcrossCells(XI);

Fig3_5f = struct();
Fig3_5f.NTotal = nnz(keep);
Fig3_5f.NTransferActive = nA;
Fig3_5f.NTransferInactive = nI;
Fig3_5f.ActiveMaskLearned = activeLearned;
Fig3_5f.ActiveMaskTransfer = activeTransfer;
Fig3_5f.XsSec = xsSec;
Fig3_5f.XMask0to3 = xMask;
assignin('base','Fig3_5f', Fig3_5f);

% --- 5) Plot
f = figure('Color','w', 'Name', 'Fig3.5f Mean NTATS');
try
	MATLAB.Graphics.FigureAspectRatio(46,46,1/2);
catch
end
ax = axes('Parent', f);
hold(ax, 'on');

meanCells = {muA(:), muI(:)};
semCells  = {seA(:), seI(:)};
edgeColors = TransferLearning.FigurePalette(2);

Patches = MATLAB.Graphics.MultiShadowedLines(meanCells, semCells, X=xsSec(xMask), EdgeColors=edgeColors(1:2,:));

try
	lgd = legend(ax, Patches(1:2), {
		'Tr LW active', ...
		'Tr LW inactive' ...
		}, 'Location', MATLAB.Graphics.OptimizedLegendLocation(Patches(1:2)));
	try
		lgd.AutoUpdate = 'off';
	catch
	end
catch
	legend(ax, 'Location', 'best');
end

try
	TransferLearning.DrawCueWaterLines(ax);
catch
end

ax.FontSize = 6;
xlabel(ax, 'Time (s)');
ylabel(ax, 'z-score');
title(ax, 'Mean response');
box(ax,'off');
grid(ax,'on');

try
	if isprop(ax, 'Toolbar') && ~isempty(ax.Toolbar)
		ax.Toolbar.Visible = 'off';
	end
catch
end

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
catch ME
	warning(ME.identifier, 'Export failed: %s', ME.message);
end

%% --- local helpers

function activeMask = iActiveMask(XLane, baseMask, respMask, kSigma)
baseMu = mean(XLane(:, baseMask), 2, 'omitnan');
baseSd = std(XLane(:, baseMask), 0, 2, 'omitnan');
respMax = max(XLane(:, respMask), [], 2, 'omitnan');
activeMask = isfinite(respMax) & isfinite(baseMu) & isfinite(baseSd) & (respMax > (baseMu + kSigma*baseSd));
end

function [mu, se, nEff] = iMeanSemAcrossCells(X2)
% X2: [nCell x nTime]
if isempty(X2)
	mu = nan(1,0);
	se = nan(1,0);
	nEff = 0;
	return;
end

mu = mean(X2, 1, 'omitnan');
sd = std(X2, 0, 1, 'omitnan');

nByTime = sum(isfinite(X2), 1);
se = nan(size(mu));
ok = nByTime > 0;
se(ok) = sd(ok) ./ sqrt(double(nByTime(ok)));

% Report a single n as the median effective sample size
nEff = round(median(double(nByTime(ok))));
if ~isfinite(nEff)
	nEff = 0;
end
end

function X = iGetNtats3D(S)
% Return numeric [nCell x nTime x nLane] NTATS.
if istable(S)
	nt = S.NTATS;
elseif isstruct(S) && isfield(S,'NTATS')
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

if isnumeric(nt)
	if ndims(nt) ~= 3
		error('Fig3_5f:BadNTATS', 'Expected NTATS to be 3D numeric or NDTable.');
	end
	X = nt;
	return;
end

error('Fig3_5f:BadNTATS', 'Unsupported NTATS container type: %s', class(nt));
end
