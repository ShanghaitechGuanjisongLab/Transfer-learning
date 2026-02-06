% 英文图1H：复用细胞占比（饼图）
%
% 复用细胞定义：Learned AudioWater 与 Transfer LightWater 在1s处均活跃
% 活跃判定：1s处 > baseline + 3*std（baseline = -3~0s）
%
% 分母定义（按用户要求与英文图1F一致）：
%   只统计“被选入F图”的细胞（F图筛选：四泳道中任一泳道在1s处活跃）

outDirUNC = "\\Data-Server-2\个人数据\张天夫\202601";

% --- 0) Ensure project loaded
try
	if ~exist('UniExp.DataSet','class')
		thisFile = mfilename('fullpath');
		thisDir = fileparts(thisFile);
		prjFile = fullfile(thisDir, '..', '..', 'Transferlearning.prj');
		if exist(prjFile,'file')
			try matlab.project.loadProject(prjFile); catch, end
		end
	end
catch
end

DS = TransferLearning.AudioLightBaseline();

% Time axis
xs = TransferLearning.Xs;
if isduration(xs)
	xsSec = seconds(xs);
else
	xsSec = double(xs);
end

baseMask = (xsSec >= -3) & (xsSec < 0);
[idx1s, ok1s] = iFindTimeIndex(xsSec, 1, 0.25);
if ~ok1s
	error('Fig1S1:No1s', 'Cannot find sample close to 1s.');
end

% Query NTATS (Median ZScore) -- align cell universe with Fig1F selection.
% Four lanes: Naive AudioOnly, Naive LightOnly, Learned AudioWater, Transfer LightWater
qNaiveAudioOnly = struct('Stimulus', 'AudioOnly');
qNaiveLightOnly = struct('Stimulus', 'LightOnly');
qLearnedAudio   = struct('Phase', 'Learned',  'Stimulus', 'AudioWater');
qTransferLight  = struct('Phase', 'Transfer', 'Stimulus', 'LightWater');

G = struct();
G.NaiveAudioOnly = DS.QueryNTATS(qNaiveAudioOnly, UniExp.Flags.ZScore, 1:24, UniExp.Flags.Median);
G.NaiveLightOnly = DS.QueryNTATS(qNaiveLightOnly, UniExp.Flags.ZScore, 1:24, UniExp.Flags.Median);
G.LearnedAudio   = DS.QueryNTATS(qLearnedAudio,   UniExp.Flags.ZScore, 1:24, UniExp.Flags.Median);
G.TransferLight  = DS.QueryNTATS(qTransferLight,  UniExp.Flags.ZScore, 1:24, UniExp.Flags.Median);

S = UniExp.NtatsCellStrip(G);
X = iGetNtats3D(S); % [nCell x nTime x 4]

% Active at 1s (baseline -3~0s) for each lane
kSigma = 3;
nLanes = size(X, 3);
activeByLane = false(size(X, 1), nLanes);
for iL = 1:nLanes
	XLane = squeeze(X(:, :, iL));
	baseMu = mean(XLane(:, baseMask), 2, 'omitnan');
	baseSd = std(XLane(:, baseMask), 0, 2, 'omitnan');
	v1 = XLane(:, idx1s);
	activeByLane(:, iL) = isfinite(v1) & isfinite(baseMu) & isfinite(baseSd) & (v1 > (baseMu + kSigma * baseSd));
end

% Fig1F selected cells: any lane active at 1s
selectedMask = any(activeByLane, 2);

% Reuse cells: LearnedAudio (lane 3) and TransferLight (lane 4) both active at 1s
reuseMask = activeByLane(:, 3) & activeByLane(:, 4);

nTotal = sum(selectedMask);
nReuse = sum(reuseMask & selectedMask);
nNon = nTotal - nReuse;

% --- Plot
svgName = "English_Fig1H_ReusedCellsPie.svg";
f = figure('Color', 'w', 'Name', 'English Fig1H Reused Cells Pie');
f.Units = 'centimeters';
f.Position(3:4) = [4.5, 4.0]; % 45mm x 40mm
ax = axes(f);
try
	if isprop(ax, 'Toolbar') && ~isempty(ax.Toolbar)
		ax.Toolbar.Visible = 'off';
	end
catch
end

pie(ax, [nReuse, nNon], {'Reuse', 'Non-reuse'});
colormap(ax, [0.85 0.325 0.098; 0.6 0.6 0.6]);
ax.FontSize = 6;
axis(ax, 'equal');
box(ax, 'off');

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
	fprintf('Wrote: %s\n', svgPath);
catch ME
	warning(ME.identifier, 'Export failed: %s', ME.message);
end

assignin('base', 'Fig1H_ReusedCounts', table(nReuse, nNon, nTotal));

%% --- Local helpers

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

if isnumeric(nt)
	if ndims(nt) ~= 3
		error('Fig1H:BadNTATS', 'Expected NTATS to be 3D numeric or NDTable.');
	end
	X = nt;
	return;
end

error('Fig1H:BadNTATS', 'Unsupported NTATS container type: %s', class(nt));
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
