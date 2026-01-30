% Fig3.7A：TH 抑制组（TransferLearning.THInhibit）的 L-T-F 三泳道热图
%
% 参考：Fig3.6G / Fig3.3A。
% Lanes (share identical cell order):
% 1) Learned AudioWater
% 2) Transfer LightWater
% 3) Final   LightWater
%
% Time window:
% - 0~2 s
%
% Active-cell criterion (per lane):
% - Active@t  : NTATS(t) > mean(-3~0s) + 3*std(-3~0s)
% - Keep cell : active@1s OR active@1.5s in ANY lane
% - Drop cell : inactive in ALL 3 lanes at BOTH 1s and 1.5s
%
% Sorting:
% - same as Fig3.3A: sort by (LearnedAudio@1s - FinalLight@1s) ascending
%
% Output:
% - SVG to \\Data-Server-2\个人数据\张天夫\202601
%
% Execution:
%   TransferLearning.Fig37.A_NTATS1s_FinalActiveTransferLW_vs_LearnedActiveNaiveLW_BarScatter

outDirUNC = "\\Data-Server-2\个人数据\张天夫\202601";
svgName = "Fig3_7a_THInhibit_LTFHeatmap_0to2s.svg";

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

DS = TransferLearning.THInhibit();

% --- 1) Time window 0~2s
xs = TransferLearning.Xs;
if ~isduration(xs)
	xs = seconds(xs);
end
xsSec = seconds(xs);

xMask = (xsSec >= 0) & (xsSec <= 2);
if nnz(xMask) < 5
	error('Fig3_7a:BadTimeMask', 'Too few samples in 0~2s window.');
end

baseMask = (xsSec >= -3) & (xsSec < 0);
if nnz(baseMask) < 5
	error('Fig3_7a:BadBaselineMask', 'Too few samples in baseline window (-3~0s).');
end
kSigma = 3;

[idx1s, ok1] = iFindTimeIndex(xsSec, 1, 0.25);
[idx15s, ok15] = iFindTimeIndex(xsSec, 1.5, 0.25);
if ~ok1 || ~ok15
	error('Fig3_7a:BadIndex', 'Cannot find sample close to 1s or 1.5s in TransferLearning.Xs.');
end

% --- 2) Assert Transfer LightWater session uniqueness & purity
%iAssertTransferLightWaterSingleSessionPure(DS);
% NOTE: 如果这里报错，说明该组存在不满足“每鼠单一 Transfer LW 会话且无 AudioWater 混入”的情况。

iAssertTransferLightWaterSingleSessionPure(DS);

% --- 3) Query 3 lanes (Median ZScore NTATS)
qLearnedAudio = struct('Phase','Learned', 'Stimulus','AudioWater');
qTransferLW   = struct('Phase','Transfer','Stimulus','LightWater');
qFinalLW      = struct('Phase','Final',   'Stimulus','LightWater');

G = struct();
G.LearnedAudio = DS.QueryNTATS(qLearnedAudio, UniExp.Flags.ZScore, 1:24, UniExp.Flags.Median);
G.TransferLight = DS.QueryNTATS(qTransferLW, UniExp.Flags.ZScore, 1:24, UniExp.Flags.Median);
G.FinalLight = DS.QueryNTATS(qFinalLW, UniExp.Flags.ZScore, 1:24, UniExp.Flags.Median);

% --- 4) Unify cells across lanes
S = UniExp.NtatsCellStrip(G);
assignin('base','Fig3_7a_TH_CellStrip', S);

if ~istable(S) || ~any(strcmp(S.Properties.VariableNames,'CellUID'))
	error('Fig3_7a:NoCellUID', 'Expected CellUID in NtatsCellStrip output.');
end
uidAll = uint64(S.CellUID(:));
zKeyAll = iCellZKeyFromDS(DS, uidAll);

laneOrder = ["LearnedAudio","TransferLight","FinalLight"];
X = iGetNtats3D(S, laneOrder);

% --- 5) Keep cells that are active at 1s OR 1.5s in ANY lane
activeByLane = false(size(X,1), size(X,3));
for iL = 1:size(X,3)
	XL = squeeze(X(:,:,iL));
	baseMu = mean(XL(:, baseMask), 2, 'omitnan');
	baseSd = std(XL(:, baseMask), 0, 2, 'omitnan');
	v1 = XL(:, idx1s);
	v15 = XL(:, idx15s);
	act1 = isfinite(v1) & isfinite(baseMu) & isfinite(baseSd) & (v1 > (baseMu + kSigma*baseSd));
	act15 = isfinite(v15) & isfinite(baseMu) & isfinite(baseSd) & (v15 > (baseMu + kSigma*baseSd));
	activeByLane(:, iL) = act1 | act15;
end
activeMask = any(activeByLane, 2);

assignin('base','Fig3_7a_TH_ActiveMask', activeMask);
assignin('base','Fig3_7a_TH_ActiveByLane_1sOr1p5', activeByLane);
assignin('base','Fig3_7a_TH_ActiveCellUID', uidAll(activeMask));

% --- 6) Split by layer (MOp2/3 vs MOp5) and sort within each layer
mask23 = activeMask & (zKeyAll == "MOp23");
mask5  = activeMask & (zKeyAll == "MOp5");

[laneData23, sortIdx23, delta23] = iBuildLaneDataPerLayer(X, mask23, xMask, idx1s);
[laneData5,  sortIdx5,  delta5 ] = iBuildLaneDataPerLayer(X, mask5,  xMask, idx1s);

assignin('base','Fig3_7a_TH_Mask_MOp23', mask23);
assignin('base','Fig3_7a_TH_Mask_MOp5', mask5);
assignin('base','Fig3_7a_TH_SortIdx_MOp23', sortIdx23);
assignin('base','Fig3_7a_TH_SortIdx_MOp5', sortIdx5);
assignin('base','Fig3_7a_TH_Delta1s_MOp23', delta23);
assignin('base','Fig3_7a_TH_Delta1s_MOp5', delta5);

% --- 8) Plot (2 rows x 3 cols)
f = figure('Color','w', 'Name', 'Fig3.7A THInhibit L-T-F heatmap by layer (0~2s)');
try
	MATLAB.Graphics.FigureAspectRatio(2,1,3/4);
catch
end

Layout = tiledlayout(f, 2, 3, 'TileSpacing','none', 'Padding','tight');
subTitlesTop = ["Learned AudioWater", "Transfer LightWater", "Final LightWater"];
subTitlesBottom = ["", "", ""];

allLaneData = cat(1, laneData23, laneData5);
negV = min(allLaneData, [], 'all', 'omitnan');
posV = max(allLaneData, [], 'all', 'omitnan');
if ~isfinite(negV); negV = -1; end
if ~isfinite(posV); posV = 1; end
CLim = [min(negV,0), max(posV,0)];
if CLim(1) == 0 && CLim(2) == 0
	CLim = [-1 1];
end

axesAll = gobjects(0,1);
[~, Axes23] = UniExp.LanearHeatmap( ...
	laneData23, ...
	SubTitles=subTitlesTop, ...
	Flags=[UniExp.Flags.SymmetricColormap], ...
	CLim=CLim, ...
	Layout=Layout, ...
	ImagescStyle={'XData', seconds([0,2])}, ...
	LMHColor=[0,0,1;1,1,1;1,0,0]);

[~, Axes5] = UniExp.LanearHeatmap( ...
	laneData5, ...
	SubTitles=subTitlesBottom, ...
	Flags=[UniExp.Flags.SymmetricColormap], ...
	CLim=CLim, ...
	Layout=Layout, ...
	ImagescStyle={'XData', seconds([0,2])}, ...
	LMHColor=[0,0,1;1,1,1;1,0,0]);

axesAll = [Axes23(:); Axes5(:)];

xlabel(Layout, 'Time (s)');

if ~isempty(Axes23)
	ylabel(Axes23(1), 'MOp2/3', 'Interpreter','none');
	Axes23(1).YLabel.Rotation = 90;
	Axes23(1).YLabel.HorizontalAlignment = 'center';
end
if ~isempty(Axes5)
	ylabel(Axes5(1), 'MOp5', 'Interpreter','none');
	Axes5(1).YLabel.Rotation = 90;
	Axes5(1).YLabel.HorizontalAlignment = 'center';
end

try
	for ax = reshape(axesAll,1,[])
		if ~isgraphics(ax)
			continue;
		end
		ax.YTick = [];
		ax.YTickLabel = [];
	end
	if ~isempty(Axes23); Axes23(1).YTick = []; end
	if ~isempty(Axes5);  Axes5(1).YTick  = []; end
catch
end

CB = colorbar;
CB.Layout.Tile = 'east';
CB.Label.String = 'z-score';

for iA = 1:numel(axesAll)
	A = axesAll(iA);
	if ~isgraphics(A)
		continue;
	end
	xline(A, 0, ':k');
	xline(A, 1, '-k');
	A.TickDir = 'in';
	box(A, 'on');
	try
		if isprop(A, 'Toolbar') && ~isempty(A.Toolbar)
			A.Toolbar.Visible = 'off';
		end
	catch
	end
end

% ensure all text uses automatic font sizing
iSetFontSizeAuto(f);

% --- 9) Export
try
	if ~isfolder(outDirUNC)
		mkdir(outDirUNC);
	end
catch
end

svgPath = fullfile(outDirUNC, svgName);
TransferLearning.PrintFigure(f, svgPath);
fprintf('Wrote: %s\n', svgPath);

%% --- local helpers

function iSetFontSizeAuto(fig)
try
	objs = findall(fig, '-property', 'FontSizeMode');
	set(objs, 'FontSizeMode', 'auto');
catch
end
end

function [laneData, sortIdx, delta1s] = iBuildLaneDataPerLayer(X, maskLayer, xMask, idx1s)
if nnz(maskLayer) < 1
	laneData = nan(0, nnz(xMask), size(X,3));
	sortIdx = zeros(0,1);
	delta1s = nan(0,1);
	return;
end
Xl = X(maskLayer, :, :);
XL = squeeze(Xl(:,:,1));
XF = squeeze(Xl(:,:,3));
vL1s = XL(:, idx1s);
vF1s = XF(:, idx1s);
delta1s = vL1s - vF1s;
delta1s(~(isfinite(vL1s) & isfinite(vF1s))) = NaN;
[~, sortIdx] = sort(delta1s, 'ascend', 'MissingPlacement','last');
X02 = Xl(:, xMask, :);
laneData = X02(sortIdx, :, :);
end

function zKey = iCellZKeyFromDS(DS, uid)
zKey = strings(numel(uid), 1);
try
	if ~isprop(DS, 'Cells')
		return;
	end
	C = DS.Cells;
	if isempty(C) || ~all(ismember(["CellUID","ZLayer"], string(C.Properties.VariableNames)))
		return;
	end
	uid = uint64(uid(:));
	[tf, loc] = ismember(uid, uint64(C.CellUID));
	zl = strings(numel(uid), 1);
	zl(tf) = string(C.ZLayer(loc(tf)));
	z = strings(numel(uid), 1);
	m23 = (zl == "MOp2/3") | (zl == "MOp23");
	m5  = (zl == "MOp5");
	z(m23) = "MOp23";
	z(m5) = "MOp5";
	zKey = z;
catch
	% keep empty
end
end

function iAssertTransferLightWaterSingleSessionPure(DS)
% Requirement:
% - For each mouse, Transfer-phase LightWater trials belong to exactly ONE DateTime.
% - That DateTime must NOT contain any AudioWater trials.

T = DS.TableQuery(["Mouse","DateTime"], Phase="Transfer", Stimulus="LightWater");
if isempty(T)
	error('Fig3_7a:NoTransferLW', 'No Transfer LightWater trials found.');
end

T.Mouse = string(T.Mouse);
try
	T.DateTime = datetime(T.DateTime);
catch
end

mice = unique(T.Mouse);
badMulti = strings(0,1);
badEmpty = strings(0,1);
badMix = strings(0,1);

for i = 1:numel(mice)
	m = mice(i);
	dt = unique(T.DateTime(T.Mouse==m));
	dt = dt(~isnat(dt));
	if isempty(dt)
		badEmpty(end+1) = m; %#ok<AGROW>
		continue;
	end
	if numel(dt) ~= 1
		badMulti(end+1) = m; %#ok<AGROW>
		continue;
	end
	try
		Ts = DS.TableQuery("Stimulus", Mouse=m, DateTime=dt);
		st = string(Ts.Stimulus);
		if any(st == "AudioWater")
			badMix(end+1) = m; %#ok<AGROW>
		end
	catch
		badMix(end+1) = m; %#ok<AGROW>
	end
end

if ~isempty(badEmpty)
	error('Fig3_7a:TransferLWBadDateTime', 'Some mice have Transfer LW trials but missing DateTime: %s', strjoin(badEmpty, ', '));
end
if ~isempty(badMulti)
	error('Fig3_7a:TransferLWMulitpleSessions', 'Transfer LightWater is not a single session for mice: %s', strjoin(badMulti, ', '));
end
if ~isempty(badMix)
	error('Fig3_7a:TransferLWMixedStim', 'Transfer LightWater session contains AudioWater trials for mice: %s', strjoin(unique(badMix), ', '));
end
end

function X = iGetNtats3D(S, laneOrder)
% Return numeric [nCell x nTime x nLane] NTATS.
if istable(S)
	nt = S.NTATS;
elseif isstruct(S) && isfield(S,'NTATS')
	nt = S.NTATS;
else
	error('Fig3_7a:BadCellStrip', 'Unexpected CellStrip container: %s', class(S));
end

if isa(nt, 'MATLAB.DataTypes.NDTable')
	try
		D = nt.Data;
		if isa(D, 'MATLAB.DataTypes.NDTable')
			Xall = D.Data;
		else
			Xall = D;
		end
	catch
		Xall = nt{:,:,:}.Data;
	end
elseif isnumeric(nt)
	Xall = nt;
else
	try
		Xall = nt{:,:,:};
	catch
		error('Fig3_7a:BadNTATS', 'Unsupported NTATS container type: %s', class(nt));
	end
end

Xall = squeeze(double(Xall));
if ndims(Xall) ~= 3
	error('Fig3_7a:BadNTATSDims', 'Expected NTATS to be 3-D after squeeze.');
end

X = Xall;
try
	if istable(S) && any(strcmp(S.Properties.VariableNames,'Lane'))
		lane = string(S.Lane);
		uLane = unique(lane, 'stable');
		if numel(uLane) == size(Xall,3)
			idx = zeros(1, numel(laneOrder));
			for i = 1:numel(laneOrder)
				idx(i) = find(uLane == laneOrder(i), 1, 'first');
			end
			if all(idx >= 1)
				X = Xall(:,:,idx);
			end
		end
	end
catch
end
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
