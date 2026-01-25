% 图3.5c：Learned AudioWater vs Transfer LightWater (Hit/Miss) 平均NTATS±SEM
%
% Curves (overlay):
% 1) Learned AudioWater
% 2) Transfer LightWater Hit
% 3) Transfer LightWater Miss
%
% Data source:
% - Reuse the exact NTATS definition and active-cell criterion used by Fig3.5a
%   (Median ZScore NTATS; learned-active cells only).
% - If Fig3.5a has already been run in the same MATLAB session, this script
%   will reuse Fig3_5a_CellStrip + Fig3_5a_ActiveMask from base workspace.
%
% Plot:
% - MATLAB.Graphics.MultiShadowedLines
% - Time window: 0~3s (cue at 0s, water at 1s)
%
% Output:
% - SVG only to \\Data-Server-2\个人数据\张天夫\202601
%
% Execution:
%   TransferLearning.Fig35.C_MeanNTATS_LearnedAudio_TransferHitMiss

outDirUNC = "\\Data-Server-2\个人数据\张天夫\202601";
svgName = "Fig3_2d_MeanNTATS_LearnedAudio_TransferHitMiss_0to3.svg";

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

% --- 1) Time window 0~3s (match Fig3.5a)
xs = TransferLearning.Xs;
if ~isduration(xs)
	xs = seconds(xs);
end
xsSec = seconds(xs);
xMask = (xsSec >= 0) & (xsSec <= 3);
if nnz(xMask) < 5
	error('Fig3_5c:BadTimeMask', 'Too few samples in 0~3s window.');
end

% --- 2) Get NTATS (prefer reusing Fig3.5a outputs)
laneOrder = ["NaiveAudio","LearnedAudio","TransferHit","TransferMiss"];
[S, activeMask] = iMaybeReuseFromFig35A();

if isempty(S)
	DS = TransferLearning.AudioLightBaseline();

	% Active-cell criterion (Learned lane only): max(0~1s) > mean(-3~0s) + 3*std(-3~0s)
	baseMask = (xsSec >= -3) & (xsSec < 0);
	respMask = (xsSec >= 0) & (xsSec <= 1);
	if nnz(baseMask) < 5 || nnz(respMask) < 2
		error('Fig3_5c:BadActiveMasks', 'Too few samples in baseline/response window for active-cell criterion.');
	end
	kSigma = 3;

	% Query 4 lanes (Median ZScore NTATS)
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
	respMax = max(XLearned(:, respMask), [], 2, 'omitnan');
	activeMask = isfinite(respMax) & isfinite(baseMu) & isfinite(baseSd) & (respMax > (baseMu + kSigma*baseSd));

	assignin('base','Fig3_5c_CellStrip', S);
	assignin('base','Fig3_5c_ActiveMask', activeMask);
else
	X = iGetNtats3D(S, laneOrder);
	if isempty(activeMask)
		activeMask = true(size(X,1), 1);
	end
	if numel(activeMask) ~= size(X,1)
		error('Fig3_5c:BadReuse', 'Fig3_5a_ActiveMask size mismatch with Fig3_5a_CellStrip NTATS.');
	end
end

X = X(activeMask, :, :);

% --- 3) Build mean±SEM curves (cell-average)
X0to3 = X(:, xMask, :);

[muLearn, seLearn, nLearn] = iMeanSemAcrossCells(squeeze(X0to3(:,:,2)));
[muHit,  seHit,  nHit]  = iMeanSemAcrossCells(squeeze(X0to3(:,:,3)));
[muMiss, seMiss, nMiss] = iMeanSemAcrossCells(squeeze(X0to3(:,:,4)));

assignin('base','Fig3_5c_NCells', struct('LearnedAudio', nLearn, 'TransferHit', nHit, 'TransferMiss', nMiss));

meanCells = {muLearn(:), muHit(:), muMiss(:)};
semCells  = {seLearn(:), seHit(:),  seMiss(:)};

% --- 4) Plot
f = figure('Color','w', 'Name', 'Fig3.5c Mean NTATS ± SEM');
try
	MATLAB.Graphics.FigureAspectRatio(8,5, 1/2);
catch
end
ax = axes('Parent', f);
hold(ax, 'on');

try
	edgeColors = GlobalOptimization.ColorAllocate(3, [1,1,1;1,1,1]);
catch
	edgeColors = lines(3);
end

Patches = MATLAB.Graphics.MultiShadowedLines(meanCells, semCells, X=xsSec(xMask), EdgeColors=edgeColors(1:3,:));

try
	lgd = legend(ax, Patches(1:3), { ...
		'Learned AudioWater', ...
		'Transfer LightWater Hit', ...
		'Transfer LightWater Miss' ...
		}, 'Location', MATLAB.Graphics.OptimizedLegendLocation(Patches(1:3)));
	try
		lgd.AutoUpdate = 'off';
	catch
	end
catch
	legend(ax, 'Location', 'best');
end

% Cue(:) and Water(|) timing lines MUST be after legend
try
	TransferLearning.DrawCueWaterLines(ax);
catch
end

xlabel(ax, 'Time (s)');
ylabel(ax, 'NTATS (z-score)');
title(ax, 'Mean NTATS (cell-average)');
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
	exportgraphics(f, svgPath, 'ContentType','vector');
	fprintf('Wrote: %s\n', svgPath);
catch ME
	warning(ME.identifier, 'Export failed: %s', ME.message);
end

%% --- local helpers

function [S, activeMask] = iMaybeReuseFromFig35A()
S = [];
activeMask = [];
try
	hasS = evalin('base', "exist('Fig3_5a_CellStrip','var')");
	hasM = evalin('base', "exist('Fig3_5a_ActiveMask','var')");
	if hasS
		S = evalin('base','Fig3_5a_CellStrip');
	end
	if hasM
		activeMask = evalin('base','Fig3_5a_ActiveMask');
	end
catch
	S = [];
	activeMask = [];
end
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
% Return numeric [nCell x nTime x nLane] NTATS.
% Keep laneOrder argument for API parity with Fig3.5a.

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
		error('Fig3_5c:BadNTATS', 'Expected NTATS to be 3D numeric or NDTable.');
	end
	X = nt;
	return;
end

error('Fig3_5c:BadNTATS', 'Unsupported NTATS container type: %s', class(nt));
end
