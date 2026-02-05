% 英文图1S1：复用细胞占比（饼图）
%
% 复用细胞定义：Learned AudioWater 与 Transfer LightWater 在1s处均活跃
% 活跃判定：1s处 > baseline + 3*std（baseline = -3~0s）
% 统计范围：全体细胞合并
%
% Execution:
%   TransferLearning.英文图1.S1_ReusedCellsPie

outDirUNC = "\\Data-Server-2\个人数据\张天夫\202601";
svgName = "English_Fig1S1_ReusedCellsPie.svg";

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

% Query NTATS (Median ZScore)
qLearned = struct('Phase', 'Learned', 'Stimulus', 'AudioWater');
qTransfer = struct('Phase', 'Transfer', 'Stimulus', 'LightWater');

G = struct();
G.Learned = DS.QueryNTATS(qLearned, UniExp.Flags.ZScore, 1:24, UniExp.Flags.Median);
G.Transfer = DS.QueryNTATS(qTransfer, UniExp.Flags.ZScore, 1:24, UniExp.Flags.Median);

S = UniExp.NtatsCellStrip(G);
X = iGetNtats3D(S); % [nCell x nTime x 2]

% Active at 1s
kSigma = 3;
XL = squeeze(X(:, :, 1));
XT = squeeze(X(:, :, 2));

baseMuL = mean(XL(:, baseMask), 2, 'omitnan');
baseSdL = std(XL(:, baseMask), 0, 2, 'omitnan');
baseMuT = mean(XT(:, baseMask), 2, 'omitnan');
baseSdT = std(XT(:, baseMask), 0, 2, 'omitnan');

v1L = XL(:, idx1s);
v1T = XT(:, idx1s);

activeL = isfinite(v1L) & isfinite(baseMuL) & isfinite(baseSdL) & (v1L > (baseMuL + kSigma * baseSdL));
activeT = isfinite(v1T) & isfinite(baseMuT) & isfinite(baseSdT) & (v1T > (baseMuT + kSigma * baseSdT));

reuseMask = activeL & activeT;

nTotal = size(X, 1);
nReuse = sum(reuseMask);
nNon = nTotal - nReuse;

% --- Plot
f = figure('Color', 'w', 'Name', 'English Fig1S1 Reused Cells Pie');
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

assignin('base', 'Fig1S1_ReusedCounts', table(nReuse, nNon, nTotal));

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
		error('Fig1S1:BadNTATS', 'Expected NTATS to be 3D numeric or NDTable.');
	end
	X = nt;
	return;
end

error('Fig1S1:BadNTATS', 'Unsupported NTATS container type: %s', class(nt));
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
