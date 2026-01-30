% 图3.6a：RSPd NTATS 热图（Learned AudioWater vs Transfer LightWater Hit/Miss，全细胞，不分层）
%
% 每脚本一张子图（A），SVG only -> \\Data-Server-2\个人数据\张天夫\202601
%
% 运行：
%   TransferLearning.Fig36.A_TaskDiscrimination

outDirUNC = "\\Data-Server-2\个人数据\张天夫\202601";
svgName = "Fig3_6a_RSPd_TaskDiscrimination_Learned_vs_TransferHitMiss_Peak01s.svg";

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

% --- 1b) Active@1s (used to filter cells)
kSigma = 3;
baseMask = (xsSec >= -3) & (xsSec < 0);
if nnz(baseMask) < 3
	error('Fig3_6a:BadBaselineMask', 'Baseline window (-3~0s) has too few samples in TransferLearning.Xs.');
end

[dtMin1, idx1] = min(abs(xsSec - 1));
if isempty(idx1) || ~isfinite(dtMin1) || dtMin1 > 0.25
	error('Fig3_6a:No1sSample', 'Cannot find a sample close to 1s in TransferLearning.Xs.');
end

% --- 2) Query 3 lanes (Median ZScore NTATS): Learned(AudioWater) + Transfer(LightWater) Hit/Miss
qLearnedAudio = struct('Phase','Learned','Stimulus','AudioWater','Design','AudioWater');

QT_HM = table(categorical({'Hit';'Miss'}), categorical({'Transfer';'Transfer'}), categorical({'LightWater';'LightWater'}), categorical({'LightWater';'LightWater'}), {1;0}, ...
	'VariableNames', {'GroupName','Phase','Design','Stimulus','Behavior'});

G = struct();
G.LearnedAudio = RSP.QueryNTATS(qLearnedAudio, UniExp.Flags.ZScore, 1:24, UniExp.Flags.Median);
G.TransferHit  = RSP.QueryNTATS(QT_HM(1,:),   UniExp.Flags.ZScore, 1:24, UniExp.Flags.Median);
G.TransferMiss = RSP.QueryNTATS(QT_HM(2,:),   UniExp.Flags.ZScore, 1:24, UniExp.Flags.Median);

% --- 3) Unify cells across lanes (keep identical cell order)
S = UniExp.NtatsCellStrip(G);
XFull = iGetNtats3D(S);

% Filter: remove cells inactive at 1s in ALL 3 lanes
act = false(size(XFull,1), size(XFull,3));
for iLane = 1:size(XFull,3)
	Xi = double(XFull(:,:,iLane));
	baseMu = mean(Xi(:, baseMask), 2, 'omitnan');
	baseSd = std(Xi(:, baseMask), 0, 2, 'omitnan');
	val1 = Xi(:, idx1);
	act(:, iLane) = val1 > (baseMu + kSigma .* baseSd);
end
keepCell = any(act, 2) & any(isfinite(XFull(:, idx1, :)), 3);
XFull = XFull(keepCell, :, :);

% --- 4) Sort cells by (Learned - TransferMiss) difference at 1s
XL = squeeze(XFull(:,:,1));
XMiss = squeeze(XFull(:,:,3));

diffLM = double(XL(:, idx1)) - double(XMiss(:, idx1));
diffLM(~isfinite(diffLM)) = NaN;
[~, sortIdx] = sort(diffLM, 'descend', 'MissingPlacement','last');

laneData = XFull(sortIdx, xMask, :);

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
	MATLAB.Graphics.FigureAspectRatio(3,2,3/4);
catch
end

Layout = tiledlayout(f, 1, 3, 'TileSpacing','none', 'Padding','tight');
subTitles = ["Learned 🔊💧", "Tr Hit 💡💧", "Tr Miss 💡💧"]; % keep emoji like Fig3.5AB

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
TransferLearning.PrintFigure(f, svgPath);
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

