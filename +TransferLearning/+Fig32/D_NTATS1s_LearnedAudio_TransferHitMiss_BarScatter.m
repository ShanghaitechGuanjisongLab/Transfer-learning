% Fig3.2D：比较三组在 1s 处的 NTATS（Learned AudioWater / Transfer Hit / Transfer Miss）
%
% Data source:
% - Median ZScore NTATS; learned-active cells only (active defined on Learned lane).
%
% Plot:
% - UniExp.BarScatterCompare
%
% Output:
% - SVG only to \\Data-Server-2\个人数据\张天夫\202601
%
% Execution:
%   TransferLearning.Fig32.D_NTATS1s_LearnedAudio_TransferHitMiss_BarScatter

outDirUNC = "\\Data-Server-2\个人数据\张天夫\202601";
svgName = "Fig3_2d_NTATS1s_LearnedAudio_TransferHitMiss_BarScatter.svg";

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

laneOrder = ["NaiveAudio","LearnedAudio","TransferHit","TransferMiss"];

xs = TransferLearning.Xs;
if ~isduration(xs)
	xs = seconds(xs);
end
xsSec = seconds(xs);

baseMask = (xsSec >= -3) & (xsSec < 0);
kSigma = 3;

% Find sample index closest to 1s
[~, idx1] = min(abs(xsSec - 1));
if abs(xsSec(idx1) - 1) > 0.25
	error('Fig3_2d:No1s', 'Cannot find sample close to 1s in TransferLearning.Xs.');
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

X = X(activeMask, :, :);

% --- Extract 1s value
vLearn = X(:, idx1, 2);
vHit  = X(:, idx1, 3);
vMiss = X(:, idx1, 4);

maskPair = isfinite(vLearn) & isfinite(vHit) & isfinite(vMiss);
vLearn = vLearn(maskPair);
vHit  = vHit(maskPair);
vMiss = vMiss(maskPair);

assignin('base','Fig3_2d_NTATS1s', struct('LearnedAudio', vLearn, 'TransferHit', vHit, 'TransferMiss', vMiss, ...
	'Idx1', idx1, 'XsSec', xsSec, 'MaskPair', maskPair));

% --- Plot via UniExp.BarScatterCompare
Data = array2table([double(vLearn(:)), double(vHit(:)), double(vMiss(:))], ...
	'VariableNames', {'Learn','Hit','Miss'});

CompareGroup = table(["Hit","Miss"], 'VariableNames', {'GroupPair'});

f = figure('Color','w', 'Name', 'Fig3.2d NTATS@1s (BarScatterCompare)');
MATLAB.Graphics.FigureAspectRatio(46,46,1/2);
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

% --- Export
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
function X = iGetNtats3D(S, ~)
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
		error('Fig3_2d:BadNTATS', 'Expected NTATS to be 3D numeric or NDTable.');
	end
	X = nt;
	return;
end

error('Fig3_2d:BadNTATS', 'Unsupported NTATS container type: %s', class(nt));
end
