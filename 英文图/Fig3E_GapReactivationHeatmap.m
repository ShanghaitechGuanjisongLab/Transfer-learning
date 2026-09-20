% English Fig3E: transfer-block reactivation of the learned ensemble,
% no gap vs 7-day gap
%
% Two lanes, one per group (no gap = AudioLightBaseline, 7-day gap =
% Vacation7). Both show the SAME cells in the SAME block: cells active at cue
% +1 s (> baseline -3..0 s mean + 3 sigma) in the learned audio-water block of
% that group, plotted in the first transfer light-water block, sorted by the
% learned response at cue +1 s (descending), group-level median across mice.
% The learned stage is therefore used only for cell selection and sorting, not
% as a separate lane. Claim: after 7 days the learned-active cells are largely
% silent during transfer.
%
% Outputs (SVG):
%   - English_Fig3E_GapReactivationHeatmap.svg
%
% Execution (hard requirement):
% - Keep this file as a script (do NOT convert to function).
% - Open in MATLAB Editor and Run/F5.

if ~exist('UniExp.DataSet', 'class')
	thisDirE = fileparts(mfilename('fullpath'));
	prjFile = fullfile(thisDirE, '..', 'Transferlearning.prj');
	if exist(prjFile, 'file')
		matlab.project.loadProject(prjFile);
	end
end

xs = TransferLearning.Xs;
if ~isduration(xs)
	xs = seconds(xs);
end
xsSec = seconds(xs);
xMask = (xsSec >= -1) & (xsSec <= 2);
xsPlot = xsSec(xMask);
baseMask = (xsSec >= -3) & (xsSec < 0);
kSigma = 3;
[idx1s, ok1s] = iFindTimeIndex(xsSec, 1, 0.25);
if ~ok1s
	error('English_Fig3E:No1s', 'Cannot find sample close to 1 s.');
end

CtrlDS = TransferLearning.AudioLightBaseline();
V7DS = TransferLearning.Vacation7();

[ctrlMat, ~, nCtrlCell] = iGroupTransferLane(CtrlDS, xMask, baseMask, idx1s, kSigma);
[v7Mat, ~, nV7Cell] = iGroupTransferLane(V7DS, xMask, baseMask, idx1s, kSigma);

fprintf('=== Fig3E transfer reactivation heatmap ===\n');
fprintf('No gap:    %d learned-active cells shown in the transfer block\n', nCtrlCell);
fprintf('7-day gap: %d learned-active cells shown in the transfer block\n', nV7Cell);

% 对称色限（两泳道共用）
allVals = [ctrlMat(:); v7Mat(:)];
allVals = allVals(isfinite(allVals));
negV = min(allVals);
posV = max(allVals);
if ~isfinite(negV)
	negV = -1;
end
if ~isfinite(posV)
	posV = 1;
end
CLim = [-sqrt(abs(min(negV, 0))), sqrt(max(posV, 0))];

f = figure('Color', 'w', 'Name', 'English Fig3E gap transfer reactivation heatmap');
f.Units = 'centimeters';
f.Position(3:4) = [9, 8];
f.PaperUnits = 'centimeters';
f.PaperSize = [9, 8];
f.PaperPositionMode = 'auto';

Layout = tiledlayout(f, 1, 2, 'TileSpacing', 'tight', 'Padding', 'tight');
% 注意：sprintf 返回 char，方括号拼接会横向连成一个字符串；必须转 string 数组，
% 否则 LanearHeatmap 的 SubTitles(L) 会取到单个字母。
% 标题只放组名（细胞数在图注给出），避免窄泳道下两标题重叠
subTitles = ["No gap", "7-day gap"];

[~, Axes] = UniExp.LanearHeatmap( ...
	{ctrlMat, v7Mat}, ...
	SubTitles = subTitles, ...
	Flags = [UniExp.Flags.HideYAxis, UniExp.Flags.SymmetricColormap], ...
	CLim = CLim, ...
	Layout = Layout, ...
	XData = [xsPlot(1), xsPlot(end)], ...
	LMHColor = [TransferLearning.HeatmapNegative; 1, 1, 1; TransferLearning.HeatmapPositive]);

Ax = Axes(:);
Ax = Ax(isgraphics(Ax));
for k = 1:numel(Ax)
	A = Ax(k);
	defFont = get(groot, 'defaultAxesFontName');
	A.FontName = 'Segoe UI Emoji';
	xlim(A, [xsPlot(1), xsPlot(end)]);
	xline(A, 0, '--', 'Color', [0.35 0.35 0.35]);
	xline(A, 1, '-.', 'Color', [0.35 0.35 0.35]);
	% 刻度只保留 cue/给水两个 emoji（该字体缺数字与连字符字形）
	A.XTick = [0, 1];
	A.XTickLabel = {'💡', '💧'};
	A.TickDir = 'in';
	box(A, 'on');
	% 标题必须用拉丁字体，否则 Segoe UI Emoji 缺字形导致标题只剩个别字母
	if isprop(A, 'Title') && isgraphics(A.Title)
		A.Title.FontName = defFont;
		A.Title.FontSize = 8;
		A.Title.FontWeight = 'normal';
	end
	if isprop(A, 'Toolbar') && ~isempty(A.Toolbar)
		A.Toolbar.Visible = 'off';
	end
end

% 规范：所有泳道 X 轴含义相同，xlabel/ylabel 写在 Layout 级别（ylabel 长度需短于 Y 轴线长）
xlabel(Layout, 'Time from cue (s)');
ylabel(Layout, 'Cells');
CB = colorbar;
CB.Layout.Tile = 'east';
CB.Label.String = 'z-score';
CB.Box = 'off';

outDirUNC = fullfile('\\Data-Server-2\个人数据\张天夫', char(datetime('now', 'Format', 'yyyyMM')));
if ~isfolder(outDirUNC)
	mkdir(outDirUNC);
end
% 规范：先结算标准样式与 padding，再统一两泳道轴限，最后导出
TransferLearning.ApplyStandardExportStyle(f, 2);
MATLAB.Graphics.UnifyAxesLims(Ax, @xlim);
svgPath = TransferLearning.ExportStandardFigure(f, 2, 'English_Fig3E_GapReactivationHeatmap.svg');
fprintf('Wrote: %s\n', svgPath);

assignin('base', 'Fig3E_HeatmapCounts', struct('nCtrl', nCtrlCell, 'nV7', nV7Cell));

%% ========== local functions ==========
function [tranMat, sortIdx, nCell] = iGroupTransferLane(DS, xMask, baseMask, idx1s, kSigma)
% QueryNTATS 组级中值聚合（与中文图46C一致）：learned@1s > baseline+3sigma 选细胞，
% 按 learned@1s 降序排序，只返回 transfer 泳道矩阵
qLearnedAudio = struct('Phase', 'Learned', 'Stimulus', 'AudioWater');
qTransfer = struct('Phase', 'Transfer', 'Stimulus', 'LightWater');
G = struct();
G.LearnedAudio = DS.QueryNTATS(qLearnedAudio, UniExp.Flags.ZScore, 1:24, UniExp.Flags.Median);
G.Transfer = DS.QueryNTATS(qTransfer, UniExp.Flags.ZScore, 1:24, UniExp.Flags.Median);
S = UniExp.NtatsCellStrip(G);
X = iGetNtats3D(S);
laneData3D = X(:, xMask, :);

XL = squeeze(X(:, :, 1));
bMu = mean(XL(:, baseMask), 2, 'omitnan');
bSd = std(XL(:, baseMask), 0, 2, 'omitnan');
v1 = XL(:, idx1s);
activeMask = isfinite(v1) & isfinite(bMu) & isfinite(bSd) & (v1 > (bMu + kSigma * bSd));
laneData3D = laneData3D(activeMask, :, :);
if isempty(laneData3D)
	tranMat = zeros(0, sum(xMask));
	sortIdx = [];
	nCell = 0;
	return;
end

vLearn1s = squeeze(X(activeMask, idx1s, 1));
vLearn1s(~isfinite(vLearn1s)) = -inf;
[sOrder, sortIdx] = sort(vLearn1s, 'descend'); %#ok<ASGLU>
laneData = laneData3D(sortIdx, :, :);
tranMat = laneData(:, :, 2);
nCell = size(laneData, 1);
end

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
		X = nt{:, :, :}.Data;
	end
	return;
end
if isnumeric(nt)
	if ndims(nt) ~= 3
		error('English_Fig3E:BadNTATS', 'Expected NTATS to be 3D numeric or NDTable.');
	end
	X = nt;
	return;
end
error('English_Fig3E:BadNTATS', 'Unsupported NTATS container type: %s', class(nt));
end

function [idx, ok] = iFindTimeIndex(xsSec, tSec, tolSec)
[d, idx] = min(abs(xsSec(:) - tSec));
ok = isfinite(d) && (d <= tolSec);
end
