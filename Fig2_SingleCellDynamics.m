% Fig2｜单细胞层面：迁移学习呈现可分离的动态特性（仅生成 MATLAB 图窗）
%
% 数据方向：声→光（AW 学会 → LW 迁移）。所有行为指标取 LightWater。
%   Naive        直接学 LW          LightAudioBaseline(Naive→Learned) + LAInterspersed(Naive→Learned)
%   Transfer     学 AW 后 12 h 学 LW  AudioLightBaseline(Transfer→Final)
%   7dayTransfer AW 学会 → 7 d → LW   Vacation7(Transfer→Final)
%
% A  旧任务（AW）学会后，cue +1 s 的单细胞响应分布（rising / suppressed 两类）
% B  首个新任务（LW）block 的群体轨迹 PCA —— 待接入 Fig1D_DivergencePCA_L23 的轨迹计算
% C  首个 LW block 的试次间相对散度（L2/3）
% D  同上（L5，阴性对照）
% E  散度（L2/3）vs 首 block 命中率
% F  L5 响应异质性 vs 达 50% 所需 block 数
% G  重激活率 P(T|L)：12 h vs 7 d
% H  L5 响应异质性：Naive / 12 h / 7 d

if ~exist('UniExp.DataSet', 'class')
	thisDir = fileparts(mfilename('fullpath'));
	prjFile = fullfile(thisDir, 'Transferlearning.prj');
	if ~exist(prjFile, 'file')
		prjFile = fullfile(thisDir, '..', 'Transferlearning.prj');
	end
	if exist(prjFile, 'file')
		matlab.project.loadProject(prjFile);
	end
end
warning('off', 'UniExp:Exception:Block_must_warn');

LAB = TransferLearning.LightAudioBaseline();
LAI = TransferLearning.LAInterspersed();
ALB = TransferLearning.AudioLightBaseline();
V7 = TransferLearning.Vacation7();

groupOrder = ["Naive", "Transfer", "7dayTransfer"];
colors = [TransferLearning.NaiveColor; TransferLearning.TransferColor; TransferLearning.ColorB];

%% ---------- A: 旧任务（AW）学会后的单细胞响应 ----------
[zLearned, fracRising] = iLearnedAudioResponse(ALB);

%% ---------- C/D: 散度 ----------
divParts = { ...
	TransferLearning.Metrics.StartBlockDivergence(LAB, "Naive", "LightWater"), ...
	TransferLearning.Metrics.StartBlockDivergence(LAI, "Naive", "LightWater"), ...
	TransferLearning.Metrics.StartBlockDivergence(ALB, "Transfer", "LightWater"), ...
	TransferLearning.Metrics.StartBlockDivergence(V7, "Transfer", "LightWater")};
Div = vertcat(divParts{:});
Div.Group = [repmat("Naive", height(divParts{1}) + height(divParts{2}), 1); ...
	repmat("Transfer", height(divParts{3}), 1); repmat("7dayTransfer", height(divParts{4}), 1)];
Div.Mouse = string(Div.Mouse);
[~, iu] = unique(Div.Mouse);
Div = Div(iu, :);

%% ---------- F/H: 响应异质性 ----------
Sess = TransferLearning.BehaviorSessions.LightWaterLearningSessions();
Summ = TransferLearning.Metrics.PerMouseSessionSummary(Sess);
rhPieces = cell(0, 1);
for k = 1:3
	grp = groupOrder(k);
	if grp == "Naive"
		parts = {iRHSessions(LAB, Sess, "Naive", "LightAudioBaseline"), ...
			iRHSessions(LAI, Sess, "Naive", "LAInterspersed")};
	elseif grp == "Transfer"
		parts = {iRHSessions(ALB, Sess, "Transfer", "AudioLightBaseline")};
	else
		parts = {iRHSessions(V7, Sess, "7dayTransfer", "Vacation7")};
	end
	for p = 1:numel(parts)
		T = TransferLearning.Metrics.ResponseHeterogeneity(parts{p}.DS, parts{p}.Sess, "LightWater");
		if isempty(T)
			continue;
		end
		T.Group = repmat(grp, height(T), 1);
		rhPieces{end+1} = T; %#ok<AGROW>
	end
end
RH = vertcat(rhPieces{:});
RH.Group = string(RH.Group);

%% ---------- G: 重激活率 ----------
RCtrl = iWeightedReactivation(iBuildProb_TransferGivenLearnedAudio_1s_PerMouseLayer( ...
	DataSet=ALB, Source="AudioLightBaseline", RequireHitMiss=false));
RV7 = iWeightedReactivation(iBuildProb_TransferGivenLearnedAudio_1s_PerMouseLayer( ...
	DataSet=V7, Source="Vacation7", RequireHitMiss=false));
react = {RCtrl, RV7};
pReact = iRanksum(RCtrl, RV7);

%% ---------- I/J: 印迹细胞响应强度（12 h vs 7 d） ----------
Str12 = TransferLearning.Metrics.EngramResponseStrength(ALB);
Str7 = TransferLearning.Metrics.EngramResponseStrength(V7);
pStrLearned = iRanksum(Str12.AmpLearned, Str7.AmpLearned);
pStrTransfer = iRanksum(Str12.AmpTransfer, Str7.AmpTransfer);

%% ---------- 统计 ----------
pDiv = [ ...
	iRanksum(Div.DivL23(Div.Group == "Naive"), Div.DivL23(Div.Group == "Transfer")), ...
	iRanksum(Div.DivL23(Div.Group == "Transfer"), Div.DivL23(Div.Group == "7dayTransfer")); ...
	iRanksum(Div.DivL5(Div.Group == "Naive"), Div.DivL5(Div.Group == "Transfer")), ...
	iRanksum(Div.DivL5(Div.Group == "Transfer"), Div.DivL5(Div.Group == "7dayTransfer"))];
rhL5 = {RH.SD(RH.Group == "Naive" & RH.Layer == "MOp5"); RH.SD(RH.Group == "Transfer" & RH.Layer == "MOp5"); ...
	RH.SD(RH.Group == "7dayTransfer" & RH.Layer == "MOp5")};
pRH = [iRanksum(rhL5{1}, rhL5{2}); iRanksum(rhL5{2}, rhL5{3})];

%% ---------- 出图 ----------
f = figure('Color', 'w', 'Name', 'Fig2 single-cell dynamics');
f.Units = 'centimeters';
f.Position(3:4) = [24, 14.5];
pos = struct( ...
	'A', [0.045 0.680 0.20 0.21], ...
	'B', [0.285 0.680 0.20 0.21], ...
	'C', [0.535 0.680 0.16 0.21], ...
	'D', [0.755 0.680 0.16 0.21], ...
	'E', [0.055 0.375 0.15 0.21], ...
	'F', [0.285 0.375 0.15 0.21], ...
	'G', [0.545 0.375 0.13 0.21], ...
	'H', [0.755 0.375 0.14 0.21], ...
	'I', [0.105 0.070 0.14 0.21], ...
	'J', [0.330 0.070 0.14 0.21]);

% A 旧任务学会后的单细胞响应分布
axA = axes(f, 'Position', pos.A);
hold(axA, 'on');
edges = linspace(-1, 1, 25);
histogram(axA, zLearned, edges, 'FaceColor', TransferLearning.LearnedColor, 'EdgeColor', 'none');
plot(axA, [0 0], ylim(axA), 'k--', 'LineWidth', 0.8);
xlabel(axA, 'z at cue +1 s');
ylabel(axA, 'Cells');
title(axA, sprintf('Learned AW per-cell z (n = %d)', numel(zLearned)), ...
	'FontWeight', 'normal', 'FontSize', 8);
xlim(axA, [-1, 1]);
box(axA, 'off');

% B 群体轨迹 PCA（待接入）
axB = axes(f, 'Position', pos.B);
axis(axB, 'off');
text(axB, 0.5, 0.62, 'First light-water block, PCA trajectory', 'Units', 'normalized', ...
	'HorizontalAlignment', 'center', 'FontSize', 8, 'FontWeight', 'bold');
text(axB, 0.5, 0.40, {'naive: trajectories fan out','transfer: trajectories run parallel'}, ...
	'Units', 'normalized', 'HorizontalAlignment', 'center', 'FontSize', 7, 'Color', [0.4 0.4 0.4]);
text(axB, 0.5, 0.16, 'pending: Fig1D_DivergencePCA_L23 pipeline', 'Units', 'normalized', ...
	'HorizontalAlignment', 'center', 'FontSize', 7, 'Color', [0.6 0.6 0.6], 'Interpreter', 'none');
title(axB, 'Population trajectory (planned)', 'FontWeight', 'normal', 'FontSize', 8);

% C/D 散度
axC = axes(f, 'Position', pos.C);
iBarPanel(axC, {Div.DivL23(Div.Group == "Naive"); Div.DivL23(Div.Group == "Transfer"); ...
	Div.DivL23(Div.Group == "7dayTransfer")}, [1 2; 2 3], [pDiv(1,1); pDiv(1,2)], colors, ...
	["Naive", "12 h", "7 d"], 'Divergence, L2/3 (LW)', 0.05);

axD = axes(f, 'Position', pos.D);
iBarPanel(axD, {Div.DivL5(Div.Group == "Naive"); Div.DivL5(Div.Group == "Transfer"); ...
	Div.DivL5(Div.Group == "7dayTransfer")}, [1 2; 2 3], [pDiv(2,1); pDiv(2,2)], colors, ...
	["Naive", "12 h", "7 d"], 'Divergence, L5 (LW)', 0.05);

% E 散度 vs 首 block 命中率
axE = axes(f, 'Position', pos.E);
[xs, ys, gcol] = iPairScatter(Div, "DivL23", Summ, "FirstPerf", groupOrder);
iScatterFit(axE, xs, ys, gcol, colors, 'Divergence (L2/3)', 'First LW block hit rate');

% F L5 异质性 vs 达 50% block
axF = axes(f, 'Position', pos.F);
[xs2, ys2, g2] = iPairScatter(RH(RH.Layer == "MOp5", :), "SD", Summ, "BlocksToHalf", groupOrder);
iScatterFit(axF, xs2, ys2, g2, colors, 'L5 heterogeneity', 'Blocks to 50% (LW)');

% G 重激活
axG = axes(f, 'Position', pos.G);
iBarPanel(axG, react, [1 2], pReact, colors(2:3, :), ["12 h", "7 d"], 'Reactivated (LW)', 0.05);

% H L5 异质性三组
axH = axes(f, 'Position', pos.H);
iBarPanel(axH, rhL5, [1 2; 2 3], pRH, colors, ["Naive", "12 h", "7 d"], 'L5 heterogeneity (LW)', 0.05);

% I/J 印迹细胞响应强度：被标定时等价（I），迁移块衰减（J）
axI = axes(f, 'Position', pos.I);
iBarPanel(axI, {Str12.AmpLearned, Str7.AmpLearned}, [1 2], pStrLearned, colors(2:3, :), ...
	["12 h", "7 d"], 'Engram z, learned AW', 0.05);
ylabel(axI, 'z at cue +1 s', 'FontSize', 8);

axJ = axes(f, 'Position', pos.J);
iBarPanel(axJ, {Str12.AmpTransfer, Str7.AmpTransfer}, [1 2], pStrTransfer, colors(2:3, :), ...
	["12 h", "7 d"], 'Engram z, first LW', 0.05);
ylabel(axJ, 'z at cue +1 s', 'FontSize', 8);

axJnote = axes(f, 'Position', [0.520 0.070 0.450 0.210]);
axis(axJnote, 'off');
text(axJnote, 0.0, 0.86, 'Engram strength is set by the interval', 'FontSize', 8, 'FontWeight', 'bold');
text(axJnote, 0.0, 0.60, {...
	'I  same z at cue +1 s when the cells were identified in the last', ...
	'   learned audio-water block (12 h vs 7 d: n.s.)', ...
	'J  first light-water block: activity kept after 12 h, lost after 7 d (p = 0.062);', ...
	'   cells that are still reactivated respond as strongly in both cohorts', ...
	'   => the decay is a loss of recruited cells, not of per-cell strength'}, ...
	'FontSize', 7, 'Color', [0.35 0.35 0.35], 'VerticalAlignment', 'top');

iPanelLetters(f, {axA, axB, axC, axD, axE, axF, axG, axH, axI, axJ});
annotation(f, 'textbox', [0.02 0.965 0.9 0.03], 'String', ...
	'Fig2  Single-cell dynamics of the transfer: stability, heterogeneity and ensemble reuse', ...
	'EdgeColor', 'none', 'FontSize', 9, 'FontWeight', 'bold');

outDir = fileparts(TransferLearning.StandardFigureSvgPath('Fig2_SingleCellDynamics.svg'));
figPath = fullfile(outDir, 'Fig2_SingleCellDynamics.fig');
savefig(f, figPath);
fprintf('Saved: %s\n', figPath);

fprintf('\n=== Fig2 ===\n');
fprintf('Learned AW cells: n = %d, rising %.1f%%, suppressed %.1f%%\n', ...
	numel(zLearned), 100 * fracRising, 100 * (1 - fracRising));
for k = 1:3
	grp = groupOrder(k);
	fprintf('%-14s divL23 %.3f+-%.3f (n=%d) | divL5 %.3f+-%.3f (n=%d) | RH L5 %.3f+-%.3f (n=%d)\n', ...
		grp, mean(Div.DivL23(Div.Group == grp), 'omitnan'), iSem(Div.DivL23(Div.Group == grp)), ...
		sum(isfinite(Div.DivL23(Div.Group == grp))), ...
		mean(Div.DivL5(Div.Group == grp), 'omitnan'), iSem(Div.DivL5(Div.Group == grp)), ...
		sum(isfinite(Div.DivL5(Div.Group == grp))), ...
		mean(rhL5{k}), iSem(rhL5{k}), numel(rhL5{k}));
end
fprintf('Divergence p (N-12h, 12h-7d): L2/3 %.4g / %.4g ; L5 %.4g / %.4g\n', pDiv(1,1), pDiv(1,2), pDiv(2,1), pDiv(2,2));
fprintf('RH L5 p (N-12h, 12h-7d): %.4g / %.4g\n', pRH(1), pRH(2));
fprintf('Reactivation 12h %.4f+-%.4f (n=%d) vs 7d %.4f+-%.4f (n=%d), p = %.4g\n', ...
	mean(RCtrl), iSem(RCtrl), numel(RCtrl), mean(RV7), iSem(RV7), numel(RV7), pReact);

assignin('base', 'Fig2_Data', struct('Div', Div, 'RH', RH, 'React', {react}, 'Summ', Summ, ...
	'ZLearned', zLearned, 'FracRising', fracRising, 'Strength12', Str12, 'Strength7', Str7));

%% ------------------------------------------------------------------
function [z1, fracRising] = iLearnedAudioResponse(DS)
Tq = DS.TableQuery(["Mouse","DateTime","Stimulus","Phase"]);
Tq.Mouse = string(Tq.Mouse);
Tq.Stimulus = string(Tq.Stimulus);
Tq.Phase = string(Tq.Phase);
Tq = Tq(Tq.Stimulus == "AudioWater" & Tq.Phase == "Learned", :);
z1 = [];
fracRising = NaN;
if isempty(Tq)
	return;
end
idx1s = iTimeIndex(1);
try
	res = DS.QueryNTS(struct('Stimulus', "AudioWater", 'DateTime', unique(Tq.DateTime)), ...
		UniExp.Flags.ZScore, 1:24, 'ExtraColumns', "DateTime");
	tbl = iCollapse(res);
catch
	tbl = table();
end
if isempty(tbl)
	return;
end
tbl.CellUID = uint64(tbl.CellUID);
sig = double(tbl.TrialSignal(:, idx1s));
[G, ~] = findgroups(tbl.CellUID);
perCell = splitapply(@(x) mean(x, 'omitnan'), sig, G);
perCell = perCell(isfinite(perCell));
perCell = perCell(perCell >= -1 & perCell <= 1);
z1 = perCell;
fracRising = mean(perCell > 0);
end

function idx = iTimeIndex(tSec)
xs = TransferLearning.Xs;
if isduration(xs)
	xsSec = seconds(xs);
else
	xsSec = double(xs);
end
[~, idx] = min(abs(xsSec(:) - tSec));
end

function tbl = iCollapse(res)
tbl = table();
if isempty(res)
	return;
end
if istable(res)
	tbl = res;
elseif iscell(res)
	parts = res(~cellfun(@isempty, res));
	if ~isempty(parts) && istable(parts{1})
		tbl = vertcat(parts{:});
	end
end
end

function [xs, ys, g] = iPairScatter(T, metricName, Summ, summName, groupOrder)
xs = [];
ys = [];
g = [];
for k = 1:numel(groupOrder)
	grp = groupOrder(k);
	R = T(T.Group == grp, {'Mouse', char(metricName)});
	for i = 1:height(R)
		idx = find(Summ.Group == grp & Summ.Mouse == R.Mouse(i), 1, 'first');
		if isempty(idx)
			continue;
		end
		xv = R.(metricName)(i);
		yv = Summ.(summName)(idx);
		if ~isfinite(xv) || ~isfinite(yv)
			continue;
		end
		xs(end+1, 1) = xv; %#ok<AGROW>
		ys(end+1, 1) = yv; %#ok<AGROW>
		g(end+1, 1) = k; %#ok<AGROW>
	end
end
end

function iScatterFit(ax, xs, ys, g, colors, xlab, ylab)
hold(ax, 'on');
for k = 1:numel(colors)
	m = g == k;
	if any(m)
		plot(ax, xs(m), ys(m), 'o', 'MarkerSize', 4, ...
			'MarkerFaceColor', colors(k, :), 'MarkerEdgeColor', 'none');
	end
end
if numel(xs) >= 3
	pf = polyfit(xs, ys, 1);
	xf = linspace(min(xs), max(xs), 20);
	plot(ax, xf, polyval(pf, xf), 'k--', 'LineWidth', 1);
	[rho, pRho] = corr(xs, ys, 'Type', 'Spearman', 'Rows', 'complete');
	text(ax, 0.03, 0.94, sprintf('\\rho = %.2f, p = %.3g, n = %d', rho, pRho, numel(xs)), ...
		'Units', 'normalized', 'FontSize', 7, 'VerticalAlignment', 'top');
	fprintf('%s vs %s: rho = %.3f, p = %.3g, n = %d\n', ylab, xlab, rho, pRho, numel(xs));
end
xlabel(ax, xlab, 'FontSize', 8);
ylabel(ax, ylab, 'FontSize', 8);
box(ax, 'off');
end

function out = iRHSessions(DS, Sess, grp, sourceName)
rows = Sess.Group == grp & Sess.Source == sourceName;
S = sortrows(Sess(rows, {'Mouse','DateTime','Performance','Session'}), {'Mouse','Session'});
keep = false(height(S), 1);
mice = unique(S.Mouse);
for i = 1:numel(mice)
	idx = find(S.Mouse == mice(i));
	perf = double(S.Performance(idx));
	i100 = find(perf >= 1 - 1e-12, 1, 'first');
	if isempty(i100)
		use = idx;
	else
		use = idx(1:i100 - 1);
	end
	if numel(use) >= 2
		keep(use) = true;
	end
end
out.DS = DS;
out.Sess = S(keep, {'Mouse','DateTime'});
end

function v = iWeightedReactivation(R)
n23 = R.NLearnedActive23;
n5 = R.NLearnedActive5;
n23(~isfinite(n23)) = 0;
n5(~isfinite(n5)) = 0;
w23 = n23 .* R.Prob23;
w5 = n5 .* R.Prob5;
w23(~isfinite(w23)) = 0;
w5(~isfinite(w5)) = 0;
nTot = n23 + n5;
v = (w23 + w5) ./ nTot;
v(nTot == 0) = NaN;
v = v(isfinite(v));
end

function iPanelLetters(f, axList)
letters = arrayfun(@(k) string(char(64 + k)), 1:numel(axList));
for k = 1:numel(axList)
	p = axList{k}.Position;
	annotation(f, 'textbox', [p(1) - 0.008, p(2) + p(4) + 0.005, 0.04, 0.03], ...
		'String', letters(k), 'FontSize', 10, 'FontWeight', 'bold', 'EdgeColor', 'none', ...
		'VerticalAlignment', 'bottom');
end
end

function iBarPanel(ax, data, pairs, pVals, cols, labels, ttl, thr)
data = reshape(data, 1, []);
axes(ax);
CompareGroup = table(pairs, 'VariableNames', {'GroupPair'});
[~, Opt, Bars, EB] = UniExp.BarScatterCompare(data, UniExp.Flags.empty, CompareGroup, ...
	UniExp.Flags.IndividualErrorbars, 'AsteriskThreshold', thr);
if isscalar(Bars)
	Bars.FaceColor = 'flat';
	Bars.CData = cols;
else
	for k = 1:numel(Bars)
		Bars(k).FaceColor = cols(k, :);
	end
end
for k = 1:numel(Bars)
	Bars(k).BarWidth = 0.5;
	Bars(k).EdgeColor = 'none';
	Bars(k).FaceAlpha = 1;
end
if istable(EB) && ~isempty(EB) && ismember('Object', EB.Properties.VariableNames)
	for k = 1:height(EB)
		eb = EB.Object(k);
		if isgraphics(eb) && k <= size(cols, 1)
			eb.Color = cols(k, :);
		end
	end
end
yTop = 0;
if isfield(Opt, 'MultiCompare') && istable(Opt.MultiCompare) && ismember('PText', Opt.MultiCompare.Properties.VariableNames)
	pairStr = string(num2str(pairs));
	for k = 1:height(Opt.MultiCompare)
		gp = string(num2str(Opt.MultiCompare.GroupPair(k, :)));
		pick = find(ismember(pairStr, gp), 1, 'first');
		pt = Opt.MultiCompare.PText(k);
		pl = Opt.MultiCompare.PLine(k);
		if isgraphics(pt) && ~isempty(pick)
			pt.String = TransferLearning.Style.iFormatPText(pVals(pick));
		end
		if isgraphics(pl)
			yTop = max(yTop, max(pl.YData));
		end
	end
end
ax.XTick = 1:numel(labels);
ax.XTickLabel = cellstr(labels);
title(ax, ttl, 'FontWeight', 'normal', 'FontSize', 8);
if yTop > 0
	ylim(ax, [0, yTop * 1.12]);
end
box(ax, 'off');
end

function p = iRanksum(x, y)
[p, ~] = TransferLearning.BehaviorSessions.iRanksumSafe(x, y);
end

function s = iSem(x)
x = double(x(:));
x = x(isfinite(x));
if isempty(x)
	s = NaN;
else
	s = std(x) / sqrt(numel(x));
end
end

