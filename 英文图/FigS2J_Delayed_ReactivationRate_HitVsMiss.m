% 英文图S2J：Hit vs Miss 再激活率（ALDelayed 延迟任务版，模仿英文图S1G）
%
% Reactivation = P(Transfer active | Learned active) at 1.5 s（S1G 用 1s；延迟任务
% 活跃判定点用 cue +1.5 s，即反应/名义给水时刻）
%   L = Learned AudioLearnWater（最后一个会话）在 1.5s 处活跃
%   T_hit/T_miss = Transfer LightLearnWater（首个会话）Hit/Miss 回合在 1.5s 处活跃
% 活跃判定同 S1G：z-score(基线 1:24) > 基线(-3~0s)均值 + 3σ
% 数据源 TransferLearning.ALDelayed；Always 给水回合不取；会话定义同 FigS2H/S2I。
% 分层合并同 S1G：MOp2/3 与 MOp5 各算条件概率后逐鼠取均值。
% 配对检验：signrank(Hit > Miss, 'tail','right')
%
% Execution:
%   run('英文图/FigS2J_Delayed_ReactivationRate_HitVsMiss.m')

if ~exist('UniExp.DataSet', 'class')
	thisFile = mfilename('fullpath');
	thisDir = fileparts(thisFile);
	prjFile = fullfile(thisDir, '..', 'Transferlearning.prj');
	if ~exist(prjFile, 'file')
		prjFile = fullfile(thisDir, '..', '..', 'Transferlearning.prj');
	end
	if exist(prjFile, 'file')
		matlab.project.loadProject(prjFile);
	end
end

R = iBuildProbDelayedPerMouseLayer();
if isempty(R)
	error('FigS2J:Empty', 'No valid mice for Reactivation Hit/Miss.');
end

% 合并2/3和5层数据：取各鼠每层的均值（同 S1G）
hit = nanmean([R.ProbHit23, R.ProbHit5], 2);
miss = nanmean([R.ProbMiss23, R.ProbMiss5], 2);
mask = isfinite(hit) & isfinite(miss);
learnedActiveCells = R.NLearnedActive23 + R.NLearnedActive5;
nCells = sum(learnedActiveCells(mask), 'omitnan');
%%

f = figure('Color', 'w', 'Name', 'English FigS2J Delayed Reactivation Hit vs Miss');
f.Units = 'centimeters';
f.Position(3:4) = [4.0, 8.0];
f.PaperUnits = 'centimeters';
f.PaperPositionMode = 'manual';
f.PaperPosition = [0, 0, 4.0, 8.0];
f.PaperSize = [4.0, 8.0];

ax = axes(f);
hold(ax, 'on');
if isprop(ax, 'Toolbar') && ~isempty(ax.Toolbar)
	ax.Toolbar.Visible = 'off';
end
ax.LineWidth = 1;

p = NaN;
if nnz(mask) >= 4
	p = signrank(hit(mask), miss(mask), 'tail', 'right');
end

Y = [hit(mask), miss(mask)];
hitColor = TransferLearning.ColorA;
missColor = TransferLearning.ColorB;
plot(ax, Y', '-', 'LineWidth', 1, 'Color', [0, 0, 0]);
scatter(ax, ones(nnz(mask), 1), hit(mask), 15, hitColor, 'filled', 'LineWidth', 0.2, 'MarkerEdgeColor', hitColor);
scatter(ax, 2 * ones(nnz(mask), 1), miss(mask), 15, missColor, 'filled', 'LineWidth', 0.2, 'MarkerEdgeColor', missColor);
set(ax, 'XTick', [1 2], 'XTickLabel', {'Hit', 'Miss'});
grid(ax, 'off');
box(ax, 'off');
ax.FontSize = 6;
ax.FontName = 'Segoe UI Emoji';
ylabel(ax, 'Reactivation', 'FontSize', 6);
title(ax, '💡💧', 'FontSize', 6, 'FontWeight', 'normal');

% p-value line with asterisk (paired signrank) via MATLAB.Graphics.PLine（同 S1G）
if isfinite(p)
	S = scatter(ax, [ones(nnz(mask), 1); 2 * ones(nnz(mask), 1)], [hit(mask); miss(mask)], ...
		1, 'k', 'filled', 'Visible', 'off', 'HandleVisibility', 'off');
	if isprop(S, 'HitTest'); S.HitTest = 'off'; end
	if isprop(S, 'PickableParts'); S.PickableParts = 'none'; end
	if isprop(S, 'AffectAutoLimits'); S.AffectAutoLimits = false; end
	pText = TransferLearning.Style.iFormatPText(p);
	Descriptors = table(S, 0, 0, pText, 0, ...
		'VariableNames', {'ObjectA', 'IndexA', 'IndexB', 'Text', 'ExtraOffset'});
	[pLines, pTexts] = MATLAB.Graphics.PLine(Descriptors);
	for pl = pLines(:)'
		pl.LineWidth = 1;
		pl.Tag = 'PLine';
	end
	for pt = pTexts(:)'
		pt.FontSize = 6;
		pt.Tag = 'PText';
	end
	delete(S);
end

svgName = "English_FigS2J_Delayed_ReactivationRate_HitVsMiss.svg";
svgPath = TransferLearning.ExportStandardFigure(f, 2, svgName);
fprintf('Wrote: %s\n', svgPath);

fprintf('\n=== English FigS2J (delayed) Reactivation Hit vs Miss ===\n');
disp(R);
fprintf('paired mice n = %d\n', nnz(mask));
fprintf('participating learned-active cells n = %d\n', nCells);
fprintf('signrank right-tail p = %.6g\n', p);

assignin('base', 'FigS2J_PerMouseLayer', R);

%% ========== local functions（口径同英文图S1G / iBuildProb_..._1s_PerMouseLayer，判定点改 1.5s） ==========
function R = iBuildProbDelayedPerMouseLayer()
R = iEmptyResult();
DS = TransferLearning.ALDelayed();

xs = TransferLearning.Xs;
if isduration(xs)
	xsSec = seconds(xs);
else
	xsSec = double(xs);
end
baseMask = (xsSec >= -3) & (xsSec < 0);
[idx15, ok15] = iFindTimeIndex(xsSec, 1.5, 0.25);
if ~ok15
	error('FigS2J:No15', 'Cannot find sample close to 1.5 s.');
end
kSigma = 3;

% 每鼠：Learned = 最后一个含 AudioLearnWater 的会话；Transfer = 首个含 LightLearnWater 的会话
T = DS.TableQuery(["Mouse", "DateTime", "Stimulus", "Behavior"]);
T.Mouse = string(T.Mouse);
T.Stimulus = string(T.Stimulus);
T.DateTime = datetime(T.DateTime);
if ~isempty(T.DateTime.TimeZone)
	T.DateTime.TimeZone = '';
end
mice = unique(T.Mouse);
Mouse = strings(0, 1);
DTL = NaT(0, 1);
DTT = NaT(0, 1);
for i = 1:numel(mice)
	m = mice(i);
	Tl = T(T.Mouse == m & T.Stimulus == "AudioLearnWater", :);
	Tt = T(T.Mouse == m & T.Stimulus == "LightLearnWater", :);
	if isempty(Tl) || isempty(Tt)
		continue;
	end
	Mouse(end + 1, 1) = m;
	DTL(end + 1, 1) = max(Tl.DateTime);
	DTT(end + 1, 1) = min(Tt.DateTime);
end
if isempty(Mouse)
	return;
end

% 查询：Learned / Transfer（各一组）+ Transfer Hit/Miss（Behavior 过滤，两组）
QL = table(Mouse, DTL, repmat("AudioLearnWater", numel(Mouse), 1), repmat("Learned", numel(Mouse), 1), ...
	'VariableNames', {'Mouse', 'DateTime', 'Stimulus', 'GroupName'});
QT = table(Mouse, DTT, repmat("LightLearnWater", numel(Mouse), 1), repmat("Transfer", numel(Mouse), 1), ...
	'VariableNames', {'Mouse', 'DateTime', 'Stimulus', 'GroupName'});
QHM = [table(Mouse, DTT, repmat("LightLearnWater", numel(Mouse), 1), repmat("Hit", numel(Mouse), 1), ones(numel(Mouse), 1), ...
	'VariableNames', {'Mouse', 'DateTime', 'Stimulus', 'GroupName', 'Behavior'}); ...
	table(Mouse, DTT, repmat("LightLearnWater", numel(Mouse), 1), repmat("Miss", numel(Mouse), 1), zeros(numel(Mouse), 1), ...
	'VariableNames', {'Mouse', 'DateTime', 'Stimulus', 'GroupName', 'Behavior'})];

GL = DS.QueryNTATS(QL, UniExp.Flags.ZScore, 1:24, UniExp.Flags.Median);
GT = DS.QueryNTATS(QT, UniExp.Flags.ZScore, 1:24, UniExp.Flags.Median);
GHM = DS.QueryNTATS(QHM, UniExp.Flags.ZScore, 1:24, UniExp.Flags.Median);

[cellLearn, XLrn] = iExtractGroups(GL, "Learned");
[cellTran, XT] = iExtractGroups(GT, "Transfer");
[cellHM, XHMAll] = iExtractGroups(GHM, ["Hit", "Miss"]); % dim3 = Hit, Miss
XLearnAll = XLrn(:, :, 1);
XTranAll = XT(:, :, 1);
XHitAll = XHMAll(:, :, 1);
XMissAll = XHMAll(:, :, 2);

CellMeta = DS.Cells(:, ["CellUID", "ZLayer", "Mouse"]);
CellMeta.CellUID = uint64(CellMeta.CellUID);
CellMeta.ZLayer = string(CellMeta.ZLayer);
CellMeta.Mouse = string(CellMeta.Mouse);

for iRow = 1:numel(Mouse)
	mouseName = Mouse(iRow);
	dtLearned = DTL(iRow);
	dtTransfer = DTT(iRow);

	beh = double(T.Behavior(T.Mouse == mouseName & T.Stimulus == "LightLearnWater" & T.DateTime == dtTransfer));
	beh = beh(isfinite(beh));
	if isempty(beh) || ~(any(beh == 1) && any(beh == 0))
		continue;
	end

	mouseCells = CellMeta.CellUID(CellMeta.Mouse == mouseName);
	if isempty(mouseCells)
		continue;
	end

	[~, idxL_mouse] = intersect(cellLearn, mouseCells, 'stable');
	[~, idxT_mouse] = intersect(cellTran, mouseCells, 'stable');
	[~, idxH_mouse] = intersect(cellHM, mouseCells, 'stable');

	[commonAll, idxL, idxT] = intersect(cellLearn(idxL_mouse), cellTran(idxT_mouse), 'stable');
	[commonAll, idxA, idxHM] = intersect(commonAll, cellHM(idxH_mouse), 'stable');
	if isempty(commonAll)
		continue;
	end

	XLearn = XLearnAll(idxL_mouse(idxL(idxA)), :);
	XTran = XTranAll(idxT_mouse(idxT(idxA)), :);
	XHit = XHitAll(idxH_mouse(idxHM), :);
	XMiss = XMissAll(idxH_mouse(idxHM), :);

	[tfL, ordC] = ismember(commonAll, CellMeta.CellUID);
	cellLayers = strings(numel(commonAll), 1);
	cellLayers(tfL) = CellMeta.ZLayer(ordC(tfL));

	learnedActive = iIsActiveAt15(XLearn, baseMask, idx15, kSigma);
	transferActive = iIsActiveAt15(XTran, baseMask, idx15, kSigma);
	transferActiveHit = iIsActiveAt15(XHit, baseMask, idx15, kSigma);
	transferActiveMiss = iIsActiveAt15(XMiss, baseMask, idx15, kSigma);

	mask23 = contains(cellLayers, "2/3");
	mask5 = contains(cellLayers, "5") & ~mask23;

	[n23, prob23] = iConditionalProb(learnedActive, transferActive, mask23);
	[n5, prob5] = iConditionalProb(learnedActive, transferActive, mask5);
	[~, probHit23] = iConditionalProb(learnedActive, transferActiveHit, mask23);
	[~, probHit5] = iConditionalProb(learnedActive, transferActiveHit, mask5);
	[~, probMiss23] = iConditionalProb(learnedActive, transferActiveMiss, mask23);
	[~, probMiss5] = iConditionalProb(learnedActive, transferActiveMiss, mask5);

	transferHitRate = mean(beh, 'omitnan');

	R = [R; table(mouseName, dtLearned, dtTransfer, transferHitRate, ...
		n23, n5, prob23, prob5, probHit23, probHit5, probMiss23, probMiss5, "ALDelayed", ...
		'VariableNames', iEmptyResult().Properties.VariableNames)]; %#ok<AGROW>
end
end

function [cellUID, X] = iExtractGroups(G, groupNames)
% QueryNTATS 输出两种形态：各组细胞集一致时为 [CellUID,NTATS] 表（NTATS 为
% [nCell x nTime x nGroup] 数组）；不一致时为按组名分字段的 struct。统一取各组
% 细胞交集，返回 [nCommon x nTime x nGroup]，dim3 = groupNames 顺序。
nG = numel(groupNames);
if istable(G)
	cellUID = uint64(G.CellUID);
	X = iNtatsToNumeric(G.NTATS);
	if ndims(X) == 2
		X = reshape(X, size(X, 1), size(X, 2), 1);
	end
	return;
end
Xs = cell(nG, 1);
U = cell(nG, 1);
for k = 1:nG
	sub = G.(groupNames(k));
	U{k} = uint64(sub.CellUID);
	Xg = iNtatsToNumeric(sub.NTATS);
	if ndims(Xg) == 3
		Xg = squeeze(Xg(:, :, 1));
	end
	Xs{k} = Xg;
end
cellUID = U{1};
for k = 2:nG
	cellUID = intersect(cellUID, U{k}, 'stable');
end
X = nan(numel(cellUID), size(Xs{1}, 2), nG);
for k = 1:nG
	[tf, loc] = ismember(cellUID, U{k});
	X(tf, :, k) = Xs{k}(loc(tf), :);
end
end

function Xg = iNtatsToNumeric(nt)
if isnumeric(nt)
	Xg = double(nt);
	return;
end
try
	Xg = double(nt.Data);
catch
	Xg = reshape(double([nt.Data]), size(nt));
end
end

function active = iIsActiveAt15(X, baseMask, idx15, kSigma)
baseMu = mean(X(:, baseMask), 2, 'omitnan');
baseSd = std(X(:, baseMask), 0, 2, 'omitnan');
v15 = X(:, idx15);
active = isfinite(v15) & isfinite(baseMu) & isfinite(baseSd) & (v15 > (baseMu + kSigma .* baseSd));
end

function [nLearned, prob] = iConditionalProb(learnedActive, transferActive, layerMask)
use = layerMask & learnedActive;
nLearned = nnz(use);
if nLearned < 1
	prob = NaN;
else
	prob = mean(double(transferActive(use)), 'omitnan');
end
end

function T = iEmptyResult()
T = table(strings(0, 1), NaT(0, 1), NaT(0, 1), nan(0, 1), nan(0, 1), nan(0, 1), ...
	nan(0, 1), nan(0, 1), nan(0, 1), nan(0, 1), nan(0, 1), nan(0, 1), strings(0, 1), ...
	'VariableNames', {'Mouse', 'DateTimeLearned', 'DateTimeTransfer', 'TransferHitRate', ...
	'NLearnedActive23', 'NLearnedActive5', 'Prob23', 'Prob5', 'ProbHit23', 'ProbHit5', 'ProbMiss23', 'ProbMiss5', 'Source'});
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
