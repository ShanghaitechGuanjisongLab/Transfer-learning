% 英文图1I：Learned 🔊💧 vs Transfer 💡💧 (Hit/Miss) 平均 z-score ± SEM
%
% Curves (overlay):
% 1) Learned 🔊💧
% 2) Transfer 💡💧 Hit
% 3) Transfer 💡💧 Miss
%
% Data source:
% - Median z-score NTATS; Learned-active cells only.
% - Active-cell criterion: z-score@1s > mean(-3~0s) + 3*std(-3~0s), on Learned lane ONLY.
%
% Plot:
% - MATLAB.Graphics.MultiShadowedLines
% - Time window: 0~3s (cue at 0s, water at 1s)
%
% Output:
% - SVG only to \\Data-Server-2\个人数据\张天夫\202601
%
% Execution:
%   TransferLearning.英文图1.I_MeanZScore

outDirUNC = "\\Data-Server-2\个人数据\张天夫\202601";
svgName = "English_Fig1I_MeanZScore.svg";

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

% --- 1) Time window 0~3s
xs = TransferLearning.Xs;
if ~isduration(xs)
	xs = seconds(xs);
end
xsSec = seconds(xs);
xMask = (xsSec >= 0) & (xsSec <= 3);
if nnz(xMask) < 5
	error('Fig1I:BadTimeMask', 'Too few samples in 0~3s window.');
end

% --- 2) Get z-score data
laneOrder = ["NaiveAudio","LearnedAudio","TransferHit","TransferMiss"];

DS = TransferLearning.AudioLightBaseline();

% Active-cell criterion (Learned lane only): z-score@1s > mean(-3~0s) + 3*std(-3~0s)
baseMask = (xsSec >= -3) & (xsSec < 0);
if nnz(baseMask) < 5
	error('Fig1I:BadActiveMasks', 'Too few samples in baseline window for active-cell criterion.');
end
kSigma = 3;

% Find sample index closest to 1s
[~, idx1] = min(abs(xsSec - 1));
if abs(xsSec(idx1) - 1) > 0.25
	error('Fig1I:No1s', 'Cannot find sample close to 1s in TransferLearning.Xs.');
end

qNaiveAudio   = struct('Phase','Naive',   'Stimulus','AudioWater');
qLearnedAudio = struct('Phase','Learned', 'Stimulus','AudioWater');
qTHit         = struct('Phase','Transfer','Stimulus','LightWater','Behavior',1);
qTMiss        = struct('Phase','Transfer','Stimulus','LightWater','Behavior',0);

G = struct();
G.NaiveAudio   = DS.QueryNTATS(qNaiveAudio,   UniExp.Flags.ZScore, 1:24, UniExp.Flags.Median);
G.LearnedAudio = DS.QueryNTATS(qLearnedAudio, UniExp.Flags.ZScore, 1:24, UniExp.Flags.Median);
G.TransferHit  = DS.QueryNTATS(qTHit,         UniExp.Flags.ZScore, 1:24, UniExp.Flags.Median);
G.TransferMiss = DS.QueryNTATS(qTMiss,        UniExp.Flags.ZScore, 1:24, UniExp.Flags.Median);

S = UniExp.NtatsCellStrip(G);
X = iGetNtats3D(S, laneOrder);

XLearned = squeeze(X(:,:,2));
baseMu = mean(XLearned(:, baseMask), 2, 'omitnan');
baseSd = std(XLearned(:, baseMask), 0, 2, 'omitnan');
v1s = XLearned(:, idx1);
activeMask = isfinite(v1s) & isfinite(baseMu) & isfinite(baseSd) & (v1s > (baseMu + kSigma*baseSd));

assignin('base','Fig1I_CellStrip', S);
assignin('base','Fig1I_ActiveMask', activeMask);

X = X(activeMask, :, :);
nActiveCells = sum(activeMask);
fprintf('Active cells (🔊💧): %d / %d\n', nActiveCells, numel(activeMask));

% --- 3) Build mean±SEM curves (cell-average)
X0to3 = X(:, xMask, :);

[muLearn, seLearn, nLearn] = iMeanSemAcrossCells(squeeze(X0to3(:,:,2)));
[muHit,  seHit,  nHit]  = iMeanSemAcrossCells(squeeze(X0to3(:,:,3)));
[muMiss, seMiss, nMiss] = iMeanSemAcrossCells(squeeze(X0to3(:,:,4)));

assignin('base','Fig1I_NCells', struct('LearnedAudio', nLearn, 'TransferHit', nHit, 'TransferMiss', nMiss));

meanCells = {muLearn(:), muHit(:), muMiss(:)};
semCells  = {seLearn(:), seHit(:),  seMiss(:)};

% --- 4) Plot
f = figure('Color','w', 'Name', 'English Fig1I Mean z-score ± SEM');
f.Units = 'centimeters';
f.Position(3:4) = [4.5, 4.5]; % 45mm x 45mm
ax = axes('Parent', f);
hold(ax, 'on');

try
	edgeColors = GlobalOptimization.ColorAllocate(3, [1,1,1;1,1,1]);
catch
	edgeColors = lines(3);
end

Patches = MATLAB.Graphics.MultiShadowedLines(meanCells, semCells, X=xsSec(xMask), EdgeColors=edgeColors(1:3,:));

% Legend with emoji
try
	lgd = legend(ax, Patches(1:3), { ...
		'🔊💧100%', ...
		'💡💧 Hit', ...
		'💡💧 Miss' ...
		}, 'Location', MATLAB.Graphics.OptimizedLegendLocation(Patches(1:3)));
	lgd.FontSize = 6;
	lgd.FontName = 'Segoe UI Emoji';
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
ax.FontName = 'Segoe UI Emoji';
% 保留默认 xticks，仅替换 0s 和 1s 处的标签为 emoji
currentTicks = ax.XTick;
currentLabels = arrayfun(@num2str, currentTicks, 'UniformOutput', false);
for i = 1:numel(currentTicks)
	if currentTicks(i) == 0
		currentLabels{i} = '🔊/💡';
	elseif currentTicks(i) == 1
		currentLabels{i} = '💧';
	end
end
ax.XTickLabel = currentLabels;
xlabel(ax, 'Time (s)', 'FontSize', 6);
ylabel(ax, 'z-score', 'FontSize', 6);
title(ax, sprintf('🔊💧 active (%d cells)', nActiveCells), 'FontSize', 6, 'FontName', 'Segoe UI Emoji');
box(ax,'off');
grid(ax,'on');

try
	if isprop(ax, 'Toolbar') && ~isempty(ax.Toolbar)
		ax.Toolbar.Visible = 'off';
	end
catch
end

% --- 5) Export
try
	if ~isfolder(outDirUNC)
		mkdir(outDirUNC);
	end
catch
end

svgPath = fullfile(outDirUNC, svgName);
try
	TransferLearning.PrintFigure(f, svgPath);
	fprintf('Wrote: %s\n', svgPath);
catch ME
	warning(ME.identifier, 'Export failed: %s', ME.message);
end

%% --- local helpers

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

nEff = sum(isfinite(X2), 1);
se = nan(size(mu));
ok = nEff > 0;
se(ok) = sd(ok) ./ sqrt(double(nEff(ok)));

% Report a single n as the median effective sample size
nEff = round(median(double(nEff(ok))));
if ~isfinite(nEff)
	nEff = 0;
end
end

function X = iGetNtats3D(S, ~)
% Return numeric [nCell x nTime x nLane] z-score.

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
		error('Fig1I:BadNTATS', 'Expected z-score to be 3D numeric or NDTable.');
	end
	X = nt;
	return;
end

error('Fig1I:BadNTATS', 'Unsupported z-score container type: %s', class(nt));
end
