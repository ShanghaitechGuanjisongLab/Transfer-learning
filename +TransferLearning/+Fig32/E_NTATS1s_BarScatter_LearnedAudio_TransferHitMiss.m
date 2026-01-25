% 图3.5d：比较三组在 1s 处的 NTATS（Learned AudioWater / Transfer Hit / Transfer Miss）
%
% Data source:
% - Reuse the exact NTATS definition and active-cell criterion used by Fig3.5a/3.5c
%   (Median ZScore NTATS; learned-active cells only).
%
% Plot:
% - UniExp.BarScatterCompare
%
% Output:
% - SVG only to \\Data-Server-2\个人数据\张天夫\202601
%
% Execution:
%   TransferLearning.Fig35.D_NTATS1s_BarScatter_LearnedAudio_TransferHitMiss

outDirUNC = "\\Data-Server-2\个人数据\张天夫\202601";
svgName = "Fig3_2e_NTATS1s_LearnedAudio_TransferHitMiss_BarScatter.svg";

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

% --- 1) Load/reuse NTATS + active mask
laneOrder = ["NaiveAudio","LearnedAudio","TransferHit","TransferMiss"];
[S, activeMask] = iMaybeReuseFromFig35A();

if isempty(S)
	DS = TransferLearning.AudioLightBaseline();

	xs = TransferLearning.Xs;
	if ~isduration(xs)
		xs = seconds(xs);
	end
	xsSec = seconds(xs);

	baseMask = (xsSec >= -3) & (xsSec < 0);
	respMask = (xsSec >= 0) & (xsSec <= 1);
	kSigma = 3;

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
	X = iGetNtats3D(S);

	XLearned = squeeze(X(:,:,2));
	baseMu = mean(XLearned(:, baseMask), 2, 'omitnan');
	baseSd = std(XLearned(:, baseMask), 0, 2, 'omitnan');
	respMax = max(XLearned(:, respMask), [], 2, 'omitnan');
	activeMask = isfinite(respMax) & isfinite(baseMu) & isfinite(baseSd) & (respMax > (baseMu + kSigma*baseSd));
else
	X = iGetNtats3D(S);
	if isempty(activeMask)
		activeMask = true(size(X,1), 1);
	end
end

if numel(activeMask) ~= size(X,1)
	error('Fig3_5d:BadActiveMask', 'ActiveMask size mismatch with NTATS cell dimension.');
end

X = X(activeMask, :, :);

% --- 2) Extract 1s value (nearest sample to 1s)
xs = TransferLearning.Xs;
if ~isduration(xs)
	xs = seconds(xs);
end
xsSec = seconds(xs);

[~, idx1] = min(abs(xsSec - 1));

vLearn = X(:, idx1, 2);
vHit  = X(:, idx1, 3);
vMiss = X(:, idx1, 4);

% Paired comparison: keep only cells with finite values in ALL three groups
maskPair = isfinite(vLearn) & isfinite(vHit) & isfinite(vMiss);
vLearn = vLearn(maskPair);
vHit  = vHit(maskPair);
vMiss = vMiss(maskPair);

assignin('base','Fig3_5d_NTATS1s', struct('LearnedAudio', vLearn, 'TransferHit', vHit, 'TransferMiss', vMiss, ...
	'Idx1', idx1, 'XsSec', xsSec, 'MaskPair', maskPair));


% --- 3) Plot via UniExp.BarScatterCompare
Data = array2table([double(vLearn(:)), double(vHit(:)), double(vMiss(:))], ...
	'VariableNames', {'Learn','Hit','Miss'});

% Only one p-value line: Hit vs Miss
CompareGroup = table(["Hit","Miss"], 'VariableNames', {'GroupPair'});

f = figure('Color','w', 'Name', 'Fig3.5d NTATS@1s (BarScatterCompare)');
MATLAB.Graphics.FigureAspectRatio(4,5,1/3);
tiledlayout(1,1,'TileSpacing','compact','Padding','compact');
nexttile;

UniExp.BarScatterCompare(Data, false, CompareGroup);
ylabel('NTATS@1s (z-score)');
title('NTATS at 1s');
ax = gca;
try
	if isprop(ax, 'Toolbar') && ~isempty(ax.Toolbar)
		ax.Toolbar.Visible = 'off';
	end
catch
end

% --- 4) Export
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

function X = iGetNtats3D(S)
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
		error('Fig3_5d:BadNTATS', 'Expected NTATS to be 3D numeric or NDTable.');
	end
	X = nt;
	return;
end

error('Fig3_5d:BadNTATS', 'Unsupported NTATS container type: %s', class(nt));
end
