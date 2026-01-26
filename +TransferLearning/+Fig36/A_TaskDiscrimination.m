% 图3.6a：RSPd NTATS 热图（Learned AudioWater vs Transfer LightWater，全细胞，不分层）
%
% 每脚本一张子图（A），SVG only -> \\Data-Server-2\个人数据\张天夫\202601
%
% 运行：
%   TransferLearning.Fig36.A_TaskDiscrimination

outDirUNC = "\\Data-Server-2\个人数据\张天夫\202601";
svgName = "Fig3_6a_RSPd_TaskDiscrimination_Peak01s.svg";

% --- Ensure project loaded (for UniExp)
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

RSP = TransferLearning.RSPd();

% --- 1) Time window 0~3s (match Fig3.5AB style)
xs = TransferLearning.Xs;
if ~isduration(xs)
	xs = seconds(xs);
end
xsSec = seconds(xs);
xMask = (xsSec >= 0) & (xsSec <= 3);
if nnz(xMask) < 5
	error('Fig3_6a:BadTimeMask', 'Too few samples in 0~3s window.');
end

% --- 2) Query 2 lanes (Median ZScore NTATS)
qLearnedAudio = struct('Phase','Learned','Stimulus','AudioWater','Design','AudioWater');
qTransferLW   = struct('Phase','Transfer','Stimulus','LightWater','Design','LightWater');

G = struct();
G.LearnedAudio = RSP.QueryNTATS(qLearnedAudio, UniExp.Flags.ZScore, 1:24, UniExp.Flags.Median);
G.TransferLW   = RSP.QueryNTATS(qTransferLW,   UniExp.Flags.ZScore, 1:24, UniExp.Flags.Median);

% --- 3) Unify cells across lanes (keep identical cell order)
S = UniExp.NtatsCellStrip(G);
X = iGetNtats3D(S);

% --- 4) Sort cells by peak time in Transfer lane within 0~3s
XTr = squeeze(X(:,:,2));
[tPeakTr, okTr] = iPeakTime_0to3(XTr, xsSec, xMask);
tPeakTr(~okTr) = NaN;
[~, sortIdx] = sort(tPeakTr, 'ascend', 'MissingPlacement','last');

laneData = X(sortIdx, xMask, :);

% Color limits (NON-symmetric): sqrt-scale magnitude for lower/upper separately
negV = min(laneData, [], 'all', 'omitnan');
posV = max(laneData, [], 'all', 'omitnan');
if ~isfinite(negV); negV = -1; end
if ~isfinite(posV); posV = 1; end

climLowAbs = iNiceLimit(sqrt(abs(min(negV, 0))));
climHighAbs = iNiceLimit(sqrt(abs(max(posV, 0))));
if climLowAbs <= 0; climLowAbs = 1; end
if climHighAbs <= 0; climHighAbs = 1; end
CLim = [-climLowAbs, climHighAbs];

% --- 5) Plot (match Fig3.5AB style)
f = figure('Color','w', 'Name', 'Fig3.6a RSPd heatmap (0~3s)');
try
	MATLAB.Graphics.FigureAspectRatio(8,5, 1/2);
catch
end

Layout = tiledlayout(f, 1, 2, 'TileSpacing','none', 'Padding','tight');
subTitles = ["Learned 🔊💧", "Tr 💡💧"]; % keep emoji like Fig3.5AB

[~, Axes] = UniExp.LanearHeatmap( ...
	laneData, ...
	SubTitles=subTitles, ...
	Flags=[UniExp.Flags.HideYAxis, UniExp.Flags.SymmetricColormap], ...
	CLim=CLim, ...
	Layout=Layout, ...
	ImagescStyle={'XData', seconds([0,3])}, ...
	LMHColor=[0,0,1;1,1,1;1,0,0]);

xlabel(Layout, 'Time (s)');
ylabel(Layout, sprintf('%d cells', size(laneData,1)));

CB = colorbar;
CB.Layout.Tile = 'east';
CB.Label.String = 'z-score';

for iA = 1:numel(Axes)
	A = Axes(iA);
	if ~isgraphics(A)
		continue;
	end
	TransferLearning.DrawCueWaterLines(A);
	A.TickDir = 'in';
	box(A, 'on');
	try
		% Ensure emoji glyphs render in exported SVG on Windows.
		if isprop(A, 'Title') && isgraphics(A.Title)
			A.Title.FontName = 'Segoe UI Emoji';
		end
	catch
	end
	try
		if isprop(A, 'Toolbar') && ~isempty(A.Toolbar)
			A.Toolbar.Visible = 'off';
		end
	catch
	end
end

title(Layout, 'RSPd NTATS heatmap (0–3s, all cells)', 'Interpreter','none');

try
	if ~isfolder(outDirUNC); mkdir(outDirUNC); end
catch
end

svgPath = fullfile(outDirUNC, svgName);
exportgraphics(f, svgPath, 'ContentType','vector');
fprintf('Wrote: %s\n', svgPath);

%% --- local helpers

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
		error('Fig3_6a:BadNTATS', 'Expected NTATS to be 3D numeric or NDTable.');
	end
	X = nt;
	return;
end

error('Fig3_6a:BadNTATS', 'Unsupported NTATS container type: %s', class(nt));
end

function [tPeak, ok] = iPeakTime_0to3(X, xsSec, xMask)
Xw = X(:, xMask);
finiteRow = any(isfinite(Xw), 2);
[~, idxRel] = max(Xw, [], 2, 'omitnan');
idxRel(~finiteRow) = 1;
xsW = xsSec(xMask);
tPeak = xsW(idxRel);
tPeak(~finiteRow) = NaN;
ok = finiteRow;
end

function y = iNiceLimit(x)
% Round x up to a "nice" limit using 1-2-5 scaling.
if ~isfinite(x) || x <= 0
	y = 1;
	return;
end

e = floor(log10(x));
f = x / (10^e);

if f <= 1
	n = 1;
elseif f <= 2
	n = 2;
elseif f <= 5
	n = 5;
else
	n = 10;
end

y = n * (10^e);
if y < x
	y = 10 * (10^e);
end
end

