% Fig2 备选面板：群体轨迹的 trial-to-trial 可靠性（参考 Neuron 2017 Fig 3 的思路）
%
% 文献：Transformation of Cortex-wide Emergent Properties during Motor Learning
%       (PMC5502752) Figure 3 "Reduced variability of cortex-wide activity"
%   A  两个阶段各自做因子分析，前 3 个因子构成的 3-D 状态空间里画随机 trial 的轨迹
%   B  5 因子空间中 trial 两两轨迹相关随学习阶段的上升
%   C  按行为相似度分箱后，活动轨迹相关依然提升 —— 排除"行为变刻板"这一替代解释
%
% 本脚本的对应版本：
%   A  12 h / 7 d 两个队列各取一例：最后一个学会的声水 block vs 首个光水 block，
%      各自做 PCA 取前 3 主成分，画若干条 trial 轨迹（黑点 = cue 前 200 ms，红点 = cue）
%   B  逐 block 的平均两两轨迹相关：最后 4 个学会声水 block → 前 3 个光水 block，
%      12 h 与 7 d 两条曲线（mean ± SEM across mice）
%   C  把 trial 对按**舔水栅格相似度**分箱（文献用杠杆轨迹相关，我们没有杠杆），
%      看每个箱内的活动轨迹相关；若学会阶段在**每个箱内**都高于迁移阶段，
%      则可靠性差异不是行为刻板化造成的
%
% 口径说明：PCA 在每个 block 内单独拟合（与文献"每个阶段单独做因子分析"一致），
% 因此不同阶段的因子轴不可直接比较，只比较"同一阶段内部的 trial 间相关"。
% 时间窗：cue −1 → +2 s；主成分数 k = 5（与文献一致）。

if ~exist('UniExp.DataSet', 'class')
	thisDir = fileparts(mfilename('fullpath'));
	prjFile = fullfile(thisDir, 'Transferlearning.prj');
	if exist(prjFile, 'file')
		matlab.project.loadProject(prjFile);
	end
end
warning('off', 'UniExp:Exception:Block_must_warn');

kFactors = 5;
nLearned = 4;      % 取最后 4 个学会声水 block
nLW = 3;           % 取前 3 个光水 block
nShow = 12;        % A 面板每格画的 trial 数
showBC = true;     % 同时展示 A/B/C 三个面板（false 则只画 A）
% A 面板的观察视角：
%   "minSpread"  在所有格子上平均意义上“trial 轨迹看起来最重叠”的视角（保守）
%   "maxSpread"  反之，最能把 trial 间差异展开的视角
%   "fixed"      固定 [-35 18]
% 注意：每格都是自己拟合的 PCA 基，所以视角不能改变“格与格之间”的差异，
% 只能改变每格内部 trial 轨迹看起来有多散。同一图内五格共用同一个视角。
viewMode = "minSpread";

xs = TransferLearning.Xs;
if isduration(xs), xsSec = seconds(xs); else, xsSec = double(xs); end
xsSec = xsSec(:);
win = (xsSec >= -1) & (xsSec <= 2);
xsWin = xsSec(win);
[~, iPre] = min(abs(xsWin - (-0.2)));

cohorts = struct( ...
	'Name', {'12 h', '7 d', 'naive'}, ...
	'DS', {TransferLearning.AudioLightBaseline(), TransferLearning.Vacation7(), TransferLearning.LightAudioBaseline()}, ...
	'Color', {TransferLearning.TransferColor, TransferLearning.ColorB, TransferLearning.NaiveColor}, ...
	'HasLearned', {true, true, false}, ...
	'LWPhase', {"", "", "Naive"});

%% ---------- 逐鼠逐 block 计算 ----------
R = struct('Cohort', {}, 'Mouse', {}, 'Block', {}, 'Stim', {}, 'NCell', {}, ...
	'Corr', {}, 'Learned', {}, 'LWIndex', {}, 'Proj', {}, 'ProjK', {}, 'Lick', {}, 'XCells', {});
for c = 1:numel(cohorts)
	DS = cohorts(c).DS;
	TP = unique(DS.TableQuery(["BlockUID","Phase"]), 'rows');
	mice = iMice(DS, cohorts(c).HasLearned);
	fprintf('%s: %d mice\n', cohorts(c).Name, numel(mice));
	for i = 1:numel(mice)
		m = mice(i);
		[TA, TL] = iTrialTables(DS, m);
		if isempty(TL), continue; end
		bL = iBlockOrder(DS, TL);
		if strlength(cohorts(c).LWPhase) > 0
			bL = bL(arrayfun(@(b) string(iBlockPhase(TP, b)) == cohorts(c).LWPhase, bL));
		end
		if isempty(bL), continue; end
		bL = bL(1:min(nLW, numel(bL)));
		bA = [];
		if cohorts(c).HasLearned && ~isempty(TA)
			bA = iBlockOrder(DS, TA);
			tLW1 = iBlockTime(DS, bL(1));
			bA = bA(arrayfun(@(b) iBlockTime(DS, b) < tLW1, bA));
			bA = bA(max(1, end - nLearned + 1):end);
		end
		for j = 1:numel(bA)
			s = iBlockStat(DS, TA, bA(j), win, kFactors, xsWin);
			if isempty(s), continue; end
			R(end+1) = iRow(cohorts(c).Name, m, bA(j), "AW", s, true, j, 0); %#ok<SAGROW>
		end
		for j = 1:numel(bL)
			s = iBlockStat(DS, TL, bL(j), win, kFactors, xsWin);
			if isempty(s), continue; end
			R(end+1) = iRow(cohorts(c).Name, m, bL(j), "LW", s, false, 0, j); %#ok<SAGROW>
		end
	end
end

if isempty(R)
	error('没有可用的 block 数据');
end

%% ---------- B：逐 block 曲线 ----------
% x 轴：学会 block 记 1..nLearned，光水 block 记 nLearned+1..nLearned+nLW
stageMax = nLearned + nLW;
corrMat = nan(numel(cohorts), 0);
mu = cell(1, numel(cohorts));
se = cell(1, numel(cohorts));
for c = 1:numel(cohorts)
	C = R(string({R.Cohort}) == cohorts(c).Name);
	mice = unique(string({C.Mouse}), 'stable');
	M = nan(numel(mice), stageMax);
	for i = 1:numel(mice)
		Ci = C(string({C.Mouse}) == mice(i));
		% 显式映射：学会 block 按 BlockUID 从小到大排
		La = sort(unique([Ci([Ci.Learned]).Block]));
		for j = 1:numel(Ci)
			if Ci(j).Learned
				pos = find(La == Ci(j).Block, 1);
				if isempty(pos), continue; end
				M(i, nLearned - numel(La) + pos) = Ci(j).Corr;
			else
				M(i, nLearned + Ci(j).LWIndex) = Ci(j).Corr;
			end
		end
	end
	mu{c} = mean(M, 1, 'omitnan');
	se{c} = std(M, 0, 1, 'omitnan') ./ sqrt(sum(isfinite(M), 1));
	se{c}(~isfinite(se{c})) = 0;
end

% 统计：最后 2 个学会 block 的平均 vs 首个光水 block（逐鼠配对）
pairStat = struct('Cohort', {}, 'Learned', {}, 'LW', {}, 'P', {});
for c = 1:numel(cohorts)
	a = []; b = [];
	mice = unique(string({R(string({R.Cohort}) == cohorts(c).Name).Mouse}), 'stable');
	for i = 1:numel(mice)
		Ci = R(string({R.Cohort}) == cohorts(c).Name & string({R.Mouse}) == mice(i));
		la = Ci([Ci.Learned]);
		lw = Ci(~[Ci.Learned]);
		if isempty(la) || isempty(lw), continue; end
		laCorr = [la.Corr];
		a(end+1) = mean(laCorr(max(1, end - 1):end)); %#ok<SAGROW>
		b(end+1) = lw(1).Corr; %#ok<SAGROW>
	end
	if numel(a) >= 2
		pp = signrank(a, b);
	else
		pp = NaN;
	end
	pairStat(end+1) = struct('Cohort', cohorts(c).Name, 'Learned', mean(a), 'LW', mean(b), 'P', pp); %#ok<SAGROW>
end

%% ---------- A：示例鼠的 3-D 轨迹 ----------
exMouse = cell(1, numel(cohorts));
for c = 1:numel(cohorts)
	C = R(string({R.Cohort}) == cohorts(c).Name);
	mice = unique(string({C.Mouse}), 'stable');
	best = -1; pick = 1;
	for i = 1:numel(mice)
		nc = max([C(string({C.Mouse}) == mice(i)).NCell]);
		if nc > best, best = nc; pick = i; end
	end
	exMouse{c} = mice(pick);
end

% 面板列表：有学会阶段的队列画 2 格（learned / first LW），naive 只画 first LW
panelCohort = zeros(1, 0);
panelStage = {};
panelTag = {};
for c = 1:numel(cohorts)
	if cohorts(c).HasLearned
		panelCohort(end+1) = c; %#ok<SAGROW>
		panelStage{end+1} = 'L'; %#ok<SAGROW>
		panelTag{end+1} = {cohorts(c).Name, 'learned AW'}; %#ok<SAGROW>
	end
	panelCohort(end+1) = c; %#ok<SAGROW>
	panelStage{end+1} = 'W1'; %#ok<SAGROW>
	panelTag{end+1} = {cohorts(c).Name, 'first LW'}; %#ok<SAGROW>
end

%% ---------- 出图 ----------
f = figure('Color', 'w', 'Name', 'Population trajectory reliability');
f.Units = 'centimeters';
if showBC
	f.Position(3:4) = [26, 13.5];
else
	f.Position(3:4) = [26, 6.8];
end

% A: 动态多格 3-D 轨迹
nP = numel(panelCohort);
if showBC
	wA = 0.150; gapA = 0.018;
	x0A = (1 - (nP * wA + (nP - 1) * gapA)) / 2;
	y0A = 0.565; hA = 0.350;
else
	wA = 0.170; gapA = 0.020;
	x0A = (1 - (nP * wA + (nP - 1) * gapA)) / 2;
	y0A = 0.140; hA = 0.700;
end
axA = gobjects(1, nP);
Pcell = cell(1, nP);
blockCell = cell(1, nP);
for k = 1:nP
	c = panelCohort(k);
	C = R(string({R.Cohort}) == cohorts(c).Name & string({R.Mouse}) == exMouse{c});
	La = sort(unique([C([C.Learned]).Block]));
	Lw = sort(unique([C(~[C.Learned]).Block]));
	if panelStage{k} == 'L'
		pick = La(end);
	else
		pick = Lw(1);
	end
	i = find([C.Block] == pick, 1, 'first');
	if isempty(i)
		Pcell{k} = [];
		continue;
	end
	Pcell{k} = iNormalize(C(i).Proj, iPre);
	blockCell{k} = C(i);
end

% 五格共用一个视角（由所有格子的 trial 轨迹共同决定）
if viewMode == "fixed"
	azView = -35; elView = 18;
else
	[azView, elView] = iPickView(Pcell, char(viewMode));
end
fprintf('A panel view: az = %.0f, el = %.0f (%s)\n', azView, elView, viewMode);

for k = 1:nP
	axA(k) = axes(f, 'Position', [x0A + (k - 1) * (wA + gapA), y0A, wA, hA]);
	if isempty(Pcell{k})
		axis(axA(k), 'off');
		continue;
	end
	iDrawTraj(axA(k), Pcell{k}, cohorts(panelCohort(k)).Color, iPre, nShow, azView, elView);
	title(axA(k), panelTag{k}, 'FontWeight', 'normal', 'FontSize', 7.5);
end

% B: 逐 block 的轨迹相关
if showBC
axB = axes(f, 'Position', [0.085 0.070 0.330 0.370]);
hold(axB, 'on');
for c = 1:numel(cohorts)
	xb = (1:stageMax).';
	plot(axB, xb, mu{c}(:), '-', 'Color', cohorts(c).Color, 'LineWidth', 1);
	errorbar(axB, xb, mu{c}(:), se{c}(:), 'o', 'Color', cohorts(c).Color, ...
		'MarkerFaceColor', cohorts(c).Color, 'MarkerSize', 3, 'LineWidth', 0.8, 'CapSize', 2);
end
xline(axB, nLearned + 0.5, '--', 'Color', [0.5 0.5 0.5]);
xlim(axB, [0.5, stageMax + 0.5]);
xticks(axB, 1:stageMax);
xticklabels(axB, [compose('L%d', 1:nLearned), compose('W%d', 1:nLW)]);
xlabel(axB, 'Block');
ylabel(axB, 'Trial-pair trajectory correlation');
title(axB, 'Reliability across blocks', 'FontWeight', 'normal', 'FontSize', 8);
text(axB, nLearned - 0.4, 0.98, 'learned AW', 'Units', 'normalized', 'FontSize', 6, ...
	'HorizontalAlignment', 'right', 'Color', [0.4 0.4 0.4]);
text(axB, nLearned + 0.6, 0.98, 'light water', 'Units', 'normalized', 'FontSize', 6, ...
	'HorizontalAlignment', 'left', 'Color', [0.4 0.4 0.4]);
proxy = gobjects(1, numel(cohorts));
for c = 1:numel(cohorts)
	proxy(c) = plot(axB, nan, nan, '-o', 'Color', cohorts(c).Color, ...
		'MarkerFaceColor', cohorts(c).Color, 'MarkerSize', 3);
end
lg = legend(axB, proxy, {cohorts.Name}, 'Location', 'northwest');
lg.Box = 'off';
box(axB, 'off');
end

% C: 按行为相似度分箱
nBin = 3;
binLearned = cell(1, numel(cohorts));
binLW = cell(1, numel(cohorts));
if showBC
axC = axes(f, 'Position', [0.560 0.070 0.330 0.370]);
hold(axC, 'on');
end
for c = 1:numel(cohorts)
	C = R(string({R.Cohort}) == cohorts(c).Name);
	mice = unique(string({C.Mouse}), 'stable');
	Bl = nan(numel(mice), nBin);
	Bw = nan(numel(mice), nBin);
	for i = 1:numel(mice)
		Ci = C(string({C.Mouse}) == mice(i));
		% 每个阶段只用单个 block：不同 block 各自拟合的 PCA 基不同，
		% 把两个 block 的投影混在一起算 trial 间相关是无效的
		la = Ci([Ci.Learned]);
		lw = Ci(~[Ci.Learned]);
		if isempty(lw), continue; end
		if ~isempty(la)
			[s1, ~] = iBinnedCorr(la(end), nBin);
			Bl(i, :) = s1;
		end
		[s1, ~] = iBinnedCorr(lw(1), nBin);
		Bw(i, :) = s1;
	end
	mb = mean(Bl, 1, 'omitnan');
	eb = std(Bl, 0, 1, 'omitnan') ./ sqrt(sum(isfinite(Bl), 1));
	mw = mean(Bw, 1, 'omitnan');
	ew = std(Bw, 0, 1, 'omitnan') ./ sqrt(sum(isfinite(Bw), 1));
	binLearned{c} = Bl;
	binLW{c} = Bw;
	if showBC
	if any(isfinite(mb))
		plot(axC, 1:nBin, mb, '-o', 'Color', cohorts(c).Color, 'MarkerFaceColor', cohorts(c).Color, 'MarkerSize', 4);
		errorbar(axC, 1:nBin, mb, eb, 'Color', cohorts(c).Color, 'LineWidth', 0.8, 'CapSize', 2);
	end
	plot(axC, 1:nBin, mw, '--o', 'Color', cohorts(c).Color, 'MarkerSize', 4);
	errorbar(axC, 1:nBin, mw, ew, 'Color', cohorts(c).Color, 'LineWidth', 0.6, 'CapSize', 2);
	end
end
if showBC
xlim(axC, [0.6, nBin + 0.4]);
xticks(axC, 1:nBin);
xticklabels(axC, {'low', 'mid', 'high'});
xlabel(axC, 'Lick-trace similarity');
ylabel(axC, 'Trajectory correlation');
title(axC, 'dashed = first LW, solid = learned', 'FontWeight', 'normal', 'FontSize', 6);
box(axC, 'off');
end

annotation(f, 'textbox', [0.02 0.955 0.95 0.040], 'String', ...
	'Trial-to-trial reliability of population trajectories (cf. Neuron 2017 Fig 3)', ...
	'EdgeColor', 'none', 'FontSize', 9, 'FontWeight', 'bold');
if showBC
	annotation(f, 'textbox', [0.02 0.495 0.95 0.030], 'String', ...
		['A: first 3 PCs fitted within each block (axes differ between panels); thick = mean trajectory, black dot = cue, red = cue+1 s.   ' ...
		'B: mean pairwise trajectory correlation (5 PCs).   C: trial pairs binned by lick-trace similarity.'], ...
		'EdgeColor', 'none', 'FontSize', 6.5, 'Color', [0.4 0.4 0.4]);
else
	annotation(f, 'textbox', [0.02 0.055 0.95 0.045], 'String', ...
		['Trial trajectories in the space of the first 3 PCs, fitted within each block (axes differ between panels). ' ...
		'Thick line = mean trajectory; black dot = cue; red circle = cue + 1 s.'], ...
		'EdgeColor', 'none', 'FontSize', 7, 'Color', [0.4 0.4 0.4]);
end

outDir = fileparts(mfilename('fullpath'));
savefig(f, fullfile(outDir, 'Fig2_TrajectoryReliability.fig'));
fprintf('Saved: %s\n', fullfile(outDir, 'Fig2_TrajectoryReliability.fig'));

%% ---------- 控制台输出 ----------
fprintf('\n=== trajectory reliability ===\n');
for c = 1:numel(cohorts)
	P = pairStat(c);
	fprintf('%s: learned(last2) %.3f vs first LW %.3f, paired signrank p = %.4g\n', ...
		P.Cohort, P.Learned, P.LW, P.P);
end
tbl = struct2table(pairStat);
disp(tbl);
for c = 1:numel(cohorts)
	Bl = binLearned{c}; Bw = binLW{c};
	fprintf('%s bin check (n = %d mice): learned %s | first LW %s\n', cohorts(c).Name, size(Bl, 1), ...
		mat2str(round(mean(Bl, 1, 'omitnan'), 3)), mat2str(round(mean(Bw, 1, 'omitnan'), 3)));
	for b = 1:nBin
		if size(Bl, 1) >= 2 && any(isfinite(Bl(:, b))) && any(isfinite(Bw(:, b)))
			fprintf('   bin %d: diff = %.3f, paired p = %.4g\n', b, ...
				mean(Bl(:, b) - Bw(:, b), 'omitnan'), signrank(Bl(:, b), Bw(:, b)));
		end
	end
end
assignin('base', 'TrajReliability_Data', struct('Blocks', R, 'PairStat', tbl, 'Win', win, ...
	'BinLearned', {binLearned}, 'BinLW', {binLW}));

% 首个光水 block 的三队列逐箱比较
fprintf('\nfirst-LW block, per bin (ranksum, unpaired):\n');
for b = 1:nBin
	L1 = binLW{1}(:, b); L2 = binLW{2}(:, b); L3 = binLW{3}(:, b);
	fprintf('  bin %d: 12 h %.3f | 7 d %.3f | naive %.3f  -> 12h vs naive p = %.4g ; 7d vs naive p = %.4g ; 12h vs 7d p = %.4g\n', ...
		b, mean(L1, 'omitnan'), mean(L2, 'omitnan'), mean(L3, 'omitnan'), ...
		ranksum(L1, L3), ranksum(L2, L3), ranksum(L1, L2));
end

%% ==================================================================
function mice = iMice(DS, needLearned)
Ta = DS.TableQuery(["Mouse","Stimulus"], Stimulus="AudioWater");
Tl = DS.TableQuery(["Mouse","Stimulus"], Stimulus="LightWater");
if needLearned
	mice = intersect(unique(string(Ta.Mouse)), unique(string(Tl.Mouse)));
else
	mice = unique(string(Tl.Mouse));
end
mice = sort(mice);
end

function ph = iBlockPhase(TP, blockUID)
% TP: unique(TableQuery(["BlockUID","Phase"]), 'rows')
r = double(TP.BlockUID) == double(blockUID);
if ~any(r)
	ph = "";
else
	ph = string(TP.Phase(find(r, 1, 'first')));
end
end

function [TA, TL] = iTrialTables(DS, mouse)
TA = TransferLearning.QueryZScoreNts(DS, char(mouse), 'AudioWater');
TL = TransferLearning.QueryZScoreNts(DS, char(mouse), 'LightWater');
end

function b = iBlockOrder(DS, T)
b = unique(T.BlockUID);
tm = arrayfun(@(x) iBlockTime(DS, x), b);
[~, ord] = sort(tm);
b = b(ord);
end

function t = iBlockTime(DS, blockUID)
B = DS.Blocks;
r = B.BlockUID == blockUID;
if ~any(r)
	t = NaT;
else
	t = B.DateTime(find(r, 1, 'first'));
end
end

function s = iBlockStat(DS, T, blk, win, k, xsWin) %#ok<INUSD>
X = TransferLearning.BuildTrialMatrix(T(T.BlockUID == blk, :), unique(T.CellUID));
if isempty(X), s = []; return; end
X = X(:, :, win);
[nTr, nCell, nT] = size(X);
if nTr < 5, s = []; return; end
Xr = reshape(permute(X, [1 3 2]), nTr * nT, nCell);
Xc = Xr - mean(Xr, 1);
[~, ~, V] = svd(Xc, 'econ');
k = min(k, size(V, 2));
P = reshape(Xc * V(:, 1:k), nTr, nT * k);
C = corr(P.');
C(logical(eye(nTr))) = NaN;
tu = unique(T.TrialUID(T.BlockUID == blk));
% 同一 block 的舔水栅格（与 X 的行同序）
Tr = DS.Trials;
sel = Tr.BlockUID == blk;
tagsAll = Tr.ResampledTags(sel);
tuidAll = uint64(Tr.TrialUID(sel));
[ok, loc] = ismember(uint64(tu), tuidAll);
Lick = [];
if all(ok) && ~isempty(tagsAll)
	tags = tagsAll(loc);
	[Lraw, ~, tTag] = TransferLearning.LickTrace(tags, Window=[-3 3]);
	Lick = Lraw(:, tTag >= -1 & tTag <= 2);
end
s = struct('Corr', mean(C(:), 'omitnan'), 'NCell', nCell, ...
	'Proj', reshape(Xc * V(:, 1:min(3, size(V, 2))), nTr, [], min(3, size(V, 2))), ...
	'ProjK', P, ...
	'Lick', Lick, 'Trials', tu);
end

function r = iRow(cohort, mouse, blk, stim, s, learned, lidx, lwidx)
r = struct('Cohort', string(cohort), 'Mouse', string(mouse), 'Block', blk, ...
	'Stim', string(stim), 'NCell', s.NCell, 'Corr', s.Corr, ...
	'Learned', logical(learned), 'LWIndex', lwidx, 'Proj', s.Proj, ...
	'ProjK', s.ProjK, 'Lick', s.Lick, 'XCells', []);
if learned, r.LWIndex = lidx; end
end

function Pn = iNormalize(P, iFrom)
% 每个主成分除以自己的 SD（三轴可比），并裁掉 cue 之前的基线段
sd = std(reshape(P, [], size(P, 3)), 0, 1);
sd(sd == 0) = 1;
Pn = P ./ reshape(sd, 1, 1, []);
iFrom = max(iFrom, 1);
Pn = Pn(:, iFrom:end, :);
end

function [az, el] = iPickView(Pcell, mode)
% 在方位角/仰角网格上搜索一个"五格共用"的视角。
% 打分 = 各格内 trial 轨迹两两距离 / 该格投影后的整体尺度（归一化散度），
% 避免"沿最大方差轴看过去把一维压没"这种退化解也可以让距离变小。
%   minSpread -> 取最小（trial 轨迹相对最相似/最重叠）
%   maxSpread -> 取最大（相对最分散）
azGrid = -180:15:165;
elGrid = -30:10:80;
az = -35; el = 18;
if strcmp(mode, 'minSpread'), best = Inf; else, best = -Inf; end
for a = azGrid
	for e = elGrid
		T = viewmtx(a, e);
		s = 0; n = 0;
		for k = 1:numel(Pcell)
			Pn = Pcell{k};
			if isempty(Pn), continue; end
			nTr = size(Pn, 1);
			V = reshape(Pn, [], 3);
			Vt = [V, ones(size(V, 1), 1)] * T;
			Xp = reshape(Vt(:, 1:2), nTr, []);
			% 以均值轨迹为参考：trial 到均值的偏离 / 均值轨迹自身的跨度
			dev = mean(pdist(Xp));
			scale = norm(mean(Xp, 1) - Xp(1, :));   % 均值轨迹的 2-D 弧长近似
			if scale < eps, continue; end
			s = s + dev / scale;
			n = n + 1;
		end
		if n == 0, continue; end
		s = s / n;
		if strcmp(mode, 'minSpread')
			if s < best, best = s; az = a; el = e; end
		else
			if s > best, best = s; az = a; el = e; end
		end
	end
end
end

function iDrawTraj(ax, Pn, col, iPre, nShow, az, el) %#ok<INUSD>
% Pn: 已归一化的 nTrials x nTime x 3（见 iNormalize）
hold(ax, 'on');
nTr = size(Pn, 1);
sel = round(linspace(1, nTr, min(nShow, nTr)));
for i = sel
	traj = reshape(Pn(i, :, :), [], 3);
	traj = movmean(traj, 5, 1);
	plot3(ax, traj(:, 1), traj(:, 2), traj(:, 3), '-', 'Color', [col 0.45], 'LineWidth', 0.5);
end
% trial 平均轨迹（粗）
mt = reshape(mean(Pn, 1), [], 3);
mt = movmean(mt, 3, 1);
plot3(ax, mt(:, 1), mt(:, 2), mt(:, 3), '-', 'Color', col * 0.60, 'LineWidth', 1.8);
plot3(ax, mt(1, 1), mt(1, 2), mt(1, 3), '.', 'Color', [0.1 0.1 0.1], 'MarkerSize', 7);
plot3(ax, mt(end, 1), mt(end, 2), mt(end, 3), 'o', 'Color', [0.85 0.2 0.2], 'MarkerSize', 4, 'LineWidth', 0.8);
set(ax, 'FontSize', 6);
view(ax, [az, el]);
% 每个轴按自身数据的 2-98 分位定范围：用统一 ±lim 会让空腔太多、轨迹被压小
V = Pn(sel, :, :);
lims = nan(3, 2);
for d = 1:3
	v = V(:, :, d);
	v = v(isfinite(v));
	if isempty(v), lims(d, :) = [-1 1]; continue; end
	lo = prctile(v, 2);
	hi = prctile(v, 98);
	if hi - lo < 0.2, hi = lo + 0.2; end
	pd = 0.08 * (hi - lo);
	lims(d, :) = [lo - pd, hi + pd];
end
xlim(ax, lims(1, :)); ylim(ax, lims(2, :)); zlim(ax, lims(3, :));
pbaspect(ax, [1 1 1]);
axis(ax, 'off');
end

function [b1, b2] = iBinnedCorr(blocks, nBin)
% 单个 block 的 trial，按舔水栅格相似度分箱后的活动轨迹相关（5 主成分空间）
P = []; L = [];
for i = 1:numel(blocks)
	P = [P; blocks(i).ProjK]; %#ok<AGROW>
	L = [L; blocks(i).Lick]; %#ok<AGROW>
end
b1 = nan(1, nBin);
b2 = nan(1, nBin);
if isempty(P) || isempty(L), return; end
Cp = corr(reshape(P, size(P, 1), []).');      % trial 之间的活动轨迹相关（5 主成分空间）
Cl = corr(double(reshape(L, size(L, 1), [])).');  % trial 之间的舔水栅格相关
iu = triu(true(size(Cp)), 1);
x = Cl(iu);
y = Cp(iu);
q = quantile(x, linspace(0, 1, nBin + 1));
for b = 1:nBin
	r = x >= q(b) & x <= q(b + 1);
	if any(r)
		b1(b) = mean(y(r), 'omitnan');
	end
end
b2 = q;
end
