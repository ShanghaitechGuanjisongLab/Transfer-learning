% 英文图1I：复用细胞占比（饼图）
%
% 复用细胞定义：Learned AudioWater 与 Transfer LightWater 在1s处均活跃
% 活跃判定：1s处 > baseline + 3*std（baseline = -3~0s）
%
% 分母定义（按用户要求）：
%   只统计“🔊💧Active”的细胞（即英文图1F第3个泳道：Learned AudioWater 在1s处活跃）


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
	error('Fig1I:No1s', 'Cannot find sample close to 1s.');
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

% Denominator: 🔊💧Active (lane 3: Learned AudioWater active at 1s)
selectedMask = activeByLane(:, 3);

% Reuse cells: LearnedAudio (lane 3) and TransferLight (lane 4) both active at 1s
reuseMask = activeByLane(:, 3) & activeByLane(:, 4);

nTotal = sum(selectedMask);
nReuse = sum(reuseMask & selectedMask);
nNon = nTotal - nReuse;

%% 
% --- Plot
f = figure('Color', 'w', 'Name', 'English Fig1I Reused Cells Pie');
f.Units = 'centimeters';
f.Position(3:4) = [3, 4]; % 30mm x 40mm
f.PaperUnits = 'centimeters';
f.PaperPositionMode = 'manual';
f.PaperPosition = [0, 0, 3, 4];
f.PaperSize = [3, 4];

if nTotal > 0
	pReuse = nReuse / nTotal;
	pNon   = nNon / nTotal;
else
	pReuse = NaN;
	pNon   = NaN;
end

majorColor = 0.7922 .* [1 1 1];
minorColor = [0, 0.6275, 0.9137];
if pReuse >= pNon
	wedgeColors = [majorColor; minorColor];
else
	wedgeColors = [minorColor; majorColor];
end

ax = axes(f);
h = MATLAB.Graphics.NestedPie( ...
	{[pReuse, pNon]}, ...
	WedgeColors={wedgeColors}, ...
	LabelText=[string(sprintf('🔊💡\nreactive\ncells')), string(sprintf('🔊💧\nactive\ncells'))], ...
	PercentStatus="on", ...
	PercentFontColor='k', ...
	RhoLower=0.4, ...
	LineWidth=0.5, ...
	LabelOffset=0, ...
	AxesHandle=ax);

% Set all text to 6pt
set(findobj(f, 'Type', 'text'), 'FontSize', 6);

% --- Export
try
outDirUNC = "\\Data-Server-2\个人数据\张天夫\202602";
	if ~isfolder(outDirUNC)
		mkdir(outDirUNC);
	end
catch
end

svgName = "English_Fig1I_ReusedCellsPie.svg";
svgPath = fullfile(outDirUNC, svgName);
try
	TransferLearning.PrintFigure(f, svgPath);
	fprintf('Wrote: %s\n', svgPath);
catch ME
	warning(ME.identifier, 'Export failed: %s', ME.message);
end

assignin('base', 'Fig1I_ReusedCounts', table(nReuse, nNon, nTotal));

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
		error('Fig1I:BadNTATS', 'Expected NTATS to be 3D numeric or NDTable.');
	end
	X = nt;
	return;
end

error('Fig1I:BadNTATS', 'Unsupported NTATS container type: %s', class(nt));
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
